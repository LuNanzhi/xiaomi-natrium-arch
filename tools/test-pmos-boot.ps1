# Zero-risk test of the official postmarketOS boot image built by pmbootstrap.
#
# `fastboot boot` loads it into RAM only - nothing is written to any partition.
# A pmOS boot.img brings up USB networking (RNDIS/CDC) and telnetd in its
# initramfs, so a *new network adapter* appearing on the PC is a positive signal
# that the kernel actually reached userspace.
#
# Usage: put the phone into fastboot, then
#   powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\test-pmos-boot.ps1
# ASCII-only on purpose.

param([string]$Image = '')

$ErrorActionPreference = 'Continue'
$nat = 'C:\Users\Public\natrium'
$pmos = Join-Path $nat 'pmos'
$adb = 'F:\platform-tools\adb.exe'
$fb  = 'F:\platform-tools\fastboot.exe'
if (-not (Test-Path $adb)) { $c = Get-Command adb -ErrorAction SilentlyContinue; if ($c) { $adb = $c.Source } }
if (-not (Test-Path $fb))  { $c = Get-Command fastboot -ErrorAction SilentlyContinue; if ($c) { $fb = $c.Source } }

if (-not $Image) {
    $cand = Get-ChildItem $pmos -Filter '*.img' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch 'root|userdata' } |
            Sort-Object Length -Descending | Select-Object -First 1
    if ($cand) { $Image = $cand.FullName }
}
Write-Host "=== 0) image ===" -ForegroundColor Cyan
if (-not $Image -or -not (Test-Path $Image)) {
    Write-Host "no pmOS boot image found in $pmos" -ForegroundColor Red
    Write-Host "wait for the pmbootstrap install to finish and export, then rerun." -ForegroundColor Yellow
    exit 1
}
Write-Host "  $Image"
Write-Host ("  size {0:N1} MB  sha256 {1}" -f ((Get-Item $Image).Length / 1MB), (Get-FileHash $Image -Algorithm SHA256).Hash)

$adaptersBefore = (Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) | Sort-Object
$portsBefore = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
Write-Host ("=== 1) adapters before: {0} ===" -f ($adaptersBefore -join ', ')) -ForegroundColor DarkGray

$devs = & $fb devices 2>&1
if (-not ($devs -match 'fastboot')) {
    $d = & $adb devices 2>&1
    if ($d -match '\sdevice\s*$') {
        Write-Host "  rebooting to bootloader via adb ..."
        & $adb reboot bootloader | Out-Null
    } else {
        Write-Host "!! phone is not in fastboot and not reachable via adb." -ForegroundColor Red
        exit 1
    }
}
$deadline = (Get-Date).AddSeconds(150)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    $devs = & $fb devices 2>&1
    if ($devs -match 'fastboot') { break }
}
if (-not ($devs -match 'fastboot')) { Write-Host "!! no fastboot device" -ForegroundColor Red; exit 1 }
Write-Host "  fastboot OK" -ForegroundColor Green

Write-Host "=== 2) fastboot boot (RAM only, nothing is written) ===" -ForegroundColor Cyan
$t0 = Get-Date
& $fb boot $Image 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

Write-Host "=== 3) watching for 4 minutes: new network adapter / new COM port / phone returning ===" -ForegroundColor Cyan
$found = $false
while (((Get-Date) - $t0).TotalMinutes -lt 4) {
    Start-Sleep -Seconds 5
    $now = (Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) | Sort-Object
    $newAd = $now | Where-Object { $adaptersBefore -notcontains $_ }
    $nowPorts = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
    $newPort = $nowPorts | Where-Object { $portsBefore -notcontains $_ }
    $d = & $adb devices 2>&1
    $adbUp = ($d -match '\sdevice\s*$')
    $fbUp = ((& $fb devices 2>&1) -match 'fastboot')
    $el = [int]((Get-Date) - $t0).TotalSeconds
    Write-Host ("    {0,3}s  new-adapter:{1}  new-com:{2}  adb:{3}  fastboot:{4}" -f $el,
                ($(if ($newAd) { $newAd -join ',' } else { '-' })),
                ($(if ($newPort) { $newPort -join ',' } else { '-' })),
                $adbUp, $fbUp) -ForegroundColor DarkGray
    if ($newAd -or $newPort) {
        Write-Host ""
        Write-Host "*** POSITIVE SIGNAL: the phone brought up USB networking/serial ***" -ForegroundColor Green
        Write-Host "    => the kernel reached userspace!" -ForegroundColor Green
        $found = $true
        break
    }
    if ($adbUp -and $el -gt 60) {
        Write-Host ""
        Write-Host "    phone is running Android again (LineageOS) - the image did not take over" -ForegroundColor Yellow
        break
    }
}
if (-not $found) {
    Write-Host ""
    Write-Host "No USB activity from the phone." -ForegroundColor Yellow
    Write-Host "Power-cycle it (hold Power 15s) and check the device state." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "NOTE: nothing was written to any partition." -ForegroundColor Cyan
