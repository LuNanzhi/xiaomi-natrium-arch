import gzip
import io
import os
import re
import tarfile

REF = r"natrium-port\build\pmos-ref"
APK = os.path.join(REF, "linux-postmarketos-qcom-msm8996-6.19.5-r0.apk")
OUT = os.path.join(REF, "pmos-kernel-config")

print("=== 1) 列出内核包里的 boot/ 内容 ===")
data = open(APK, "rb").read()
raw = gzip.decompress(data)
pos, idx, files = 0, 0, []
vf = None
while pos < len(raw) - 1024 and idx < 8:
    try:
        tf = tarfile.open(fileobj=io.BytesIO(raw[pos:]), mode="r:")
    except Exception:
        break
    if not tf.getnames():
        break
    idx += 1
    for m in tf.getmembers():
        if m.isfile() and ("boot/" in m.name or m.name.endswith(".config")):
            files.append((m.name, m.size))
            if m.name.endswith("vmlinuz"):
                vf = tf.extractfile(m).read()
    pos += tf.offset
for n, s in sorted(files):
    print("  %-60s %9d" % (n, s))

print()
print("=== 2) 在内核镜像里找嵌入的 config (IKCFG_ST ... IKCFG_ED) ===")
if vf is None:
    print("  没找到 vmlinuz")
    raise SystemExit(1)
print("  vmlinuz 大小: %d bytes" % len(vf))
st = vf.find(b"IKCFG_ST")
ed = vf.find(b"IKCFG_ED")
print("  IKCFG_ST @ %s, IKCFG_ED @ %s" % (st, ed))
if st < 0:
    print("  => 内核没有内嵌 config（CONFIG_IKCONFIG 未开）。")
    # 退一步：在整个镜像里找可解压的 gzip 成员，看有没有像 config 的
    print("  尝试搜索内核里以 CONFIG_ 开头的明文片段:")
    m = re.search(rb"CONFIG_[A-Z0-9_]+=y\n", vf)
    print("   ", "找到" if m else "没找到")
    raise SystemExit(0)

gz = vf[st + 8:ed]
try:
    cfg = gzip.decompress(gz)
except Exception:
    # 有些内核是把 gzip 流放在标记之后但前面还有一个 gzip 头
    i = gz.find(b"\x1f\x8b")
    cfg = gzip.decompress(gz[i:]) if i >= 0 else b""
print("  解出 config: %d bytes" % len(cfg))
open(OUT, "wb").write(cfg)
print("  已保存: %s" % OUT)

txt = cfg.decode("utf-8", "replace")
print()
print("=== 3) 关键差异预览（pmOS 配置里的早启动相关项）===")
keys = ["CONFIG_LOCALVERSION", "CONFIG_ARM64_VA_BITS", "CONFIG_ARM64_4K_PAGES",
        "CONFIG_QCOM_Q6V5_PAS", "CONFIG_SCSI_UFS_QCOM", "CONFIG_PHY_QCOM_QMP_UFS",
        "CONFIG_PHY_QCOM_UFS_20NM", "CONFIG_PHY_QCOM_QMP", "CONFIG_DRM_MSM",
        "CONFIG_DRM_PANEL_JDI_R63452", "CONFIG_DRM_FBDEV_EMULATION", "CONFIG_FRAMEBUFFER_CONSOLE",
        "CONFIG_PINCTRL_MSM8996", "CONFIG_MSM_GCC_8996", "CONFIG_QCOM_SMD_RPM",
        "CONFIG_REGULATOR_QCOM_SMD_RPM", "CONFIG_ARM_SMMU", "CONFIG_QCOM_IOMMU",
        "CONFIG_INITRAMFS_SOURCE", "CONFIG_EXT4_FS", "CONFIG_IKCONFIG"]
for k in keys:
    m = re.search(r"^(%s)=?(.*)$" % k, txt, re.M)
    print("  %-34s %s" % (k, m.group(0) if m else "(不在配置里)"))
