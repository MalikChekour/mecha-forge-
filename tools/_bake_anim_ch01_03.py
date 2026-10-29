# -*- coding: utf-8 -*-
"""Re-bake animated 8-dir sprites for Ch01-03 roles from Meshy anim_*.glb."""
import os, sys, subprocess, time, json
from PIL import Image

ROOT = r"C:\Users\Administrator\mecha-forge"
TOOLS = os.path.join(ROOT, "tools")
OUT = os.path.join(ROOT, "game", "assets", "enemies")
REFS = os.path.join(ROOT, "refs", "enemies_role_concepts")
os.makedirs(OUT, exist_ok=True)
os.makedirs(REFS, exist_ok=True)

NAMES = [
    "en01_tech_swarm", "en01_tech_shield", "en01_tech_sniper",
    "en02_desert_swarm", "en02_desert_shield", "en02_desert_sniper",
    "en03_jungle_swarm", "en03_jungle_shield", "en03_jungle_sniper",
]
DIRS = ["front", "back", "left", "right", "front_right", "front_left", "back_right", "back_left"]
ANIMS = [
    ("walk", 8, []),
    ("attack", 6, []),
    ("die", 5, ["--oneshot"]),
]
PY = r"C:\Python311\python.exe"
BAKE = os.path.join(TOOLS, "bake_enemy8.py")
LOGP = os.path.join(REFS, "_bake_anim_ch01_03.log")
RESP = os.path.join(REFS, "_bake_anim_results.json")

results = []
t_all = time.time()

def log(msg):
    line = msg
    print(line, flush=True)
    with open(LOGP, "a", encoding="utf-8") as f:
        f.write(line + "\n")

# fresh log
open(LOGP, "w", encoding="utf-8").write("START %s\n" % time.strftime("%Y-%m-%d %H:%M:%S"))

def targets_ok(name, anim, glb):
    glb_m = os.path.getmtime(glb)
    for d in DIRS:
        p = os.path.join(OUT, "%s_%s_%s.png" % (name, anim, d))
        if not os.path.exists(p):
            return False
        if os.path.getmtime(p) < glb_m:
            return False
    return True

total = len(NAMES) * len(ANIMS)
done = 0
ok_n = 0
fail_n = 0
skip_n = 0

for ni, name in enumerate(NAMES, 1):
    for anim, frames, extra in ANIMS:
        done += 1
        glb = os.path.join(ROOT, "meshy_in", name, "anim_%s.glb" % anim)
        dst_stem = os.path.join(OUT, "%s_%s.png" % (name, anim))
        entry = {"name": name, "anim": anim, "frames": frames, "glb": glb}

        if not os.path.exists(glb):
            log("[%d/%d] MISSING %s" % (done, total, glb))
            entry.update(ok=False, err="missing_glb", skipped=False)
            results.append(entry); fail_n += 1
            json.dump(results, open(RESP, "w", encoding="utf-8"), indent=2)
            continue

        if targets_ok(name, anim, glb):
            log("[%d/%d] SKIP %s_%s (8 png newer than glb)" % (done, total, name, anim))
            entry.update(ok=True, skipped=True, secs=0)
            results.append(entry); skip_n += 1; ok_n += 1
            json.dump(results, open(RESP, "w", encoding="utf-8"), indent=2)
            continue

        log("[%d/%d] BAKE %s_%s frames=%d" % (done, total, name, anim, frames))
        t0 = time.time()
        cmd = [PY, BAKE, glb, dst_stem, "--dirs", "8", "--frames", str(frames),
               "--res", "176", "--samples", "24", "--el", "40"] + extra
        try:
            r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=3600)
            secs = time.time() - t0
            outlog = os.path.join(REFS, "_bake_%s_%s.out" % (name, anim))
            with open(outlog, "w", encoding="utf-8") as f:
                f.write((r.stdout or "") + "\n---STDERR---\n" + (r.stderr or ""))
            present = sum(1 for d in DIRS if os.path.exists(os.path.join(OUT, "%s_%s_%s.png" % (name, anim, d))))
            ok = (r.returncode == 0 and present == 8)
            if ok:
                log("  OK %.0fs present=%d/8" % (secs, present))
                ok_n += 1
            else:
                tail = ((r.stderr or r.stdout) or "")[-400:]
                log("  FAIL rc=%s %.0fs present=%d/8 %s" % (r.returncode, secs, present, tail))
                fail_n += 1
            entry.update(ok=ok, skipped=False, secs=round(secs, 1), present=present, rc=r.returncode)
        except Exception as e:
            secs = time.time() - t0
            log("  EXC %.0fs %s" % (secs, e))
            entry.update(ok=False, skipped=False, secs=round(secs, 1), err=str(e))
            fail_n += 1
        results.append(entry)
        json.dump({"ok": ok_n, "fail": fail_n, "skip": skip_n, "elapsed_s": round(time.time()-t_all,1), "items": results},
                  open(RESP, "w", encoding="utf-8"), indent=2)

# contact sheet: walk front frame0 for 9 names
try:
    cells = []
    for name in NAMES:
        p = os.path.join(OUT, "%s_walk_front.png" % name)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        # first frame = left tile
        h = im.height
        cells.append((name, im.crop((0, 0, h, h))))
    if cells:
        pad = 8
        label_h = 18
        cw = cells[0][1].width
        ch = cells[0][1].height
        cols = 3
        rows = (len(cells) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * (cw + pad) + pad, rows * (ch + label_h + pad) + pad), (20, 22, 28, 255))
        # simple labels via tiny fill bar (no font dependency required)
        for i, (name, cell) in enumerate(cells):
            r, c = divmod(i, cols)
            x = pad + c * (cw + pad)
            y = pad + r * (ch + label_h + pad)
            sheet.paste(cell, (x, y), cell)
        contact = os.path.join(REFS, "contact_bake_anim_ch01_03.png")
        sheet.save(contact)
        log("CONTACT %s (%d cells)" % (contact, len(cells)))
except Exception as e:
    log("CONTACT fail: %s" % e)

elapsed = time.time() - t_all
summary = {"ok": ok_n, "fail": fail_n, "skip": skip_n, "elapsed_s": round(elapsed, 1), "items": results}
json.dump(summary, open(RESP, "w", encoding="utf-8"), indent=2)
log("DONE ok=%d fail=%d skip=%d elapsed=%.0fs" % (ok_n, fail_n, skip_n, elapsed))
print(json.dumps(summary, indent=2))
