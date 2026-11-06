#!/bin/sh
# Auto-detect the PC's IP on the USB link and export it as a proxy for all shells.
# The PC runs natrium-port/tools/proxy.js on port 3128.
cat > /etc/profile.d/natrium-proxy.sh <<'EOF'
# natrium: the PC is the other end of the usb0 link and runs an HTTP proxy.
if [ -z "$NATRIUM_NO_PROXY" ]; then
    _peer=$(ip neigh show dev usb0 2>/dev/null | awk '/lladdr/ {print $1; exit}')
    if [ -n "$_peer" ]; then
        export http_proxy="http://$_peer:3128"
        export https_proxy="$http_proxy"
    fi
    unset _peer
fi
EOF
chmod 644 /etc/profile.d/natrium-proxy.sh

# session shells (bash) also load it
grep -q natrium-proxy /etc/profile 2>/dev/null || echo '[ -f /etc/profile.d/natrium-proxy.sh ] && . /etc/profile.d/natrium-proxy.sh' >> /etc/profile

echo "=== profile.d ==="
cat /etc/profile.d/natrium-proxy.sh
echo "=== test in a login shell ==="
sh -lc 'echo "peer-based proxy: $http_proxy"'
