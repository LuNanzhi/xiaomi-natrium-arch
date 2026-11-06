import gzip
import io
import os
import tarfile
import urllib.request

BASE = "https://mirror.postmarketos.org/postmarketos/v25.12/aarch64/"
PKG = "device-xiaomi-natrium-3-r0.apk"
OUT = r"natrium-port\build\pmos-ref"
os.makedirs(OUT, exist_ok=True)

p = os.path.join(OUT, PKG)
if not os.path.exists(p):
    print("下载", BASE + PKG)
    d = urllib.request.urlopen(BASE + PKG, timeout=180).read()
    open(p, "wb").write(d)
    print("  %.1f MB" % (len(d) / 2**20))
else:
    d = open(p, "rb").read()
    print("已有 %.1f MB" % (len(d) / 2**20))

raw = gzip.decompress(d)
pos, idx = 0, 0
while pos < len(raw) - 1024 and idx < 8:
    try:
        tf = tarfile.open(fileobj=io.BytesIO(raw[pos:]), mode="r:")
    except Exception:
        break
    if not tf.getnames():
        break
    idx += 1
    for m in tf.getmembers():
        if not m.isfile():
            continue
        low = m.name.lower()
        if "deviceinfo" in low or "bootimg" in low or m.name.endswith("deviceinfo"):
            body = tf.extractfile(m).read()
            name = os.path.basename(m.name)
            open(os.path.join(OUT, "pmos-" + name), "wb").write(body)
            print("\n===== %s (%d bytes) =====" % (m.name, len(body)))
            txt = body.decode("utf-8", "replace")
            for line in txt.splitlines():
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                if any(k in s for k in ("bootimg", "kernel", "cmdline", "dtb", "pagesize", "page_size",
                                        "base", "offset", "header", "arch", "codename", "name",
                                        "flash", "partition", "rootfs", "append")):
                    print("   " + s[:150])
    pos += tf.offset
