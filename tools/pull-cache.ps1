# Pull the cache partition to the PC for offline ext4 parsing.
# Usage: powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\pull-cache.ps1
# ASCII-only on purpose (Windows PowerShell 5.1 parses .ps1 as ANSI).
# No 'su' needed: 'adb root' is enabled, so adb shell already runs as root.

$ErrorActionPreference = 'Continue'
$adb = 'F:\platform-tools\adb.exe'
if (-not (Test-Path $adb)) { $c = Get-Command adb -ErrorAction SilentlyContinue; if ($c) { $adb = $c.Source } else { Write-Host "adb not found" ; exit 1 } }
$out  = 'C:\Users\Public\natrium\cache.img'
$sh   = 'C:\Users\Public\natrium\dump-cache.sh'

Write-Host "=== 1) adb root ===" -ForegroundColor Cyan
& $adb root
Start-Sleep -Seconds 4
& $adb wait-for-device
& $adb shell id

Write-Host "=== 2) push device script ===" -ForegroundColor Cyan
& $adb push $sh /data/local/tmp/dump-cache.sh
& $adb shell chmod 755 /data/local/tmp/dump-cache.sh

Write-Host "=== 3) run it on the phone ===" -ForegroundColor Cyan
& $adb shell sh /data/local/tmp/dump-cache.sh

Write-Host "=== 4) pull the image ===" -ForegroundColor Cyan
& $adb pull /data/local/tmp/cache.img $out

Write-Host "=== 5) cleanup on phone ===" -ForegroundColor Cyan
& $adb shell rm -f /data/local/tmp/cache.img /data/local/tmp/dump-cache.sh

if (Test-Path $out) {
    Write-Host ""
    Write-Host ("OK - saved {0} ({1:N1} MB)" -f $out, ((Get-Item $out).Length / 1MB)) -ForegroundColor Green
    Write-Host "Tell the agent it is ready - it will parse the ext4 image locally." -ForegroundColor Green
} else {
    Write-Host "FAILED to pull the image - paste the output above to the agent." -ForegroundColor Yellow
}
