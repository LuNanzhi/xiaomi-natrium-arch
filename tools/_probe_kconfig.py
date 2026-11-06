import re
import urllib.request

for path in ["drivers/gpu/drm/msm/Kconfig"]:
    u = "https://raw.githubusercontent.com/torvalds/linux/v6.18/" + path
    d = urllib.request.urlopen(u, timeout=60).read().decode()
    m = re.search(r"config DRM_MSM\n(.*?)\n\n", d, re.S)
    print("=====", path, "=====")
    print(m.group(0) if m else d[:2000])

# 面板驱动的依赖
u = "https://raw.githubusercontent.com/torvalds/linux/v6.18/drivers/gpu/drm/panel/Kconfig"
d = urllib.request.urlopen(u, timeout=60).read().decode()
m = re.search(r"config DRM_PANEL_JDI_FHD_R63452\n(.*?)\n\n", d, re.S)
print("\n===== panel Kconfig =====")
print(m.group(0) if m else "未找到")
