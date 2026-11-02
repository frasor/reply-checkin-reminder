$mutexName = "Local\ReplyCheckinReminderMutex"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
    exit
}

try {
    $dayOfWeek = (Get-Date).DayOfWeek
    if ($dayOfWeek -eq 'Saturday' -or $dayOfWeek -eq 'Sunday') {
        exit
    }

    $ConfigFile = "$PSScriptRoot\config.json"
    if (-not (Test-Path -Path $ConfigFile)) {
        exit
    }
    $Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json

    $BookingUrl = $Config.BookingUrl
    $OfficeNetwork = $Config.OfficeNetwork
    $RemoteHourTrigger = [int]$Config.RemoteHourTrigger

    Add-Type -AssemblyName "System.Windows.Forms"

    $AppDir = "$env:LOCALAPPDATA\ReplyCheckinReminder"
    $StateFile = "$AppDir\last_checkin.txt"
    $todayStr = (Get-Date).ToString("yyyy-MM-dd")

    if (Test-Path -Path $StateFile) {
        $lastRun = (Get-Content -Path $StateFile -Raw).Trim()
        if ($lastRun -eq $todayStr) {
            exit
        }
    }

    if (-not (Test-Path -Path $AppDir)) {
        New-Item -ItemType Directory -Path $AppDir | Out-Null
    }

    function Get-ActiveSSID {
        $wlan = netsh wlan show interfaces
        # Match 'SSID' but not 'BSSID'
        $ssidLine = $wlan | Select-String -Pattern "^\s*SSID\s*:" | Select-Object -First 1
        if ($ssidLine) {
            $parts = $ssidLine.ToString() -split ":", 2
            if ($parts.Count -eq 2) {
                return $parts[1].Trim()
            }
        }
        return $null
    }

    function Show-NativeNotification {
        param(
            [string]$Title,
            [string]$Message,
            [string]$Url
        )

        $currentToday = (Get-Date).ToString("yyyy-MM-dd")
        if (Test-Path -Path $StateFile) {
            $lastRun = (Get-Content -Path $StateFile -Raw).Trim()
            if ($lastRun -eq $currentToday) {
                exit
            }
        }

        Set-Content -Path $StateFile -Value $currentToday -NoNewline

        $MenuDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\ReplyCheckin"
        if (-not (Test-Path -Path $MenuDir)) {
            New-Item -ItemType Directory -Path $MenuDir | Out-Null
        }
        $ShortcutPath = "$MenuDir\Reply.lnk"
        if (-not (Test-Path -Path $ShortcutPath)) {
            $WshShell = New-Object -ComObject "WScript.Shell"
            $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
            $Shortcut.TargetPath = "$env:SystemRoot\explorer.exe"
            $Shortcut.Save()
        }

        $toastXmlString = @"
<toast scenario="reminder" launch="$Url" activationType="protocol">
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
    <actions>
        <action content="Check In Now" arguments="$Url" activationType="protocol"/>
    </actions>
</toast>
"@

        $tempXmlPath = "$AppDir\temp_toast.xml"
        Set-Content -Path $tempXmlPath -Value $toastXmlString -Encoding UTF8

        $AppIdName = "Reply.Checkin.Reminder"
        $RegPath = "HKCU:\Software\Classes\AppUserModelId\$AppIdName"
        if (-not (Test-Path -Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }
        Set-ItemProperty -Path $RegPath -Name "DisplayName" -Value "Reply" -Type String -Force
        Set-ItemProperty -Path $RegPath -Name "IconUri" -Value "$env:SystemRoot\System32\shell32.dll,14" -Type ExpandString -Force

        $notifyScriptPath = "$AppDir\send_toast.ps1"
        $notifyCmd = @"
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
`$xmlString = Get-Content -Path '$tempXmlPath' -Raw -Encoding 'UTF8'
`$toastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
`$toastXml.LoadXml(`$xmlString)
`$toast = [Windows.UI.Notifications.ToastNotification]::new(`$toastXml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('$AppIdName').Show(`$toast)
"@
        Set-Content -Path $notifyScriptPath -Value $notifyCmd -Encoding UTF8

        $vbsToastPath = "$AppDir\send_toast.vbs"
        $vbsContent = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$notifyScriptPath""", 0, True
"@
        Set-Content -Path $vbsToastPath -Value $vbsContent -Encoding ASCII

        & wscript.exe "$vbsToastPath"
    }

    while ($true) {
        $currentSSID = Get-ActiveSSID
        if (-not [string]::IsNullOrWhiteSpace($currentSSID) -and ($currentSSID -eq $OfficeNetwork)) {
            Show-NativeNotification -Title "🏢 Office Detected" -Message "You are connected to the office network. Please check in your desk!" -Url $BookingUrl
            exit
        }

        $currentHour = (Get-Date).Hour
        if ($currentHour -ge $RemoteHourTrigger) {
            $lastPos = [System.Windows.Forms.Cursor]::Position
            
            while ($true) {
                Start-Sleep -Seconds 2
                
                $currentSSID = Get-ActiveSSID
                if (-not [string]::IsNullOrWhiteSpace($currentSSID) -and ($currentSSID -eq $OfficeNetwork)) {
                    Show-NativeNotification -Title "🏢 Office Detected" -Message "You are connected to the office network. Please check in your desk!" -Url $BookingUrl
                    exit
                }

                $currentPos = [System.Windows.Forms.Cursor]::Position
                $diffX = [math]::Abs($lastPos.X - $currentPos.X)
                $diffY = [math]::Abs($lastPos.Y - $currentPos.Y)
                
                if (($diffX -gt 50) -or ($diffY -gt 50)) {
                    Show-NativeNotification -Title "🏠 Remote Work Detected" -Message "You've started working. Time to do your remote check-in!" -Url $BookingUrl
                    exit
                }
                $lastPos = $currentPos
            }
        }

        Start-Sleep -Seconds 60
    }
}
finally {
    if ($null -ne $mutex) {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}