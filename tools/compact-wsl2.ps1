# Rebuild the ubuntu-natrium VHD so the host file shrinks (content preserved).
$ErrorActionPreference = 'Continue'
$Distro  = 'ubuntu-natrium'
$OldDir  = 'C:\Users\Public\wsl\import-v3'
$NewDir  = 'C:\Users\Public\wsl\import-v4'
$Tar     = 'C:\Users\Public\wsl\natrium-export2.tar'
function FreeGB { [math]::Round((Get-PSDrive C).Free / 1GB, 2) }

Write-Host ("=== before: C: free {0} GB ===" -f (FreeGB))
if (Test-Path "$OldDir\ext4.vhdx") { Write-Host ("  old vhdx: {0:N2} GB" -f ((Get-Item "$OldDir\ext4.vhdx").Length / 1GB)) }

Write-Host "=== 1) shutdown WSL ==="
wsl --shutdown
Start-Sleep -Seconds 8

Write-Host "=== 2) export ==="
if (Test-Path $Tar) { Remove-Item $Tar -Force }
$t0 = Get-Date
wsl --export $Distro $Tar
Write-Host ("  export {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds)
if (-not (Test-Path $Tar)) { Write-Host "!! export failed"; exit 1 }
Write-Host ("  tar: {0:N2} GB" -f ((Get-Item $Tar).Length / 1GB))

Write-Host "=== 3) unregister old ==="
wsl --unregister $Distro
Start-Sleep -Seconds 3

Write-Host "=== 4) import fresh ==="
New-Item -ItemType Directory -Force -Path $NewDir | Out-Null
wsl --import $Distro $NewDir $Tar --version 2
Start-Sleep -Seconds 3

Write-Host "=== 5) verify ==="
wsl -d $Distro -u root -- bash -c "df -h / | tail -1; echo '--- /root ---'; du -sh /root/* 2>/dev/null | sort -hr | head -5; echo '--- artifacts ---'; ls /root/art-6187 2>/dev/null | head -3" 2>&1 | ForEach-Object { Write-Host "  $_" }

Write-Host "=== 6) delete old vhdx + tar ==="
if (Test-Path $Tar) { Remove-Item $Tar -Force; Write-Host "  tar deleted" }
if (Test-Path $OldDir) { Remove-Item -Recurse -Force $OldDir; Write-Host "  old dir deleted" }
Write-Host ("  new vhdx: {0:N2} GB" -f ((Get-Item "$NewDir\ext4.vhdx").Length / 1GB))
Write-Host ("=== after: C: free {0} GB ===" -f (FreeGB))
