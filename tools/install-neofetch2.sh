#!/bin/sh
. /etc/profile.d/natrium-proxy.sh
echo "proxy=$http_proxy"
for url in \
    "https://cdn.jsdelivr.net/gh/dylanaraps/neofetch/neofetch" \
    "https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch" \
    "https://ghproxy.net/https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch"
do
    echo "trying $url"
    if curl -fsSL --max-time 25 "$url" -o /usr/local/bin/neofetch; then
        if head -1 /usr/local/bin/neofetch | grep -q '^#!'; then
            chmod 755 /usr/local/bin/neofetch
            echo "OK: $(wc -l < /usr/local/bin/neofetch) lines"
            break
        fi
    fi
    rm -f /usr/local/bin/neofetch
done
command -v neofetch fastfetch 2>/dev/null
