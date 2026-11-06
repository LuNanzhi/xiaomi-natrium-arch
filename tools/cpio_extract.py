"""从 LineageOS ramdisk.cpio 里提取文件（默认 system/etc/fstab.qcom）并打印，用于确认分区表（是否有 dtbo）。"""
import sys

CPIO = r"natrium-port/bootimg/lineage-unpacked/ramdisk.cpio"


def parse(r):
    i = 0
    while i + 110 <= len(r) and r[i:i + 6] in (b"070701", b"070702"):
        f = lambda k: int(r[i + 6 + k * 8:i + 6 + k * 8 + 8], 16)
        size, namesize = f(6), f(11)
        name = r[i + 110:i + 110 + namesize - 1].decode("utf-8", "replace")
        i += (110 + namesize + 3) & ~3
        data = r[i:i + size]
        i += (size + 3) & ~3
        if name == "TRAILER!!!":
            break
        yield name, data


def main():
    want = sys.argv[1] if len(sys.argv) > 1 else "system/etc/fstab.qcom"
    r = open(CPIO, "rb").read()
    for name, data in parse(r):
        if name == want:
            print("===== %s (%d bytes) =====" % (name, len(data)))
            print(data.decode("utf-8", "replace"))
            return
    print("未找到", want, "；现有条目:")
    for name, data in parse(r):
        print("  ", name, len(data))


if __name__ == "__main__":
    main()
