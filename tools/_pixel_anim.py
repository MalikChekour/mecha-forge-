"""Animated pixel-mecha catalog: pixel-snap the detailed FLUX mechas, then give each a reliable
procedural IDLE (float + breathe + reactor glow pulse) -> looping GIF. Builds GIFs + an HTML
catalog page (served on localhost) so the mechas can be seen MOVING."""
import os, math
from PIL import Image, ImageDraw, ImageFilter

PX = r"C:\Users\Administrator\mecha-forge\cine\pixel"
OUT = r"C:\Users\Administrator\mecha-forge\cine\pixel_cat"
os.makedirs(OUT, exist_ok=True)


def snap(path, w=150, colors=44):
    im = Image.open(path).convert("RGBA")
    h = round(w * im.height / im.width)
    small = im.resize((w, h), Image.BILINEAR)
    rgb = small.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    a = small.getchannel("A").point(lambda p: 255 if p > 60 else 0)
    snapped = Image.merge("RGBA", (*rgb.split(), a))
    return snapped.resize((snapped.width * 3, snapped.height * 3), Image.NEAREST)


def animate(sprite, frames=24):
    sw, sh = sprite.size
    pad_x, pad_y = 44, 60
    cw, ch = sw + pad_x * 2, sh + pad_y * 2
    out = []
    for i in range(frames):
        t = i / frames
        bob = int(round(6 * math.sin(2 * math.pi * t)))
        sway = int(round(3 * math.sin(2 * math.pi * t + 0.7)))
        breathe = 1.0 + 0.018 * math.sin(2 * math.pi * t)
        glow_a = 0.35 + 0.35 * (0.5 + 0.5 * math.sin(2 * math.pi * t))
        canvas = Image.new("RGBA", (cw, ch), (22, 25, 33, 255))
        # pulsing cyan reactor glow behind the mech
        gl = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        gd = ImageDraw.Draw(gl)
        gr = int(sw * 0.42)
        gcx, gcy = cw // 2 + sway, ch // 2 - bob
        gd.ellipse([gcx - gr, gcy - gr, gcx + gr, gcy + gr],
                   fill=(70, 210, 240, int(120 * glow_a)))
        gl = gl.filter(ImageFilter.GaussianBlur(22))
        canvas.alpha_composite(gl)
        # breathing scale
        bw, bh = int(sw * breathe), int(sh * breathe)
        spr = sprite.resize((bw, bh), Image.NEAREST)
        px = (cw - bw) // 2 + sway
        py = (ch - bh) // 2 - bob
        canvas.alpha_composite(spr, (px, py))
        # ground shadow
        sd = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        ImageDraw.Draw(sd).ellipse([cw // 2 - sw // 3, ch - pad_y + 6, cw // 2 + sw // 3, ch - pad_y + 22],
                                   fill=(0, 0, 0, 90))
        canvas.alpha_composite(sd.filter(ImageFilter.GaussianBlur(4)))
        out.append(canvas.convert("RGB"))
    return out


NAMES = [("hi_1", "MECHA LOURD"), ("hi_2", "SCOUT (lame)"), ("hi_3", "ARTILLERIE")]
for fid, _ in NAMES:
    frames = animate(snap(os.path.join(PX, fid + ".png")))
    pal = frames[0].quantize(colors=64)
    q = [f.quantize(palette=pal) for f in frames]
    q[0].save(os.path.join(OUT, fid + ".gif"), save_all=True, append_images=q[1:],
              duration=90, loop=0, disposal=1)
    print("gif", fid)

# HTML catalog
html = """<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MECHA-FORGE - Catalogue pixel-art animé</title>
<style>:root{color-scheme:dark}body{margin:0;background:#0a0d13;color:#d5e8ee;
font-family:'Segoe UI',system-ui,sans-serif;padding:26px 18px 60px}.wrap{max-width:900px;margin:0 auto}
h1{font-size:23px;color:#eafcff;letter-spacing:1px}h1 b{color:#39dcf0}.sub{color:#6d8b93;font-size:14px;margin-bottom:20px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px}
.card{background:#0e131b;border:1px solid #1a2a38;border-radius:12px;padding:14px;text-align:center}
.card img{image-rendering:pixelated;width:100%;max-width:280px;border-radius:8px;background:#161922}
.card .n{margin-top:10px;font-weight:700;color:#8fd;font-size:16px}
.note{background:#0d1520;border:1px solid #1c3542;border-radius:8px;padding:11px 14px;font-size:13px;color:#9fbcc4;margin:16px 0}</style>
</head><body><div class="wrap">
<h1>MECHA-<b>FORGE</b> - pixel-art animé <span style="font-size:13px;color:#6d8b93">(test)</span></h1>
<p class="sub">Mechas pixel-art détaillés (FLUX haute-fidélité) + idle procédural : flottement, respiration, pulsation du cœur.</p>
<div class="note">🎞️ Les 3 mechas s'animent en boucle ci-dessous. Le rendu STILL matche la qualité Spriterrific ;
l'animation ici est un idle procédural fiable (les vrais cycles walk/attack via image→vidéo demandent un solde FAL/vidéo, actuellement épuisé).</div>
<div class="grid">
CARDS
</div></div></body></html>"""
cards = "\n".join('<div class="card"><img src="%s.gif" alt="%s"><div class="n">%s</div></div>' % (fid, n, n)
                  for fid, n in NAMES)
open(os.path.join(OUT, "index.html"), "w", encoding="utf-8").write(html.replace("CARDS", cards))
print("html ok ->", OUT)
