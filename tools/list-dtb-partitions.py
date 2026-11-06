import struct

DTB = r"natrium-port\build\pmos-ref\msm8996pro-xiaomi-natrium.dtb"
FDT = 0xD00DFEED


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def walk(blob):
    so, ss, ssz = be32(blob, 8), be32(blob, 12), be32(blob, 32)
    strings = blob[ss:ss + ssz]
    nodes, path, i = [], [], so
    while i + 4 <= len(blob):
        t = be32(blob, i); i += 4
        if t == 1:
            e = blob.index(b"\x00", i)
            nm = blob[i:e].decode("utf-8", "replace")
            path.append(nm if nm else "/")
            i = (e + 1 + 3) & ~3
        elif t == 2:
            if path:
                nodes.append(("/".join(path), None))
                path.pop()
        elif t == 3:
            plen = be32(blob, i); i += 4
            ns = be32(blob, i); i += 4
            e = strings.index(b"\x00", ns)
            name = strings[ns:e].decode("utf-8", "replace")
            val = blob[i:i + plen]
            i += (plen + 3) & ~3
            if path:
                nodes.append(("/".join(path), (name, val)))
        elif t == 9:
            break
        elif t != 4:
            break
    return nodes


b = open(DTB, "rb").read()
print("DTB:", DTB, len(b), "bytes")
nodes = walk(b)

# 找 partitions 节点里的 label/reg
cur_label = None
cur_reg = None
found = []
for p, prop in nodes:
    if prop is None:
        if cur_label:
            found.append((cur_label, cur_reg))
        cur_label, cur_reg = None, None
        continue
    name, val = prop
    if name == "label":
        cur_label = val.rstrip(b"\x00").decode("utf-8", "replace")
    elif name == "reg" and len(val) >= 8:
        cur_reg = [be32(val, 0), be32(val, 4)]
if cur_label:
    found.append((cur_label, cur_reg))

print("\n=== UFS 分区表（来自设备树）===")
for label, reg in found:
    if reg:
        print("  %-14s offset=0x%-10x size=%d KB" % (label, reg[0], reg[1] // 1024))
    else:
        print("  %-14s (无 reg)" % label)

names = [l.lower() for l, r in found]
print("\n=== 疑似日志/转储分区 ===")
for k in ("logfs", "rdimage", "crash", "dip", "misc", "devinfo", "fsg", "ssd", "mdtp", "toolsfv", "aboot", "xbl", "tz"):
    if k in names:
        print("  ✅ 存在:", k)
print("  （以上没有的就不存在）")
