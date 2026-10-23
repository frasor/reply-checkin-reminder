$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
if (-not $isAdmin) {
    Write-Host -Object:"Requesting Administrator privileges... Please click 'Yes' on the popup." -ForegroundColor:"Yellow";
    Start-Process -FilePath:"powershell.exe" -ArgumentList:"-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb:"RunAs";
    exit;
}

$AppDir = "$env:LOCALAPPDATA\ReplyCheckinReminder";
$SourceScript = "$PSScriptRoot\main.ps1";
$SourceConfig = "$PSScriptRoot\config.json";
$TargetScript = "$AppDir\main.ps1";
$TargetConfig = "$AppDir\config.json";
$VbsScript = "$AppDir\run_hidden.vbs";

Write-Host -Object:"Setting up application files..." -ForegroundColor:"Cyan";

if (-not (Test-Path -Path:$AppDir)) {
    New-Item -ItemType:"Directory" -Path:$AppDir | Out-Null;
}

Copy-Item -Path:$SourceScript -Destination:$TargetScript -Force:$true;

if (Test-Path -Path:$SourceConfig) {
    Copy-Item -Path:$SourceConfig -Destination:$TargetConfig -Force:$true;
}
else {
    Write-Warning -Message:"config.json not found in the same folder.";
}

$vbsCode = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$TargetScript""", 0, False
"@
Set-Content -Path:$VbsScript -Value:$vbsCode -Force:$true;

Write-Host -Object:"Configuring Task Scheduler via XML..." -ForegroundColor:"Cyan";

$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <CalendarTrigger>
      <StartBoundary>2024-01-01T09:00:00</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Hidden>true</Hidden>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
  </Settings>
  <Actions>
    <Exec>
      <Command>wscript.exe</Command>
      <Arguments>"$VbsScript"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Unregister-ScheduledTask -TaskName:"ReplyCheckinReminder" -Confirm:$false -ErrorAction:"SilentlyContinue";
Register-ScheduledTask -TaskName:"ReplyCheckinReminder" -Xml:$taskXml -User:$env:USERNAME -Force:$true | Out-Null;

Write-Host -Object:"Installation Complete! This window will close in 3 seconds." -ForegroundColor:"Green";
Start-Sleep -Seconds:3;