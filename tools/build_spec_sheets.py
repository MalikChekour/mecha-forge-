#!/usr/bin/env python3
"""Build premium enemy anim sheets from static 4-dir bakes.
Each anim (idle/walk/attack/hit/die [+hover]) is the SAME brightened static
frame; motion comes from Enemy.gd's live procedural transform (proc:true).
Overwrites the chassis sheet names so every specialist reusing that chassis
inherits the premium art. Input bakes: cine/_show/<name>_<dir>.png
"""
import sys
from PIL import Image

DIRS = ["front", "back", "left", "right"]
OUT = "game/assets/enemies"
# name (bake stem in cine/_show) -> chassis (sheet name) [, extra anims]
MAP = {
    "spec_shielded": ("shielded", ["idle", "walk", "attack", "hit", "die"]),
    "spec_elite":    ("elite",    ["idle", "walk", "attack", "hit", "die"]),
    "spec_warden":   ("warden",   ["idle", "walk", "attack", "hit", "die"]),
    "spec_crusher":  ("crusher",  ["idle", "walk", "attack", "hit", "die"]),
    "spec_eyedrone": ("eyedrone", ["idle", "walk", "attack", "hit", "die", "hover"]),
}


def brighten(im, f=1.4):
    lut = [min(255, int(i * f)) for i in range(256)]
    r, g, b, a = im.split()
    return Image.merge("RGBA", (r.point(lut), g.point(lut), b.point(lut), a))


def main():
    for name, (chassis, anims) in MAP.items():
        for d in DIRS:
            src = brighten(Image.open("cine/_show/%s_%s.png" % (name, d)).convert("RGBA"))
            for anim in anims:
                src.save("%s/%s_%s_%s.png" % (OUT, chassis, anim, d))
        print("built", chassis, "->", len(anims), "anims x 4 dir")
    print("done spec sheets")


if __name__ == "__main__":
    main()
