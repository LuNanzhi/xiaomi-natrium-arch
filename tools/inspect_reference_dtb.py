"""检查 LineageOS 参考 DTB 里是否包含 natrium 专属硬件（面板/触摸），以及追加 DTB 的选取字段。"""
import struct
import sys

BASE = r"natrium-port/bootimg/lineage-unpacked"
FDT = 0xD00DFEED
KEYS = ("panel", "dsi", "touch", "synaptics", "rmi", "goodix", "focaltech", "atmel",
        "jdi", "r63452", "tp_", "lcd")


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def walk(blob):
    so, ss, ssz = be32(blob, 8), be32(blob, 12), be32(blob, 32)
    strings = blob[ss:ss + ssz]
    nodes = {}
    path = []
    i = so
    while i + 4 <= len(blob):
        tok = be32(blob, i); i += 4
        if tok == 1:
            e = blob.index(b"\x00", i)
            nm = blob[i:e].decode("utf-8", "replace")
            path.append(nm if nm else "/")
            i = (e + 1 + 3) & ~3
        elif tok == 2:
            if path:
                nodes["/".join(path)] = []
                path.pop()
        elif tok == 3:
            plen = be32(blob, i); i += 4
            ns = be32(blob, i); i += 4
            e = strings.index(b"\x00", ns)
            name = strings[ns:e].decode("utf-8", "replace")
            val = blob[i:i + plen]
            i += (plen + 3) & ~3
            if path:
                nodes.setdefault("/".join(path), []).append((name, val))
        elif tok == 4:
            pass
        elif tok == 9:
            break
        else:
            break
    return nodes


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    blob = open("%s/lineage-dtb-%d.dtb" % (BASE, n), "rb").read()
    nodes = walk(blob)
    print("DTB #%d: 节点数 %d" % (n, len(nodes)))
    print("\n--- 含 panel/dsi/touch 等关键字的节点 ---")
    hits = 0
    for np, props in nodes.items():
        blobtxt = np.lower() + " " + " ".join(
            (nm + "=" + v.decode("utf-8", "replace")).lower() for nm, v in props if len(v) < 64)
        if any(k in blobtxt for k in KEYS):
            hits += 1
            if hits <= 25:
                print("  ", np)
                for nm, v in props[:6]:
                    if len(v) < 80:
                        print("      %-34s = %r" % (nm, v.rstrip(b"\x00")))
    print("  命中节点数:", hits)
    print("\n--- 所有 mdss/dsi 相关节点 ---")
    for np in nodes:
        if "mdss" in np or "dsi" in np:
            print("  ", np)


if __name__ == "__main__":
    main()
