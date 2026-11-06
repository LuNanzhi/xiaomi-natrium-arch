import json
import re
import urllib.request


def get(u, t=60):
    return urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "curl/8.0"}), timeout=t).read().decode("utf-8", "replace")


print("=== images.nura.eco/edge/ ===")
try:
    t = get("https://images.nura.eco/edge/")
    links = sorted(set(re.findall(r'href="([^"?][^"]*)"', t)))
    print("  %d 条:" % len(links), links[:25])
except Exception as e:
    print("  ERR", e)

print()
print("=== nura.eco/download/ ===")
try:
    t = get("https://nura.eco/download/")
    links = sorted(set(re.findall(r'href="([^"?][^"]*)"', t)))
    nat = [x for x in links if "natrium" in x.lower()]
    print("  natrium:", nat if nat else "无")
    print("  前 20:", links[:20])
except Exception as e:
    print("  ERR", e)

print()
print("=== 试历史发布目录里有没有 natrium ===")
for base in ["https://images.nura.eco/v25.06/", "https://images.nura.eco/v24.12/",
             "https://images.postmarketos.org/postmarketos/v24.12/",
             "https://images.nura.eco/edge/xiaomi-natrium/",
             "https://images.nura.eco/edge/natrium/"]:
    try:
        t = get(base, 45)
        links = sorted(set(re.findall(r'href="([^"?][^"]*)"', t)))
        print("  %-52s -> %s" % (base, links[:8]))
    except Exception as e:
        print("  %-52s ERR %s" % (base, e))
