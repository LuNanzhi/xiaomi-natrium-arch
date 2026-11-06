#!/usr/bin/env bash
# 路线 B 第二步：确认刷写目标分区、可选 GUI、以及 Sharp 面板分支是否存在
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py

echo "=== A) fastboot 刷写会写到哪些分区（安全关键）==="
grep -rn "fastboot flash" /root/pmbootstrap/pmb/ 2>/dev/null | head -12
echo "--- flasher 里与 rootfs/kernel 目标分区相关的代码 ---"
grep -rn "partition_system\|partition_kernel\|userdata" /root/pmbootstrap/pmb/flasher/*.py /root/pmbootstrap/pmb/config/*.py 2>/dev/null | head -20

echo
echo "=== B) 设备包里的关键设置 ==="
grep -E 'deviceinfo_(flash_method|flash_fastboot|bootimg|generate_bootimg|append_dtb|dtb|kernel_cmdline|ui|usb_network)' \
  /root/pmaports/device/archived/device-xiaomi-natrium/deviceinfo 2>/dev/null

echo
echo "=== C) 可用 UI 列表（含触摸界面的）==="
python3 "$PB" --as-root init --help 2>&1 | head -5
grep -rn "phosh\|plasma-mobile" /root/pmaports/main/postmarketos-ui-phosh/APKBUILD 2>/dev/null | head -3
ls /root/pmaports/main/ 2>/dev/null | grep -E '^postmarketos-ui-' | head -25

echo
echo "=== D) 是否有 Sharp 面板专用内核分支（用户机器 ABL 传的是 sharp_fhd_td4722）==="
python3 - <<'PY'
import json, urllib.request, urllib.parse
def api(url):
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent":"curl/8.0"}), timeout=60)
        return json.load(r)
    except Exception as e:
        return {"error": str(e)}

proj = urllib.parse.quote("msm8996-mainline/linux", safe="")
d = api("https://gitlab.com/api/v4/projects/%s/repository/branches?per_page=100" % proj)
if isinstance(d, list):
    names = [b["name"] for b in d]
    print("  msm8996-mainline/linux 分支共 %d 个；含 natrium/sharp 的：" % len(names))
    for n in names:
        if "natrium" in n.lower() or "sharp" in n.lower():
            print("   -", n)
    print("  全部:", ", ".join(names[:20]))
else:
    print("  查询失败:", d)
PY

echo
echo "=== E) 当前 pmbootstrap 配置 ==="
python3 "$PB" --as-root config 2>&1 | head -20
