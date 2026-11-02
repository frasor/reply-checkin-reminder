$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges... Please click 'Yes' on the popup." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$AppDir = "$env:LOCALAPPDATA\ReplyCheckinReminder"
$MenuDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\ReplyCheckin"
$RegPath = "HKCU:\Software\Classes\AppUserModelId\Reply.Checkin.Reminder"
$TaskName = "ReplyCheckinReminder"

Write-Host "Starting uninstallation of Reply Checkin Reminder..." -ForegroundColor Cyan

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask) {
    Write-Host "Stopping and removing Scheduled Task: $TaskName..." -ForegroundColor Yellow
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
else {
    Write-Host "Scheduled Task not found. Skipping..." -ForegroundColor DarkGray
}

Write-Host "Stopping any running background processes..." -ForegroundColor Yellow
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'wscript.exe'" -ErrorAction SilentlyContinue |
Where-Object { $_.CommandLine -like "*ReplyCheckinReminder*" } |
ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Start-Sleep -Seconds 1

if (Test-Path -Path $AppDir) {
    Write-Host "Removing application directory and state files: $AppDir..." -ForegroundColor Yellow
    Remove-Item -Path $AppDir -Recurse -Force -ErrorAction SilentlyContinue
}
else {
    Write-Host "Application directory not found. Skipping..." -ForegroundColor DarkGray
}

if (Test-Path -Path $MenuDir) {
    Write-Host "Removing Start Menu shortcut: $MenuDir..." -ForegroundColor Yellow
    Remove-Item -Path $MenuDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path -Path $RegPath) {
    Write-Host "Removing Registry entries..." -ForegroundColor Yellow
    Remove-Item -Path $RegPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Uninstallation Complete! All traces have been removed. This window will close in 3 seconds." -ForegroundColor Green
Start-Sleep -Seconds 3