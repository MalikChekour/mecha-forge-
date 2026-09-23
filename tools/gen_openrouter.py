# -*- coding: utf-8 -*-
"""Genere des MISSILES via OpenRouter (modele image, ex. Gemini 2.5 Flash Image / Nano Banana),
detoure (rembg) + oriente -> candidats. Cle = env OPENROUTER_API_KEY.
  python gen_openrouter.py test                 # 1 appel, dump structure reponse
  python gen_openrouter.py <type> [n]           # genere un type
  python gen_openrouter.py all [n]              # tous les types
"""
import os, sys, io, json, math, base64, urllib.request
import numpy as np
from PIL import Image, ImageDraw

KEY = os.environ["OPENROUTER_API_KEY"]
MODEL = os.environ.get("OR_IMAGE_MODEL", "google/gemini-2.5-flash-image")
SHOW = os.path.abspath("cine/_show/or_gen"); os.makedirs(SHOW, exist_ok=True)

FRAME = ("Single object, the WHOLE missile fully visible and centered with margin, strict SIDE "
         "profile view, lying perfectly horizontal pointing to the RIGHT, on a solid pure white "
         "background with no shadow, even studio lighting, sharp high detail, square image. "
         "STRICTLY not an aircraft, not a jet, no wings, no cockpit, no launcher, no smoke, no text.")
TYPES = {
    "guided":  "A photorealistic 3D render of one slim air-to-air guided missile, gunmetal and white "
               "body, pointed seeker nose cone, small cruciform fins. " + FRAME,
    "warhead": "A photorealistic 3D render of one heavy bunker-buster rocket, thick olive-drab body, "
               "blunt rounded high-explosive warhead nose, short stubby tail fins, brass band. " + FRAME,
    "rpg":     "A photorealistic 3D render of one RPG-7 rocket-propelled grenade, bulbous pointed olive "
               "warhead on a thin dark stem, small stabiliser fins at the tail. " + FRAME,
    "mecha":   "A photorealistic 3D render of one sci-fi mech rocket, dark gunmetal armored body, glowing "
               "hot orange-red warhead tip, glowing orange thruster nozzle, angular fins. " + FRAME,
}

def call(prompt):
    body = json.dumps({"model": MODEL, "messages": [{"role": "user", "content": prompt}],
                       "modalities": ["image", "text"]}).encode()
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", data=body,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json",
                 "HTTP-Referer": "https://mecha-forge.local", "X-Title": "mecha-forge"})
    return json.loads(urllib.request.urlopen(req, timeout=180).read())

def extract_png(resp):
    msg = resp["choices"][0]["message"]
    imgs = msg.get("images") or []
    if imgs:
        url = imgs[0]["image_url"]["url"] if isinstance(imgs[0], dict) else imgs[0]
        b64 = url.split(",", 1)[1] if "," in url else url
        return base64.b64decode(b64)
    return None

def orient(im):
    a = np.array(im)[:, :, 3].astype(float); ys, xs = np.nonzero(a > 40)
    if len(xs) < 10: return im
    xs = xs.astype(float); ys = ys.astype(float)
    cov = np.cov(np.stack([xs - xs.mean(), ys - ys.mean()])); w, v = np.linalg.eigh(cov)
    ax = v[:, int(np.argmax(w))]
    out = im.rotate(-math.degrees(math.atan2(ax[1], ax[0])), resample=Image.BICUBIC, expand=True)
    ob = out.getbbox()
    if ob and (ob[3] - ob[1]) > (ob[2] - ob[0]): out = out.rotate(90, resample=Image.BICUBIC, expand=True)
    # NEZ (bout le plus ETROIT = pointe du missile) -> a DROITE (sens de vol)
    al = np.array(out)[:, :, 3]
    cols = np.nonzero(al.max(axis=0) > 40)[0]
    if len(cols) > 8:
        x0, x1 = cols[0], cols[-1]; band = max(3, (x1 - x0) // 5)
        left_h = (al[:, x0:x0 + band] > 40).sum(axis=0).mean()
        right_h = (al[:, x1 - band:x1] > 40).sum(axis=0).mean()
        if left_h < right_h:                 # bout etroit a gauche -> flip pour le mettre a droite
            out = out.transpose(Image.FLIP_LEFT_RIGHT)
    bb = out.getbbox()
    if bb: out = out.crop(bb)
    sq = max(out.size); cv = Image.new("RGBA", (sq, sq), (0, 0, 0, 0))
    cv.alpha_composite(out, ((sq - out.width) // 2, (sq - out.height) // 2))
    return cv.resize((128, 128), Image.LANCZOS)

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "test"
    if arg == "test":
        r = call(TYPES["mecha"])
        png = extract_png(r)
        if png:
            open(os.path.join(SHOW, "test_raw.png"), "wb").write(png)
            print("OK image bytes:", len(png))
        else:
            print("NO IMAGE. keys:", list(r.get("choices", [{}])[0].get("message", {}).keys()))
            print(json.dumps(r)[:800])
    else:
        from rembg import remove
        kinds = list(TYPES) if arg == "all" else [arg]
        N = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        for kind in kinds:
            tiles = []
            for s in range(N):
                try:
                    png = extract_png(call(TYPES[kind]))
                    if not png: print("NOIMG", kind, s); continue
                    im = orient(remove(Image.open(io.BytesIO(png)).convert("RGBA")))
                    im.save(os.path.join(SHOW, "%s_%d.png" % (kind, s))); tiles.append(im); print("GEN", kind, s, flush=True)
                except Exception as e:
                    print("FAIL", kind, s, e, flush=True)
            if tiles:
                m = Image.new("RGB", (len(tiles) * 150 + 20, 175), (22, 24, 30)); d = ImageDraw.Draw(m)
                for i, im in enumerate(tiles):
                    bg = Image.new("RGBA", (140, 140), (30, 32, 40, 255)); bg.alpha_composite(im, (6, 6))
                    m.paste(bg.convert("RGB"), (i * 150 + 10, 28)); d.text((i * 150 + 12, 8), "%s %d" % (kind, i), fill=(230, 230, 240))
                m.save("cine/_show/orgen_%s.png" % kind); print("MONTAGE", kind)
        print("DONE")
