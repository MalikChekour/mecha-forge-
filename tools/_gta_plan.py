"""GTA 8-direction plan catalog for the MECHA LOURD (hi_1): pull directional views from the Kling
turntable (+ mirror for the left side), pixel-snap them, lay them on a compass, and spell out the
full animation matrix (idle / walk / run / FIRE x 8 directions). Confirms the plan before building."""
import glob, os
from PIL import Image, ImageDraw, ImageFont

TT = sorted(glob.glob(r"C:\Users\Administrator\mecha-forge\cine\pixel\tt\t_*.png"))
OUT = r"C:\Users\Administrator\mecha-forge\cine\_show\gta_plan.png"
FB = "C:/Windows/Fonts/arialbd.ttf"
FR = "C:/Windows/Fonts/arial.ttf"


def f(p, s):
    return ImageFont.truetype(p, s)


def snap(im, w=118, colors=44):
    im = im.convert("RGBA")
    # autocrop to content
    bb = im.getbbox()
    if bb:
        im = im.crop(bb)
    h = round(w * im.height / im.width)
    s = im.resize((w, h), Image.BILINEAR)
    rgb = s.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    o = Image.merge("RGBA", (*rgb.split(), s.getchannel("A")))
    return o.resize((o.width * 2, o.height * 2), Image.NEAREST)


def load(idx, mirror=False):
    im = Image.open(TT[min(idx, len(TT) - 1)]).convert("RGBA")
    # crop to a centered square around the mech (video is 1:1 already)
    if mirror:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return snap(im)


# turntable maps roughly front -> right -> back over the clip; mirror gives the left side
VIEWS = {
    "face":       load(0),
    "face_droite": load(7),
    "droite":     load(14),
    "dos_droite": load(25),
    "dos":        load(38),
    "dos_gauche": load(25, mirror=True),
    "gauche":     load(14, mirror=True),
    "face_gauche": load(7, mirror=True),
}
LABELS = {"face": "FACE", "dos": "DOS", "gauche": "GAUCHE", "droite": "DROITE",
          "face_droite": "FACE-DROITE", "face_gauche": "FACE-GAUCHE",
          "dos_droite": "DOS-DROITE", "dos_gauche": "DOS-GAUCHE"}
# compass 3x3 (top = dos / away, bottom = face / toward viewer)
GRID = [["dos_gauche", "dos", "dos_droite"],
        ["gauche", None, "droite"],
        ["face_gauche", "face", "face_droite"]]

W, H = 1180, 940
sheet = Image.new("RGB", (W, H), (14, 16, 22))
d = ImageDraw.Draw(sheet)
d.text((22, 16), "PLAN — MECHA LOURD en 8 directions (GTA) + TIR", font=f(FB, 30), fill=(200, 230, 245))
d.text((22, 56), "Vues extraites du turntable Kling (+ miroir pour la gauche). Meme design, meme taille.",
       font=f(FR, 16), fill=(150, 165, 185))

# --- compass ---
cell = 210
gx, gy = 40, 100
for r in range(3):
    for c in range(3):
        x, y = gx + c * cell, gy + r * cell
        key = GRID[r][c]
        d.rounded_rectangle([x, y, x + cell - 12, y + cell - 12], radius=10,
                            fill=(22, 25, 33), outline=(40, 70, 84), width=2)
        if key is None:
            # center: compass rose + move/aim note
            cx, cy = x + (cell - 12) // 2, y + (cell - 12) // 2
            for ang, lab in [(-90, "N"), (90, "S"), (0, "E"), (180, "O")]:
                import math
                dx, dy = math.cos(math.radians(ang)), math.sin(math.radians(ang))
                d.line([cx, cy, cx + dx * 70, cy + dy * 70], fill=(90, 200, 220), width=3)
            d.text((cx - 44, cy - 8), "8 dirs", font=f(FB, 20), fill=(120, 235, 255))
            continue
        im = VIEWS[key]
        spr = im if im.height <= cell - 44 else im.resize((int(im.width * (cell - 44) / im.height), cell - 44), Image.NEAREST)
        sheet.paste(spr.convert("RGB"), (x + (cell - 12 - spr.width) // 2, y + 6), spr)
        d.text((x + 8, y + cell - 34), LABELS[key], font=f(FB, 15), fill=(140, 220, 235))

# --- animation matrix (right side) ---
mx = 690
d.text((mx, 100), "ANIMATIONS  x  8 directions", font=f(FB, 22), fill=(120, 235, 160))
anims = [("IDLE", "immobile"), ("MARCHE", "8 dir"), ("COURSE", "8 dir"),
         ("TIR / VISER", "8 dir — dans la direction du curseur"), ("TOUCHE", "flash"), ("MORT", "1x")]
yy = 140
for name, note in anims:
    d.rounded_rectangle([mx, yy, mx + 450, yy + 44], radius=8, fill=(18, 22, 30), outline=(40, 70, 84), width=2)
    col = (120, 235, 255) if "TIR" in name else (200, 230, 245)
    d.text((mx + 14, yy + 8), name, font=f(FB, 20), fill=col)
    d.text((mx + 200, yy + 12), note, font=f(FR, 15), fill=(150, 175, 195))
    yy += 54

# --- GTA note ---
ny = yy + 16
d.rounded_rectangle([mx, ny, mx + 450, ny + 150], radius=10, fill=(13, 21, 32), outline=(28, 53, 66), width=2)
note = ("PRINCIPE GTA (twin-stick) :\n"
        "- le CORPS s'oriente selon le deplacement (8 dir)\n"
        "- le TIR vise la direction de la cible/curseur\n"
        "  -> pose de tir dans les 8 directions,\n"
        "  independante du sens de marche.\n\n"
        "PIPELINE : FLUX (design) -> turntable Kling\n"
        "(8 vues) -> anim i2v par vue -> spritesheets.")
d.multiline_text((mx + 14, ny + 12), note, font=f(FR, 15), fill=(190, 205, 220), spacing=5)

sheet.save(OUT)
print("ok", OUT)
