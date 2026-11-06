#!/bin/sh
# Tune the X/i3 desktop for a 5.7" 1080p touchscreen.
cat > /home/arch/.Xresources <<'EOF'
Xft.dpi: 260
XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 18
XTerm*internalBorder: 4
EOF

mkdir -p /home/arch/.config/i3
cat > /home/arch/.config/i3/config <<'EOF'
# i3 config for Xiaomi Mi 5s Plus (touch-first, no physical keyboard)
font pango:DejaVu Sans Bold 13

exec --no-startup-id onboard --layout=Phone
exec --no-startup-id xterm -fa 'DejaVu Sans Mono' -fs 18

floating_modifier Mod4
focus_follows_mouse no
default_orientation horizontal

bar {
    position top
    status_command i3status
    tray_output none
    font pango:DejaVu Sans 10
    height 34
}

bindsym XF86PowerOff exec systemctl poweroff

set $mod Mod4
bindsym $mod+Return exec xterm -fa 'DejaVu Sans Mono' -fs 18
bindsym $mod+Shift+q kill
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec i3-msg exit
EOF

mkdir -p /home/arch/.config/i3status
cat > /home/arch/.config/i3status/config <<'EOF'
general {
    colors = true
    interval = 3
    color_good = "#00cc66"
    color_bad  = "#cc3333"
}
order += "battery all"
order += "disk /"
order += "memory"
order += "tztime local"

battery all {
    format = "%status %percentage %remaining"
    path = "/sys/class/power_supply/qcom-battery"
    low_threshold = 15
}

disk "/" {
    format = "/ %avail"
}

memory {
    format = "RAM %used"
    threshold_degraded = "8%"
}

tztime local {
    format = "%H:%M"
}
EOF

chown -R arch:arch /home/arch/.Xresources /home/arch/.config/i3 /home/arch/.config/i3status

su - arch -c 'DISPLAY=:0 i3-msg restart' >/dev/null 2>&1
sleep 3
su - arch -c 'DISPLAY=:0 onboard --layout=Phone' >/dev/null 2>&1 &
sleep 6

echo "=== procs ==="
ps aux 2>/dev/null | grep -E 'onboard|i3$|xterm' | grep -v grep | head -6
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot2.png' 2>&1
ls -l /tmp/shot2.png 2>&1
