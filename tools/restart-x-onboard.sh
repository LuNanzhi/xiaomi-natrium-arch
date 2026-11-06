#!/bin/sh
export http_proxy=http://172.16.42.102:3128
export https_proxy=$http_proxy
command -v at-spi-bus-launcher >/dev/null 2>&1 || pacman -S --noconfirm at-spi2-core 2>&1 | tail -2

# i3 config: onboard instead of xvkbd
sed -i 's|exec --no-startup-id xvkbd.*|exec --no-startup-id onboard --layout=Phone|' /home/arch/.config/i3/config
grep -n "onboard" /home/arch/.config/i3/config

# restart the X session so it runs under dbus-run-session
su - arch -c 'DISPLAY=:0 i3-msg exit' >/dev/null 2>&1
sleep 12

echo "=== X back? ==="
ps aux 2>/dev/null | grep -E "Xorg|/i3$|i3bar" | grep -v grep | head -4
echo "=== onboard ==="
pgrep -a onboard | head -2
echo "=== session bus ==="
su - arch -c 'DISPLAY=:0 env | grep -c DBUS_SESSION_BUS_ADDRESS' 2>&1
