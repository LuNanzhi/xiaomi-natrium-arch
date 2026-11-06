#!/usr/bin/env python3
"""sdat2img 的纯 Python 实现（支持 transfer.list 版本 1~4）。

版本 4（Android 11+）的格式：
    line1: version (4)
    line2: total_blocks
    line3/4: 元数据（最大暂存块数等）
    lineN: "<cmd> <组数> s1,e1,s2,e2,..."   # 注意是一整串逗号分隔的数字
版本 2：
    lineN: "<cmd> s1,e1,s2,e2,..."

用法: python sdat2img.py <transfer.list> <new.dat> <输出.img>
"""
import os
import sys


def parse_cmd(line):
    parts = line.split()
    cmd = parts[0]
    nums = []
    for p in parts[1:]:
        nums += [int(x) for x in p.split(",") if x.strip() != ""]
    # 版本 3/4：首个数字是「紧随其后的数字个数」，例如
    #   new 4,0,121,480,1383        -> 4 个数字 = 2 段范围 (0,121) (480,1383)
    #   erase 8,93102,97792,...     -> 8 个数字 = 4 段范围
    if nums and nums[0] == len(nums) - 1:
        nums = nums[1:]
    pairs = [(nums[i], nums[i + 1]) for i in range(0, len(nums) - 1, 2)]
    return cmd, pairs


def main():
    tl, dat, out = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(tl, errors="replace") as f:
        lines = [l.strip() for l in f if l.strip()]
    version = int(lines[0])
    total_blocks = int(lines[1]) if len(lines) > 1 else 0
    cmds = []
    for l in lines[2:]:
        if l.split()[0] in ("new", "erase", "zero", "move"):
            cmd, pairs = parse_cmd(l)
            cmds.append((cmd, pairs))
    print("transfer.list: version=%d total_blocks=%d 命令数=%d" % (version, total_blocks, len(cmds)))
    print("前 3 条命令:", [(c, p[:2]) for c, p in cmds[:3]])
    need = sum((e - s) * 4096 for c, pairs in cmds if c == "new" for s, e in pairs)
    have = os.path.getsize(dat)
    print("需要从 .dat 读 %d 字节，实际有 %d 字节  %s" % (need, have, "✅" if have >= need else "❌ 不足"))

    block = 4096
    # 正确的镜像大小 = 所有命令范围里的最大结束块（不能信 transfer.list 第 2 行，
    # 它小于整个分区/文件系统尺寸时会把镜像截断，导致 debugfs 读不到块位图）
    max_end = 0
    for cmd, pairs in cmds:
        for s, e in pairs:
            if e > max_end:
                max_end = e
    print("最大结束块: %d -> 预期镜像大小 %.1f MB" % (max_end, max_end * block / 2**20))

    src = open(dat, "rb")
    with open(out, "wb") as dst:
        for cmd, pairs in cmds:
            for s, e in pairs:
                n = (e - s) * block
                if cmd == "new":
                    dst.seek(s * block)
                    remaining = n
                    while remaining:
                        chunk = src.read(min(1 << 22, remaining))
                        if not chunk:
                            raise SystemExit("!! .dat 数据提前耗尽")
                        dst.write(chunk)
                        remaining -= len(chunk)
                elif cmd in ("erase", "zero"):
                    dst.seek(s * block)
                    dst.write(b"\x00" * n)
        dst.truncate(max_end * block)   # 按最大结束块定尺寸（需要时自动扩展）
    src.close()
    size = os.path.getsize(out)
    with open(out, "rb") as f:
        f.seek(1024 + 56)
        magic = f.read(2)
    print("写出 %s: %d bytes；ext4 magic @0x438 = %s  %s"
          % (out, size, magic.hex(), "✅ ext4" if magic == b"\x53\xef" else "❌ 不是 ext4"))


if __name__ == "__main__":
    main()
