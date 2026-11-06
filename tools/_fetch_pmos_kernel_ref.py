import base64
import json
import os
import urllib.parse
import urllib.request

PROJ = urllib.parse.quote("postmarketOS/pmaports", safe="")
DIR = "device/community/linux-postmarketos-qcom-msm8996"
OUT = r"natrium-port\build\pmos-ref"


def api(path, timeout=90):
    u = "https://gitlab.postmarketos.org/api/v4/projects/%s%s" % (PROJ, path)
    try:
        return json.load(urllib.request.urlopen(u, timeout=timeout))
    except Exception as e:
        return {"error": str(e)}


os.makedirs(OUT, exist_ok=True)
print("=== 目录文件列表 ===")
t = api("/repository/tree?path=%s&per_page=100" % urllib.parse.quote(DIR, safe=""))
if isinstance(t, list):
    for x in t:
        print("  ", x["type"], x["name"])
else:
    print("  ", t)

print("\n=== 下载文件 ===")
for ref in ("main", "master"):
    for name in ("APKBUILD", "config-postmarketos-qcom-msm8996.aarch64"):
        p = "/repository/files/%s/raw?ref=%s" % (urllib.parse.quote(DIR + "/" + name, safe=""), ref)
        r = api(p)
        if isinstance(r, dict) and "error" in r:
            print("  %-46s ref=%-7s -> %s" % (name, ref, r["error"]))
            continue
        try:
            data = base64.b64decode(r["content"]) if isinstance(r, dict) and "content" in r else r.encode()
        except Exception:
            data = str(r).encode()
        path = os.path.join(OUT, name if ref == "main" else name + "." + ref)
        open(path, "wb").write(data)
        print("  %-46s ref=%-7s -> %d bytes 存为 %s" % (name, ref, len(data), os.path.basename(path)))
        if name == "APKBUILD" and len(data) > 100:
            txt = data.decode("utf-8", "replace")
            for line in txt.splitlines():
                if any(k in line for k in ("pkgver", "pkgrel", "_commit", "source=", "_config", "config_", "upstream")):
                    print("      | " + line.strip()[:140])
