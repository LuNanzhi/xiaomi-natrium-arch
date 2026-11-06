#!/usr/bin/env bash
# 配置 pmbootstrap（非交互式）并验证配置可用
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
CFG=/root/.config/pmbootstrap_v3.cfg

mkdir -p /root/.config /root/.local/var/pmbootstrap
cat > "$CFG" <<'EOF'
[pmbootstrap]
aports = /root/pmaports
as_root = True
build_pkgs_on_install = True
ccache = False
device = xiaomi-natrium
extra_packages = 
hostname = natrium
is_default_channel = True
jobs = 8
kernel = 
log = /root/.local/var/pmbootstrap/log.txt
mirror_alpine = http://dl-cdn.alpinelinux.org/alpine/
mirror_postmarketos = http://mirror.postmarketos.org/postmarketos/
pmbootstrap_version = 3.12.0
ssh_keys = False
sudo_timer = False
timezone = 
ui = none
user = user
work = /root/.local/var/pmbootstrap
EOF

echo "=== 配置内容 ==="
cat "$CFG"

echo
echo "=== pmbootstrap status ==="
python3 "$PB" --as-root status 2>&1 | sed -n '1,40p'

echo
echo "=== deviceinfo_parse（确认设备包能被识别）==="
python3 "$PB" --as-root deviceinfo_parse 2>&1 | sed -n '1,30p'

echo
echo "=== 现有 chroot / work 目录 ==="
ls -la /root/.local/var/pmbootstrap 2>/dev/null | head
df -h / | tail -1
