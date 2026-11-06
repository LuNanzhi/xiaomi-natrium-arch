import json
import urllib.parse
import urllib.request

PROJ = urllib.parse.quote("msm8996-mainline/linux", safe="")


def api(path, timeout=60):
    u = "https://gitlab.com/api/v4/projects/%s%s" % (PROJ, path)
    try:
        return json.load(urllib.request.urlopen(u, timeout=timeout))
    except Exception as e:
        return {"error": str(e)}


print("=== 项目信息 ===")
p = api("")
if "error" in p:
    print(" ", p["error"])
else:
    print("  默认分支:", p.get("default_branch"), "| 最后活动:", p.get("last_activity_at"))

print("\n=== 分支（前 40）===")
b = api("/repository/branches?per_page=100")
if isinstance(b, list):
    for x in b:
        print("  %-34s %s" % (x["name"], x["commit"]["committed_date"][:10]))
else:
    print("  ", b)

print("\n=== 标签（前 25）===")
t = api("/repository/tags?per_page=25")
if isinstance(t, list):
    for x in t:
        print("  %-30s %s" % (x["name"], x["commit"]["committed_date"][:10]))
else:
    print("  ", t)

print("\n=== README ===")
rd = api("/repository/files/README.md/raw?ref=msm8996-mainline/6.12")
if isinstance(rd, dict):
    print("  (6.12 分支 README 取不到:", rd.get("error"), ")")
else:
    print(rd[:1500] if isinstance(rd, str) else rd)
