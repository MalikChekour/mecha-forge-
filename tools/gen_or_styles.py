# -*- coding: utf-8 -*-
"""Exploration de STYLES de dessin de missiles via OpenRouter (Gemini Image, qui RESPECTE les
styles, contrairement a Pollinations qui ne fait que des jets). Plusieurs styles x plusieurs
images. Montage par style -> le patron choisit le style.
  python gen_or_styles.py [n_par_style]
"""
import os, sys, io, json, base64, urllib.request
from PIL import Image, ImageDraw

KEY = os.environ["OPENROUTER_API_KEY"]
MODEL = os.environ.get("OR_IMAGE_MODEL", "google/gemini-2.5-flash-image")
SHOW = os.path.abspath("cine/_show/style_or"); os.makedirs(SHOW, exist_ok=True)
N = int(sys.argv[1]) if len(sys.argv) > 1 else 2

SUBJECT = ("one sci-fi military missile rocket, strict side profile, lying horizontal pointing to the "
           "right, cylindrical armored body, pointed warhead nose, small tail fins, glowing hot tip; "
           "the WHOLE missile centered with margin on a solid pure white background; "
           "STRICTLY not an aircraft, no wings, no jet, no cockpit, no launcher, no text.")

STYLES = {
    "1_realiste":  "Photorealistic detailed 3D render, brushed gunmetal, dramatic studio lighting.",
    "2_flat_icon": "Flat vector icon illustration, clean minimal flat design, bold simple shapes, "
                   "solid flat colors, thick clean outlines, mobile game UI icon, sticker look.",
    "3_pixel":     "Crisp 16-bit pixel-art sprite, blocky pixels, limited retro palette, clean arcade "
                   "game asset, hard edges.",
    "4_cartoon":   "Bold cartoon style, thick black outlines, cel-shaded flat shadows, vibrant "
                   "saturated colors, playful mobile game art.",
    "5_lowpoly":   "Stylized low-poly 3D render, clearly faceted flat-shaded triangular surfaces, "
                   "clean minimal game asset.",
    "6_neon":      "Sleek stylized game art, dark gunmetal with glowing neon-orange energy accents, "
                   "clean rim light, premium mobile game asset look.",
}

def call(prompt):
    body = json.dumps({"model": MODEL, "messages": [{"role": "user", "content": prompt}],
                       "modalities": ["image", "text"]}).encode()
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", data=body,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json",
                 "HTTP-Referer": "https://mecha-forge.local", "X-Title": "mecha-forge"})
    r = json.loads(urllib.request.urlopen(req, timeout=180).read())
    imgs = r["choices"][0]["message"].get("images") or []
    if not imgs: return None
    url = imgs[0]["image_url"]["url"] if isinstance(imgs[0], dict) else imgs[0]
    return base64.b64decode(url.split(",", 1)[1] if "," in url else url)

for name, sp in STYLES.items():
    tiles = []
    for s in range(N):
        try:
            png = call("%s Style: %s" % (SUBJECT, sp))
            if not png: print("NOIMG", name, s); continue
            im = Image.open(io.BytesIO(png)).convert("RGB").resize((240, 240))
            im.save(os.path.join(SHOW, "%s_%d.png" % (name, s))); tiles.append(im); print("GEN", name, s, flush=True)
        except Exception as e:
            print("FAIL", name, s, e, flush=True)
    if tiles:
        m = Image.new("RGB", (len(tiles) * 250 + 20, 280), (22, 24, 30)); d = ImageDraw.Draw(m)
        for i, im in enumerate(tiles):
            m.paste(im, (i * 250 + 10, 30)); d.text((i * 250 + 12, 8), "%s  v%d" % (name, i), fill=(232, 232, 242))
        m.save(os.path.join("cine/_show", "stor_%s.png" % name)); print("MONTAGE", name, flush=True)
print("DONE")
