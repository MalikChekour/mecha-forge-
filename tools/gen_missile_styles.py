# -*- coding: utf-8 -*-
"""Exploration de STYLES de dessin de missiles (facon Redbubble) via Pollinations FLUX :
plusieurs styles x plusieurs images. Montage PAR STYLE -> le patron choisit le style.
Pas de detourage ici (on juge le STYLE ; detourage apres validation).
  python gen_missile_styles.py [n_par_style]
"""
import urllib.request, urllib.parse, os, sys, io
from PIL import Image, ImageDraw

SHOW = os.path.abspath("cine/_show/style_gen"); os.makedirs(SHOW, exist_ok=True)
N = int(sys.argv[1]) if len(sys.argv) > 1 else 3

SUBJECT = ("a single military missile rocket, side view, lying horizontal pointing to the right, "
           "cylindrical body with a pointed nose cone and small tail fins, centered, whole missile "
           "visible, isolated on a plain flat background, NOT an aircraft, no wings, no jet, no text")

STYLES = {
    "1_realiste":  "photorealistic detailed 3D render, brushed metal, studio product lighting, sharp",
    "2_flat_icon": "flat vector icon, clean minimal flat design, bold simple shapes, solid colors, "
                   "thick even lines, mobile game UI icon, sticker style",
    "3_pixel":     "16-bit pixel art sprite, crisp blocky pixels, limited retro palette, "
                   "clean readable, arcade game asset",
    "4_cartoon":   "bold cartoon style, thick black outlines, cel shaded, vibrant saturated colors, "
                   "playful mobile game art",
    "5_lowpoly":   "stylized low-poly 3D render, faceted flat-shaded surfaces, clean game asset, "
                   "soft ambient light",
    "6_concept":   "digital painting concept art, painterly brush, dramatic rim light, gritty "
                   "sci-fi military, artstation",
}

def gen(style_prompt, seed):
    p = "%s, %s" % (SUBJECT, style_prompt)
    u = ("https://image.pollinations.ai/prompt/" + urllib.parse.quote(p)
         + "?width=640&height=640&nologo=true&model=flux&seed=%s" % seed)
    raw = urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"}), timeout=200).read()
    return Image.open(io.BytesIO(raw)).convert("RGB").resize((240, 240))

for name, sp in STYLES.items():
    tiles = []
    for s in range(N):
        seed = 300 + s * 13
        try:
            tiles.append(gen(sp, seed)); print("GEN", name, seed, flush=True)
        except Exception as e:
            print("FAIL", name, seed, e, flush=True)
    if tiles:
        m = Image.new("RGB", (len(tiles) * 250 + 20, 280), (22, 24, 30)); d = ImageDraw.Draw(m)
        for i, im in enumerate(tiles):
            m.paste(im, (i * 250 + 10, 30)); d.text((i * 250 + 12, 8), "%s  v%d" % (name, i), fill=(232, 232, 242))
        m.save(os.path.join("cine/_show", "styles_%s.png" % name)); print("MONTAGE", name, flush=True)
print("DONE")
