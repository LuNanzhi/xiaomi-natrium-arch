#!/bin/sh
# Dock onboard at the bottom of the 1080x1920 screen via i3 window rules.
cat > /tmp/i3rules.tmp <<'EOF'

# --- on-screen keyboard: always float at the bottom, full width ---
for_window [class="Onboard"] floating enable
for_window [class="Onboard"] border none
for_window [class="Onboard"] move position 0 1500
for_window [class="Onboard"] resize set 1080 420
EOF
cat /tmp/i3rules.tmp >> /home/arch/.config/i3/config
chown arch:arch /home/arch/.config/i3/config

# apply to the already-running keyboard without restarting X
su - arch -c 'DISPLAY=:0 i3-msg "[class=\"Onboard\"] floating enable, border none, move position 0 1500, resize set 1080 420"' 2>&1 | tail -2
sleep 2

# make the terminal not hide behind the keyboard: let i3 handle it, then screenshot
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot7.png' 2>&1
ls -l /tmp/shot7.png 2>&1
