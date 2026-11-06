import configparser
import sys

c = configparser.ConfigParser()
c.read("/root/.config/pmbootstrap_v3.cfg")
if "pmbootstrap" not in c:
    print("  配置文件里没有 [pmbootstrap] 段")
    sys.exit(0)
v = c["pmbootstrap"].get("extra_packages", "")
print("  raw    : %r" % v)
print("  split  : %r" % [x for x in v.split(",")])
print("  空项数 : %d" % sum(1 for x in v.split(",") if x.strip() == ""))
