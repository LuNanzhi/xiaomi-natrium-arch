# Back up Android data off the phone BEFORE wiping userdata for postmarketOS.
#
# Pulls: internal storage (/sdcard: photos, downloads, documents), the installed
# package list, SMS/MMS and call log databases (needs adb root). App *data* of
# third-party apps cannot be pulled reliably without root-level tar tricks, but
# this covers what people usually care about.
#
# Usage: phone booted into LineageOS, then
#   powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\backup-android-data.ps1
# ASCII-only on purpose.

param([string]$Dest = 'C:\Users\Public\natrium\android-backup')

$ErrorActionPreference = 'Continue'
$adb = 'F:\platform-tools\adb.exe'
if (-not (Test-Path $adb)) { $c = Get-Command adb -ErrorAction SilentlyContinue; if ($c) { $adb = $c.Source } }

$d = & $adb devices 2>&1
if (-not ($d -match '\sdevice\s*$')) {
    Write-Host "!! phone not visible via adb (boot it into LineageOS first)" -ForegroundColor Red
    Write-Host $d
    exit 1
}

New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Write-Host "=== 0) destination: $Dest ===" -ForegroundColor Cyan

Write-Host "=== 1) storage usage on the phone ===" -ForegroundColor Cyan
& $adb shell "df -h /data /sdcard 2>/dev/null" | ForEach-Object { Write-Host "  $_" }

Write-Host "=== 2) listing /sdcard ===" -ForegroundColor Cyan
& $adb shell "ls -la /sdcard" | Out-File -Encoding utf8 (Join-Path $Dest 'sdcard-listing.txt')
Write-Host "  saved sdcard-listing.txt"

Write-Host "=== 3) pulling /sdcard (this is the big one, may take a long time) ===" -ForegroundColor Cyan
& $adb pull /sdcard (Join-Path $Dest 'sdcard')

Write-Host "=== 4) package list, SMS and call logs (needs adb root) ===" -ForegroundColor Cyan
& $adb root | Out-Null
Start-Sleep -Seconds 4
& $adb wait-for-device
& $adb shell "pm list packages" | Out-File -Encoding utf8 (Join-Path $Dest 'packages.txt')
& $adb shell "pm list packages -3" | Out-File -Encoding utf8 (Join-Path $Dest 'packages-thirdparty.txt')
& $adb shell "ls -l /data/data/com.android.providers.telephony/databases/ /data/data/com.android.providers.contacts/databases/ 2>/dev/null" |
    Out-File -Encoding utf8 (Join-Path $Dest 'databases-listing.txt')
foreach ($f in @(
    '/data/data/com.android.providers.telephony/databases/mmssms.db',
    '/data/data/com.android.providers.telephony/databases/telephony.db',
    '/data/data/com.android.providers.contacts/databases/contacts2.db',
    '/data/data/com.android.providers.calendar/databases/calendar.db'
)) {
    $name = Split-Path $f -Leaf
    & $adb shell "cp $f /sdcard/__backup_$name 2>/dev/null"
    & $adb pull "/sdcard/__backup_$name" (Join-Path $Dest $name) 2>&1 | Out-Null
    & $adb shell "rm -f /sdcard/__backup_$name"
    if (Test-Path (Join-Path $Dest $name)) { Write-Host "  pulled $name" } else { Write-Host "  (no $name)" -ForegroundColor DarkGray }
}

$size = (Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Write-Host ""
Write-Host ("=== DONE: {0:N2} GB in {1} ===" -f ($size / 1GB), $Dest) -ForegroundColor Green
Write-Host "Copy this folder somewhere safe (external drive / cloud) before flashing." -ForegroundColor Cyan
