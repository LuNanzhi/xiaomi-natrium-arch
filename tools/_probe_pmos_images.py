import json
import re
import urllib.request

CANDIDATES = [
    "https://images.postmarketos.org/postmarketos/",
    "https://images.nura.eco/postmarketos/",
    "https://mirror.postmarketos.org/postmarketos/",
    "https://mirrors.nura.eco/postmarketos/",
]


def get(u, t=60):
    return urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "curl/8.0"}), timeout=t).read().decode("utf-8", "replace")


for base in CANDIDATES:
    print("==", base)
    try:
        t = get(base)
        links = sorted(set(re.findall(r'href="([^"?][^"]*)"', t)))
        nat = [x for x in links if "natrium" in x.lower()]
        print("   %d 个链接；含 natrium: %s" % (len(links), nat[:5] if nat else "无"))
        if not nat:
            print("   前 15 个条目:", links[:15])
    except Exception as e:
        print("   ERR", e)
