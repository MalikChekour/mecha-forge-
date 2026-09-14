#!/usr/bin/env python3
"""
VFX SHOWCASE — a wide sampler of ANIMATED special effects, procedurally generated (numpy/scipy),
every one a game-ready horizontal sprite sheet on black (additive-blend). Also emits a GIF per
effect for a catalog. Styles span: realistic, anime, pixel, elemental, magic, sci-fi, digital.

  python vfx_showcase.py            -> refs/vfx_showcase/<name>.png (sheet) + <name>.gif (preview)
"""
import numpy as np, os
from scipy.ndimage import zoom, gaussian_filter
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "refs", "vfx_showcase")
os.makedirs(OUT, exist_ok=True)
S = 100          # frame size
NF = 16          # frames per effect

def grid():
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    return xx - S / 2, yy - S / 2, np.hypot(xx - S / 2, yy - S / 2), np.arctan2(yy - S / 2, xx - S / 2)

def vnoise(h, w, cell, seed):
    rng = np.random.default_rng(seed)
    low = rng.random((h // cell + 2, w // cell + 2))
    return zoom(low, cell, order=1)[:h, :w]

def ramp(t, stops):
    # t in 0..1 -> rgb from (pos,(r,g,b)) stops
    pos = np.array([s[0] for s in stops]); cols = np.array([s[1] for s in stops], float)
    out = np.zeros(t.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(t, pos, cols[:, c])
    return out

def frames_to_sheet(frames):
    # frames: list of (rgb[H,W,3] 0..1, a[H,W] 0..1)
    sheet = Image.new("RGBA", (S * len(frames), S), (0, 0, 0, 0))
    for i, (rgb, a) in enumerate(frames):
        arr = np.zeros((S, S, 4), np.uint8)
        arr[..., :3] = np.clip(rgb, 0, 1) * 255
        arr[..., 3] = np.clip(a, 0, 1) * 255
        sheet.paste(Image.fromarray(arr, "RGBA"), (i * S, 0))
    return sheet

def save(name, frames, gif_bg=(10, 10, 16)):
    frames_to_sheet(frames).save(os.path.join(OUT, name + ".png"))
    gif = []
    for rgb, a in frames:
        base = np.array(gif_bg, float) / 255
        comp = base[None, None, :] * (1 - a[..., None]) + np.clip(rgb, 0, 1) * a[..., None]  # over dark
        # additive feel: also add a bit of the glow
        comp = np.clip(comp + np.clip(rgb, 0, 1) * a[..., None] * 0.5, 0, 1)
        gif.append(Image.fromarray((comp * 255).astype(np.uint8)).convert("P", palette=Image.ADAPTIVE))
    gif[0].save(os.path.join(OUT, name + ".gif"), save_all=True, append_images=gif[1:],
                duration=60, loop=0, disposal=2)
    print(f"  {name:16s} {len(frames)}f")

X, Y, R, TH = grid()

# ---------------------------------------------------------------- REALISTIC
def fireball():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        rad = 8 + t * 40
        n = vnoise(S, S, 12, 1) + 0.6 * vnoise(S, S, 6, 2)
        n = gaussian_filter(n, 1.5); n /= n.max()
        turb = np.clip(1 - R / rad, 0, 1) * (0.5 + 0.7 * n)
        heat = np.clip(turb * (1.4 - t), 0, 1)
        rgb = ramp(heat, [(0, (0, 0, 0)), (.3, (.6, .05, 0)), (.6, (1, .4, 0)), (.85, (1, .8, .2)), (1, (1, 1, .9))])
        a = np.clip(heat * 1.6, 0, 1) * (1 - t * 0.3)
        fr.append((rgb, a))
    return fr

def smoke():
    fr = []
    tall = vnoise(S * 2, S, 16, 7) + 0.5 * vnoise(S * 2, S, 8, 8)
    for i in range(NF):
        t = i / (NF - 1)
        off = int(t * S)
        n = gaussian_filter(tall[off:off + S], 2.0)
        dens = np.clip(1 - R / (18 + t * 34), 0, 1) * (n / n.max())
        dens = gaussian_filter(dens, 1.5)
        g = 0.35 + 0.15 * (n / n.max())
        rgb = np.stack([g, g, g * 1.05], -1)
        a = np.clip(dens * 1.4, 0, 1) * (1 - t * 0.55)
        fr.append((rgb, a))
    return fr

def sparks():
    rng = np.random.default_rng(11)
    N = 60
    ang = rng.random(N) * 2 * np.pi; spd = 2 + rng.random(N) * 3.4
    fr = []
    for i in range(NF):
        t = i / (NF - 1); img = np.zeros((S, S));
        for k in range(N):
            d = spd[k] * i * (1 - i / (NF * 2.2))
            x = int(S / 2 + np.cos(ang[k]) * d); y = int(S / 2 + np.sin(ang[k]) * d + 0.15 * i * i)
            if 1 <= x < S - 1 and 1 <= y < S - 1:
                img[y, x] = 1; img[y - 1, x] = 0.5
        img = gaussian_filter(img, 0.6)
        rgb = ramp(np.clip(img, 0, 1), [(0, (0, 0, 0)), (.5, (1, .5, .1)), (1, (1, 1, .8))])
        fr.append((rgb, np.clip(img * 1.8, 0, 1) * (1 - t * 0.4)))
    return fr

# ---------------------------------------------------------------- ANIME / STYLISED
def anime_impact():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        sc = min(1, t * 3); fade = 1 if t < .5 else 1 - (t - .5) * 2
        spikes = (0.5 + 0.5 * np.cos(6 * TH)) ** 8       # 6-point star
        star = np.clip(1 - R / (10 + sc * 42) / (0.4 + 0.6 * spikes), 0, 1)
        core = np.clip(1 - R / (sc * 20 + 4), 0, 1) ** 2
        v = np.clip(star * 0.8 + core, 0, 1) * fade
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (1, .85, .2)), (.8, (1, 1, .8)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

def slash():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        ang0 = -1.1 + t * 2.2
        arc = np.exp(-((TH - ang0) * 3.0) ** 2) * np.exp(-((R - 34) / 10) ** 2)
        arc += 0.4 * np.exp(-((TH - ang0 + .25) * 4) ** 2) * np.exp(-((R - 34) / 14) ** 2)
        v = np.clip(arc, 0, 1) * (1 - abs(t - .5))
        rgb = ramp(v, [(0, (0, 0, 0)), (.5, (.2, .8, 1)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 2, 0, 1)))
    return fr

def nova():
    fr = []
    rays = (0.5 + 0.5 * np.cos(12 * TH)) ** 3
    for i in range(NF):
        t = i / (NF - 1)
        rad = t * 46
        ring = np.exp(-((R - rad) / (4 + t * 8)) ** 2)
        v = np.clip(ring * (0.4 + 0.6 * rays) + np.clip(1 - R / (rad + 2), 0, 1) * (1 - t), 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (1, .9, .4)), (.8, (1, 1, .8)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.5, 0, 1) * (1 - t * 0.3)))
    return fr

# ---------------------------------------------------------------- ELEMENTAL
def lightning():
    fr = []
    for i in range(NF):
        rng = np.random.default_rng(100 + i)
        img = np.zeros((S, S))
        x = S / 2
        pts = [(x, 4)]
        for y in range(4, S - 4, 4):
            x += rng.normal(0, 6); pts.append((np.clip(x, 6, S - 6), y))
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            for s in np.linspace(0, 1, 8):
                xx = int(x0 + (x1 - x0) * s); yy = int(y0 + (y1 - y0) * s)
                if 0 <= xx < S and 0 <= yy < S: img[yy, xx] = 1
        img = gaussian_filter(img, 1.0) * 3
        glow = gaussian_filter(img, 4) * 0.6
        v = np.clip(img + glow, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.3, .5, 1)), (.8, (.7, .85, 1)), (1, (1, 1, 1))])
        fr.append((rgb, v))
    return fr

def frost():
    fr = []
    spike = (0.5 + 0.5 * np.cos(8 * TH)) ** 6
    for i in range(NF):
        t = i / (NF - 1)
        rad = 6 + t * 40
        sh = np.clip(1 - R / rad, 0, 1) * (0.25 + 0.75 * spike)
        edge = np.exp(-((R - rad) / 3) ** 2) * spike
        v = np.clip(sh * 0.7 + edge, 0, 1) * (1 - t * 0.3)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.4, .7, 1)), (.8, (.8, .95, 1)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

def toxic():
    fr = []
    tall = vnoise(S, S * 2, 14, 21)
    for i in range(NF):
        t = i / (NF - 1); off = int(t * S)
        n = gaussian_filter(np.roll(vnoise(S, S, 12, 21 + i), (0, off), (0, 1)), 2)
        dens = np.clip(1 - R / (16 + t * 30), 0, 1) * (n / n.max())
        bub = (n > 0.72).astype(float)
        v = np.clip(dens + gaussian_filter(bub, 1) * 0.6, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.2, .5, .05)), (.8, (.5, .95, .2)), (1, (.8, 1, .5))])
        fr.append((rgb, np.clip(v * 1.2, 0, 1) * (1 - t * 0.4)))
    return fr

def fire_jet():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        n = gaussian_filter(vnoise(S, S, 10, 30 + i), 1.5); n /= n.max()
        cone = np.clip(1 - np.abs(X) / (6 + (Y + S / 2) * 0.35), 0, 1) * np.clip((S / 2 - Y) / S, 0, 1)
        heat = np.clip(cone * (0.6 + 0.8 * n), 0, 1)
        rgb = ramp(heat, [(0, (0, 0, 0)), (.35, (.7, .1, 0)), (.65, (1, .5, 0)), (.9, (1, .85, .3)), (1, (1, 1, .9))])
        fr.append((rgb, np.clip(heat * 1.5, 0, 1)))
    return fr

# ---------------------------------------------------------------- MAGIC / SCI-FI
def rune_circle():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); rot = t * 1.2; fade = min(1, t * 3) * (1 if t < .7 else 1 - (t - .7) / .3)
        ring = np.exp(-((R - 36) / 1.5) ** 2) + np.exp(-((R - 30) / 1.0) ** 2)
        ticks = ((np.cos((TH - rot) * 24) > 0.6) & (np.abs(R - 33) < 5)).astype(float)
        tri = 0
        for a in range(3):
            aa = rot + a * 2 * np.pi / 3
            d = np.abs(np.cos(TH - aa) * R)
            tri = np.maximum(tri, np.exp(-((R - 26) / 2) ** 2) * (np.cos(TH - aa) > .3))
        v = np.clip((ring + ticks * 0.8 + tri * 0.5) * fade, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (1, .7, .1)), (.8, (1, .9, .4)), (1, (1, 1, .85))])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

def portal():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); rot = t * 3
        spiral = 0.5 + 0.5 * np.cos(TH * 3 - R * 0.35 + rot * 4)
        disk = np.clip(1 - R / (12 + t * 34), 0, 1)
        v = np.clip(disk * (0.3 + 0.9 * spiral), 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.4, .1, .7)), (.75, (.7, .3, 1)), (1, (1, .8, 1))])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

def plasma_orb():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        pulse = 20 + 4 * np.sin(t * 6.28 * 2)
        n = gaussian_filter(vnoise(S, S, 8, 40 + i), 1.5); n /= n.max()
        orb = np.clip(1 - R / pulse, 0, 1) ** 1.4
        arc = np.exp(-((R - pulse) / 3) ** 2) * (0.4 + 0.6 * n)
        v = np.clip(orb * (0.6 + 0.6 * n) + arc, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.1, .5, 1)), (.75, (.4, .9, 1)), (1, (.9, 1, 1))])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

def shockwave():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); rad = t * 46
        ring = np.exp(-((R - rad) / (2 + t * 4)) ** 2)
        ring += 0.4 * np.exp(-((R - rad * 0.7) / 3) ** 2)
        v = np.clip(ring, 0, 1) * (1 - t * 0.6)
        rgb = ramp(v, [(0, (0, 0, 0)), (.5, (.5, .8, 1)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

def beam_core():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); w = 4 + 3 * np.sin(t * 12)
        core = np.exp(-(Y / w) ** 2)
        glow = np.exp(-(Y / (w * 3)) ** 2) * 0.5
        flick = 0.7 + 0.3 * np.sin(t * 20 + X * 0.3)
        v = np.clip((core + glow) * flick, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.5, (.2, .8, 1)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.4, 0, 1)))
    return fr

def muzzle():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); fade = 1 - t
        # cone pointing RIGHT (+X)
        fwd = np.clip(X / (10 + 26 * (1 - t * .3)), 0, 1)
        cone = np.clip(1 - np.abs(Y) / (4 + X * 0.5), 0, 1) * (X > 0) * np.clip(1 - fwd, 0, 1)
        n = vnoise(S, S, 8, 50 + i)
        v = np.clip(cone * (0.6 + 0.8 * n) + np.clip(1 - R / 8, 0, 1), 0, 1) * fade
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (1, .6, .1)), (.8, (1, .9, .4)), (1, (1, 1, .9))])
        fr.append((rgb, np.clip(v * 1.7, 0, 1)))
    return fr

def heal():
    rng = np.random.default_rng(5); N = 26
    px = rng.random(N) * S; ph = rng.random(N) * 2 * np.pi
    fr = []
    for i in range(NF):
        t = i / (NF - 1); img = np.zeros((S, S))
        for k in range(N):
            y = int((1 - ((t + px[k] / S) % 1)) * S); x = int(px[k] + 4 * np.sin(ph[k] + t * 6))
            if 2 <= x < S - 2 and 2 <= y < S - 2:
                img[y, x] = 1; img[y, x - 1] = img[y, x + 1] = img[y - 1, x] = img[y + 1, x] = .6  # plus sign
        img = gaussian_filter(img, 0.7)
        col = np.clip(1 - R / 46, 0, 1) * 0.3
        rgb = ramp(np.clip(img + col, 0, 1), [(0, (0, 0, 0)), (.4, (.2, .8, .3)), (1, (.8, 1, .85))])
        fr.append((rgb, np.clip(img * 1.6 + col * 0.5, 0, 1)))
    return fr

# ---------------------------------------------------------------- PIXEL / DIGITAL
def pixel_explosion():
    fr = []; P = 22  # low-res grid -> retro
    for i in range(NF):
        t = i / (NF - 1)
        yy, xx = np.mgrid[0:P, 0:P].astype(float); r = np.hypot(xx - P / 2, yy - P / 2)
        rad = 2 + t * 11
        ring = ((r < rad) & (r > rad - 3 - t * 2)).astype(float)
        core = (r < rad * 0.5 * (1 - t)).astype(float)
        rng = np.random.default_rng(60 + i)
        val = np.clip(ring + core, 0, 1) * (rng.random((P, P)) * 0.5 + 0.6)
        # quantise to 4 retro colours
        q = np.digitize(val * (1 - t * .5), [0.15, 0.4, 0.7, 1.1])
        pal = np.array([[0, 0, 0], [.7, .1, .1], [1, .5, .1], [1, .85, .2], [1, 1, .8]])
        rgb = pal[np.clip(q, 0, 4)]
        a = (q > 0).astype(float) * (1 - t * 0.2)
        big_rgb = np.repeat(np.repeat(rgb, S // P + 1, 0), S // P + 1, 1)[:S, :S]
        big_a = np.repeat(np.repeat(a, S // P + 1, 0), S // P + 1, 1)[:S, :S]
        fr.append((big_rgb, big_a))
    return fr

def holo_glitch():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        rng = np.random.default_rng(70 + i)
        base = np.clip(1 - R / 40, 0, 1) ** 0.6
        scan = (0.6 + 0.4 * np.sin(Y * 0.8 + t * 20))
        # rgb split rows
        shift = int(4 * np.sin(t * 15))
        img = base * scan
        glitch_rows = rng.random(S) < 0.15
        img[glitch_rows] *= rng.random(int(glitch_rows.sum()))[:, None] if glitch_rows.sum() else 1
        r = np.roll(img, shift, 1); b = np.roll(img, -shift, 1); g = img
        rgb = np.stack([r * 0.3, g * 0.9, b * 1.0], -1)
        a = np.clip(img * 1.3, 0, 1)
        fr.append((rgb, a))
    return fr

def implosion():
    fr = []
    rng = np.random.default_rng(9); N = 40
    ang = rng.random(N) * 2 * np.pi; rad0 = 30 + rng.random(N) * 16
    for i in range(NF):
        t = i / (NF - 1); img = np.zeros((S, S))
        for k in range(N):
            d = rad0[k] * (1 - t)
            x = int(S / 2 + np.cos(ang[k]) * d); y = int(S / 2 + np.sin(ang[k]) * d)
            if 1 <= x < S - 1 and 1 <= y < S - 1: img[y, x] = 1
        img = gaussian_filter(img, 0.8)
        flash = np.clip(1 - R / 30, 0, 1) * max(0, (t - 0.8) * 5)
        v = np.clip(img + flash, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.6, .3, 1)), (.8, (.9, .7, 1)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

# ---------------------------------------------------------------- COMPREHENSIVE EXPANSION (ALL REMAINING GAME VFX)
def bullet_tracer():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); pos = -30 + t * 60
        # fast moving elongated bullet streak along X
        core = np.exp(-(Y ** 2) / 3) * np.exp(-((X - pos) ** 2) / 16)
        trail = np.exp(-(Y ** 2) / 8) * np.clip((pos - X) / 35, 0, 1) * (X < pos)
        v = np.clip(core * 1.5 + trail, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.3, (1, .5, .1)), (.7, (1, .9, .4)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

def shield_ripple():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); rad = 8 + t * 38
        # hex wave or ring ripple
        ring = np.exp(-((R - rad) / 3) ** 2)
        hex_mod = (0.7 + 0.3 * np.cos(6 * TH))
        v = np.clip(ring * hex_mod * (1 - t), 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.1, .6, 1)), (.8, (.5, .9, 1)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.7, 0, 1)))
    return fr

def electric_dome():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); rad = 36
        dome = np.exp(-((R - rad) / 2) ** 2) * (Y < 10)
        n = vnoise(S, S, 10, 200 + i); n /= n.max()
        arcs = (n > 0.68).astype(float) * (R < rad + 4) * (Y < 12)
        v = np.clip((dome + gaussian_filter(arcs, 1) * 1.5) * (1 - t * 0.5), 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.4, .2, 1)), (.8, (.7, .8, 1)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

def ice_patch():
    fr = []
    base_n = vnoise(S, S, 8, 300); base_n /= base_n.max()
    for i in range(NF):
        t = i / (NF - 1); rad = t * 40
        mask = (R < rad * (0.6 + 0.5 * base_n)).astype(float)
        crystals = gaussian_filter(mask, 1.0) * (0.5 + 0.5 * np.cos(R * 1.5 + TH * 4))
        v = np.clip(crystals * (1 - t * 0.2), 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.3, .65, .9)), (.8, (.7, .95, 1)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.4, 0, 1)))
    return fr

def sandstorm():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); off = int(t * S * 1.5)
        n = gaussian_filter(np.roll(vnoise(S, S * 2, 16, 400), off, 1)[:, :S], 2.0)
        n /= n.max()
        wind = np.exp(-(Y ** 2) / 600) * n
        v = np.clip(wind * 1.2, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.6, .4, .15)), (.8, (.9, .7, .3)), (1, (1, .9, .6))])
        fr.append((rgb, np.clip(v * 1.3, 0, 1) * (1 - abs(t - .5) * 0.5)))
    return fr

def overdrive_aura():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        n = gaussian_filter(vnoise(S, S, 12, 500 + i), 1.5); n /= n.max()
        # rising flames/energy tendrils surrounding center
        ring = np.exp(-((R - 22) / 8) ** 2)
        flame = ring * (0.4 + 0.8 * n) * (1 + (Y / (S / 2)) * 0.4)
        v = np.clip(flame * (0.8 + 0.2 * np.sin(t * 12)), 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.35, (1, .2, 0)), (.7, (1, .7, .1)), (1, (1, 1, .7))])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

def shield_raise():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); rad = min(36, t * 50)
        ring = np.exp(-((R - rad) / 2.5) ** 2)
        fill = (R < rad).astype(float) * 0.15
        v = np.clip((ring + fill) * (1 if t < .8 else 1 - (t - .8) * 4), 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.5, (.1, .7, 1)), (1, (.8, 1, 1))])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

def shield_break():
    fr = []
    rng = np.random.default_rng(600); N = 18
    ang = rng.random(N) * 2 * np.pi; spd = 1 + rng.random(N) * 3
    for i in range(NF):
        t = i / (NF - 1); img = np.zeros((S, S))
        for k in range(N):
            d = 36 + spd[k] * i * 2.5
            x = int(S / 2 + np.cos(ang[k]) * d); y = int(S / 2 + np.sin(ang[k]) * d)
            if 2 <= x < S - 2 and 2 <= y < S - 2:
                img[y-1:y+2, x-1:x+2] = 1.0  # shard
        img = gaussian_filter(img, 0.8)
        v = np.clip(img * (1 - t), 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.5, (.2, .6, 1)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.8, 0, 1)))
    return fr

def slow_field():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); rad = 38
        grid_mask = ((np.abs(X) % 10 < 1.5) | (np.abs(Y) % 10 < 1.5)).astype(float)
        disk = (R < rad).astype(float) * np.clip(1 - R / rad, 0, 1)
        pulse = 0.6 + 0.4 * np.sin(t * 4 * np.pi)
        v = np.clip(grid_mask * disk * pulse, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.5, (.5, .1, .9)), (1, (.8, .6, 1))])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

def target_lock():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); dist = 40 * (1 - min(1, t * 1.5)) + 18
        img = np.zeros((S, S))
        # 4 brackets forming square/reticle
        for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            cx = int(S / 2 + dx * dist); cy = int(S / 2 + dy * dist)
            if 4 <= cx < S - 4 and 4 <= cy < S - 4:
                img[cy, cx-3:cx+4] = 1; img[cy-3:cy+4, cx] = 1
        img = gaussian_filter(img, 0.6)
        blink = 1.0 if t < .7 else (0.3 + 0.7 * (int(t * 20) % 2))
        v = np.clip(img * blink, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.5, (1, .2, .2)), (1, (1, .8, .8))])
        fr.append((rgb, np.clip(v * 1.8, 0, 1)))
    return fr

def xp_gem():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); pulse = 0.7 + 0.3 * np.sin(t * 4 * np.pi)
        diamond = np.clip(1 - (np.abs(X) + np.abs(Y)) / (12 * pulse), 0, 1) ** 1.5
        glow = np.exp(-(R ** 2) / 200) * 0.5 * pulse
        v = np.clip(diamond + glow, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (.1, .8, .4)), (.8, (.4, 1, .8)), (1, (1, 1, 1))])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

def gem_absorb():
    fr = []
    for i in range(NF):
        t = i / (NF - 1); dist = 44 * (1 - t)
        # streak moving toward center (0,0)
        pos_x = int(dist * 0.7); pos_y = int(dist * 0.7)
        streak = np.exp(-((X - pos_x) ** 2 + (Y - pos_y) ** 2) / 12)
        trail = np.exp(-((X - pos_x - 6) ** 2 + (Y - pos_y - 6) ** 2) / 25) * 0.5
        v = np.clip(streak + trail, 0, 1) * (1 if t < .9 else (1 - t) * 10)
        rgb = ramp(v, [(0, (0, 0, 0)), (.5, (.2, .9, .5)), (1, (1, 1, .9))])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

def level_up():
    fr = []
    rng = np.random.default_rng(700); N = 24
    ang = rng.random(N) * 2 * np.pi; rad0 = rng.random(N) * 25
    for i in range(NF):
        t = i / (NF - 1); pillar = np.exp(-(X ** 2) / 100) * (1 - t * 0.6)
        img = np.zeros((S, S))
        for k in range(N):
            y = int(S / 2 + rad0[k] - t * 40); x = int(S / 2 + np.cos(ang[k]) * (rad0[k] + t * 10))
            if 2 <= x < S - 2 and 2 <= y < S - 2:
                img[y, x] = 1; img[y-1, x] = img[y+1, x] = img[y, x-1] = img[y, x+1] = 0.5
        img = gaussian_filter(img, 0.7)
        v = np.clip(pillar * 0.6 + img * 1.5, 0, 1)
        rgb = ramp(v, [(0, (0, 0, 0)), (.4, (1, .7, .1)), (.8, (1, .95, .4)), (1, (1, 1, .9))])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

EFFECTS = {
    # realistic
    "fireball": fireball, "smoke": smoke, "sparks": sparks, "fire_jet": fire_jet, "bullet_tracer": bullet_tracer,
    # anime / stylised
    "anime_impact": anime_impact, "slash": slash, "nova": nova,
    # elemental
    "lightning": lightning, "frost": frost, "toxic_cloud": toxic, "electric_dome": electric_dome, "ice_patch": ice_patch, "sandstorm": sandstorm,
    # magic / sci-fi / powers
    "rune_circle": rune_circle, "portal": portal, "plasma_orb": plasma_orb, "shockwave": shockwave, "beam": beam_core, "muzzle_cone": muzzle, "heal": heal,
    "shield_ripple": shield_ripple, "overdrive_aura": overdrive_aura, "shield_raise": shield_raise, "shield_break": shield_break, "slow_field": slow_field, "target_lock": target_lock,
    # pickups / rewards
    "xp_gem": xp_gem, "gem_absorb": gem_absorb, "level_up": level_up,
    # pixel / digital
    "pixel_explosion": pixel_explosion, "holo_glitch": holo_glitch, "implosion": implosion,
}

if __name__ == "__main__":
    print("generating VFX showcase ->", OUT)
    for name, fn in EFFECTS.items():
        save(name, fn())
    print(f"DONE {len(EFFECTS)} effects")
