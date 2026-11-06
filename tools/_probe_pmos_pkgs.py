import re
import urllib.request

PAT = re.compile(r"https?://[^\"'<> ]+\.apk")


def get(u, t=90):
    return urllib.request.urlopen(u, timeout=t).read().decode("utf-8", "replace")


print("=== pmOS 软件包页面 ===")
for u in ["https://pkgs.postmarketos.org/package/v25.12/postmarketos/aarch64/firmware-xiaomi-natrium",
          "https://pkgs.postmarketos.org/package/v25.12/postmarketos/aarch64/device-xiaomi-natrium"]:
    try:
        t = get(u, 60)
        apk = sorted(set(PAT.findall(t)))
        print("  ", u.split("/")[-1], "->", apk[:3] if apk else "无 .apk 直链 (%d 字节)" % len(t))
    except Exception as e:
        print("  ", u, "ERR", e)

print("\n=== pmOS 镜像目录 ===")
for u in ["https://mirror.postmarketos.org/postmarketos/v25.12/aarch64/",
          "https://mirror.postmarketos.org/postmarketos/master/aarch64/"]:
    try:
        t = get(u, 120)
        hits = sorted(set(re.findall(r'href="([^"]*natrium[^"]*)"', t)))
        print("  ", u, "->", len(t), "字节; natrium 命中:", hits[:5])
    except Exception as e:
        print("  ", u, "ERR", e)
