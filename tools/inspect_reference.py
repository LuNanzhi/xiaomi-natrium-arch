"""调试/核实：LineageOS boot.img 追加 DTB 链 + ramdisk cpio 内容。"""
import lzma
import os
import struct

BASE = r"natrium-port/bootimg/lineage-unpacked"
KC = os.path.join(BASE, "kernel.img")
RC = os.path.join(BASE, "ramdisk.img")
FDT = 0xD00DFEED


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def main():
    d = open(KC, "rb").read()
    # 找所有 4 字节对齐的 FDT magic（含非对齐扫描）
    hits = []
    i = d.find(b"\xd0\x0d\xfe\xed")
    while i >= 0 and len(hits) < 12:
        hits.append(i)
        i = d.find(b"\xd0\x0d\xfe\xed", i + 1)
    print("kernel.img 内 FDT magic 出现位置:", hits)

    # 逐个解析 DTB 头
    for n, off in enumerate(hits, 1):
        ts = be32(d, off + 4)
        struct_off = be32(d, off + 8)
        strings_off = be32(d, off + 12)
        n_strings = be32(d, off + 32)
        n_struct = be32(d, off + 36)
        version = be32(d, off + 20)
        print("\n[DTB #%d] offset=0x%x totalsize=%d version=%d off_struct=%d(%d bytes) off_strings=%d(%d bytes)"
              % (n, off, ts, version, struct_off, n_struct, strings_off, n_strings))
        body = d[off:off + ts]
        if struct_off + 8 <= len(body):
            print("     struct 首 6 个 token:", [hex(be32(body, struct_off + 4 * k)) for k in range(6)])
            # 手工走第一个节点
            p = struct_off
            tok = be32(body, p); p += 4
            name = body[p:body.index(b"\x00", p)].decode("utf-8", "replace")
            p = body.index(b"\x00", p) + 1
            print("     首个 token=%d 根节点名=%r" % (tok, name))
            strs = body[strings_off:strings_off + n_strings]
            found = []
            for _ in range(8):
                if p + 12 > len(body):
                    break
                t = be32(body, p)
                if t != 3:
                    print("     token=%d 非属性，停止" % t)
                    break
                plen = be32(body, p + 4)
                noff = be32(body, p + 8)
                nm = strs[noff:strs.index(b"\x00", noff)].decode("utf-8", "replace")
                val = body[p + 12:p + 12 + plen]
                p += 12 + ((plen + 3) & ~3)
                found.append((nm, val[:48]))
            for nm, val in found:
                print("     属性 %-16s = %r" % (nm, val))
        if off + ts > len(d):
            print("     !! totalsize 超出文件范围")
            break

    print("\n\n===== ramdisk.img =====")
    raw = lzma.decompress(open(RC, "rb").read())
    print("解压后 %d bytes, 头部 magic=%r" % (len(raw), raw[:6]))
    i = 0
    count = 0
    while i + 110 <= len(raw) and raw[i:i + 6] in (b"070701", b"070702"):
        def f(k):
            return int(raw[i + 6 + k * 8:i + 6 + k * 8 + 8], 16)
        mode, size, namesize = f(1), f(6), f(11)
        name = raw[i + 110:i + 110 + namesize - 1].decode("utf-8", "replace")
        if name == "TRAILER!!!":
            print("  [%3d] TRAILER 结束 (共 %d 条)" % (count, count))
            break
        print("  [%3d] %-52s mode=%07o size=%d" % (count, name, mode, size))
        count += 1
        i += 110 + namesize
        i += (size + 3) & ~3
    else:
        print("  解析在中途停止于 offset=%d, 剩余 magic=%r" % (i, raw[i:i + 6]))


if __name__ == "__main__":
    main()
