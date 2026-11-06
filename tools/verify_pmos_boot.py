#!/usr/bin/env python3
"""正确解析 Android boot v0/v1/v2 镜像并校验 natrium 关键内容。"""
import gzip
import lzma
import struct
import sys
import zlib

path = sys.argv[1]
d = open(path, "rb").read()
print("文件: %s  (%d bytes = %.1f MB)" % (path, len(d), len(d) / 1048576))

magic = d[:8]
assert magic == b"ANDROID!", "magic 不是 ANDROID!: %r" % magic

kernel_size, kernel_addr = struct.unpack_from("<II", d, 8)
ramdisk_size, ramdisk_addr = struct.unpack_from("<II", d, 16)
second_size, second_addr = struct.unpack_from("<II", d, 24)
tags_addr, page_size = struct.unpack_from("<II", d, 32)
header_version, os_version = struct.unpack_from("<II", d, 40)
cmdline = d[64:64 + 512].split(b"\x00")[0].decode("utf-8", "replace")

print("header_version = %d   page_size = %d" % (header_version, page_size))
print("kernel  size=%9d addr=0x%08x" % (kernel_size, kernel_addr))
print("ramdisk size=%9d addr=0x%08x" % (ramdisk_size, ramdisk_addr))
print("second  size=%9d addr=0x%08x" % (second_size, second_addr))
print("tags           addr=0x%08x" % tags_addr)
print("os_version = 0x%08x" % os_version)
print("cmdline = %r" % cmdline)

assert page_size == 4096, "page size 不是 4096"
assert kernel_addr == 0x80008000, "kernel addr 不是 0x80008000"
assert ramdisk_addr == 0x81000000, "ramdisk addr 不是 0x81000000"
assert tags_addr == 0x80000100, "tags addr 不是 0x80000100"
print("✅ 头部参数符合 natrium（page 4096 / 0x80008000 / 0x81000000 / 0x80000100）")

kernel = d[page_size:page_size + kernel_size]
rd_off = page_size + ((kernel_size + page_size - 1) // page_size) * page_size
ramdisk = d[rd_off:rd_off + ramdisk_size]

print()
print("=== 内核 ===")
raw = kernel
kind = "raw Image"
try:
    if kernel[:2] == b"\x1f\x8b":
        raw = gzip.decompress(kernel); kind = "gzip"
    elif kernel[:6] == b"\xfd7zXZ\x00":
        raw = lzma.decompress(kernel); kind = "xz"
except Exception as e:
    print("  解压失败:", e)
i = raw.find(b"Linux version")
print("  格式: %s, 解压后 %d bytes" % (kind, len(raw)))
print("  版本串: %s" % (raw[i:i + 100].split(b"\x00")[0].decode("utf-8", "replace") if i >= 0 else "未找到"))
for kw in (b"sharp,td4722-xcmd", b"jdi,fhd-r63452", b"xiaomi,natrium", b"msm8996pro-xiaomi-natrium"):
    print("  含 %-28s %s" % (kw.decode(), "✅ 是" if kw in raw else "❌ 否"))

print()
print("=== initramfs ===")
rawrd = ramdisk
fmt = "未知"
try:
    if ramdisk[:6] == b"\xfd7zXZ\x00":
        rawrd = lzma.decompress(ramdisk); fmt = "xz"
    elif ramdisk[:2] == b"\x1f\x8b":
        rawrd = gzip.decompress(ramdisk); fmt = "gzip"
    elif ramdisk[:6] in (b"070701", b"070702"):
        rawrd = ramdisk; fmt = "cpio"
    else:
        rawrd = zlib.decompress(ramdisk, 16 + zlib.MAX_WBITS); fmt = "zlib"
except Exception as e:
    print("  解压失败:", e)
print("  格式: %s, 解压后 %d bytes" % (fmt, len(rawrd)))
for kw in (b"panel-sharp-td4722-xcmd.ko", b"panel_sharp_td4722", b"panel-jdi-fhd-r63452",
           b"init", b"modloop", b"pmos"):
    print("  含 %-30s %s" % (kw.decode(), "✅ 是" if kw in rawrd else "❌ 否"))
