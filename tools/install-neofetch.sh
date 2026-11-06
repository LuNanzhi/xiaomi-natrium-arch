#!/bin/sh
. /etc/profile.d/natrium-proxy.sh
echo "proxy=$http_proxy"
pacman -S --noconfirm neofetch 2>&1 | tail -4 || true
if command -v neofetch >/dev/null 2>&1; then
    echo "--- neofetch installed ---"
else
    echo "--- neofetch not available, trying fastfetch ---"
    pacman -S --noconfirm fastfetch 2>&1 | tail -4 || true
fi
command -v neofetch fastfetch 2>/dev/null
