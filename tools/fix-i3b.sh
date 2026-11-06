#!/bin/sh
# Fix i3status battery path, restart xterm with big font, start onboard.
cat > /home/arch/.config/i3status/config <<'EOF'
general {
    colors = true
    interval = 3
    color_good = "#00cc66"
    color_bad  = "#cc3333"
}
order += "disk /"
order += "memory"
order += "tztime local"

disk "/" {
    format = "/ %avail"
}

memory {
    format = "RAM %used"
}

tztime local {
    format = "%H:%M"
}
EOF
chown -R arch:arch /home/arch/.config/i3status

# restart i3 so i3bar re-reads the status config
su - arch -c 'DISPLAY=:0 i3-msg restart' >/dev/null 2>&1
sleep 2

# replace the old small xterm with a big one
pkill -f "xterm" 2>/dev/null
sleep 1
su - arch -c 'DISPLAY=:0 xterm -fa "DejaVu Sans Mono" -fs 20 -bg black -fg white' >/dev/null 2>&1 &
sleep 3

# on-screen keyboard
su - arch -c 'DISPLAY=:0 nohup onboard --layout=Phone > /tmp/onboard.log 2>&1 &' 2>/dev/null
sleep 6
echo "=== onboard ==="
pgrep -a onboard | head -3
tail -5 /tmp/onboard.log 2>/dev/null
echo "=== procs ==="
ps aux 2>/dev/null | grep -E "xterm|i3bar" | grep -v grep | head -4
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot3.png' 2>&1
ls -l /tmp/shot3.png 2>&1
