import gzip
import io
import json
import os
import re
import tarfile
import urllib.parse
import urllib.request

OUT = r"natrium-port\build\pmos-ref"
os.makedirs(OUT, exist_ok=True)

# ---------- 1) msm8996-mainline 树里有哪些 arm64 配置 ----------
print("=== msm8996-mainline: arch/arm64/configs ===")
u = ("https://gitlab.com/api/v4/projects/msm8996-mainline%2Flinux/repository/tree"
     "?path=arch/arm64/configs&ref=v6.18.7-msm8996&per_page=100")
try:
    for x in json.load(urllib.request.urlopen(u, timeout=60)):
        print("  ", x["name"])
except Exception as e:
    print("  ERR", e)

# ---------- 2) 从 pmOS 镜像找内核包 ----------
print("\n=== 在 pmOS 镜像里找 linux-postmarketos-qcom-msm8996 包 ===")
apk = None
for base in ["https://mirror.postmarketos.org/postmarketos/main/aarch64/",
             "https://mirror.postmarketos.org/postmarketos/v25.12/aarch64/"]:
    try:
        t = urllib.request.urlopen(base, timeout=120).read().decode("utf-8", "replace")
        hits = sorted(set(re.findall(r'href="(linux-postmarketos-qcom-msm8996[^"]*\.apk)"', t)))
        print("  ", base, "->", hits[:4] if hits else "无")
        if hits and not apk:
            apk = base + hits[0]
            break
    except Exception as e:
        print("  ", base, "ERR", e)

if not apk:
    print("  没找到内核包，退出")
    raise SystemExit(0)

# ---------- 3) 下载并从包里抽出 config ----------
print("\n=== 下载并抽取 config ===")
print("  ", apk)
data = urllib.request.urlopen(apk, timeout=300).read()
print("  包大小 %.1f MB" % (len(data) / 2**20))
raw = gzip.decompress(data)
pos, found, idx = 0, [], 0
while pos < len(raw) - 1024 and idx < 8:
    try:
        tf = tarfile.open(fileobj=io.BytesIO(raw[pos:]), mode="r:")
    except Exception:
        break
    names = tf.getnames()
    if not names:
        break
    idx += 1
    for m in tf.getmembers():
        if m.isfile() and re.search(r"(^|/)config", m.name):
            body = tf.extractfile(m).read()
            name = os.path.join(OUT, "pmos-" + os.path.basename(m.name))
            open(name, "wb").write(body)
            found.append((m.name, len(body), name))
    pos += tf.offset
for n, ln, p in found:
    print("  抽出 %-50s %6d bytes -> %s" % (n, ln, p))
if not found:
    print("  包里没有 config 文件；列出包内文件片段：")
    tf = tarfile.open(fileobj=io.BytesIO(raw), mode="r:")
    for n in sorted(tf.getnames())[:25]:
        print("    ", n)
