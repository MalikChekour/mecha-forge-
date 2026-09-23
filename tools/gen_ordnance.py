# -*- coding: utf-8 -*-
"""Genere un SET de VRAIS MISSILES reconnaissables (plusieurs sortes) via LE GENERATEUR
(Pollinations FLUX), detoure (rembg) + oriente (axe long horizontal, tete a droite) -> montage
par type pour choisir. Sorties candidates : cine/_show/ord_gen/<type>_s<seed>.png + montages.
  python gen_ordnance.py                 # tous les types, 4 seeds
  python gen_ordnance.py rocket 6        # un type, N seeds
"""
import urllib.request, urllib.parse, os, sys, io, math
import numpy as np
from PIL import Image, ImageDraw
from rembg import remove

SHOW = os.path.abspath("cine/_show/ord_gen"); os.makedirs(SHOW, exist_ok=True)
STYLE = ("simple 3D render of ONE small rocket projectile, flat orthographic SIDE PROFILE, "
         "lying perfectly horizontal, whole object visible, centered, matte finish, "
         "isolated on plain flat medium-grey studio background, soft even lighting, clean game icon, "
         "STRICTLY NOT an aircraft, NOT an airplane, NOT a jet fighter, NO wings, NO delta wings, "
         "NO swept wings, NO tailplane, NO cockpit, just a compact stubby cylindrical tube; "
         "no launcher, no smoke, no exhaust, no hands, no text, no watermark, no scenery")

TYPES = {
    # (le prompt qui marchait le mieux : tube court, tete conique, TOUTES PETITES ailettes)
    "rocket":  "a compact stubby rocket, short smooth cylindrical gunmetal tube body, a conical nose "
               "cone glowing hot orange-red at the right end, three TINY short stubby tail fins, "
               "a small dark exhaust nozzle at the left end; thick and short, like a firework rocket",
    "rpg":     "an RPG-7 rocket-propelled grenade warhead, a bulbous pointed olive-green warhead head on "
               "the right on a thin metal stem, tiny stabiliser fins at the left tail; iconic and simple",
    "torpedo": "a naval torpedo, one long smooth rounded steel cylinder, blunt rounded nose on the right, "
               "a small propeller and tiny fins at the left tail; plain metal tube, simple",
}

def orient(im):
    a = np.array(im)[:, :, 3].astype(float)
    ys, xs = np.nonzero(a > 40)
    if len(xs) < 10: return im
    xs = xs.astype(float); ys = ys.astype(float)
    cov = np.cov(np.stack([xs - xs.mean(), ys - ys.mean()]))
    w, v = np.linalg.eigh(cov); axis = v[:, int(np.argmax(w))]
    out = im.rotate(-math.degrees(math.atan2(axis[1], axis[0])), resample=Image.BICUBIC, expand=True)
    ob = out.getbbox()
    if ob and (ob[3] - ob[1]) > (ob[2] - ob[0]):
        out = out.rotate(90, resample=Image.BICUBIC, expand=True)
    arr = np.array(out).astype(float); al = arr[:, :, 3]
    warm = np.clip(arr[:, :, 0] - arr[:, :, 2], 0, 255) * (al > 40)
    if warm.sum() > 1:
        wx = (np.arange(arr.shape[1])[None, :] * warm).sum() / warm.sum()
        gx = np.nonzero(al > 40)[1].mean()
        if wx < gx: out = out.transpose(Image.FLIP_LEFT_RIGHT)
    bb = out.getbbox()
    if bb: out = out.crop(bb)
    sq = max(out.size); cv = Image.new("RGBA", (sq, sq), (0, 0, 0, 0))
    cv.alpha_composite(out, ((sq - out.width) // 2, (sq - out.height) // 2))
    return cv.resize((128, 128), Image.LANCZOS)

def gen(kind, seed):
    u = ("https://image.pollinations.ai/prompt/"
         + urllib.parse.quote("%s, %s" % (TYPES[kind], STYLE))
         + "?width=768&height=768&nologo=true&model=flux&seed=%s" % seed)
    raw = urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"}), timeout=200).read()
    return orient(remove(Image.open(io.BytesIO(raw)).convert("RGBA")))

kinds = [sys.argv[1]] if len(sys.argv) > 1 and sys.argv[1] in TYPES else list(TYPES)
N = int(sys.argv[2]) if len(sys.argv) > 2 else 4
for kind in kinds:
    tiles = []
    for s in range(N):
        seed = 200 + s * 11
        try:
            im = gen(kind, seed); im.save(os.path.join(SHOW, "%s_s%d.png" % (kind, seed))); tiles.append((seed, im)); print("GEN", kind, seed, flush=True)
        except Exception as e:
            print("FAIL", kind, seed, e, flush=True)
    if tiles:
        mont = Image.new("RGB", (len(tiles) * 150 + 20, 180), (22, 24, 30)); dr = ImageDraw.Draw(mont)
        for i, (seed, im) in enumerate(tiles):
            bg = Image.new("RGBA", (140, 140), (30, 32, 40, 255)); bg.alpha_composite(im.resize((128, 128)), (6, 6))
            mont.paste(bg.convert("RGB"), (i * 150 + 10, 28)); dr.text((i * 150 + 12, 8), "%s s%d" % (kind, seed), fill=(230, 230, 240))
        mont.save(os.path.join("cine/_show", "misgen_%s.png" % kind)); print("MONTAGE", kind, flush=True)
print("DONE")
