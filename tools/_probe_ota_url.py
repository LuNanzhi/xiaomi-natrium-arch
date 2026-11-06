import urllib.error
import urllib.request

ZIPNAME = "lineage-22.2-20261004-nightly-natrium-signed.zip"
URLS = [
    "http://mirrorbits.lineageos.org/full/natrium/20261004/" + ZIPNAME,
    "https://mirrorbits.lineageos.org/full/natrium/20261004/" + ZIPNAME,
    "http://mirrorbits.lineageos.org/full/natrium/20261004/boot.img",
    "https://mirrors.ustc.edu.cn/lineageos/full/natrium/20261004/" + ZIPNAME,
    "https://mirrors.ustc.edu.cn/lineageos/full/natrium/20261004/",
    "https://mirrors.tuna.tsinghua.edu.cn/lineageos/full/natrium/20261004/" + ZIPNAME,
]


def try_read(url, n=2048):
    print("== ", url)
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "curl/8.0"}), timeout=90)
        head = r.read(n)
        print("     状态 %s  Content-Type=%s  Content-Length=%s" % (r.status, r.headers.get("Content-Type"), r.headers.get("Content-Length")))
        print("     前 %d 字节: %r" % (len(head), head[:200]))
        r.close()
        return True
    except urllib.error.HTTPError as e:
        print("     HTTP %s %s  Location=%s" % (e.code, e.reason, e.headers.get("Location")))
    except Exception as e:
        print("     失败:", type(e).__name__, e)
    return False


for u in URLS:
    try_read(u)

print("\n== mirrorbits 镜像列表 ==")
for q in ["?mirrorlist", "?mirrorlist=1"]:
    try:
        r = urllib.request.urlopen("https://mirrorbits.lineageos.org/full/natrium/20261004/" + ZIPNAME + q,
                                   timeout=60)
        print(" ", q, "->", r.read(2000).decode("utf-8", "replace"))
    except Exception as e:
        print(" ", q, "->", type(e).__name__, e)
