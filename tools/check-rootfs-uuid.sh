#!/usr/bin/env bash
# 核对 root.img 的文件系统 UUID 与 boot.img cmdline 里的 pmos_root_uuid 是否一致
set -uo pipefail
PMOS=/mnt/c/Users/Public/natrium/pmos

echo "=== 1) boot.img cmdline 里的 UUID ==="
python3 - <<'PY'
import struct
d = open("/mnt/c/Users/Public/natrium/pmos/boot.img", "rb").read()
cmd = d[64:64+512].split(b"\x00")[0].decode("utf-8", "replace")
print("  cmdline:", cmd)
for tok in cmd.split():
    if tok.startswith("pmos_root_uuid=") or tok.startswith("pmos_boot_uuid="):
        print("   ", tok)
PY

echo
echo "=== 2) root.img 的文件系统 UUID ==="
blkid "$PMOS/root.img" 2>/dev/null || {
  echo "  blkid 无输出，尝试直接读 ext4 超级块"
  python3 - <<'PY'
import struct, uuid
d = open("/mnt/c/Users/Public/natrium/pmos/root.img", "rb").read(4096)
# ext4 超级块偏移 1024，s_uuid 在偏移 0x68 处，16 字节
sb = d[1024:1024+1024]
u = sb[0x68:0x68+16]
print("  fs UUID:", uuid.UUID(bytes=u))
print("  volume name:", sb[0x78:0x78+16].split(b"\x00")[0].decode("utf-8","replace"))
PY
}

echo
echo "=== 3) root.img 的 blob / 标签信息 ==="
file "$PMOS/root.img"

echo
echo "=== 4) 结论 ==="
python3 - <<'PY'
import struct, subprocess, uuid
cmd = open("/mnt/c/Users/Public/natrium/pmos/boot.img","rb").read()[64:64+512].split(b"\x00")[0].decode()
root_uuid = ""
for t in cmd.split():
    if t.startswith("pmos_root_uuid="): root_uuid = t.split("=",1)[1]
d = open("/mnt/c/Users/Public/natrium/pmos/root.img","rb").read(8192)
sb = d[1024:2048]
fs_uuid = str(uuid.UUID(bytes=sb[0x68:0x78]))
label = sb[0x78:0x88].split(b"\x00")[0].decode("utf-8","replace")
print("  cmdline pmos_root_uuid :", root_uuid)
print("  root.img fs UUID       :", fs_uuid)
print("  root.img 卷标          :", label)
print("  => %s" % ("✅ 一致，刷进 userdata 后 initramfs 能找到根分区" if root_uuid == fs_uuid
                  else "❌ 不一致！需要修正 cmdline 或重新生成 root.img"))
PY
