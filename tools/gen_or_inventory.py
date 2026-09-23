# -*- coding: utf-8 -*-
"""INVENTAIRE COMPLET par style via OpenRouter (Gemini Image) : 3 styles finalistes x plusieurs
missiles distincts -> montage par style pour choisir a fond. Fond blanc (detourage apres choix).
  python gen_or_inventory.py
"""
import os, sys, io, json, base64, urllib.request
from PIL import Image, ImageDraw

KEY = os.environ["OPENROUTER_API_KEY"]
MODEL = os.environ.get("OR_IMAGE_MODEL", "google/gemini-2.5-flash-image")
SHOW = os.path.abspath("cine/_show/inv"); os.makedirs(SHOW, exist_ok=True)

FRAME = ("strict SIDE profile, lying horizontal pointing to the RIGHT, the WHOLE missile centered "
         "with margin on a solid pure white background, no shadow; STRICTLY not an aircraft, no "
         "wings, no jet, no cockpit, no launcher, no text.")

SUBJECTS = [
    ("guided",  "a slim air-to-air guided missile, pointed seeker nose cone, small cruciform fins"),
    ("ogive",   "a heavy bunker-buster rocket, thick body, blunt rounded warhead nose, stubby tail fins, brass band"),
    ("rpg",     "an RPG-7 rocket grenade, bulbous pointed warhead on a thin stem, small tail fins"),
    ("mecha",   "a sci-fi mech rocket, armored body, glowing hot warhead tip and glowing thruster nozzle, angular fins"),
    ("croisiere","a cruise missile, long smooth body, rounded nose, short folded body fins, tail nozzle"),
]
STYLES = {
    "realiste": "Photorealistic detailed 3D render, brushed gunmetal metal, dramatic studio lighting, sharp.",
    "neon":     "Sleek stylized premium mobile-game art, dark gunmetal body with glowing neon-orange "
                "energy accents and a hot glowing tip, clean rim light.",
    "lowpoly":  "Stylized low-poly 3D render, clearly faceted flat-shaded triangular surfaces, clean minimal game asset.",
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

for sname, sp in STYLES.items():
    tiles = []
    for key, subj in SUBJECTS:
        try:
            png = call("A %s. Style: %s %s" % (subj, sp, FRAME))
            if not png: print("NOIMG", sname, key); continue
            im = Image.open(io.BytesIO(png)).convert("RGB").resize((230, 230))
            im.save(os.path.join(SHOW, "%s_%s.png" % (sname, key))); tiles.append((key, im)); print("GEN", sname, key, flush=True)
        except Exception as e:
            print("FAIL", sname, key, e, flush=True)
    if tiles:
        m = Image.new("RGB", (len(tiles) * 240 + 20, 275), (22, 24, 30)); d = ImageDraw.Draw(m)
        d.text((10, 6), "STYLE : %s" % sname.upper(), fill=(255, 220, 150))
        for i, (key, im) in enumerate(tiles):
            m.paste(im, (i * 240 + 10, 30)); d.text((i * 240 + 12, 262 - 260), "", fill=(0, 0, 0))
            d.text((i * 240 + 12, 262), key, fill=(210, 210, 220))
        m.save(os.path.join("cine/_show", "inv_%s.png" % sname)); print("MONTAGE", sname, flush=True)
print("DONE")
