# -*- coding: utf-8 -*-
"""Detoure (rembg) + oriente (nez ETROIT a droite) les missiles Gemini -> sprites jeu 128px
transparents dans game/assets/weapons/. Mapping src -> nom de sortie en argv (defaut = set complet)."""
import os, sys, io, math
import numpy as np
from PIL import Image
from rembg import remove

OUTW = os.path.abspath("game/assets/weapons"); os.makedirs(OUTW, exist_ok=True)
SRC = os.path.abspath("cine/_show/inv")

# src (sans prefixe) -> nom de fichier de sortie
MAP = {
    "gemini_mecha": "missile_gunner",     # gunner = missile mecha elabore
    "gemini_ogive": "missile_boss",       # ogive qui tombe = bombe lourde
    "gemini_guided": "missile_guided",
    "gemini_rpg": "missile_rpg",
    "gemini_croisiere": "missile_croisiere",
}

def orient(im):
    a = np.array(im)[:, :, 3].astype(float); ys, xs = np.nonzero(a > 40)
    if len(xs) < 10: return im
    xs = xs.astype(float); ys = ys.astype(float)
    cov = np.cov(np.stack([xs - xs.mean(), ys - ys.mean()])); w, v = np.linalg.eigh(cov)
    ax = v[:, int(np.argmax(w))]
    out = im.rotate(-math.degrees(math.atan2(ax[1], ax[0])), resample=Image.BICUBIC, expand=True)
    ob = out.getbbox()
    if ob and (ob[3] - ob[1]) > (ob[2] - ob[0]): out = out.rotate(90, resample=Image.BICUBIC, expand=True)
    al = np.array(out)[:, :, 3]
    cols = np.nonzero(al.max(axis=0) > 40)[0]
    if len(cols) > 8:
        x0, x1 = cols[0], cols[-1]; band = max(3, (x1 - x0) // 5)
        lh = (al[:, x0:x0 + band] > 40).sum(axis=0).mean()
        rh = (al[:, x1 - band:x1] > 40).sum(axis=0).mean()
        if lh < rh: out = out.transpose(Image.FLIP_LEFT_RIGHT)   # nez etroit -> droite
    bb = out.getbbox()
    if bb: out = out.crop(bb)
    sq = max(out.size); cv = Image.new("RGBA", (sq, sq), (0, 0, 0, 0))
    cv.alpha_composite(out, ((sq - out.width) // 2, (sq - out.height) // 2))
    return cv.resize((128, 128), Image.LANCZOS)

for src, out in MAP.items():
    p = os.path.join(SRC, "%s.png" % src)
    if not os.path.exists(p):
        print("MISS", src); continue
    im = orient(remove(Image.open(p).convert("RGBA")))
    im.save(os.path.join(OUTW, "%s.png" % out)); print("OK", out)
print("DONE")
