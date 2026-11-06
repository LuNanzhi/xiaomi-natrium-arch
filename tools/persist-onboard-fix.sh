#!/bin/sh
# Session script: runs inside dbus-run-session, so gsettings/dconf work.
cat > /home/arch/.xsession <<'EOF'
#!/bin/sh
# onboard: never reposition itself (that is what made the keyboard wobble)
gsettings set org.onboard.auto-show reposition-method-floating none 2>/dev/null
gsettings set org.onboard.auto-show reposition-method-docked none 2>/dev/null
gsettings set org.onboard.auto-show enabled false 2>/dev/null
gsettings set org.onboard.auto-show tablet-mode-detection-enabled false 2>/dev/null
exec i3
EOF
chmod 755 /home/arch/.xsession
chown arch:arch /home/arch/.xsession

cat > /home/arch/.xinitrc <<'EOF'
#!/bin/sh
export XDG_RUNTIME_DIR=/run/user/1001
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
xset s off
xset -dpms
xset s noblank
exec dbus-run-session -- "$HOME/.xsession"
EOF
chmod 755 /home/arch/.xinitrc
chown arch:arch /home/arch/.xinitrc

# restart the X session so the new scripts run
su - arch -c 'DISPLAY=:0 i3-msg exit' >/dev/null 2>&1
sleep 14

echo "=== procs ==="
ps aux 2>/dev/null | grep -E "Xorg|/i3$|onboard" | grep -v grep | head -5
echo "=== reposition setting ==="
grep -n "reposition" /home/arch/.xsession
echo "=== screenshot ==="
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot8.png' 2>&1
ls -l /tmp/shot8.png 2>&1
