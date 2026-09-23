"""Directional animated pixel-mecha catalog (the decisive test): pixel-snap the EXISTING 3D-rendered
mech (george) animations -> walk / run / attack(aim) in front/back/left/right. Reliable + free.
This proves whether the 3D->pixel pipeline gives clean directional animations."""
import os
from PIL import Image, ImageDraw, ImageFilter

MECHA = r"C:\Users\Administrator\mecha-forge\game\assets\mecha"
OUT = r"C:\Users\Administrator\mecha-forge\cine\pixel_dirs"
os.makedirs(OUT, exist_ok=True)
FW = 192   # george frame width
ACTIONS = [("walk", "MARCHE"), ("run", "COURSE"), ("attack", "VISER / TIR")]
DIRS = [("front", "face"), ("back", "dos"), ("left", "gauche"), ("right", "droite")]


def snap_frame(im, w=124, colors=44):
    im = im.convert("RGBA")
    h = round(w * im.height / im.width)
    small = im.resize((w, h), Image.BILINEAR)
    rgb = small.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    a = small.getchannel("A").point(lambda p: 255 if p > 60 else 0)
    s = Image.merge("RGBA", (*rgb.split(), a))
    return s.resize((s.width * 2, s.height * 2), Image.NEAREST)


def frames_of(path):
    im = Image.open(path).convert("RGBA")
    n = max(1, im.width // FW)
    return [snap_frame(im.crop((i * FW, 0, (i + 1) * FW, im.height))) for i in range(n)]


def make_gif(frames, out, dur=100):
    sw, sh = frames[0].size
    pad = 24
    cw, ch = sw + pad * 2, sh + pad + 16
    comp = []
    for fr in frames:
        c = Image.new("RGBA", (cw, ch), (24, 27, 35, 255))
        # ground shadow
        sd = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        ImageDraw.Draw(sd).ellipse([cw // 2 - sw // 3, ch - 22, cw // 2 + sw // 3, ch - 8], fill=(0, 0, 0, 110))
        c.alpha_composite(sd.filter(ImageFilter.GaussianBlur(3)))
        c.alpha_composite(fr, (pad, 8))
        comp.append(c.convert("RGB"))
    pal = comp[0].quantize(colors=48)
    q = [im.quantize(palette=pal) for im in comp]
    q[0].save(out, save_all=True, append_images=q[1:], duration=dur, loop=0, disposal=1)


for act, _ in ACTIONS:
    for d, _ in DIRS:
        src = os.path.join(MECHA, "george_%s_%s.png" % (act, d))
        if not os.path.exists(src):
            print("skip", src); continue
        make_gif(frames_of(src), os.path.join(OUT, "%s_%s.gif" % (act, d)),
                 dur=80 if act == "run" else 100)
    print("done", act)

# HTML catalog grouped by action, 4 directions each
rows = ""
for act, alab in ACTIONS:
    cells = "".join(
        '<div class="c"><img src="%s_%s.gif"><div class="d">%s</div></div>' % (act, d, dlab)
        for d, dlab in DIRS)
    rows += '<h2>%s</h2><div class="row">%s</div>' % (alab, cells)
html = """<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Pixel-mecha - animations directionnelles</title>
<style>:root{color-scheme:dark}body{margin:0;background:#0a0d13;color:#d5e8ee;font-family:'Segoe UI',system-ui,sans-serif;padding:24px 16px 60px}
.wrap{max-width:1000px;margin:0 auto}h1{font-size:22px;color:#eafcff}h1 b{color:#39dcf0}
h2{color:#39dcf0;font-size:17px;margin:22px 0 8px;border-bottom:1px solid #1a2a38;padding-bottom:4px}
.row{display:flex;gap:14px;flex-wrap:wrap}.c{background:#0e131b;border:1px solid #1a2a38;border-radius:10px;padding:10px;text-align:center}
.c img{image-rendering:pixelated;width:200px;background:#181c24;border-radius:6px}.c .d{margin-top:6px;color:#8fd;font-weight:600;font-size:14px}
.note{background:#0d1520;border:1px solid #1c3542;border-radius:8px;padding:11px 14px;font-size:13px;color:#9fbcc4;margin:14px 0}</style>
</head><body><div class="wrap"><h1>Pixel-mecha - <b>animations directionnelles</b> (test 3D->pixel)</h1>
<div class="note">Le mecha 3D existant (george) rendu en 4 directions x walk/run/attack, puis pixellisé (léger).
C'est la voie FIABLE et GRATUITE pour de vraies anims directionnelles. Design = george (pas les jolis mechas FLUX) :
pour animer un design FLUX pareil, il faut le passer en 3D (Meshy) - solde a recharger.</div>
ROWS</div></body></html>"""
open(os.path.join(OUT, "index.html"), "w", encoding="utf-8").write(html.replace("ROWS", rows))
print("html ok ->", OUT)
