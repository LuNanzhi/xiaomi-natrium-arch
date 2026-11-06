# Arch Linux ARM on Xiaomi Mi 5s Plus (natrium)

把 Arch Linux ARM 移植到小米 5s Plus（代号 `natrium`，SoC MSM8996**Pro** / 骁龙 821，PM8994 + PMI8994）。

**状态：可用。** 内核、显示、触摸、USB 网络、包管理都已跑通，X11 + i3 + 屏幕键盘可日常操作。
Wayland 桌面（phosh）目前被一个未定位的 wlroots/DRM 问题挡住，见 [Known issues](#known-issues)。

---

## 1. 设备

| | |
|---|---|
| 代号 | `natrium` |
| SoC | MSM8996Pro（骁龙 821），4× Kryo |
| 内存 / 存储 | 4/6 GB RAM，64/128 GB UFS 2.0 |
| 屏幕 | 5.7" 1080×1920，**夏普 TD4722（command-mode DSI）**，另有 JDI 版本 |
| 触摸 | Synaptics RMI4 |
| WiFi / BT | QCA6174（ath10k） |
| 分区方式 | A-only，无 A/B、无动态分区、无 dtbo |

> ⚠️ 这块机器**混用两种面板**。ABL 传的是 `qcom,mdss_dsi_sharp_fhd_td4722_xcmd`，
> 用 JDI 的 DTB 会导致内核正常但**屏幕全黑**。本项目的 DTB 来自 pmOS 的夏普补丁版本。

## 2. 当前能做什么

| 功能 | 状态 |
|---|---|
| 启动 / systemd / 登录 | ✅ |
| 屏幕（夏普面板，1080×1920） | ✅ |
| 触摸（libinput 识别为 TOUCHSCREEN） | ✅ |
| USB 网络（RNDIS，`172.16.42.1/24`） | ✅ |
| USB 串口（CDC-ACM，Windows 显示为 COM 口） | ✅ |
| SSH / pacman / 包管理 | ✅ |
| GPU（Adreno 530，a530 固件 + Mesa） | ✅ EGL 可用，Weston 能出画面 |
| X11 + i3 + onboard 屏幕键盘 | ✅ |
| Wayland / phosh | ❌ 见 Known issues |
| WiFi 关联 | ⚠️ 能扫描，关联失败（board data / 监管域问题） |
| 音频（耳机口） | ⚠️ 未系统验证 |
| 相机 / 蜂窝 / GPS / 传感器 / 红外 | ❌ 主线无驱动 |

## 3. 从 Release 安装

Release 里有两个镜像：

| 文件 | 刷到 | 说明 |
|---|---|---|
| `boot-arch-v9.img` | `boot` | 内核 6.19.5 + 夏普 DTB，`root=PARTLABEL=userdata` |
| `arch-natrium-v8.img` | `userdata` | Arch Linux ARM aarch64，ext4 3 GB（会清空数据） |
| `rootfs-backup.tar.gz` | — | 整机 tar 备份（装桌面之前的干净状态） |
| `pmos-boot.img` | — | 内核+DTB 的原始来源，重打 boot 镜像时用 |

```bash
# 手机进 fastboot：关机后按住「音量下 + 电源」
fastboot flash boot boot-arch-v9.img
fastboot -S 256M flash userdata arch-natrium-v8.img
fastboot reboot
```

首次启动约 1–2 分钟。系统起来后：

- 屏幕是 `natrium login:`，账号 `root`，密码 `arch`
- USB 网卡（RNDIS6）出现后 `ssh root@172.16.42.1`

> 若 3 GB 镜像被拆成 `part1/part2`，先 `cat arch-natrium-v8.img.part* > arch-natrium-v8.img` 再刷。

## 4. 从源码重建

工具都在 `tools/`，主要流程：

```bash
# 1) 准备 Arch rootfs（下载 ALARM tarball 后解包）
bash tools/prepare-arch-rootfs.sh /root/arch/root

# 2) 打进 ext4 镜像（3 GB，4096 块）
bash tools/build-arch-image.sh /root/arch/root /root/arch/arch-natrium.img 3G

# 3) 打 boot.img（内核 + DTB + cmdline）
bash tools/build-arch-bootimg.sh
```

boot 镜像的打包参数（与 pmOS `deviceinfo` 一致）：

```
header v0, page_size 4096
kernel  0x80008000
ramdisk 0x81000000
tags    0x80000100
append_dtb = true
```

## 5. 在手机上装桌面

刷完 base 镜像后，用 `tools/on-phone.ps1` 把脚本传到手机执行（PC 侧跑 `tools/proxy.js` 提供代理）：

| 脚本 | 作用 |
|---|---|
| `setup-i3.sh` | 装 Xorg + i3 + onboard，配置 tty1 自动登录进图形 |
| `tune-i3.sh` | 字号/DPI、i3 配置、i3status |
| `persist-dock.sh` | onboard 停靠到底部（解决"键盘乱晃"） |
| `fix-neofetch-display.sh` | UTF-8 locale + 字号，修 neofetch 折行 |

关键点：

- `onboard` 必须跑在 `dbus-run-session` 里（`~/.xinitrc` → `~/.xsession`）
- onboard 用 **docking 模式**（`docking-enabled true`），不要用 i3 的 `move`/`resize` 规则硬摆
- 1080p 下 xterm 用 `-fs 10` 才有约 72 列，neofetch 才不折行

## 6. 目录结构

```
tools/          全部脚本（打包、刷机、手机端配置、串口、代理）
docs/           完整移植记录与踩坑表（07 是主文档）
arch-files/     i3 / onboard / networkd 的配置文件
firmware/       natrium 的 mbn 固件（adsp/mba/modem/slpi/venus/a530_zap）
build/          内核 defconfig、构建脚本
```

## 7. Known issues

### phosh / wlroots 的 atomic 提交 EBUSY

`phoc` 拿到 DRM framebuffer 后，每个原子提交都返回 `EBUSY`：

```
phoc-wlroots-CRITICAL: [backend/drm/atomic.c:82] connector DSI-1:
  Atomic commit failed: Device or resource busy
```

已排除：无进程占用 `/dev/dri/card0`、解绑 fbcon 无效、内核没有打印
`busy with a previous commit`、msm 驱动里没有任何 `-EBUSY`。Weston 用自己
的 DRM 后端可以正常出画面。**结论：不是配置问题，需要动 wlroots 或内核。**

> 所以本项目当前用 **X11 + i3**，它完全不走 wlroots，绕开了这个问题。

### WiFi

ath10k 能加载固件、能扫描到 AP，但关联失败。两个线索：

1. PCI 子系统 ID 读出来是 `0000:0000`，匹配不到 `board-2.bin` 里的条目，退到通用 `board.bin`
2. 监管域是 `00`（world），很多信道只能被动扫描 —— 已装 `wireless-regdb`，需冷启动生效

### 供电

电池老化，3.6 V 左右就撑不住；PC 的 USB 口几乎充不进去（实测 ~256 mA）。
长时间操作前用墙充，或带供电的 USB HUB。

## 8. 刷机风险

- 刷 `userdata` 会**清空全部 Android 数据**，不可逆
- `boot` 分区可随时用 `lineage-boot-rollback.img` 恢复，但 Android 需要重刷完整包
- **热重启（`reboot`）后 USB 可能不再枚举**，冷启动（关机再开机）正常 —— 这是 msm8996 的怪癖

## 9. 相关项目

- [postmarketOS: Xiaomi Mi 5s Plus](https://wiki.postmarketos.org/wiki/Xiaomi_Mi_5s_Plus_(xiaomi-natrium))（设备包已归档）
- [msm8996-mainline/linux](https://gitlab.com/msm8996-mainline/linux)（本项目内核的来源）
- [Arch Linux ARM](https://archlinuxarm.org/)

## License

脚本与文档：MIT。`firmware/` 里的固件版权归高通/小米，仅作设备移植用途。
