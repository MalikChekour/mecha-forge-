"""Pixel-art mecha TEST: (A) pure-AI method (FLUX pixel style, Spriterrific-like) and (B) the
reliable 3D->pixel method (pixelate the existing 3D-rendered george sheets = consistent views +
animations). Builds a comparison contact sheet + an animated GIF of the walk."""
import os, glob
from PIL import Image, ImageDraw, ImageFont

ROOT = r"C:\Users\Administrator\mecha-forge"
MECHA = os.path.join(ROOT, "game", "assets", "mecha")
PX = os.path.join(ROOT, "cine", "pixel")
OUT = os.path.join(ROOT, "cine", "_show")
FB = "C:/Windows/Fonts/arialbd.ttf"


def pixelate(im, target_w, colors=22, athresh=100):
    """RGBA -> low-res, palette-quantised pixel art (still low-res; caller upscales nearest)."""
    im = im.convert("RGBA")
    h = max(1, round(target_w * im.height / im.width))
    small = im.resize((target_w, h), Image.BILINEAR)
    rgb = small.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    a = small.getchannel("A").point(lambda p: 255 if p > athresh else 0)
    return Image.merge("RGBA", (*rgb.split(), a))


def up(im, scale):
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def frames_of(path, fw=192):
    im = Image.open(path).convert("RGBA")
    n = max(1, im.width // fw)
    return [im.crop((i * fw, 0, (i + 1) * fw, im.height)) for i in range(n)]


def fnt(s):
    return ImageFont.truetype(FB, s)


# ---------- A) pure-AI ----------
ai_views = pixelate(Image.open(os.path.join(PX, "ai_views.png")), 160, colors=24)
ai_walk = pixelate(Image.open(os.path.join(PX, "ai_walk.png")), 240, colors=24)

# ---------- B) 3D -> pixel (george) : 4 views idle + walk frames ----------
DIRS = ["front", "back", "left", "right"]
idle_px = []
for d in DIRS:
    f = frames_of(os.path.join(MECHA, "george_idle_%s.png" % d))[0]
    idle_px.append(up(pixelate(f, 46, colors=20), 3))   # 46px -> x3 = 138
walk_front = frames_of(os.path.join(MECHA, "george_walk_front.png"))
walk_px = [up(pixelate(fr, 46, colors=20), 3) for fr in walk_front]

# ---------- compose contact sheet ----------
W = 1180
H = 900
sheet = Image.new("RGB", (W, H), (16, 18, 24))
d = ImageDraw.Draw(sheet)
d.text((20, 14), "TEST MECHA PIXEL-ART", font=fnt(30), fill=(200, 230, 245))

# A) AI row
d.text((20, 60), "A. METHODE PURE-IA (FLUX, facon Spriterrific) — 1 prompt -> image",
       font=fnt(18), fill=(255, 200, 120))
sheet.paste(up(ai_views, 2).convert("RGB"), (20, 92))
aw = up(ai_walk, 2)
sheet.paste(aw.convert("RGB"), (360, 92))
d.text((360, 92 + aw.height + 6), "cycle de marche IA (frames peu alignees)", font=fnt(13), fill=(150, 165, 185))
d.text((20, 92 + up(ai_views, 2).height + 6), "4 vues IA (approximatives)", font=fnt(13), fill=(150, 165, 185))

# B) 3D->pixel row
y0 = 470
d.text((20, y0), "B. METHODE 3D -> PIXEL (george existant pixellise) — vues + anims COHERENTES",
       font=fnt(18), fill=(120, 235, 160))
# 4 views
lbl = ["face", "dos", "gauche", "droite"]
for i, im in enumerate(idle_px):
    x = 20 + i * 150
    bg = Image.new("RGB", (im.width, im.height), (26, 29, 36)); bg.paste(im, (0, 0), im)
    sheet.paste(bg, (x, y0 + 30))
    d.text((x + 4, y0 + 30 + im.height + 2), lbl[i], font=fnt(14), fill=(150, 220, 235))
# walk strip
d.text((20, y0 + 210), "marche (8 frames, face) :", font=fnt(14), fill=(180, 200, 215))
xx = 20
for im in walk_px:
    bg = Image.new("RGB", (im.width, im.height), (26, 29, 36)); bg.paste(im, (0, 0), im)
    sheet.paste(bg, (xx, y0 + 236)); xx += im.width + 6
sheet.save(os.path.join(OUT, "pixel_test.png"))
print("sheet ok")

# ---------- animated GIF of the pixel walk (shared palette to avoid flicker) ----------
gif_frames = [up(pixelate(fr, 46, colors=20), 4).convert("RGBA") for fr in walk_front]
base = Image.new("RGBA", gif_frames[0].size, (26, 29, 36, 255))
flat = [Image.alpha_composite(base, f).convert("RGB") for f in gif_frames]
pal = flat[0].quantize(colors=32)
flat_q = [im.quantize(palette=pal) for im in flat]
flat_q[0].save(os.path.join(OUT, "pixel_walk.gif"), save_all=True, append_images=flat_q[1:],
               duration=110, loop=0, disposal=1)
print("gif ok")
