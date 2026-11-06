import json
import urllib.parse
import urllib.request

FORK = "AlecJY/msm8996-mainline-linux"
UP = "msm8996-mainline/linux"


def api(proj, path, timeout=90):
    url = "https://gitlab.com/api/v4/projects/%s%s" % (urllib.parse.quote(proj, safe=""), path)
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "curl/8.0"}), timeout=timeout)
        return json.load(r)
    except Exception as e:
        return {"error": str(e)}


def raw(proj, path, ref):
    return api(proj, "/repository/files/%s/raw?ref=%s" % (urllib.parse.quote(path, safe=""), urllib.parse.quote(ref, safe="")))


print("=== 1) 2022 分支 natrium-sharp-panel 相对其上游改了哪些文件 ===")
d = api(FORK, "/repository/compare?from=msm8996-stable-5.17.y&to=natrium-sharp-panel")
if isinstance(d, dict) and "diffs" in d:
    for diff in d["diffs"]:
        print("  %-70s +%s -%s" % (diff.get("new_path"), diff.get("diff", "").count("\n+"), diff.get("diff", "").count("\n-")))
else:
    print("  compare 失败:", d)

print()
print("=== 2) 面板驱动文件（该分支 drivers/gpu/drm/panel 下）===")
d = api(FORK, "/repository/tree?ref=natrium-sharp-panel&path=drivers/gpu/drm/panel&per_page=100")
if isinstance(d, list):
    for x in d:
        if any(k in x["name"] for k in ("td4722", "r63452", "sharp", "jdi")):
            print("  -", x["name"])
else:
    print("  ", d)

print()
print("=== 3) 抓取驱动源码 ===")
for cand in ["drivers/gpu/drm/panel/panel-sharp-td4722.c",
             "drivers/gpu/drm/panel/panel-jdi-r63452.c",
             "drivers/gpu/drm/panel/panel-sharp-td4722-xcmd.c"]:
    t = raw(FORK, cand, "natrium-sharp-panel")
    if isinstance(t, str):
        out = "natrium-port/build/pmos-ref/" + cand.split("/")[-1]
        open(out, "w", encoding="utf-8", newline="\n").write(t)
        print("  ✅ %s (%d bytes) -> %s" % (cand, len(t), out))
    else:
        print("  ✗ %s" % cand)

print()
print("=== 4) 当前官方树里有没有 td4722 面板驱动（6.19.5 分支）===")
for ref in ["msm8996-stable-6.19.y", "v6.19.5-msm8996"]:
    d = api(UP, "/repository/tree?ref=%s&path=drivers/gpu/drm/panel&per_page=100" % urllib.parse.quote(ref, safe=""))
    if isinstance(d, list):
        hits = [x["name"] for x in d if any(k in x["name"] for k in ("td4722", "r63452", "sharp"))]
        print("  ref=%s -> %s" % (ref, hits if hits else "无 sharp/td4722/r63452"))
    else:
        print("  ref=%s -> %s" % (ref, d))

print()
print("=== 5) 该分支的 DTS 与官方新版 DTS 的差异行数 ===")
d_old = raw(FORK, "arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts", "natrium-sharp-panel")
d_new = raw(UP, "arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts", "msm8996-stable-6.19.y")
for name, txt in (("2022 sharp 分支", d_old), ("官方 6.19.y", d_new)):
    if isinstance(txt, str):
        lines = txt.splitlines()
        print("  %-16s %d 行" % (name, len(lines)))
        for i, l in enumerate(lines):
            if any(k in l for k in ("panel", "td4722", "r63452", "dsi", "backlight", "touchscreen")):
                print("      %4d| %s" % (i + 1, l.rstrip()[:120]))
    else:
        print("  %-16s 获取失败" % name)
