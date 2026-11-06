import json
import urllib.parse
import urllib.request


def api(proj, path, timeout=90):
    url = "https://gitlab.com/api/v4/projects/%s%s" % (urllib.parse.quote(proj, safe=""), path)
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "curl/8.0"}), timeout=timeout)
        return json.load(r)
    except Exception as e:
        return {"error": str(e)}


print("=== 1) AlecJY/msm8996-mainline-linux 的分支 ===")
d = api("AlecJY/msm8996-mainline-linux", "/repository/branches?per_page=100")
if isinstance(d, list):
    for b in d:
        c = b.get("commit", {})
        print("  %-34s %s  %s" % (b["name"], c.get("committed_date", "")[:10], (c.get("title") or "")[:70]))
else:
    print("  ", d)

print()
print("=== 2) AlecJY/pmaports 的分支 ===")
d = api("AlecJY/pmaports", "/repository/branches?per_page=100")
if isinstance(d, list):
    for b in d:
        c = b.get("commit", {})
        print("  %-34s %s  %s" % (b["name"], c.get("committed_date", "")[:10], (c.get("title") or "")[:70]))
else:
    print("  ", d)

print()
print("=== 3) 内核分支 natrium-sharp-panel 的关键文件 ===")
for branch in ["natrium-sharp-panel"]:
    for f in ["arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts",
              "arch/arm64/boot/dts/qcom/msm8996-xiaomi-common.dtsi",
              "drivers/gpu/drm/panel/panel-sharp-td4722.c",
              "Makefile"]:
        d = api("AlecJY/msm8996-mainline-linux", "/repository/files/%s/raw?ref=%s" % (urllib.parse.quote(f, safe=""), branch))
        if isinstance(d, str):
            print("  找到 %s (%d bytes)" % (f, len(d)))
        else:
            print("  无   %s" % f)

print()
print("=== 4) 内核分支里搜 td4722 / sharp 相关文件（列目录）===")
d = api("AlecJY/msm8996-mainline-linux", "/repository/tree?ref=natrium-sharp-panel&path=drivers/gpu/drm/panel&per_page=100")
if isinstance(d, list):
    for x in d:
        if "sharp" in x["name"] or "r63452" in x["name"] or "jdi" in x["name"]:
            print("   ", x["name"])
else:
    print("  ", d)

print()
print("=== 5) 该分支与官方 6.19.5 的差异提交（最近 10 条）===")
d = api("AlecJY/msm8996-mainline-linux", "/repository/commits?ref_name=natrium-sharp-panel&per_page=10")
if isinstance(d, list):
    for c in d:
        print("  %s  %s  %s" % (c["short_id"], c["committed_date"][:10], c["title"][:80]))
else:
    print("  ", d)
