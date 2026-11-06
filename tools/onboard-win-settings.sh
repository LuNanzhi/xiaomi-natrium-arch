#!/bin/sh
pid=$(pgrep -f "bin/onboard" | head -1)
bus=$(tr '\0' '\n' < /proc/$pid/environ 2>/dev/null | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
G="env DBUS_SESSION_BUS_ADDRESS=$bus DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1001 gsettings"

echo "=== window settings ==="
su - arch -c "$G list-recursively org.onboard.window" 2>/dev/null | grep -iE "docking|position|width|height|landscape|portrait" | head -20
