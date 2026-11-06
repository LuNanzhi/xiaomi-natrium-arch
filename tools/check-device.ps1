# Diagnose the USB state of xiaomi-natrium (Mi 5s Plus).
#
# Tells you which of these you are in, and what to do next:
#   A) Android booted          (adb)
#   B) fastboot / bootloader   (fastboot)
#   C) EDL / QDL 9008          (only MiFlash can talk to it)
#   D) nothing at all          (cable, driver, or powered off)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File check-device.ps1
#   powershell -ExecutionPolicy Bypass -File check-device.ps1 -Save fastboot-all.txt
#
# ASCII only on purpose.

param(
    [string]$Save = '',
    [string]$Fastboot = ''
)

$ErrorActionPreference = 'Continue'
$fb = $Fastboot
if (-not $fb) {
    $c = Get-Command fastboot -ErrorAction SilentlyContinue
    if ($c) { $fb = $c.Source }
    elseif (Test-Path 'F:\platform-tools\fastboot.exe') { $fb = 'F:\platform-tools\fastboot.exe' }
}
$ad = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $ad -and (Test-Path 'F:\platform-tools\adb.exe')) { $ad = 'F:\platform-tools\adb.exe' }

function Section($t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Cyan }

# ---------------------------------------------------------------- USB layer
Section "USB: Qualcomm / Xiaomi / Google devices"
$usb = @()
try {
    $usb = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -match 'VID_05C6|VID_18D1|VID_2717|VID_2A96' }
} catch { }
if ($usb) {
    $usb | Select-Object Status, Class, FriendlyName, InstanceId | Format-List
} else {
    Write-Host "  (none found)" -ForegroundColor DarkGray
}
$edl = $usb | Where-Object { $_.InstanceId -match 'VID_05C6&PID_9008' -or $_.FriendlyName -match '9008|QDLoader|QUSB_BULK' }
$qm = $usb | Where-Object { $_.InstanceId -match 'VID_05C6&PID_900E' -or $_.FriendlyName -match '900E' }

# ---------------------------------------------------------------- fastboot
Section "fastboot"
$fbOut = ''
if ($fb) {
    Write-Host "  tool: $fb"
    $fbOut = (& $fb devices 2>&1 | Out-String)
    Write-Host ($fbOut.Trim() -replace "`r?`n", "`n  ")
} else {
    Write-Host "  fastboot.exe NOT FOUND (install platform-tools)" -ForegroundColor Yellow
}
$fbOk = $fbOut -match '\S+\s+fastboot'

if ($fbOk) {
    Section "fastboot variables"
    $vars = @('product', 'variant', 'serialno', 'current-slot', 'partition-size:userdata', 'partition-size:boot', 'unlocked', 'secure')
    $lines = @()
    foreach ($v in $vars) {
        $r = (& $fb getvar $v 2>&1 | Out-String)
        $r = ($r -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1)
        $lines += ("  getvar {0,-26} {1}" -f $v, $r.Trim())
    }
    $lines | ForEach-Object { Write-Host $_ }

    Section "partition table (best effort)"
    & $fb getvar all 2>&1 | Out-String | Write-Host

    if ($Save) {
        (& $fb getvar all 2>&1 | Out-String) | Set-Content -Path $Save -Encoding UTF8
        Write-Host "  saved to $Save" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------- adb
Section "adb"
if ($ad) {
    Write-Host "  tool: $ad"
    $adOut = (& $ad devices 2>&1 | Out-String)
    Write-Host ($adOut.Trim() -replace "`r?`n", "`n  ")
} else {
    Write-Host "  adb.exe NOT FOUND" -ForegroundColor Yellow
}
$adOk = $adOut -match '\S+\s+device$'

# ---------------------------------------------------------------- verdict
Section "VERDICT"
if ($edl) {
    Write-Host "  [C] EDL / QDL 9008 mode." -ForegroundColor Red
    Write-Host "      The phone is in Qualcomm's emergency download mode."
    Write-Host "      Nothing except MiFlash (or qdl) can talk to it."
    Write-Host "      Fix: download the official fastboot ROM for natrium and flash with MiFlash."
    Write-Host "      (a plain USB cable + MiFlash 2020.x; ROM name contains 'natrium')"
} elseif ($qm) {
    Write-Host "  [C2] Qualcomm 900E (diagnostic) mode - almost the same as EDL." -ForegroundColor Red
    Write-Host "      Force a power-off (hold power 15 s), then try Volume-Down + Power."
} elseif ($fbOk) {
    Write-Host "  [B] fastboot works. Good - the bootloader is alive." -ForegroundColor Green
    Write-Host "      Next: rescue Android, or test a mainline kernel."
    Write-Host "        rescue:  powershell -ExecutionPolicy Bypass -File rescue-to-android.ps1"
    Write-Host "        test  :  fastboot boot C:\Users\Public\natrium\boot-6195-bbshell.img"
} elseif ($adOk) {
    Write-Host "  [A] Android is running (adb). The phone is fine." -ForegroundColor Green
    Write-Host "      Reboot to fastboot with:  adb reboot bootloader"
} else {
    Write-Host "  [D] No device visible." -ForegroundColor Yellow
    Write-Host "      1. Use a DATA cable (not charge-only), plug into a rear USB2 port."
    Write-Host "      2. Hold Power ~15 s to force off, then hold Volume-Down + Power ~10 s."
    Write-Host "      3. Watch Device Manager: any unknown device / 'QUSB_BULK' / 'Android'?"
    Write-Host "      4. Windows may need the Xiaomi/Google USB driver (WinUSB)."
    Write-Host "      5. If the screen shows a MI logo loop, it is NOT EDL - just wait for fastboot."
}
Write-Host ""
