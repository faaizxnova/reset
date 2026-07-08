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

## How to use it (step by step)

1. **Open PowerShell as Administrator**
   Right-click PowerShell → "Run as administrator."

2. **Move to the folder where the script is saved**
   ```powershell
   cd "C:\path\to\folder"
   ```

3. **Fix the encoding** (see below) so special characters in your password
   aren't lost. Open the script and change:
   ```powershell
   Set-Content -Path $resetFile -Value $sqlContent -Encoding ASCII
   ```
   to:
   ```powershell
   Set-Content -Path $resetFile -Value $sqlContent -Encoding utf8NoBOM
   ```

4. **Allow the script to run (bypass execution policy)**
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process
   ```
   This only allows scripts to run for this one PowerShell window/session —
   it doesn't change any permanent settings on your computer.

5. **Run the script with your new password**
   ```powershell
   .\resetSQL.ps1 "newpassword"
   ```

6. **Check the password actually changed**
   - Don't close the terminal yet.
   - Open a **separate** Command Prompt or PowerShell window and log in with
     the MySQL command-line client:
     ```powershell
     mysql -u root -p
     ```
   - Enter your new password when prompted. If it logs in, the change worked.

7. **Close the script's session and restart the MySQL service**
   - You can now close/end the resetSQL.ps1 session in the first terminal.
   - Open the **Run** dialog (`Win + R`), type `services.msc`, press Enter.
   - Find the MySQL service in the list, right-click it, and choose **Restart**
     (or Stop, then Start) to make sure it's running normally with the new
     password in place.

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

### 2. The script bypasses Windows' normal safety check

When the script re-opens itself with admin rights, it adds `-ExecutionPolicy Bypass`.
This tells Windows to **bypass** (skip) the usual check that blocks scripts
from running. That's why the script works even on computers that normally
stop scripts from running. This bypass only applies to this one run — it
doesn't change any permanent settings on your computer.

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
