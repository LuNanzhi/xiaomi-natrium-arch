#!/bin/sh
export http_proxy=http://172.16.42.102:3128
export https_proxy=$http_proxy
command -v xvkbd >/dev/null 2>&1 || pacman -S --noconfirm xvkbd 2>&1 | tail -2

# give the X session a session bus as well (GTK apps / future onboard)
cat > /home/arch/.xinitrc <<'EOF'
#!/bin/sh
export XDG_RUNTIME_DIR=/run/user/1001
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
xset s off
xset -dpms
xset s noblank
exec dbus-run-session -- i3
EOF
chmod 755 /home/arch/.xinitrc
chown arch:arch /home/arch/.xinitrc

# swap onboard for xvkbd in the i3 config
sed -i 's|exec --no-startup-id onboard --layout=Phone|exec --no-startup-id xvkbd -geometry 1080x420+0+1500 -modifier|' /home/arch/.config/i3/config
grep -n "xvkbd" /home/arch/.config/i3/config

pkill -f xvkbd 2>/dev/null
su - arch -c 'DISPLAY=:0 nohup xvkbd -geometry 1080x420+0+1500 -modifier > /tmp/xvkbd.log 2>&1 &' 2>/dev/null
sleep 4
echo "=== xvkbd ==="
pgrep -a xvkbd | head -2
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot4.png' 2>&1
ls -l /tmp/shot4.png 2>&1
