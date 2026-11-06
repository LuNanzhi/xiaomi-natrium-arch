#!/usr/bin/env bash
# 对比 mainline 6.18.55 与 pmOS(msm8996-mainline 6.19.5) 的 natrium 设备树差异
set -uo pipefail
A=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/out/msm8996pro-xiaomi-natrium.dtb
B=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/build/pmos-ref/msm8996pro-xiaomi-natrium.dtb
C=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/stage/msm8996pro-xiaomi-natrium.dtb
OUT=/mnt/c/Users/Public/natrium/dtb-diff.txt

for f in "$A" "$B"; do
  [ -f "$f" ] || { echo "缺文件: $f"; exit 1; }
done

dtc -I dtb -O dts -o /tmp/a.dts "$A" 2>/dev/null
dtc -I dtb -O dts -o /tmp/b.dts "$B" 2>/dev/null
[ -f "$C" ] && dtc -I dtb -O dts -o /tmp/c.dts "$C" 2>/dev/null

echo "A = mainline 6.18.55 : $(stat -c%s "$A") bytes, $(wc -l < /tmp/a.dts) 行"
echo "B = pmOS 6.19.5     : $(stat -c%s "$B") bytes, $(wc -l < /tmp/b.dts) 行"
[ -f /tmp/c.dts ] && echo "C = 补丁树 6.18.7    : $(stat -c%s "$C") bytes, $(wc -l < /tmp/c.dts) 行"

{
  echo "===== diff: mainline 6.18.55  vs  pmOS 6.19.5（natrium）====="
  diff -u /tmp/a.dts /tmp/b.dts | head -400
  echo
  echo "===== 我们编译的 6.18.7 与 pmOS 6.19.5 是否一致 ====="
  if [ -f /tmp/c.dts ]; then
    if diff -q /tmp/c.dts /tmp/b.dts >/dev/null 2>&1; then
      echo "  完全一致 —— 说明 6.18.7 树里的 natrium 设备树就是 pmOS 现在用的那棵 ✅"
    else
      echo "  有差异，行数: $(diff /tmp/c.dts /tmp/b.dts | wc -l)"
      diff -u /tmp/c.dts /tmp/b.dts | head -80
    fi
  fi
} > "$OUT" 2>&1

echo
echo "=== 关键差异摘要（只看节点/属性增删）==="
diff /tmp/a.dts /tmp/b.dts | grep -E '^[<>]' | grep -vE '^[<>]\s*$' | head -60
echo
echo "完整差分已写入: $OUT ($(stat -c%s "$OUT") bytes)"
