#!/bin/sh
# 1) proper UTF-8 locale
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null
grep -q '^en_US.UTF-8' /etc/locale.gen 2>/dev/null || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen 2>&1 | tail -2
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'LC_ALL=en_US.UTF-8' >> /etc/locale.conf
cat /etc/locale.conf

# 2) smaller terminal font so 80 columns fit on 1080px
sed -i "s/-fs 20/-fs 12/g; s/-fs 18/-fs 12/g" /home/arch/.config/i3/config
sed -i 's/XTerm\*faceSize: 18/XTerm*faceSize: 12/; s/XTerm\*faceSize: 20/XTerm*faceSize: 12/' /home/arch/.Xresources
grep -n "xterm" /home/arch/.config/i3/config
cat /home/arch/.Xresources
chown -R arch:arch /home/arch/.Xresources /home/arch/.config/i3

# 3) replace the running xterm with a correctly sized one
pkill -f xterm 2>/dev/null
sleep 1
su - arch -c 'DISPLAY=:0 LANG=en_US.UTF-8 xterm -fa "DejaVu Sans Mono" -fs 12 -bg black -fg white -e "bash -lc \"neofetch; exec bash\""' >/dev/null 2>&1 &
sleep 6
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot12.png' 2>&1
ls -l /tmp/shot12.png 2>&1
