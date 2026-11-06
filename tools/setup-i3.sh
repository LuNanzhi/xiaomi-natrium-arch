#!/bin/sh
# Configure Xorg + i3 + onboard for the phone, with tty1 autologin -> startx.
set -e

mkdir -p /home/arch

cat > /home/arch/.xinitrc <<'EOF'
#!/bin/sh
export XDG_RUNTIME_DIR=/run/user/1001
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
xset s off
xset -dpms
xset s noblank
exec i3
EOF
chmod 755 /home/arch/.xinitrc

cat > /home/arch/.Xresources <<'EOF'
Xft.dpi: 200
XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 12
EOF

mkdir -p /home/arch/.config/i3
cat > /home/arch/.config/i3/config <<'EOF'
# i3 config for Xiaomi Mi 5s Plus (touch-first, no physical keyboard)
font pango:DejaVu Sans 10

# on-screen keyboard: always available, follows focus
exec --no-startup-id onboard --layout=Phone --enable-background-transparency
# something to look at on first boot
exec --no-startup-id xterm -fa 'DejaVu Sans Mono' -fs 11

# touch: tap = click, no need for modifiers
floating_modifier Mod4
focus_follows_mouse no

# window behaviour on a small screen
default_orientation horizontal
workspace_layout tabbed
new_window pixel 1
new_float pixel 40

bar {
    position top
    status_command i3status
    tray_output none
    font pango:DejaVu Sans 8
}

# hardware buttons
bindsym XF86PowerOff exec systemctl poweroff
bindsym XF86AudioRaiseVolume exec amixer -q sset Master 5%+
bindsym XF86AudioLowerVolume exec amixer -q sset Master 5%-

# no keyboard, but keep sane defaults for an OTG one
set $mod Mod4
bindsym $mod+Return exec xterm
bindsym $mod+Shift+q kill
bindsym $mod+Shift+r restart
EOF
chown -R arch:arch /home/arch/.xinitrc /home/arch/.Xresources /home/arch/.config

cat > /home/arch/.bash_profile <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx -- -keeptty
fi
EOF
chown arch:arch /home/arch/.bash_profile

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin arch --noclear %I $TERM
Type=idle
EOF

systemctl daemon-reload
systemctl reset-failed getty@tty1.service 2>/dev/null
systemctl restart getty@tty1.service
sleep 15

echo "=== X / i3 procs ==="
ps aux 2>/dev/null | grep -E 'Xorg|i3|onboard' | grep -v grep
echo "=== X log tail ==="
tail -15 /home/arch/.local/share/xorg/Xorg.0.log 2>/dev/null || tail -15 /var/log/Xorg.0.log 2>/dev/null
