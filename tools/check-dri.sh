#!/bin/sh
echo "--- machine-id ---"
wc -c /etc/machine-id
cat -A /etc/machine-id | head -2
echo "--- dri holders ---"
for p in /proc/[0-9]*; do
  if ls -l $p/fd 2>/dev/null | grep -q '/dev/dri/card0'; then
    echo "$(basename $p) $(tr '\0' ' ' < $p/cmdline)"
  fi
done
echo "--- compositor procs ---"
pgrep -a weston
pgrep -a phoc
pgrep -a phosh
