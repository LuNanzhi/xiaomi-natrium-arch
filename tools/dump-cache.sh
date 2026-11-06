#!/system/bin/sh
# Runs ON THE PHONE (pushed to /data/local/tmp). Dumps the cache partition for offline parsing.
echo "=== id ==="
id
echo "=== is cache mounted? ==="
cat /proc/mounts | grep -i cache
echo "=== block device ==="
ls -l /dev/block/by-name/cache
echo "=== size (blocks of 1M) ==="
dd if=/dev/block/by-name/cache of=/dev/null bs=1M 2>&1 | tail -2
echo "=== dump to /data/local/tmp/cache.img ==="
rm -f /data/local/tmp/cache.img
dd if=/dev/block/by-name/cache of=/data/local/tmp/cache.img bs=1M
chmod 644 /data/local/tmp/cache.img
ls -l /data/local/tmp/cache.img
echo "=== search 'natrium' text directly in the raw partition ==="
strings -a /dev/block/by-name/cache 2>/dev/null | grep -m 10 natrium
echo "=== search log markers ==="
strings -a /dev/block/by-name/cache 2>/dev/null | grep -m 5 -E "===== natrium|CACHE=|dmesg"
echo "=== done ==="
