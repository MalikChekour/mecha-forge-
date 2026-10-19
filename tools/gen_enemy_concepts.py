"""Concepts 2D (FLUX gratuit, Cloudflare) des 3 ennemis de base avant tout appel Meshy payant. Aucun credit Meshy depense."""
import os, sys
sys.path.insert(0, r"C:\Users\Administrator\workspace\pod")
from flux_gen import flux
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "refs", "enemies_meshy")
os.makedirs(OUT, exist_ok=True)
BASE = ("single hostile sci-fi robot enemy for a top-down survivor game, full body, three-quarter front view, centered, isolated on a plain flat "
        "dark grey background, no text, no logo, hard-surface design, matte black and bone-white armor plates with glowing red optics, "
        "game concept art, 3D render, studio lighting, T-pose-free natural stance. ")
SPEC = {
 "rodeur": ["RODEUR: fast melee rusher. Lean predatory biped, digitigrale legs, low forward-leaning crouch, long blade-like claws on both forearms, "
            "slim insectoid head with two red eyes, light armor, small size, no ranged weapon, no big guns.",
            "RODEUR: small aggressive spider-legged melee robot, quadruped crawler on four thin legs with razor claws, flat head, red glowing eyes, no gun."],
 "guepe": ["GUEPE: small hovering wasp drone. Compact oval armored body, two translucent wing-like hover fins, ventral stinger cannon pointing forward, "
           "glowing red sensor, tiny, flying, no legs, keeps distance and shoots.",
           "GUEPE: hover drone shaped like a wasp, segmented abdomen with a stinger barrel, four small rotor jets, red core eye, no legs."],
 "belier": ["BELIER: heavy charging ram robot. Stocky quadruped shell, thick armored dome back, massive ram head with a reinforced battering horn, "
            "short strong legs, glowing red cores in the chest, built to charge in a straight line.",
            "BELIER: armored beetle-like battering ram mech on four legs, thick plated carapace, big forward ram horn, red glowing vents."],
}
for name, variants in SPEC.items():
    for i, v in enumerate(variants):
        dst = os.path.join(OUT, "%s_v%d.png" % (name, i + 1))
        if os.path.exists(dst): continue
        print(name, i + 1, "OK" if flux(BASE + v, dst, steps=8) else "ECHEC", flush=True)
