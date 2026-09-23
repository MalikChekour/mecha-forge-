"""Faithful PIL mockups of the in-engine Cutscene panel + reskinned HOME menu, using the REAL art
and the same layout constants as Cutscene.gd / MetaScreen.gd. Portrait phone 720x1280.
(The server has no GPU so Godot can't render headless — these validate the look before a build.)
"""
import os
from PIL import Image, ImageDraw, ImageFont

MENU = r"C:\Users\Administrator\mecha-forge\game\assets\menu"
OUT = r"C:\Users\Administrator\mecha-forge\cine\_show"
os.makedirs(OUT, exist_ok=True)
W, H = 720, 1280
F = "C:/Windows/Fonts/arialbd.ttf"
FR = "C:/Windows/Fonts/arial.ttf"


def font(path, sz):
    return ImageFont.truetype(path, sz)


def covered(im, w, h):
    """Emulate Godot STRETCH_KEEP_ASPECT_COVERED: scale to cover, center-crop."""
    s = max(w / im.width, h / im.height)
    im2 = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x = (im2.width - w) // 2
    y = (im2.height - h) // 2
    return im2.crop((x, y, x + w, y + h))


def ctext(d, cx, y, txt, fnt, fill, outline=(0, 0, 0), ow=3, anchor_mid=True):
    bbox = d.textbbox((0, 0), txt, font=fnt)
    tw = bbox[2] - bbox[0]
    x = cx - tw // 2 if anchor_mid else cx
    if ow:
        for dx in range(-ow, ow + 1):
            for dy in range(-ow, ow + 1):
                d.text((x + dx, y + dy), txt, font=fnt, fill=outline)
    d.text((x, y), txt, font=fnt, fill=fill)
    return tw


# ---------- 1) CUTSCENE panel (opening story, cine4 "reveil du noyau") ----------
def mock_cutscene():
    base = Image.new("RGB", (W, H), (0, 0, 0))
    art = covered(Image.open(os.path.join(MENU, "cine4.png")).convert("RGB"), W, H)
    base.paste(art, (0, 0))
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    # caption band (bottom ~200 px), like the PanelContainer bg 0.62 alpha
    band_h = 210
    d.rectangle([0, H - band_h, W, H], fill=(5, 8, 13, 165))
    ctext(d, W // 2, H - band_h + 34, "LE REVEIL DU NOYAU", font(F, 40), (140, 235, 255), ow=4)
    ctext(d, W // 2, H - band_h + 104, "Une etincelle cyan. Le geant ouvre les yeux.",
          font(FR, 26), (225, 230, 245), ow=3)
    # PASSER button top-right
    bx0, by0, bx1, by1 = W - 190, 34, W - 30, 86
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=8, fill=(25, 30, 40, 190), outline=(120, 200, 220, 200), width=2)
    ctext(d, (bx0 + bx1) // 2, by0 + 12, "PASSER  >", font(F, 22), (220, 235, 245), ow=0)
    base = Image.alpha_composite(base.convert("RGBA"), ov).convert("RGB")
    base.save(os.path.join(OUT, "mock_cutscene.png"))
    return base


# ---------- 2) HOME menu (menu_bg + veil + emblem + title + buttons) ----------
def button(d, cx, y, w, h, label, fill, text_col=(255, 255, 255)):
    x0, x1 = cx - w // 2, cx + w // 2
    d.rounded_rectangle([x0, y, x1, y + h], radius=10, fill=fill, outline=(90, 110, 130), width=2)
    bbox = d.textbbox((0, 0), label, font=font(F, 26))
    d.text((cx - (bbox[2] - bbox[0]) // 2, y + h // 2 - 18), label, font=font(F, 26), fill=text_col)


def mock_menu():
    base = covered(Image.open(os.path.join(MENU, "menu_bg.png")).convert("RGB"), W, H).convert("RGBA")
    veil = Image.new("RGBA", (W, H), (5, 8, 13, 112))   # 0.44 alpha darken
    base = Image.alpha_composite(base, veil)
    d = ImageDraw.Draw(base)
    # emblem (keyed) near top
    em = Image.open(os.path.join(MENU, "emblem_cut.png")).convert("RGBA")
    eh = 150
    em = em.resize((round(em.width * eh / em.height), eh), Image.LANCZOS)
    base.alpha_composite(em, ((W - em.width) // 2, 40))
    d = ImageDraw.Draw(base)
    ctext(d, W // 2, 205, "MECHA-FORGE", font(F, 52), (185, 235, 255), ow=5)
    ctext(d, W // 2, 272, "Survivor-like mecha   -   v0.9", font(FR, 22), (155, 175, 205), ow=2)
    ctext(d, W // 2, 330, "1240  ferraille     8  cristaux     2  noyaux",
          font(F, 24), (150, 230, 255), ow=3)
    # a couple meta rows (as in _build_shop)
    y = 392
    for name, lvl in [("Blindage   [2/8]", "120"), ("Puissance   [1/8]", "90"), ("Recuperation   [0/6]", "60")]:
        d.rounded_rectangle([90, y, 470, y + 44], radius=6, fill=(18, 22, 30, 180))
        d.text((108, y + 10), name, font=font(FR, 22), fill=(210, 220, 235))
        button(d, 560, y, 150, 44, lvl, (34, 40, 52))
        y += 56
    # action buttons
    button(d, W // 2, 588, 380, 56, "QUOTIDIEN  (recompenses)", (28, 60, 42))
    button(d, W // 2, 654, 380, 56, "EQUIPEMENT  (pieces)", (50, 40, 72))
    button(d, W // 2, 720, 380, 56, "GARAGE  (mechs)", (30, 50, 72))
    button(d, W // 2, 800, 380, 74, "JOUER", (26, 150, 78))
    base.convert("RGB").save(os.path.join(OUT, "mock_menu.png"))
    return base.convert("RGB")


c = mock_cutscene()
m = mock_menu()
# side-by-side contact sheet
sheet = Image.new("RGB", (W * 2 + 30, H + 20), (14, 16, 20))
sheet.paste(m, (10, 10))
sheet.paste(c, (W + 20, 10))
sheet.thumbnail((1400, 1400))
sheet.save(os.path.join(OUT, "mock_ui.png"))
print("ok ->", os.path.join(OUT, "mock_ui.png"))
