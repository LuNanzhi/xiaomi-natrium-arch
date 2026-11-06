#!/usr/bin/env python3
"""Android boot image 解析 + 解包/重打包工具（纯标准库，Windows/Linux 通用）。

用法:
  python bootimg_info.py info  <boot.img>
  python bootimg_info.py unpack <boot.img> <outdir>
  python bootimg_info.py repack <outdir> <new-boot.img>
"""
import gzip, hashlib, os, struct, sys, zlib

BOOT_MAGIC = b"ANDROID!"
VENDOR_MAGIC = b"VNDRBOOT"
FDT_MAGIC = 0xD00DFEED
QCDT_MAGIC = b"QCDT"
VENDOR_BOOT_MAGIC = b"VNDRBOOT"


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def rd(b, o):
    return struct.unpack_from("<I", b, o)[0]


def parse_hdr(d):
    """返回 (version, dict of fields)。"""
    if d[:8] == VENDOR_BOOT_MAGIC:
        h = {
            "header_version": 0xFFFFFFFF,
            "page_size": 4096,
            "kernel_addr": rd(d, 12),
            "ramdisk_addr": rd(d, 16),
            "kernel_size": rd(d, 8),
            "ramdisk_size": rd(d, 20),
        }
        return -1, h  # vendor_boot
    if d[:8] != BOOT_MAGIC:
        raise SystemExit("不是 Android boot image（magic=%r）" % d[:8])
    h = {
        "kernel_size": rd(d, 8),
        "kernel_addr": rd(d, 12),
        "ramdisk_size": rd(d, 16),
        "ramdisk_addr": rd(d, 20),
        "second_size": rd(d, 24),
        "second_addr": rd(d, 28),
        "tags_addr": rd(d, 32),
        "page_size": rd(d, 36),
        "header_version": rd(d, 40),
        "os_version_raw": rd(d, 44),
        "name": d[48:64].rstrip(b"\x00").decode("utf-8", "replace"),
        "cmdline": d[64:576].rstrip(b"\x00").decode("utf-8", "replace"),
        "img_id": d[576:608].hex(),
        "extra_cmdline": d[608:1632].rstrip(b"\x00").decode("utf-8", "replace"),
    }
    v = h["header_version"]
    if v >= 2:
        h["dtb_size"] = rd(d, 1632)
        h["dtb_addr"] = rd(d, 1636)
    return v, h


def page(n, ps):
    return (n + ps - 1) // ps * ps


def slices(d, h, v):
    ps = h["page_size"]
    off = ps  # header occupies one page
    out = {}
    for key, size in (("kernel", h["kernel_size"]), ("ramdisk", h["ramdisk_size"]),
                      ("second", h.get("second_size", 0))):
        out[key] = (off, size)
        off += page(size, ps)
    if v >= 2 and h.get("dtb_size"):
        out["dtb"] = (off, h["dtb_size"])
        off += page(h["dtb_size"], ps)
    out["_tail"] = (off, len(d) - off)
    return out


def guess_fmt(b):
    if b[:2] == b"\x1f\x8b":
        return "gzip"
    if b[:4] == b"\x04\x22\x4d\x18":
        return "lz4-legacy"
    if b[:4] == b"\x02\x21\x4c\x18":
        return "lz4"
    if b[:6] == b"\xfd7zXZ\x00":
        return "xz"
    if b[:4] == b"\x28\xb5\x2f\xfd":
        return "zstd"
    if b[:3] == b"BZh":
        return "bzip2"
    if b[:6] == b"070701" or b[:6] == b"070702":
        return "cpio"
    return "raw/other"


def parse_fdt(b):
    """返回 (header dict, 顶层 compatible 列表, model)。"""
    if len(b) < 40 or be32(b, 0) != FDT_MAGIC:
        return None, [], None
    totalsize = be32(b, 4)
    off_struct = be32(b, 8)
    off_strings = be32(b, 12)
    size_strings = be32(b, 32)
    strings = b[off_strings:off_strings + size_strings]
    if totalsize < len(b):
        b = b[:totalsize]

    def cstr(p):
        e = b.index(b"\x00", p)
        return b[p:e].decode("utf-8", "replace")

    compats, model = [], None
    i, depth = off_struct, 0
    in_root = True
    while i < len(b):
        tok = be32(b, i)
        i += 4
        if tok == 1:  # BEGIN_NODE
            name = cstr(i)
            i += len(name) + 1
            depth += 1
            in_root = depth == 1
            if in_root:
                model = name if name else model
        elif tok == 2:  # END_NODE
            depth -= 1
            in_root = depth == 1
        elif tok == 3:  # PROP
            nlen = be32(b, i)
            i += 4
            plen = be32(b, i)
            i += 4
            n = strings[be32(b, i):]
            n = n[:n.index(b"\x00")].decode()
            i += 4
            val = b[i:i + plen]
            i += (plen + 3) & ~3
            if in_root and n == "compatible":
                compats = [s.decode("utf-8", "replace") for s in val.split(b"\x00") if s]
            if in_root and n == "model":
                model = val.rstrip(b"\x00").decode("utf-8", "replace")
        elif tok == 4:  # NOP
            pass
        elif tok == 9:  # END
            break
        else:
            break
    return {"totalsize": totalsize}, compats, model


def decompress(b, fmt):
    if fmt == "gzip":
        try:
            return gzip.decompress(b), True
        except Exception as e:
            try:
                return zlib.decompressobj(31).decompress(b), False
            except Exception:
                return b"", False
    return b"", False


def cmd_info(path):
    d = open(path, "rb").read()
    v, h = parse_hdr(d)
    print("== 文件 ==")
    print("路径        :", path)
    print("大小        :", len(d), "bytes   sha256:", hashlib.sha256(d).hexdigest())
    if v == -1:
        print("类型        : vendor_boot (magic VNDRBOOT)")
        return
    print("header 版本 : v%d" % v)
    print("page_size   :", h["page_size"])
    print("os_version  : 0x%08x" % h["os_version_raw"], end="")
    ov = h["os_version_raw"]
    if ov:
        print("  (a=%d b=%d c=%d %s%d)" % (((ov >> 25) & 0x7F), ((ov >> 18) & 0x7F),
              ((ov >> 11) & 0x7F), "V" if (ov >> 4) & 0x1 else "P", ov & 0x7F))
    else:
        print()
    print("name        :", repr(h["name"]))
    print("cmdline     :", repr(h["cmdline"]))
    if h["extra_cmdline"]:
        print("extra_cmd :", repr(h["extra_cmdline"]))
    print("kernel      : size=%d addr=0x%08x" % (h["kernel_size"], h["kernel_addr"]))
    print("ramdisk     : size=%d addr=0x%08x" % (h["ramdisk_size"], h["ramdisk_addr"]))
    print("second      : size=%d addr=0x%08x" % (h["second_size"], h["second_addr"]))
    print("tags_addr   : 0x%08x" % h["tags_addr"])
    if v >= 2:
        print("dtb         : size=%d addr=0x%08x" % (h.get("dtb_size", 0), h.get("dtb_addr", 0)))
    print("img id      :", h["img_id"])

    sl = slices(d, h, v)
    for key in ("kernel", "ramdisk", "second", "dtb"):
        if key in sl:
            o, n = sl[key]
            blob = d[o:o + n]
            print("\n-- %s @0x%x (%d bytes) 格式=%s" % (key, o, n, guess_fmt(blob[:64]) if n else "-"))
            if key == "kernel" and n:
                f = guess_fmt(blob[:64])
                raw, ok = decompress(blob, f)
                target = raw if ok else blob
                idx = target.find(b"Linux version")
                if idx >= 0:
                    print("   内核版本串:", target[idx:idx + 200].split(b"\x00")[0].decode("utf-8", "replace"))
                # 压缩流里通常也能搜到
                if not ok:
                    j = blob.find(b"Linux version")
                    if j >= 0:
                        print("   (压缩流内) :", blob[j:j + 160].split(b"\x00")[0].decode("utf-8", "replace"))
                for tag in (b"CONFIG_", b"IKCFG_ST"):
                    if target.find(tag) >= 0:
                        print("   含配置数据 :", tag)
                        break
            if key == "dtb" and n:
                off = 0
                n_dtb = 0
                while off + 40 <= n:
                    ts = be32(blob, off + 4)
                    if be32(blob, off) != FDT_MAGIC:
                        break
                    hdr, comps, model = parse_fdt(blob[off:off + ts])
                    n_dtb += 1
                    print("   [dtb#%d] size=%d model=%r" % (n_dtb, ts, model))
                    print("           compatible=%s" % ", ".join(comps))
                    off += ts
                if n_dtb == 0 and blob[:2] == b"\x1f\x8b":
                    raw, _ = decompress(blob, "gzip")
                    if be32(raw, 0) == FDT_MAGIC:
                        print("   (dtb 为 gzip)")
                print("   dtb 数量   :", n_dtb)
    # 关尾 QCDT（很多高通 boot.img 的 dtb 直接跟着 ramdisk，magic 为 QCDT）
    q = d.find(QCDT_MAGIC)
    if q >= 0:
        print("\n发现 QCDT 段 @0x%x  (qcom 表格, 条目数=%d)" % (q, be32(d, q + 4)))


def cmd_unpack(path, outdir):
    d = open(path, "rb").read()
    v, h = parse_hdr(d)
    if v == -1:
        raise SystemExit("vendor_boot 暂不支持拆分，仅 info")
    os.makedirs(outdir, exist_ok=True)
    sl = slices(d, h, v)
    meta = {
        "header_version": v, "page_size": h["page_size"], "kernel_addr": h["kernel_addr"],
        "ramdisk_addr": h["ramdisk_addr"], "second_addr": h["second_addr"],
        "tags_addr": h["tags_addr"], "dtb_addr": h.get("dtb_addr", 0),
        "os_version": h["os_version_raw"], "name": h["name"], "cmdline": h["cmdline"],
        "extra_cmdline": h["extra_cmdline"], "img_id": h["img_id"],
    }
    import json
    json.dump(meta, open(os.path.join(outdir, "header.json"), "w"), indent=2)
    for key in ("kernel", "ramdisk", "second", "dtb"):
        if key in sl:
            o, n = sl[key]
            if n:
                p = os.path.join(outdir, key + ".img")
                open(p, "wb").write(d[o:o + n])
                print("写出", p, n, "bytes", guess_fmt(d[o:o + 40]))
    tail_o, tail_n = sl["_tail"]
    if tail_n > 0:
        open(os.path.join(outdir, "tail.bin"), "wb").write(d[tail_o:])
        print("写出 tail.bin", tail_n, "bytes (签名/AVB 或补白)")
    print("header.json 已写出:", os.path.join(outdir, "header.json"))


def cmd_repack(outdir, dest):
    import json
    m = json.load(open(os.path.join(outdir, "header.json")))
    ps = m["page_size"]
    v = m["header_version"]

    def rd_or(name):
        p = os.path.join(outdir, name)
        return open(p, "rb").read() if os.path.exists(p) else b""

    kernel, ramdisk = rd_or("kernel.img"), rd_or("ramdisk.img")
    second, dtb = rd_or("second.img"), rd_or("dtb.img")
    tail = rd_or("tail.bin")

    hdr = bytearray(1632 + (8 if v >= 2 else 0))
    hdr[0:8] = BOOT_MAGIC
    struct.pack_into("<I", hdr, 8, len(kernel))
    struct.pack_into("<I", hdr, 12, m["kernel_addr"])
    struct.pack_into("<I", hdr, 16, len(ramdisk))
    struct.pack_into("<I", hdr, 20, m["ramdisk_addr"])
    struct.pack_into("<I", hdr, 24, len(second))
    struct.pack_into("<I", hdr, 28, m["second_addr"])
    struct.pack_into("<I", hdr, 32, m["tags_addr"])
    struct.pack_into("<I", hdr, 36, ps)
    struct.pack_into("<I", hdr, 40, v)
    struct.pack_into("<I", hdr, 44, m["os_version"])
    hdr[48:64] = m["name"].encode()[:16].ljust(16, b"\x00")
    hdr[64:576] = m["cmdline"].encode()[:512].ljust(512, b"\x00")
    hdr[576:608] = bytes.fromhex(m["img_id"]) if m.get("img_id") else b"\x00" * 32
    hdr[608:1632] = m["extra_cmdline"].encode()[:1024].ljust(1024, b"\x00")
    if v >= 2:
        struct.pack_into("<I", hdr, 1632, len(dtb))
        struct.pack_into("<I", hdr, 1636, m["dtb_addr"])

    out = bytearray()
    out += hdr.ljust(ps, b"\x00")
    for blob in (kernel, ramdisk, second):
        out += blob
        if blob or True:
            out += b"\x00" * (page(len(blob), ps) - len(blob))
    if v >= 2 and dtb:
        out += dtb + b"\x00" * (page(len(dtb), ps) - len(dtb))
    out += tail
    open(dest, "wb").write(out)
    print("写出", dest, len(out), "bytes")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    c = sys.argv[1]
    if c == "info":
        cmd_info(sys.argv[2])
    elif c == "unpack":
        cmd_unpack(sys.argv[2], sys.argv[3])
    elif c == "repack":
        cmd_repack(sys.argv[2], sys.argv[3])
    else:
        raise SystemExit(__doc__)
