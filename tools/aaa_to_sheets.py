#!/usr/bin/env python3
"""Convert the AAA VFX gifs -> game sprite-sheets.
White-hot luminance sheets (rgb=white, alpha=luminance) so the in-engine
per-weapon accent colour tints them (dark-premium: one vivid accent / weapon).
A few keep their native hue where the colour *is* the weapon signature."""
import os
from PIL import Image
import numpy as np

ROOT = "C:/Users/Administrator/mecha-forge"
SRC = f"{ROOT}/refs/vfx_aaa"
DST = f"{ROOT}/game/assets/vfx"
os.makedirs(DST, exist_ok=True)

FPX = 168          # per-frame size in the sheet
# id -> (keep_native_hue, target_frames)
JOBS = {
    "muzzle":    (False, 28),
    "impact":    (False, 28),
    "explosion": (True,  30),   # fireball colour is the effect
    "beam":      (False, 26),
    "aoe":       (True,  28),   # plasma violet is the signature
    "sabre":     (False, 26),
    "shockwave": (False, 26),
    "charge":    (False, 28),
}

# radial edge vignette: forces alpha to 0 at the cell border so an additive
# sprite never shows a hard square halo when its glow reaches the edge.
_yy, _xx = np.mgrid[0:FPX, 0:FPX]
_r = np.sqrt(((_xx - FPX/2) / (FPX/2))**2 + ((_yy - FPX/2) / (FPX/2))**2)
EDGE = np.clip((1.0 - _r) / 0.16, 0.0, 1.0)          # 1 inside, ramps to 0 in the outer 16%

def to_sheet(idv, native, tgt):
    im = Image.open(f"{SRC}/{idv}/{idv}.gif")
    n = getattr(im, "n_frames", 1)
    idxs = [int(round(k*(n-1)/(tgt-1))) for k in range(tgt)] if n > 1 else [0]
    frames = []
    for j in idxs:
        im.seek(j)
        rgb = np.asarray(im.convert("RGB").resize((FPX, FPX)), dtype=np.float32) / 255.0
        lum = rgb.max(axis=2)                       # brightest channel = glow strength
        # soft floor so faint background haze goes fully transparent
        a = np.clip((lum - 0.09) / 0.91, 0.0, 1.0) ** 0.9
        a = a * EDGE                                # kill any square halo at the cell border
        if native:
            out = np.dstack([rgb, a])               # keep colour (fire / plasma)
        else:
            # white-hot core that keeps a hint of the original warm/cool tint in the mids
            base = np.ones_like(rgb)
            out = np.dstack([base, a])
        frames.append((out * 255).astype(np.uint8))
    sheet = Image.fromarray(np.concatenate(frames, axis=1), "RGBA")
    sheet.save(f"{DST}/aaa_{idv}.png")
    return len(frames)

for idv, (native, tgt) in JOBS.items():
    c = to_sheet(idv, native, tgt)
    print(f"  aaa_{idv}.png  frames={c} native={native}")
print("done")
