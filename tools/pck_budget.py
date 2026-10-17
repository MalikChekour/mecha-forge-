"""Budget du pack Web : taille IMPORTEE (.godot/imported) par dossier d'assets. Usage : python tools/pck_budget.py"""
import glob, os, re, collections
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game"))
sizes = collections.defaultdict(int); cnt = collections.defaultdict(int)
for imp in glob.glob("**/*.import", recursive=True):
    if imp.startswith((".godot", "android", "build")):
        continue
    t = open(imp, encoding="utf-8", errors="ignore").read()
    m = re.search(r'^path="res://([^"]+)"', t, re.M)
    if not m or not os.path.exists(m.group(1)):
        continue
    src = imp[:-7].replace(os.sep, "/")
    parts = src.split("/")
    k = "/".join(parts[:2]) if parts[0] == "assets" else parts[0]
    if parts[:2] == ["assets", "mecha"] or parts[:2] == ["assets", "enemies"]:
        k = "/".join(parts[:2]) + "/" + re.split(r"_(idle|walk|run|attack|hit|die|melee)", parts[-1])[0]
    sizes[k] += os.path.getsize(m.group(1)); cnt[k] += 1
print("%.1f MB importes" % (sum(sizes.values()) / 1048576))
for k, v in sorted(sizes.items(), key=lambda x: -x[1])[:30]:
    print("%7.1f MB %4d  %s" % (v / 1048576, cnt[k], k))
