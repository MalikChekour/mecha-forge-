"""Nettoie le detourage du Prototype (pieds/halo/specks) + le recolorise en plusieurs
styles ROBOT (gradient-map de la luminance + accent sur les zones rouges).
- ecrit le detourage propre (crimson nettoye) sur les sheets du jeu
- genere des GIF anim de chaque style -> cine/_show/styles/ pour le catalogue
"""
import os, numpy as np
from PIL import Image
from scipy import ndimage

SRC = "game/assets/enemies"
OUTG = "cine/_show/styles"
os.makedirs(OUTG, exist_ok=True)
DIRS = ["front", "back", "left", "right"]

def clean_alpha(arr):
    """Hard cutout: kill anti-alias halo + detached specks, per 8-frame cell."""
    a = arr[:, :, 3]
    fw = arr.shape[1] // 8
    solid = (a >= 120)
    out = np.zeros_like(a)
    for i in range(8):
        sub = solid[:, i*fw:(i+1)*fw]
        lbl, n = ndimage.label(sub)
        if n >= 1:
            sizes = ndimage.sum(np.ones_like(sub), lbl, range(1, n+1))
            keep = [idx+1 for idx, s in enumerate(sizes) if s >= 0.12*sizes.max()]
            m = np.isin(lbl, keep)
            # tiny morphological close to smooth the border, then set crisp alpha
            m = ndimage.binary_closing(m, iterations=1)
            out[:, i*fw:(i+1)*fw] = np.where(m, 255, 0)
    arr[:, :, 3] = out
    return arr

def lut_from_ramp(ramp):
    xs = [p[0] for p in ramp]
    cols = np.array([p[1] for p in ramp], float)
    t = np.linspace(0, 1, 256)
    return np.stack([np.interp(t, xs, cols[:, c]) for c in range(3)], 1)  # 256x3

def recolor(arr, ramp, accent, accent_str=0.4):
    rgb = arr[:, :, :3].astype(float)
    a = arr[:, :, 3]
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    L = (0.299*R + 0.587*G + 0.114*B)
    # strong denoise so the mech reads as CLEAN metal, not mottled lava, then lift contrast
    L = ndimage.median_filter(L, size=5)
    L = ndimage.gaussian_filter(L, sigma=0.8)
    L = np.clip((L - 14) * 1.22, 0, 255).astype(int)
    lut = lut_from_ramp(ramp)
    body = lut[L]  # HxWx3
    # accent ONLY on the brightest pure-red glows (energy lines/core), not the whole body
    redness = np.clip((R - np.maximum(G, B) - 55) / 70.0, 0, 1)
    glow = redness * np.clip((R - 120) / 100.0, 0, 1)      # must also be bright
    glow = (glow[..., None]) * accent_str
    acc = np.array(accent, float)
    out = body * (1 - glow) + acc * glow
    res = np.zeros_like(arr)
    res[..., :3] = np.clip(out, 0, 255).astype(np.uint8)
    res[..., 3] = a
    return res

STYLES = {
    "acier":        (dict(ramp=[(0,(18,20,26)),(.4,(72,80,92)),(.72,(150,160,176)),(1,(236,243,252))], accent=(70,205,255)), "Acier · cyan"),
    "cobalt":       (dict(ramp=[(0,(10,14,30)),(.4,(30,52,112)),(.72,(84,132,212)),(1,(205,228,255))], accent=(95,165,255)), "Cobalt"),
    "orange_indus": (dict(ramp=[(0,(22,20,18)),(.4,(74,70,64)),(.72,(152,148,140)),(1,(242,240,234))], accent=(255,140,28)), "Industriel orange"),
    "olive_mil":    (dict(ramp=[(0,(18,20,14)),(.4,(58,64,40)),(.72,(122,128,86)),(1,(222,224,190))], accent=(255,196,66)), "Militaire olive"),
    "chrome_rouge": (dict(ramp=[(0,(20,20,24)),(.4,(82,84,90)),(.72,(166,170,178)),(1,(246,248,252))], accent=(232,46,56)), "Chrome · rouge"),
    "toxic_vert":   (dict(ramp=[(0,(14,20,16)),(.4,(45,72,52)),(.72,(112,152,120)),(1,(216,242,222))], accent=(126,255,92)), "Toxique vert"),
    "violet_void":  (dict(ramp=[(0,(18,14,26)),(.4,(58,44,92)),(.72,(126,104,180)),(1,(228,214,250))], accent=(190,90,255)), "Void violet"),
    "or_noir":      (dict(ramp=[(0,(16,15,12)),(.4,(60,54,40)),(.72,(140,124,86)),(1,(244,232,196))], accent=(255,210,90)), "Or & noir"),
}

def gif_of(sheet_rgba, out):
    fw = sheet_rgba.shape[1] // 8
    frames = []
    for i in range(8):
        cell = sheet_rgba[:, i*fw:(i+1)*fw]
        im = Image.fromarray(cell, "RGBA")
        bg = Image.new("RGBA", im.size, (30, 32, 38, 255)); bg.alpha_composite(im)
        frames.append(bg.convert("RGB").resize((190, 190)).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=110, loop=0, disposal=2)

# 1) clean detour on the actual game sheets (front-facing kept crimson), + gather cleaned arrays
cleaned = {}
for d in DIRS:
    p = f"{SRC}/mixtest_walk_{d}.png"
    arr = np.array(Image.open(p).convert("RGBA"))
    arr = clean_alpha(arr)
    cleaned[d] = arr
    Image.fromarray(arr, "RGBA").save(p)  # write cleaned detour back to game
print("detour cleaned on 4 dirs")

# 2) style GIFs from the cleaned FRONT sheet
front = cleaned["front"]
gif_of(front, f"{OUTG}/style_crimson_clean.gif")  # cleaned original for reference
report = [("crimson_clean", "Crimson (nettoye)")]
for key, (params, label) in STYLES.items():
    styled = recolor(front, **params)
    gif_of(styled, f"{OUTG}/style_{key}.gif")
    report.append((key, label))
print("styles:", [r[0] for r in report])
