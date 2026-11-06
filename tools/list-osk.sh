#!/bin/sh
for p in matchbox-keyboard florence svkbd onboard cellwriter xvkbd; do
    printf '%-20s ' "$p"
    pacman -Ss "^$p\$" 2>/dev/null | head -1 || true
    echo
done
