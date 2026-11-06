#!/bin/sh
# Repair /etc/machine-id (must be 32 hex chars + newline) and restart dbus.
newid=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
printf '%s\n' "$newid" > /etc/machine-id
mkdir -p /var/lib/dbus
printf '%s\n' "$newid" > /var/lib/dbus/machine-id
echo "machine-id: $(cat /etc/machine-id)"
wc -c /etc/machine-id
systemctl restart dbus
sleep 2
echo "dbus: $(systemctl is-active dbus)"
