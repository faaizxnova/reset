# resetSQL.ps1 — Reset Your MySQL Root Password

## What this script does

This script resets the password for the MySQL `root` user on Windows.
In simple steps, it:

1. Asks for admin permission (a Windows popup) if it doesn't already have it.
2. Finds MySQL on your computer automatically.
3. Stops MySQL for a moment.
4. Sets your new password.
5. Starts MySQL again.
6. Logs you in with the new password.

## How to use it

Open PowerShell and run:

```powershell
.\resetSQL.ps1 -NewRootPassword "YourNewPassword123!"
```

Replace `YourNewPassword123!` with the password you want.

## Things to fix or watch out for

### 1. Password characters can get lost (encoding problem)

The script saves your password using **ASCII** text format. This format
only understands plain English letters, numbers, and basic symbols.

If your password has special characters — like `é`, `ñ`, `ü`, or letters
from other languages — those characters get turned into `?` marks. This
means the password that actually gets saved is **not** the one you typed,
and you won't be able to log in with it afterward.

**Fix:** Use UTF-8 (without BOM) instead of ASCII when saving the file:

```powershell
Set-Content -Path $resetFile -Value $sqlContent -Encoding utf8NoBOM
```

**Simple tip:** To avoid this problem entirely, use only plain English
letters, numbers, and basic symbols (like `!@#$%`) in your password.

### 2. The script skips Windows' normal safety check

When the script re-opens itself with admin rights, it tells Windows to
skip the "is this script allowed to run" check (called execution policy).
This is why the script can run even on computers that normally block
scripts. It only skips the check for this one run — it doesn't change
any settings on your computer permanently.

## Common problems

| What you see | What it likely means |
|---|---|
| "mysqld.exe not found" | MySQL isn't installed in the usual location. |
| "Could not locate the MySQL data directory" | MySQL's data folder is somewhere unusual. |
| MySQL fails to start again | Another program may be using MySQL's port (3306). |
| Can't log in with new password | Most likely the encoding problem above — try a simpler password. |

## Good to know (security)

- Your new password briefly appears in a temporary file and in the command
  window while the script runs. It's deleted afterward, but on a shared
  computer, someone else with access could potentially see it during that
  short time.
