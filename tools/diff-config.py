import os
import re

PMOS = r"natrium-port\build\pmos-ref\config-postmarketos-qcom-msm8996.aarch64"
MINE = r"natrium-port\out\config-6.18-natrium"


def load(p):
    d = {}
    for line in open(p, encoding="utf-8", errors="replace"):
        line = line.strip()
        m = re.match(r"^(CONFIG_[A-Z0-9_]+)=(.*)$", line)
        if m:
            d[m.group(1)] = m.group(2)
        m = re.match(r"^# (CONFIG_[A-Z0-9_]+) is not set$", line)
        if m:
            d[m.group(1)] = "n"
    return d


a = load(PMOS)   # pmOS
b = load(MINE)   # 我们的

print("pmOS 配置符号数: %d，我们的: %d" % (len(a), len(b)))
print()

KEY = re.compile(r"QCOM|MSM8996|ARM64|SMMU|IOMMU|PINCTRL|CLK|REGULATOR|INTERCONNECT|RPM|SPMI|PHY_|UFS|DRM_MSM|PANEL_JDI|FBDEV|FRAMEBUFFER|RMI4|EXT4|F2FS|IKCONFIG|PSTORE|DEBUG|SERIAL|USB_DWC3|REMOTEPROC|QDSP6|SND_SOC_MSM")

builtin_only_in_pmos = []
for k, v in a.items():
    if v != "y":
        continue
    if b.get(k) not in ("y",):
        if KEY.search(k):
            builtin_only_in_pmos.append((k, b.get(k, "缺失")))

print("=== pmOS 内建(=y)、而我们不是 =y 的关键符号（前 60 个）===")
for k, v in sorted(builtin_only_in_pmos)[:60]:
    print("  %-52s pmOS=y   我们=%s" % (k, v))
print("  ... 共 %d 个" % len(builtin_only_in_pmos))

print()
print("=== 反过来：我们 =y 而 pmOS 不是 =y 的（前 25）===")
cnt = 0
for k, v in sorted(b.items()):
    if v == "y" and a.get(k) not in ("y",) and KEY.search(k):
        print("  %-52s pmOS=%s" % (k, a.get(k, "缺失")))
        cnt += 1
        if cnt >= 25:
            break
