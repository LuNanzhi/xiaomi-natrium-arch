# Read the diagnostics that the logger image wrote into the phone cache partition.
# Usage:  powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\read-diag.ps1
# NOTE: keep this file ASCII-only - Windows PowerShell 5.1 reads .ps1 as ANSI
#       and non-ASCII characters would break parsing.

$ErrorActionPreference = 'Continue'

$adb = 'F:\platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
    $c = Get-Command adb -ErrorAction SilentlyContinue
    if ($c) { $adb = $c.Source } else { Write-Host "adb.exe not found - edit line 8 of this script" -ForegroundColor Red; exit 1 }
}
$out = 'C:\Users\Public\natrium\natrium-diag.txt'

Write-Host "=== 1) adb devices ===" -ForegroundColor Cyan
& $adb devices

Write-Host "=== 2) adb root ===" -ForegroundColor Cyan
& $adb root
Start-Sleep -Seconds 4
& $adb wait-for-device

Write-Host "=== 3) mount cache and dump log ===" -ForegroundColor Cyan
$cmd = 'mkdir -p /data/local/tmp/c; mount -t ext4 -o ro /dev/block/by-name/cache /data/local/tmp/c 2>&1; echo "--- ls /data/local/tmp/c ---"; ls -l /data/local/tmp/c 2>&1; echo "=====BEGIN====="; cat /data/local/tmp/c/natrium-diag.txt 2>&1'
$res = & $adb shell $cmd 2>&1
$res | Out-File -Encoding utf8 $out

if ($res -match 'Linux version|CACHE=|BEGIN') {
    Write-Host ""
    Write-Host "OK - saved to $out" -ForegroundColor Green
    Write-Host "--- last 25 lines ---" -ForegroundColor Cyan
    $res | Select-Object -Last 25
} else {
    Write-Host ""
    Write-Host "FAILED to find the log. Raw output:" -ForegroundColor Yellow
    $res | Select-Object -First 20
    Write-Host ""
    Write-Host "Fallback 1: enable 'Rooted debugging' in Developer options and rerun." -ForegroundColor Yellow
    Write-Host "Fallback 2: dump the whole cache partition and let the agent parse it:" -ForegroundColor Yellow
    Write-Host "  & '$adb' pull /dev/block/by-name/cache C:\Users\Public\natrium\cache.img" -ForegroundColor Yellow
}
