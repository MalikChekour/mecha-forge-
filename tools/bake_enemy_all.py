#!/usr/bin/env python3
"""Cuit les sprites d'UN ennemi (8 directions x walk/attack/die) depuis meshy_in/<name>/anim_*.glb vers game/assets/enemies/<chassis>_<anim>_<dir>.png
Usage : python tools/bake_enemy_all.py <name> <chassis> [--res 176]
Budget poids : walk 6 images, attack 6, die 5 (un seul passage, sans boucle)."""
import subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
name, chassis = sys.argv[1], sys.argv[2]
res = sys.argv[sys.argv.index("--res") + 1] if "--res" in sys.argv else "176"
out = os.path.join(ROOT, "game", "assets", "enemies")
for anim, frames, extra in (("walk", 6, ["--pose", "walk"]), ("attack", 6, ["--pose", "attack"]), ("die", 5, ["--pose", "die", "--oneshot"])):
    # attaque = pose procedurale des BRAS sur le rig (rigged.glb) ; walk/die = animations Meshy
    glb = os.path.join(ROOT, "meshy_in", name, "rigged.glb")
    if not os.path.exists(glb):
        print("MANQUE", glb); continue
    dst = os.path.join(out, "%s_%s.png" % (chassis, anim))
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "bake_enemy8.py"), glb, dst, "--frames", str(frames), "--res", res,
                    "--dirs", "8", "--samples", "20"] + extra, cwd=ROOT, check=True)
print("OK", chassis)
