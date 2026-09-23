"""Decor function-status catalogue: every DECOR kind, its art, and whether it has a SPECIAL
function yet. Sorted so the 'no function' ones (candidates) come first."""
import os
from PIL import Image, ImageDraw, ImageFont

DEC = r"C:\Users\Administrator\mecha-forge\game\assets\decor"
OUT = r"C:\Users\Administrator\mecha-forge\cine\_show\decor_catalog.png"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
FB = "C:/Windows/Fonts/arialbd.ttf"
FR = "C:/Windows/Fonts/arial.ttf"

# (kind, art, status, note)
DATA = [
    ("lave",       "g35", "NONE",  "deco seule - DEVRAIT bruler"),
    ("cristaux",   "g30", "NONE",  "glow cyan - rien"),
    ("plante",     "g32", "NONE",  "glow vert - rien"),
    ("glace",      "g33", "NONE",  "rien (gel ?)"),
    ("racines",    "g36", "NONE",  "glow vert - rien (agripper ?)"),
    ("emetteur",   "g25", "NONE",  "glow cyan - rien"),
    ("epave",      "g26", "NONE",  "destructible - pourrait se reveiller"),
    ("arbre",      "g31", "BLOCK", "bloque (terrain)"),
    ("rocher",     "g29", "BLOCK", "bloque / crete"),
    ("arche",      "g34", "BLOCK", "bloque (structure)"),
    ("caisses",    "g21", "LOOT",  "caisse a competence"),
    ("container",  "g28", "LOOT",  "conteneur a loot"),
    ("baril",      "g20", "ACTIVE","PIEGE explosif"),
    ("generateur", "g22", "ACTIVE","PYLONE : foudre + EMP"),
    ("antenne",    "g23", "ACTIVE","NID : spawn ennemis"),
    ("conduit",    "g24", "ACTIVE","CHAMP ralentisseur"),
    ("tourelle",   "g27", "ACTIVE","TOURELLE : tire"),
    ("capaciteur", "g25", "ACTIVE","CANON a rayon"),
]
STATUS = {
    "NONE":  ((255, 90, 70),  "SANS FONCTION"),
    "BLOCK": ((120, 150, 190),"BLOQUE (terrain)"),
    "LOOT":  ((240, 195, 80), "LOOT"),
    "ACTIVE":((90, 230, 150), "FONCTION ACTIVE"),
}

CW, CH, pad = 250, 250, 10
cols = 4
rows = (len(DATA) + cols - 1) // cols
top = 70
W = cols * CW + pad * (cols + 1)
H = top + rows * (CH + pad) + pad
sheet = Image.new("RGB", (W, H), (14, 16, 21))
d = ImageDraw.Draw(sheet)


def fnt(p, s):
    return ImageFont.truetype(p, s)


d.text((pad + 6, 16), "CATALOGUE DECOR — fonctions", font=fnt(FB, 30), fill=(200, 230, 245))
d.text((pad + 6, 50), "rouge = sans fonction speciale (a decider)   ·   vert = deja actif",
       font=fnt(FR, 16), fill=(150, 165, 185))

for i, (kind, art, st, note) in enumerate(DATA):
    c, r = i % cols, i // cols
    x, y = pad + c * (CW + pad), top + r * (CH + pad)
    col, lbl = STATUS[st]
    # cell bg + status border
    d.rounded_rectangle([x, y, x + CW, y + CH], radius=10, fill=(22, 25, 32), outline=col, width=3)
    # art thumb
    try:
        im = Image.open(os.path.join(DEC, art + ".png")).convert("RGBA")
        im.thumbnail((CW - 40, CH - 96))
        cell = Image.new("RGBA", (CW, CH - 90), (0, 0, 0, 0))
        cell.alpha_composite(im, ((CW - im.width) // 2, (CH - 90 - im.height) // 2))
        sheet.paste(Image.alpha_composite(Image.new("RGBA", cell.size, (22, 25, 32, 255)), cell).convert("RGB"),
                    (x, y + 4))
    except Exception as e:
        d.text((x + 10, y + 40), "?" + str(e)[:20], font=fnt(FR, 12), fill=(255, 80, 80))
    # name + status chip + note
    d.text((x + 12, y + CH - 82), "%s  (%s)" % (kind, art), font=fnt(FB, 20), fill=(230, 238, 248))
    d.rounded_rectangle([x + 12, y + CH - 54, x + 12 + 150, y + CH - 30], radius=6, fill=col)
    d.text((x + 20, y + CH - 52), lbl, font=fnt(FB, 13), fill=(15, 18, 22))
    d.text((x + 12, y + CH - 24), note, font=fnt(FR, 14), fill=(180, 192, 208))

sheet.save(OUT)
print("ok ->", OUT, sheet.size)
