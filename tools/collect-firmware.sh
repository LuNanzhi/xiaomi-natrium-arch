#!/system/bin/sh
# ---------------------------------------------------------------------------
# 在手机上采集 mainline（6.18）需要的固件，按内核期望的路径重命名后放到 /data/local/tmp/natrium-fw/
#
# 用法（电脑上）:
#   adb push collect-firmware.sh /data/local/tmp/
#   adb shell su -c "sh /data/local/tmp/collect-firmware.sh"
#   adb pull /data/local/tmp/natrium-fw ./
#
# mainline natrium 设备树里写死的固件名（见 msm8996pro-xiaomi-natrium.dts）:
#   adsp.mbn / mba.mbn / modem.mbn / slpi.mbn / venus.mbn / a530_zap.mbn
#   + WiFi 的 wlan/prima/*（wcn36xx 驱动用）
#   + GPU 的 a530_pfp.fw / a530_pm4.fw（freedreno 用）
# ---------------------------------------------------------------------------
OUT=/data/local/tmp/natrium-fw
mkdir -p "$OUT/qcom/msm8996/natrium" "$OUT/wlan/prima" "$OUT/qcom"

echo "=== 搜索固件来源目录 ==="
for d in /vendor/firmware_mnt/image /firmware/image /vendor/firmware /system/etc/firmware /firmware; do
  [ -d "$d" ] && echo "  $d 存在，文件数 $(ls "$d" 2>/dev/null | wc -l)"
done

copy_first() {   # copy_first <目标名> <候选源路径...>
  local dst="$1"; shift
  for s in "$@"; do
    if [ -f "$s" ]; then
      cp -f "$s" "$OUT/qcom/msm8996/natrium/$dst"
      echo "  ok  $dst  <=  $s  ($(stat -c%s "$s") bytes)"
      return 0
    fi
  done
  echo "  !!  找不到 $dst （候选: $*）"
  return 1
}

echo
echo "=== [1] remoteproc 固件 (adsp / modem / slpi / venus) ==="
copy_first adsp.mbn  /vendor/firmware_mnt/image/adsp.mbn  /firmware/image/adsp.mbn  /vendor/firmware/adsp.mbn
copy_first mba.mbn   /vendor/firmware_mnt/image/mba.mbn   /firmware/image/mba.mbn
copy_first modem.mbn /vendor/firmware_mnt/image/modem.mbn /firmware/image/modem.mbn
copy_first slpi.mbn  /vendor/firmware_mnt/image/slpi.mbn  /firmware/image/slpi.mbn
copy_first venus.mbn /vendor/firmware_mnt/image/venus.mbn /firmware/image/venus.mbn

echo
echo "=== [2] GPU 固件 (Adreno 530 / freedreno + zap shader) ==="
copy_first a530_zap.mbn /vendor/firmware/a530_zap.mbn /vendor/firmware_mnt/image/a530_zap.mbn /firmware/image/a530_zap.mbn
cp -f /vendor/firmware/a530_pfp.fw "$OUT/qcom/" 2>/dev/null && echo "  ok  a530_pfp.fw"
cp -f /vendor/firmware/a530_pm4.fw "$OUT/qcom/" 2>/dev/null && echo "  ok  a530_pm4.fw"
ls /vendor/firmware/ 2>/dev/null | grep -i a530

echo
echo "=== [3] WiFi / 蓝牙固件 (QCA6174 + WCNSS) ==="
for f in /vendor/firmware/wlan/prima/* /system/etc/firmware/wlan/prima/* /vendor/firmware/*wcnss* /vendor/firmware_mnt/image/wcnss*; do
  [ -f "$f" ] || continue
  case "$f" in
    *prima*) cp -f "$f" "$OUT/wlan/prima/" && echo "  ok  wlan/prima/$(basename "$f")" ;;
    *)       cp -f "$f" "$OUT/qcom/"       && echo "  ok  qcom/$(basename "$f")" ;;
  esac
done

echo
echo "=== [4] 传感器/触摸 固件（如有） ==="
ls -l /vendor/firmware/ 2>/dev/null | grep -Ei 'synaptics|s3528|touch|goodix' 
find /vendor/firmware /vendor/firmware_mnt/image -iname '*syna*' -o -iname '*s3528*' 2>/dev/null

echo
echo "=== [5] 采集结果 ==="
find "$OUT" -type f | while read -r f; do echo "  $(stat -c%s "$f")  $f"; done
echo
echo "总计 $(find "$OUT" -type f | wc -l) 个文件"
echo
echo "下一步（电脑上）:"
echo "  adb pull /data/local/tmp/natrium-fw ./natrium-fw"
echo "  然后把这些文件放到目标系统的 /lib/firmware/ 下（保持目录结构）"
echo
echo "注意: 若某固件在 Android 上是 b00/b01... 分片格式（modem/adsp/venus 常见），"
echo "      主线 remoteproc 需要合并后的 .mbn；pmOS 的 firmware-xiaomi-natrium 包里就是合并好的，"
echo "      可直接用 pmOS 固件包，不必自己合并。"
