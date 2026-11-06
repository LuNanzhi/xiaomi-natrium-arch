import re
import urllib.request

# 1) LineageOS 发布目录里有哪些文件（是否存在 dtbo.img）
for u in ["https://mirrorbits.lineageos.org/full/natrium/20261004/",
          "http://mirrorbits.lineageos.org/full/natrium/20261004/"]:
    try:
        d = urllib.request.urlopen(u, timeout=45).read().decode("utf-8", "replace")
        print("==", u)
        for x in sorted(set(re.findall(r'href="([^"?][^"]*)"', d))):
            print("   ", x)
        break
    except Exception as e:
        print("  ERR", u, e)
