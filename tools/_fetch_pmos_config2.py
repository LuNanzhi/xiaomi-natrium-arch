import base64
import json
import os
import urllib.parse
import urllib.request

OUT = r"natrium-port\build\pmos-ref"
os.makedirs(OUT, exist_ok=True)

DIR = "device/community/linux-postmarketos-qcom-msm8996"
COMMITS = ["e8519a8a91e278170aa00474e0e9b44cab23d42b",
           "02aad8d342ffe1fd4c29af3d709f687619b98f83"]
HOSTS = ["https://gitlab.postmarketos.org", "https://gitlab.com"]
BRANCHES = ["main", "master", "v25.12"]


def fetch_raw(host, ref, name):
    url = "%s/postmarketOS/pmaports/-/raw/%s/%s/%s" % (host, ref, DIR, name)
    try:
        return urllib.request.urlopen(url, timeout=90).read()
    except Exception as e:
        return None


print("=== 尝试各种 URL 组合拿 APKBUILD ===")
apkbuild = None
for host in HOSTS:
    for ref in COMMITS + BRANCHES:
        d = fetch_raw(host, ref, "APKBUILD")
        if d and len(d) > 200:
            print("  OK: %s @ %s (%d bytes)" % (host, ref[:12], len(d)))
            apkbuild = d
            open(os.path.join(OUT, "APKBUILD.pmos"), "wb").write(d)
            break
    if apkbuild:
        break

if not apkbuild:
    print("  全部失败")
    raise SystemExit(1)

txt = apkbuild.decode("utf-8", "replace")
print()
print("=== APKBUILD 关键行 ===")
for line in txt.splitlines():
    if any(k in line for k in ("pkgver", "pkgrel", "source=", "config", "_commit", "upstream", "url=", "install=")):
        print("  " + line.strip()[:150])

# 找配置文件名
import re
cfg_names = set(re.findall(r"[\w\-\.]*config[\w\-\.]*", txt))
cfg_names |= {"config-postmarketos-qcom-msm8996.aarch64"}
print()
print("=== 候选配置文件: %s ===" % sorted(cfg_names))
got = False
for host in HOSTS:
    for ref in COMMITS + BRANCHES:
        for name in sorted(cfg_names):
            if not name.endswith((".aarch64", ".config")):
                continue
            d = fetch_raw(host, ref, name)
            if d and len(d) > 5000:
                p = os.path.join(OUT, name)
                open(p, "wb").write(d)
                print("  下载成功: %s @ %s/%s -> %d bytes" % (name, host, ref[:12], len(d)))
                got = True
                break
        if got:
            break
    if got:
        break

if not got:
    print("  没拿到配置文件")
