import hashlib
import os
import sys
import urllib.request

# mirrorbits 对带 Range 头 / 浏览器 UA 的请求返回 403；用 curl UA 普通 GET 即可，且不用 Range
URL = ("http://mirrorbits.lineageos.org/full/natrium/20261004/"
       "lineage-22.2-20261004-nightly-natrium-signed.zip")
WANT_SIZE = 995123443
WANT_SHA256 = "8c40047299c800738c1f22f206799167cf55c08aaa0a0ac4af8bfebbb7f65fe9"
DEST = r"natrium-port\lineage-ota\lineage-22.2-20261004-nightly-natrium-signed.zip"


def verify(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(1 << 22)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


os.makedirs(os.path.dirname(DEST), exist_ok=True)
if os.path.exists(DEST) and os.path.getsize(DEST) == WANT_SIZE:
    d = verify(DEST)
    print("已存在且大小正确；sha256 =", d, "->", "匹配 ✅" if d == WANT_SHA256 else "不匹配 ❌")
    sys.exit(0 if d == WANT_SHA256 else 2)

req = urllib.request.Request(URL, headers={
    "User-Agent": "curl/8.0",
    "Accept": "*/*",
})
with urllib.request.urlopen(req, timeout=180) as r:
    total = int(r.headers.get("Content-Length") or 0)
    print("下载 %s\n声明大小 %.1f MB（期望 %d）" % (URL, total / 2**20, WANT_SIZE), flush=True)
    done = 0
    with open(DEST + ".part", "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if done % (128 << 20) < (1 << 20):
                print("  %.1f / %.1f MB" % (done / 2**20, total / 2**20), flush=True)
os.replace(DEST + ".part", DEST)
size = os.path.getsize(DEST)
digest = verify(DEST)
print("完成：%d 字节 (期望 %d) %s" % (size, WANT_SIZE, "✅" if size == WANT_SIZE else "❌"))
print("sha256: %s %s" % (digest, "✅ 与官方一致" if digest == WANT_SHA256 else "❌ 与官方不一致"))
