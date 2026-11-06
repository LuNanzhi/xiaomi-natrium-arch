#!/bin/sh
pid=$(pgrep -f "bin/onboard" | head -1)
bus=$(tr '\0' '\n' < /proc/$pid/environ 2>/dev/null | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
run_g() {
    su - arch -c "DBUS_SESSION_BUS_ADDRESS='$bus' DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1001 gsettings $1" 2>/dev/null
}

# portrait is the current orientation (1080x1920)
run_g "set org.onboard.window.portrait dock-width 1080"
run_g "set org.onboard.window.portrait dock-height 420"
run_g "set org.onboard.window.portrait dock-expand true"
run_g "set org.onboard.window.landscape dock-width 1920"
run_g "set org.onboard.window.landscape dock-height 420"
run_g "set org.onboard.window docking-edge 'bottom'"
run_g "set org.onboard.window docking-enabled true"
run_g "get org.onboard.window docking-enabled"
run_g "get org.onboard.window.portrait dock-width"

# i3: keep it floating but stop forcing geometry (onboard docks itself now)
grep -v 'move_containers' /dev/null 2>/dev/null
sed -i '/class="Onboard".*move position/d; /class="Onboard".*resize set/d' /home/arch/.config/i3/config
grep -n 'Onboard' /home/arch/.config/i3/config

pkill -f "bin/onboard" 2>/dev/null
sleep 1
su - arch -c 'DISPLAY=:0 nohup onboard --layout=Phone > /tmp/onboard.log 2>&1 &' 2>/dev/null
sleep 5
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot9.png' 2>&1
ls -l /tmp/shot9.png 2>&1
