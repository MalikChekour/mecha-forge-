"""Varied procedural animations on the 3 FLUX pixel-mechas (front view): idle / march / run / aim-fire
/ hit. A 2D puppet-ish rig (bob, tilt-rock, lean, leg-band shear, muzzle flash, recoil, flash+shake).
Free, real motion — not a true 4-dir walk cycle (that needs the funded video/3D pipeline)."""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageEnhance

PX = r"C:\Users\Administrator\mecha-forge\cine\pixel"
OUT = r"C:\Users\Administrator\mecha-forge\cine\pixel_moves"
os.makedirs(OUT, exist_ok=True)
random.seed(7)
MECHS = [("hi_1", "MECHA LOURD"), ("hi_2", "SCOUT"), ("hi_3", "ARTILLERIE")]
ANIMS = ["idle", "marche", "course", "tir", "hit"]


def snap(path, w=150, colors=46):
    im = Image.open(path).convert("RGBA")
    h = round(w * im.height / im.width)
    s = im.resize((w, h), Image.BILINEAR)
    rgb = s.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    a = s.getchannel("A").point(lambda p: 255 if p > 60 else 0)
    o = Image.merge("RGBA", (*rgb.split(), a))
    return o.resize((o.width * 3, o.height * 3), Image.NEAREST)


def leg_shear(spr, amt):
    """Shear the lower half horizontally to fake a step (amt px at the very bottom)."""
    w, h = spr.size
    top = spr.crop((0, 0, w, int(h * 0.55)))
    legs = spr.crop((0, int(h * 0.55), w, h))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(top, (0, 0))
    lh = legs.height
    sheared = Image.new("RGBA", (w, lh), (0, 0, 0, 0))
    for yy in range(lh):
        dx = int(amt * (yy / max(1, lh - 1)))
        sheared.alpha_composite(legs.crop((0, yy, w, yy + 1)), (dx, yy))
    out.alpha_composite(sheared, (0, int(h * 0.55)))
    return out


def glow(canvas, cx, cy, r, col, a):
    g = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([cx - r, cy - r, cx + r, cy + r], fill=(col[0], col[1], col[2], int(a)))
    canvas.alpha_composite(g.filter(ImageFilter.GaussianBlur(20)))


def frame(spr, mode, i, n):
    sw, sh = spr.size
    padx, padyt, padyb = 70, 70, 26
    cw, ch = sw + padx * 2, sh + padyt + padyb
    t = i / n
    ph = 2 * math.pi * t
    c = Image.new("RGBA", (cw, ch), (24, 27, 35, 255))
    bob = 0; sway = 0; tilt = 0.0; lean = 0; shear = 0; scale = 1.0
    flash = 0.0; shake = (0, 0); muzzle = None; tint = None
    if mode == "idle":
        bob = int(4 * math.sin(ph)); scale = 1.0 + 0.015 * math.sin(ph)
    elif mode == "marche":
        bob = int(6 * abs(math.sin(ph))); tilt = 4 * math.sin(ph); shear = int(10 * math.sin(ph))
    elif mode == "course":
        bob = int(5 * abs(math.sin(2 * ph))); tilt = 8; lean = 8; shear = int(16 * math.sin(2 * ph))
    elif mode == "tir":
        # aim right + recoil kick on the beat + muzzle flash
        k = math.sin(ph) ** 6
        lean = int(6 - 10 * k); tilt = 2
        if k > 0.5:
            muzzle = (padx + int(sw * 0.92) - int(14 * k), padyt + int(sh * 0.42))
    elif mode == "hit":
        flash = max(0.0, 1.0 - t * 3.0); s = int(6 * flash)
        shake = (random.randint(-s, s), random.randint(-s, s)); tint = (1.6, 0.5, 0.5)
    # reactor glow
    glow(c, cw // 2 + sway, ch // 2 - bob - 20, int(sw * 0.4), (70, 210, 240), 90 + 40 * math.sin(ph))
    if mode == "course":  # speed streaks
        d = ImageDraw.Draw(c)
        for yy in range(80, ch - 60, 26):
            d.line([(20, yy), (60 + random.randint(0, 30), yy)], fill=(120, 200, 230, 120), width=2)
    s2 = spr
    if shear:
        s2 = leg_shear(s2, shear)
    if scale != 1.0:
        s2 = s2.resize((int(sw * scale), int(sh * scale)), Image.NEAREST)
    if tilt or lean:
        s2 = s2.rotate(-tilt, resample=Image.NEAREST, expand=False)
    if tint:
        r, gg, b, aa = s2.split()
        s2 = Image.merge("RGBA", (r.point(lambda p: min(255, int(p * tint[0]))),
                                  gg.point(lambda p: int(p * tint[1])),
                                  b.point(lambda p: int(p * tint[2])), aa))
    px = (cw - s2.width) // 2 + sway + lean + shake[0]
    py = padyt + (sh - s2.height) // 2 - bob + shake[1]
    c.alpha_composite(s2, (px, py))
    if muzzle:
        mg = Image.new("RGBA", c.size, (0, 0, 0, 0))
        md = ImageDraw.Draw(mg)
        md.ellipse([muzzle[0] - 26, muzzle[1] - 14, muzzle[0] + 26, muzzle[1] + 14], fill=(255, 230, 150, 230))
        md.ellipse([muzzle[0] - 12, muzzle[1] - 7, muzzle[0] + 40, muzzle[1] + 7], fill=(255, 180, 90, 200))
        c.alpha_composite(mg.filter(ImageFilter.GaussianBlur(2)))
    if flash > 0.02:
        fl = Image.new("RGBA", c.size, (255, 255, 255, int(150 * flash)))
        c.alpha_composite(fl)
    return c.convert("RGB")


for mid, _ in MECHS:
    spr = snap(os.path.join(PX, mid + ".png"))
    for mode in ANIMS:
        n = 16 if mode in ("idle", "tir", "hit") else 14
        frames = [frame(spr, mode, i, n) for i in range(n)]
        pal = frames[0].quantize(colors=64)
        q = [f.quantize(palette=pal) for f in frames]
        dur = {"idle": 95, "marche": 90, "course": 55, "tir": 80, "hit": 70}[mode]
        q[0].save(os.path.join(OUT, "%s_%s.gif" % (mid, mode)), save_all=True,
                  append_images=q[1:], duration=dur, loop=0, disposal=1)
    print("done", mid)

# HTML
rows = ""
lab = {"idle": "IDLE", "marche": "MARCHE", "course": "COURSE", "tir": "VISER / TIR", "hit": "TOUCHÉ"}
for mid, name in MECHS:
    cells = "".join('<div class="c"><img src="%s_%s.gif"><div class="d">%s</div></div>' % (mid, m, lab[m])
                    for m in ANIMS)
    rows += '<h2>%s</h2><div class="row">%s</div>' % (name, cells)
html = """<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Mechas FLUX - animations</title>
<style>:root{color-scheme:dark}body{margin:0;background:#0a0d13;color:#d5e8ee;font-family:'Segoe UI',system-ui,sans-serif;padding:24px 16px 60px}
.wrap{max-width:1050px;margin:0 auto}h1{font-size:22px;color:#eafcff}h1 b{color:#39dcf0}
h2{color:#39dcf0;font-size:18px;margin:22px 0 8px;border-bottom:1px solid #1a2a38;padding-bottom:4px}
.row{display:flex;gap:14px;flex-wrap:wrap}.c{background:#0e131b;border:1px solid #1a2a38;border-radius:10px;padding:10px;text-align:center}
.c img{image-rendering:pixelated;width:190px;background:#181c24;border-radius:6px}.c .d{margin-top:6px;color:#8fd;font-weight:600;font-size:13px}
.note{background:#0d1520;border:1px solid #1c3542;border-radius:8px;padding:11px 14px;font-size:13px;color:#9fbcc4;margin:14px 0}</style>
</head><body><div class="wrap"><h1>Mechas FLUX - <b>animations variées</b> (procédural 2D)</h1>
<div class="note">Idle / marche / course / viser-tir / touché, sur les 3 mechas FLUX (vue de face). 100% procédural (gratuit),
c'est un rig 2D marionnette — pas un vrai cycle 4-directions. Pour du walk/run propre en face/dos/côté animé image-par-image,
il faut la chaîne image→vidéo (FAL/Spriterrific) ou 3D (Meshy), soldes à recharger.</div>
ROWS</div></body></html>"""
open(os.path.join(OUT, "index.html"), "w", encoding="utf-8").write(html.replace("ROWS", rows))
print("html ok ->", OUT)
