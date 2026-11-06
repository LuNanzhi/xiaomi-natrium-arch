import re
import urllib.request
import urllib.parse

RAW = "https://raw.githubusercontent.com/torvalds/linux/v6.18/"

# 1) zap 调用点所在的函数（在 probe 里就致命，在 hw_init 里只是 GPU 不可用）
d = urllib.request.urlopen(RAW + "drivers/gpu/drm/msm/adreno/a5xx_gpu.c", timeout=60).read().decode()
lines = d.splitlines()
call = [i for i, l in enumerate(lines) if "a5xx_zap_shader_init(gpu)" in l and "static int a5xx_zap" not in l]
print("=== a5xx_gpu.c 中调用 zap 的位置 ===")
for i in call:
    fn = "?"
    for j in range(i, 0, -1):
        m = re.match(r"^(?:static\s+)?(?:int|void|struct \w+ \*)\s+(\w+)\s*\(", lines[j])
        if m and not lines[j].startswith((" ", "\t")):
            fn = m.group(1)
            break
    print("  行 %d 函数 %s: %s" % (i + 1, fn, lines[i].strip()))

# 2) msm DRM 是否跳过 disabled 的 GPU 节点
d2 = urllib.request.urlopen(RAW + "drivers/gpu/drm/msm/msm_drv.c", timeout=60).read().decode()
i = d2.find("add_gpu_components")
i = d2.find("add_gpu_components") if i >= 0 else -1
start = d2.find("static int add_gpu_components")
print("\n=== msm_drv.c: add_gpu_components ===")
print(d2[start:start + 1200] if start >= 0 else "未找到（可能改名）")

# 3) pmOS 固件包下载地址
print("\n=== pmOS firmware-xiaomi-natrium 包地址探测 ===")
for u in ["https://pkgs.postmarketos.org/package/v25.12/postmarketos/aarch64/firmware-xiaomi-natrium",
          "https://mirror.postmarketos.org/postmarketos/v25.12/aarch64/"]:
    try:
        t = urllib.request.urlopen(u, timeout=60).read().decode("utf-8", "replace")
        hits = sorted(set(re.findall(r'href="([^"]*firmware-xiaomi-natrium[^"]*)"', t)))
        print("  ", u, "->", hits[:6] if hits else "无直链（%d 字节）" % len(t))
    except Exception as e:
        print("  ", u, "ERR", e)
