$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "Requesting Administrator privileges... Please click 'Yes' on the popup." -ForegroundColor Yellow
  Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
  exit
}

$AppDir = "$env:LOCALAPPDATA\ReplyCheckinReminder"
$SourceScript = "$PSScriptRoot\main.ps1"
$SourceConfig = "$PSScriptRoot\config.json"
$TargetScript = "$AppDir\main.ps1"
$TargetConfig = "$AppDir\config.json"
$VbsScript = "$AppDir\run_hidden.vbs"

Write-Host "Setting up application files..." -ForegroundColor Cyan

if (-not (Test-Path -Path $AppDir)) {
  New-Item -ItemType Directory -Path $AppDir | Out-Null
}

Copy-Item -Path $SourceScript -Destination $TargetScript -Force

$TriggerHour = 9
if (Test-Path -Path $SourceConfig) {
  Copy-Item -Path $SourceConfig -Destination $TargetConfig -Force
  $Config = Get-Content -Path $SourceConfig -Raw | ConvertFrom-Json
  if ($null -ne $Config.RemoteHourTrigger) {
    $TriggerHour = [int]$Config.RemoteHourTrigger
  }
}
else {
  Write-Warning "config.json not found in the same folder. Defaulting trigger hour to 09:00."
}

$FormattedHour = "{0:D2}:00:00" -f $TriggerHour

$vbsCode = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$TargetScript""", 0, True
"@
Set-Content -Path $VbsScript -Value $vbsCode -Force

Write-Host "Configuring Task Scheduler via XML (Mon-Fri at $FormattedHour)..." -ForegroundColor Cyan

$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <CalendarTrigger>
      <StartBoundary>2024-01-01T$FormattedHour</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByWeek>
        <DaysOfWeek>
          <Monday />
          <Tuesday />
          <Wednesday />
          <Thursday />
          <Friday />
        </DaysOfWeek>
        <WeeksInterval>1</WeeksInterval>
      </ScheduleByWeek>
    </CalendarTrigger>
  </Triggers>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Hidden>true</Hidden>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <ExecutionTimeLimit>PT12H</ExecutionTimeLimit>
  </Settings>
  <Actions>
    <Exec>
      <Command>wscript.exe</Command>
      <Arguments>"$VbsScript"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Unregister-ScheduledTask -TaskName "ReplyCheckinReminder" -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName "ReplyCheckinReminder" -Xml $taskXml -User $env:USERNAME -Force | Out-Null

Write-Host "Installation Complete! This window will close in 3 seconds." -ForegroundColor Green
Start-Sleep -Seconds 3