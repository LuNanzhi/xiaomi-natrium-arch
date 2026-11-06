#!/usr/bin/env python3
"""Split gzip kernel + appended DTB(s) and decompile the first DTB."""
import sys, os, subprocess

src = sys.argv[1] if len(sys.argv) > 1 else "/root/dt/kernel.img"
outdir = sys.argv[2] if len(sys.argv) > 2 else "/root/dt/out"
os.makedirs(outdir, exist_ok=True)

data = open(src, "rb").read()
MAGIC = b"\xd0\x0d\xfe\xed"
offs = []
i = 0
while True:
    i = data.find(MAGIC, i)
    if i < 0:
        break
    size = int.from_bytes(data[i + 4:i + 8], "big")
    if 0 < size < len(data) - i:
        offs.append((i, size))
    i += 4

print("kernel size:", len(data))
print("dtb candidates:", offs[:5], "count:", len(offs))
for n, (off, size) in enumerate(offs):
    p = os.path.join(outdir, f"dtb{n}.dtb")
    open(p, "wb").write(data[off:off + size])
    d = os.path.join(outdir, f"dtb{n}.dts")
    subprocess.run(["dtc", "-I", "dtb", "-O", "dts", p, "-o", d], check=False)
    print("wrote", p, size, "->", d)
