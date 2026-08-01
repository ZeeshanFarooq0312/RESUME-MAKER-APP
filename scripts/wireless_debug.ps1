# Reconnects your Android phone to adb over Wi-Fi so you can debug without
# a USB cable. Wireless debugging drops every time the phone reboots (this
# is Android's own behavior, not a bug in this script) — plug the phone in
# via USB once and re-run this script to turn it back on.

$ErrorActionPreference = 'Stop'

function Find-Adb {
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:ANDROID_HOME\platform-tools\adb.exe",
        "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe"
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    $onPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    throw "Couldn't find adb.exe. Install Android platform-tools or set ANDROID_HOME."
}

$adb = Find-Adb
Write-Host "Using adb: $adb"

# Find a device connected via USB (serial won't contain ':', unlike an
# existing IP:port entry from a previous wireless session).
$deviceLines = & $adb devices -l | Select-String '^\S+\s+device\s'
$usbLine = $deviceLines | Where-Object { ($_ -split '\s+')[0] -notmatch ':\d+$' } | Select-Object -First 1

if (-not $usbLine) {
    Write-Host "No USB-connected phone found. Plug your phone in via USB, unlock it, accept the" -ForegroundColor Yellow
    Write-Host "'Allow USB debugging?' prompt if shown, then re-run this script." -ForegroundColor Yellow
    exit 1
}

$serial = ($usbLine -split '\s+')[0]
Write-Host "Found USB device: $serial"

$ipOutput = & $adb -s $serial shell ip addr show wlan0
$ipMatch = [regex]::Match($ipOutput, 'inet (\d+\.\d+\.\d+\.\d+)/')
if (-not $ipMatch.Success) {
    Write-Host "Couldn't determine the phone's Wi-Fi IP. Is it connected to Wi-Fi?" -ForegroundColor Red
    exit 1
}
$ip = $ipMatch.Groups[1].Value
Write-Host "Phone Wi-Fi IP: $ip"

& $adb -s $serial tcpip 5555 | Out-Null
Start-Sleep -Seconds 2
& $adb connect "$($ip):5555"

Write-Host ""
Write-Host "Done. You can unplug the USB cable now." -ForegroundColor Green
Write-Host "Run 'flutter devices' to confirm, or 'flutter run -d $($ip):5555' to launch on it directly."
