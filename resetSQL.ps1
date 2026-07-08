[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$NewRootPassword
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Warn2 {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
$isAdmin = $currentPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Warn2 "Not running as Administrator. Relaunching elevated..."
    $scriptPath = $MyInvocation.MyCommand.Path
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", "-NewRootPassword", "`"$NewRootPassword`"")
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}

Write-Step "Locating mysqld.exe..."

$mysqld = $null

$whereResult = & where.exe mysqld.exe 2>$null
if ($LASTEXITCODE -eq 0 -and $whereResult) {
    $mysqld = ($whereResult -split "`r?`n")[0]
}

if (-not $mysqld) {
    $candidates = Get-ChildItem "C:\Program Files\MySQL" -Directory -Filter "MySQL Server *" -ErrorAction SilentlyContinue
    foreach ($c in $candidates) {
        $candidatePath = Join-Path $c.FullName "bin\mysqld.exe"
        if (Test-Path $candidatePath) {
            $mysqld = $candidatePath
            break
        }
    }
}

if (-not $mysqld) {
    Write-Err "mysqld.exe not found."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Found mysqld:"
Write-Host "  $mysqld"

$mysqlBinDir  = Split-Path $mysqld -Parent
$mysqlBaseDir = Split-Path $mysqlBinDir -Parent

$mysqlClient = $null
$clientCandidate = Join-Path $mysqlBinDir "mysql.exe"
if (Test-Path $clientCandidate) {
    $mysqlClient = $clientCandidate
} else {
    $whereClient = & where.exe mysql.exe 2>$null
    if ($LASTEXITCODE -eq 0 -and $whereClient) {
        $mysqlClient = ($whereClient -split "`r?`n")[0]
    }
}

if ($mysqlClient) {
    Write-Host "Found mysql client:"
    Write-Host "  $mysqlClient"
} else {
    Write-Warn2 "mysql.exe client not found. Will skip auto-login at the end."
}

Write-Step "`nLocating MySQL data directory..."

$dataDir = $null

$dataRoots = @(
    "C:\ProgramData\MySQL",
    "C:\Program Files\MySQL"
)

foreach ($root in $dataRoots) {
    if (-not (Test-Path $root)) { continue }
    $serverDirs = Get-ChildItem $root -Directory -Filter "MySQL Server *" -ErrorAction SilentlyContinue
    foreach ($sd in $serverDirs) {
        foreach ($sub in @("Data", "data")) {
            $candidate = Join-Path $sd.FullName $sub
            if (Test-Path (Join-Path $candidate "ibdata1")) {
                $dataDir = $candidate
                break
            }
        }
        if ($dataDir) { break }
    }
    if ($dataDir) { break }
}

if (-not $dataDir) {
    Write-Err "Could not locate the MySQL data directory automatically."
    Write-Err "Edit `$dataDir manually in this script and re-run."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Found data directory:"
Write-Host "  $dataDir"

Write-Step "`nLooking for a MySQL Windows service..."

$mysqlService = Get-Service | Where-Object { $_.Name -like "*mysql*" } | Select-Object -First 1

if ($mysqlService) {
    Write-Host "Detected MySQL service: $($mysqlService.Name) (Status: $($mysqlService.Status))"
} else {
    Write-Warn2 "No MySQL service found (may be running standalone)."
}

if ($mysqlService -and $mysqlService.Status -ne 'Stopped') {
    Write-Step "Stopping service $($mysqlService.Name)..."
    try {
        Stop-Service -Name $mysqlService.Name -Force -ErrorAction Stop
        $mysqlService.WaitForStatus('Stopped', (New-TimeSpan -Seconds 30))
        Write-Host "Service stopped."
    } catch {
        Write-Err "Failed to stop service: $($_.Exception.Message)"
        Read-Host "Press Enter to exit"
        exit 1
    }
}

$strayProcs = Get-Process -Name mysqld -ErrorAction SilentlyContinue
if ($strayProcs) {
    Write-Warn2 "Stray mysqld.exe process(es) detected. Terminating..."
    $strayProcs | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$resetFile = Join-Path $env:TEMP ("mysql_reset_{0}.sql" -f ([System.Guid]::NewGuid().ToString("N")))

Write-Step "`nCreating temporary reset file:"
Write-Host "  $resetFile"

$escapedPassword = $NewRootPassword.Replace("'", "''")
$sqlContent = @"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$escapedPassword';
FLUSH PRIVILEGES;
"@

try {
    Set-Content -Path $resetFile -Value $sqlContent -Encoding utf8NoBOM -ErrorAction Stop
} catch {
    Write-Err "Failed to create reset file: $($_.Exception.Message)"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Step "`nStarting MySQL (no-defaults mode) to apply password reset..."
Write-Host "Wait until you see 'ready for connections', THEN press Ctrl+C" -ForegroundColor Yellow
Write-Host "to stop this instance and let the script continue.`n" -ForegroundColor Yellow

$mysqldArgs = @(
    "--no-defaults",
    "--basedir=`"$mysqlBaseDir`"",
    "--datadir=`"$dataDir`"",
    "--init-file=`"$resetFile`"",
    "--console"
)

$process = Start-Process -FilePath $mysqld -ArgumentList $mysqldArgs -NoNewWindow -PassThru -Wait
$mysqldExitCode = $process.ExitCode

Write-Step "`nRemoving temporary reset file..."
Remove-Item -Path $resetFile -Force -ErrorAction SilentlyContinue

if ($mysqldExitCode -ne 0) {
    Write-Warn2 "mysqld exited with code $mysqldExitCode."
    Write-Warn2 "If it failed to start immediately, the password was NOT reset."
    Write-Warn2 "Common causes: port 3306 already in use, or an incorrectly detected datadir."
    Write-Warn2 "Restarting the original service as-is without further changes..."
}

if ($mysqlService) {
    Write-Step "`nRestarting service $($mysqlService.Name)..."
    try {
        Start-Service -Name $mysqlService.Name -ErrorAction Stop
        $mysqlService.WaitForStatus('Running', (New-TimeSpan -Seconds 30))
        Write-Host "Service $($mysqlService.Name) is running."
    } catch {
        Write-Err "Service did not start in time or failed: $($_.Exception.Message)"
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    Write-Warn2 "No service was recorded to restart. Start MySQL manually if needed."
}

if ($mysqldExitCode -ne 0) {
    Write-Warn2 "`nSkipping auto-login since the reset likely did not apply."
    Write-Warn2 "Try logging in with your EXISTING root password instead:"
    Write-Warn2 "  mysql -u root -p"
    Read-Host "Press Enter to exit"
    exit 1
}

if ($mysqlClient) {
    Write-Step "`nOpening MySQL client as root..."
    & $mysqlClient "-u" "root" "-p$NewRootPassword"
} else {
    Write-Warn2 "mysql.exe not found — log in manually with:"
    Write-Warn2 "  mysql -u root -p"
}

Read-Host "`nPress Enter to exit"
