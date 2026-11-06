#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 为 Xiaomi Mi 5s Plus (natrium / MSM8996Pro) 构建 mainline Linux 6.18 内核
#
# 用法:
#   bash build-kernel.sh                    # 默认 6.18.55
#   bash build-kernel.sh 6.18.50 ~/build    # 指定版本与工作目录
#
# 产物 (在 $WORK/out-artifacts/):
#   Image.gz                       - 内核镜像
#   msm8996pro-xiaomi-natrium.dtb  - 设备树
#   Image.gz-dtb                   - 供 bootloader 使用的追加 DTB 镜像
#   modules.tar.gz                 - 内核模块(含 depmod 结果)
#   build.log / .config            - 构建日志与最终配置
# ---------------------------------------------------------------------------
set -euo pipefail

VER="${1:-6.18.55}"
WORK="${2:-$HOME/natrium-build}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAGMENT="${FRAGMENT:-$SCRIPT_DIR/natrium.config}"
CROSS="aarch64-linux-gnu-"
ARCH=arm64
JOBS="${JOBS:-$(nproc)}"

SRC="$WORK/linux-$VER"
OUT="$WORK/out"
ART="$WORK/out-artifacts"
BASE="https://cdn.kernel.org/pub/linux/kernel/v6.x"

mkdir -p "$WORK" "$ART"

echo "==> [1/6] 获取源码 linux-$VER"
cd "$WORK"
if [ ! -d "$SRC" ]; then
  if [ ! -f "linux-$VER.tar.xz" ]; then
    wget -O "linux-$VER.tar.xz" "$BASE/linux-$VER.tar.xz"
  fi
  echo "    源码 sha256: $(sha256sum "linux-$VER.tar.xz" | cut -d' ' -f1)"
  tar -xf "linux-$VER.tar.xz"
else
  echo "    已存在，跳过解包"
fi
cd "$SRC"

echo "==> [2/6] 生成配置 (defconfig + natrium.config)"
if [ "${KEEP_OUT:-0}" = "1" ] && [ -f "$OUT/.config" ]; then
  echo "    KEEP_OUT=1：复用已编译的 $OUT（跳过配置与重建）"
else
  rm -rf "$OUT"
  make ARCH=$ARCH CROSS_COMPILE=$CROSS O="$OUT" defconfig >/dev/null
  scripts/kconfig/merge_config.sh -m -O "$OUT" "$OUT/.config" "$FRAGMENT" 2>&1 | grep -Ei 'value requested|not in final|warning' || true
  make ARCH=$ARCH CROSS_COMPILE=$CROSS O="$OUT" olddefconfig >/dev/null
fi
cp "$OUT/.config" "$ART/config-6.18-natrium"
echo "    最终配置已存: config-6.18-natrium"

echo "==> [3/6] 关键符号自检"
missing=0
warned=0
check() {  # check SYMBOL EXPECTED [strict|warn]
  local sym="$1" want="$2" mode="${3:-strict}" got
  # 注意: 必须带 || true，否则 set -e + pipefail 会在 grep 无匹配时直接终止脚本
  got="$(grep -E "^$sym=" "$OUT/.config" 2>/dev/null | head -1 | cut -d= -f2 || true)"
  if [ "$got" != "$want" ]; then
    if [ "$mode" = strict ]; then
      echo "    !! $sym = ${got:-未设置} (期望 $want)"
      missing=$((missing + 1))
    else
      echo "    ?  $sym = ${got:-未设置} (期望 $want，非致命)"
      warned=$((warned + 1))
    fi
  else
    echo "    ok $sym=$got"
  fi
}
# —— 致命：缺了就不可能看到画面/进用户态 ——
check CONFIG_ARCH_QCOM y
check CONFIG_DRM y
check CONFIG_DRM_MSM y
check CONFIG_DRM_PANEL_JDI_R63452 y
check CONFIG_DRM_FBDEV_EMULATION y
check CONFIG_FRAMEBUFFER_CONSOLE y
check CONFIG_PINCTRL_MSM8996 y
check CONFIG_MSM_GCC_8996 y
check CONFIG_BLK_DEV_INITRD y
# —— 重要但不致命：名字随版本可能变化，仅警告 ——
check CONFIG_RMI4_I2C y warn
check CONFIG_SCSI_UFS_QCOM y
check CONFIG_PHY_QCOM_QMP y
check CONFIG_PHY_QCOM_QMP_UFS y
check CONFIG_EXT4_FS y
check CONFIG_USB_DWC3 y warn
check CONFIG_USB_CONFIGFS y warn
check CONFIG_WCN36XX y warn
check CONFIG_QCOM_Q6V5_PAS y warn
check CONFIG_QCOM_Q6V5_MSS y warn
check CONFIG_SERIAL_MSM y warn
check CONFIG_ANDROID_BINDERFS y warn
if [ "$missing" -gt 0 ]; then
  echo "!! 有 $missing 个致命符号未满足（$warned 个非致命警告），请修正 natrium.config 与 Kconfig 名称"
  exit 2
fi
echo "    自检通过（非致命警告 $warned 项，稍后在完整日志中确认）"

echo "==> [4/6] 编译 (Image.gz + dtbs)，并行 $JOBS"
make -j"$JOBS" ARCH=$ARCH CROSS_COMPILE=$CROSS O="$OUT" Image.gz dtbs 2>&1 | tee "$ART/build.log"
tail -5 "$ART/build.log"

echo "==> [5/6] 收集产物"
cp "$OUT/arch/arm64/boot/Image.gz" "$ART/Image.gz"
DTB_SRC="$OUT/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dtb"
[ -f "$DTB_SRC" ] || { echo "!! 未找到 natrium DTB: $DTB_SRC"; exit 3; }
cp "$DTB_SRC" "$ART/msm8996pro-xiaomi-natrium.dtb"
cat "$ART/Image.gz" "$ART/msm8996pro-xiaomi-natrium.dtb" > "$ART/Image.gz-dtb"
echo "    Image.gz       : $(stat -c%s "$ART/Image.gz") bytes"
echo "    natrium.dtb    : $(stat -c%s "$ART/msm8996pro-xiaomi-natrium.dtb") bytes"
echo "    Image.gz-dtb   : $(stat -c%s "$ART/Image.gz-dtb") bytes"
echo "    DTB 校验:"
# 注意: `fdtdump | head` 会因 SIGPIPE 让 pipefail 判失败，必须吞掉退出码
if command -v fdtdump >/dev/null 2>&1; then
  fdtdump "$ART/msm8996pro-xiaomi-natrium.dtb" 2>/dev/null | head -14 || true
else
  dtc -I dtb -O dts "$ART/msm8996pro-xiaomi-natrium.dtb" 2>/dev/null | head -14 || true
fi
echo "    DTB 里的关键字段（ABL 靠这些值选树）:"
dtc -I dtb -O dts "$ART/msm8996pro-xiaomi-natrium.dtb" 2>/dev/null | grep -E 'model|compatible =|msm-id|board-id' | head -5 || true

echo "==> [6/6] 编译并安装模块到 $WORK/modules"
make -j"$JOBS" ARCH=$ARCH CROSS_COMPILE=$CROSS O="$OUT" modules 2>&1 | tee -a "$ART/build.log" || { echo "!! make modules 失败"; exit 4; }
make ARCH=$ARCH CROSS_COMPILE=$CROSS O="$OUT" INSTALL_MOD_PATH="$WORK/modules" INSTALL_MOD_STRIP=1 modules_install >>"$ART/build.log" 2>&1 || { echo "!! modules_install 失败"; exit 5; }
tar -C "$WORK/modules" -czf "$ART/modules.tar.gz" lib
echo "    modules.tar.gz : $(stat -c%s "$ART/modules.tar.gz") bytes"
echo "    模块版本目录   : $(ls "$WORK/modules/lib/modules" 2>/dev/null | head -2)"

echo
echo "==> 完成。产物目录: $ART"
ls -lh "$ART"
echo
echo "下一步: python3 $SCRIPT_DIR/../tools/mk_bootimg.py --help"
