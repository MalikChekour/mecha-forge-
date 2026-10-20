"""4 alternatives FLUX (gratuit) pour le mecha du chapitre 4 (Volcanique) : solo, fond uni, aucun texte/annotation, bras libres."""
import os, sys
sys.path.insert(0, r"C:\Users\Administrator\workspace\pod")
from flux_gen import flux
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "images_18_mechas", "alt_ch04")
os.makedirs(OUT, exist_ok=True)
BASE = ("single bipedal combat mecha, full body front three-quarter view, centered, standing on plain flat light grey studio floor, plain solid light grey "
        "background, no text, no annotations, no labels, symmetrical A-pose, both arms visible and separated from the torso, charcoal black and dark red "
        "heat-scorched armor with glowing orange magma vents, hard-surface Gundam-like design, clean 3D render, studio lighting. ")
V = ["Volcanic foundry mecha: right arm is a huge molten-slag cannon, left arm a heavy forge-hammer fist, broad shoulder armor with smoke stacks, thick armored legs.",
     "Volcanic magma-lancer mecha: right arm integrated lava flamethrower nozzle, left arm a clamp hand, tall lean build, glowing orange chest core, heat-shield plates.",
     "Volcanic brute mecha: both forearms are twin glowing plasma cannons built into the arms, wide chest with orange vent grilles, backpack with two exhaust chimneys.",
     "Volcanic siege mecha: right arm a long magma-mortar launcher, left arm a shield-bracer with cooling fins, rounded helmet with a single orange lens, sturdy reverse-knee legs."]
for i, v in enumerate(V, 1):
    dst = os.path.join(OUT, "Ch04_alt%d.png" % i)
    if not os.path.exists(dst):
        print(i, "OK" if flux(BASE + v, dst, steps=8) else "ECHEC", flush=True)
