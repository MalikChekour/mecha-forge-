# -*- coding: utf-8 -*-
"""Oriente un sprite de projectile : rotation pour que l'axe LONG soit HORIZONTAL et la
tete CHAUDE (ogive orange/rouge) pointe a DROITE (+X). -> game/assets/weapons/<name>.png
  python orient_ordnance.py <src.png> <name> [extra_deg]
"""
import sys, os, math, numpy as np
from PIL import Image

src = sys.argv[1]; name = sys.argv[2]
extra = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
OUTW = os.path.abspath("game/assets/weapons"); os.makedirs(OUTW, exist_ok=True)

im = Image.open(src).convert("RGBA")
a = np.array(im)[:, :, 3].astype(float)
ys, xs = np.nonzero(a > 40)
xs = xs.astype(float); ys = ys.astype(float)
cx, cy = xs.mean(), ys.mean()
# PCA -> axe principal (le plus long)
cov = np.cov(np.stack([xs - cx, ys - cy]))
w, v = np.linalg.eigh(cov)
axis = v[:, np.argmax(w)]                       # vecteur de l'axe long (dx, dy)
ang = math.degrees(math.atan2(axis[1], axis[0]))  # angle image (y vers le bas)
# rotation pour rendre l'axe horizontal (PIL tourne CCW en degres, y-haut)
rot = -ang
out = im.rotate(rot, resample=Image.BICUBIC, expand=True)
# force le PAYSAGE (axe long horizontal) : si encore portrait, +90 deg
ob = out.getbbox()
if ob and (ob[3] - ob[1]) > (ob[2] - ob[0]):
    out = out.rotate(90, resample=Image.BICUBIC, expand=True)
# tete chaude a droite ? mesure la "chaleur" (R - B) ponderee -> centroide chaud
arr = np.array(out).astype(float); al = arr[:, :, 3]
warm = np.clip(arr[:, :, 0] - arr[:, :, 2], 0, 255) * (al > 40)
if warm.sum() > 1:
    wx = (np.arange(arr.shape[1])[None, :] * warm).sum() / warm.sum()
    gx = np.nonzero(al > 40)[1].mean()
    if wx < gx:                                 # tete chaude a gauche -> flip pour la mettre a droite
        out = out.transpose(Image.FLIP_LEFT_RIGHT)
if extra:
    out = out.rotate(extra, resample=Image.BICUBIC, expand=True)
# trim + carre + 128
bb = out.getbbox()
if bb: out = out.crop(bb)
sq = max(out.size); canvas = Image.new("RGBA", (sq, sq), (0, 0, 0, 0))
canvas.alpha_composite(out, ((sq - out.width) // 2, (sq - out.height) // 2))
canvas = canvas.resize((128, 128), Image.LANCZOS)
canvas.save(os.path.join(OUTW, "%s.png" % name))
# apercu sur fond sombre
prev = Image.new("RGBA", (160, 160), (26, 28, 34, 255)); prev.alpha_composite(canvas.resize((150, 150)), (5, 5))
prev.convert("RGB").save(os.path.join("cine/_show", "oriented_%s.png" % name))
print("ORIENTED", name, "rot=%.1f" % rot)
