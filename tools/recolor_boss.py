# -*- coding: utf-8 -*-
"""Recolor du mini-boss a ogives en schema BOSS distinct : armure CRIMSON (au lieu du
gunmetal des ennemis normaux) + accent orange (ogives) + yeux rouges. -> game assets + montage."""
import sys, os, numpy as np
sys.path.insert(0, os.path.abspath("tools"))
from biome_paint3 import recolor
from PIL import Image

# NOIR + OR : armure métal NOIR sombre (multi-ton, pas d'aplat) + accent OR = boss élite
CRIMSON = [(0, (10, 10, 13)), (.38, (34, 36, 42)), (.65, (82, 86, 96)), (.86, (152, 158, 170)), (1, (216, 222, 234))]
ACC = (255, 188, 55); GL = 1.05   # ogives / énergie = or
CHASSIS = "ogreboss"

mont = Image.new("RGB", (256 * 4, 256), (24, 26, 32))
for i, d in enumerate(["front", "back", "left", "right"]):
    sh = np.array(Image.open(f"cine/_show/boss/raw_{d}.png").convert("RGBA"))
    fw = sh.shape[1] // 8
    out = Image.new("RGBA", (sh.shape[1], sh.shape[0]), (0, 0, 0, 0))
    for k in range(8):
        cell = recolor(sh[:, k * fw:(k + 1) * fw], CRIMSON, (0, 0, 0), ACC, GL)
        out.paste(Image.fromarray(cell, "RGBA"), (k * fw, 0))
    out.save(f"game/assets/enemies/{CHASSIS}_walk_{d}.png")
    # montage : frame 2
    c2 = recolor(sh[:, 2 * fw:3 * fw], CRIMSON, (0, 0, 0), ACC, GL)
    im = Image.fromarray(c2, "RGBA"); bg = Image.new("RGBA", im.size, (24, 26, 32, 255)); bg.alpha_composite(im)
    mont.paste(bg.convert("RGB"), (i * 256, 0))
    print("PAINTED", d)
mont.save("cine/_show/boss_recolor_montage.png")
print("DONE")
