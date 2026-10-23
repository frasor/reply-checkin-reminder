# Reply Check-In Reminder

A background script for Windows that reminds you to do your Reply check-in once a day. 

Instead of using a dumb timer, it checks your Wi-Fi to see if you are in the office. If you aren't in the office, it waits until your normal start time (like 9:00 AM) and watches for mouse movement to know when you've actually started working remotely. Once triggered, it pops up a persistent Windows notification with a button that opens the booking page, then shuts itself off until tomorrow.

## Requirements & PowerShell Compatibility

* **OS:** Windows 10 or Windows 11.
* **PowerShell:** Works with both Windows PowerShell 5.1 (built into Windows) and PowerShell 7+. 
  *(Note: Windows Toast notifications require the legacy 5.1 engine to render, so `main.ps1` automatically calls `powershell.exe` in the background via a hidden VBScript wrapper. You can run the install/uninstall scripts from any terminal, including VS Code).*

## Setup (`config.json`)

Create a `config.json` file in the same folder as the scripts before installing:

```json
{
    "BookingUrl": "https://your-reply-booking-url.com",
    "OfficeNetwork": "ReplyWifiName",
    "RemoteHourTrigger": 9
}
```

* **BookingUrl**: The full URL (`https://...`) to open when you click the notification button.
* **OfficeNetwork**: The exact Wi-Fi SSID of your office (case-sensitive).
* **RemoteHourTrigger**: The hour (0–23) when the script should start checking for mouse movement if you're working from home (e.g., `9` for 9:00 AM). If you turn on your PC earlier than this, the script sleeps until this hour.

## Installation & Execution Policy

By default, Windows blocks unsigned `.ps1` scripts from running. If you get an *Execution Policy* error when trying to install or uninstall, you need to bypass the block for your current terminal session first.

> **Warning:** Bypassing the PowerShell execution policy disables Windows' built-in protection against running untrusted scripts. Only run this command for scripts you have inspected and trust. Using `-Scope Process` ensures the bypass is temporary and resets as soon as you close the terminal window—do not change your global system policy unless you know what you are doing.

**NB:** If scripts are blocked on your machine, run this command in your PowerShell window **before** running `install.ps1` or `uninstall.ps1`:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Installing the Task
Once your `config.json` is ready, open PowerShell in the project folder and run:

```powershell
.\install.ps1
```

Click **Yes** on the UAC Administrator prompt. The script will:
1. Copy `main.ps1` and `config.json` to `%LOCALAPPDATA%\ReplyCheckinReminder`.
2. Create a hidden VBScript wrapper (`run_hidden.vbs`) so no console window flashes on startup.
3. Register a Scheduled Task (`ReplyCheckinReminder`) that runs at logon and at 9:00 AM daily.

If you change `config.json` later, re-run `.\install.ps1` to copy the updated file over (or edit the one in `%LOCALAPPDATA%\ReplyCheckinReminder` directly).

## Testing Manually

Once the notification triggers, it writes today's date into `%LOCALAPPDATA%\ReplyCheckinReminder\last_checkin.txt` so it won't bother you again for the rest of the day.

If you want to test the popup again on the same day, delete that file first and run `main.ps1`:

```powershell
Remove-Item "$env:LOCALAPPDATA\ReplyCheckinReminder\last_checkin.txt" -ErrorAction SilentlyContinue
.\main.ps1
```

Make sure Windows "Do Not Disturb" / "Focus Assist" is turned off, otherwise Windows will hide the popup inside the Action Center.

## Uninstallation

To remove the scheduled task and delete everything in `%LOCALAPPDATA%\ReplyCheckinReminder`:

1. If PowerShell blocks the script, run the temporary bypass first:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
2. Run the uninstaller and accept the UAC Administrator prompt:
   ```powershell
   .\uninstall.ps1
   ```