#!/usr/bin/env bash
# Boot the phone into Arch and grab the evidence as early as possible.
# Usage: capture-boot.sh <outfile>
set -uo pipefail
OUT=${1:-/mnt/c/Users/Public/natrium/capture.txt}
SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3"

: > "$OUT"
for i in $(seq 1 40); do
    if timeout 8 sshpass -p arch ssh $SSHOPTS root@172.16.42.1 '
        echo "===== CAPTURED $(date) ====="
        echo "--- uptime ---"; uptime
        echo "--- pstore ---"; ls -la /sys/fs/pstore/ 2>&1
        echo "--- pstore content ---"; cat /sys/fs/pstore/* 2>/dev/null | head -120
        echo "--- previous boot (if any) ---"
        journalctl -b -1 --no-pager -k 2>/dev/null | grep -iE "panic|oops|BUG:|watchdog|Call trace" | tail -30
        echo "--- this boot errors ---"
        journalctl -b -k --no-pager 2>/dev/null | grep -iE "panic|oops|BUG:|watchdog|Call trace|enable_irq" | tail -30
        echo "--- dmesg tail ---"; dmesg 2>/dev/null | tail -15
        echo "--- thermal/battery ---"
        for f in /sys/class/power_supply/*/capacity /sys/class/power_supply/*/voltage_now; do
            [ -e "$f" ] && echo "$f = $(cat $f 2>/dev/null)"
        done
        echo "===== END ====="
    ' >> "$OUT" 2>/dev/null; then
        echo "[$i] captured" >> "$OUT"
        break
    fi
    sleep 3
done
tail -5 "$OUT"
