# -*- coding: utf-8 -*-
"""Mock RAPIDE du montage d'un equipement sur le mecha (composite PIL sur le sprite baké),
pour regler position/echelle/flip/z par direction AVANT de cabler les ancrages en jeu.
Params par direction dans PLACE = (dx, dy, scale, flip_h, rot_deg, behind).
  dx,dy = offset px (repere sprite 256, +x droite, +y bas) depuis le CENTRE du sprite.
"""
import sys, math
from PIL import Image

CHASSIS = sys.argv[1] if len(sys.argv) > 1 else "vortex"
EQUIP = "game/assets/equip/cannon_shoulder.png"
DIRS = ["front", "back", "left", "right"]
# reglages initiaux (a iterer)
# ancrages MESURES (os LeftArm, epaule gauche) projetes par direction (_shoulder_measure.py) :
#   front (15,-54) back (-15,-56) left (-1,-45) right (1,-65)  [offset px256 depuis le centre]
# barrel oriente selon le facing : left->pointe gauche (flip), right->droite, z derriere si bras cache.
PLACE = {
    "front": (16, -44, 0.29, False, 14, False),
    "back":  (-16, -46, 0.29, True, 14, True),
    "left":  (-2, -37, 0.33, True, 2, False),
    "right": (2, -53, 0.27, False, 2, True),
}

def compose(dr):
    sh = Image.open("game/assets/mecha/%s_walk_%s.png" % (CHASSIS, dr)).convert("RGBA")
    fw = sh.width // 8
    mech = sh.crop((2 * fw, 0, 3 * fw, sh.height))   # frame 2
    eq = Image.open(EQUIP).convert("RGBA")
    dx, dy, sc, flip, rot, behind = PLACE[dr]
    ew = int(eq.width * sc); eh = int(eq.height * sc)
    e = eq.resize((ew, eh))
    if flip: e = e.transpose(Image.FLIP_LEFT_RIGHT)
    if rot: e = e.rotate(rot, resample=Image.BICUBIC, expand=True)
    cx = fw // 2 + dx - e.width // 2
    cy = sh.height // 2 + dy - e.height // 2
    base = Image.new("RGBA", mech.size, (0, 0, 0, 0))
    if behind:
        base.alpha_composite(e, (cx, cy)); base.alpha_composite(mech, (0, 0))
    else:
        base.alpha_composite(mech, (0, 0)); base.alpha_composite(e, (cx, cy))
    bg = Image.new("RGBA", mech.size, (30, 32, 40, 255)); bg.alpha_composite(base)
    return bg.convert("RGB")

out = Image.new("RGB", (256 * 4 + 20, 276), (20, 22, 28))
from PIL import ImageDraw
d = ImageDraw.Draw(out)
for i, dr in enumerate(DIRS):
    out.paste(compose(dr), (i * 256 + 5, 20)); d.text((i * 256 + 8, 4), dr, fill=(235, 235, 245))
out.save("cine/_show/mock_equip.png"); print("ok")
