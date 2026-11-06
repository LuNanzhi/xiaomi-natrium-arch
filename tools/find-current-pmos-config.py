import json
import urllib.parse
import urllib.request

PROJ = urllib.parse.quote("postmarketOS/pmaports", safe="")
BASE = "https://gitlab.postmarketos.org/api/v4/projects/" + PROJ


def api(path, timeout=90):
    try:
        return json.load(urllib.request.urlopen(BASE + path, timeout=timeout))
    except Exception as e:
        return {"error": str(e)}


print("=== 1) 项目里的默认分支 ===")
p = api("")
if isinstance(p, dict) and "error" not in p:
    print("  default_branch =", p.get("default_branch"))
    db = p.get("default_branch")
else:
    print("  ", p)
    db = "main"

print("\n=== 2) 搜索 contains 'linux-postmarketos-qcom-msm8996' 的路径 ===")
found = []
for scope_path in ["device", "device/community", "device/testing", "main"]:
    for page in range(1, 6):
        t = api("/repository/tree?path=%s&per_page=100&page=%d" % (urllib.parse.quote(scope_path, safe=""), page))
        if not isinstance(t, list) or not t:
            break
        for x in t:
            if "msm8996" in x["name"] or "msm8996" in x["path"]:
                found.append(x["path"])
        if len(t) < 100:
            break
print("  命中:", found if found else "无")

print("\n=== 3) 直接试候选路径下的文件 ===")
CANDS = found + [
    "device/community/linux-postmarketos-qcom-msm8996",
    "device/testing/linux-postmarketos-qcom-msm8996",
]
for d in CANDS:
    for name in ["APKBUILD", "config-postmarketos-qcom-msm8996.aarch64"]:
        r = api("/repository/files/%s/raw?ref=%s" % (urllib.parse.quote(d + "/" + name, safe=""), db))
        if isinstance(r, str) and len(r) > 300:
            print("  命中: %s/%s  (%d bytes)" % (d, name, len(r)))
            open("natrium-port/build/pmos-ref/" + name + ".current", "w", encoding="utf-8", newline="\n").write(r)
            break
    else:
        continue
    break
