# -*- coding: utf-8 -*-
"""Bake Ch01-03 roles with procedural --pose on remeshed rigged.glb (fixes Meshy narrow gait)."""
import os, sys, subprocess, time, json
from PIL import Image

ROOT = r"C:\Users\Administrator\mecha-forge"
TOOLS = os.path.join(ROOT, "tools")
OUT = os.path.join(ROOT, "game", "assets", "enemies")
REFS = os.path.join(ROOT, "refs", "enemies_role_concepts")
NAMES = [
    "en01_tech_swarm", "en01_tech_shield", "en01_tech_sniper",
    "en02_desert_swarm", "en02_desert_shield", "en02_desert_sniper",
    "en03_jungle_swarm", "en03_jungle_shield", "en03_jungle_sniper",
]
DIRS = ["front", "back", "left", "right", "front_right", "front_left", "back_right", "back_left"]
# walk first (legs), then attack/die
ANIMS = [
    ("walk", 8, ["--pose", "walk"]),
    ("attack", 6, ["--pose", "attack"]),
    ("die", 5, ["--pose", "die", "--oneshot"]),
]
PY = r"C:\Python311\python.exe"
BAKE = os.path.join(TOOLS, "bake_enemy8.py")
LOGP = os.path.join(REFS, "_bake_pose_ch01_03.log")
RESP = os.path.join(REFS, "_bake_pose_results.json")

results = []; t_all = time.time()
open(LOGP, "w", encoding="utf-8").write("START %s\n" % time.strftime("%Y-%m-%d %H:%M:%S"))

def log(msg):
    print(msg, flush=True)
    open(LOGP, "a", encoding="utf-8").write(msg + "\n")

ok_n = fail_n = 0
total = len(NAMES) * len(ANIMS); done = 0
for name in NAMES:
    glb = os.path.join(ROOT, "meshy_in", name, "rigged.glb")
    for anim, frames, extra in ANIMS:
        done += 1
        dst_stem = os.path.join(OUT, "%s_%s.png" % (name, anim))
        entry = {"name": name, "anim": anim, "glb": glb}
        if not os.path.exists(glb):
            log("[%d/%d] MISSING %s" % (done, total, glb))
            entry.update(ok=False); results.append(entry); fail_n += 1; continue
        # force rebake: remove targets
        for d in DIRS:
            p = os.path.join(OUT, "%s_%s_%s.png" % (name, anim, d))
            if os.path.exists(p):
                try: os.remove(p)
                except Exception: pass
        log("[%d/%d] BAKE POSE %s_%s frames=%d" % (done, total, name, anim, frames))
        t0 = time.time()
        cmd = [PY, BAKE, glb, dst_stem, "--dirs", "8", "--frames", str(frames),
               "--res", "176", "--samples", "20", "--el", "40"] + extra
        try:
            r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=3600)
            secs = time.time() - t0
            present = sum(1 for d in DIRS if os.path.exists(os.path.join(OUT, "%s_%s_%s.png" % (name, anim, d))))
            ok = (r.returncode == 0 and present == 8)
            if ok:
                log("  OK %.0fs present=%d/8" % (secs, present)); ok_n += 1
            else:
                log("  FAIL rc=%s %.0fs present=%d/8 %s" % (r.returncode, secs, present, ((r.stderr or r.stdout) or "")[-300:]))
                fail_n += 1
            entry.update(ok=ok, secs=round(secs,1), present=present, rc=r.returncode)
        except Exception as e:
            log("  EXC %s" % e); entry.update(ok=False, err=str(e)); fail_n += 1
        results.append(entry)
        json.dump({"ok": ok_n, "fail": fail_n, "elapsed_s": round(time.time()-t_all,1), "items": results},
                  open(RESP, "w", encoding="utf-8"), indent=2)

# contact sheet walk front f0
try:
    cells = []
    for name in NAMES:
        p = os.path.join(OUT, "%s_walk_front.png" % name)
        if not os.path.exists(p): continue
        im = Image.open(p).convert("RGBA"); h = im.height
        cells.append(im.crop((0, 0, h, h)))
    if cells:
        pad, label_h = 8, 18
        cw = cells[0].width; ch = cells[0].height
        cols = 3; rows = (len(cells) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols*cw+(cols+1)*pad, rows*(ch+label_h)+(rows+1)*pad), (24,24,28,255))
        from PIL import ImageDraw, ImageFont
        dr = ImageDraw.Draw(sheet)
        for i, cell in enumerate(cells):
            r, c = divmod(i, cols)
            x = pad + c*(cw+pad); y = pad + r*(ch+label_h+pad)
            sheet.paste(cell, (x, y+label_h), cell)
            dr.text((x, y), NAMES[i].replace("en0",""), fill=(220,220,220,255))
        cp = os.path.join(REFS, "contact_bake_anim_ch01_03.png")
        sheet.save(cp); log("CONTACT %s" % cp)
except Exception as e:
    log("CONTACT fail %s" % e)

log("DONE ok=%d fail=%d elapsed=%.0fs" % (ok_n, fail_n, time.time()-t_all))
