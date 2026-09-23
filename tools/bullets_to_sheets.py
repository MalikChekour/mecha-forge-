#!/usr/bin/env python3
"""Convert the rendered bullet gifs -> game sprite sheets (horizontal, 12 cells of 128px).

Luminance families ship WHITE (rgb=1) with alpha=luminance, so the engine can tint each
one with its weapon's accent colour. The warhead keeps its native fire hue.
"""
import os
from PIL import Image
import numpy as np

ROOT = "C:/Users/Administrator/mecha-forge"
SRC = f"{ROOT}/refs/bullets"
DST = f"{ROOT}/game/assets/bullets"
os.makedirs(DST, exist_ok=True)

CELL = 128
FRAMES = 12
# id -> (native_hue, left_fade_px)
# left_fade guards against a plume running off the canvas edge (additive blending would show
# that as a hard vertical cut). All four renders now fall to black on their own — the warhead's
# earlier 0.46 left-edge bleed was fixed in its render — so no fade is needed. Kept here because
# the sheets are re-rendered often and it's the one defect that silently ruins them.
JOBS = {
    "tracer":  (False, 0),
    "lance":   (False, 0),
    "orb":     (False, 0),
    "warhead": (True,  0),
}

def build(idv, native, left_fade):
    im = Image.open(f"{SRC}/{idv}/{idv}.gif")
    n = getattr(im, "n_frames", 1)
    assert n >= FRAMES, f"{idv}: only {n} frames"
    cells = []
    for i in range(FRAMES):
        im.seek(i)
        rgb = np.asarray(im.convert("RGB").resize((CELL, CELL)), dtype=np.float32) / 255.0
        lum = rgb.max(axis=2)
        a = np.clip((lum - 0.04) / 0.96, 0.0, 1.0)
        if left_fade > 0:
            ramp = np.clip(np.arange(CELL) / float(left_fade), 0.0, 1.0)   # 0 at x=0 -> 1
            a = a * ramp[None, :]
        out_rgb = rgb if native else np.ones_like(rgb)
        cells.append((np.dstack([out_rgb, a]) * 255).astype(np.uint8))
    sheet = Image.fromarray(np.concatenate(cells, axis=1), "RGBA")
    sheet.save(f"{DST}/{idv}.png")
    # verify no border bleed on any cell edge (would show as a hard box in additive blend)
    arr = np.asarray(sheet, dtype=np.float32)[..., 3] / 255.0
    worst = 0.0
    for i in range(FRAMES):
        c = arr[:, i*CELL:(i+1)*CELL]
        worst = max(worst, c[0].max(), c[-1].max(), c[:, 0].max(), c[:, -1].max())
    print(f"  {idv}.png  {sheet.size}  border={worst:.3f} {'OK' if worst < 0.06 else '** BLEEDS **'}")

for idv, (native, lf) in JOBS.items():
    build(idv, native, lf)
print("done")
