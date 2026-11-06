import json
import re
import urllib.parse
import urllib.request


def get(u, t=60):
    r = urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "curl/8.0"}), timeout=t)
    return r.read()


print("=== 1) 在 pmOS 新 wiki 里搜 natrium / Mi 5s Plus ===")
for q in ["natrium", "Mi 5s Plus"]:
    u = "https://wiki.nura.eco/api.php?action=query&list=search&srsearch=%s&format=json&srlimit=8" % urllib.parse.quote(q)
    try:
        d = json.loads(get(u).decode("utf-8", "replace"))
        hits = [x["title"] for x in d.get("query", {}).get("search", [])]
        print("  %-14s -> %s" % (q, hits if hits else "无"))
    except Exception as e:
        print("  %-14s ERR %s" % (q, e))

print()
print("=== 2) 试各种 pmOS 镜像站路径 ===")
CANDS = [
    "https://images.postmarketos.org/postmarketos/",
    "https://images.postmarketos.org/postmarketos/v25.12/",
    "https://images.postmarketos.org/",
    "https://images.nura.eco/",
    "https://mirror.postmarketos.org/postmarketos/v25.12/",
    "https://mirrors.nura.eco/postmarketos/v25.12/",
]
for u in CANDS:
    try:
        b = get(u, 45)
        t = b.decode("utf-8", "replace")
        links = sorted(set(re.findall(r'href="([^"?][^"]*)"', t)))
        nat = [x for x in links if "natrium" in x.lower()]
        print("  %-58s %d 条链接; natrium: %s" % (u, len(links), nat[:4] if nat else "无"))
        if links and not nat:
            print("      样例:", links[:8])
    except Exception as e:
        print("  %-58s ERR %s" % (u, e))
