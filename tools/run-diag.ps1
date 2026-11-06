param([string]$Image = '')

# ONE-SHOT end-to-end diagnostic:
#   1) verifies the phone is in fastboot
#   2) boots a logger image (writes dmesg into the cache partition, then self-reboots)
#   3) waits for LineageOS to come back
#   4) dumps + pulls the cache partition and extracts the kernel diagnostics
# ASCII-only on purpose (Windows PowerShell 5.1 parses .ps1 as ANSI).
#
# Usage: put the phone into fastboot (Vol- + Power), then run:
#   powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\run-diag.ps1
# Optionally pick a specific image:
#   ... -File ...\run-diag.ps1 -Image C:\Users\Public\natrium\boot-xxx-logger.img

$ErrorActionPreference = 'Continue'
$nat  = 'C:\Users\Public\natrium'
$adb  = 'F:\platform-tools\adb.exe'
$fb   = 'F:\platform-tools\fastboot.exe'

if (-not $Image) {
    # prefer the newest logger image that exists
    $cands = @('boot-6.12.10-msm-logger.img', 'boot-6.17.8-msm-logger.img',
               'boot-6.18.7-msmpmos-logger.img', 'boot-6.19.5-msmpmos-logger.img',
               'boot-6.18.55-static-logger.img')
    foreach ($c in $cands) {
        $p = Join-Path $nat $c
        if (Test-Path $p) { $Image = $p; break }
    }
}
$img  = $Image
$out  = Join-Path $nat 'cache.img'
$diag = Join-Path $nat 'natrium-diag.txt'

Write-Host "=== 0) sanity ===" -ForegroundColor Cyan
Write-Host "    using image: $img"
foreach ($p in @($adb, $fb, $img, (Join-Path $nat 'dump-cache.sh'))) {
    if (-not (Test-Path $p)) { Write-Host "MISSING: $p" -ForegroundColor Red; exit 1 }
}
Write-Host ("    image sha256: {0}" -f (Get-FileHash $img -Algorithm SHA256).Hash)

Write-Host "=== 1) fastboot devices ===" -ForegroundColor Cyan
$devs = & $fb devices 2>&1
$devs
if (-not ($devs -match 'fastboot')) {
    Write-Host ""
    Write-Host "Phone is not in fastboot mode." -ForegroundColor Yellow
    Write-Host "Power off (hold Power 15s), then hold Vol- + Power until FASTBOOT shows, then rerun this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== 2) boot the logger image (takes 1-3 min to hand over) ===" -ForegroundColor Cyan
& $fb boot $img

Write-Host "=== 3) wait for LineageOS to come back (up to 8 min) ===" -ForegroundColor Cyan
$deadline = (Get-Date).AddMinutes(8)
$back = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 6
    $d = & $adb devices 2>&1
    if ($d -match '\sdevice\s*$') { $back = $true; break }
    Write-Host ("    ...waiting ({0:HH:mm:ss})" -f (Get-Date)) -ForegroundColor DarkGray
}
if (-not $back) {
    Write-Host "Phone did not come back within 8 minutes." -ForegroundColor Yellow
    Write-Host "Power-cycle it (hold Power 15s) and rerun this script." -ForegroundColor Yellow
    exit 1
}
Write-Host "    phone is back" -ForegroundColor Green
Start-Sleep -Seconds 10

Write-Host "=== 4) adb root ===" -ForegroundColor Cyan
& $adb root
Start-Sleep -Seconds 4
& $adb wait-for-device

Write-Host "=== 5) dump cache on the phone ===" -ForegroundColor Cyan
& $adb push (Join-Path $nat 'dump-cache.sh') /data/local/tmp/dump-cache.sh
& $adb shell chmod 755 /data/local/tmp/dump-cache.sh
& $adb shell sh /data/local/tmp/dump-cache.sh

Write-Host "=== 6) pull the image ===" -ForegroundColor Cyan
& $adb pull /data/local/tmp/cache.img $out
& $adb shell rm -f /data/local/tmp/cache.img /data/local/tmp/dump-cache.sh
if (-not (Test-Path $out)) { Write-Host "pull failed" -ForegroundColor Red; exit 1 }

Write-Host "=== 7) extract the diagnostics ===" -ForegroundColor Cyan
$bytes = [System.IO.File]::ReadAllBytes($out)
$text  = [System.Text.Encoding]::ASCII.GetString($bytes)
$idx   = $text.IndexOf('===== natrium')
if ($idx -lt 0) { $idx = $text.IndexOf('Linux version 6') }

if ($idx -ge 0) {
    $chunk = $text.Substring($idx, [Math]::Min(200000, $text.Length - $idx))
    $chunk | Out-File -Encoding utf8 $diag
    Write-Host ""
    Write-Host "SUCCESS - saved to $diag" -ForegroundColor Green
    Write-Host "--- first 40 lines ---" -ForegroundColor Cyan
    ($chunk -split "`n" | Select-Object -First 40)
    Write-Host ""
    Write-Host "--- display / storage / error lines ---" -ForegroundColor Cyan
    ($chunk -split "`n" | Select-String -Pattern 'drm|mdss|dsi|panel|wled|backlight|ufs|phy|regulator|error|fail|panic' | Select-Object -First 60 | ForEach-Object { $_.Line })
} else {
    Write-Host ""
    Write-Host "Still no 6.x kernel text in the cache image." -ForegroundColor Yellow
    Write-Host "That means the 6.18.7 kernel also failed to reach/mount the cache partition." -ForegroundColor Yellow
    Write-Host "Send this whole output to the agent." -ForegroundColor Yellow
}
