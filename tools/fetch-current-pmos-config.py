import os
import urllib.parse
import urllib.request

PROJ = urllib.parse.quote("postmarketOS/pmaports", safe="")
BASE = "https://gitlab.postmarketos.org/api/v4/projects/" + PROJ
DIR = "device/testing/linux-postmarketos-qcom-msm8996"
OUT = r"natrium-port\build\pmos-ref"
os.makedirs(OUT, exist_ok=True)


def raw(name, ref="main"):
    url = "%s/repository/files/%s/raw?ref=%s" % (BASE, urllib.parse.quote(DIR + "/" + name, safe=""), ref)
    return urllib.request.urlopen(url, timeout=120).read()


print("=== APKBUILD (current, main) ===")
try:
    d = raw("APKBUILD")
    open(os.path.join(OUT, "APKBUILD.current"), "wb").write(d)
    print("  %d bytes 已保存" % len(d))
    for line in d.decode("utf-8", "replace").splitlines():
        s = line.strip()
        if any(k in s for k in ("pkgver", "pkgrel", "_tag", "_flavor", "config-", "source=", "url=")):
            print("   |", s[:140])
except Exception as e:
    print("  失败:", e)

print()
print("=== config-postmarketos-qcom-msm8996.aarch64 (current, main) ===")
try:
    d = raw("config-postmarketos-qcom-msm8996.aarch64")
    p = os.path.join(OUT, "config-postmarketos-qcom-msm8996.aarch64.current")
    open(p, "wb").write(d)
    txt = d.decode("utf-8", "replace")
    print("  %d bytes 已保存 -> %s" % (len(d), p))
    print("  符号数: %d" % sum(1 for l in txt.splitlines() if l.startswith("CONFIG_")))
    import re
    for s in ["CONFIG_LOCALVERSION", "CONFIG_PANIC_TIMEOUT", "CONFIG_PHY_QCOM_QMP_UFS", "CONFIG_PHY_QCOM_USB_HS",
              "CONFIG_DRM_MSM", "CONFIG_DRM_PANEL_JDI_R63452", "CONFIG_ARM64_VA_BITS_48", "CONFIG_QCOM_WDT",
              "CONFIG_PSTORE_RAM", "CONFIG_IKCONFIG", "CONFIG_SCSI_UFS_QCOM", "CONFIG_PHY_QCOM_QMP"]:
        m = re.search(r"^(%s)=?(.*)$" % s, txt, re.M)
        print("    %-34s %s" % (s, m.group(0) if m else "(未出现)"))
except Exception as e:
    print("  失败:", e)
