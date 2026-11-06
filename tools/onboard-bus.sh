#!/bin/sh
# Get the session bus from the running onboard process, then really apply settings.
pid=$(pgrep -f "bin/onboard" | head -1)
echo "onboard pid=$pid"
bus=$(tr '\0' '\n' < /proc/$pid/environ 2>/dev/null | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
echo "bus=$bus"
[ -n "$bus" ] || { echo "no bus found"; exit 1; }

export DBUS_SESSION_BUS_ADDRESS="$bus"
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1001

# these need to run as the user that owns the session
set -- "$bus"
su - arch -c "DBUS_SESSION_BUS_ADDRESS='$bus' DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1001 gsettings get org.onboard.auto-show reposition-method-floating"
su - arch -c "DBUS_SESSION_BUS_ADDRESS='$bus' DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1001 gsettings set org.onboard.auto-show reposition-method-floating none"
su - arch -c "DBUS_SESSION_BUS_ADDRESS='$bus' DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1001 gsettings set org.onboard.auto-show reposition-method-docked none"
su - arch -c "DBUS_SESSION_BUS_ADDRESS='$bus' DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1001 gsettings get org.onboard.auto-show reposition-method-floating"

# now place it at the bottom
su - arch -c 'DISPLAY=:0 i3-msg "[class=\"Onboard\"] floating enable, border none, move position 0 1500, resize set 1080 420"' 2>&1 | tail -1
sleep 3
su - arch -c 'DISPLAY=:0 xwininfo -root -tree 2>/dev/null' | grep -i -A2 onboard | head -6
