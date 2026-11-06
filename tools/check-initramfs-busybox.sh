#!/usr/bin/env bash
# 验证 initramfs 里的 busybox 是不是静态链接（动态链接 = initramfs 里跑不起来 = 内核找不到 init = 秒 panic）
set -uo pipefail
echo "=== [1] WSL 里的 busybox ==="
for b in /usr/bin/busybox /bin/busybox; do
  if [ -e "$b" ]; then
    echo "  $b -> $(readlink -f "$b")"
    file "$(readlink -f "$b")" | sed 's/^/    /'
    if ldd "$(readlink -f "$b")" 2>&1 | grep -q 'not a dynamic executable\|statically linked'; then
      echo "    => 静态链接 ✅"
    else
      echo "    => 动态链接 ❌ (initramfs 里无法运行!)"
      ldd "$(readlink -f "$b")" | head -4 | sed 's/^/       /'
    fi
  fi
done

echo
echo "=== [2] 我们实际打进 initramfs 的那个文件 ==="
ls -l /root/ir-logger/bin/busybox /root/ir-shell/bin/busybox /root/ir-diag/bin/busybox 2>/dev/null | head
for f in /root/ir-logger/bin/busybox /root/ir-shell/bin/busybox; do
  [ -f "$f" ] || continue
  echo "  $f:"
  file "$f" | sed 's/^/    /'
  ldd "$f" 2>&1 | head -3 | sed 's/^/    ldd: /'
done

echo
echo "=== [3] dpkg 里装了什么 ==="
dpkg -l 2>/dev/null | grep -E '^ii +(busybox|busybox-static)' | sed 's/^/  /' || echo "  (查不到)"

echo
echo "=== [4] 从 initramfs cpio 里直接解出 busybox 看链接方式 ==="
cd /tmp
rm -rf ircheck; mkdir ircheck; cd ircheck
xz -dc /mnt/c/Users/Public/natrium/stage/initramfs-logger.cpio.xz > ../ir.cpio 2>/dev/null || true
cpio -idmv < ../ir.cpio >/dev/null 2>&1 || true
if [ -f bin/busybox ]; then
  echo "  解出的 bin/busybox:"
  file bin/busybox | sed 's/^/    /'
  if file bin/busybox | grep -q 'statically linked'; then
    echo "    => 静态 ✅ 那问题不在这里"
  else
    echo "    => 动态 ❌❌ 这就是内核找不到 init 的原因!"
  fi
  ls -l init bin/busybox
else
  echo "  没能解出 bin/busybox"
  ls -l
fi
