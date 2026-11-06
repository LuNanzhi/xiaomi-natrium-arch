# Talk to the natrium Arch console over the USB CDC-ACM serial port.
#
#   powershell -ExecutionPolicy Bypass -File serial-shell.ps1 -Port COM7
#   powershell -ExecutionPolicy Bypass -File serial-shell.ps1 -Port COM7 -Cmd "systemctl status sshd"
#
# Logs in as root/arch if a login prompt is seen, then runs -Cmd and prints
# whatever comes back. ASCII only.

param(
    [Parameter(Mandatory = $true)][string]$Port,
    [string]$Cmd = 'uname -a; ip -brief addr',
    [int]$Baud = 115200,
    [string]$User = 'root',
    [string]$Pass = 'arch'
)

$ErrorActionPreference = 'Stop'
$sp = New-Object System.IO.Ports.SerialPort $Port, $Baud, 'None', 8, 'one'
$sp.NewLine = "`r"
$sp.ReadTimeout = 800
$sp.WriteTimeout = 2000
$sp.DtrEnable = $true
$sp.RtsEnable = $true

function Read-Port([int]$ms) {
    $sb = New-Object System.Text.StringBuilder
    $deadline = (Get-Date).AddMilliseconds($ms)
    while ((Get-Date) -lt $deadline) {
        try {
            $s = $sp.ReadExisting()
            if ($s) { [void]$sb.Append($s) }
            else { Start-Sleep -Milliseconds 100 }
        } catch { Start-Sleep -Milliseconds 100 }
    }
    return $sb.ToString()
}

try {
    $sp.Open()
    Start-Sleep -Milliseconds 500
    $sp.DiscardInBuffer()
    $sp.Write("`r")
    $banner = Read-Port 2500
    Write-Host "--- banner ---"
    Write-Host $banner

    if ($banner -match 'login:') {
        $sp.Write("$User`r")
        Start-Sleep -Milliseconds 1200
        $sp.Write("$Pass`r")
        Start-Sleep -Milliseconds 2500
        $after = Read-Port 1500
        Write-Host "--- login ---"
        Write-Host $after
    }

    $sp.DiscardInBuffer()
    $sp.Write("$Cmd`r")
    $result = Read-Port 4000
    Write-Host "--- output of: $Cmd ---"
    Write-Host $result
} finally {
    if ($sp.IsOpen) { $sp.Close() }
    $sp.Dispose()
}
