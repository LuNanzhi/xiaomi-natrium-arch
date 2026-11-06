#!/usr/bin/env bash
# 修 pmbootstrap 的索引文件名不一致问题，并预置 apk.static，然后继续完整流水线
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap

echo "########## 1) 找出 Alpine main x86_64 索引并按 pmbootstrap 期待的名字补齐 ##########"
echo "--- 缓存里的索引（按大小判断归属；531284 = 清华 alpine edge/main x86_64）---"
for f in "$WORK"/cache_apk_x86_64/APKINDEX.*.tar.gz; do
  [ -e "$f" ] || continue
  printf '  %-46s %8d bytes\n' "$(basename "$f")" "$(stat -c%s "$f")"
done

SRC=""
for f in "$WORK"/cache_apk_x86_64/APKINDEX.*.tar.gz; do
  [ -e "$f" ] || continue
  if [ "$(stat -c%s "$f")" = "531284" ]; then SRC="$f"; fi
done
if [ -n "$SRC" ]; then
  TARGET="$WORK/cache_apk_x86_64/APKINDEX.2e7b893f.tar.gz"
  cp -f "$SRC" "$TARGET"
  echo "  已用 $(basename "$SRC") 补齐 -> $(basename "$TARGET")"
  # 验证里面确实有 apk-tools-static
  n=$(tar -xzOf "$TARGET" APKINDEX 2>/dev/null | grep -c '^P:apk-tools-static')
  echo "  校验：该索引含 apk-tools-static 条目 $n 个"
else
  echo "  !! 没找到 531284 字节的索引，改为直接下载"
  curl -s -o "$WORK/cache_apk_x86_64/APKINDEX.2e7b893f.tar.gz" --max-time 60 \
    "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/x86_64/APKINDEX.tar.gz"
  ls -l "$WORK/cache_apk_x86_64/APKINDEX.2e7b893f.tar.gz"
fi

echo
echo "########## 2) 预置 apk.static（双保险）##########"
if [ ! -x "$WORK/apk.static" ]; then
  cd /tmp && rm -rf apkst && mkdir apkst && cd apkst
  if curl -s -O --max-time 120 "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/x86_64/apk-tools-static-3.0.8-r0.apk"; then
    tar -xzf apk-tools-static-3.0.8-r0.apk 2>/dev/null
    if [ -f sbin/apk.static ]; then
      cp -f sbin/apk.static "$WORK/apk.static"; chmod 755 "$WORK/apk.static"
      echo "  已预置 $WORK/apk.static ($(file -b "$WORK/apk.static" | cut -c1-60))"
    else
      echo "  !! 解包后没有 sbin/apk.static"; ls -R | head
    fi
  else
    echo "  !! 下载 apk-tools-static 失败"
  fi
else
  echo "  已存在: $(file -b "$WORK/apk.static" | cut -c1-60)"
fi

echo
echo "########## 3) 构建内核包（用 Sharp 补丁树，最长 90 分钟）##########"
date
timeout 7200 python3 "$PB" --as-root -y build --src=/root/linux-sharp linux-postmarketos-qcom-msm8996 2>&1 | tail -30
echo "内核包退出码 $?"
ls -lh "$WORK"/packages/*/aarch64/linux-postmarketos-qcom-msm8996*.apk 2>/dev/null

echo
echo "########## 4) 构建设备包 ##########"
timeout 3600 python3 "$PB" --as-root -y build device-xiaomi-natrium 2>&1 | tail -15
echo "设备包退出码 $?"

echo
echo "########## 5) 装配 Phosh 完整系统（最长 150 分钟）##########"
date
timeout 9000 python3 "$PB" --as-root -y install --password 1234 --split 2>&1 | tail -35
echo "install 退出码 $?"
date
ls -lh "$WORK"/*.img 2>/dev/null

echo
echo "########## 6) 导出到 Windows ##########"
timeout 900 python3 "$PB" --as-root export 2>&1 | tail -8
ls -lL /tmp/postmarketos-export/ 2>/dev/null
mkdir -p /mnt/c/Users/Public/natrium/pmos
for f in /tmp/postmarketos-export/*; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  case "$base" in
    boot*.img) cp -fL "$f" /mnt/c/Users/Public/natrium/pmos/boot-sharp.img && echo "  -> boot-sharp.img ($base)";;
    *) cp -fL "$f" "/mnt/c/Users/Public/natrium/pmos/$base" 2>/dev/null && echo "  -> $base";;
  esac
done
ls -lh /mnt/c/Users/Public/natrium/pmos/ 2>/dev/null
du -sh "$WORK" 2>/dev/null
df -h / | tail -1
