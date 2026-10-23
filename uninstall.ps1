$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
if (-not $isAdmin) {
    Write-Host -Object:"Requesting Administrator privileges... Please click 'Yes' on the popup." -ForegroundColor:"Yellow";
    Start-Process -FilePath:"powershell.exe" -ArgumentList:"-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb:"RunAs";
    exit;
}

$AppDir = "$env:LOCALAPPDATA\ReplyCheckinReminder";
$TaskName = "ReplyCheckinReminder";

Write-Host -Object:"Starting uninstallation of Reply Checkin Reminder..." -ForegroundColor:"Cyan";

$existingTask = Get-ScheduledTask -TaskName:$TaskName -ErrorAction:"SilentlyContinue";
if ($null -ne $existingTask) {
    Write-Host -Object:"Removing Scheduled Task: $TaskName..." -ForegroundColor:"Yellow";
    Unregister-ScheduledTask -TaskName:$TaskName -Confirm:$false;
}
else {
    Write-Host -Object:"Scheduled Task not found. Skipping..." -ForegroundColor:"DarkGray";
}

if (Test-Path -Path:$AppDir) {
    Write-Host -Object:"Removing application directory and state files: $AppDir..." -ForegroundColor:"Yellow";
    Remove-Item -Path:$AppDir -Recurse:$true -Force:$true;
}
else {
    Write-Host -Object:"Application directory not found. Skipping..." -ForegroundColor:"DarkGray";
}

Remove-Item -Path:"HKCU:\Software\Classes\AppUserModelId\Reply.Checkin.Reminder" -Recurse:$true -Force:$true -ErrorAction:"SilentlyContinue";

Write-Host -Object:"Uninstallation Complete! All traces have been removed. This window will close in 5 seconds." -ForegroundColor:"Green";
Start-Sleep -Seconds:3;