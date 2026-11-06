import gzip
import io
import os
import re
import tarfile
import urllib.request

APK = ("https://mirror.postmarketos.org/postmarketos/main/aarch64/"
       "linux-postmarketos-qcom-msm8996-6.19.5-r0.apk")
OUT = r"natrium-port\build\pmos-ref"
os.makedirs(OUT, exist_ok=True)

apk_path = os.path.join(OUT, "linux-postmarketos-qcom-msm8996-6.19.5-r0.apk")
if not os.path.exists(apk_path):
    print("下载内核包 ...")
    data = urllib.request.urlopen(APK, timeout=600).read()
    open(apk_path, "wb").write(data)
    print("  %.1f MB" % (len(data) / 2**20))
else:
    data = open(apk_path, "rb").read()
    print("已有内核包 %.1f MB" % (len(data) / 2**20))

raw = gzip.decompress(data)
pos, idx, extracted = 0, 0, []
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
        base = os.path.basename(m.name)
        want = ("msm8996" in m.name and (m.name.endswith(".dtb"))) or base in ("vmlinuz", "config", "System.map")
        if want:
            body = tf.extractfile(m).read()
            p = os.path.join(OUT, base)
            open(p, "wb").write(body)
            extracted.append((m.name, len(body), p))
    pos += tf.offset

print("\n=== 抽出的 msm8996 相关文件 ===")
for n, ln, p in sorted(extracted, key=lambda x: x[0]):
    print("  %-58s %9d bytes" % (n, ln))

# 看看内核版本串
vk = os.path.join(OUT, "vmlinuz")
if os.path.exists(vk):
    b = open(vk, "rb").read(4 << 20)
    for m in re.finditer(rb"Linux version [0-9][^\x00]{0,120}", b):
        print("\n  内核版本串:", m.group(0).decode("utf-8", "replace"))
        break
