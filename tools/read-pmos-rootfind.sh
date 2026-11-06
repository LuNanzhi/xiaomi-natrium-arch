#!/usr/bin/env bash
# 查看 pmOS init_functions.sh 里查找根分区的完整逻辑
set -uo pipefail
W=/tmp/irdump
F="$W/init_functions.sh"
[ -f "$F" ] || { echo "!! 没解包，先跑 inspect-pmos-initramfs2.sh"; exit 1; }

echo "=== 1) 与根分区查找相关的行 ==="
grep -n -iE 'pmos_root_uuid|pmos_boot_uuid|blkid|findfs|root partition|find_root|wait_for_root|PARTLABEL|LABEL=' "$F" | head -40

echo
echo "=== 2) find_root_partition / mount_root 函数全文 ==="
awk '/^find_root_partition\(\)|^mount_root\(\)|^find_boot_partition\(\)|^wait_root\(\)/{p=1} p{print} p&&/^}$/{p=0; print "-----"}' "$F" | head -120

echo
echo "=== 3) cmdline 参数解析 ==="
grep -n -B3 -A12 'pmos_root_uuid' "$F" | head -60

echo
echo "=== 4) /init 全文 ==="
cat "$W/init"

echo
echo "=== 5) init_2nd.sh 全文 ==="
cat "$W/init_2nd.sh"
