# Capture the phone's USB serial output while running a "stay" image.
#
# What it does:
#   1) boots boot-6.18.7-msmpmos-stay.img with `fastboot boot`
#   2) waits for a NEW COM port to appear (the phone's ACM gadget)
#   3) opens it and captures up to ~2 minutes of output into natrium-serial.txt
#
# The 'stay' image re-sends its whole report every 30 s, so even if the port is
# opened late we still receive the full report.
#
# Usage: put the phone into fastboot, then:
#   powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\serial-capture.ps1
# ASCII-only on purpose (Windows PowerShell 5.1 parses .ps1 as ANSI).

param([string]$Image = '')

$ErrorActionPreference = 'Continue'
$nat = 'C:\Users\Public\natrium'
$adb = 'F:\platform-tools\adb.exe'
$fb  = 'F:\platform-tools\fastboot.exe'
if (-not (Test-Path $adb)) { $c = Get-Command adb -ErrorAction SilentlyContinue; if ($c) { $adb = $c.Source } }
if (-not (Test-Path $fb))  { $c = Get-Command fastboot -ErrorAction SilentlyContinue; if ($c) { $fb = $c.Source } }
if (-not $Image) { $Image = Join-Path $nat 'boot-6.18.7-msmpmos-stay.img' }
$out = Join-Path $nat 'natrium-serial.txt'

Write-Host "=== 0) image ===" -ForegroundColor Cyan
if (-not (Test-Path $Image)) { Write-Host "MISSING: $Image" -ForegroundColor Red; exit 1 }
Write-Host "  $Image"
Write-Host ("  sha256 {0}" -f (Get-FileHash $Image -Algorithm SHA256).Hash)

$before = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
Write-Host ("=== 1) COM ports before: {0} ===" -f ($before -join ', ')) -ForegroundColor Cyan

$devs = & $fb devices 2>&1
if (-not ($devs -match 'fastboot')) {
    $d = & $adb devices 2>&1
    if ($d -match '\sdevice\s*$') {
        Write-Host "  rebooting to bootloader via adb ..."
        & $adb reboot bootloader | Out-Null
    } else {
        Write-Host "!! phone is not in fastboot and not reachable via adb. Enter fastboot manually and rerun." -ForegroundColor Red
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

Write-Host "=== 2) booting the stay image ===" -ForegroundColor Cyan
& $fb boot $Image 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

Write-Host "=== 3) waiting for a NEW COM port (up to 5 min) ===" -ForegroundColor Cyan
$newPort = $null
$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 5
    $now = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
    $diff = $now | Where-Object { $before -notcontains $_ }
    if ($diff) { $newPort = $diff[0]; break }
    Write-Host ("    ... still waiting ({0:HH:mm:ss}), ports: {1}" -f (Get-Date), ($now -join ',')) -ForegroundColor DarkGray
}

if (-not $newPort) {
    Write-Host ""
    Write-Host "No new COM port appeared - the USB gadget did not enumerate." -ForegroundColor Yellow
    Write-Host "That itself is information: the kernel either did not reach our init, or USB didn't come up." -ForegroundColor Yellow
    Write-Host "Try the logger image + get-diag.ps1 instead, or power-cycle and retry." -ForegroundColor Yellow
    exit 1
}

Write-Host "  new port: $newPort" -ForegroundColor Green
Write-Host "=== 4) capturing up to 150 seconds ===" -ForegroundColor Cyan
$sp = New-Object System.IO.Ports.SerialPort $newPort, 115200, 'None', 8, 'One'
$sp.ReadTimeout = 3000
$sp.NewLine = "`n"
$captured = New-Object System.Text.StringBuilder
try {
    $sp.Open()
    $end = (Get-Date).AddSeconds(150)
    while ((Get-Date) -lt $end) {
        try {
            $chunk = $sp.ReadExisting()
            if ($chunk.Length -gt 0) {
                [void]$captured.Append($chunk)
                Write-Host $chunk -NoNewline -ForegroundColor DarkGray
                if ($captured.ToString() -match 'REPORT END' -and $captured.ToString() -match 'dmesg') {
                    Write-Host ""
                    Write-Host "  (full report captured)" -ForegroundColor Green
                    break
                }
            } else {
                Start-Sleep -Milliseconds 300
            }
        } catch [TimeoutException] { }
    }
} catch {
    Write-Host "serial error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($sp.IsOpen) { $sp.Close() }
}

$text = $captured.ToString()
$text | Out-File -Encoding utf8 $out
if ($text.Length -gt 200) {
    Write-Host ""
    Write-Host ("OK - captured {0} chars -> {1}" -f $text.Length, $out) -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Captured almost nothing - gadget enumerated but no output arrived." -ForegroundColor Yellow
    Write-Host "Power-cycle the phone (hold Power 15s) and retry." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "NOTE: the phone is still running the stay image - power-cycle it (hold Power 15s) afterwards." -ForegroundColor Cyan
