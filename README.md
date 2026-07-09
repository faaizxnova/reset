# resetSQL.exe — Reset Your MySQL Root Password

A standalone Windows tool that resets the `root@localhost` password for a
local MySQL Server install. No Python, no PowerShell setup, no execution
policy — just one `.exe` file.

## What it does

1. Asks for Administrator permission (UAC popup) if it doesn't already have it.
2. Finds MySQL on your computer automatically.
3. Stops the MySQL service for a moment.
4. Sets your new password.
5. Starts MySQL again.
6. Logs you in with the new password.

## How to use it

### Option A — Double-click

1. Double-click `resetSQL.exe`.
2. Click **Yes** on the UAC (Administrator permission) popup.
3. When asked, type the new password and press Enter.
4. Wait for it to finish. Once you see `ready for connections`, press
   `Ctrl+C` to let it continue automatically stopping/restarting MySQL.

### Option B — Command line

Open Command Prompt or PowerShell and run:

```
resetSQL.exe "YourNewPassword123!"
```

Replace `YourNewPassword123!` with the password you want. It will still
show a UAC popup for Administrator permission if needed.

## Verify it worked

Open a **separate** terminal and log in with the MySQL client:

```
mysql -u root -p
```

Enter your new password. If it logs in, the change worked.

## Common problems

| What you see | What it likely means |
|---|---|
| "mysqld.exe not found" | MySQL isn't installed in the usual location on this computer. |
| "Could not locate the MySQL data directory" | MySQL's data folder is in an unusual location. |
| mysqld fails to start again | Another program may already be using MySQL's port (3306). |
| Can't log in with new password | Double-check what you typed — special characters are supported, but a typo is the most common cause. |
| Window flashes and closes instantly | Should no longer happen — the tool now waits for input and pauses with an error message if something goes wrong. If you still see this, let me know exactly what you did (double-click vs. command line) so it can be tracked down. |

## Good to know (security)

- Your new password briefly appears in a temporary file and in the console
  window while it runs. It's deleted afterward, but on a shared computer,
  someone else with access could potentially see it during that short time.
- It needs Administrator rights because stopping/starting a Windows
  service requires them — this is unavoidable no matter how the tool is
  built.
