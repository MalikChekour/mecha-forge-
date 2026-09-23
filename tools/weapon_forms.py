#!/usr/bin/env python3
"""
Animate the 9 proposed WEAPON FORMS (top-down mockups) so the variety is visible before coding.
Player = cyan mech at center, enemies = red dots. Each weapon shows its characteristic pattern.
Outputs refs/weapon_forms/<name>.gif
"""
import numpy as np, os, math
from scipy.ndimage import gaussian_filter
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "refs", "weapon_forms")
os.makedirs(OUT, exist_ok=True)
S = 150; NF = 32; C = S / 2
BG = np.array([0.08, 0.09, 0.13])
rng = np.random.default_rng(3)
ENEMIES = [(C + math.cos(a) * r, C + math.sin(a) * r) for a, r in
           [(0.3, 52), (1.4, 60), (2.6, 48), (3.6, 58), (4.7, 50), (5.6, 62), (0.9, 40), (2.0, 66)]]

def blank():
    return np.tile(BG, (S, S, 1)).astype(float)

def dot(img, x, y, rad, col, a=1.0):
    yy, xx = np.mgrid[0:S, 0:S]
    d = np.hypot(xx - x, yy - y)
    m = np.clip(1 - d / rad, 0, 1) ** 1.5 * a
    for c in range(3):
        img[..., c] = img[..., c] * (1 - m) + col[c] * m
    return img

def add(img, x, y, rad, col, a=1.0):  # additive glow
    yy, xx = np.mgrid[0:S, 0:S]
    m = np.clip(1 - np.hypot(xx - x, yy - y) / rad, 0, 1) ** 2 * a
    for c in range(3):
        img[..., c] = np.clip(img[..., c] + col[c] * m, 0, 1)
    return img

def line(img, x0, y0, x1, y1, w, col, a=1.0):
    yy, xx = np.mgrid[0:S, 0:S]
    dx, dy = x1 - x0, y1 - y0
    L2 = dx * dx + dy * dy + 1e-6
    t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / L2, 0, 1)
    px, py = x0 + t * dx, y0 + t * dy
    m = np.clip(1 - np.hypot(xx - px, yy - py) / w, 0, 1) ** 1.5 * a
    for c in range(3):
        img[..., c] = np.clip(img[..., c] + col[c] * m, 0, 1)
    return img

def player(img):
    add(img, C, C, 12, (0.3, 0.7, 1.0), 0.5)
    dot(img, C, C, 7, (0.7, 0.95, 1.0))
    return img

def enemies(img, hit=()):
    for i, (x, y) in enumerate(ENEMIES):
        col = (1.0, 0.9, 0.3) if i in hit else (0.9, 0.3, 0.25)
        dot(img, x, y, 5, col)
    return img

def save(name, frames):
    gif = [Image.fromarray((np.clip(f, 0, 1) * 255).astype(np.uint8)).convert("P", palette=Image.ADAPTIVE) for f in frames]
    gif[0].save(os.path.join(OUT, name + ".gif"), save_all=True, append_images=gif[1:], duration=70, loop=0, disposal=2)
    print(" ", name)

CYAN = (0.8, 0.95, 1.0); ORANGE = (1.0, 0.6, 0.3); VIOLET = (0.75, 0.45, 1.0); GOLD = (1.0, 0.85, 0.3)

def w_autocannon():
    fr = []
    for i in range(NF):
        im = player(enemies(blank()))
        for k in range(4):
            p = ((i * 0.13 + k * 0.25) % 1.0)
            add(im, C + p * 70, C - 3 + k, 4, CYAN, 1 - p * 0.5)
        fr.append(im)
    return fr

def w_missiles():
    tgt = [ENEMIES[1], ENEMIES[4], ENEMIES[6]]
    fr = []
    for i in range(NF):
        im = player(enemies(blank()))
        for j, (tx, ty) in enumerate(tgt):
            p = ((i / NF) + j * 0.33) % 1.0
            x = C + (tx - C) * p + math.sin(p * 9 + j) * 10 * (1 - p)
            y = C + (ty - C) * p + math.cos(p * 9 + j) * 10 * (1 - p)
            add(im, x, y, 5, ORANGE)
            add(im, x - (tx - C) * 0.04, y - (ty - C) * 0.04, 7, (1, 0.4, 0.1), 0.4)
        fr.append(im)
    return fr

def w_railgun():
    fr = []
    for i in range(NF):
        im = player(enemies(blank()))
        charge = (i % 16) / 16
        if charge > 0.6:
            b = (charge - 0.6) / 0.4
            line(im, C, C, S, C - 4, 6 * b, (0.7, 0.9, 1.0), b)
            line(im, C, C, S, C - 4, 2, (1, 1, 1), b)
        fr.append(im)
    return fr

def w_plasma():
    fr = []
    tx, ty = ENEMIES[3]
    for i in range(NF):
        im = player(enemies(blank()))
        p = (i % 16) / 16
        if p < 0.5:
            x = C + (tx - C) * (p * 2); y = C + (ty - C) * (p * 2)
            add(im, x, y, 6, VIOLET)
        else:
            r = (p - 0.5) * 2 * 34
            yy, xx = np.mgrid[0:S, 0:S]
            ring = np.exp(-((np.hypot(xx - tx, yy - ty) - r) / 5) ** 2) * (1 - (p - 0.5) * 2)
            for c in range(3):
                im[..., c] = np.clip(im[..., c] + VIOLET[c] * ring, 0, 1)
        fr.append(im)
    return fr

def w_aura():
    fr = []
    for i in range(NF):
        im = enemies(blank())
        r = 34 + 5 * math.sin(i / NF * 2 * math.pi)
        yy, xx = np.mgrid[0:S, 0:S]
        ring = np.exp(-((np.hypot(xx - C, yy - C) - r) / 6) ** 2) * 0.8
        fill = np.clip(1 - np.hypot(xx - C, yy - C) / r, 0, 1) * 0.12
        for c in range(3):
            im[..., c] = np.clip(im[..., c] + (0.4, 0.9, 1.0)[c] * (ring + fill), 0, 1)
        player(im)
        hit = [k for k, (x, y) in enumerate(ENEMIES) if math.hypot(x - C, y - C) < r]
        enemies(im, hit)
        fr.append(im)
    return fr

def w_drones():
    fr = []
    for i in range(NF):
        im = player(enemies(blank()))
        for k in range(3):
            a = i / NF * 2 * math.pi + k * 2.09
            x, y = C + math.cos(a) * 30, C + math.sin(a) * 30
            add(im, x, y, 5, (0.5, 0.95, 1.0))
            if (i + k * 4) % 12 < 3:
                tx, ty = ENEMIES[(i + k) % len(ENEMIES)]
                line(im, x, y, tx, ty, 2, (0.6, 0.95, 1.0), 0.7)
        fr.append(im)
    return fr

def w_sabre():
    fr = []
    for i in range(NF):
        im = player(enemies(blank()))
        base = (i / NF) * 2 * math.pi
        yy, xx = np.mgrid[0:S, 0:S]
        ang = np.arctan2(yy - C, xx - C)
        r = np.hypot(xx - C, yy - C)
        arc = np.exp(-((((ang - base + math.pi) % (2 * math.pi)) - math.pi) / 0.5) ** 2) * np.exp(-((r - 28) / 12) ** 2)
        for c in range(3):
            im[..., c] = np.clip(im[..., c] + (0.5, 1.0, 1.0)[c] * arc, 0, 1)
        fr.append(im)
    return fr

def w_mines():
    mines = [(C - 30, C + 20), (C + 24, C - 26), (C + 30, C + 28)]
    fr = []
    for i in range(NF):
        im = player(enemies(blank()))
        cyc = i % 16
        for mx, my in mines:
            if cyc < 12:
                blink = 0.4 + 0.6 * abs(math.sin(cyc * (0.3 + cyc * 0.05)))
                dot(im, mx, my, 4, (1.0, 0.5, 0.2), blink)
            else:
                b = (cyc - 12) / 4
                add(im, mx, my, 22 * b, (1.0, 0.7, 0.3), 1 - b)
        fr.append(im)
    return fr

def w_boomerang():
    fr = []
    for i in range(NF):
        im = player(enemies(blank()))
        p = i / NF
        reach = math.sin(p * math.pi) * 60
        x = C + reach; y = C + math.sin(p * 2 * math.pi) * 18
        add(im, x, y, 6, GOLD)
        add(im, x, y, 10, (1, 0.9, 0.5), 0.3 + 0.3 * math.sin(i))
        fr.append(im)
    return fr

FORMS = {
    "1_autocanon": w_autocannon, "2_missiles": w_missiles, "3_railgun": w_railgun,
    "4_plasma": w_plasma, "5_aura": w_aura, "6_drones": w_drones,
    "7_sabre": w_sabre, "8_mines": w_mines, "9_boomerang": w_boomerang,
}
if __name__ == "__main__":
    print("weapon forms ->", OUT)
    for n, f in FORMS.items():
        save(n, f())
    print("DONE")
