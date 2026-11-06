#!/bin/sh
# neofetch: use the small logo so the info column fits next to it
mkdir -p /home/arch/.config/neofetch
CFG=/home/arch/.config/neofetch/config.conf
if [ ! -f "$CFG" ]; then
    su - arch -c 'neofetch --stdout >/dev/null 2>&1; test -f ~/.config/neofetch/config.conf && echo cfg-created' 2>/dev/null
fi

# neofetch generates the config on first run; patch the ascii_distro line
if [ -f "$CFG" ]; then
    sed -i 's/^#\?ascii_distro=.*/ascii_distro="arch_small"/' "$CFG"
else
    printf 'ascii_distro="arch_small"\n' > "$CFG"
fi
chown -R arch:arch /home/arch/.config/neofetch
grep -n 'ascii_distro' "$CFG" | head -3

pkill -f xterm 2>/dev/null
sleep 1
su - arch -c 'DISPLAY=:0 LANG=en_US.UTF-8 xterm -fa "DejaVu Sans Mono" -fs 12 -bg black -fg white -e "bash -lc \"neofetch; exec bash\""' >/dev/null 2>&1 &
sleep 6
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot13.png' 2>&1
ls -l /tmp/shot13.png 2>&1
