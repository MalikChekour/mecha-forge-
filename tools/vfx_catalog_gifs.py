#!/usr/bin/env python3
"""Build web display GIFs: each AAA effect sheet composited (additive) over the game's
dark tech floor, tinted to its weapon accent, clean-loop, palette-optimised for the catalog."""
import os
from PIL import Image
import numpy as np

ROOT = "C:/Users/Administrator/mecha-forge"
SHEETS = f"{ROOT}/game/assets/vfx"
FLOOR = f"{ROOT}/game/assets/decor/ground_tech.png"
OUT = f"{ROOT}/refs/vfx_cards"
os.makedirs(OUT, exist_ok=True)

FPX = 168          # source cell size in the sheet
CARD = 224         # output card size
# id -> (frames, native_hue, accent RGB 0-1, out_frames, colors)
EFF = {
    "muzzle":    (28, False, (1.00, 0.72, 0.16), 18, 56),
    "impact":    (28, False, (1.00, 0.72, 0.16), 18, 56),
    "explosion": (30, True,  (1.00, 0.55, 0.20), 20, 96),
    "beam":      (26, False, (0.28, 0.86, 1.00), 16, 56),
    "aoe":       (28, True,  (0.75, 0.35, 1.00), 18, 96),
    "sabre":     (26, False, (0.35, 0.95, 1.00), 16, 56),
    "shockwave": (26, False, (0.45, 0.90, 1.00), 16, 56),
    "charge":    (28, False, (0.70, 0.45, 1.00), 18, 72),
}

def make_bg():
    fl = Image.open(FLOOR).convert("RGB")
    # tile/crop a CARD-sized patch, darken to premium near-black, add radial vignette
    fw, fh = fl.size
    patch = fl.resize((CARD, CARD)) if (fw < CARD or fh < CARD) else fl.crop((0, 0, CARD, CARD))
    a = np.asarray(patch, dtype=np.float32) / 255.0
    a *= 0.34                                   # deep, dark-premium
    yy, xx = np.mgrid[0:CARD, 0:CARD]
    r = np.sqrt(((xx-CARD/2)/(CARD/2))**2 + ((yy-CARD/2)/(CARD/2))**2)
    vig = np.clip(1.15 - 0.85*r, 0.15, 1.0)     # darker corners
    a *= vig[..., None]
    return a                                     # float HxWx3

BG = make_bg()

def build(idv, frames, native, accent, out_frames, colors):
    sheet = np.asarray(Image.open(f"{SHEETS}/aaa_{idv}.png").convert("RGBA"), dtype=np.float32)/255.0
    H = sheet.shape[0]
    fw = sheet.shape[1] // frames
    acc = np.array(accent, dtype=np.float32)
    idxs = [int(round(k*(frames-1)/(out_frames-1))) for k in range(out_frames)]
    imgs = []
    for j in idxs:
        cell = sheet[:, j*fw:(j+1)*fw, :]
        rgb = cell[..., :3]; al = cell[..., 3:4]
        # tint white-hot sheets by accent; keep a hot white core in the brightest zone
        if not native:
            core = np.clip((al-0.72)/0.28, 0, 1)          # brightest bit stays near-white
            tinted = acc[None, None, :]*(1-core) + np.array([1,1,1])*core
            eff = tinted * al
        else:
            eff = rgb * al
        # scale cell -> CARD
        im = Image.fromarray((np.clip(np.dstack([eff, al[...,0]]),0,1)*255).astype(np.uint8), "RGBA").resize((CARD, CARD))
        arr = np.asarray(im, dtype=np.float32)/255.0
        ergb = arr[..., :3]; ea = arr[..., 3:4]
        out = np.clip(BG + ergb*1.35, 0, 1)               # additive over floor (over-drive glow)
        imgs.append(Image.fromarray((out*255).astype(np.uint8), "RGB").convert("P", palette=Image.ADAPTIVE, colors=colors))
    imgs[0].save(f"{OUT}/{idv}.gif", save_all=True, append_images=imgs[1:],
                 duration=58, loop=0, disposal=2, optimize=True)
    sz = os.path.getsize(f"{OUT}/{idv}.gif")
    print(f"  {idv}.gif  {out_frames}f  {sz//1024}KB")

for idv,(fr,nat,acc,of,col) in EFF.items():
    build(idv, fr, nat, acc, of, col)
print("done")
