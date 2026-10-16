#!/usr/bin/env python3
"""
Textures d'effets des TIRS DE TOURELLE (15/10, patron : « la qualite etait trop basique »).
Pipeline HDR : lumiere accumulee -> bloom multi-echelle -> tonemap filmique. Bruit fractal (fbm) pour
l'organique (lave, acide, givre, fumee). Sortie : game/assets/vfx/ts/*.png

  ts_<style>_head.png     tete de projectile (256x256, additive)
  ts_<style>_impact.png   planche 4x4 de 16 images de 192x192 (additive) = 768x768
  ts_<style>_decal.png    residu au sol, alpha normal (384x384)
  ts_<style>_glow.png     emissif du residu, additive (384x384)
  ts_beam_<style>.png     bande de faisceau (256x64), 4 variantes empilees (256x256)
  ts_smoke.png / ts_flare.png / ts_ring.png / ts_streak.png   communs (blanc, teintes en jeu)
"""
import os, math
import numpy as np
from scipy.ndimage import gaussian_filter, zoom
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "assets", "vfx", "ts")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(1510)


def grid(w, h=None):
    h = h or w
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return xx, yy


def fbm(w, h=None, base=4, octaves=5, seed=0, persistence=0.55):
    h = h or w
    r = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = base * (2 ** o)
        low = r.random((c + 2, max(2, int(c * h / w) + 2))).astype(np.float32)
        z = zoom(low, (h / low.shape[0] * 1.0, w / low.shape[1] * 1.0), order=3)[:h, :w]
        out += z * amp
        tot += amp
        amp *= persistence
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)


def blank(w, h=None):
    return np.zeros((h or w, w, 3), np.float32)


def add(b, mask, col, inten=1.0):
    for c in range(3):
        b[..., c] += mask * col[c] * inten
    return b


def gauss(xx, yy, x, y, r):
    return np.exp(-(((xx - x) ** 2 + (yy - y) ** 2) / (2 * r * r))).astype(np.float32)


def ringm(xx, yy, x, y, rad, th):
    d = np.hypot(xx - x, yy - y)
    return np.exp(-(((d - rad) / th) ** 2)).astype(np.float32)


def bloom(h, k=1.0):
    b = np.zeros_like(h)
    for sig, wt in [(1.5, 0.5), (4, 0.45), (10, 0.32), (22, 0.2)]:
        for c in range(3):
            b[..., c] += gaussian_filter(h[..., c], sig) * wt * k
    return h + b


def tonemap(h):
    x = np.clip(h, 0, None)
    a, bb, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    return np.clip((x * (a * x + bb)) / (x * (c * x + d) + e), 0, 1)


def window(h, w):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
    return np.clip((1 - d) / 0.28, 0, 1) ** 1.2


def to_rgba_additive(h, k=1.0, win=True):
    """Image additive : alpha = luminance max, RGB = teinte normalisee, de sorte que RGB*alpha (melange
    additif du moteur) redonne exactement l'image tonemappee. `win` : fondu radial -> jamais de bord de carre."""
    img = tonemap(bloom(h, k))
    if win:
        img = img * window(img.shape[0], img.shape[1])[..., None]
    a = np.clip(img.max(axis=2), 0, 1)
    rgb = np.clip(img / np.maximum(a[..., None], 1e-4), 0, 1)
    out = np.dstack([rgb, a])
    return (out * 255).astype(np.uint8)


def save(name, arr):
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT, name), optimize=True)
    print("  ", name, arr.shape[1], "x", arr.shape[0])


# ---------------------------------------------------------------- palettes (HDR)
WHITE = (1.0, 1.0, 1.0)
CYAN = (0.35, 1.15, 1.7); ICE = (0.65, 1.05, 1.6)
GOLD = (1.7, 1.25, 0.35); AMBER = (1.8, 0.8, 0.18); LAVA = (1.9, 0.55, 0.1); RED = (1.9, 0.3, 0.15)
LIME = (0.8, 1.6, 0.25); GREEN = (0.35, 1.7, 0.7); TEAL = (0.3, 1.5, 1.3)
VIOLET = (1.2, 0.5, 1.7); PINK = (1.8, 0.5, 1.2)

# ================================================================== COMMUNS
def make_common():
    s = 256
    xx, yy = grid(s)
    c = s / 2
    # fumee : nuage doux et bruite (alpha normal, blanc)
    n = fbm(s, base=3, octaves=5, seed=11)
    d = np.hypot(xx - c, yy - c) / c
    m = np.clip(1 - d, 0, 1) ** 1.3
    a = np.clip((n * 1.3 - 0.25) * m * 1.6, 0, 1)
    sm = np.dstack([np.ones((s, s, 3)) * (0.55 + 0.45 * n[..., None]), a])
    save("ts_smoke.png", (np.clip(sm, 0, 1) * 255).astype(np.uint8))
    # flare : etoile a 4 branches + halo (additive)
    b = blank(s)
    add(b, gauss(xx, yy, c, c, 6), WHITE, 3.0)
    add(b, gauss(xx, yy, c, c, 22), WHITE, 0.55)
    for ang, ln, w in [(0, 120, 2.0), (math.pi / 2, 120, 2.0), (math.pi / 4, 62, 1.5), (-math.pi / 4, 62, 1.5)]:
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        m = np.exp(-(p / w) ** 2) * np.exp(-np.abs(t) / (ln * 0.45))
        add(b, m.astype(np.float32), WHITE, 1.5)
    save("ts_flare.png", to_rgba_additive(b, 0.6))
    # anneau d'onde de choc (additive, fin, degrade)
    b = blank(s)
    add(b, ringm(xx, yy, c, c, 100, 5), WHITE, 1.6)
    add(b, ringm(xx, yy, c, c, 100, 14), WHITE, 0.4)
    nn = fbm(s, base=8, octaves=3, seed=3)
    b *= (0.55 + 0.6 * nn[..., None])
    save("ts_ring.png", to_rgba_additive(b, 0.8))
    # traînee : bande horizontale effilee (additive)
    w, h = 256, 64
    xx2, yy2 = grid(w, h)
    m = np.exp(-(((yy2 - h / 2) / (h * 0.14 * (0.25 + xx2 / w * 0.75))) ** 2)) * (xx2 / w) ** 1.6
    b = np.zeros((h, w, 3), np.float32)
    add(b, m.astype(np.float32), WHITE, 1.8)
    add(b, (np.exp(-(((yy2 - h / 2) / (h * 0.4)) ** 2)) * (xx2 / w) ** 2.4).astype(np.float32), WHITE, 0.35)
    save("ts_streak.png", to_rgba_additive(b, 0.5, False))
    # eclat de debris (petit trait lumineux)
    w, h = 64, 16
    xx2, yy2 = grid(w, h)
    m = np.exp(-(((yy2 - h / 2) / 2.2) ** 2)) * (xx2 / w) ** 1.3
    b = np.zeros((h, w, 3), np.float32)
    add(b, m.astype(np.float32), WHITE, 2.4)
    save("ts_spark.png", to_rgba_additive(b, 0.4, False))


# ================================================================== TETES DE PROJECTILE
def head(name, painter, size=256):
    xx, yy = grid(size)
    b = blank(size)
    painter(b, xx, yy, size / 2)
    save("ts_%s_head.png" % name, to_rgba_additive(b, 0.9))


def head_pod(b, xx, yy, c):
    # graine blindee : coque + epine bioluminescente + 3 ailes de samare
    n = fbm(256, base=6, octaves=4, seed=21)
    d = np.hypot(xx - c, yy - c)
    add(b, gauss(xx, yy, c, c, 44), LIME, 0.3)
    body = np.clip(1 - d / 38, 0, 1) ** 0.7
    add(b, body * (0.5 + 0.6 * n), (0.35, 0.95, 0.22), 1.3)
    add(b, gauss(xx, yy, c - 8, c - 8, 13), (1.4, 1.9, 0.9), 1.2)
    for k in range(3):
        a = k * 2.0944 + 0.5
        ux, uy = math.cos(a), math.sin(a)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        wing = np.exp(-(p / (7 + t * 0.12)) ** 2) * ((t > 18) & (t < 64)) * np.exp(-(t - 40) ** 2 / 700)
        add(b, wing.astype(np.float32), (0.55, 1.4, 0.3), 1.0)
    add(b, gauss(xx, yy, c, c, 8), WHITE, 1.4)


def head_slag(b, xx, yy, c):
    n = fbm(256, base=5, octaves=5, seed=22)
    d = np.hypot(xx - c, yy - c)
    add(b, gauss(xx, yy, c, c, 46), LAVA, 0.45)
    crust = np.clip(1 - d / 46, 0, 1) ** 0.5
    cracks = np.clip(1 - np.abs(n - 0.5) * 7, 0, 1)
    add(b, crust * (0.12 + 0.2 * n), (0.5, 0.35, 0.3), 1.0)
    add(b, crust * cracks, (2.0, 1.1, 0.25), 1.7)
    add(b, gauss(xx, yy, c, c, 20), (2.0, 1.6, 0.8), 0.9)
    add(b, gauss(xx, yy, c - 6, c - 6, 8), WHITE, 1.2)


def head_flak(b, xx, yy, c):
    # obus traceur : pointe phosphore blanche + longue flamme vers l'arriere (-x)
    t = c - xx
    p = yy - c
    flame = np.exp(-(p / (5 + np.clip(t, 0, 200) * 0.05)) ** 2) * (t > 0) * np.exp(-t / 70)
    add(b, flame.astype(np.float32), (1.9, 0.85, 0.25), 1.5)
    add(b, (np.exp(-(p / 2.5) ** 2) * (t > 0) * np.exp(-t / 36)).astype(np.float32), (2, 1.9, 1.2), 1.4)
    add(b, gauss(xx, yy, c, c, 17), (1.6, 1.0, 0.4), 0.7)
    add(b, gauss(xx, yy, c, c, 6), WHITE, 2.4)


def head_frost(b, xx, yy, c):
    n = fbm(256, base=7, octaves=4, seed=23)
    d = np.hypot(xx - c, yy - c)
    ang = np.arctan2(yy - c, xx - c)
    add(b, gauss(xx, yy, c, c, 44), ICE, 0.4)
    # cristal a 8 facettes
    rad = 40 + 14 * np.cos(ang * 8)
    body = np.clip(1 - d / rad, 0, 1) ** 0.6
    add(b, body * (0.6 + 0.5 * n), (0.5, 0.95, 1.5), 1.1)
    for k in range(8):
        a = k * math.pi / 4
        ux, uy = math.cos(a), math.sin(a)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        spike = np.exp(-(p / 2.0) ** 2) * ((t > 8) & (t < 78)) * np.exp(-t / 55)
        add(b, spike.astype(np.float32), (0.9, 1.4, 1.9), 1.3)
    add(b, gauss(xx, yy, c, c, 14), WHITE, 2.0)


def head_plasma(b, xx, yy, c):
    n = fbm(256, base=6, octaves=5, seed=24)
    add(b, gauss(xx, yy, c, c, 48), GREEN, 0.4)
    add(b, gauss(xx, yy, c, c, 28), (0.5, 1.6, 0.9), 0.7)
    arcs = np.clip(1 - np.abs(n - 0.5) * 8, 0, 1) * np.clip(1 - np.hypot(xx - c, yy - c) / 80, 0, 1)
    add(b, arcs, (0.9, 1.9, 1.3), 1.4)
    add(b, gauss(xx, yy, c, c, 17), WHITE, 2.4)
    add(b, ringm(xx, yy, c, c, 46, 3.5), (0.6, 1.9, 1.0), 0.9)


def head_bolt(b, xx, yy, c):
    t = c - xx
    p = yy - c
    m = np.exp(-(p / 3.0) ** 2) * (t > -10) * np.exp(-np.abs(t) / 90)
    add(b, m.astype(np.float32), (0.9, 1.9, 1.2), 1.6)
    add(b, (np.exp(-(p / 9.0) ** 2) * (t > -10) * np.exp(-np.abs(t) / 70)).astype(np.float32), GREEN, 0.7)
    add(b, gauss(xx, yy, c, c, 10), WHITE, 2.0)


def head_acid(b, xx, yy, c):
    n = fbm(256, base=6, octaves=4, seed=25)
    d = np.hypot((xx - c) * 0.8, yy - c)
    add(b, gauss(xx, yy, c, c, 42), LIME, 0.35)
    body = np.clip(1 - d / 52, 0, 1) ** 0.55
    add(b, body * (0.55 + 0.5 * n), (0.7, 1.55, 0.2), 1.3)
    add(b, ringm(xx, yy, c, c, 50, 5), (1.0, 1.9, 0.5), 0.8)       # membrane
    add(b, gauss(xx, yy, c - 12, c - 14, 11), (1.9, 2, 1.4), 1.3)   # reflet
    add(b, gauss(xx, yy, c + 14, c + 12, 22), (0.3, 1.0, 0.1), 0.5)


def head_missile(b, xx, yy, c):
    # missile vu de cote : corps + ogive doree + flamme bleutee vers l'arriere
    t = xx - c
    p = yy - c
    body = (np.abs(p) < 9 * (1 - np.clip((t - 22) / 30, 0, 1)) + 1) & (t > -34) & (t < 52)
    add(b, body.astype(np.float32), (1.05, 1.05, 1.15), 0.9)
    add(b, ((np.abs(p) < 4) & (t > -34) & (t < 52)).astype(np.float32), WHITE, 0.4)
    nose = (t > 30) & (t < 56) & (np.abs(p) < 8 * (1 - (t - 30) / 26))
    add(b, nose.astype(np.float32), (1.9, 1.2, 0.3), 1.0)
    for sgn in (-1, 1):
        fin = (t > -34) & (t < -14) & (np.abs(p - sgn * (9 + (t + 34) * 0.6)) < 3.2)
        add(b, fin.astype(np.float32), (1.7, 1.1, 0.3), 0.9)
    flame = np.exp(-(p / (4 + np.clip(-t - 34, 0, 100) * 0.1)) ** 2) * (t < -34) * np.exp(-(-t - 34) / 40)
    add(b, flame.astype(np.float32), (0.5, 1.2, 1.9), 1.6)
    add(b, gauss(xx, yy, c - 40, c, 12), (0.8, 1.6, 2.0), 1.1)
    add(b, gauss(xx, yy, c - 46, c, 5), WHITE, 1.8)


# ================================================================== IMPACTS (planche 4x4)
FR = 192


def sheet(name, painter, k=0.9):
    frames = []
    xx, yy = grid(FR)
    for i in range(16):
        t = i / 15.0
        b = blank(FR)
        painter(b, xx, yy, FR / 2, t, np.random.default_rng(500 + i))
        frames.append(to_rgba_additive(b, k))
    sh = np.zeros((FR * 4, FR * 4, 4), np.uint8)
    for i, f in enumerate(frames):
        sh[(i // 4) * FR:(i // 4 + 1) * FR, (i % 4) * FR:(i % 4 + 1) * FR] = f
    save("ts_%s_impact.png" % name, sh)


def debris(b, xx, yy, c, t, r, col, n, speed, size, grav=0.0, bright=1.6):
    fade = (1 - t) ** 1.3
    for k in range(n):
        a = r.uniform(0, 6.283)
        v = r.uniform(0.35, 1.0) * speed
        x = c + math.cos(a) * v * t
        y = c + math.sin(a) * v * t + grav * t * t
        add(b, gauss(xx, yy, x, y, size * (0.6 + 0.4 * (1 - t))), col, bright * fade)


def ramp(field, col, hot):
    """Rampe de temperature : bord = couleur sombre, milieu = couleur, centre = blanc chaud."""
    f = np.clip(field, 0, 1)
    out = np.zeros(field.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = (col[c] * 0.35 * f + col[c] * 0.9 * f ** 2 + hot[c] * 1.1 * f ** 4)
    return out


def blast(b, xx, yy, c, t, col, hot, rad, ring=1.0, turb=0.8):
    """Boule de feu/souffle : champ de bruit deforme, seuil qui recule avec le temps, rampe de chaleur."""
    fade = (1 - t) ** 1.25
    n1 = fbm(FR, base=3, octaves=5, seed=77)
    n2 = fbm(FR, base=5, octaves=4, seed=91)
    ox = int((t * 22) % FR)
    n = np.roll(n1, ox, axis=1) * 0.6 + np.roll(n2, -ox // 2, axis=0) * 0.4
    ang = np.arctan2(yy - c, xx - c)
    rr = np.random.default_rng(int(rad * 7))
    lobes = sum(rr.uniform(0.25, 0.6) * np.sin(ang * k + rr.uniform(0, 6.28)) for k in (2, 3, 5, 7, 11)) / 1.6
    d = np.hypot(xx - c, yy - c) / (rad * (0.30 + 0.85 * np.sqrt(t)) * (1 + 0.42 * lobes))
    field = (1.15 - d) + (n - 0.5) * turb * 2.6
    field = np.clip(field, 0, 1) * fade
    rgb = ramp(field, col, hot)
    b += rgb * 1.15
    # filet de matiere ejectée
    add(b, ringm(xx, yy, c, c, rad * (0.25 + 0.95 * np.sqrt(t)), 2.0 + 2 * t) * np.clip((n - 0.5) * 5, 0, 1), col, 0.9 * fade * ring)


def imp_slag(b, xx, yy, c, t, r):
    blast(b, xx, yy, c, t, LAVA, (2.2, 1.8, 0.9), 74, 1.0, 0.7)
    debris(b, xx, yy, c, t, r, (2, 0.9, 0.2), 30, 130, 2.4, grav=70)


def imp_ice(b, xx, yy, c, t, r):
    blast(b, xx, yy, c, t, ICE, (1.8, 2.0, 2.0), 76, 1.4)
    fade = (1 - t) ** 1.2
    for k in range(14):
        a = k * 6.283 / 14 + 0.2
        ux, uy = math.cos(a), math.sin(a)
        tt = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        L = 80 * np.sqrt(t) + 6
        m = np.exp(-(p / 2.6) ** 2) * ((tt > 0.04 * L) & (tt < L))
        add(b, m.astype(np.float32), (1.2, 1.7, 2.0), 1.5 * fade)
    debris(b, xx, yy, c, t, r, (1.2, 1.8, 2.0), 22, 100, 2.2)


def imp_acid(b, xx, yy, c, t, r):
    blast(b, xx, yy, c, t, LIME, (1.9, 2.0, 1.0), 62, 0.8)
    debris(b, xx, yy, c, t, r, (1.0, 1.9, 0.3), 30, 105, 2.6, grav=55)


def imp_pod(b, xx, yy, c, t, r):
    blast(b, xx, yy, c, t, (0.55, 1.5, 0.28), (1.5, 2.0, 0.9), 56, 0.9)
    debris(b, xx, yy, c, t, r, (0.9, 1.8, 0.4), 34, 95, 2.2, grav=25)


def imp_smoke(b, xx, yy, c, t, r):
    # eclair de detonation aerienne (flak) : flash + etoile + anneau
    fade = (1 - t) ** 2.2
    add(b, gauss(xx, yy, c, c, 8 + 16 * t), (2.1, 1.7, 1.0), 1.5 * fade)
    for k in range(8):
        a = k * 0.785 + 0.2
        ux, uy = math.cos(a), math.sin(a)
        tt = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        L = 24 + 78 * np.sqrt(t)
        m = np.exp(-(p / 2.2) ** 2) * ((tt > 0) & (tt < L))
        add(b, m.astype(np.float32), (2.0, 1.4, 0.6), 1.6 * fade)
    add(b, ringm(xx, yy, c, c, 20 + 70 * np.sqrt(t), 3.5), (2, 1.4, 0.7), 1.5 * fade)
    debris(b, xx, yy, c, t, r, (2.0, 1.2, 0.4), 14, 90, 2.0)


def imp_plasma(b, xx, yy, c, t, r):
    blast(b, xx, yy, c, t, GREEN, (1.6, 2.2, 1.6), 68, 1.2)
    fade = (1 - t) ** 1.4
    n = fbm(FR, base=7, octaves=4, seed=int(10 + t * 30))
    arcs = np.clip(1 - np.abs(n - 0.5) * 9, 0, 1) * np.clip(1 - np.hypot(xx - c, yy - c) / (30 + 62 * t), 0, 1)
    add(b, arcs, (1.0, 2.0, 1.4), 1.8 * fade)


def imp_missile(b, xx, yy, c, t, r):
    blast(b, xx, yy, c, t, (1.9, 0.85, 0.5), (2.2, 1.8, 1.2), 72, 1.3)
    debris(b, xx, yy, c, t, r, (2.0, 1.3, 0.6), 28, 125, 2.2)
    fade = (1 - t) ** 1.6
    add(b, ringm(xx, yy, c, c, 20 + 78 * np.sqrt(t), 2.6), (1.4, 1.7, 2.0), 1.1 * fade)


# ================================================================== RESIDUS AU SOL
DS = 384


def decal_rgba(rgb, alpha):
    return (np.clip(np.dstack([rgb, alpha]), 0, 1) * 255).astype(np.uint8)


def disc_mask(xx, yy, c, rad, jag, seed):
    n = fbm(DS, base=6, octaves=4, seed=seed)
    ang = np.arctan2(yy - c, xx - c)
    wob = 1 + jag * (np.sin(ang * 5 + seed) * 0.5 + np.sin(ang * 9 + seed * 2) * 0.3 + (n - 0.5) * 1.2)
    d = np.hypot(xx - c, yy - c) / (rad * wob)
    return np.clip((1 - d) * 5, 0, 1), d, n


def make_decals():
    xx, yy = grid(DS)
    c = DS / 2
    # --- magma : croute sombre craquelee + (emissif separe)
    m, d, n = disc_mask(xx, yy, c, 170, 0.12, 5)
    rim = np.clip(1 - np.abs(d - 0.92) * 9, 0, 1)
    crust = 0.07 + 0.12 * fbm(DS, base=10, octaves=4, seed=6)
    rgb = np.dstack([crust * 1.1, crust * 0.8, crust * 0.7])
    save("ts_slag_decal.png", decal_rgba(rgb, m * (0.55 + 0.4 * (d > 0.55))))
    n2 = fbm(DS, base=7, octaves=5, seed=8)
    veins = np.clip(1 - np.abs(n2 - 0.5) * 6.5, 0, 1) ** 1.4
    core = np.clip(1 - d / 0.85, 0, 1) ** 0.8
    b = blank(DS)
    add(b, m * (core * 0.18 + veins * 0.8 * np.clip(1.05 - d, 0, 1)), (1.9, 0.6, 0.1), 0.95)
    add(b, m * core ** 3, (2.0, 1.2, 0.4), 0.35)
    add(b, rim * m, (2.0, 0.5, 0.08), 0.55)
    save("ts_slag_glow.png", to_rgba_additive(b, 0.7))
    # --- acide : flaque visqueuse brillante
    m, d, n = disc_mask(xx, yy, c, 168, 0.16, 12)
    base = np.dstack([0.16 + 0.1 * n, 0.3 + 0.2 * n, 0.04 + 0.04 * n])
    save("ts_acid_decal.png", decal_rgba(base, m * 0.82))
    b = blank(DS)
    add(b, m * np.clip(1 - d, 0, 1) ** 0.8 * (0.3 + 0.5 * n), (0.6, 1.4, 0.15), 0.45)
    add(b, m * np.clip(1 - np.abs(d - 0.9) * 8, 0, 1), (1.3, 1.9, 0.45), 0.6)
    bub = fbm(DS, base=14, octaves=2, seed=14)
    add(b, m * np.clip((bub - 0.66) * 8, 0, 1), (1.4, 1.9, 0.7), 0.6)
    save("ts_acid_glow.png", to_rgba_additive(b, 0.7))
    # --- givre : rime cristalline
    m, d, n = disc_mask(xx, yy, c, 170, 0.2, 21)
    ang = np.arctan2(yy - c, xx - c)
    star = np.clip(np.cos(ang * 6) * 0.5 + 0.5, 0, 1) ** 6 * np.clip(1 - d, 0, 1)
    base = np.dstack([0.55 + 0.4 * n, 0.72 + 0.28 * n, 0.9 + 0.1 * n])
    save("ts_frost_decal.png", decal_rgba(base, np.clip(m * (0.22 + 0.45 * n) + star * 0.7, 0, 1)))
    b = blank(DS)
    add(b, star, (0.8, 1.3, 1.8), 0.8)
    add(b, m * (fbm(DS, base=18, octaves=2, seed=23) > 0.74) * 0.8, (1.0, 1.5, 1.9), 0.55)
    save("ts_frost_glow.png", to_rgba_additive(b, 0.7))
    # --- spores : nuage organique
    m, d, n = disc_mask(xx, yy, c, 176, 0.2, 31)
    base = np.dstack([0.25 + 0.2 * n, 0.55 + 0.3 * n, 0.12 + 0.1 * n])
    save("ts_spores_decal.png", decal_rgba(base, m * (0.1 + 0.22 * n)))
    b = blank(DS)
    pts = fbm(DS, base=24, octaves=2, seed=33)
    add(b, (pts > 0.66) * m * np.clip(1 - d, 0, 1), (0.9, 1.9, 0.5), 1.1)
    save("ts_spores_glow.png", to_rgba_additive(b, 0.6))
    # --- verre vitrifie : bande (largeur = axe x, hauteur = epaisseur) 512x128
    W, H = 512, 128
    gx, gy = grid(W, H)
    n = fbm(W, H, base=8, octaves=4, seed=41)
    off = (n - 0.5) * 34
    dist = np.abs(gy - H / 2 - off)
    edge = np.clip(1 - dist / 50, 0, 1)
    base = np.dstack([0.1 + 0.2 * n, 0.3 + 0.3 * n, 0.3 + 0.28 * n])
    save("ts_glass_decal.png", decal_rgba(base, edge ** 0.8 * np.clip(gx / 20, 0, 1) * np.clip((W - gx) / 20, 0, 1) * 0.85))
    b = np.zeros((H, W, 3), np.float32)
    core = np.exp(-(dist / 7.0) ** 2)
    sh = np.clip(1 - np.abs(fbm(W, H, base=20, octaves=2, seed=42) - 0.5) * 9, 0, 1)
    add(b, core * (0.7 + 0.5 * sh), (1.9, 1.5, 0.5), 1.2)
    add(b, edge ** 2 * sh, (0.5, 1.8, 1.6), 0.9)
    save("ts_glass_glow.png", to_rgba_additive(b, 0.7, False))


# ================================================================== FAISCEAUX (bandes 256x64, 4 variantes)
def make_beams():
    W, H = 256, 64
    xx, yy = grid(W, H)
    for name, col, hot in [("weld", CYAN, (1.6, 2.0, 2.0)), ("solar", GOLD, (2.2, 2.0, 1.4)), ("plasma", GREEN, (1.6, 2.2, 1.7))]:
        var = []
        for v in range(4):
            n = fbm(W, H, base=10, octaves=4, seed=60 + v)
            wob = (n - 0.5) * 9
            dist = np.abs(yy - H / 2 - wob * (name != "solar"))
            b = np.zeros((H, W, 3), np.float32)
            add(b, np.exp(-(dist / 13) ** 2).astype(np.float32), col, 0.9)
            add(b, np.exp(-(dist / 5.5) ** 2).astype(np.float32), col, 1.3)
            add(b, np.exp(-(dist / 2.2) ** 2).astype(np.float32), hot, 1.8)
            sparkle = np.clip((fbm(W, H, base=30, octaves=2, seed=70 + v) - 0.7) * 6, 0, 1)
            add(b, sparkle * np.exp(-(dist / 14) ** 2), hot, 1.2)
            b *= np.clip(xx / 8, 0, 1)[..., None] * np.clip((W - xx) / 8, 0, 1)[..., None]
            var.append(to_rgba_additive(b, 0.55, False))
        save("ts_beam_%s.png" % name, np.vstack(var))


if __name__ == "__main__":
    print("communs"); make_common()
    print("tetes")
    head("pod", head_pod); head("slag", head_slag); head("flak", head_flak); head("frost", head_frost)
    head("plasma", head_plasma); head("bolt", head_bolt); head("acid", head_acid); head("missile", head_missile)
    print("impacts")
    for nm, fn in [("slag", imp_slag), ("ice", imp_ice), ("acid", imp_acid), ("pod", imp_pod),
                   ("smoke", imp_smoke), ("plasma", imp_plasma), ("missile", imp_missile)]:
        sheet(nm, fn)
    print("residus"); make_decals()
    print("faisceaux"); make_beams()
    print("ok")
