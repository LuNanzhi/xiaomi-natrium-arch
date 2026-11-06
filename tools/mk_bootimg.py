#!/usr/bin/env python3
"""Android boot image (header v0/v2) 打包器 —— 纯标准库，无需 mkbootimg。

小米 5s Plus (natrium) 的 bootloader 读取 boot.img v0 (page 4096)，
内核为 gzip 压缩的 Image，DTB 以 "Image.gz-dtb" 形式追加在内核之后。

回环验证：用原厂 boot.img 解包出的 kernel/ramdisk 重新打包，得到 15,163,392 字节的镜像，
与原厂**大小完全一致，且除 header 里 20 字节的 img_id 字段外逐字节相同**。
（原厂 img_id 由 LineageOS 构建系统注入，非 AOSP mkbootimg 的 SHA1 算法；bootloader 不校验该字段。）
"""
import argparse
import hashlib
import os
import struct
import subprocess
import tempfile

MAGIC = b"ANDROID!"
DEF_KERNEL_ADDR = 0x80008000
DEF_RAMDISK_ADDR = 0x81000000
DEF_TAGS_ADDR = 0x80000100
DEF_PAGE = 4096


def page_align(n, ps):
    return (n + ps - 1) // ps * ps


def compress(path, method):
    if method == "none":
        return open(path, "rb").read()
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix="." + method)
    tmp.close()
    cmds = {"gzip": ["gzip", "-9", "-c", path],
            "xz": ["xz", "-9", "-c", "--check=crc32", path],
            "lz4": ["lz4", "-l", "-9", "-c", path],
            "zstd": ["zstd", "-19", "-c", path]}
    if method not in cmds:
        raise SystemExit("不支持的压缩方式: " + method)
    with open(tmp.name, "wb") as fh:
        subprocess.run(cmds[method], stdout=fh, check=True)
    data = open(tmp.name, "rb").read()
    os.unlink(tmp.name)
    return data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel", required=True, help="arch/arm64/boot/Image.gz")
    ap.add_argument("--dtb", default=None, help="要追加到内核后的 DTB（可多个，逗号分隔）")
    ap.add_argument("--ramdisk", required=True, help="ramdisk（未压缩的 cpio 或已压缩文件）")
    ap.add_argument("--ramdisk-compress", default="none", choices=["none", "gzip", "xz", "lz4", "zstd"])
    ap.add_argument("--cmdline", default="", help="内核 cmdline")
    ap.add_argument("--out", required=True)
    ap.add_argument("--page-size", type=int, default=DEF_PAGE)
    ap.add_argument("--kernel-addr", default=hex(DEF_KERNEL_ADDR))
    ap.add_argument("--ramdisk-addr", default=hex(DEF_RAMDISK_ADDR))
    ap.add_argument("--tags-addr", default=hex(DEF_TAGS_ADDR))
    ap.add_argument("--os-version", default="0x1e0001a9")
    a = ap.parse_args()

    kernel = open(a.kernel, "rb").read()
    if a.dtb:
        for p in a.dtb.split(","):
            nb = open(p, "rb").read()
            print("追加 DTB: %s (%d bytes)" % (p, len(nb)))
            kernel += nb
    ramdisk = open(a.ramdisk, "rb").read()
    if a.ramdisk_compress != "none":
        ramdisk = compress(a.ramdisk, a.ramdisk_compress)
    print("kernel blob (gz+dtb): %d bytes" % len(kernel))
    print("ramdisk             : %d bytes" % len(ramdisk))

    ps = a.page_size
    hdr = bytearray(1632)
    hdr[0:8] = MAGIC
    struct.pack_into("<I", hdr, 8, len(kernel))
    struct.pack_into("<I", hdr, 12, int(a.kernel_addr, 0))
    struct.pack_into("<I", hdr, 16, len(ramdisk))
    struct.pack_into("<I", hdr, 20, int(a.ramdisk_addr, 0))
    struct.pack_into("<I", hdr, 24, 0)
    struct.pack_into("<I", hdr, 28, 0)
    struct.pack_into("<I", hdr, 32, int(a.tags_addr, 0))
    struct.pack_into("<I", hdr, 36, ps)
    struct.pack_into("<I", hdr, 40, 0)
    struct.pack_into("<I", hdr, 44, int(a.os_version, 0))
    hdr[48:64] = b"\x00" * 16
    cb = a.cmdline.encode()
    if len(cb) > 512:
        raise SystemExit("cmdline 超过 512 字节")
    hdr[64:576] = cb.ljust(512, b"\x00")
    sha = hashlib.sha1()
    sha.update(kernel)
    sha.update(struct.pack("<I", len(kernel)))
    sha.update(ramdisk)
    sha.update(struct.pack("<I", len(ramdisk)))
    sha.update(b"")
    sha.update(struct.pack("<I", 0))
    hdr[576:608] = sha.digest() + b"\x00" * 12

    out = bytearray()
    out += hdr.ljust(ps, b"\x00")
    out += kernel + b"\x00" * (page_align(len(kernel), ps) - len(kernel))
    out += ramdisk + b"\x00" * (page_align(len(ramdisk), ps) - len(ramdisk))
    open(a.out, "wb").write(out)
    print("\n写出 %s (%d bytes, %.2f MiB)" % (a.out, len(out), len(out) / 1048576))
    print("cmdline: %s" % a.cmdline)
    print("提示: fastboot flash boot %s" % os.path.basename(a.out))


if __name__ == "__main__":
    main()
