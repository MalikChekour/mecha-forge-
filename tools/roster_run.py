#!/usr/bin/env python3
"""
mecha-forge — roster orchestrator. Per asset in roster.json, runs the proven
Meshy pipeline end-to-end and bakes game-ready sprites. Resumable (skips steps
whose outputs already exist).

  concept (FLUX)  ->  image-to-3D (low-poly textured)  ->
    if humanoid: rig + Meshy animations -> bake_anim.py spritesheets
    else:        bake_meshy.py static sprite (procedural motion added in-engine)

Requires MESHY_KEY in env.
  python roster_run.py --only titan,drone,crawler
  python roster_run.py                 # whole roster
"""
import json, os, sys, subprocess, hashlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
PY = sys.executable
roster = json.load(open(os.path.join(TOOLS, "roster.json")))

only = None
if "--only" in sys.argv:
    only = set(sys.argv[sys.argv.index("--only") + 1].split(","))

DEST = {"mecha": os.path.join(ROOT, "game", "assets", "mecha"),
        "enemies": os.path.join(ROOT, "game", "assets", "enemies"),
        "decor": os.path.join(ROOT, "game", "assets", "decor")}
for d in DEST.values():
    os.makedirs(d, exist_ok=True)


def run(cmd, label):
    print("  $ %s" % label, flush=True)
    r = subprocess.run(cmd, cwd=ROOT)
    if r.returncode != 0:
        raise RuntimeError("step failed: %s" % label)


def seed_for(name):
    return str(int(hashlib.md5(name.encode()).hexdigest(), 16) % 100000)


summary = []
for asset in roster["assets"]:
    name = asset.get("name")
    if not name or name.startswith("_"):
        continue
    if only and name not in only:
        continue
    print("\n=== %s (%s) ===" % (name, asset.get("group")), flush=True)
    outdir = os.path.join(ROOT, "meshy_in", name)
    os.makedirs(outdir, exist_ok=True)
    concept = os.path.join(outdir, "concept.png")
    model = os.path.join(outdir, "model.glb")
    meta = os.path.join(outdir, "meta.json")
    dest = DEST.get(asset.get("group"), DEST["enemies"])
    try:
        # 1. concept
        if not os.path.exists(concept):
            run([PY, os.path.join(TOOLS, "flux_concept.py"), asset["prompt"], concept, seed_for(name)],
                "flux concept")
        # 2. image -> 3D (low-poly textured)
        if not (os.path.exists(model) and os.path.getsize(model) > 1000):
            run([PY, os.path.join(TOOLS, "meshy_client.py"), "image", concept, "--name", name],
                "image-to-3D")
        mid = json.load(open(meta))["id"]
        # 3. rig + animations (humanoid) OR static
        if asset.get("rig"):
            labels = asset.get("anims", ["walk"])
            last = os.path.join(outdir, "anim_%s.glb" % labels[-1])
            if not os.path.exists(last):
                run([PY, os.path.join(TOOLS, "meshy_client.py"), "riganim", mid,
                     "--name", name, "--label", ",".join(labels)], "rig + anims")
            # 4a. bake each animation to a spritesheet
            made = []
            for lab in labels:
                g = os.path.join(outdir, "anim_%s.glb" % lab)
                if os.path.exists(g):
                    out = os.path.join(dest, "%s_%s.png" % (name, lab))
                    run([PY, os.path.join(TOOLS, "bake_anim.py"), g, out,
                         "--frames", "8", "--res", "256", "--el", "38", "--samples", "22"],
                        "bake %s" % lab)
                    made.append("%s_%s" % (name, lab))
            summary.append("%s: rigged, anims=%s" % (name, made))
        else:
            # 4b. static sprite (procedural motion in-engine)
            out = os.path.join(dest, "%s.png" % name)
            run([PY, os.path.join(TOOLS, "bake_meshy.py"), model, out,
                 "--res", str(asset.get("size", 256)), "--el", "40", "--samples", "28"],
                "bake static")
            summary.append("%s: static (proc=%s)" % (name, asset.get("proc")))
    except Exception as e:
        print("  !! %s FAILED: %s" % (name, e), flush=True)
        summary.append("%s: FAILED (%s)" % (name, e))

print("\n===== ROSTER SUMMARY =====")
for s in summary:
    print(" ", s)
