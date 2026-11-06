#!/usr/bin/env bash
# Repack images with the v2 static init (adds USB serial output channel)
set -uo pipefail
STAGE=/mnt/c/Users/Public/natrium/stage
SRC="$STAGE/tools/natrium-init2.c"
W=/root/static-ir2
CROSS=aarch64-linux-gnu-

[ -f "$SRC" ] || { echo "!! missing $SRC"; exit 1; }

rm -rf "$W"; mkdir -p "$W/root"
"${CROSS}gcc" -static -O2 -o "$W/root/init" "$SRC" || { echo "!! compile failed"; exit 2; }
chmod +x "$W/root/init"
INFO="$(file -b "$W/root/init")"
echo "  init: $INFO"
case "$INFO" in
  *ARM*aarch64*statically*) echo "  ok: static ARM64" ;;
  *) echo "  !! wrong arch/linkage"; exit 3 ;;
esac

( cd "$W/root" && find . -print0 | cpio --null -o -H newc --quiet ) | xz -9 -C crc32 > "$W/initramfs.cpio.xz"
echo "  initramfs: $(stat -c%s "$W/initramfs.cpio.xz") bytes"

rm -rf "$W/check"; mkdir -p "$W/check"
( cd "$W/check" && xz -dc "$W/initramfs.cpio.xz" | cpio -id --quiet 2>/dev/null )
echo "  init inside cpio: $(file -b "$W/check/init" 2>/dev/null)"

for pair in /root/art-6195:6.19.5-msmpmos /root/art-6187:6.18.7-msmpmos /root/art-6.12.10:6.12.10-msm /root/art-6.17.8:6.17.8-msm; do
  ART="${pair%%:*}"
  TAG="${pair##*:}"
  if [ ! -f "$ART/Image.gz" ] || [ ! -f "$ART/msm8996pro-xiaomi-natrium.dtb" ]; then
    echo "  skip $TAG (missing artifacts)"
    continue
  fi
  for mode in stay logger diag; do
    out="$STAGE/boot-$TAG-$mode.img"
    python3 "$STAGE/tools/mk_bootimg.py" \
      --kernel "$ART/Image.gz" \
      --dtb "$ART/msm8996pro-xiaomi-natrium.dtb" \
      --ramdisk "$W/initramfs.cpio.xz" \
      --cmdline "console=tty0 loglevel=8 ignore_loglevel init=/init rw root=/dev/ram0 panic=10 natrium.mode=$mode" \
      --out "$out" >/dev/null && printf '    %-46s %9d bytes\n' "$(basename "$out")" "$(stat -c%s "$out")"
  done
done
echo
echo "=== done ==="
ls -lh "$STAGE"/boot-6.19.5-msmpmos-stay.img "$STAGE"/boot-6.18.7-msmpmos-stay.img 2>/dev/null
