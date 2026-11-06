#!/usr/bin/env python3
"""从 vmlinuz 里提取内嵌内核配置（IKCONFIG），并核查 UFS 相关选项。"""
import gzip
import io
import lzma
import re
import struct
import sys

path = "/mnt/c/Users/Public/natrium/pmos/vmlinuz"
d = open(path, "rb").read()
print("文件 %s  %d bytes" % (path, len(d)))

# 1) 先看它是什么格式
nf = d
kind = "raw"
try:
    if d[:2] == b"\x1f\x8b":
        nf = gzip.decompress(d); kind = "gzip"
    elif d[:6] == b"\xfd7zXZ\x00":
        nf = lzma.decompress(d); kind = "xz"
except Exception as e:
    print("  解压失败:", e)
print("  格式: %s, 解压后 %d bytes" % (kind, len(nf)))

# 2) 找内嵌配置的魔数
i = nf.find(b"IKCFG_ST")
print("  IKCFG_ST 位置:", i)
if i >= 0:
    start = i + 8
    # 之后通常紧跟一个 gzip 流
    j = nf.find(b"\x1f\x8b", start)
    print("  内嵌 gzip 起点:", j)
    if j >= 0:
        try:
            cfg = gzip.decompress(nf[j:]).decode("utf-8", "replace")
        except Exception:
            # 可能在 IKCFG_ED 处结束
            k = nf.find(b"IKCFG_ED", j)
            try:
                cfg = gzip.decompress(nf[j:k]).decode("utf-8", "replace")
            except Exception as e:
                cfg = ""
                print("  配置解压失败:", e)
        if cfg:
            print("  内嵌配置行数: %d" % len(cfg.splitlines()))
            keys = ["CONFIG_SCSI_UFSHCD", "CONFIG_SCSI_UFSHCD_PLATFORM", "CONFIG_SCSI_UFS_QCOM",
                    "CONFIG_PHY_QCOM_QMP_UFS", "CONFIG_PHY_QCOM_QMP", "CONFIG_QCOM_ICE",
                    "CONFIG_PHY_QCOM_UFS_20NM", "CONFIG_SCSI_UFS_CRYPTO",
                    "CONFIG_DRM_PANEL_SHARP_TD4722_XCMD", "CONFIG_DRM_PANEL_JDI_R63452",
                    "CONFIG_REGULATOR_QCOM_SMD_RPM", "CONFIG_QCOM_CLK_SMD_RPM"]
            print("  --- UFS / 面板 / PMIC 相关 ---")
            for k in keys:
                m = re.search(r"^(# )?%s(=.*| is not set)$" % k, cfg, re.M)
                print("   %-38s %s" % (k, m.group(0) if m else "(未出现)"))
else:
    print("  ✗ 没找到内嵌配置")

# 3) 直接找驱动字符串
print()
print("=== 驱动/兼容字符串是否在镜像里 ===")
for kw in (b"qcom,msm8996-ufshc", b"qcom,msm8996-qmp-ufs-phy", b"ufs_qcom", b"ufshcd-qcom",
           b"phy init failed", b"Failed to get PHY", b"sharp,td4722-xcmd"):
    print("  %-30s %s" % (kw.decode(), "✅ 在" if kw in nf else "❌ 不在"))
