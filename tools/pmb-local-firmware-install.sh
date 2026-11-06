#!/usr/bin/env bash
# 用本地固件文件伪造 firmware-xiaomi-natrium 的源码包（绕开仓库 403），
# 修正 extra_packages 空项，然后构建固件包 + 设备包 + 装配 Phosh + 导出
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap
NAT=/mnt/c/Users/Public/natrium
FWPKG=/root/pmaports/device/archived/firmware-xiaomi-natrium
COMMIT=ec5784e0abed3ce08a45543144f19fd32450b297
TOP="firmware-xiaomi-natrium-$COMMIT"

echo "########## 1) 修掉 extra_packages 空项 ##########"
python3 - "$HOME/.config/pmbootstrap_v3.cfg" <<'PY'
import sys
p = sys.argv[1]
out = []
for line in open(p, encoding="utf-8"):
    if line.strip().startswith("extra_packages"):
        continue
    out.append(line)
open(p, "w", encoding="utf-8", newline="\n").writelines(out)
print("  已移除 extra_packages 行")
PY
grep -c 'extra_packages' /root/.config/pmbootstrap_v3.cfg || echo "  确认：配置里已无该项"

echo
echo "########## 2) 组装本地固件源码包 ##########"
rm -rf /root/fwbuild; mkdir -p "/root/fwbuild/$TOP"
cp -rL "$NAT/firmware/lib" "/root/fwbuild/$TOP/"
find "/root/fwbuild/$TOP" -type f | sed 's|/root/fwbuild/||'
tar -czf "$FWPKG/firmware-xiaomi-natrium.tar.gz" -C /root/fwbuild "$TOP"
ls -lh "$FWPKG/firmware-xiaomi-natrium.tar.gz"
echo "  校验内容："
tar -tzf "$FWPKG/firmware-xiaomi-natrium.tar.gz" | head -8

echo
echo "########## 3) 改 APKBUILD（改成本地源）并更新校验和 ##########"
python3 - "$FWPKG/APKBUILD" <<'PY'
import hashlib, os, re, sys
p = sys.argv[1]
base = os.path.dirname(p)
s = open(p, encoding="utf-8").read()
# 把远端 tar.gz 源改成本地文件
s = re.sub(r'\$\{?pkgname\}?\.tar\.gz::\$url/-/archive/\$_commit/\$pkgname-\$_commit\.tar\.gz',
           'firmware-xiaomi-natrium.tar.gz', s)
s = s.replace('$pkgname.tar.gz::$url/-/archive/$_commit/$pkgname-$_commit.tar.gz',
              'firmware-xiaomi-natrium.tar.gz')
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("  source 段现在是：")
m = re.search(r'source="(.*?)"', s, re.S)
print("   ", " ".join(m.group(1).split()) if m else "(?)")
# 更新 tar.gz 的校验和
new = hashlib.sha512(open(os.path.join(base, "firmware-xiaomi-natrium.tar.gz"), "rb").read()).hexdigest()
s = open(p, encoding="utf-8").read()
s2 = re.sub(r'^([0-9a-f]{128})(\s+firmware-xiaomi-natrium\.tar\.gz\s*)$',
            new + r'\2', s, flags=re.M)
if s2 == s:
    print("  !! 没能替换校验和，尝试追加")
    s2 = s.rstrip() + "\n" + new + "  firmware-xiaomi-natrium.tar.gz\n"
open(p, "w", encoding="utf-8", newline="\n").write(s2)
print("  新校验和 %s..." % new[:16])
PY

echo
echo "########## 4) 清理并构建固件包 ##########"
pkill -f 'abuild' 2>/dev/null; pkill -f 'apk.static' 2>/dev/null; sleep 2
find "$WORK" -name 'lock' -path '*apk*' -delete 2>/dev/null
rm -f "$WORK/log.txt"
timeout 1800 python3 "$PB" --as-root -y build firmware-xiaomi-natrium 2>&1 | tail -12
echo "固件包退出码 $?"

echo
echo "########## 5) 构建设备包 ##########"
timeout 1800 python3 "$PB" --as-root -y build device-xiaomi-natrium 2>&1 | tail -12
echo "设备包退出码 $?"
ls -lh "$WORK"/packages/*/aarch64/*.apk 2>/dev/null | tail -6

echo
echo "########## 6) 装配 Phosh 完整系统（最长 120 分钟）##########"
date
timeout 7200 python3 "$PB" --as-root -y install --password 1234 --split 2>&1 | tail -35
echo "install 退出码 $?"
date
ls -lh "$WORK"/*.img 2>/dev/null

echo
echo "########## 7) 导出到 Windows ##########"
timeout 900 python3 "$PB" --as-root export 2>&1 | tail -8
ls -lL /tmp/postmarketos-export/ 2>/dev/null
mkdir -p "$NAT/pmos"
for f in /tmp/postmarketos-export/*; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  case "$base" in
    boot*.img) cp -fL "$f" "$NAT/pmos/boot-sharp.img" && echo "  -> boot-sharp.img ($base)";;
    *) cp -fL "$f" "$NAT/pmos/$base" 2>/dev/null && echo "  -> $base";;
  esac
done
ls -lh "$NAT/pmos/" 2>/dev/null
du -sh "$WORK" 2>/dev/null
df -h / | tail -1
