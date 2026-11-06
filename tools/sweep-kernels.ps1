# AUTO SWEEP: try every candidate kernel in turn and report which one actually boots.
#
# How it works: for each logger image it does `fastboot boot`, waits for the phone to
# come back, dumps the cache partition and looks for our diagnostics log. A kernel that
# reaches userspace writes that log; one that dies early does not. Between attempts it
# uses `adb reboot bootloader` to get back into fastboot automatically.
#
# Usage: powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\sweep-kernels.ps1
# Requirements: phone connected, booted into LineageOS (adb), nothing else to do.
# ASCII-only on purpose (Windows PowerShell 5.1 parses .ps1 as ANSI).

$ErrorActionPreference = 'Continue'
$nat = 'C:\Users\Public\natrium'
$adb = 'F:\platform-tools\adb.exe'
$fb  = 'F:\platform-tools\fastboot.exe'
if (-not (Test-Path $adb)) { $c = Get-Command adb -ErrorAction SilentlyContinue; if ($c) { $adb = $c.Source } }
if (-not (Test-Path $fb))  { $c = Get-Command fastboot -ErrorAction SilentlyContinue; if ($c) { $fb = $c.Source } }
$dump = Join-Path $nat 'dump-cache.sh'
$imgCache = Join-Path $nat 'cache.img'
$report = Join-Path $nat 'sweep-results.txt'

# oldest first: the device is archived upstream, so older kernels are the best bet
$images = @(
    'boot-6.12.10-msm-logger.img',
    'boot-6.17.8-msm-logger.img',
    'boot-6.18.7-msmpmos-logger.img',
    'boot-6.19.5-msmpmos-logger.img',
    'boot-6.18.55-ufs-logger.img'
)

function Wait-Adb([int]$seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        $d = & $adb devices 2>&1
        if ($d -match '\sdevice\s*$') { return $true }
    }
    return $false
}

function Wait-Fastboot([int]$seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $d = & $fb devices 2>&1
        if ($d -match 'fastboot') { return $true }
    }
    return $false
}

function Get-CacheLog {
    # returns the extracted log text (or $null)
    if (Test-Path $imgCache) { Remove-Item $imgCache -Force }
    & $adb root | Out-Null
    Start-Sleep -Seconds 3
    & $adb wait-for-device | Out-Null
    & $adb push $dump /data/local/tmp/dump-cache.sh | Out-Null
    & $adb shell chmod 755 /data/local/tmp/dump-cache.sh | Out-Null
    & $adb shell sh /data/local/tmp/dump-cache.sh | Out-Null
    & $adb pull /data/local/tmp/cache.img $imgCache | Out-Null
    & $adb shell rm -f /data/local/tmp/cache.img /data/local/tmp/dump-cache.sh | Out-Null
    if (-not (Test-Path $imgCache)) { return $null }
    $bytes = [IO.File]::ReadAllBytes($imgCache)
    $txt = [Text.Encoding]::ASCII.GetString($bytes)
    Remove-Item $imgCache -Force
    $i = $txt.IndexOf('===== natrium')
    if ($i -lt 0) { return $null }
    return $txt.Substring($i, [Math]::Min(200000, $txt.Length - $i))
}

$log = @()
$log += "===== kernel sweep started $(Get-Date) ====="

# make sure we start from a known state
Write-Host "=== make sure the phone is in fastboot ===" -ForegroundColor Cyan
$devs = & $fb devices 2>&1
if (-not ($devs -match 'fastboot')) {
    $d = & $adb devices 2>&1
    if ($d -match '\sdevice\s*$') {
        Write-Host "  rebooting to bootloader via adb ..."
        & $adb reboot bootloader | Out-Null
        if (-not (Wait-Fastboot 120)) { Write-Host "!! could not reach fastboot" -ForegroundColor Red; exit 1 }
    } else {
        Write-Host "!! phone not visible (not fastboot, not adb). Put it into fastboot manually and rerun." -ForegroundColor Red
        exit 1
    }
}
Write-Host "  fastboot OK" -ForegroundColor Green

foreach ($img in $images) {
    $path = Join-Path $nat $img
    if (-not (Test-Path $path)) { Write-Host "skip (missing): $img" -ForegroundColor DarkGray; continue }

    Write-Host ""
    Write-Host "=== trying $img ===" -ForegroundColor Cyan
    $t0 = Get-Date
    & $fb boot $path 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    $back = Wait-Adb 360
    $elapsed = [int]((Get-Date) - $t0).TotalSeconds
    if (-not $back) {
        Write-Host "    phone did NOT come back in 6 min (hard hang)" -ForegroundColor Yellow
        $line = "{0,-34} elapsed=--  result=NO_REPLY(hard hang)" -f $img
        $log += $line; Write-Host "    $line"
        Write-Host "    >>> power-cycle the phone (hold Power 15s) then rerun this script" -ForegroundColor Yellow
        break
    }
    Write-Host "    phone is back after $elapsed s"

    Start-Sleep -Seconds 8
    $diag = Get-CacheLog
    if ($diag) {
        Write-Host "    *** FOUND KERNEL LOG - THIS KERNEL BOOTS! ***" -ForegroundColor Green
        $log += ("{0,-34} elapsed={1}s  result=SUCCESS (log written)" -f $img, $elapsed)
        $diag | Out-File -Encoding utf8 (Join-Path $nat 'natrium-diag.txt')
        Write-Host "    log saved to natrium-diag.txt" -ForegroundColor Green
        ($diag -split "`n" | Select-Object -First 25) | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
        break
    }
    $hint = if ($elapsed -lt 90) { "died early (panic or hang before userspace)" } else { "took long but wrote no log" }
    $log += ("{0,-34} elapsed={1}s  result=FAIL ({2})" -f $img, $elapsed, $hint)
    Write-Host "    no log - $hint" -ForegroundColor Yellow

    Write-Host "    rebooting to bootloader for the next candidate ..."
    & $adb reboot bootloader | Out-Null
    if (-not (Wait-Fastboot 150)) { Write-Host "!! lost fastboot, stopping" -ForegroundColor Red; break }
}

$log += "===== sweep finished $(Get-Date) ====="
$log -join "`n" | Out-File -Encoding utf8 $report
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
$log | ForEach-Object { Write-Host "  $_" }
Write-Host ""
Write-Host "saved: $report" -ForegroundColor Green
