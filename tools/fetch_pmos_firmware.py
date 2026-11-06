"""从 postmarketOS 镜像下载 firmware-xiaomi-natrium 包并解出 mainline 需要的固件文件。

.apk 是「多个 gzip 成员拼接的 tar」，Python 的 gzip.decompress 会全部解出；
随后按 tar 归档边界逐个读取（第一个是签名，第二个是 control，第三个是 data）。
"""
import gzip
import io
import os
import sys
import tarfile
import urllib.request

BASE = "https://mirror.postmarketos.org/postmarketos/v25.12/aarch64/"
PKG = "firmware-xiaomi-natrium-1-r0.apk"
DEST = "natrium-port/firmware"


def main():
    os.makedirs(os.path.dirname(DEST + "/x"), exist_ok=True)
    apk = os.path.join("natrium-port", "build", "rootfs", PKG)
    if not os.path.exists(apk):
        url = BASE + PKG
        print("下载", url)
        data = urllib.request.urlopen(url, timeout=300).read()
        open(apk, "wb").write(data)
        print("  %.2f MB" % (len(data) / 2**20))
    else:
        data = open(apk, "rb").read()
        print("已存在", apk, "%.2f MB" % (len(data) / 2**20))

    raw = gzip.decompress(data)
    print("解压后 %d 字节（多 tar 拼接）" % len(raw))

    # 逐段读取 tar 归档
    pos, idx, files = 0, 0, []
    while pos < len(raw) - 1024:
        try:
            f = io.BytesIO(raw[pos:])
            tf = tarfile.open(fileobj=f, mode="r:")
        except Exception as e:
            print("  段 %d 解析结束 (%s)" % (idx, e))
            break
        names = tf.getnames()
        if not names:
            break
        idx += 1
        # 计算本段长度
        start = pos
        for m in tf.getmembers():
            if m.isreg() or m.isdir():
                pass
        end = start + tf.offset
        print("  段 %d: %d 个条目, %d 字节" % (idx, len(names), end - start))
        for m in tf.getmembers():
            if m.isfile() and ("firmware" in m.name or m.name.endswith((".mbn", ".bin", ".fw", ".mbn.gz"))):
                files.append(m.name)
                target = os.path.join(DEST, m.name.lstrip("./"))
                os.makedirs(os.path.dirname(target), exist_ok=True)
                with tf.extractfile(m) as src, open(target, "wb") as dst:
                    dst.write(src.read())
        pos = end
        if idx > 6:
            break

    print("\n提取到 %s 的固件文件 (%d 个):" % (DEST, len(files)))
    for n in files:
        p = os.path.join(DEST, n.lstrip("./"))
        print("  %10d  %s" % (os.path.getsize(p), n))


if __name__ == "__main__":
    main()
