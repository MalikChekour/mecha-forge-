"""2D cut-out puppet walk: segment the mech (rembg) into torso+arms and two legs, then animate an
articulated march (legs swing+lift around the hip, torso bobs). Front view test -> GIF."""
import math, os
import numpy as np
from PIL import Image
from rembg import remove, new_session

sess = new_session("u2net")
OUT = r"C:\Users\Administrator\mecha-forge\cine\artifact"
os.makedirs(OUT, exist_ok=True)


def snap(im, w=120, colors=44):
    im = im.convert("RGBA")
    a = np.asarray(im.getchannel("A"))
    ys, xs = np.where(a > 140)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    h = round(w * im.height / im.width)
    rgb = im.convert("RGB").resize((w, h), Image.BILINEAR).quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    al = im.getchannel("A").resize((w, h), Image.BILINEAR).point(lambda p: 255 if p > 110 else 0)
    return Image.merge("RGBA", (*rgb.split(), al))


mech = snap(remove(Image.open(r"C:\Users\Administrator\mecha-forge\cine\pixel\hi_1.png").convert("RGB")).convert("RGBA"))
w, h = mech.size
HIP = int(h * 0.54)                        # split at the hips
OVER = int(h * 0.09)                       # torso piece extends DOWN past the hip to cover the seam
top = mech.crop((0, 0, w, HIP + OVER))     # torso + head + arms + hip skirt (one rigid piece, drawn last)
legs = mech.crop((0, HIP, w, h))
lh = legs.height
cx = w // 2
ov = 3                                     # small overlap between the two legs so the split has no gap
left_leg = legs.crop((0, 0, cx + ov, lh))
right_leg = legs.crop((cx - ov, 0, w, lh))
PAD = 26


def pad(leg):
    c = Image.new("RGBA", (leg.width + 2 * PAD, leg.height + 2 * PAD), (0, 0, 0, 0))
    c.alpha_composite(leg, (PAD, PAD))
    return c


pL, pR = pad(left_leg), pad(right_leg)
# hip pivot inside each padded leg (top of leg, over the outer thigh so any tilt swings the foot OUTWARD, never crossing)
pivL = (PAD + int(left_leg.width * 0.30), PAD)
pivR = (PAD + int(right_leg.width * 0.70), PAD)

N = 8
frames = []
CH = h + 30
for i in range(N):
    ph = 2 * math.pi * i / N
    sw = math.sin(ph)                          # left-leg phase; right is opposite
    bob = -abs(sw) * 2.0                        # torso settles a touch when a knee is up
    sway = sw * 1.6                             # weight shifts toward the planted foot
    # knee-lift march: each leg raises straight up in alternation (no sideways scissoring)
    liftL = max(0.0, sw) * 11.0
    liftR = max(0.0, -sw) * 11.0
    # a small OUTWARD tilt only while lifted, so the raised knee reads as stepping, feet never cross
    aL = 5.0 * max(0.0, sw)                     # +ccw -> left foot swings out to the left
    aR = -5.0 * max(0.0, -sw)                   # -cw  -> right foot swings out to the right
    stepL = max(0.0, sw) * 2.0                  # lifted leg also shifts out a hair
    stepR = max(0.0, -sw) * 2.0
    canvas = Image.new("RGBA", (w, CH), (0, 0, 0, 0))
    rl = pL.rotate(aL, center=pivL, resample=Image.NEAREST, expand=False)
    rr = pR.rotate(aR, center=pivR, resample=Image.NEAREST, expand=False)
    canvas.alpha_composite(rr, (int(cx - ov - PAD + sway + stepR), int(HIP - PAD - liftR)))
    canvas.alpha_composite(rl, (int(0 - PAD + sway - stepL), int(HIP - PAD - liftL)))
    canvas.alpha_composite(top, (int(sway), int(bob)))   # torso drawn on top -> hides the hip seam
    frames.append(canvas)

# upscale x3 crisp + a neutral bg, build GIF
disp = []
for f in frames:
    u = f.resize((f.width * 3, f.height * 3), Image.NEAREST)
    bg = Image.new("RGB", u.size, (26, 29, 37))
    bg.paste(u, (0, 0), u)
    disp.append(bg)
pal = disp[0].quantize(colors=64)
q = [d.quantize(palette=pal) for d in disp]
q[0].save(os.path.join(OUT, "cutout_walk.gif"), save_all=True, append_images=q[1:], duration=95, loop=0, disposal=1)
# also a strip to inspect the leg articulation
strip = Image.new("RGB", (disp[0].width * N, disp[0].height), (18, 20, 26))
for i, d in enumerate(disp):
    strip.paste(d, (i * d.width, 0))
strip.save(r"C:\Users\Administrator\mecha-forge\cine\_show\cutout_strip.png")
print("ok", os.path.getsize(os.path.join(OUT, "cutout_walk.gif")) // 1024, "Ko  frame", frames[0].size)
