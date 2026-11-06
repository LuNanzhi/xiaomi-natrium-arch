#!/usr/bin/env python3
"""分析 LineageOS 内核镜像：解压 Image、提取追加 DTB 链、打印设备树关键属性、列 ramdisk。

Android 的 "Image.gz-dtb" 布局：gzip(Image) 之后**直接拼接**多个 DTB（无对齐填充），
每个 DTB 的 totalsize 决定下一个的起点。bootloader 用 qcom,msm-id / qcom,board-id 匹配选取。
"""
import lzma
import os
import struct
import zlib

BASE = r"natrium-port/bootimg/lineage-unpacked"
KC = os.path.join(BASE, "kernel.img")
RC = os.path.join(BASE, "ramdisk.img")
OUT = BASE
FDT = 0xD00DFEED


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def gunzip_prefix(b):
    """解压第一个 gzip member，返回 (raw, 压缩流占用字节数)。"""
    d = zlib.decompressobj(31)
    raw = d.decompress(b)
    raw += d.flush()
    return raw, len(b) - len(d.unused_data)


def fdt_props(blob):
    """遍历 FDT，返回 {(节点路径, 属性名): 值}。"""
    so, ss, ssz = be32(blob, 8), be32(blob, 12), be32(blob, 32)
    strings = blob[ss:ss + ssz]
    props, path, i = {}, [], so
    while i + 4 <= len(blob):
        tok = be32(blob, i); i += 4
        if tok == 1:                                    # BEGIN_NODE
            e = blob.index(b"\x00", i)
            nm = blob[i:e].decode("utf-8", "replace")
            path.append(nm if nm else "/")
            i = (e + 1 + 3) & ~3                        # 节点名整体 4 字节对齐
        elif tok == 2:                                  # END_NODE
            if path:
                path.pop()
        elif tok == 3:                                  # PROP: [3][len][nameoff][value]
            plen = be32(blob, i); i += 4
            ns = be32(blob, i); i += 4
            e = strings.index(b"\x00", ns)
            name = strings[ns:e].decode("utf-8", "replace")
            props[("/".join(path), name)] = blob[i:i + plen]
            i += (plen + 3) & ~3
        elif tok == 4:                                  # NOP
            pass
        elif tok == 9:                                  # END
            break
        else:
            break
    return props


def strs(v):
    return [s.decode("utf-8", "replace") for s in v.split(b"\x00") if s]


def words(v):
    return [be32(v, k) for k in range(0, len(v) - 3, 4)]


def show_dtb(blob, label):
    props = fdt_props(blob)
    print("  %s  size=%d" % (label, len(blob)))
    print("      model      : %s" % props.get(("/", "model"), b"").rstrip(b"\x00").decode("utf-8", "replace"))
    print("      compatible : %s" % ", ".join(strs(props.get(("/", "compatible"), b""))))
    for k in ("qcom,msm-id", "qcom,board-id", "qcom,pmic-id"):
        if ("/", k) in props:
            print("      %-11s: %s" % (k, ["0x%x" % w for w in words(props[("/", k)])]))
    # 面板 / 触摸 / 关键外设节点
    for (p, n), v in props.items():
        if n == "compatible":
            s = strs(v)
            if any(k in s for k in ("jdi,fhd-r63452", "syna,rmi4-i2c", "qcom,msm8996",
                                    "qcom,msm8996pro", "xiaomi,natrium")):
                print("      节点 %-28s -> %s" % (p, ", ".join(s)))
    # 该 DTB 里是否有触摸屏节点
    has_touch = any("rmi4" in str(strs(v)) for (p, n), v in props.items() if n == "compatible")
    has_panel = any("r63452" in str(strs(v)) for (p, n), v in props.items() if n == "compatible")
    print("      含面板节点: %-5s 含触摸节点: %s" % (has_panel, has_touch))


def main():
    d = open(KC, "rb").read()
    print("== kernel.img ==", len(d), "bytes")
    raw, consumed = gunzip_prefix(d)
    print("gzip 解压后 Image: %d bytes；压缩流占用 %d bytes" % (len(raw), consumed))
    i = raw.find(b"Linux version")
    if i >= 0:
        print("内核版本串:", raw[i:i + 220].split(b"\x00")[0].decode("utf-8", "replace"))
    print("Image 头 8 字节: %s (ARM64 Image 的 code0/code1)" % raw[:8].hex())

    tail = d[consumed:]
    print("\n== 追加 DTB 链 ==", len(tail), "bytes")
    off, n = 0, 0
    while off + 40 <= len(tail):
        if be32(tail, off) != FDT:
            print("  偏移 %d 处不是 FDT (magic=0x%08x)，停止" % (off, be32(tail, off)))
            break
        ts = be32(tail, off + 4)
        if ts <= 0 or off + ts > len(tail):
            print("  偏移 %d 的 totalsize=%d 异常" % (off, ts))
            break
        n += 1
        show_dtb(tail[off:off + ts], "DTB #%d @+%d" % (n, off))
        open(os.path.join(OUT, "lineage-dtb-%d.dtb" % n), "wb").write(tail[off:off + ts])
        off += ts
    print("  DTB 总数: %d，占用 %d / %d bytes" % (n, off, len(tail)))
    if n:
        open(os.path.join(OUT, "lineage-appended-dtbs.bin"), "wb").write(tail[:off])

    print("\n== ramdisk ==")
    r = lzma.decompress(open(RC, "rb").read())
    print("xz 解压后 %d bytes，magic=%r" % (len(r), r[:6]))
    i = cnt = 0
    while i + 110 <= len(r) and r[i:i + 6] in (b"070701", b"070702"):
        f = lambda k: int(r[i + 6 + k * 8:i + 6 + k * 8 + 8], 16)
        mode, size, namesize = f(1), f(6), f(11)
        name = r[i + 110:i + 110 + namesize - 1].decode("utf-8", "replace")
        if name == "TRAILER!!!":
            print("  TRAILER 结束，共 %d 条" % cnt)
            break
        print("  [%3d] %-46s mode=%07o size=%d" % (cnt, name, mode, size))
        cnt += 1
        i += (110 + namesize + 3) & ~3       # 头 110 + 名字(含 NUL) 整体 4 字节对齐
        i += (size + 3) & ~3                 # 数据 4 字节对齐
    else:
        print("  解析停止于 offset=%d，剩余 magic=%r（共解析 %d 条）" % (i, r[i:i + 6], cnt))
    open(os.path.join(OUT, "ramdisk.cpio"), "wb").write(r)


if __name__ == "__main__":
    main()
