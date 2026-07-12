#!/usr/bin/env python3
import os, sys, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
IN_DIR = os.path.join(ROOT, "meshy_in", "mecha_joueur")
OUT_DIR = os.path.join(ROOT, "game", "assets", "mecha")

anims = [
    ("anim_idle.glb", "mecha_joueur_idle.png"),
    ("anim_walk.glb", "mecha_joueur_walk.png"),
    ("anim_run.glb",  "mecha_joueur_run.png"),
    ("anim_attack.glb", "mecha_joueur_attack.png"),
    ("anim_hit.glb",  "mecha_joueur_hit.png"),
    ("anim_die.glb",  "mecha_joueur_die.png"),
]

for glb_name, out_name in anims:
    glb_path = os.path.join(IN_DIR, glb_name)
    out_path = os.path.join(OUT_DIR, out_name)
    if not os.path.exists(glb_path):
        print(f"SKIP {glb_name} (not found)")
        continue
    print(f"=== BAKING 4 DIRS FOR {out_name} ===", flush=True)
    subprocess.run([
        sys.executable,
        os.path.join(TOOLS, "bake_anim.py"),
        glb_path,
        out_path,
        "--dirs", "4",
        "--frames", "8",
        "--res", "256",
        "--samples", "16"
    ], check=True)

print("ALL MECHA_JOUEUR 4-DIR ANIMATIONS BAKED SUCCESSFULLY.")
