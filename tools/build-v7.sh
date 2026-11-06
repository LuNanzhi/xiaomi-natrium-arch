#!/usr/bin/env bash
# v7: deterministic network for the phone + bulletproof sshd + better diagnostics.
#
#   - static 10.10.10.222/24 on wlp1s0 via systemd-networkd (no DHCP race)
#   - SSH host keys pre-generated in the image (no first-boot dependency)
#   - sshd drop-in: RuntimeDirectory=sshd
#   - two console dumps (40 s and 120 s) with ip addr / failed units / per-unit status
set -uo pipefail
ROOT=/root/arch/root
AF=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/arch-files
TOOLS=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/tools

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "== 1) static IP on wlp1s0 (networkd), drop dhcpcd =="
rm -f "$ROOT/etc/systemd/system/multi-user.target.wants/dhcpcd@wlp1s0.service"
cat > "$ROOT/etc/systemd/network/30-wlp1s0.network" <<'EOF'
[Match]
Name=wlp1s0

[Network]
Address=10.10.10.222/24
Gateway=10.10.10.254
DNS=223.5.5.5
EOF
ln -sf /usr/lib/systemd/system/systemd-networkd.service "$ROOT/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"

say "== 2) SSH host keys, generated now =="
rm -f "$ROOT"/etc/ssh/ssh_host_*
ssh-keygen -q -t ed25519 -N '' -f "$ROOT/etc/ssh/ssh_host_ed25519_key"
ssh-keygen -q -t rsa -b 3072 -N '' -f "$ROOT/etc/ssh/ssh_host_rsa_key"
ssh-keygen -q -t ecdsa -N '' -f "$ROOT/etc/ssh/ssh_host_ecdsa_key"
chmod 600 "$ROOT"/etc/ssh/ssh_host_*_key
chmod 644 "$ROOT"/etc/ssh/ssh_host_*_key.pub
ls -l "$ROOT"/etc/ssh/ssh_host_*_key | wc -l

say "== 3) sshd drop-in =="
cat > "$ROOT/etc/systemd/system/sshd.service.d/runtime-dir.conf" 2>/dev/null || mkdir -p "$ROOT/etc/systemd/system/sshd.service.d"
cat > "$ROOT/etc/systemd/system/sshd.service.d/runtime-dir.conf" <<'EOF'
[Service]
RuntimeDirectory=sshd
RuntimeDirectoryMode=0755
EOF
cat "$ROOT/etc/systemd/system/sshd.service.d/runtime-dir.conf"

say "== 4) better console diagnostics =="
cat > "$ROOT/usr/local/sbin/natrium-debug" <<'EOF'
#!/bin/sh
{
  printf '\033[2J\033[H'
  echo "=================================================="
  echo " NATRIUM DEBUG $(date)"
  echo "=================================================="
  echo "--- ip addr ---"
  ip -brief addr 2>&1
  echo "--- failed units ---"
  systemctl --failed --no-pager --no-legend 2>&1
  echo "--- sshd / iwd / networkd / gadget ---"
  for u in sshd iwd systemd-networkd natrium-usb-gadget; do
      printf '%-22s %s\n' "$u" "$(systemctl is-active $u 2>&1)/$(systemctl is-enabled $u 2>&1)"
  done
  echo "--- sshd log ---"
  journalctl -b -u sshd --no-pager -n 15 2>&1
  echo "--- iwd log ---"
  journalctl -b -u iwd --no-pager -n 15 2>&1
  echo "--- networkd log ---"
  journalctl -b -u systemd-networkd --no-pager -n 15 2>&1
  echo "--- wpa/iwd state ---"
  ls -l /var/lib/iwd 2>&1
  echo "=================================================="
  echo " END DEBUG"
  echo "=================================================="
} > /dev/tty0 2>&1
EOF
chmod 755 "$ROOT/usr/local/sbin/natrium-debug"

cat > "$ROOT/etc/systemd/system/natrium-debug.service" <<'EOF'
[Unit]
Description=Dump diagnostics to the console
After=multi-user.target
[Service]
Type=oneshot
ExecStartPre=/bin/sleep 40
ExecStart=/usr/local/sbin/natrium-debug
[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/natrium-debug.service "$ROOT/etc/systemd/system/multi-user.target.wants/natrium-debug.service"

say "== 5) regenerate image =="
rm -f /root/arch/arch-natrium-v7.img
bash "$TOOLS/build-arch-image.sh" "$ROOT" /root/arch/arch-natrium-v7.img 3G 2>&1 | tail -6
mv -f /mnt/c/Users/Public/natrium/arch/arch-natrium.img /mnt/c/Users/Public/natrium/arch/arch-natrium-v7.img
e2fsck -fn /root/arch/arch-natrium-v7.img >/tmp/v7fsck.log 2>&1 && echo "fsck: clean" || { echo "fsck:"; tail -3 /tmp/v7fsck.log; }
ls -l /mnt/c/Users/Public/natrium/arch/arch-natrium-v7.img
say "ready"
