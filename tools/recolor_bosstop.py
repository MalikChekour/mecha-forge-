# -*- coding: utf-8 -*-
"""Recolor des boss greffes (torse Meshy + jambes Blue Strike) : UNIFIE torse+jambes dans
UN skin metal par boss (rampe multi-tons avec derive de teinte = 'meme couleur mais pas trop uni'),
tout en gardant le COEUR/YEUX qui glow (accent). -> game/assets/enemies + montage de validation."""
import sys, os, numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw

def _lut(stops):
    xs = [int(p * 255) for p, _ in stops]; cols = [c for _, c in stops]
    lut = np.zeros((256, 3), float)
    for i in range(len(stops) - 1):
        a, b = xs[i], xs[i + 1]; ca, cb = np.array(cols[i], float), np.array(cols[i + 1], float)
        for x in range(a, b + 1):
            t = (x - a) / max(b - a, 1); lut[x] = ca * (1 - t) + cb * t
    for x in range(xs[-1], 256): lut[x] = cols[-1]
    return lut

def paint(arr, ramp, accent, glow=1.0, vth=0.66, sth=0.42):
    a = arr[:, :, 3].astype(float); rgb = arr[:, :, :3].astype(float)
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    L = 0.299 * R + 0.587 * G + 0.114 * B
    Ls = ndimage.median_filter(L, 3); Ls = ndimage.gaussian_filter(Ls, 0.5)
    detail = Ls - ndimage.gaussian_filter(Ls, 2.0)               # lignes de panneaux nettes
    Lr = np.clip((Ls - 5) * 1.20 + detail * 0.95, 0, 255)        # contraste + relief (anti-aplat)
    Li = Lr.astype(int)
    body = _lut(ramp)[Li]                                        # metal unifie torse+jambes
    # accent = zones emissives (coeur / yeux / energie) = pixels vifs & satures
    mx = rgb.max(-1); mn = rgb.min(-1); sat = (mx - mn) / (mx + 1e-3); val = mx / 255.0
    en_mask = ((val > vth) & (sat > sth)).astype(float)
    en_mask *= (a > 8)
    en_mask = ndimage.gaussian_filter(en_mask, 0.5)
    en = np.array(accent, float)
    out = body * (1 - en_mask[..., None]) + en * en_mask[..., None]
    # bloom du coeur (menacant)
    bloom = ndimage.gaussian_filter(en_mask, 2.3)
    out = out + en * (bloom[..., None] * 0.55 * glow)
    # reflet d'accent sur les aretes hautes du metal (papier peint : le metal capte la teinte)
    hi = np.clip((Lr - 188) / 66.0, 0, 1)[..., None]
    out = out + en * hi * (1 - en_mask[..., None]) * 0.14
    res = np.zeros_like(arr)
    res[..., :3] = np.clip(out, 0, 255).astype(np.uint8)
    res[..., 3] = np.clip(a + en_mask * 40, 0, 255).astype(np.uint8)
    return res

# --- skins « qui leur sient » (rampe = derive de teinte sombre->clair, pas d'aplat) ---
#          (ramp, accent, glow, vth, sth)
SKINS = {
    # CRUSHER : rouille martelee (maroon froid -> rouge oxyde -> acier chaud), coeur fondu
    "crusher": ([(0, (26, 17, 15)), (.30, (78, 33, 27)), (.56, (146, 60, 44)),
                 (.80, (200, 120, 92)), (1, (238, 198, 170))], (255, 150, 58), 1.05, 0.66, 0.42),
    # COLOSSE : acier neutre (corps) + OR reserve au coeur (accent) = 'acier & or' propre, pas mouchete
    "midboss": ([(0, (18, 20, 26)), (.32, (50, 55, 67)), (.60, (104, 112, 127)),
                 (.82, (162, 168, 182)), (1, (212, 218, 230))], (255, 196, 80), 1.05, 0.80, 0.60),
    # SOUVERAIN : obsidienne, chassis = corps (hautes lumieres plafonnees pour que les jambes
    # ne virent PAS argent -> memes tons que le torse noir), coeur CRAMOISI menacant
    "endboss": ([(0, (12, 13, 16)), (.42, (30, 33, 40)), (.70, (54, 59, 70)),
                 (.90, (88, 94, 108)), (1, (122, 130, 146))], (255, 52, 44), 1.1, 0.66, 0.46),
}
LABELS = {"crusher": "CRUSHER — rouille", "midboss": "COLOSSE — acier & or", "endboss": "SOUVERAIN — obsidienne"}
# nom de CHASSIS de sortie : crusher-boss ecrit sur 'crusherboss' pour NE PAS clobber le trash 'crusher'
OUTNAME = {"crusher": "crusherboss", "midboss": "midboss", "endboss": "endboss"}
DIRS = ["front", "left", "back", "right"]
BOSSES = sys.argv[1:] if len(sys.argv) > 1 else list(SKINS.keys())

mont = Image.new("RGB", (300 * len(BOSSES), 330), (20, 22, 28)); dr = ImageDraw.Draw(mont)
for i, boss in enumerate(BOSSES):
    ramp, acc, gl, vth, sth = SKINS[boss]
    for d in DIRS:
        sh = np.array(Image.open(f"cine/_show/bosstop/{boss}_{d}.png").convert("RGBA"))
        fw = sh.shape[1] // 8
        out = Image.new("RGBA", (sh.shape[1], sh.shape[0]), (0, 0, 0, 0))
        for k in range(8):
            cell = paint(sh[:, k * fw:(k + 1) * fw], ramp, acc, gl, vth, sth)
            out.paste(Image.fromarray(cell, "RGBA"), (k * fw, 0))
        out.save(f"game/assets/enemies/{OUTNAME.get(boss, boss)}_walk_{d}.png")
    # montage frame 2 front
    sh = np.array(Image.open(f"cine/_show/bosstop/{boss}_front.png").convert("RGBA")); fw = sh.shape[1] // 8
    c2 = paint(sh[:, 2 * fw:3 * fw], ramp, acc, gl, vth, sth)
    im = Image.fromarray(c2, "RGBA"); bg = Image.new("RGBA", (300, 300), (26, 28, 34, 255))
    im2 = im.resize((300, 300)); bg.alpha_composite(im2)
    mont.paste(bg.convert("RGB"), (i * 300, 26)); dr.text((i * 300 + 8, 8), LABELS[boss], fill=(235, 235, 245))
    print("PAINTED", boss)
mont.save("cine/_show/bosstop_recolor.png"); print("DONE")
