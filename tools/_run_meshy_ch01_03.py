import os, sys, time, json
sys.path.insert(0, r"C:\Users\Administrator\mecha-forge\tools")
from meshy_client import gen_image
ROOT = r"C:\Users\Administrator\mecha-forge"
SRC = os.path.join(ROOT, "refs", "enemies_role_concepts")
names = ["en01_tech_swarm","en01_tech_shield","en01_tech_sniper","en02_desert_swarm","en02_desert_shield","en02_desert_sniper","en03_jungle_swarm","en03_jungle_shield","en03_jungle_sniper"]
results = []
for i, name in enumerate(names, 1):
    img = os.path.join(SRC, name + ".png")
    print("[%d/%d] MESHY %s" % (i, len(names), name), flush=True)
    t0 = time.time()
    try:
        out = gen_image(img, name, pbr=True)
        rec = {"name": name, "ok": True, "out": out, "sec": round(time.time()-t0,1)}
        print("  OK", out, flush=True)
    except Exception as e:
        rec = {"name": name, "ok": False, "err": str(e)[:400], "sec": round(time.time()-t0,1)}
        print("  FAIL", e, flush=True)
    results.append(rec)
    open(os.path.join(SRC, "_meshy_results.json"), "w", encoding="utf-8").write(json.dumps(results, indent=2))
print("DONE", results, flush=True)
