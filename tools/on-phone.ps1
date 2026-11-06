param(
    [Parameter(Mandatory = $true)][string]$Script,
    [string]$Remote = 'sh /root/_x.sh',
    [string]$SshHost = 'root@172.16.42.1'
)
# Upload a local shell script to the phone and run it.
# Accepts a Windows path (C:\...) or an already-WSL path (/mnt/c/...).

if ($Script -match '^[A-Za-z]:') {
    $p = $Script -replace '\\', '/'
    $local = '/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2)
} else {
    $local = $Script
}

$ssh = "sshpass -p arch ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 $SshHost"
$cmd = "$ssh 'cat > /root/_x.sh' < '$local' && $ssh '$Remote' 2>&1"
wsl -d ubuntu-natrium -e bash -c $cmd
