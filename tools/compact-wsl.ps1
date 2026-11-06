# Rebuild the WSL distro VHD via export/import so the host file shrinks.
# The distro name stays "ubuntu-natrium"; content is preserved.
$ErrorActionPreference = 'Continue'
$Distro = 'ubuntu-natrium'
$OldDir = 'C:\Users\Public\wsl\import-v2'
$NewDir = 'C:\Users\Public\wsl\import-v3'
$Tar    = 'C:\Users\Public\wsl\natrium-export.tar'

function FreeGB { [math]::Round((Get-PSDrive C).Free / 1GB, 2) }

Write-Host ("=== before: C: free {0} GB ===" -f (FreeGB))
if (Test-Path (Join-Path $OldDir 'ext4.vhdx')) {
    Write-Host ("  old vhdx: {0:N2} GB" -f ((Get-Item (Join-Path $OldDir 'ext4.vhdx')).Length / 1GB))
}

Write-Host "=== 1) shutting down WSL ==="
wsl --shutdown
Start-Sleep -Seconds 8

Write-Host "=== 2) exporting to tar (this is the slow part) ==="
if (Test-Path $Tar) { Remove-Item $Tar -Force }
$t0 = Get-Date
wsl --export $Distro $Tar
Write-Host ("  export finished in {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds)
if (Test-Path $Tar) { Write-Host ("  tar: {0:N2} GB" -f ((Get-Item $Tar).Length / 1GB)) } else { Write-Host "!! export failed"; exit 1 }

Write-Host "=== 3) unregistering old distro ==="
wsl --unregister $Distro
Start-Sleep -Seconds 3

Write-Host "=== 4) importing fresh distro ==="
New-Item -ItemType Directory -Force -Path $NewDir | Out-Null
wsl --import $Distro $NewDir $Tar --version 2
Start-Sleep -Seconds 3

Write-Host "=== 5) verifying the new distro ==="
wsl -d $Distro -u root -- bash -c "df -h / | tail -1; echo '--- artifacts kept ---'; ls /root/art-6187 /root/art-6195 2>/dev/null | head -8; echo '--- toolchain ---'; aarch64-linux-gnu-gcc --version | head -1" 2>&1 | ForEach-Object { Write-Host "  $_" }

Write-Host "=== 6) deleting the old vhdx and the tar ==="
if (Test-Path $Tar) { Remove-Item $Tar -Force; Write-Host "  tar deleted" }
if (Test-Path $OldDir) { Remove-Item -Recurse -Force $OldDir; Write-Host "  old dir deleted" }
if (Test-Path (Join-Path $NewDir 'ext4.vhdx')) {
    Write-Host ("  new vhdx: {0:N2} GB" -f ((Get-Item (Join-Path $NewDir 'ext4.vhdx')).Length / 1GB))
}
Write-Host ("=== after: C: free {0} GB ===" -f (FreeGB))
