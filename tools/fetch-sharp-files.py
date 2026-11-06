import difflib
import json
import os
import urllib.parse
import urllib.request

FORK = "AlecJY/msm8996-mainline-linux"
UP = "msm8996-mainline/linux"
REF_OLD = "natrium-sharp-panel"
REF_NEW = "msm8996-stable-6.19.y"
OUT = r"natrium-port\build\pmos-ref"
os.makedirs(OUT, exist_ok=True)


def api(proj, path, t=120):
    url = "https://gitlab.com/api/v4/projects/%s%s" % (urllib.parse.quote(proj, safe=""), path)
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "curl/8.0"}), timeout=t)
        return r.read().decode("utf-8", "replace")
    except Exception as e:
        return None


def get_file(proj, path, ref):
    return api(proj, "/repository/files/%s/raw?ref=%s" % (urllib.parse.quote(path, safe=""), urllib.parse.quote(ref, safe="")))


print("=== 1) 抓取 Sharp 面板驱动 ===")
src = get_file(FORK, "drivers/gpu/drm/panel/panel-sharp-td4722-xcmd.c", REF_OLD)
if src:
    p = os.path.join(OUT, "panel-sharp-td4722-xcmd.c")
    open(p, "w", encoding="utf-8", newline="\n").write(src)
    print("  ✅ %d bytes -> %s" % (len(src), p))
    for kw in ("compatible", "MODULE_", "drm_panel_init", "backlight", "prepare(", "unprepare(", "enable(", "disable("):
        for line in src.splitlines():
            if kw in line:
                print("     %s" % line.strip()[:120])
                break
else:
    print("  ✗ 抓取失败")

print()
print("=== 2) 设备树对比（2022 sharp 分支 vs 官方 6.19.y）===")
old = get_file(FORK, "arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts", REF_OLD)
new = get_file(UP, "arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts", REF_NEW)
if old and new:
    for name, txt in (("old-2022.dts", old), ("new-619.dts", new)):
        open(os.path.join(OUT, name), "w", encoding="utf-8", newline="\n").write(txt)
    print("  行数: 2022=%d  6.19=%d" % (len(old.splitlines()), len(new.splitlines())))
    print("  --- 与面板/DSI/背光/触摸相关的行（2022 sharp 分支）---")
    for i, l in enumerate(old.splitlines()):
        if any(k in l for k in ("td4722", "r63452", "panel@", "panel =", "compatible", "backlight", "touchscreen", "vdd", "vcca", "vdda")):
            s = l.strip()
            if s and not s.startswith("//"):
                print("     %4d| %s" % (i + 1, s[:130]))
else:
    print("  获取失败 old=%s new=%s" % (bool(old), bool(new)))

print()
print("=== 3) 官方 6.19.y 的对应行（对照）===")
if new:
    for i, l in enumerate(new.splitlines()):
        if any(k in l for k in ("td4722", "r63452", "panel@", "compatible", "backlight", "touchscreen")):
            s = l.strip()
            if s and not s.startswith("//"):
                print("     %4d| %s" % (i + 1, s[:130]))
