#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 用「静态 ARM64 C init」重新打包所有候选内核（内核无需重编，只重新打包 boot.img）
#
# 背景：之前用 WSL 里的 busybox 做 initramfs，那其实是个 x86_64 的自引用脚本，
#       内核 exec /init 永远失败 → 秒 panic → 所有内核版本表现一致。这才是真正的坑。
#
# 用法: repack-static-init.sh <stage 目录> [artifacts 目录:tag ...]
# ---------------------------------------------------------------------------
set -uo pipefail
STAGE="${1:?用法: repack-static-init.sh <stage> [art:tag ...]}"
shift || true
CROSS=aarch64-linux-gnu-
W=/root/static-ir
SRC="$STAGE/tools/natrium-init.c"
[ -f "$SRC" ] || { echo "!! 缺少 $SRC"; exit 1; }

# 默认要重新打包的 (artifacts 目录:tag) 组合
if [ "$#" -eq 0 ]; then
  set -- /root/art-6.12.10:6.12.10-msm \
         /root/art-6.17.8:6.17.8-msm \
         /root/art-6187:6.18.7-msmpmos \
         /root/art-6195:6.19.5-msmpmos \
         /root/natrium-build/out-artifacts:6.18.55-static
fi

echo "### [1] 编译静态 ARM64 init"
rm -rf "$W"; mkdir -p "$W/root"
$CROSS"gcc" -static -O2 -Wall -o "$W/root/init" "$SRC" || { echo "!! 编译失败"; exit 2; }
chmod +x "$W/root/init"
INFO="$(file -b "$W/root/init")"
echo "  $INFO"
case "$INFO" in
  *"ARM aarch64"*)        echo "  ✅ 架构正确 (ARM aarch64)" ;;
  *)                      echo "  ❌ 架构不是 ARM64，终止"; exit 3 ;;
esac
case "$INFO" in
  *"statically linked"*)  echo "  ✅ 静态链接" ;;
  *)                      echo "  ❌ 不是静态链接，终止"; exit 4 ;;
esac

echo
echo "### [2] 制作 initramfs（只含 /init，不需要 busybox）"
( cd "$W/root" && find . -print0 | cpio --null -o -H newc --quiet ) | xz -9 -C crc32 > "$W/initramfs-static.cpio.xz"
echo "  $(stat -c%s "$W/initramfs-static.cpio.xz") bytes"
# 再次确认压缩包里那个 init 是可执行的 ARM64 静态程序
rm -rf "$W/check"; mkdir -p "$W/check"
( cd "$W/check" && xz -dc "$W/initramfs-static.cpio.xz" | cpio -id --quiet 2>/dev/null )
echo "  cpio 里的 init: $(file -b "$W/check/init" 2>/dev/null || echo '缺失!')"
case "$(file -b "$W/check/init" 2>/dev/null)" in
  *"ARM aarch64"*"statically linked"*) echo "  ✅ 包内 init 可执行且架构正确" ;;
  *)                                   echo "  ❌ 包内 init 有问题，终止"; exit 5 ;;
esac

echo
echo "### [3] 逐个内核重新打包（4 种模式）"
for item in "$@"; do
  ART="${item%%:*}"
  TAG="${item##*:}"
  if [ ! -f "$ART/Image.gz" ] || [ ! -f "$ART/msm8996pro-xiaomi-natrium.dtb" ]; then
    echo "  !! 跳过 $TAG（缺 $ART 里的 Image.gz 或 dtb）"
    continue
  fi
  echo "  --- $TAG ---"
  for mode in logger diag flash stay; do
    out="$STAGE/boot-$TAG-$mode.img"
    python3 "$STAGE/tools/mk_bootimg.py" \
      --kernel "$ART/Image.gz" \
      --dtb "$ART/msm8996pro-xiaomi-natrium.dtb" \
      --ramdisk "$W/initramfs-static.cpio.xz" \
      --cmdline "console=tty0 loglevel=8 ignore_loglevel init=/init rw root=/dev/ram0 panic=10 natrium.mode=$mode" \
      --out "$out" >/dev/null || { echo "     !! $mode 打包失败"; continue; }
    printf '    %-52s %9d bytes  sha256=%s\n' "$(basename "$out")" "$(stat -c%s "$out")" "$(sha256sum "$out" | cut -c1-16)"
  done
done

echo
echo "=== 成品清单 ==="
ls -lh "$STAGE"/boot-*-static-*.img 2>/dev/null
ls -lh "$STAGE"/boot-6.12.10-msm-*.img "$STAGE"/boot-6.17.8-msm-*.img "$STAGE"/boot-6.18.7-msmpmos-*.img "$STAGE"/boot-6.19.5-msmpmos-*.img 2>/dev/null | tail -20
