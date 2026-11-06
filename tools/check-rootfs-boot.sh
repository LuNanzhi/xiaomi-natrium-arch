#!/usr/bin/env bash
# 检查 root.img 里的 /etc/fstab、启动相关配置是否引用了不存在的分区/UUID
set -uo pipefail
IMG=/mnt/c/Users/Public/natrium/pmos/root.img
W=/mnt/rootcheck2
mkdir -p "$W"

if ! mount -o loop,ro "$IMG" "$W" 2>/dev/null; then echo "!! 挂载失败"; exit 1; fi

echo "=== 1) /etc/fstab ==="
cat "$W/etc/fstab" 2>/dev/null

echo
echo "=== 2) 实际存在的分区 UUID（pmOS 期望的）==="
echo "  boot.img cmdline: pmos_boot_uuid=f8574aae-f337-46e3-ad47-a03555708c3d"
echo "                    pmos_root_uuid=c3df8e67-5a9a-4313-8ddf-a6ff7db3c3bc"
blkid "$IMG"

echo
echo "=== 3) 内核 cmdline 文件（有些设备用它）==="
ls "$W/boot" 2>/dev/null | head
cat "$W/etc/kernel/cmdline" 2>/dev/null || echo "  (无 /etc/kernel/cmdline)"

echo
echo "=== 4) 是否配置了 initramfs-extra / boot 挂载相关 ==="
grep -rn 'pmOS_boot\|pmos_boot' "$W/etc/fstab" "$W/etc/default" 2>/dev/null | head -10

echo
echo "=== 5) sshd 是否启用（为什么 SSH 不通）==="
ls -l "$W/etc/systemd/system/multi-user.target.wants/sshd.service" 2>/dev/null || echo "  sshd.service 未启用"
ls "$W/etc/ssh/" 2>/dev/null | head -5
grep -rn '^PermitRootLogin\|^PasswordAuthentication' "$W/etc/ssh/sshd_config" 2>/dev/null | head -5

echo
echo "=== 6) 显示管理器 / Phosh 服务 ==="
ls "$W/etc/systemd/system/display-manager.service" 2>/dev/null && readlink -f "$W/etc/systemd/system/display-manager.service"
ls "$W/etc/systemd/system/multi-user.target.wants/" 2>/dev/null | head -20

echo
echo "=== 7) 是否为 user 设置了密码（install 时给了 1234）==="
grep -c 'user:' "$W/etc/shadow" 2>/dev/null
grep '^user:' "$W/etc/shadow" 2>/dev/null | cut -c1-40

umount "$W"
echo "(已卸载)"
