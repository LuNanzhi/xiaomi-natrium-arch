#!/bin/sh
echo "--- seatd ---"
systemctl is-active seatd
ls -l /run/seatd.sock 2>&1
echo "--- phoc direct ---"
su - arch -c 'XDG_RUNTIME_DIR=/run/user/1001 timeout 10 phoc -S -C /usr/share/phosh/phoc.ini' 2>&1 | head -30
echo "--- env of arch ---"
su - arch -c 'echo HOME=$HOME; id' 2>&1
