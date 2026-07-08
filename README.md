# resetSQL.ps1 — MySQL Root Password Reset Script

## What it does

This PowerShell script resets the `root@localhost` password for a local MySQL
Server installation on Windows. It automates the standard "safe mode" reset
procedure:

1. Re-launches itself elevated (as Administrator) if not already running as one.
2. Locates `mysqld.exe` (via `where.exe`, or by scanning
   `C:\Program Files\MySQL\MySQL Server *\bin`).
3. Locates the `mysql.exe` client binary (for auto-login at the end).
4. Locates the MySQL **data directory** (scans `C:\ProgramData\MySQL` and
   `C:\Program Files\MySQL` for a folder containing `ibdata1`).
5. Detects the MySQL Windows service and stops it (and kills any stray
   `mysqld.exe` processes).
6. Writes a temporary `.sql` file containing:
   ```sql
   ALTER USER 'root'@'localhost' IDENTIFIED BY '<new-password>';
   FLUSH PRIVILEGES;
   ```
7. Starts `mysqld.exe --no-defaults --init-file=<temp.sql>` so the ALTER USER
   statement runs automatically on startup, then waits for you to press
   `Ctrl+C` once it's ready.
8. Deletes the temp SQL file, restarts the MySQL service, and (if the client
   was found) logs you in as `root` with the new password.

## Usage

```powershell
.\resetSQL.ps1 -NewRootPassword "YourNewPassword123!"
```

The script requires Administrator rights and will elevate itself automatically
if needed (a UAC prompt will appear).

## ⚠️ Encoding issue to be aware of

The temporary SQL file is written with:

```powershell
Set-Content -Path $resetFile -Value $sqlContent -Encoding ASCII
```

**This is the main thing to fix or watch out for.** `-Encoding ASCII` only
supports the 7-bit ASCII character set. If `$NewRootPassword` contains any
non-ASCII character — accented letters (`é`, `ü`, `ñ`), symbols, or
characters from non-Latin alphabets — PowerShell will silently replace each
unsupported character with `?` when writing the file. That means:

- The password actually written into the `ALTER USER` statement will **not**
  match the password you typed.
- The script will report success, but you won't be able to log in with the
  password you intended — only with the mangled `?`-substituted version.

### Fix

Change the encoding to UTF-8 **without a BOM** (a BOM at the start of the
file can confuse `mysqld`'s SQL parser on some versions):

```powershell
[System.IO.File]::WriteAllText($resetFile, $sqlContent, (New-Object System.Text.UTF8Encoding($false)))
```

Or, if you're on PowerShell 6+ / 7+ (not Windows PowerShell 5.1), `-Encoding utf8NoBOM` works directly:

```powershell
Set-Content -Path $resetFile -Value $sqlContent -Encoding utf8NoBOM
```

Avoid plain `-Encoding UTF8` in **Windows PowerShell 5.1** — it writes a
UTF-8 BOM, which some MySQL versions choke on when reading `--init-file`.

### Extra safety tip

If you want to guarantee compatibility regardless of password characters,
restrict generated/entered passwords to ASCII-safe characters, or keep the
UTF-8-no-BOM fix above so any character set is preserved correctly.

## Common failure points

| Symptom | Likely cause |
|---|---|
| `mysqld.exe not found` | MySQL not installed in the default path, or not on `PATH`. Install location must be edited manually if non-standard. |
| `Could not locate the MySQL data directory` | Data directory is in a custom location. Edit `$dataDir` manually and re-run. |
| `mysqld exited with code <n>` | Port 3306 already in use by another MySQL instance, or wrong `--datadir` detected. |
| Can't log in with new password | Likely the ASCII encoding issue above — password characters were silently mangled. |

## Security notes

- The new password is passed as a plain-text command-line argument and
  briefly written to a temp file in `%TEMP%` (deleted immediately after use).
  On a shared or monitored machine, process command-line arguments and temp
  files can potentially be visible to other processes/users with sufficient
  privileges.
- The script opens an interactive `mysql` session with the password on the
  command line (`-p$NewRootPassword`), which may be visible in process
  listings (`tasklist`, Task Manager "Command line" column, etc.) for the
  duration of that command.
