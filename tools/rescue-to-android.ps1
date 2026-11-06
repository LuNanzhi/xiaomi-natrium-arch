# Put xiaomi-natrium (Mi 5s Plus) back to a bootable LineageOS.
#
# What it does:
#   1. flashes the ORIGINAL boot image back to the boot partition
#   2. wipes userdata / cache / metadata  (the pmOS rootfs lives in userdata)
#   3. reboots
#
# It does NOT touch system / vendor / modem / persist.
# Android data on userdata is lost - that is unavoidable after flashing pmOS there.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File rescue-to-android.ps1
#   powershell -ExecutionPolicy Bypass -File rescue-to-android.ps1 -NoWipe    # boot only
#
# ASCII only on purpose.

param(
    [switch]$NoWipe,
    [string]$BootImage = 'C:\Users\Public\natrium\lineage-boot-rollback.img',
    [string]$Fastboot = ''
)

$ErrorActionPreference = 'Continue'
$fb = $Fastboot
if (-not $fb) {
    $c = Get-Command fastboot -ErrorAction SilentlyContinue
    if ($c) { $fb = $c.Source }
    elseif (Test-Path 'F:\platform-tools\fastboot.exe') { $fb = 'F:\platform-tools\fastboot.exe' }
}
if (-not $fb) { Write-Host "!! fastboot.exe not found" -ForegroundColor Red; exit 1 }

Write-Host "=== 0) assets ===" -ForegroundColor Cyan
Write-Host ("  boot image : {0} ({1:N1} MB)" -f $BootImage, ((Get-Item $BootImage).Length / 1MB))
if (-not (Test-Path $BootImage)) { Write-Host "!! boot image missing" -ForegroundColor Red; exit 1 }
$sha = (Get-FileHash $BootImage -Algorithm SHA256).Hash
Write-Host "  sha256     : $sha"

Write-Host ""
Write-Host "=== 1) device ===" -ForegroundColor Cyan
$devs = & $fb devices 2>&1 | Out-String
Write-Host ("  " + ($devs.Trim() -replace "`r?`n", "`n  "))
if (-not ($devs -match 'fastboot')) {
    Write-Host "!! not in fastboot. Hold Power 15 s, then Volume-Down + Power." -ForegroundColor Red
    exit 1
}

if (-not $NoWipe) {
    Write-Host ""
    Write-Host "*** userdata / cache / metadata will be ERASED ***" -ForegroundColor Red
    $a = Read-Host "Type RESCUE to continue"
    if ($a -ne 'RESCUE') { Write-Host "aborted" -ForegroundColor Yellow; exit 0 }
}

Write-Host ""
Write-Host "=== 2) flashing original boot ===" -ForegroundColor Cyan
& $fb flash boot $BootImage
if ($LASTEXITCODE -ne 0) { Write-Host "!! flash boot failed" -ForegroundColor Red; exit 1 }

if (-not $NoWipe) {
    Write-Host ""
    Write-Host "=== 3) wiping user data ===" -ForegroundColor Cyan
    & $fb -w 2>&1 | Write-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  'fastboot -w' failed, erasing partitions individually" -ForegroundColor Yellow
        foreach ($p in @('userdata', 'cache', 'metadata')) {
            & $fb erase $p 2>&1 | Write-Host
        }
    }
}

Write-Host ""
Write-Host "=== 4) reboot ===" -ForegroundColor Cyan
& $fb reboot 2>&1 | Write-Host

Write-Host ""
Write-Host "First boot of LineageOS can take 5-10 minutes (it rebuilds /data)." -ForegroundColor Green
Write-Host "If it still does not boot, you need the full fastboot ROM + MiFlash." -ForegroundColor Yellow
