#!/system/bin/sh
# ---------------------------------------------------------------------------
# 在手机的 LineageOS 上采集「Android 用户态为何离不开 4.4 下游内核」的直接证据。
# 用法（电脑上）:
#   adb push collect-android-evidence.sh /data/local/tmp/
#   adb shell su -c "sh /data/local/tmp/collect-android-evidence.sh" > evidence.txt
# 输出即为报告中的实测证据。
# ---------------------------------------------------------------------------
echo "===== natrium Android 侧证据采集 $(date) ====="
echo
echo "--- [1] 内核版本（下游基线） ---"
uname -a
cat /proc/version
echo
echo "--- [2] 厂商图形栈命门：kgsl / ion / fb ---"
ls -l /dev/kgsl* /dev/ion /dev/graphics/fb* 2>&1
echo "kgsl 驱动版本:"
cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null
cat /sys/class/kgsl/kgsl-3d0/gpuclk 2>/dev/null
echo
echo "--- [3] 通话依赖的下游 SMD 节点 ---"
ls -l /dev/smd* 2>&1 | head -20
echo
echo "--- [4] 厂商 HAL 二进制（编译期绑定 4.4 内核接口） ---"
ls -l /vendor/lib/hw/ 2>/dev/null | grep -Ei 'gralloc|hwcomposer|memtrack|camera|copybit|sensors|audio|lights|power|gps'
ls -l /vendor/lib64/hw/ 2>/dev/null | grep -Ei 'gralloc|hwcomposer|memtrack|camera|copybit'
echo
echo "--- [5] 内核模块 vermagic（决定能否在 6.18 加载） ---"
for m in /vendor/lib/modules/*.ko; do
  [ -f "$m" ] || continue
  echo "$m: $(modinfo "$m" 2>/dev/null | grep -E '^vermagic' )"
done
echo
echo "--- [6] 关键内核模块列表 ---"
ls /vendor/lib/modules/ 2>/dev/null
echo
echo "--- [7] 挂载与分区（rootfs 布局参考） ---"
mount | grep -E ' /(system|vendor|data|firmware|persist)' 
cat /proc/partitions
echo
echo "--- [8] 固件文件（6.18 所需 mbn 的来源） ---"
ls -l /vendor/firmware/ 2>/dev/null | head -30
ls -l /firmware/image/ 2>/dev/null | head -30
echo
echo "--- [9] SELinux 与厂商策略 ---"
getenforce
ls -l /vendor/etc/selinux/ 2>/dev/null
echo
echo "--- [10] DTB 选择依据（bootloader 靠这两个值选 DTB） ---"
for f in /sys/firmware/devicetree/base/qcom,msm-id /sys/firmware/devicetree/base/qcom,board-id /sys/firmware/devicetree/base/model; do
  [ -e "$f" ] && echo "$f = $(cat "$f" | tr -d '\0' | od -An -tx1 | tr -s ' ')"
done
echo
echo "===== 采集结束 ====="
