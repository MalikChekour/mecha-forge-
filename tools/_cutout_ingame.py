"""Rebuild lourd_walk_<dir>.png (4 dirs) as an ARTICULATED knee-lift march, using the 2D cut-out
rig, sourced from each idle sheet's standing frame so framing/anchor/size match the game exactly.
Also writes a control strip per direction for inspection before integration."""
import math, os, shutil
import numpy as np
from PIL import Image

MECHA = r"C:\Users\Administrator\mecha-forge\game\assets\mecha"
SHOW = r"C:\Users\Administrator\mecha-forge\cine\_show"
BAK = r"C:\Users\Administrator\mecha-forge\cine\_bak_walk"
os.makedirs(SHOW, exist_ok=True)
os.makedirs(BAK, exist_ok=True)
N = 8
DIRS = ["front", "back", "left", "right"]


def build(dirn, run=False):
    src = Image.open(os.path.join(MECHA, f"lourd_idle_{dirn}.png")).convert("RGBA")
    W, H = src.size
    FW = W // 8
    base = src.crop((0, 0, FW, H))                      # the standing frame
    al = np.asarray(base.getchannel("A"))
    ys, xs = np.where(al > 120)
    bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max(), ys.max()
    bh = by1 - by0
    cx = (bx0 + bx1) // 2
    HIP = by0 + int(bh * 0.55)
    OVER = int(bh * 0.11)                               # torso skirt covers the hip seam
    top = base.crop((0, 0, FW, HIP + OVER))
    legs = base.crop((0, HIP, FW, H))
    lh = legs.height
    ov = 3
    left_leg = legs.crop((0, 0, cx + ov, lh))
    right_leg = legs.crop((cx - ov, 0, FW, lh))
    PAD = 28

    def pad(leg):
        c = Image.new("RGBA", (leg.width + 2 * PAD, leg.height + 2 * PAD), (0, 0, 0, 0))
        c.alpha_composite(leg, (PAD, PAD))
        return c

    pL, pR = pad(left_leg), pad(right_leg)
    pivL = (PAD + int(left_leg.width * 0.30), PAD)      # pivot on outer thigh -> feet swing OUT, never cross
    pivR = (PAD + int(right_leg.width * 0.70), PAD)

    LIFT = 15.0 if run else 11.0                        # knee raise (px); run lifts higher
    TILT = 6.0 if run else 4.5
    SWAY = 2.0 if run else 1.5
    LEAN = int(bh * 0.05) if run else 0                 # run leans the torso forward a hair

    sheet = Image.new("RGBA", (FW * N, H), (0, 0, 0, 0))
    strip = Image.new("RGB", (FW * N, H), (22, 25, 32))
    for i in range(N):
        ph = 2 * math.pi * i / N
        sw = math.sin(ph)
        bob = -abs(sw) * (2.5 if run else 2.0)
        sway = sw * SWAY
        liftL = max(0.0, sw) * LIFT
        liftR = max(0.0, -sw) * LIFT
        aL = TILT * max(0.0, sw)
        aR = -TILT * max(0.0, -sw)
        stepL = max(0.0, sw) * 2.0
        stepR = max(0.0, -sw) * 2.0
        canvas = Image.new("RGBA", (FW, H), (0, 0, 0, 0))
        rl = pL.rotate(aL, center=pivL, resample=Image.NEAREST, expand=False)
        rr = pR.rotate(aR, center=pivR, resample=Image.NEAREST, expand=False)
        canvas.alpha_composite(rr, (int(cx - ov - PAD + sway + stepR), int(HIP - PAD - liftR)))
        canvas.alpha_composite(rl, (int(0 - PAD + sway - stepL), int(HIP - PAD - liftL)))
        canvas.alpha_composite(top, (int(sway), int(bob - LEAN)))
        sheet.alpha_composite(canvas, (i * FW, 0))
        cell = Image.new("RGB", (FW, H), (22, 25, 32))
        cell.paste(canvas, (0, 0), canvas)
        strip.paste(cell, (i * FW, 0))
    anim = "run" if run else "walk"
    sheet.save(os.path.join(MECHA, f"lourd_{anim}_{dirn}.png"))
    strip.save(os.path.join(SHOW, f"cutout_{anim}_{dirn}.png"))


for d in DIRS:
    for a in ["walk", "run"]:
        shutil.copy(os.path.join(MECHA, f"lourd_{a}_{d}.png"), os.path.join(BAK, f"lourd_{a}_{d}.png"))

for d in DIRS:
    build(d, run=False)
    build(d, run=True)

# 4-up contact sheet (walk, all dirs) for a quick look
cells = [Image.open(os.path.join(SHOW, f"cutout_walk_{d}.png")) for d in DIRS]
cw = max(c.width for c in cells)
ch = sum(c.height for c in cells)
board = Image.new("RGB", (cw, ch), (14, 16, 22))
y = 0
for c in cells:
    board.paste(c, (0, y)); y += c.height
board.save(os.path.join(SHOW, "cutout_walk_ALL.png"))
print("built walk+run x4 dirs; backup in _bak_walk")
