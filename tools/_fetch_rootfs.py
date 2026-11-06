import os
import sys
import urllib.request

URL = "https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz"
DEST = r"natrium-port\build\rootfs\ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz"
os.makedirs(os.path.dirname(DEST), exist_ok=True)
if os.path.exists(DEST) and os.path.getsize(DEST) > 100 * 1024 * 1024:
    print("已存在，跳过下载:", DEST, os.path.getsize(DEST))
    sys.exit(0)

req = urllib.request.Request(URL)
with urllib.request.urlopen(req, timeout=120) as r:
    total = int(r.headers.get("Content-Length", 0))
    print("开始下载", URL, "大小 %.1f MB" % (total / 2**20))
    done = 0
    with open(DEST + ".part", "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if done % (32 << 20) < (1 << 20):
                print("  %.1f / %.1f MB" % (done / 2**20, total / 2**20), flush=True)
os.replace(DEST + ".part", DEST)
print("完成:", DEST, os.path.getsize(DEST), "bytes")
