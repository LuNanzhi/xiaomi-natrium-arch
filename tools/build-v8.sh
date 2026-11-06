#!/usr/bin/env bash
# v8: USB serial (CDC-ACM) console + getty, so we always have a way in.
#   - gadget exposes RNDIS + ACM (ttyGS0)
#   - serial-getty@ttyGS0 enabled -> login prompt over the USB COM port
#   - console debug dump loops every 20 s so it stays on screen
set -uo pipefail
ROOT=/root/arch/root
AF=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/arch-files
TOOLS=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/tools

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "== 1) gadget script with ACM =="
install -m 755 "$AF/natrium-usb-gadget" "$ROOT/usr/local/sbin/natrium-usb-gadget"
grep -n "acm.GS0" "$ROOT/usr/local/sbin/natrium-usb-gadget" | head -3

say "== 2) getty on ttyGS0 =="
mkdir -p "$ROOT/etc/systemd/system/getty.target.wants"
ln -sf /usr/lib/systemd/system/serial-getty@.service \
       "$ROOT/etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service"
ls -l "$ROOT/etc/systemd/system/getty.target.wants/"

say "== 3) looping debug dump =="
cat > "$ROOT/usr/local/sbin/natrium-debug" <<'EOF'
#!/bin/sh
# keep the diagnostics on screen: systemd/kernel messages would otherwise scroll it away
while true; do
  {
    printf '\033[2J\033[H'
    echo "========== NATRIUM DEBUG $(date) =========="
    ip -brief addr 2>&1
    echo "--- active/failed ---"
    systemctl --failed --no-pager --no-legend 2>&1
    for u in sshd iwd systemd-networkd natrium-usb-gadget; do
        printf '%-22s %s\n' "$u" "$(systemctl is-active $u 2>&1)"
    done
    echo "--- udc ---"; ls /sys/class/udc 2>&1
    echo "--- sshd log ---"; journalctl -b -u sshd --no-pager -n 8 2>&1
    echo "--- iwd log ---"; journalctl -b -u iwd --no-pager -n 8 2>&1
    echo "========== END =========="
  } > /dev/tty0 2>&1
  sleep 20
done
EOF
chmod 755 "$ROOT/usr/local/sbin/natrium-debug"
cat > "$ROOT/etc/systemd/system/natrium-debug.service" <<'EOF'
[Unit]
Description=Keep diagnostics on the console
After=multi-user.target
[Service]
Type=simple
ExecStart=/usr/local/sbin/natrium-debug
Restart=always
[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/natrium-debug.service "$ROOT/etc/systemd/system/multi-user.target.wants/natrium-debug.service"

say "== 4) regenerate image =="
rm -f /root/arch/arch-natrium-v8.img
bash "$TOOLS/build-arch-image.sh" "$ROOT" /root/arch/arch-natrium-v8.img 3G 2>&1 | tail -6
mv -f /mnt/c/Users/Public/natrium/arch/arch-natrium.img /mnt/c/Users/Public/natrium/arch/arch-natrium-v8.img
e2fsck -fn /root/arch/arch-natrium-v8.img >/tmp/v8fsck.log 2>&1 && echo "fsck: clean" || { echo "fsck:"; tail -3 /tmp/v8fsck.log; }
ls -l /mnt/c/Users/Public/natrium/arch/arch-natrium-v8.img
say "ready"
