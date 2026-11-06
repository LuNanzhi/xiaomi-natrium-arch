#!/bin/sh
# Stop onboard from repositioning itself (that is the "wobble": its
# prevent-occlusion logic fighting i3's fixed geometry).
su - arch -c 'DISPLAY=:0 gsettings set org.onboard.auto-show reposition-method-floating none' 2>&1
su - arch -c 'DISPLAY=:0 gsettings set org.onboard.auto-show reposition-method-docked none' 2>&1
su - arch -c 'DISPLAY=:0 gsettings set org.onboard.auto-show enabled false' 2>&1
su - arch -c 'DISPLAY=:0 gsettings set org.onboard.auto-show tablet-mode-detection-enabled false' 2>&1

pkill -f onboard 2>/dev/null
sleep 1
su - arch -c 'DISPLAY=:0 nohup onboard --layout=Phone > /tmp/onboard.log 2>&1 &' 2>/dev/null
sleep 5
su - arch -c 'DISPLAY=:0 i3-msg "[class=\"Onboard\"] floating enable, border none, move position 0 1500, resize set 1080 420"' 2>&1 | tail -1
sleep 2

echo "=== geometry now ==="
su - arch -c 'DISPLAY=:0 xwininfo -root -tree 2>/dev/null | grep -i onboard | head -3' 2>&1
echo "=== gsettings ==="
su - arch -c 'DISPLAY=:0 gsettings get org.onboard.auto-show reposition-method-floating' 2>&1
