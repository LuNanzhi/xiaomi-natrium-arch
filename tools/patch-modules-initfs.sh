#!/usr/bin/env bash
# 让 pmOS 的 initramfs 带上 Sharp 面板模块，并同步 APKBUILD 校验和
set -uo pipefail
DEV=/root/pmaports/device/archived/device-xiaomi-natrium
MI="$DEV/modules-initfs"
APK="$DEV/APKBUILD"

echo "=== 1) 修改 modules-initfs（加入 Sharp 面板模块）==="
cp -f "$MI" "$MI.bak.$(date +%s)"
if grep -q '^panel_sharp_td4722_xcmd$' "$MI"; then
  echo "  已存在，跳过"
else
  printf 'panel_sharp_td4722_xcmd\n' >> "$MI"
  echo "  已追加"
fi
cat "$MI"

echo
echo "=== 2) 计算新校验和并更新 APKBUILD ==="
NEW=$(sha512sum "$MI" | cut -d' ' -f1)
echo "  modules-initfs sha512 = $NEW"
python3 - "$APK" "$NEW" <<'PY'
import re, sys
path, new = sys.argv[1], sys.argv[2]
s = open(path, encoding="utf-8").read()
# 在 sha512sums 区块里，把 modules-initfs 前面那一行的哈希替换掉
pattern = re.compile(r'^([0-9a-f]{128})(\s+modules-initfs\s*)$', re.M)
m = pattern.search(s)
if not m:
    print("  !! 没找到 modules-initfs 的校验和条目")
    print("  --- APKBUILD 里的 sha512sums 段 ---")
    i = s.find("sha512sums")
    print(s[i:i+800])
    sys.exit(1)
old = m.group(1)
s = s[:m.start(1)] + new + s[m.end(1):]
open(path, "w", encoding="utf-8", newline="\n").write(s)
print("  已更新: %s... -> %s..." % (old[:16], new[:16]))
PY

echo
echo "=== 3) 校验 APKBUILD 现在与文件一致 ==="
python3 - "$APK" <<'PY'
import hashlib, re, sys, os
path = sys.argv[1]
s = open(path, encoding="utf-8").read()
base = os.path.dirname(path)
ok = bad = 0
for m in re.finditer(r'^([0-9a-f]{128})\s+(\S+)\s*$', s, re.M):
    want, name = m.group(1), m.group(2)
    p = os.path.join(base, name)
    if not os.path.isfile(p):
        print("  (跳过不存在的文件 %s)" % name)
        continue
    got = hashlib.sha512(open(p, "rb").read()).hexdigest()
    if got == want:
        ok += 1
    else:
        bad += 1
        print("  ✗ 校验和不符: %s" % name)
print("  一致 %d 个，不符 %d 个" % (ok, bad))
PY

echo
echo "=== 4) 确认内核包构建仍在进行（不受影响）==="
tail -2 /root/.local/var/pmbootstrap/log.txt 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
