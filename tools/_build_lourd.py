"""Build the 4-direction game spritesheets for the new pixel MECHA LOURD from the Kling animations.
rembg cutout -> thresholded global bbox (consistent size) -> pixel-snap -> 8-frame strips.
Output: game/assets/mecha/lourd_<anim>_<dir>.png  (walk/run/attack x front/back/left/right)."""
import glob, os
import numpy as np
from PIL import Image
from rembg import remove, new_session

sess = new_session("u2net")
PROD = "cine/pixel/prod"
CUT = "cine/pixel/prod/cut"
os.makedirs(CUT, exist_ok=True)
os.makedirs("game/assets/mecha", exist_ok=True)

SRC = {"walk": {"front": "walk_face", "back": "walk_dos", "right": "walk_droite"},
       "run":  {"front": "run_face",  "back": "run_dos",  "right": "run_droite"},
       "attack": {"front": "tir_face", "back": "tir_dos", "right": "tir_droite"}}


def pick8(d):
    fs = sorted(glob.glob("%s/fr_%s/*.png" % (PROD, d)))
    return [fs[round(i * (len(fs) - 1) / 7)] for i in range(8)] if fs else []


def cut(path):
    key = os.path.basename(os.path.dirname(path)) + "_" + os.path.basename(path)
    cp = os.path.join(CUT, key)
    if os.path.exists(cp):
        return Image.open(cp).convert("RGBA")
    out = remove(Image.open(path).convert("RGB"), session=sess).convert("RGBA")
    out.save(cp)
    return out


# thresholded global bbox for consistent framing
gx0 = gy0 = 10**9
gx1 = gy1 = 0
for anim, dirs in SRC.items():
    for src in dirs.values():
        for p in pick8(src):
            a = np.asarray(cut(p).getchannel("A"))
            ys, xs = np.where(a > 140)
            if len(xs):
                gx0 = min(gx0, xs.min()); gy0 = min(gy0, ys.min())
                gx1 = max(gx1, xs.max()); gy1 = max(gy1, ys.max())
pad = 12
gx0 = int(max(0, gx0 - pad)); gy0 = int(max(0, gy0 - pad))
gx1 = int(gx1 + pad); gy1 = int(gy1 + pad)
print("mech bbox", gx0, gy0, gx1, gy1, "-> WxH", gx1 - gx0, gy1 - gy0)

FW = 94


def snapf(path, mirror):
    im = cut(path).crop((gx0, gy0, gx1, gy1))
    if mirror:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    h = round(FW * im.height / im.width)
    rgb = im.convert("RGB").resize((FW, h), Image.BILINEAR).quantize(colors=40, method=Image.MEDIANCUT).convert("RGB")
    a = im.getchannel("A").resize((FW, h), Image.BILINEAR).point(lambda p: 255 if p > 110 else 0)
    o = Image.merge("RGBA", (*rgb.split(), a))
    return o.resize((o.width * 2, o.height * 2), Image.NEAREST)


for anim, dirs in SRC.items():
    for gdir in ["front", "back", "right", "left"]:
        src = dirs["right"] if gdir == "left" else dirs[gdir]
        mir = (gdir == "left")
        fr = [snapf(p, mir) for p in pick8(src)]
        fw, fh = fr[0].size
        strip = Image.new("RGBA", (fw * 8, fh), (0, 0, 0, 0))
        for i, f in enumerate(fr):
            strip.paste(f, (i * fw, 0))
        strip.save("game/assets/mecha/lourd_%s_%s.png" % (anim, gdir))
print("done, frame size", fr[0].size)
