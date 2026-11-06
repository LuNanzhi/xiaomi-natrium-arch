# 07 · Arch Linux 移植方案与 P0 进度

> 更新时间：2026-10-25 01:30
> 一句话：**Arch 不需要重新移植内核。** 复用 pmOS 那套 6.19.5 + 夏普面板 DTB，只换用户态。
> P0 的三个产物已经做好了，等电量到位就能刷。

---

## 一、为什么说"只换用户态"

这台机器的移植工作量集中在四处，前三处已经有了：

| 部件 | 来源 | 状态 |
|---|---|---|
| 内核 6.19.5-msm8996（msm8996-mainline + 夏普 TD4722 面板补丁） | pmOS 内核包 | ✅ 有 |
| DTB `msm8996pro-xiaomi-natrium`（`compatible = sharp,td4722-xcmd`） | pmOS `boot.img` 里 | ✅ 有 |
| boot.img 打包（page 4096 / kernel 0x80008000 / ramdisk 0x81000000 / 追加 DTB） | `tools/mk_bootimg.py`、`bootimg_info.py` | ✅ 已验证 |
| 用户态 | **本次要做的** | 🟡 P0 完成 |

⚠️ **一个之前一直踩着的坑**：`art-6195` 那套 DTB 是 `jdi,fhd-r63452`（JDI 屏），而这台机器 ABL
传的是夏普屏参数。用 JDI 的 DTB，内核就算跑到用户态，屏幕也永远不会亮。现在 `boot-arch.img`
用的 DTB 是从 pmOS 镜像里原样取的夏普版，`grep -a 'sharp,td4722-xcmd'` 已确认命中。

## 二、P0 产物（`C:\Users\Public\natrium\arch\`）

| 文件 | 大小 | 说明 |
|---|---|---|
| `boot-arch.img` | 11.9 MB | 内核 + 夏普 DTB + 自研 initramfs |
| `arch-natrium.img` | 3.0 GB | Arch Linux ARM aarch64，ext4，**直接写 userdata** |
| `arch-initramfs.cpio.xz` | 533 KB | 单独留一份，便于改 cmdline 重打包 |

### boot-arch.img

```
kernel : 6.19.5 (pmOS 构建，clang) —— 与 /lib/modules/6.19.5 的 592 个模块严格匹配
dtb    : msm8996pro-xiaomi-natrium，compatible sharp,td4722-xcmd
cmdline: console=tty0 loglevel=7 ignore_loglevel root=PARTLABEL=userdata rootwait rw
         init=/init panic=10
```

initramfs 只做一件事：找到 `PARTLABEL=userdata` → mount ext4 → `switch_root /sbin/init`。
找不到就掉进 busybox shell 并打印分区表，**不会静默 panic**。

### arch-natrium.img

- 来源：ALARM 官方 `ArchLinuxARM-aarch64-latest.tar.gz`（829 MB，2026-08-05 版）
- 已注入：`/lib/modules/6.19.5`（592 个模块，`modules.dep` 重新生成 —— 原包里的 dep 是空的）
- 已注入：`/lib/firmware/qcom/msm8996/natrium/*`（adsp/mba/modem/slpi/venus/a530_zap）
- 已配置：
  - `fstab`: `PARTLABEL=userdata / ext4 rw,relatime`
  - root 密码 `arch`（`$6$` 哈希）
  - `sshd` 已 enable，`PermitRootLogin yes`
  - `/etc/modules-load.d/natrium.conf`: `drm` `msm` `panel-sharp-td4722-xcmd` `leds-qcom-lpg`
    （最后一个是背光，少了它 console 画出来但屏幕是黑的）
  - `systemd-networkd` + `usb0 = 172.16.42.1/24` + DHCP 服务端
  - `natrium-usb-gadget.service`：configfs 拉 RNDIS（Windows 免驱那个）

## 三、测试顺序（从最安全开始）

手机进 fastboot（关机后音量下+电源），**每条都不写分区**，失败重启就能回：

### 1. 先证明内核和夏普屏能工作

```
fastboot boot C:\Users\Public\natrium\pmos\boot-console.img
```

它是 pmOS 自己的镜像，cmdline 带 `console=tty0 ... loglevel=8`。
判读：**屏幕出内核日志**（成功）／黑屏但有 USB 网卡出现（也成功）／
几十秒自己回 fastboot（失败，要上 UART）。

### 2. 再证明 Arch 的启动链能工作

```
fastboot boot C:\Users\Public\natrium\arch\boot-arch.img
```

此时 userdata 里还是 pmOS 的根，Arch 的 initramfs 找不到 `PARTLABEL=userdata` 的 ext4，
**预期会掉进 busybox shell**，屏幕能看到 `natrium: root filesystem not found`。
看到这行就等于成功 —— 内核、DTB、initramfs、cmdline 全部正确。

### 3. 最后才是真刷（会清 userdata）

```
fastboot flash boot    C:\Users\Public\natrium\arch\boot-arch.img
fastboot -S 256M flash userdata C:\Users\Public\natrium\arch\arch-natrium.img
fastboot reboot
```

首启 1~3 分钟。屏幕出 `natrium login:` 就登录 root / `arch`；
USB 网卡出来后 `ssh root@172.16.42.1`。

## 四、已知风险

| 风险 | 说明 |
|---|---|
| 电池 | 3.52 V 时 `fastboot boot` 必掉电。**先充到 ≥4.0 V**，而且测试时插着线 |
| RNDIS 在 Windows | Win10/11 自带 RNDIS 驱动，但偶尔要手动指定"USB RNDIS Adapter" |
| 首次启动 | Arch 的 `systemd` 会跑 `systemd-firstboot`，machine-id 已预生成避免卡住 |
| pacman 源 | ALARM 官方源在国内慢，P1 再换清华/中科大 |
| 桌面 | P0 只到 console；P1 才上 Mesa/freedreno + sway/phosh |

## 四之二、P0 实测结果（2026-10-25）

**Arch Linux ARM 已经在这台机器上跑起来了。**

```
Linux natrium 6.19.5 #1-postmarketos-qcom-msm8996 aarch64
sshd / iwd / systemd-networkd  active
usb0  172.16.42.1/24  UP        # RNDIS，PC 侧 172.16.42.x
ttyGS0  getty 已起              # CDC-ACM 串口，Windows 显示为 COM13
屏幕   natrium login:           # 夏普屏正常点亮
```

已打通：`ssh root@172.16.42.1`（密码 `arch`）、`pacman`（可用，但手机没有出网路由）。

### 踩过的坑（都记下来，避免重走）

| 坑 | 真相 |
|---|---|
| "内核起不来" | 全是误判。内核一直正常，是 initramfs 里的 `/init` 被写成了符号链接指向 busybox 本体 |
| 黑屏 | 用错了 DTB：`art-6195` 那套是 `jdi,fhd-r63452`，这台是 `sharp,td4722-xcmd`。从 pmOS `boot.img` 里取 DTB 才对 |
| 电脑找不到手机 | Windows 没给 RNDIS 装驱动（问题代码 28）。手动选 `USB RNDIS6 适配器` 后立刻通 |
| iwd 不启动 | `iwd.service` 是 `Type=dbus`，而 ALARM tarball 里 `dbus.service` 没 enable |
| pacman 报 Landlock | 内核没开 `CONFIG_SECURITY_LANDLOCK`；`/etc/pacman.conf` 加 `DisableSandbox` |
| 改镜像后 `/usr/lib/iwd` 报 Bad message | 在 loop 挂载的 ext4 上直接写文件会弄坏文件系统。**必须改 rootfs 目录再整盘重建** |
| 断线 | 我自己 `systemctl disable --now natrium-usb-gadget`，等于远程把自己的网线拔了。**远程运维别停承载通道的服务** |

### 仍然存在的问题
2. **运行几分钟后设备硬复位（不是 panic）**：`/sys/fs/pstore` 每次都是空的，而 `ramoops`
   已经注册成功（`pstore: Registered ramoops as persistent store backend`），说明**内核没有 panic**，
   是硬件级复位。两个候选：
   - **硬件看门狗**：`/sys/class/watchdog/` 是空的 —— `qcom-wdt` 是内建的，但一个看门狗设备都没注册。
     如果 ABL 启动时已经armed 了 APCS 看门狗，而内核侧驱动没绑定，就没有任何东西去喂它，到点就复位。
   - **电池瞬间掉压**：电池 34%、3.6 V，放电 256 mA（充电也是 256 mA），跑 pacman 这种负载时
     电流尖峰可能触发 PMIC 欠压保护。复位都发生在有负载的时候，符合这个特征。
   区分方法：**墙充充到 70% 以上再跑**。高电量下仍然复位 → 看门狗；不复位 → 电池掉压。
3. **一次可存活的 oops**（不致命）：

   ```
   WARNING: kernel/irq/manage.c:754 at enable_irq
   enable_irq → wled_ovp_work → process_scheduled_works
   ```

   是 PMI8994 背光（WLED）过压保护工作里的不配对 `enable_irq`，发生在加载 `leds-qcom-lcd` 之后。
   想彻底消掉，需要给 `qcom-wled` / `leds-qcom-lpg` 打补丁或改用其他背光路径。
4. **WiFi 关联不上**：ath10k 缺本机 `board-2.bin`（`failed to fetch board data`），
   用通用 board data 能扫描到 SSID 但关联失败。要修就得从原厂固件里提取 board 数据。
5. **手机没有出网**：PC 未做 NAT/ICS。已在 PC 上跑了一个极简 HTTP 代理
   （`tools/proxy.js`，监听 `0.0.0.0:3128`），手机侧设 `http_proxy=http://172.16.42.101:3128`
   即可让 pacman 通网，不需要改 IP、不需要 ICS。

## 四之三、P0 收尾状态（2026-10-25 16:15）

上面那节里几条已经过时，以这节为准：

| 项 | 现状 |
|---|---|
| pacman | ✅ **已可用**。先 `pacman-key --init && pacman-key --populate archlinuxarm`，再配代理即可装包（实测 `pacman -S htop` 成功） |
| 时钟 | ⚠️ RTC 无电池，每次冷启动都回到 1970/7 月。必须 `timedatectl set-ntp false; timedatectl set-time ...`，否则所有 TLS 都会报 "certificate is not yet valid" |
| 根文件系统 | ✅ 已在线扩到 **20 GB**（`resize2fs /dev/sda15 20G`），原先 3 GB 只剩 571 MB |
| 备份 | ✅ `arch/rootfs-backup.tar.gz`（839 MB，整机 tar） |
| 复位问题 | ❗**重新评估**：`journalctl --list-boots` 显示所有重启都落在手动刷机/按电源的时间窗里；当前这轮已连续运行 10+ 分钟无复位。**"看门狗定时咬"暂不成立**，不要把 DT 里的 qcom-wdt 当既成结论 |
| 供电 | ⚠️ 仍是硬约束：电池 34%、充电仅 ~256 mA，PC USB 口基本不升电。长时间作业前先墙充 |
| WiFi | ❌ ath10k 缺 `board-2.bin`，能扫到 SSID 但关联失败；用 USB 网络 + 代理已经够用 |
| WLED oops | ⚠️ 每次启动一次，不致命，暂不修 |

### 每次接管这台机器的标准动作

```bash
# PC 侧先起代理（后台）
node natrium-port/tools/proxy.js            # 监听 0.0.0.0:3128

# 手机侧（ssh root@172.16.42.1，密码 arch）
timedatectl set-ntp false
timedatectl set-time "$(date -u '+%Y-%m-%d %H:%M:%S')"   # 用 PC 的时间
export http_proxy=http://<PC的172.16.42.x>:3128
export https_proxy=$http_proxy

# 串口兜底（网络全挂了也能进）
#   Windows: COM13 (USB 串行设备) 115200 8N1
#   natrium-port/tools/serial-shell.ps1 -Port COM13 -Cmd "ip -brief addr"
```

## 五、P1 计划（P0 之后）

### 五之一、P1 已完成 / 卡住的地方（2026-10-25 16:20）

已完成：

| 项 | 状态 |
|---|---|
| GPU 固件 | ✅ `linux-firmware-qcom` 装上，`a530_pm4/pfp/gpmu.fw2` 全部加载成功 |
| Mesa | ✅ `mesa 26.2.5`，EGL 可用，Weston 选到了 XRGB8888 配置 |
| DRM 输出 | ✅ `DSI-1` connected，`fb0 msmdrmfb` 注册 |
| Weston | ✅ DRM 后端成功接管输出（说明 KMS/GPU 通路是通的） |
| phosh 套件 | ✅ `phosh 0.57 / phoc 0.57 / squeekboard 1.43` 已装 |
| logind/seat | ✅ seatd 正常，tty1 自动登录能建立 seat0 会话 |

**卡住的地方：`phoc`（wlroots）的每一个原子提交都返回 `-EBUSY`。**

```
phoc-wlroots-CRITICAL: [backend/drm/atomic.c:82] connector DSI-1:
  Atomic commit failed: Device or resource busy
```

排查记录：

- 没有任何进程持有 `/dev/dri/card0`（`fuser` 为空）
- 解绑 fbcon（`echo 0 > /sys/class/vtconsole/vtcon1/bind`）后仍然 EBUSY
- MDP 的 `pp done time out` 只在开机出现 2 次，phoc 运行期间**没有新增**，
  所以不是“提交超时未完成”这条路
- Weston 用自家 DRM 后端能出画面，phoc 用 wlroots 就失败

> **推测**：这块面板是 `sharp,td4722-xcmd`，`xcmd` = command mode DSI。
> 命令模式面板的提交要靠 TE 信号完成；如果 TE 没接对，原子提交就永远“未完成”，
> 后续提交全部 EBUSY。这需要动内核/面板侧（TE 中断、或改成 video mode），
> 不是用户态能解决的。

下一步（P1 续）：

1. 查 `panel-sharp-td4722-xcmd` 驱动的 TE 处理，和 pmOS 上能跑 phosh 的 msm8996 设备对比
2. 或者试 `WLR_DRM_NO_ATOMIC` 类兼容开关 / 更老的 phoc
3. 如果 phosh 短期修不好，可以先做 **Weston kiosk shell + 触摸**，至少有个能用的图形界面

### 五之二、phosh 实测记录（2026-10-25 16:30）

**已经做到**：phosh 会话能通过 tty1 自动登录 + logind 建立 seat0 会话，
`phoc` 成功拿到 DRM framebuffer（`/sys/kernel/debug/dri/0/state` 里
`fb=110 allocated by = phoc`），屏幕上出现 phoc 的启动动画。**说明合成器已经接管了屏幕。**

**仍然卡住**：之后每一个原子提交都返回 `EBUSY`，10 秒内 1500+ 次、2.5 分钟 19763 次：

```
phoc-wlroots-CRITICAL: [backend/drm/atomic.c:82] connector DSI-1:
  Atomic commit failed: Device or resource busy
```

已试过、**都无效**的开关/操作：

| 尝试 | 结果 |
|---|---|
| `echo 0 > /sys/class/vtconsole/vtcon1/bind`（解绑 fbcon） | 仍 EBUSY |
| `WLR_DRM_NO_MODIFIERS=1` | 仍 EBUSY（但 phoc 能拿到 fb 了） |
| `WLR_NO_HARDWARE_CURSORS=1` | 仍 EBUSY |
| `WLR_RENDERER=gles2` | 仍 EBUSY |
| 重启 `systemd-logind` / 修 `machine-id` / 起 `seatd` | 会话能起，EBUSY 不变 |
| 查 `fuser /dev/dri/card0` | 没有其他进程持有 |
| 开 `drm.debug=0x1ff` 抓内核侧原因 | **内核没有打印** `busy with a previous commit`，说明不是 DRM core 那三条检查 |
| 查 msm 驱动源码 | `msm_atomic.c` / `mdp5_*` / `dsi_*` 里**没有任何 `-EBUSY`** |

也就是说：`EBUSY` 的来源至今没定位到，既不是 DRM core 的 busy 检查，也不是 msm 驱动显式返回的。
Weston 用自家 DRM 后端能正常渲染，说明 KMS/GPU 本身没问题，问题只出在 wlroots 的提交路径上。

> 下一步建议（留给下一次会话）：
> 1. 用 `strace -f -e trace=ioctl` 抓 phoc 的 `DRM_IOCTL_MODE_ATOMIC` 返回值，确认是不是真的 EBUSY、哪个 flag 触发的
> 2. 对比 postmarketOS 给 msm8996 的 `phoc.ini` / wlroots 版本（Arch 的 phoc 0.57 可能太新）
> 3. 退一步：先做 Weston kiosk，保证有一个能用的图形界面

**strace 结果（16:30）**：跑 `strace -f -e trace=ioctl` 抓 phoc，整份日志里
**一条 `DRM_IOCTL_MODE_ATOMIC` 都没有**，说明 phoc 在 strace 下更早就退出了。
同时看到 `DRM_IOCTL_AUTH_MAGIC = -1 EINVAL`。

结论：`EBUSY` 的来源仍然没定位到（内核没打印 busy 检查、msm 驱动没有 `-EBUSY`、
strace 里连原子提交都没发出去）。这条线需要单独一整段时间来查，不适合在长时间会话末尾硬啃。

### 五之三、可行的图形方案：Xorg + i3 + onboard（2026-10-25 16:40，**已跑通**）

**phosh 走不通之后，绕开 wlroots 用 X11，一次成功。**

```
Xorg :0 -keeptty vt1          ← X11 modesetting，走自家 DRM 路径
i3 / i3bar / i3status         ← 平铺 WM + 状态栏
xterm -fs 20                  ← 大字号终端
onboard --layout=Phone        ← 屏幕键盘，i3 规则固定在底部 1080x420
libinput: Synaptics TD4722B7 → is tagged by udev as: Touchscreen ✅
```

截图确认：顶栏有磁盘/内存/时间，中间是大字号终端，底部是完整 QWERTY 屏幕键盘，
**触摸点击可用**。

关键配置：

| 文件 | 作用 |
|---|---|
| `~/.xinitrc` | `dbus-run-session -- i3`（onboard 需要会话总线） |
| `~/.Xresources` | `Xft.dpi: 260`、xterm faceSize 18 |
| `~/.config/i3/config` | 启动 onboard/xterm；`for_window [class="Onboard"]` 固定到底部 |
| `~/.config/i3status/config` | 磁盘/内存/时间（电池模块因节点名叫 `qcom-battery` 而跳过） |
| `getty@tty1` drop-in | 自动登录 arch → `startx` |

坑：

- `onboard` 必须要**会话 D-Bus**，否则报 `org.freedesktop.DBus.Error.NotSupported`；
  用 `dbus-run-session -- i3` 解决
- ALARM 仓库里没有 `xvkbd` / `matchbox-keyboard` / `svkbd` / `florence`，**只有 onboard**
- i3status 的 `battery` 模块要求 `path` 里有 `%d` 占位，`qcom-battery` 这种无编号节点无法直接用

**这条路线与 phosh 完全解耦**：X11 不用 wlroots，所以不受那个 EBUSY 影响。
如果以后修好 phosh，两者可以共存（不同 VT）。



1. 内核做成 Arch 包（`PKGBUILD`，基于 msm8996-mainline + 面板补丁），`pacman -Syu` 不会换掉内核
2. GPU：Mesa + freedreno a530 + zap shader
3. 桌面：sway 或 phosh（1080p 下 scale 2.5）
4. WiFi：ath10k + board-2.bin + firmware
5. 音频（耳机口）、电量计、USB OTG

相机 / 蜂窝 / GPS / 传感器 / 红外：主线驱动缺失，别指望。
