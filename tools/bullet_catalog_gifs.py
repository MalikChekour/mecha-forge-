#!/usr/bin/env python3
"""Catalog GIFs for the 4 HDR bullets: each composited (additive) over the game's tech floor
and tinted with its weapon's accent, exactly as the engine does. Also renders a size strip
showing the bullet at its REAL on-screen size next to the zoom, since the honest story is
that most of the internal detail is invisible at play size."""
import os
from PIL import Image
import numpy as np

ROOT = "C:/Users/Administrator/mecha-forge"
SHEETS = f"{ROOT}/game/assets/bullets"
FLOOR = f"{ROOT}/game/assets/decor/ground_tech.png"
OUT = f"{ROOT}/refs/bullet_cards"
os.makedirs(OUT, exist_ok=True)

CELL, FRAMES = 128, 12
CARD = 224
# id -> (accent RGB 0-1 | None = native fire, game scale from Projectile.BULLET_STYLE)
EFF = {
    "tracer":  ((1.00, 0.72, 0.15), 0.42),
    "warhead": (None,               0.40),
    "lance":   ((0.20, 0.85, 1.00), 0.52),
    "orb":     ((0.75, 0.30, 1.00), 0.36),
}

def make_bg(size):
    fl = Image.open(FLOOR).convert("RGB")
    patch = fl.crop((0, 0, min(size, fl.width), min(size, fl.height))).resize((size, size))
    a = np.asarray(patch, dtype=np.float32) / 255.0 * 0.34
    yy, xx = np.mgrid[0:size, 0:size]
    r = np.sqrt(((xx-size/2)/(size/2))**2 + ((yy-size/2)/(size/2))**2)
    return a * np.clip(1.15 - 0.85*r, 0.15, 1.0)[..., None]

def cells(idv):
    sh = np.asarray(Image.open(f"{SHEETS}/{idv}.png").convert("RGBA"), dtype=np.float32)/255.0
    return [sh[:, i*CELL:(i+1)*CELL, :] for i in range(FRAMES)]

def tint(cell, accent):
    rgb, al = cell[..., :3], cell[..., 3:4]
    if accent is None:
        eff = rgb * al                      # native fire keeps its hue
    else:
        acc = np.array(accent, dtype=np.float32) * 1.6   # engine modulates by accent*1.6
        core = np.clip((al - 0.75) / 0.25, 0, 1)         # hottest part stays near-white
        eff = (acc[None, None, :]*(1-core) + np.ones(3)*core) * al
    return eff

def build(idv, accent, game_scale):
    bg = make_bg(CARD)
    frames = []
    for c in cells(idv):
        eff = tint(c, accent)
        im = Image.fromarray((np.clip(eff, 0, 1)*255).astype(np.uint8), "RGB").resize((CARD, CARD), Image.LANCZOS)
        out = np.clip(bg + np.asarray(im, dtype=np.float32)/255.0 * 1.3, 0, 1)
        frames.append(Image.fromarray((out*255).astype(np.uint8), "RGB").convert("P", palette=Image.ADAPTIVE, colors=72))
    frames[0].save(f"{OUT}/{idv}.gif", save_all=True, append_images=frames[1:],
                   duration=56, loop=0, disposal=2, optimize=True)   # engine plays 18fps ~= 56ms
    print(f"  {idv}.gif  {os.path.getsize(f'{OUT}/{idv}.gif')//1024}KB")

def size_strip():
    """Real play size vs 4x zoom, side by side — what you actually see vs what's in there."""
    pad, gap = 14, 26
    W = 640
    H = 150
    bg = make_bg(max(W, H))[:H, :W]
    canvas = np.clip(bg.copy(), 0, 1)
    x = pad
    for idv, (accent, gs) in EFF.items():
        c = cells(idv)[3]
        real = int(CELL * gs)                       # exactly the size the engine draws it
        eff = tint(c, accent)
        im = Image.fromarray((np.clip(eff, 0, 1)*255).astype(np.uint8), "RGB")
        small = np.asarray(im.resize((real, real), Image.LANCZOS), dtype=np.float32)/255.0
        y = (H - real)//2
        canvas[y:y+real, x:x+real] = np.clip(canvas[y:y+real, x:x+real] + small*1.3, 0, 1)
        x += real + gap
    Image.fromarray((canvas*255).astype(np.uint8), "RGB").save(f"{OUT}/_realsize.png")
    print("  _realsize.png (taille de jeu exacte)")

for idv, (accent, gs) in EFF.items():
    build(idv, accent, gs)
size_strip()
print("done")
