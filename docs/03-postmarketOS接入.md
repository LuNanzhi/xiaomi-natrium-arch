# 03 · 把 6.18 内核接入 postmarketOS（真正的可用系统）

> 这是路线 B。Android 用户态走不通（见 01 报告），而 postmarketOS 是**主线内核 + 主线用户态**，
> 和 6.18 天生匹配；natrium 在 pmOS 里已有设备包（`device-xiaomi-natrium`、`firmware-xiaomi-natrium`）。

## 0. 推荐顺序（重要）

**先用 pmOS 自带内核把系统装起来并跑通，再换我们的 6.18 内核。**
这样任何问题都能立刻区分是「pmOS/用户态问题」还是「我们的内核问题」——直接换内核会两个变量一起变，很难排查。

## 1. 安装 pmOS（用自带内核）

```bash
# 在 Linux 机器上（或本机 WSL 内）
pip install pmbootstrap
pmbootstrap init        # vendor: xiaomi   device: natrium   ui: phosh
pmbootstrap install     # 生成 rootfs 与 boot.img
pmbootstrap flasher flash_rootfs      # 刷 userdata
pmbootstrap flasher flash_kernel      # 刷 boot（= pmOS 自带内核）
```

装好后确认能用：显示、触摸、WiFi。这些一旦通了，后面只剩下「换内核」一个变量。

## 2. 用本工程编译的 6.18 替换内核

pmOS 的 boot.img 同样是「内核 + initramfs(挂载 rootfs 用) + cmdline」。我们的做法是
**保留 pmOS 的 ramdisk 与 cmdline，只换掉内核（含追加 DTB）**：

```bash
# 2.1 解出 pmOS boot.img 的 ramdisk 与 cmdline
python3 tools/bootimg_info.py info   pmos-boot.img
python3 tools/bootimg_info.py unpack pmos-boot.img pmos-unpacked
#     -> pmos-unpacked/ramdisk.img, header.json(含 pmOS 的 cmdline)

# 2.2 用我们的 6.18 重新打包
python3 tools/mk_bootimg.py \
  --kernel   out/Image.gz \
  --dtb      out/msm8996pro-xiaomi-natrium.dtb \
  --ramdisk  pmos-unpacked/ramdisk.img \
  --cmdline  "$(python3 -c "import json;print(json.load(open('pmos-unpacked/header.json'))['cmdline'])")" \
  --out      boot-6.18.55-natrium-pmos.img

# 2.3 刷入
fastboot flash boot boot-6.18.55-natrium-pmos.img
```

> 注意：**不要**照抄本工程 bring-up 镜像的 cmdline（那个是 `root=/dev/ram0` 的调试用），
> 换内核时一定要用 pmOS 自己的 cmdline（里面有 `root=` 指向 userdata 上的 rootfs、`console=` 等）。

## 3. 装上 6.18 的内核模块

我们的内核里大部分驱动是模块（WiFi、GPU、音频、remoteproc 等），必须放进 rootfs 的模块目录，
版本号要与 `uname -r` 完全一致：

```bash
# 在设备上（pmOS 已启动）
sudo tar -xzf modules.tar.gz -C /          # 解出 /lib/modules/6.18.55-natrium/
sudo depmod -a 6.18.55-natrium
uname -r                                   # 应显示 6.18.55-natrium
```

或者更省事：在换内核之前，直接把这些模块打包进 pmOS rootfs 再刷。

## 4. 固件（WiFi / GPU / modem / adsp / slpi / venus）

mainline 设备树写死的固件名是：

```
qcom/msm8996/natrium/adsp.mbn   slpi.mbn   venus.mbn
qcom/msm8996/natrium/mba.mbn    modem.mbn
qcom/msm8996/natrium/a530_zap.mbn
qcom/a530_pfp.fw  qcom/a530_pm4.fw          # freedreno
wlan/prima/*                                 # wcn36xx
```

两种来源：

1. **pmOS 固件包（推荐）**：`sudo apk add firmware-xiaomi-natrium`，装完即在 `/lib/firmware/`。
2. **从你自己的手机提取**：在 Android 下跑 `tools/collect-firmware.sh`，再 `adb pull` 出来放进 `/lib/firmware/`。
   注意 modem/adsp/venus 在 Android 上常是 `b00/b01/...` 分片格式，主线 remoteproc 要合并后的 `.mbn`，
   这种情况直接用 pmOS 固件包更省事。

## 5. 验证清单

| 检查项 | 命令 | 期望 |
|---|---|---|
| 内核版本 | `uname -a` | `6.18.55-natrium` |
| 设备树被正确选中 | `cat /proc/device-tree/model` | `Xiaomi Mi 5s Plus` |
| 显示 | `ls /sys/class/drm/`；`cat /sys/class/drm/card0-*/status` | `connected` |
| 背光 | `ls /sys/class/backlight/` | `backlight`（wled） |
| 触摸 | `dmesg | grep -i rmi4` | 出现 `rmi4_i2c … 6-0020` |
| GPU | `dmesg | grep -i adreno`；`glxinfo -B`（Mesa） | `Adreno 530` |
| WiFi | `dmesg | grep -i wcn36xx`；`nmcli` | 出现 `wlan0` |
| 存储 | `lsblk` | UFS 分区 |
| 远程处理器 | `ls /sys/class/remoteproc/`；`dmesg | grep -i remoteproc` | adsp/mss/slpi 加载成功 |

## 6. 预期结果

| 功能 | 6.18 上 | 说明 |
|---|---|---|
| 显示 + 触摸 | ✅ | mainline 面板/触摸驱动齐全 |
| 背光 | ✅ | pmi8994 wled |
| WiFi / 蓝牙 | ✅（需固件） | wcn36xx / btqcomsmd |
| GPU 3D | ✅（需固件） | freedreno + a530_zap.mbn |
| 音频 | ⚠️ 部分 | apq8096 sndcard + WCD9335 已主线化，可能需调 |
| 通话 / 短信 / 数据 | ⚠️ 需折腾 | 需 modem 固件 + q6voiced + ModemManager，不是开箱可用 |
| 摄像头 | ❌ | msm8996 CAMSS 在 natrium 未接线，主线无驱动 |

## 7. 想要 Android 应用？

装完 pmOS 后再上 **Waydroid**（Android 容器，主线内核的 binder/binderfs 与 freedreno 都支持）：

```bash
sudo apk add waydroid
sudo waydroid init
sudo rc-service waydroid-container start
```

它**不是完整手机系统**：没有通话、没有相机；性能取决于主线 GPU 驱动。
但这是「6.18 内核 + Android 应用」唯一现实可行的形态。
