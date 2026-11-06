# One-shot: dump the phone cache partition, pull it, and extract the kernel diagnostics
# written by the logger image. ASCII-only on purpose.
# Usage: powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\get-diag.ps1

$ErrorActionPreference = 'Continue'
$adb = 'F:\platform-tools\adb.exe'
if (-not (Test-Path $adb)) { $c = Get-Command adb -ErrorAction SilentlyContinue; if ($c) { $adb = $c.Source } else { Write-Host "adb not found"; exit 1 } }
$dir = 'C:\Users\Public\natrium'
$img = Join-Path $dir 'cache.img'
$diag = Join-Path $dir 'natrium-diag.txt'

Write-Host "=== 1) adb root ===" -ForegroundColor Cyan
& $adb root
Start-Sleep -Seconds 4
& $adb wait-for-device
& $adb shell id

Write-Host "=== 2) dump cache on the phone ===" -ForegroundColor Cyan
& $adb push (Join-Path $dir 'dump-cache.sh') /data/local/tmp/dump-cache.sh
& $adb shell chmod 755 /data/local/tmp/dump-cache.sh
& $adb shell sh /data/local/tmp/dump-cache.sh

Write-Host "=== 3) pull the image ===" -ForegroundColor Cyan
& $adb pull /data/local/tmp/cache.img $img
& $adb shell rm -f /data/local/tmp/cache.img /data/local/tmp/dump-cache.sh

if (-not (Test-Path $img)) { Write-Host "pull failed - paste the output above" -ForegroundColor Red; exit 1 }
Write-Host ("    image: {0:N1} MB" -f ((Get-Item $img).Length / 1MB)) -ForegroundColor Gray

Write-Host "=== 4) extract the diagnostics text from the raw image ===" -ForegroundColor Cyan
$bytes = [System.IO.File]::ReadAllBytes($img)
$text  = [System.Text.Encoding]::ASCII.GetString($bytes)
$idx   = $text.IndexOf('===== natrium')
if ($idx -lt 0) { $idx = $text.IndexOf('Linux version 6') }

if ($idx -ge 0) {
    $len = [Math]::Min(200000, $text.Length - $idx)
    $chunk = $text.Substring($idx, $len)
    $chunk | Out-File -Encoding utf8 $diag
    Write-Host ""
    Write-Host "OK - saved to $diag" -ForegroundColor Green
    Write-Host "--- first 30 lines ---" -ForegroundColor Cyan
    ($chunk -split "`n" | Select-Object -First 30)
    Write-Host ""
    Write-Host "--- lines mentioning display / storage / errors ---" -ForegroundColor Cyan
    ($chunk -split "`n" | Select-String -Pattern 'drm|mdss|dsi|panel|wled|backlight|ufs|phy|error|fail|panic|regulator' | Select-Object -First 40 | ForEach-Object { $_.Line })
} else {
    Write-Host ""
    Write-Host "No 'natrium' / 6.x kernel text found in the cache image." -ForegroundColor Yellow
    Write-Host "=> the logger image could not mount the cache partition (likely UFS did not come up)." -ForegroundColor Yellow
    Write-Host "--- what IS in the image (first interesting lines) ---" -ForegroundColor Cyan
    ($text -split "`n" | Select-String -Pattern 'Linux version|drm|ufs|magisk' | Select-Object -First 15 | ForEach-Object { $_.Line })
}
