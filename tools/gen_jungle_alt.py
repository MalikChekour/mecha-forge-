"""4 alternatives FLUX (gratuit) pour le mecha du chapitre 3 (Jungle) : solo, fond uni, AUCUN socle/plante, pas de scie, bras libres."""
import os, sys
sys.path.insert(0, r"C:\Users\Administrator\workspace\pod")
from flux_gen import flux
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "images_18_mechas", "alt_ch03")
os.makedirs(OUT, exist_ok=True)
BASE = ("single bipedal combat mecha, full body front three-quarter view, centered, standing on plain flat light grey studio floor with NO ground props, "
        "NO plants, NO base, plain solid light grey background, no text, symmetrical A-pose, both arms visible and separated from the torso, "
        "military olive-drab and dark green armor with moss-stained panels, hard-surface Gundam-like design, clean 3D render, studio lighting. ")
V = ["Heavy jungle assault mecha: right arm is a large rotary autocannon, left arm a heavy gripping claw, broad shoulder armor, thick armored legs, small angular head with a visor slit.",
     "Jungle sniper mecha: right arm carries a very long integrated railgun barrel, left arm a clamp hand, lean tall build, vine-camouflage paint, forward-swept antenna.",
     "Jungle brawler mecha: both forearms are twin short cannons built into the arms, wide chest with ventilation grilles, digitigrade armored legs, backpack with two exhaust stacks.",
     "Jungle support mecha: right arm a flamethrower nozzle, left arm a shield-bracer, rounded helmet with a single lens, armored skirt, sturdy reverse-knee legs."]
for i, v in enumerate(V, 1):
    dst = os.path.join(OUT, "Ch03_alt%d.png" % i)
    if not os.path.exists(dst):
        print(i, "OK" if flux(BASE + v, dst, steps=8) else "ECHEC", flush=True)
