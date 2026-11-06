import json
import urllib.parse
import urllib.request

PROJ = urllib.parse.quote("msm8996-mainline/linux", safe="")
BASE = "https://gitlab.com/api/v4/projects/" + PROJ


def api(path, timeout=90):
    try:
        r = urllib.request.urlopen(urllib.request.Request(BASE + path, headers={"User-Agent": "curl/8.0"}), timeout=timeout)
        return json.load(r)
    except Exception as e:
        return {"error": str(e)}


print("=== 1) 合并请求里含 td4722 / natrium / sharp 的 ===")
for state in ["opened", "merged", "closed"]:
    for page in range(1, 4):
        d = api("/merge_requests?state=%s&per_page=100&page=%d" % (state, page))
        if not isinstance(d, list) or not d:
            break
        for mr in d:
            text = ((mr.get("title") or "") + " " + (mr.get("description") or "")).lower()
            if "td4722" in text or "natrium" in text or "sharp" in text:
                print("  [%s] !%s %s" % (state, mr["iid"], mr.get("title")))
                print("       url: %s" % mr.get("web_url"))
                print("       source_branch: %s" % mr.get("source_branch"))
                desc = (mr.get("description") or "").strip().replace("\n", " ")[:200]
                if desc:
                    print("       desc: %s" % desc)
        if len(d) < 100:
            break

print()
print("=== 2) 直接搜索代码里的 td4722 ===")
for q in ["td4722", "sharp"]:
    d = api("/search?scope=blobs&search=%s&per_page=20" % urllib.parse.quote(q))
    if isinstance(d, list):
        print("  查询 '%s': %d 条" % (q, len(d)))
        for hit in d[:10]:
            print("    %s:%s  %s" % (hit.get("path"), hit.get("startline"), (hit.get("data") or "").strip()[:110]))
    else:
        print("  查询 '%s' 失败: %s" % (q, d))

print()
print("=== 3) 该项目的 fork（面板补丁可能在某个 fork 里）===")
d = api("/forks?per_page=50")
if isinstance(d, list):
    print("  fork 数: %d" % len(d))
    for f in d[:15]:
        print("   - %s (%s)" % (f.get("path_with_namespace"), f.get("web_url")))
else:
    print("  ", d)
