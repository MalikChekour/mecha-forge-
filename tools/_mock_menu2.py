"""Premium LANDSCAPE menu mockup (1280x720) for MECHA-FORGE — the design I'll build in Godot.
Full-bleed hero art + cinematic darkening, top currency chips, logo, a big glowing PLAY, and a
row of framed secondary buttons. PIL only."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

CINE = r"C:\Users\Administrator\mecha-forge\cine"
MENU = r"C:\Users\Administrator\mecha-forge\game\assets\menu"
OUT = r"C:\Users\Administrator\mecha-forge\cine\_show\menu2.png"
W, H = 1280, 720
FB = "C:/Windows/Fonts/arialbd.ttf"
FR = "C:/Windows/Fonts/arial.ttf"
CY = (70, 216, 240)
GOLD = (255, 205, 90)


def f(p, s):
    return ImageFont.truetype(p, s)


def covered(im, w, h):
    s = max(w / im.width, h / im.height)
    r = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x, y = (r.width - w) // 2, (r.height - h) // 2
    return r.crop((x, y, x + w, y + h))


def vgrad(w, h, top, bot):
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


def rrect(d, box, r, fill=None, outline=None, w=2):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=w)


def ctext(d, cx, y, txt, fnt, fill, ow=0, oc=(0, 0, 0)):
    b = d.textbbox((0, 0), txt, font=fnt); tw = b[2] - b[0]
    x = cx - tw // 2
    if ow:
        for dx in range(-ow, ow + 1):
            for dy in range(-ow, ow + 1):
                d.text((x + dx, y + dy), txt, font=fnt, fill=oc)
    d.text((x, y), txt, font=fnt, fill=fill)
    return tw


def button(base, cx, cy, w, h, label, sub, accent, big=False):
    """Rounded gradient button with border + glow, icon-less; returns via paste."""
    # glow
    glow = Image.new("RGBA", (w + 60, h + 60), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rounded_rectangle([30, 30, 30 + w, 30 + h], radius=16, fill=(*accent, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    base.alpha_composite(glow, (cx - w // 2 - 30, cy - h // 2 - 30))
    # body gradient
    top = tuple(min(255, int(c * 1.15) + 22) for c in accent)
    bot = tuple(int(c * 0.42) for c in accent)
    body = vgrad(w, h, top, bot).convert("RGBA")
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=16, fill=255)
    base.paste(body, (cx - w // 2, cy - h // 2), mask)
    d = ImageDraw.Draw(base)
    rrect(d, [cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2], 16,
          outline=(min(255, accent[0] + 80), min(255, accent[1] + 80), min(255, accent[2] + 80), 255), w=3)
    # sheen
    d.rounded_rectangle([cx - w // 2 + 4, cy - h // 2 + 4, cx + w // 2 - 4, cy - h // 2 + h // 3], radius=12,
                        fill=(255, 255, 255, 26))
    fs = 44 if big else 24
    ctext(d, cx, cy - (26 if big else 18) - (6 if sub else 0), label, f(FB, fs), (255, 255, 255), ow=2)
    if sub:
        ctext(d, cx, cy + (14 if big else 8), sub, f(FR, 15), (235, 245, 250))


def chip(base, x, y, w, h, icon_col, label):
    d = ImageDraw.Draw(base)
    rrect(d, [x, y, x + w, y + h], 10, fill=(14, 20, 30, 220), outline=(60, 90, 110, 255), w=2)
    d.ellipse([x + 10, y + h // 2 - 9, x + 28, y + h // 2 + 9], fill=icon_col)
    d.text((x + 38, y + h // 2 - 13), label, font=f(FB, 22), fill=(235, 245, 250))


# ---- compose ----
bg = covered(Image.open(os.path.join(CINE, "hero_hq.png")).convert("RGB"), W, H).convert("RGBA")
# cinematic darkening: bottom band for buttons + left for title + vignette
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(ov)
# bottom gradient band
band = vgrad(W, 300, (8, 10, 16), (8, 10, 16)).convert("RGBA")
bmask = Image.new("L", (W, 300))
for yy in range(300):
    bmask.paste(int(235 * (yy / 299) ** 1.2), (0, yy, W, yy + 1))
bg.paste(band, (0, H - 300), bmask)
# top scrim
top = vgrad(W, 150, (6, 8, 13), (6, 8, 13)).convert("RGBA")
tmask = Image.new("L", (W, 150))
for yy in range(150):
    tmask.paste(int(180 * (1 - yy / 149)), (0, yy, W, yy + 1))
bg.paste(top, (0, 0), tmask)
d = ImageDraw.Draw(bg)

# --- top-right currency chips ---
chip(bg, W - 250, 20, 230, 42, GOLD, "1240")            # ferraille
chip(bg, W - 250, 70, 230, 42, (150, 200, 255), "18  cristaux")
# points chip (headline) top-left of currency
chip(bg, W - 490, 20, 230, 42, (120, 235, 255), "9  points")
d.text((W - 490 + 200, 22), "+", font=f(FB, 30), fill=(120, 255, 180))

# --- logo top-left ---
try:
    em = Image.open(os.path.join(MENU, "emblem_cut.png")).convert("RGBA")
    eh = 132; em = em.resize((round(em.width * eh / em.height), eh), Image.LANCZOS)
    bg.alpha_composite(em, (40, 34))
    lx = 40 + em.width + 20
except Exception:
    lx = 60
d = ImageDraw.Draw(bg)
d.text((lx, 52), "MECHA-FORGE", font=f(FB, 62), fill=(200, 240, 255))
for dx in (-1, 1):
    d.text((lx + dx, 52), "MECHA-FORGE", font=f(FB, 62), fill=(40, 160, 190))
d.text((lx + 4, 122), "SURVIVE  THE  HORDE", font=f(FB, 22), fill=CY)

# --- bottom: big PLAY + secondary row ---
button(bg, W // 2, H - 150, 420, 96, "JOUER", "Campagne · NORMAL", (32, 170, 92), big=True)
sec = [("ARSENAL", "arme + points", (150, 110, 60)),
       ("ÉQUIPEMENT", "pièces", (110, 90, 160)),
       ("GARAGE", "mechs", (60, 110, 160)),
       ("QUOTIDIEN", "récompenses", (60, 130, 95))]
bw, gap = 250, 18
total = len(sec) * bw + (len(sec) - 1) * gap
x0 = (W - total) // 2 + bw // 2
for i, (lab, sub, acc) in enumerate(sec):
    button(bg, x0 + i * (bw + gap), H - 56, bw, 62, lab, sub, acc)

d = ImageDraw.Draw(bg)
d.text((20, H - 20), "v3.1   ·   Musique K. MacLeod CC-BY   ·   SFX Kenney CC0", font=f(FR, 13), fill=(120, 140, 155))
bg.convert("RGB").save(OUT)
print("ok", OUT)
