# Collect bootloader-level facts from LineageOS. No fastboot, no risk.
# Usage: powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\collect-abl-info.ps1
# ASCII-only on purpose (Windows PowerShell 5.1 parses .ps1 as ANSI).

$ErrorActionPreference = 'Continue'
$adb = 'F:\platform-tools\adb.exe'
if (-not (Test-Path $adb)) { $c = Get-Command adb -ErrorAction SilentlyContinue; if ($c) { $adb = $c.Source } else { Write-Host "adb not found"; exit 1 } }
$out = 'C:\Users\Public\natrium\abl-info.txt'

& $adb root | Out-Null
Start-Sleep -Seconds 4
& $adb wait-for-device

function Sh($cmd) { (& $adb shell $cmd 2>&1) -join "`n" }

$report = @()
$report += "===== 1) cmdline the ABL passes to the kernel ====="
$report += Sh "cat /proc/cmdline"

$report += ""
$report += "===== 2) msm-id / board-id / pmic-id actually passed in ====="
foreach ($p in @('qcom,msm-id','qcom,board-id','qcom,pmic-id','model','compatible','chassis-type')) {
    $v = Sh "od -An -tx4 /proc/device-tree/$p 2>/dev/null | tr -s ' '"
    if ($v.Trim()) { $report += ("  {0,-18} = {1}" -f $p, $v.Trim()) }
}
$report += ("  model(string)      = " + (Sh "cat /proc/device-tree/model 2>/dev/null"))

$report += ""
$report += "===== 3) full partition list ====="
$parts = Sh "ls /dev/block/by-name/"
$report += $parts

$report += ""
$report += "===== 4) candidate bootloader log partitions ====="
foreach ($cand in @('logfs','rdimage','crash','misc','dip','mdtp','ssd','toolsfv','fsg','devinfo','oem','aboot','xbl')) {
    if ($parts -match "(?m)\b$cand\b") {
        $sz = Sh "blockdev --getsize64 /dev/block/by-name/$cand 2>/dev/null"
        $report += ("  {0,-10} present, size = {1} bytes" -f $cand, $sz.Trim())
    }
}

$report += ""
$report += "===== 5) device props ====="
$report += Sh "getprop ro.boot.hwversion; getprop ro.boot.verifiedbootstate; getprop ro.boot.veritymode; getprop ro.boot.secureboot; getprop ro.boot.serialno; getprop ro.boot.bootdevice"

$report -join "`n" | Out-File -Encoding utf8 $out
Write-Host "saved: $out" -ForegroundColor Green
Get-Content $out

Write-Host ""
Write-Host "=== 6) dump candidate log partitions and grep readable text ===" -ForegroundColor Cyan
foreach ($cand in @('logfs','rdimage','crash','mdtp','toolsfv','misc')) {
    if ($parts -match "(?m)\b$cand\b") {
        Write-Host "  dumping $cand ..."
        & $adb shell "dd if=/dev/block/by-name/$cand of=/data/local/tmp/$cand.bin bs=1M 2>/dev/null"
        & $adb shell "chmod 644 /data/local/tmp/$cand.bin 2>/dev/null"
        $local = "C:\Users\Public\natrium\$cand.bin"
        & $adb pull "/data/local/tmp/$cand.bin" $local | Out-Null
        & $adb shell "rm -f /data/local/tmp/$cand.bin"
        if (Test-Path $local) {
            $len = (Get-Item $local).Length
            Write-Host ("    {0}: {1:N1} MB" -f $cand, ($len / 1MB))
            if ($len -lt 120MB) {
                $bytes = [IO.File]::ReadAllBytes($local)
                $txt = [Text.Encoding]::ASCII.GetString($bytes)
                $hits = [regex]::Matches($txt, '[\x20-\x7E]{10,}') | ForEach-Object { $_.Value } |
                        Where-Object { $_ -match 'boot|kernel|dtb|image|sign|verif|error|fail|panic|msm-id|board-id|aboot|xbl|Load|secure|slot' } |
                        Select-Object -First 80
                if ($hits) {
                    $hits | Out-File -Encoding utf8 "C:\Users\Public\natrium\$cand-strings.txt"
                    Write-Host "    -> found $(($hits | Measure-Object).Count) suspicious strings, saved to $cand-strings.txt"
                    $hits | Select-Object -First 20 | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
                } else {
                    Write-Host "    -> no readable text found"
                }
            }
        }
    }
}
Write-Host ""
Write-Host "DONE - the agent can read abl-info.txt directly" -ForegroundColor Green
