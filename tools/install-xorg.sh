#!/bin/sh
# Install Xorg + i3 + onboard and start the install in the background.
set -x
timedatectl set-ntp false
date -s @1792917124
export http_proxy=http://172.16.42.102:3128
export https_proxy=$http_proxy

nohup pacman -S --noconfirm xorg-server xorg-xinit xf86-input-libinput \
      i3-wm i3status i3lock onboard xterm ttf-dejavu noto-fonts \
      > /tmp/xorg-install.log 2>&1 &
echo "install started"
