import re
import urllib.request

for u in ["https://cloud-images.ubuntu.com/wsl/releases/24.04/current/",
          "https://cloud-images.ubuntu.com/wsl/noble/current/",
          "https://cloud-images.ubuntu.com/wsl/releases/26.04/current/"]:
    print("==", u)
    try:
        d = urllib.request.urlopen(u, timeout=45).read().decode("utf-8", "replace")
        for x in re.findall(r'href="([^"?][^"]*)"', d):
            if x.endswith(".tar.gz") or x.endswith(".tar.xz") or x.endswith(".rootfs.tar.gz"):
                print("   ", x)
    except Exception as e:
        print("   ERR", e)
