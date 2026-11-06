#!/usr/bin/env python3
"""Benchmark real download throughput from the mirrors (large-file test)."""
import io
import os
import subprocess
import sys
import tarfile
import time
import urllib.request

MIRRORS = [
    ("南京大学 pmOS", "http://mirror.nju.edu.cn/postmarketos/main/aarch64"),
    ("清华 Alpine", "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/aarch64"),
    ("官方 pmOS", "http://mirror.postmarketos.org/postmarketos/main/aarch64"),
    ("哈雷 RWTH", "https://ftp.halifax.rwth-aachen.de/postmarketos/main/aarch64"),
]

TMP = "/tmp/bench_idx"
os.makedirs(TMP, exist_ok=True)


def fetch(url, timeout=90):
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0"})
    return urllib.request.urlopen(req, timeout=timeout).read()


def largest_pkg(base):
    idx = base + "/APKINDEX.tar.gz"
    data = fetch(idx)
    tf = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")
    txt = tf.extractfile("APKINDEX").read().decode("utf-8", "replace")
    pkg, best = "", ("", 0)
    for line in txt.splitlines():
        if line.startswith("P:"):
            pkg = line[2:]
        elif line.startswith("S:") and pkg:
            try:
                s = int(line[2:])
            except ValueError:
                s = 0
            if s > best[1]:
                best = (pkg, s)
    return best


def bench(url, mb=30, timeout=60):
    """Download up to `mb` megabytes and report MB/s."""
    limit = mb * 1024 * 1024
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0", "Range": "bytes=0-%d" % (limit - 1)})
    t0 = time.time()
    got = 0
    try:
        r = urllib.request.urlopen(req, timeout=timeout)
        while True:
            chunk = r.read(262144)
            if not chunk:
                break
            got += len(chunk)
            if got >= limit or time.time() - t0 > timeout:
                break
    except Exception as e:
        return None, str(e)
    dt = max(time.time() - t0, 0.001)
    return got / dt, "%.1f MB in %.1fs" % (got / 1048576, dt)


print("=== 各源最大的包 + 30MB 实测吞吐 ===")
for name, base in MIRRORS:
    try:
        pkg, size = largest_pkg(base)
    except Exception as e:
        print("  %-14s 索引获取失败: %s" % (name, e))
        continue
    if not pkg:
        print("  %-14s 索引里没解析出包" % name)
        continue
    url = "%s/%s" % (base, pkg)
    speed, info = bench(url)
    if speed is None:
        print("  %-14s %-28s 下载失败: %s" % (name, pkg, info))
    else:
        print("  %-14s %-28s %6.2f MB/s   (%s, 包大小 %d MB)" % (name, pkg, speed / 1048576, info, size // 1048576))

print()
print("判读: >=1 MB/s 不用代理；0.3~1 可接受；<0.3 建议挂代理换国外源")
