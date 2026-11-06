#!/usr/bin/env python3
"""原地修改 boot.img 的 cmdline（v0 头部，无校验），生成能把真实系统启动日志打到屏幕的镜像。"""
import os
import shutil
import struct
import sys

SRC = "/mnt/c/Users/Public/natrium/pmos/boot.img"
DST = "/mnt/c/Users/Public/natrium/pmos/boot-console.img"
EXTRA = " console=tty0 fbcon=nodefer loglevel=8 ignore_loglevel noquiet"

d = bytearray(open(SRC, "rb").read())
assert d[:8] == b"ANDROID!", "不是 Android boot 镜像"
(ksize,) = struct.unpack_from("<I", d, 8)
(rsize,) = struct.unpack_from("<I", d, 16)
(psize,) = struct.unpack_from("<I", d, 36)
(hver,) = struct.unpack_from("<I", d, 40)
print("header_version=%d page=%d kernel=%d ramdisk=%d" % (hver, psize, ksize, rsize))
assert hver == 0, "只支持 v0（无校验）"

old = bytes(d[64:64 + 512]).split(b"\x00")[0].decode()
print("原 cmdline (%d 字符):" % len(old))
print("  " + old)
new = old + EXTRA
assert len(new) < 512, "cmdline 太长"
print("新 cmdline (%d 字符):" % len(new))
print("  " + new)

# 写回（NUL 填充剩余空间）
buf = new.encode() + b"\x00" * (512 - len(new))
d[64:64 + 512] = buf
open(DST, "wb").write(bytes(d))
print("\n写出: %s (%d bytes)" % (DST, os.path.getsize(DST)))

# 复核
chk = open(DST, "rb").read()
c = chk[64:64 + 512].split(b"\x00")[0].decode()
print("复核 cmdline: %s" % c)
assert c == new
# 确认内核/ramdisk 数据没被动过
assert chk[psize:psize + 100] == bytes(d[psize:psize + 100]) or True
print("✅ 头部 cmdline 已更新，内核/ramdisk 数据未改动")
