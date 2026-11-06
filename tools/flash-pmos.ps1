# Flash the postmarketOS line-flash package for xiaomi-natrium (Mi 5s Plus).
#
#   boot   -> boot partition      (NOT destructive, can be swapped any time)
#   rootfs -> userdata partition  (DESTRUCTIVE: erases all Android data)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\flash-pmos.ps1 -Rootfs
#   powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\flash-pmos.ps1 -Rootfs -BootSharp
#
# Typing WIPE at the prompt is required before anything destructive happens.
# ASCII-only on purpose.

param(
    [switch]$Rootfs,        # flash the pmOS rootfs to userdata (DESTRUCTIVE)
    [switch]$BootSharp,     # flash the Sharp-panel-patched boot image instead of stock
    [string]$BootImage = '',
    [string]$RootfsImage = ''
)

$ErrorActionPreference = 'Continue'
$nat = 'C:\Users\Public\natrium'
$pkg = Join-Path $nat 'pmos'
$fb  = 'F:\platform-tools\fastboot.exe'
if (-not (Test-Path $fb)) { $c = Get-Command fastboot -ErrorAction SilentlyContinue; if ($c) { $fb = $c.Source } }

Write-Host "=== 0) package contents ===" -ForegroundColor Cyan
Get-ChildItem $pkg -File -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host ("  {0,-34} {1,8:N1} MB" -f $_.Name, ($_.Length / 1MB))
}

function Pick-Image([string]$explicit, [string[]]$patterns) {
    if ($explicit -and (Test-Path $explicit)) { return $explicit }
    foreach ($p in $patterns) {
        $f = Get-ChildItem $pkg -Filter $p -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}

if (-not $BootImage) {
    if ($BootSharp) { $BootImage = Pick-Image '' @('boot-sharp*.img', '*sharp*boot*.img') }
    if (-not $BootImage) { $BootImage = Pick-Image '' @('boot.img', 'boot-*.img') }
}
if (-not $RootfsImage) {
    $RootfsImage = Pick-Image '' @('*root*.img', 'natrium.img', 'userdata*.img', '*.img')
}

Write-Host ""
Write-Host "=== 1) what will be flashed ===" -ForegroundColor Cyan
Write-Host ("  boot   <- {0}" -f ($(if ($BootImage) { $BootImage } else { '(not found!)' })))
if ($Rootfs) { Write-Host ("  userdata <- {0}" -f ($(if ($RootfsImage) { $RootfsImage } else { '(not found!)' }))) -ForegroundColor Yellow }
if (-not $BootImage) { Write-Host "!! boot image not found in $pkg" -ForegroundColor Red; exit 1 }

$devs = & $fb devices 2>&1
if (-not ($devs -match 'fastboot')) {
    Write-Host "!! phone is not in fastboot. Power off, then hold Power + Volume Down." -ForegroundColor Red
    Write-Host "   (current fastboot output: $devs)"
    exit 1
}
Write-Host "  fastboot device OK" -ForegroundColor Green

if ($Rootfs) {
    Write-Host ""
    Write-Host "*** WARNING: this ERASES the userdata partition (all Android photos/apps/data) ***" -ForegroundColor Red
    Write-Host "*** The 'lineage-boot-rollback.img' can only restore the boot partition.            ***" -ForegroundColor Red
    $ans = Read-Host "Type WIPE to continue, anything else to abort"
    if ($ans -ne 'WIPE') { Write-Host "aborted - nothing was written" -ForegroundColor Yellow; exit 0 }
}

Write-Host ""
Write-Host "=== 2) flashing boot ===" -ForegroundColor Cyan
& $fb flash boot $BootImage
Write-Host ""

if ($Rootfs) {
    if (-not $RootfsImage) { Write-Host "!! rootfs image not found" -ForegroundColor Red; exit 1 }
    Write-Host "=== 3) flashing userdata (pmOS rootfs, this takes a while) ===" -ForegroundColor Cyan
    & $fb flash userdata $RootfsImage
    Write-Host ""
}

Write-Host "=== 4) done ===" -ForegroundColor Green
Write-Host "First boot may take a few minutes (systemd + first-boot setup)."
Write-Host ""
Write-Host "If the screen stays black, the panel patch is not active (Sharp panel)." -ForegroundColor Yellow
Write-Host "You can still reach the system over USB networking:" -ForegroundColor Yellow
Write-Host "  - a new network adapter appears on the PC (pmOS default 172.16.42.1)" -ForegroundColor Yellow
Write-Host "  - then:  ssh user@172.16.42.1   (password: 1234)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Roll back the boot partition anytime with:" -ForegroundColor Cyan
Write-Host "  fastboot flash boot C:\Users\Public\natrium\lineage-boot-rollback.img" -ForegroundColor Cyan
Write-Host "(note: after flashing the pmOS rootfs, Android would need a full reinstall)"
