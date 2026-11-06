#!/bin/sh
. /etc/profile.d/natrium-proxy.sh
echo "proxy=$http_proxy"
echo "=== neofetch ==="
su - arch -c "neofetch --stdout" 2>&1 | head -32
