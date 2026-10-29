# -*- coding: utf-8 -*-
import os, sys, subprocess, time, json
from PIL import Image
ROOT = r"C:\\Users\\Administrator\\mecha-forge"
TOOLS = os.path.join(ROOT, "tools")
OUT = os.path.join(ROOT, "game", "assets", "enemies")
TMP = os.path.join(ROOT, "refs", "enemies_role_concepts", "_bake_tmp")
os.makedirs(TMP, exist_ok=True)
os.makedirs(OUT, exist_ok=True)
NAMES = [
 "en01_tech_swarm","en01_tech_shield","en01_tech_sniper",
 "en02_desert_swarm","en02_desert_shield","en02_desert_sniper",
 "en03_jungle_swarm","en03_jungle_shield","en03_jungle_sniper",
]
# bake_meshy azimuth i*45 -> enemy dir suffix (same as bake_enemy8)
DIR_MAP = {
 0: "front", 1: "front_left", 2: "left", 3: "back_left",
 4: "back", 5: "back_right", 6: "right", 7: "front_right",
}
ANIMS = [("walk", 8), ("attack", 6), ("die", 5)]
RES = 176
SAMPLES = 24
logp = os.path.join(ROOT, "refs", "enemies_role_concepts", "_bake_ch01_03.log")
results = []

def log(msg):
    print(msg, flush=True)
    open(logp, "a", encoding="utf-8").write(msg + "\\n")

def strip_from(frame, n):
    w, h = frame.size
    sheet = Image.new("RGBA", (w * n, h), (0, 0, 0, 0))
    for i in range(n):
        sheet.paste(frame, (i * w, 0))
    return sheet

for ni, name in enumerate(NAMES, 1):
    glb = os.path.join(ROOT, "meshy_in", name, "model.glb")
    if not os.path.exists(glb):
        log("[%d/9] MISS %s" % (ni, glb)); results.append({"name": name, "ok": False, "err": "no glb"}); continue
    stem = os.path.join(TMP, name)
    # skip bake if all 8 already exist
    need = False
    for i in range(8):
        if not os.path.exists("%s_%d.png" % (stem, i)):
            need = True; break
    if need:
        log("[%d/9] BAKE %s" % (ni, name))
        t0 = time.time()
        cmd = [sys.executable, os.path.join(TOOLS, "bake_meshy.py"), glb, stem + ".png",
               "--dirs", "8", "--res", str(RES), "--samples", str(SAMPLES), "--el", "40"]
        r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        open(os.path.join(TMP, name + "_bake.out"), "w", encoding="utf-8").write(r.stdout + "\\n" + r.stderr)
        if r.returncode != 0:
            log("  FAIL bake rc=%s %s" % (r.returncode, (r.stderr or r.stdout)[-300:]))
            results.append({"name": name, "ok": False, "err": "bake"}); continue
        log("  bake done %.0fs" % (time.time() - t0))
    else:
        log("[%d/9] REUSE bake %s" % (ni, name))
    # assemble sheets
    ok_dirs = 0
    for i, dname in DIR_MAP.items():
        fp = "%s_%d.png" % (stem, i)
        if not os.path.exists(fp):
            log("  missing dir %d" % i); continue
        frame = Image.open(fp).convert("RGBA")
        for anim, nframes in ANIMS:
            dst = os.path.join(OUT, "%s_%s_%s.png" % (name, anim, dname))
            strip_from(frame, nframes).save(dst)
        ok_dirs += 1
    log("  wrote sheets dirs=%d -> %s_*" % (ok_dirs, name))
    results.append({"name": name, "ok": ok_dirs == 8, "dirs": ok_dirs})
    json.dump(results, open(os.path.join(ROOT, "refs", "enemies_role_concepts", "_bake_results.json"), "w"), indent=2)

log("DONE " + json.dumps(results))
