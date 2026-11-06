#!/bin/sh
echo "=== fresh login shell: pacman without any manual proxy setup ==="
sh -lc 'echo "http_proxy=$http_proxy"; pacman -Sy 2>&1 | tail -3'
