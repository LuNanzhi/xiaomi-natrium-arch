#!/bin/sh
# 1080px wide, need ~72+ columns for neofetch: use font size 10
sed -i "s/-fs 12/-fs 10/g" /home/arch/.config/i3/config
sed -i 's/XTerm\*faceSize: 12/XTerm*faceSize: 10/' /home/arch/.Xresources
chown -R arch:arch /home/arch/.Xresources /home/arch/.config/i3

pkill -f xterm 2>/dev/null
sleep 1
su - arch -c 'DISPLAY=:0 LANG=en_US.UTF-8 xterm -fa "DejaVu Sans Mono" -fs 10 -bg black -fg white -e "bash -lc \"neofetch; exec bash\""' >/dev/null 2>&1 &
sleep 6
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot14.png' 2>&1
# report the column count of that terminal for the record
su - arch -c 'DISPLAY=:0 xterm -fa "DejaVu Sans Mono" -fs 10 -e "sh -c \"tput cols; sleep 1\""' 2>/dev/null
