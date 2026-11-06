import sys

pkg = ver = ""
best = ("", "", 0)
for line in sys.stdin:
    line = line.rstrip("\n")
    if line.startswith("P:"):
        pkg = line[2:]
    elif line.startswith("V:"):
        ver = line[2:]
    elif line.startswith("S:") and pkg:
        try:
            s = int(line[2:])
        except ValueError:
            s = 0
        if s > best[2]:
            best = (pkg, ver, s)
if best[0]:
    print("%s-%s.apk %d" % (best[0], best[1], best[2]))
