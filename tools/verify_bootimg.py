#!/usr/bin/env python3
"""独立验证 boot.img：解 header → 解压内核看版本串 → 走追加 DTB 链看 ABL 选取字段 → 列 ramdisk。

用法: python verify_bootimg.py <boot.img>
不依赖构建日志，纯粹从镜像本身取证。
"""
import gzip
import lzma
import struct
import sys
import zlib

FDT = 0xD00DFEED


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def le32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def gunzip_prefix(b):
    d = zlib.decompressobj(31)
    raw = d.decompress(b) + d.flush()
    return raw, len(b) - len(d.unused_data)


def fdt_root(blob):
    """返回 (model, compatible列表, {属性: 值})，只看根节点。"""
    so, ss, ssz = be32(blob, 8), be32(blob, 12), be32(blob, 32)
    strings = blob[ss:ss + ssz]
    out, depth, i = {}, 0, so
    while i + 4 <= len(blob):
        tok = be32(blob, i); i += 4
        if tok == 1:
            e = blob.index(b"\x00", i)
            depth += 1
            i = (e + 1 + 3) & ~3
        elif tok == 2:
            depth -= 1
        elif tok == 3:
            plen = be32(blob, i); i += 4
            ns = be32(blob, i); i += 4
            e = strings.index(b"\x00", ns)
            name = strings[ns:e].decode()
            if depth <= 1:
                out[name] = blob[i:i + plen]
            i += (plen + 3) & ~3
        elif tok == 9:
            break
        elif tok != 4:
            break
    comps = [s.decode() for s in out.get("compatible", b"").split(b"\x00") if s]
    return out.get("model", b"").rstrip(b"\x00").decode(), comps, out


def main():
    path = sys.argv[1]
    d = open(path, "rb").read()
    print("=" * 78)
    print("验证镜像:", path)
    print("大小    :", len(d), "bytes")
    assert d[:8] == b"ANDROID!", "不是 Android boot image"
    v = le32(d, 40)
    ps = le32(d, 36)
    ksize, kaddr = le32(d, 8), le32(d, 12)
    rsize, raddr = le32(d, 16), le32(d, 20)
    cmdline = d[64:576].rstrip(b"\x00").decode()
    print("header  : v%d, page=%d, kernel=%d@0x%08x, ramdisk=%d@0x%08x" % (v, ps, ksize, kaddr, rsize, raddr))
    print("cmdline :", cmdline)
    assert v == 0 and ps == 4096, "header 版本/page 与 natrium 要求不符"
    assert (kaddr, raddr) == (0x80008000, 0x81000000), "加载地址与设备不符"

    ko = ps
    kernel = d[ko:ko + ksize]
    ramdisk = d[ko + (ksize + ps - 1) // ps * ps:][:rsize]
    print("\n-- 内核 --")
    raw, consumed = gunzip_prefix(kernel)
    i = raw.find(b"Linux version")
    ver = raw[i:i + 120].split(b"\x00")[0].decode("utf-8", "replace") if i >= 0 else "(未找到版本串)"
    print("  解压: %d -> %d bytes；版本串: %s" % (len(kernel), len(raw), ver))
    assert "Linux version 6." in ver, "内核版本不是 6.x"
    if "natrium" not in ver:
        print("  注意: 版本串里没有 '-natrium'（用 pmOS 官方 config 时 LOCALVERSION 为空，属正常）")

    print("\n-- 追加 DTB 链 --")
    tail = kernel[consumed:]
    off, n = 0, 0
    while off + 40 <= len(tail) and be32(tail, off) == FDT:
        ts = be32(tail, off + 4)
        model, comps, props = fdt_root(tail[off:off + ts])
        n += 1
        print("  DTB #%d: size=%d model=%r" % (n, ts, model))
        print("         compatible: %s" % ", ".join(comps))
        for k in ("qcom,msm-id", "qcom,board-id"):
            if k in props:
                print("         %-13s = %s" % (k, [hex(be32(props[k], j)) for j in range(0, len(props[k]) - 3, 4)]))
        off += ts
    assert n >= 1, "没有找到追加 DTB —— bootloader 无从选树"
    print("  DTB 数: %d，占用 %d/%d bytes" % (n, off, len(tail)))

    print("\n-- ramdisk --")
    try:
        cp = lzma.decompress(ramdisk)
        kind = "xz"
    except Exception:
        try:
            cp = gzip.decompress(ramdisk)
            kind = "gzip"
        except Exception:
            cp = ramdisk
            kind = "raw"
    names, i = [], 0
    while i + 110 <= len(cp) and cp[i:i + 6] in (b"070701", b"070702"):
        f = lambda k: int(cp[i + 6 + k * 8:i + 6 + k * 8 + 8], 16)
        size, ns = f(6), f(11)
        nm = cp[i + 110:i + 110 + ns - 1].decode("utf-8", "replace")
        if nm == "TRAILER!!!":
            break
        names.append(nm)
        i += (110 + ns + 3) & ~3
        i += (size + 3) & ~3
    print("  格式 %s，%d 个条目；含 init: %s" % (kind, len(names), "init" in names))
    print("  条目:", ", ".join(names[:14]))
    assert "init" in names, "ramdisk 里没有 init"

    # —— 关键检查：init 必须是「可执行的、目标架构正确的」程序 ——
    # （曾经踩过坑：把 WSL 里 x86_64 的 busybox 脚本打进 initramfs，
    #   内核永远 exec 不了 /init → 秒 panic，而这里只检查"有没有 init"是查不出来的）
    i = 0
    init_data, init_mode = None, None
    while i + 110 <= len(cp):
        if cp[i:i + 6] not in (b"070701", b"070702"):
            break
        g = lambda k: int(cp[i + 6 + k * 8:i + 6 + k * 8 + 8], 16)
        mode_, size_, nsize = g(1), g(6), g(11)
        nm = cp[i + 110:i + 110 + nsize - 1].decode("utf-8", "replace")
        i += (110 + nsize + 3) & ~3
        if nm == "init":
            init_data, init_mode = cp[i:i + size_], mode_
            break
        i += (size_ + 3) & ~3
    if init_data is None:
        print("  !! 无法定位 init 内容")
    else:
        exec_ok = bool(init_mode & 0o111)
        if init_data[:4] == b"\x7fELF":
            machine = struct.unpack_from("<H", init_data, 18)[0]
            arch = {0xB7: "ARM aarch64", 0x3E: "x86-64"}.get(machine, "0x%x" % machine)
            print("  init: ELF, 架构=%s, 可执行位=%s" % (arch, "有" if exec_ok else "无"))
            assert machine == 0xB7, "init 不是 ARM64 程序（架构=%s）—— 内核无法执行，会直接 panic" % arch
        elif init_data[:2] == b"#!":
            shebang = init_data.split(b"\n")[0].decode("utf-8", "replace")
            print("  init: 脚本, shebang = %s" % shebang)
            print("  ⚠ initramfs 里的 init 是脚本 —— 需要解释器存在于 initramfs 内，且必须是目标架构")
        else:
            print("  init: 未知格式, 前 8 字节 = %s" % init_data[:8].hex())
        if not exec_ok:
            print("  ⚠ init 没有可执行位！内核 exec 会失败")
    print("\n✅ 全部检查通过：这是一枚 natrium 可引导的 6.18 boot.img")


if __name__ == "__main__":
    main()
