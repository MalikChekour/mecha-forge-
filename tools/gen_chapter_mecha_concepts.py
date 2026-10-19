"""Concepts FLUX (gratuit) des mecha des chapitres 1-9 a partir de meshy_in/<biome>_mecha/prompt.txt (les images fournies pour 1-9 sont des FICHES techniques, pas des rendus)."""
import os, sys
sys.path.insert(0, r"C:\Users\Administrator\workspace\pod")
from flux_gen import flux
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = ["tech", "desert", "jungle", "volcanic", "swamp", "cryo", "reacteur", "ruche", "citadelle"]
for i, b in enumerate(B, 1):
    p = open(os.path.join(ROOT, "meshy_in", b + "_mecha", "prompt.txt"), encoding="utf-8").read().strip()
    for v in (1, 2):
        dst = os.path.join(ROOT, "images_18_mechas", "concepts", "Ch%02d_%s_v%d.png" % (i, b, v))
        if os.path.exists(dst): continue
        print(i, b, v, "OK" if flux(p, dst, steps=8) else "ECHEC", flush=True)
