#!/usr/bin/env python3
"""
PREMIUM VFX GENERATOR FOR TURRET SHOTS
Generates genuine AAA-quality textures for the 9 level turret shot styles:
1. Usine: Weld electrical arc, high-speed sparks, ionization
2. Terres Calcineés: Solar needle laser, orbital convergence, fulgurite glass
3. Ruine Verte: Biomechanical spiked pod, seed vanes, organic spore cloud
4. Forge: Molten slag boulder, incandescent cracks, boiling magma explosion
5. Cité Déchue: Tungsten supersonic flak dart, shrapnel ring, gunpowder blast
6. Cryo: Hexagonal frost crystal orb, glacial dendrites, cryogenic nova
7. Noyau Instable: Quantum plasma orb, confinement rings, branched lightning
8. Ruche: Distended caustic acid globule, viscous droplets, corrosive explosion
9. Citadelle: Mach-diamond missile, military HUD reticle, heavy HE fireball
"""
import os, math, time
import numpy as np
from scipy.ndimage import gaussian_filter, zoom
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "assets", "vfx", "ts")
os.makedirs(OUT, exist_ok=True)

# -----------------------------------------------------------------------------
# CORE MATH UTILITIES
# -----------------------------------------------------------------------------
def grid(w, h=None):
    h = h or w
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return xx, yy

def dist(xx, yy, cx, cy):
    return np.hypot(xx - cx, yy - cy)

def fbm(w, h=None, base=4, octaves=5, seed=0, persistence=0.55):
    h = h or w
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = base * (2 ** o)
        rx = c + 2
        ry = max(2, int(c * h / w) + 2)
        low = rng.random((ry, rx)).astype(np.float32)
        z = zoom(low, (h / low.shape[0], w / low.shape[1]), order=2)[:h, :w]
        out += z * amp
        tot += amp
        amp *= persistence
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)

def domain_warp(w, h=None, strength=18.0, seed=42):
    h = h or w
    n1 = fbm(w, h, base=3, octaves=4, seed=seed)
    n2 = fbm(w, h, base=3, octaves=4, seed=seed + 100)
    xx, yy = grid(w, h)
    xx_w = xx + (n1 - 0.5) * strength * 2.0
    yy_w = yy + (n2 - 0.5) * strength * 2.0
    return xx_w, yy_w

def worley_cells(w, h=None, n_points=24, seed=42):
    h = h or w
    rng = np.random.default_rng(seed)
    pts = rng.random((n_points, 2)).astype(np.float32)
    pts[:, 0] *= w
    pts[:, 1] *= h
    xx, yy = grid(w, h)
    # calculate distance to closest point (F1) and second closest (F2)
    dists = []
    for px, py in pts:
        dists.append((xx - px) ** 2 + (yy - py) ** 2)
    dists = np.sqrt(np.stack(dists, axis=0))
    dists.sort(axis=0)
    f1 = dists[0]
    f2 = dists[1]
    return f1, f2 - f1

def blank(w, h=None):
    return np.zeros((h or w, w, 3), np.float32)

def add(b, mask, col, inten=1.0):
    m = mask * inten
    for c in range(3):
        b[..., c] += m * col[c]
    return b

def bloom(h, k=1.0):
    b = np.zeros_like(h)
    for sig, wt in [(1.5, 0.45), (3.5, 0.40), (8.0, 0.30), (18.0, 0.22), (38.0, 0.15)]:
        for c in range(3):
            b[..., c] += gaussian_filter(h[..., c], sig) * (wt * k)
    return h + b

def tonemap_aces(h):
    x = np.clip(h, 0, None)
    a, bb, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    return np.clip((x * (a * x + bb)) / (x * (c * x + d) + e), 0, 1)

def window(h, w, power=1.4):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.hypot((xx - w * 0.5) / (w * 0.5), (yy - h * 0.5) / (h * 0.5))
    return np.clip((1.0 - d) / 0.25, 0, 1) ** power

def to_rgba_additive(h, k=1.0, win=True, win_power=1.4):
    img = tonemap_aces(bloom(h, k))
    img = np.nan_to_num(img, nan=0.0, posinf=1.0, neginf=0.0)
    if win:
        img = img * window(img.shape[0], img.shape[1], win_power)[..., None]
    a = np.clip(img.max(axis=2), 0, 1)
    rgb = np.clip(img / np.maximum(a[..., None], 1e-4), 0, 1)
    out = np.dstack([rgb, a])
    return np.clip(out * 255.0, 0, 255).astype(np.uint8)

def to_rgba_alpha(rgb, alpha):
    a = np.clip(np.nan_to_num(alpha, nan=0.0), 0, 1)
    c = np.clip(np.nan_to_num(rgb, nan=0.0), 0, 1)
    out = np.dstack([c, a])
    return np.clip(out * 255.0, 0, 255).astype(np.uint8)

def save_png(name, arr):
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT, name), optimize=True)
    print(f"  [OK] {name} ({arr.shape[1]}x{arr.shape[0]})")

# -----------------------------------------------------------------------------
# PALETTES
# -----------------------------------------------------------------------------
WHITE = (1.0, 1.0, 1.0)
CYAN_BRIGHT = (0.45, 1.35, 1.95)
CYAN_DEEP = (0.15, 0.75, 1.5)
GOLD_CORE = (2.2, 1.6, 0.5)
AMBER_HOT = (2.0, 1.1, 0.2)
LAVA_CORE = (2.4, 1.5, 0.5)
LAVA_FLAME = (2.1, 0.65, 0.12)
LAVA_CRUST = (0.28, 0.16, 0.14)
LIME_CORE = (1.2, 2.0, 0.5)
TOXIC_GREEN = (0.45, 1.85, 0.35)
ICE_CORE = (1.1, 1.4, 2.2)
ICE_CYAN = (0.5, 1.1, 1.8)
PLASMA_PURPLE = (1.6, 0.6, 2.1)
PLASMA_ELECTRIC = (0.6, 1.5, 2.0)
MISSILE_FIRE = (2.2, 1.2, 0.35)
SMOKE_DARK = (0.18, 0.17, 0.19)

# =============================================================================
# 1. COMMON VFX TEXTURES (Flare, Smoke, Shock Ring, Streak, Sparks)
# =============================================================================
def build_commons():
    s = 256
    xx, yy = grid(s)
    c = s * 0.5

    # 1. ts_flare.png : Anamorphic high-end cinematic lens flare
    b = blank(s)
    d = dist(xx, yy, c, c)
    # Bright center core
    add(b, np.exp(-(d / 12.0) ** 2), WHITE, 4.0)
    add(b, np.exp(-(d / 32.0) ** 2), (0.9, 0.95, 1.0), 1.2)
    add(b, np.exp(-(d / 75.0) ** 1.5), (0.5, 0.8, 1.0), 0.5)
    # 4 Primary spikes + 4 secondary spikes
    for ang, length, width, inten in [
        (0.0, 124.0, 2.2, 2.6), (math.pi * 0.5, 124.0, 2.2, 2.6),
        (math.pi * 0.25, 78.0, 1.6, 1.4), (-math.pi * 0.25, 78.0, 1.6, 1.4)
    ]:
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        spike = np.exp(-(p / width) ** 2) * np.exp(-np.abs(t) / (length * 0.42))
        add(b, spike, WHITE, inten)
    # Subtle halo ring
    halo = np.exp(-(((d - 64.0) / 7.0) ** 2)) * 0.35
    add(b, halo, (0.7, 0.85, 1.0), 0.8)
    save_png("ts_flare.png", to_rgba_additive(b, k=0.7))

    # 2. ts_smoke.png : Volumetric fractal smoke puff with self-shadowing normals
    n1 = fbm(s, base=4, octaves=5, seed=77)
    n2 = fbm(s, base=7, octaves=4, seed=88)
    d_norm = d / c
    falloff = np.clip((1.0 - d_norm) / 0.45, 0, 1) ** 1.3
    turb = n1 * 0.7 + n2 * 0.3
    density = np.clip((turb - 0.25) * 1.8 * falloff, 0, 1)
    # Light from top-left (-1, -1)
    gx, gy = np.gradient(turb)
    light = np.clip(0.55 - gx * 1.8 - gy * 1.8, 0.2, 1.0)
    smoke_rgb = np.dstack([np.ones((s, s)) * light] * 3)
    save_png("ts_smoke.png", to_rgba_alpha(smoke_rgb, density))

    # 3. ts_ring.png : Crisp supersonic shockwave distortion ring
    b = blank(s)
    r_wave = np.exp(-(((d - 98.0) / 4.2) ** 2)) * 2.2
    r_outer = np.exp(-(((d - 104.0) / 10.0) ** 2)) * 0.7
    r_inner = np.exp(-(((d - 92.0) / 8.0) ** 2)) * 0.5
    noise_mod = fbm(s, base=8, octaves=3, seed=12) * 0.4 + 0.8
    add(b, (r_wave + r_outer + r_inner) * noise_mod, WHITE, 1.4)
    save_png("ts_ring.png", to_rgba_additive(b, k=0.6))

    # 4. ts_streak.png : Smooth high-speed motion streak
    w_st, h_st = 256, 64
    xs, ys = grid(w_st, h_st)
    dy = np.abs(ys - h_st * 0.5)
    t_prof = xs / float(w_st)
    streak_w = 4.0 + 14.0 * (1.0 - t_prof)
    m_core = np.exp(-((dy / 3.0) ** 2)) * (t_prof ** 1.4)
    m_soft = np.exp(-((dy / streak_w) ** 2)) * (t_prof ** 2.0) * 0.7
    b_st = np.zeros((h_st, w_st, 3), np.float32)
    add(b_st, m_core, WHITE, 2.5)
    add(b_st, m_soft, (0.8, 0.9, 1.0), 1.2)
    save_png("ts_streak.png", to_rgba_additive(b_st, k=0.5, win=False))

    # 5. ts_spark.png : Needle spark particle
    w_sp, h_sp = 64, 16
    xsp, ysp = grid(w_sp, h_sp)
    ysp_d = np.abs(ysp - h_sp * 0.5)
    x_t = xsp / float(w_sp)
    spark_m = np.exp(-((ysp_d / 2.2) ** 2)) * (x_t ** 1.2)
    b_sp = np.zeros((h_sp, w_sp, 3), np.float32)
    add(b_sp, spark_m, (2.2, 1.8, 1.2), 3.0)
    save_png("ts_spark.png", to_rgba_additive(b_sp, k=0.4, win=False))

# =============================================================================
# 2. BEAMS (ts_beam_weld, ts_beam_solar, ts_beam_plasma)
# =============================================================================
def build_beams():
    w, h = 256, 256
    # 4 stacked beam strips of height 64 each
    for name, col_core, col_glow in [
        ("ts_beam_weld", WHITE, CYAN_BRIGHT),
        ("ts_beam_solar", WHITE, GOLD_CORE),
        ("ts_beam_plasma", WHITE, (0.4, 1.8, 1.2)),
    ]:
        b = np.zeros((h, w, 3), np.float32)
        for strip_idx in range(4):
            y_base = strip_idx * 64 + 32
            # Horizontal coordinates inside strip
            xs, ys = grid(w, 64)
            y_local = ys - 32.0
            seed = 100 * strip_idx + (42 if "weld" in name else 77)
            # Turbulent filament noise along length
            turb = fbm(w, 64, base=5, octaves=4, seed=seed)
            jitter = (turb[32, :] - 0.5) * (14.0 if "weld" in name else 6.0)
            
            # Distance from jittered beam center
            y_eff = np.abs(y_local - jitter[None, :])
            core_line = np.exp(-((y_eff / (3.2 if "weld" in name else 4.5)) ** 2))
            glow_line = np.exp(-((y_eff / 18.0) ** 2)) * 0.6
            sub_spikes = (np.abs(turb - 0.5) < 0.08) * np.exp(-((y_eff / 28.0) ** 2)) * 0.5
            
            # Place in master buffer
            m_c = core_line
            m_g = glow_line + sub_spikes
            for c_i in range(3):
                b[strip_idx*64:(strip_idx+1)*64, :, c_i] += m_c * col_core[c_i] * 2.8 + m_g * col_glow[c_i] * 1.5
                
        save_png(f"{name}.png", to_rgba_additive(b, k=0.8, win=False))

# =============================================================================
# 3. PROJECTILE HEADS (256x256)
# =============================================================================
def build_heads():
    s = 256
    xx, yy = grid(s)
    c = s * 0.5
    d = dist(xx, yy, c, c)

    # 1. ts_frost_head.png : Hexagonal ice crystal star with sharp glacial needles
    b = blank(s)
    # Central crystalline core
    add(b, np.exp(-(d / 24.0) ** 2), ICE_CORE, 3.5)
    add(b, np.exp(-(d / 65.0) ** 1.8), ICE_CYAN, 0.9)
    # 6 or 8 sharp crystal dendrite needles
    for i in range(8):
        ang = i * (math.pi / 4.0)
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        w_p = np.maximum(2.2 + 0.05 * t, 0.4)
        crystal = np.exp(-(p / w_p) ** 2) * (t > 0) * (t < 95.0) * np.exp(-t / 45.0)
        # Crystal facets
        side_facets = np.exp(-((p - 6.0) / 2.0) ** 2) * (t > 15) * (t < 60) * 0.4
        add(b, crystal + side_facets, ICE_CORE, 2.2)
    save_png("ts_frost_head.png", to_rgba_additive(b, k=0.8))

    # 2. ts_slag_head.png : Volcanic incandescent magma boulder with basalt crust fissures
    b = blank(s)
    f1, diff = worley_cells(s, n_points=32, seed=89)
    cracks = np.exp(-((diff / 4.5) ** 2))
    boulder_shape = np.clip(1.0 - d / 56.0, 0, 1) ** 0.5
    boulder_noise = fbm(s, base=6, octaves=4, seed=51)
    # Glowing fiery heart
    add(b, np.exp(-(d / 38.0) ** 2), LAVA_CORE, 3.2)
    # Fissures of molten fire cutting through basalt
    add(b, boulder_shape * cracks * 2.2, LAVA_CORE, 2.8)
    add(b, boulder_shape * (0.3 + 0.7 * boulder_noise), LAVA_FLAME, 1.4)
    # Outer corona
    add(b, np.exp(-(d / 78.0) ** 1.6), LAVA_FLAME, 0.8)
    save_png("ts_slag_head.png", to_rgba_additive(b, k=0.9))

    # 3. ts_acid_head.png : Viscous caustic bubble with translucent membrane and boiling nucleus
    b = blank(s)
    membrane = np.exp(-(((d - 36.0) / 5.0) ** 2)) * 2.5
    core_acid = np.exp(-(d / 28.0) ** 2) * (0.6 + 0.4 * fbm(s, base=5, seed=14))
    # Secondary trailing micro-droplets
    for drop_angle, drop_dist, r_drop in [(0.4, 62.0, 12.0), (-0.7, 54.0, 9.0), (2.8, 68.0, 14.0)]:
        dx = c + math.cos(drop_angle) * drop_dist
        dy = c + math.sin(drop_angle) * drop_dist
        d_sub = dist(xx, yy, dx, dy)
        add(b, np.exp(-(d_sub / r_drop) ** 2), LIME_CORE, 1.8)
        add(b, np.exp(-(((d_sub - r_drop*0.9)/2.5)**2)), WHITE, 1.2)
    add(b, membrane, WHITE, 2.0)
    add(b, core_acid, TOXIC_GREEN, 3.2)
    add(b, np.exp(-(d / 72.0) ** 1.4), (0.2, 1.8, 0.4), 0.7)
    save_png("ts_acid_head.png", to_rgba_additive(b, k=0.85))

    # 4. ts_plasma_head.png : High-energy unstable plasma orb with electric arc halo
    b = blank(s)
    # Blinding electric core
    add(b, np.exp(-(d / 26.0) ** 2), WHITE, 4.5)
    add(b, np.exp(-(d / 50.0) ** 1.8), CYAN_BRIGHT, 2.2)
    # Chaotic electric tendrils radiating out
    for i in range(12):
        ang = i * (math.pi / 6.0) + (fbm(s, base=4, seed=i)[128, 128] - 0.5) * 0.8
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        arc = np.exp(-(p / 2.0) ** 2) * (t > 20) * (t < 85) * np.exp(-t / 35.0)
        add(b, arc, WHITE, 2.0)
    # Magnetic confinement rings
    for r_ring in [58.0, 78.0]:
        add(b, np.exp(-(((d - r_ring) / 3.0) ** 2)) * 0.7, (0.3, 1.8, 1.4), 1.2)
    save_png("ts_plasma_head.png", to_rgba_additive(b, k=0.9))

    # 5. ts_bolt_head.png : High-voltage lightning spearhead with branched tail
    b = blank(s)
    # Pointed lightning arrow pointing right (+X)
    dx = xx - c
    dy = yy - c
    t_fwd = dx
    p_lat = np.abs(dy)
    # Spear tip at +X, tail at -X
    tip_cone = (t_fwd < 70) * (t_fwd > -60) * np.exp(-(p_lat / (4.0 + (70 - t_fwd) * 0.15)) ** 2)
    add(b, tip_cone, WHITE, 3.8)
    add(b, tip_cone * np.exp(-(p_lat / 18.0) ** 2), (0.4, 2.0, 1.2), 1.6)
    # Trailing electric tendrils
    for k in [-1, 1]:
        branch = np.exp(-(((dy - k * 22.0 - (t_fwd + 40) * 0.3) / 3.0) ** 2)) * (t_fwd < 10) * (t_fwd > -80)
        add(b, branch, (0.5, 2.2, 1.4), 1.8)
    save_png("ts_bolt_head.png", to_rgba_additive(b, k=0.85))

    # 6. ts_flak_head.png : Supersonic tungsten dart with Mach shockwave cone
    b = blank(s)
    # Dart body aligned with +X
    dx = xx - c
    dy = yy - c
    body = (dx > -50) * (dx < 50) * np.exp(-((dy / 4.0) ** 2))
    tip_hot = np.exp(-(((dx - 48.0) ** 2 + dy ** 2) / 32.0)) * 4.0
    # Mach cone shockwave angled back
    mach_dist = np.abs(dy) - (50 - dx) * 0.55
    mach_shock = (dx < 50) * (dx > -80) * np.exp(-((mach_dist / 4.5) ** 2)) * np.exp(-(50 - dx) / 60.0)
    add(b, body, (2.2, 1.8, 1.4), 3.0)
    add(b, tip_hot, WHITE, 4.0)
    add(b, mach_shock, (2.2, 1.1, 0.3), 2.2)
    save_png("ts_flak_head.png", to_rgba_additive(b, k=0.8))

    # 7. ts_pod_head.png : Biomechanical spiked jungle seed with samara wings
    b = blank(s)
    # Pod body
    pod_core = np.exp(-(d / 32.0) ** 2) * 2.5
    add(b, pod_core, LIME_CORE, 2.0)
    # 3 Rotating swept biomechanical wings
    for k in range(3):
        ang = k * (2.0 * math.pi / 3.0)
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        w_w = np.maximum(6.0 + 0.15 * t, 0.5)
        wing = np.exp(-(p / w_w) ** 2) * (t > 15) * (t < 80) * np.exp(-((t - 45) / 25.0) ** 2)
        edge = np.exp(-(((p - 4.0) / 1.5) ** 2)) * (t > 20) * (t < 75)
        add(b, wing, (0.5, 1.8, 0.4), 1.8)
        add(b, edge, WHITE, 2.0)
    save_png("ts_pod_head.png", to_rgba_additive(b, k=0.85))

    # 8. ts_missile_head.png : Precision military missile with rocket nozzle Mach shock diamonds
    b = blank(s)
    # Missile body: cylinder with sharp nosecone pointing right (+X)
    dx = xx - c
    dy = yy - c
    fuselage = (dx > -35) * (dx < 35) * np.exp(-((dy / 5.5) ** 2))
    w_nose = np.maximum(5.5 * (1.0 - (dx - 35) / 20.0), 0.5)
    nose = (dx >= 35) * (dx < 55) * np.exp(-((dy / w_nose) ** 2))
    fins = (dx > -35) * (dx < -15) * np.exp(-(((np.abs(dy) - 14.0) / 2.5) ** 2))
    # Rocket exhaust plume pointing left (-X)
    ex_len = np.abs(dx + 35)
    exhaust = (dx <= -35) * (dx > -110) * np.exp(-((dy / (3.5 + ex_len * 0.12)) ** 2)) * np.exp(-ex_len / 35.0)
    # Mach diamonds in exhaust
    mach_diamonds = (dx <= -42) * (dx > -95) * (np.sin((dx + 35) * 0.35) ** 2 > 0.6) * np.exp(-((dy / 3.0) ** 2))
    add(b, fuselage + nose + fins, (1.8, 1.9, 2.0), 2.2)
    add(b, exhaust, (0.6, 1.4, 2.2), 3.0)
    add(b, mach_diamonds, WHITE, 4.0)
    save_png("ts_missile_head.png", to_rgba_additive(b, k=0.8))

# =============================================================================
# 4. IMPACT ANIMATION SHEETS (4x4 = 16 Frames of 192x192 = 768x768)
# =============================================================================
def build_impact_sheet(name, frame_renderer):
    frame_sz = 192
    sheet_sz = frame_sz * 4 # 768x768
    master = Image.new("RGBA", (sheet_sz, sheet_sz), (0, 0, 0, 0))
    for f in range(16):
        col_idx = f % 4
        row_idx = f // 4
        u = float(f) / 15.0 # progress 0.0 to 1.0
        frame_arr = frame_renderer(frame_sz, u, f)
        frame_im = Image.fromarray(frame_arr, "RGBA")
        master.paste(frame_im, (col_idx * frame_sz, row_idx * frame_sz))
    master.save(os.path.join(OUT, f"{name}.png"), optimize=True)
    print(f"  [OK IMPACT] {name}.png (768x768, 16 frames)")

def render_slag_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    
    # Expanding lava fireball with molten droplets flying outward
    r_core = 18.0 + 64.0 * (u ** 0.6)
    fade = np.clip((1.0 - u) / 0.55, 0, 1)
    
    # Molten central blast
    core_mask = np.exp(-((d / max(r_core, 1.0)) ** 2)) * fade
    turb = fbm(sz, base=5, seed=f + 20)
    add(b, core_mask * (0.6 + 0.4 * turb), LAVA_CORE if u < 0.4 else LAVA_FLAME, 3.5 * fade)
    
    # Molten lava droplets ejected radially
    rng = np.random.default_rng(f + 99)
    for p_i in range(24):
        ang = p_i * (math.pi / 12.0) + rng.uniform(-0.15, 0.15)
        spd = 18.0 + (p_i % 5) * 16.0
        p_dist = spd * (u ** 0.7) * 4.5
        px = c + math.cos(ang) * p_dist
        py = c + math.sin(ang) * p_dist + (u ** 2) * 22.0 # gravity drop
        d_p = dist(xx, yy, px, py)
        p_size = 4.0 + 3.0 * (1.0 - u)
        drop = np.exp(-((d_p / p_size) ** 2)) * fade
        add(b, drop, LAVA_CORE if u < 0.5 else LAVA_FLAME, 3.0 * fade)
        
    return to_rgba_additive(b, k=0.9)

def render_ice_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.5, 0, 1)
    
    # Cryogenic shockwave ring expanding
    r_shock = 15.0 + 72.0 * (u ** 0.55)
    shock = np.exp(-(((d - r_shock) / (6.0 + 12.0 * u)) ** 2)) * fade
    add(b, shock, ICE_CYAN, 2.5 * fade)
    
    # Sharp angular ice crystal shards shattering outwards
    for i in range(16):
        ang = i * (math.pi / 8.0) + math.sin(i * 3.7) * 0.2
        shard_dist = (20.0 + (i % 4) * 22.0) * (u ** 0.7) * 3.5
        sx = c + math.cos(ang) * shard_dist
        sy = c + math.sin(ang) * shard_dist
        d_s = dist(xx, yy, sx, sy)
        shard = np.exp(-(d_s / (5.0 * (1.0 - u * 0.5))) ** 2) * fade
        add(b, shard, WHITE, 3.2 * fade)
        
    # Freezing mist vapor in the center
    mist = np.exp(-(d / (40.0 + 40.0 * u)) ** 2) * fbm(sz, base=4, seed=f + 30) * fade
    add(b, mist, ICE_CYAN, 1.4 * fade)
    return to_rgba_additive(b, k=0.85)

def render_acid_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.55, 0, 1)
    
    # Corrosive liquid splash crown expanding
    r_splash = 12.0 + 60.0 * (u ** 0.5)
    turb = fbm(sz, base=6, seed=f + 40)
    crown = np.exp(-(((d - r_splash) / (7.0 + 10.0 * u)) ** 2)) * (0.6 + 0.4 * turb) * fade
    add(b, crown, TOXIC_GREEN, 3.0 * fade)
    
    # Spattering acid droplets
    for i in range(18):
        ang = i * (math.pi / 9.0) + (i % 3) * 0.2
        drop_d = (16.0 + (i % 5) * 14.0) * (u ** 0.65) * 3.8
        dx = c + math.cos(ang) * drop_d
        dy = c + math.sin(ang) * drop_d + (u ** 1.8) * 16.0
        d_p = dist(xx, yy, dx, dy)
        add(b, np.exp(-(d_p / 4.0) ** 2) * fade, LIME_CORE, 2.8 * fade)
        
    # Smoking center
    add(b, np.exp(-(d / (35.0 + 35.0 * u)) ** 2) * fade * 0.5, (0.3, 1.8, 0.4), 1.2 * fade)
    return to_rgba_additive(b, k=0.85)

def render_pod_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.55, 0, 1)
    
    # Bioluminescent spore cloud burst
    spore_cloud = fbm(sz, base=5, seed=f + 60) * np.exp(-(d / (25.0 + 55.0 * u)) ** 2) * fade
    add(b, spore_cloud, (0.6, 2.2, 0.5), 3.0 * fade)
    
    # 6 Splintering thorns shooting outward
    for i in range(6):
        ang = i * (math.pi / 3.0) + 0.2
        thorn_d = 20.0 + 90.0 * (u ** 0.8)
        tx = c + math.cos(ang) * thorn_d
        ty = c + math.sin(ang) * thorn_d
        d_th = dist(xx, yy, tx, ty)
        add(b, np.exp(-(d_th / 4.5) ** 2) * fade, WHITE, 3.5 * fade)
    return to_rgba_additive(b, k=0.85)

def render_plasma_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.45, 0, 1)
    
    # High-intensity electrical flash core
    r_core = 35.0 * (1.0 - u * 0.7)
    add(b, np.exp(-(d / max(r_core, 1.0)) ** 2) * fade, WHITE, 4.5 * fade)
    
    # Violent lightning branches discharging outward
    for i in range(14):
        ang = i * (math.pi / 7.0) + math.sin(i * 5.2) * 0.3
        len_arc = (30.0 + (i % 3) * 25.0) * (u ** 0.5) * 3.2
        ax = c + math.cos(ang) * len_arc
        ay = c + math.sin(ang) * len_arc
        d_a = dist(xx, yy, ax, ay)
        add(b, np.exp(-(d_a / 3.5) ** 2) * fade, CYAN_BRIGHT, 3.0 * fade)
        
    # Expanding electromagnetic halo ring
    r_ring = 18.0 + 75.0 * (u ** 0.5)
    ring_m = np.exp(-(((d - r_ring) / 6.0) ** 2)) * fade
    add(b, ring_m, (0.4, 1.6, 2.2), 2.2 * fade)
    return to_rgba_additive(b, k=0.9)

def render_missile_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.55, 0, 1)
    
    # Expanding fiery high-explosive fireball
    r_blast = 16.0 + 68.0 * (u ** 0.55)
    turb = fbm(sz, base=5, octaves=4, seed=f + 88)
    fire = np.exp(-((d / max(r_blast, 1.0)) ** 2)) * (0.5 + 0.5 * turb) * fade
    add(b, fire, MISSILE_FIRE if u < 0.45 else (2.0, 0.6, 0.1), 3.8 * fade)
    
    # Bright center flash
    add(b, np.exp(-(d / (18.0 * (1.0 - u * 0.8))) ** 2) * fade, WHITE, 4.5 * fade)
    
    # Shrapnel spark trails
    for i in range(16):
        ang = i * (math.pi / 8.0) + (i % 3) * 0.15
        s_dist = (25.0 + (i % 4) * 20.0) * (u ** 0.75) * 3.5
        sx = c + math.cos(ang) * s_dist
        sy = c + math.sin(ang) * s_dist
        d_s = dist(xx, yy, sx, sy)
        add(b, np.exp(-(d_s / 3.0) ** 2) * fade, WHITE, 3.0 * fade)
    return to_rgba_additive(b, k=0.9)

def render_smoke_impact(sz, u, f):
    # Shrapnel flak burst (NO MORE BICYCLE WHEEL!)
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.5, 0, 1)
    
    # Shrapnel fragmentation burst ring
    r_shrap = 18.0 + 72.0 * (u ** 0.6)
    shrap_ring = np.exp(-(((d - r_shrap) / (4.0 + 8.0 * u)) ** 2)) * fade
    turb = fbm(sz, base=6, seed=f + 120)
    add(b, shrap_ring * (0.4 + 0.6 * turb), (2.2, 1.5, 0.7), 3.0 * fade)
    
    # 20 Hot tungsten fragments flying in irregular cloud
    for i in range(20):
        ang = i * (math.pi / 10.0) + math.sin(i * 2.3) * 0.25
        f_dist = (15.0 + (i % 5) * 16.0) * (u ** 0.7) * 3.8
        fx = c + math.cos(ang) * f_dist
        fy = c + math.sin(ang) * f_dist
        d_f = dist(xx, yy, fx, fy)
        add(b, np.exp(-(d_f / 3.2) ** 2) * fade, WHITE, 3.5 * fade)
        
    return to_rgba_additive(b, k=0.85)

# =============================================================================
# 5. DECALS & GLOW RESIDUES (384x384)
# =============================================================================
def build_decals():
    s = 384
    xx, yy = grid(s)
    c = s * 0.5
    d = dist(xx, yy, c, c)
    d_norm = d / c
    falloff = np.clip((1.0 - d_norm) / 0.35, 0, 1) ** 1.4

    # 1. ts_slag_decal.png & ts_slag_glow.png : Basalt crust with lava veins
    f1, diff = worley_cells(s, n_points=40, seed=33)
    turb = fbm(s, base=5, seed=77)
    cracks = np.exp(-((diff / 6.0) ** 2)) * falloff
    basalt = np.clip((0.2 + 0.4 * turb) * falloff, 0, 1)
    # Decal (normal blend)
    decal_rgb = np.dstack([
        basalt * 0.18 + cracks * 0.65,
        basalt * 0.15 + cracks * 0.25,
        basalt * 0.14 + cracks * 0.05
    ])
    save_png("ts_slag_decal.png", to_rgba_alpha(decal_rgb, falloff * 0.95))
    # Glow (additive)
    b_glow = blank(s)
    add(b_glow, cracks * 2.5, LAVA_CORE, 2.5)
    add(b_glow, np.exp(-(d / 95.0) ** 2), LAVA_FLAME, 1.2)
    save_png("ts_slag_glow.png", to_rgba_additive(b_glow, k=0.9))

    # 2. ts_acid_decal.png & ts_acid_glow.png : Caustic bubbling sludge
    n_acid = fbm(s, base=4, seed=91)
    puddle = np.clip((1.0 - d_norm + (n_acid - 0.5) * 0.6) / 0.35, 0, 1) ** 1.5
    f1_a, diff_a = worley_cells(s, n_points=32, seed=65)
    bubbles = np.exp(-((f1_a / 12.0) ** 2)) * puddle
    decal_acid = np.dstack([
        puddle * 0.25 + bubbles * 0.5,
        puddle * 0.55 + bubbles * 0.9,
        puddle * 0.15 + bubbles * 0.2
    ])
    save_png("ts_acid_decal.png", to_rgba_alpha(decal_acid, puddle * 0.9))
    b_aglow = blank(s)
    add(b_aglow, bubbles * 2.0 + puddle * 0.6, LIME_CORE, 2.2)
    save_png("ts_acid_glow.png", to_rgba_additive(b_aglow, k=0.85))

    # 3. ts_frost_decal.png & ts_frost_glow.png : Intricate frost crystal dendrites
    frost_n = fbm(s, base=6, octaves=5, seed=108)
    crystal_pattern = np.clip(np.abs(np.sin(xx * 0.12) * np.cos(yy * 0.12) + frost_n * 0.8), 0, 1) * falloff
    decal_frost = np.dstack([
        crystal_pattern * 0.75,
        crystal_pattern * 0.90,
        crystal_pattern * 1.0
    ])
    save_png("ts_frost_decal.png", to_rgba_alpha(decal_frost, falloff * 0.88))
    b_fglow = blank(s)
    add(b_fglow, crystal_pattern * 1.8, ICE_CORE, 2.0)
    save_png("ts_frost_glow.png", to_rgba_additive(b_fglow, k=0.8))

    # 4. ts_spores_decal.png & ts_spores_glow.png : Fungal spores bloom
    spore_puddle = fbm(s, base=5, seed=112) * falloff
    decal_spore = np.dstack([
        spore_puddle * 0.35,
        spore_puddle * 0.75,
        spore_puddle * 0.25
    ])
    save_png("ts_spores_decal.png", to_rgba_alpha(decal_spore, spore_puddle * 0.92))
    b_sglow = blank(s)
    add(b_sglow, spore_puddle * 2.2, (0.5, 2.2, 0.4), 2.0)
    save_png("ts_spores_glow.png", to_rgba_additive(b_sglow, k=0.85))

    # 5. ts_glass_decal.png & ts_glass_glow.png : Vitrified molten fulgurite trench
    # Dimensions: 256 x 64
    w_g, h_g = 256, 64
    xg, yg = grid(w_g, h_g)
    yg_d = np.abs(yg - h_g * 0.5)
    g_crack = fbm(w_g, h_g, base=5, seed=44)
    trench = np.exp(-((yg_d / (8.0 + g_crack[32, :] * 4.0)) ** 2))
    decal_glass = np.dstack([
        trench * 0.85,
        trench * 0.70,
        trench * 0.45
    ])
    save_png("ts_glass_decal.png", to_rgba_alpha(decal_glass, trench * 0.9))
    b_gglow = np.zeros((h_g, w_g, 3), np.float32)
    add(b_gglow, np.exp(-((yg_d / 4.5) ** 2)), GOLD_CORE, 3.2)
    add(b_gglow, trench * 0.7, AMBER_HOT, 1.8)
    save_png("ts_glass_glow.png", to_rgba_additive(b_gglow, k=0.8, win=False))

# =============================================================================
# MAIN EXECUTION
# =============================================================================
def main():
    t0 = time.time()
    print("=== STARTING GENERATION OF PREMIUM TURRET SHOT VFX ===")
    print("\n--- 1. Generating Commons ---")
    build_commons()
    print("\n--- 2. Generating Continuous Beams ---")
    build_beams()
    print("\n--- 3. Generating Projectile Heads ---")
    build_heads()
    print("\n--- 4. Generating Decals & Ground Resides ---")
    build_decals()
    print("\n--- 5. Generating 16-Frame Impact Sheets ---")
    build_impact_sheet("ts_slag_impact", render_slag_impact)
    build_impact_sheet("ts_ice_impact", render_ice_impact)
    build_impact_sheet("ts_acid_impact", render_acid_impact)
    build_impact_sheet("ts_pod_impact", render_pod_impact)
    build_impact_sheet("ts_plasma_impact", render_plasma_impact)
    build_impact_sheet("ts_missile_impact", render_missile_impact)
    build_impact_sheet("ts_smoke_impact", render_smoke_impact)
    
    dt = time.time() - t0
    print(f"\n=== COMPLETED IN {dt:.1f}s — ALL PREMIUM VFX GENERATED ===")

if __name__ == "__main__":
    main()
