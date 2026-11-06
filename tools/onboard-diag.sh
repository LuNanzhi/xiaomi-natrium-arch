#!/bin/sh
echo "=== onboard --help (options we care about) ==="
onboard --help 2>&1 | grep -iE "docked|size|x=|y=|geometry|auto|hide|show|layout" | head -20
echo
echo "=== onboard gsettings keys ==="
su - arch -c 'DISPLAY=:0 gsettings list-recursively org.onboard 2>/dev/null | grep -iE "auto|hide|show|docked|window" | head -20'
echo
echo "=== current window geometry ==="
su - arch -c 'DISPLAY=:0 i3-msg -t get_tree' 2>/dev/null | tr ',' '\n' | grep -E '"(name|class|x|y|width|height)"' | head -40
