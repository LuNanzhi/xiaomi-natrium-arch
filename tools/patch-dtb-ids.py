#!/usr/bin/env python3
"""把 natrium DTB 里的 qcom,msm-id / qcom,board-id 改成另一组值，
用于「同一硬件、ABL 按不同 msm-id 挑树」的情况（小米 5s Plus 出货过 MSM8996 Pro 与 v3.0 两种）。

做法：在 DTB 二进制里定位根节点的这两个属性（值紧跟 token 3 的属性头），就地改写字节。
输出 <名字>.patched.dtb，再用 mk_bootimg.py 把两个 DTB 一起追加到内核后。

用法:
  python3 patch-dtb-ids.py <输入.dtb> <输出.dtb> --msm-id 246 0x30000 --board-id 47 0
"""
import argparse
import struct
import sys

FDT = 0xD00DFEED


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def find_root_prop(blob, name):
    """在根节点里找属性，返回 (值在文件中的偏移, 长度)。"""
    so, ss, ssz = be32(blob, 8), be32(blob, 12), be32(blob, 32)
    strings = blob[ss:ss + ssz]
    i = so
    depth = 0
    while i + 4 <= len(blob):
        tok = be32(blob, i)
        i += 4
        if tok == 1:                      # BEGIN_NODE
            e = blob.index(b"\x00", i)
            depth += 1
            i = (e + 1 + 3) & ~3
        elif tok == 2:                    # END_NODE
            depth -= 1
            if depth <= 0:
                break
        elif tok == 3:                    # PROP
            plen = be32(blob, i); i += 4
            ns = be32(blob, i); i += 4
            e = strings.index(b"\x00", ns)
            pname = strings[ns:e].decode("utf-8", "replace")
            if depth == 1 and pname == name:
                return i, plen
            i += (plen + 3) & ~3
        elif tok == 9:
            break
        elif tok != 4:
            break
    return None, None


def patch(blob, name, values):
    off, ln = find_root_prop(blob, name)
    if off is None:
        print("  !! 找不到属性", name)
        return False, blob
    need = 4 * len(values)
    if ln < need:
        print("  !! %s 长度不足 (%d < %d)" % (name, ln, need))
        return False, blob
    old = [be32(blob, off + 4 * k) for k in range(ln // 4)]
    b = bytearray(blob)
    for k, v in enumerate(values):
        struct.pack_into(">I", b, off + 4 * k, v)
    new = [be32(b, off + 4 * k) for k in range(ln // 4)]
    print("  %-10s %s -> %s" % (name, ["0x%x" % x for x in old], ["0x%x" % x for x in new]))
    return True, bytes(b)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--msm-id", nargs="+", type=lambda x: int(x, 0))
    ap.add_argument("--board-id", nargs="+", type=lambda x: int(x, 0))
    ap.add_argument("--pmic-id", nargs="+", type=lambda x: int(x, 0))
    a = ap.parse_args()

    blob = open(a.src, "rb").read()
    print("输入: %s (%d bytes)" % (a.src, len(blob)))
    ok = True
    if a.msm_id:
        r, blob = patch(blob, "qcom,msm-id", a.msm_id); ok &= r
    if a.board_id:
        r, blob = patch(blob, "qcom,board-id", a.board_id); ok &= r
    if a.pmic_id:
        r, blob = patch(blob, "qcom,pmic-id", a.pmic_id); ok &= r
    if not ok:
        sys.exit(2)
    open(a.dst, "wb").write(blob)
    print("输出: %s (%d bytes)" % (a.dst, len(blob)))


if __name__ == "__main__":
    main()
