"""Verify intro-cinematic calibration: how a 16:9 panel renders under COVERED (current) vs CONTAIN
(letterbox fix), in portrait AND landscape frames. Reproduces Cutscene.gd's stretch on the art."""
import os
from PIL import Image, ImageDraw, ImageFont

MENU = r"C:\Users\Administrator\mecha-forge\game\assets\menu"
OUT = r"C:\Users\Administrator\mecha-forge\cine\_show\cine_check.png"
FB = "C:/Windows/Fonts/arialbd.ttf"


def covered(im, w, h):
    s = max(w / im.width, h / im.height)
    r = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x, y = (r.width - w) // 2, (r.height - h) // 2
    return r.crop((x, y, x + w, y + h))


def contain(im, w, h):
    s = min(w / im.width, h / im.height)
    r = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    cell = Image.new("RGB", (w, h), (0, 0, 0))
    cell.paste(r, ((w - r.width) // 2, (h - r.height) // 2))
    return cell


src = Image.open(os.path.join(MENU, "cine1.png")).convert("RGB")  # the wide "war" establishing shot
# frames: (label, mode, w, h) scaled down for display
FR = [
    ("PORTRAIT  COVERED (actuel)\n-> rogne les cotes, on perd la scene", covered, 360, 640),
    ("PORTRAIT  CONTAIN (fix)\n-> panneau ENTIER, bandes noires", contain, 360, 640),
    ("PAYSAGE  COVERED (actuel)\n-> 16:9 dans 16:9 = OK", covered, 640, 360),
    ("PAYSAGE  CONTAIN (fix)\n-> identique, OK", contain, 640, 360),
]
pad, top = 16, 60
# lay portrait pair on the left row, landscape pair below
W = 360 * 2 + pad * 3
H = top + 640 + pad + 360 + pad + 40
sheet = Image.new("RGB", (W, H), (18, 20, 26))
d = ImageDraw.Draw(sheet)
d.text((pad, 18), "CINEMATIQUE INTRO — calibrage (panneau cine1, 16:9)", font=ImageFont.truetype(FB, 24), fill=(200, 230, 245))
pos = [(pad, top), (pad * 2 + 360, top), (pad, top + 640 + pad), (pad * 2 + 360, top + 640 + pad)]
for i, (lbl, fn, w, h) in enumerate(FR):
    x, y = pos[i]
    img = fn(src, w, h)
    sheet.paste(img, (x, y))
    d.rectangle([x, y, x + w, y + h], outline=(90, 200, 220), width=2)
    for j, line in enumerate(lbl.split("\n")):
        d.text((x + 4, y + h + 2 + j * 16), line, font=ImageFont.truetype(FB, 13), fill=(150, 210, 225))
sheet.save(OUT)
print("ok ->", OUT)
