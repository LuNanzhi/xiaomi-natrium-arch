# postmarketOS 线刷包使用说明（小米 5s Plus / natrium）

> 产物位置：`C:\Users\Public\natrium\pmos\`
> 构建方式：pmbootstrap 3.12.0 + pmaports（`device/archived/device-xiaomi-natrium`）
> 内核：`msm8996-mainline` v6.19.5-msm8996 + **Sharp TD4722 面板补丁**（本机自行为该面板补的）
> 界面：**Phosh**（触摸界面）

---

## 一、包内文件（已实测校验）

| 文件 | 大小 | 刷到哪个分区 | 是否破坏数据 | 校验结果 |
|---|---|---|---|---|
| `boot.img` | 24 MB | `boot` | ❌ 不破坏（可随时换） | v0 / page 4096 / 内核地址 0x80008000 / initramfs 0x81000000 / tags 0x80000100 ✓；内核内 DTB **含 `sharp,td4722-xcmd`** ✓；initramfs **含 `panel-sharp-td4722-xcmd.ko`** ✓ |
| `root.img` | 2.8 GB | `userdata` | ⚠️ **会清空全部 Android 数据** | ext4 ✓；pmOS「Nura edge」✓；`/usr/lib/phosh` + `phosh.desktop`（Phosh 触摸界面）✓；`lib/modules/6.19.5/.../panel-sharp-td4722-xcmd.ko.zst` ✓；固件 adsp/mba/modem/slpi/venus/a530_zap ✓；用户 `user`（密码 `1234`）✓ |
| `initramfs` / `vmlinuz` | 13 MB / 11 MB | — | — | 备用（不进分区，仅便于排查） |

> 注意：**只有这两个文件需要刷**。`boot.img` 里已含内核 + 设备树 + initramfs，`root.img` 是完整系统分区。

## 二、刷写前必做

```powershell
# 备份 Android 数据（照片/短信/通话记录/应用列表）到 C:\Users\Public\natrium\android-backup
powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\backup-android-data.ps1
```
**备份完请把 `android-backup` 文件夹拷到外部盘/U 盘。** 刷了 rootfs 之后，Android 需要整机重装才能恢复（我们的 `lineage-boot-rollback.img` 只能恢复 `boot` 分区）。

## 三、刷写

手机先进 fastboot：**长按电源 15 秒关机 → 按住「音量减 + 电源」**。

```powershell
# 一键（会要求输入 WIPE 确认，之后才会动数据分区）
powershell -ExecutionPolicy Bypass -File C:\Users\Public\natrium\flash-pmos.ps1 -Rootfs

# 或手动两步
cd F:\platform-tools
.\fastboot flash boot C:\Users\Public\natrium\pmos\boot-sharp.img
.\fastboot flash userdata C:\Users\Public\natrium\pmos\natrium.img
.\fastboot reboot
```

## 四、首次启动

- 第一次开机较慢（systemd 首启配置），**给 3~5 分钟**
- 正常情况：屏幕亮起 → 出现 Phosh 界面（锁屏）
- 如果**屏幕全程黑但手机在运行**：说明面板补丁未生效或面板型号不符 → 见下一节，系统仍可通过 SSH 使用

## 五、屏幕黑也能进系统（重要）

pmOS 会在 USB 上拉起网络（RNDIS），所以：

1. 插着 USB 线，等 1~2 分钟
2. 电脑上会出现一个**新网卡**（名字类似「USB Ethernet/RNDIS」）
3. 然后：
   ```powershell
   ssh user@172.16.42.1      # 密码: 1234
   ```
4. 进去后可以查显示状态：
   ```sh
   dmesg | grep -iE 'panel|dsi|drm'
   ls /sys/class/drm/
   ```
   把输出发我，我就能定位是面板、供电还是时序的问题。

## 六、回滚

```powershell
# 只恢复 boot 分区（系统仍是 pmOS 或无法启动）
cd F:\platform-tools
.\fastboot flash boot C:\Users\Public\natrium\lineage-boot-rollback.img
```
> 注意：`userdata` 被 pmOS 覆盖后，LineageOS 即使恢复了 boot 也需要**重新刷入 LineageOS 完整包**（会丢失原数据）。

## 七、构建信息（便于复现）

| 项目 | 值 |
|---|---|
| pmbootstrap | 3.12.0（git: `gitlab.postmarketos.org/postmarketOS/pmbootstrap`） |
| pmaports | `main`（含 `device/archived/device-xiaomi-natrium`） |
| 内核源码 | `gitlab.com/msm8996-mainline/linux` tag `v6.19.5-msm8996` |
| 面板补丁 | `panel-sharp-td4722-xcmd.c`（取自 AlecJY `natrium-sharp-panel` 分支，已前移：`remove()` 改为 `void` 以适配 6.1+ API） |
| 设备树改动 | `msm8996pro-xiaomi-natrium.dts`：面板 `compatible` 改为 `sharp,td4722-xcmd` |
| 内核配置 | 追加 `CONFIG_DRM_PANEL_SHARP_TD4722_XCMD=y` |
| 软件源 | pmOS: `mirror.nju.edu.cn`（1.37 MB/s）；Alpine: `mirrors.tuna.tsinghua.edu.cn`（10.9 MB/s） |

## 八、已知限制（来自 pmOS 官方 wiki）

- 蜂窝数据、相机、GPS、传感器、IR：**不可用**
- WiFi：不稳定、信号弱
- 内置扬声器/麦克风不可用（耳机口可用）
- 该设备在 pmOS 中已被**归档**，官方不再测试；本次是我们自行补齐面板支持后构建的
