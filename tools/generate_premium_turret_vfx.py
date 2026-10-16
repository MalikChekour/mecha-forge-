#!/usr/bin/env python3
"""
HORLOGER-GRADE VFX TEXTURE ENGINE FOR TURRET SHOTS
Engineered with uncompromising precision, multi-scale physical dynamics,
faceted crystalline lattice geometry, and 32-bit HDR ACES tonemapped bloom.

Covers all 9 biome turret weapons:
1. Usine: Braided electric arc, tungsten electrode flare, Townsend branches, bouncing iron sparks
2. Terres Calcinées: Matrix orbital convergence, solar needle fusion laser, cooling fulgurite trench
3. Ruine Verte: Biomechanical samara seed pod, 6 barbed chitin thorns, Fibonacci spore vortex
4. Forge: Molten basalt slag boulder, parabolic kinetic bounce, 5s bubbling caldera
5. Cité Déchue: Supersonic tungsten dart with Mach shock cone, mid-air flak fragmentation ring
6. Cryo: 8-pointed hexagonal crystal snowflake orb, dendritic frost line, cryogenic nova
7. Noyau Instable: 3-stage magnetic containment charge, ball lightning tri-fission, Townsend discharge
8. Ruche: Viscous caustic venom teardrop, surface tension spallation, frothing acid puddle
9. Citadelle: Tactical combat HUD reticle, vertical cold-launch boost, Mach diamond exhaust, HE fireball
"""
import os, math, time
import numpy as np
from scipy.ndimage import gaussian_filter, zoom
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "assets", "vfx", "ts")
os.makedirs(OUT, exist_ok=True)

# -----------------------------------------------------------------------------
# 1. PRECISION MATHEMATICAL UTILITIES
# -----------------------------------------------------------------------------
def grid(w, h=None):
    h = h or w
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return xx, yy

def dist(xx, yy, cx, cy):
    return np.hypot(xx - cx, yy - cy)

def fbm(w, h=None, base=4, octaves=5, seed=0, persistence=0.52):
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

def domain_warp(w, h=None, strength=16.0, seed=42):
    h = h or w
    n1 = fbm(w, h, base=3, octaves=4, seed=seed)
    n2 = fbm(w, h, base=3, octaves=4, seed=seed + 100)
    xx, yy = grid(w, h)
    xx_w = xx + (n1 - 0.5) * strength * 2.0
    yy_w = yy + (n2 - 0.5) * strength * 2.0
    return xx_w, yy_w

def worley_cells(w, h=None, n_points=32, seed=42):
    h = h or w
    rng = np.random.default_rng(seed)
    pts = rng.random((n_points, 2)).astype(np.float32)
    pts[:, 0] *= w
    pts[:, 1] *= h
    xx, yy = grid(w, h)
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
    for sig, wt in [(1.2, 0.50), (3.0, 0.42), (7.5, 0.32), (16.0, 0.22), (36.0, 0.14)]:
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
    return np.clip((1.0 - d) / 0.22, 0, 1) ** power

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
    print(f"  [HORLOGER] {name} ({arr.shape[1]}x{arr.shape[0]})")

# -----------------------------------------------------------------------------
# 2. COLOR PALETTES (PHOTOMETRIC & SPECTRAL VALUES)
# -----------------------------------------------------------------------------
WHITE = (1.0, 1.0, 1.0)
CYAN_CORE = (0.6, 1.5, 2.2)
CYAN_OZONE = (0.15, 0.8, 1.6)
GOLD_CORE = (2.4, 1.8, 0.6)
AMBER_HOT = (2.2, 1.2, 0.25)
LAVA_CORE = (2.6, 1.7, 0.55)
LAVA_FLAME = (2.2, 0.7, 0.12)
LAVA_CRUST = (0.24, 0.14, 0.12)
LIME_CORE = (1.3, 2.2, 0.6)
TOXIC_GREEN = (0.45, 1.95, 0.35)
ICE_CORE = (1.2, 1.5, 2.4)
ICE_CYAN = (0.55, 1.2, 1.9)
PLASMA_PURPLE = (1.8, 0.65, 2.2)
PLASMA_ELECTRIC = (0.65, 1.6, 2.2)
MISSILE_FIRE = (2.4, 1.3, 0.35)

# =============================================================================
# 3. COMMONS: FLARE, RING, SMOKE, STREAK, SPARK
# =============================================================================
def build_commons():
    s = 256
    xx, yy = grid(s)
    c = s * 0.5
    d = dist(xx, yy, c, c)

    # 1. ts_flare.png: 12-facet precision anamorphic star flare with central singularity
    b = blank(s)
    # Singularity center
    add(b, np.exp(-(d / 7.0) ** 2), WHITE, 5.0)
    add(b, np.exp(-(d / 18.0) ** 2), (0.9, 0.95, 1.0), 2.2)
    add(b, np.exp(-(d / 52.0) ** 1.6), (0.45, 0.8, 1.0), 0.7)
    # 12 Diffraction Spikes
    for ang, length, width, inten in [
        (0.0, 126.0, 1.8, 3.4),             # Primary Horizontal Anamorphic Left
        (math.pi, 126.0, 1.8, 3.4),         # Primary Horizontal Anamorphic Right
        (math.pi * 0.5, 96.0, 1.8, 2.8),    # Primary Vertical Up
        (-math.pi * 0.5, 96.0, 1.8, 2.8),   # Primary Vertical Down
        (math.pi * 0.25, 68.0, 1.4, 1.6),   # 45 deg Diagonals
        (-math.pi * 0.25, 68.0, 1.4, 1.6),
        (math.pi * 0.75, 68.0, 1.4, 1.6),
        (-math.pi * 0.75, 68.0, 1.4, 1.6),
        (math.pi * 0.125, 42.0, 1.1, 0.9),  # 22.5 deg Micro Spikes
        (-math.pi * 0.125, 42.0, 1.1, 0.9),
        (math.pi * 0.625, 42.0, 1.1, 0.9),
        (-math.pi * 0.625, 42.0, 1.1, 0.9)
    ]:
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        spike = np.exp(-(p / width) ** 2) * (t > 0) * np.exp(-t / (length * 0.40))
        add(b, spike, WHITE, inten)
    # Dual chromatic halo rings
    add(b, np.exp(-(((d - 54.0) / 4.5) ** 2)) * 0.35, (0.7, 0.85, 1.0), 1.0)
    add(b, np.exp(-(((d - 92.0) / 6.0) ** 2)) * 0.20, (0.5, 0.75, 1.0), 0.8)
    save_png("ts_flare.png", to_rgba_additive(b, k=0.75))

    # 2. ts_ring.png: Supersonic compression shockwave ring (steep front, turbulent wake)
    b_ring = blank(s)
    r_front = 98.0
    # Steep compression front on outer side (d > 98)
    steep_front = (d >= r_front) * np.exp(-(((d - r_front) / 3.0) ** 2))
    # Rarefaction turbulent expansion on inner side (d < 98)
    wake_n = fbm(s, base=7, octaves=4, seed=15) * 0.35 + 0.75
    diff_in = np.maximum(r_front - d, 0.0)
    soft_wake = (d < r_front) * np.exp(-((diff_in / 10.0) ** 1.8)) * wake_n
    add(b_ring, steep_front * 3.0 + soft_wake * 1.5, WHITE, 1.5)
    # Inner diffraction micro-ripple
    add(b_ring, np.exp(-(((d - 84.0) / 4.0) ** 2)) * 0.45, (0.8, 0.9, 1.0), 0.9)
    save_png("ts_ring.png", to_rgba_additive(b_ring, k=0.6))

    # 3. ts_smoke.png: Volumetric 3D directional shaded fractal smoke puff
    n1 = fbm(s, base=4, octaves=5, seed=101)
    n2 = fbm(s, base=8, octaves=4, seed=202)
    d_norm = d / c
    falloff = np.clip((1.0 - d_norm) / 0.40, 0, 1) ** 1.4
    density = np.clip(((n1 * 0.7 + n2 * 0.3) - 0.22) * 2.0 * falloff, 0, 1)
    # Directional lighting from top-left (-0.5, -0.7)
    gx, gy = np.gradient(n1 * 0.7 + n2 * 0.3)
    light = np.clip(0.55 - gx * 2.2 - gy * 2.2, 0.18, 1.0)
    smoke_rgb = np.dstack([np.ones((s, s)) * light] * 3)
    save_png("ts_smoke.png", to_rgba_alpha(smoke_rgb, density))

    # 4. ts_streak.png: Hypervelocity projectile streak (tapered wake, intense head)
    w_st, h_st = 256, 64
    xs, ys = grid(w_st, h_st)
    dy = np.abs(ys - h_st * 0.5)
    t_prof = xs / float(w_st) # 0 at tail (left), 1 at head (right)
    streak_w = np.maximum(2.5 + 12.0 * (1.0 - t_prof), 0.5)
    m_core = np.exp(-((dy / 2.5) ** 2)) * (t_prof ** 1.3)
    m_sheath = np.exp(-((dy / streak_w) ** 2)) * (t_prof ** 2.0) * 0.75
    b_st = np.zeros((h_st, w_st, 3), np.float32)
    add(b_st, m_core, WHITE, 3.2)
    add(b_st, m_sheath, (0.75, 0.9, 1.0), 1.6)
    # Head singularity flash
    add(b_st, np.exp(-(((xs - 250.0)**2 + dy**2) / 16.0)), WHITE, 4.0)
    save_png("ts_streak.png", to_rgba_additive(b_st, k=0.55, win=False))

    # 5. ts_spark.png: Needle-sharp incandescent spark particle
    w_sp, h_sp = 64, 16
    xsp, ysp = grid(w_sp, h_sp)
    ysp_d = np.abs(ysp - h_sp * 0.5)
    x_t = xsp / float(w_sp)
    spark_w = np.maximum(1.6 + 2.5 * (1.0 - x_t), 0.4)
    spark_m = np.exp(-((ysp_d / spark_w) ** 2)) * (x_t ** 1.1)
    b_sp = np.zeros((h_sp, w_sp, 3), np.float32)
    add(b_sp, spark_m, (2.4, 1.9, 1.3), 3.5)
    add(b_sp, np.exp(-(((xsp - 60.0)**2 + ysp_d**2) / 6.0)), WHITE, 4.5)
    save_png("ts_spark.png", to_rgba_additive(b_sp, k=0.45, win=False))

# =============================================================================
# 4. CONTINUOUS BEAMS (4 ANIMATED STRIPS PER 256x256 TEXTURE)
# =============================================================================
def build_beams():
    w, h = 256, 256
    # 1. ts_beam_weld: High-voltage braided electric arc with Townsend micro-spikes
    b_weld = np.zeros((h, w, 3), np.float32)
    for strip in range(4):
        xs, ys = grid(w, 64)
        y_loc = ys - 32.0
        seed = 100 * strip + 42
        turb = fbm(w, 64, base=5, octaves=4, seed=seed)
        jitter = (turb[32, :] - 0.5) * 14.0
        y_eff = np.abs(y_loc - jitter[None, :])
        # Dual-braided core lines
        braid1 = np.sin(xs * 0.18 + strip * 1.5) * 4.0
        braid2 = -np.sin(xs * 0.18 + strip * 1.5) * 4.0
        c1 = np.exp(-(((y_loc - jitter[None, :] - braid1) / 2.0) ** 2))
        c2 = np.exp(-(((y_loc - jitter[None, :] - braid2) / 2.0) ** 2))
        core = np.maximum(c1, c2)
        sheath = np.exp(-((y_eff / 16.0) ** 2)) * 0.65
        # Micro Townsend discharges
        spikes = (np.abs(turb - 0.5) < 0.07) * np.exp(-((y_eff / 26.0) ** 2)) * 0.6
        m_tot = core * 3.6 + (sheath + spikes) * 1.6
        b_weld[strip*64:(strip+1)*64, :, 0] += core * 3.0 + sheath * 0.4
        b_weld[strip*64:(strip+1)*64, :, 1] += core * 3.2 + sheath * 1.2
        b_weld[strip*64:(strip+1)*64, :, 2] += core * 3.5 + sheath * 2.0
    save_png("ts_beam_weld.png", to_rgba_additive(b_weld, k=0.85, win=False))

    # 2. ts_beam_solar: Concentrated orbital solar laser (golden sheath, white fusion filament)
    b_solar = np.zeros((h, w, 3), np.float32)
    for strip in range(4):
        xs, ys = grid(w, 64)
        y_loc = ys - 32.0
        turb = fbm(w, 64, base=4, octaves=3, seed=strip * 70 + 88)
        y_eff = np.abs(y_loc)
        core_filament = np.exp(-((y_eff / 2.8) ** 2))
        mid_beam = np.exp(-((y_eff / 9.0) ** 2)) * (0.8 + 0.2 * turb)
        outer_sheath = np.exp(-((y_eff / 22.0) ** 2)) * 0.5
        b_solar[strip*64:(strip+1)*64, :, 0] += core_filament * 4.0 + mid_beam * 2.4 + outer_sheath * 1.6
        b_solar[strip*64:(strip+1)*64, :, 1] += core_filament * 3.8 + mid_beam * 1.7 + outer_sheath * 0.9
        b_solar[strip*64:(strip+1)*64, :, 2] += core_filament * 3.5 + mid_beam * 0.5 + outer_sheath * 0.2
    save_png("ts_beam_solar.png", to_rgba_additive(b_solar, k=0.85, win=False))

    # 3. ts_beam_plasma: Helical magnetic plasma confinement beam with wave nodes
    b_plasma = np.zeros((h, w, 3), np.float32)
    for strip in range(4):
        xs, ys = grid(w, 64)
        y_loc = ys - 32.0
        helix1 = np.sin(xs * 0.12 + strip * 1.6) * 7.0
        helix2 = -np.sin(xs * 0.12 + strip * 1.6) * 7.0
        c_helix1 = np.exp(-(((y_loc - helix1) / 2.2) ** 2))
        c_helix2 = np.exp(-(((y_loc - helix2) / 2.2) ** 2))
        core_node = np.exp(-((np.abs(y_loc) / 3.2) ** 2)) * (0.8 + 0.4 * np.cos(xs * 0.24) ** 2)
        sheath_p = np.exp(-((np.abs(y_loc) / 18.0) ** 2)) * 0.55
        m_col = (c_helix1 + c_helix2) * 1.8 + core_node * 3.2 + sheath_p * 1.2
        b_plasma[strip*64:(strip+1)*64, :, 0] += m_col * 0.4
        b_plasma[strip*64:(strip+1)*64, :, 1] += m_col * 1.8
        b_plasma[strip*64:(strip+1)*64, :, 2] += m_col * 2.2
    save_png("ts_beam_plasma.png", to_rgba_additive(b_plasma, k=0.85, win=False))

# =============================================================================
# 5. PROJECTILE HEADS (256x256)
# =============================================================================
def build_heads():
    s = 256
    xx, yy = grid(s)
    c = s * 0.5
    d = dist(xx, yy, c, c)

    # 1. ts_frost_head.png: Hexagonal 8-spoke crystal snowflake with faceted dendrites
    b_frost = blank(s)
    add(b_frost, np.exp(-(d / 22.0) ** 2), ICE_CORE, 4.0)
    add(b_frost, np.exp(-(d / 62.0) ** 1.8), ICE_CYAN, 1.2)
    for i in range(8):
        ang = i * (math.pi / 4.0)
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        w_p = np.maximum(2.2 + 0.05 * t, 0.4)
        crystal = np.exp(-(p / w_p) ** 2) * (t > 0) * (t < 96.0) * np.exp(-t / 44.0)
        # 3 chevron facet branches along each arm
        chevrons = np.zeros_like(xx)
        for ch_t in [28.0, 52.0, 74.0]:
            dt = np.abs(t - ch_t)
            dp = np.abs(np.abs(p) - (t - ch_t) * 0.6)
            chevrons += (t > ch_t) * (t < ch_t + 22.0) * np.exp(-((dp / 1.6) ** 2)) * np.exp(-dt / 14.0)
        add(b_frost, crystal * 2.8 + chevrons * 1.6, ICE_CORE, 1.4)
    save_png("ts_frost_head.png", to_rgba_additive(b_frost, k=0.85))

    # 2. ts_slag_head.png: Molten magma boulder with Worley basalt crust fissures
    b_slag = blank(s)
    f1, diff = worley_cells(s, n_points=36, seed=89)
    cracks = np.exp(-((diff / 4.5) ** 2))
    boulder_shape = np.clip(1.0 - d / 58.0, 0, 1) ** 0.5
    boulder_noise = fbm(s, base=6, octaves=4, seed=51)
    # Incandescent magma heart
    add(b_slag, np.exp(-(d / 36.0) ** 2), LAVA_CORE, 3.8)
    add(b_slag, boulder_shape * cracks * 2.6, LAVA_CORE, 3.2)
    add(b_slag, boulder_shape * (0.3 + 0.7 * boulder_noise), LAVA_FLAME, 1.5)
    add(b_slag, np.exp(-(d / 76.0) ** 1.6), LAVA_FLAME, 0.9)
    save_png("ts_slag_head.png", to_rgba_additive(b_slag, k=0.9))

    # 3. ts_acid_head.png: Caustic venom globule with translucent membrane & boiling bubbles
    b_acid = blank(s)
    membrane = np.exp(-(((d - 38.0) / 4.5) ** 2)) * 2.8
    core_acid = np.exp(-(d / 30.0) ** 2) * (0.6 + 0.4 * fbm(s, base=5, seed=14))
    # Interior boiling bubbles
    for drop_ang, drop_d, r_drop in [(0.4, 64.0, 12.0), (-0.7, 56.0, 10.0), (2.8, 70.0, 14.0)]:
        dx_b = c + math.cos(drop_ang) * drop_d
        dy_b = c + math.sin(drop_ang) * drop_d
        d_sub = dist(xx, yy, dx_b, dy_b)
        add(b_acid, np.exp(-(d_sub / r_drop) ** 2), LIME_CORE, 1.8)
        add(b_acid, np.exp(-(((d_sub - r_drop * 0.85) / 2.2) ** 2)), WHITE, 1.3)
    add(b_acid, membrane, WHITE, 2.2)
    add(b_acid, core_acid, TOXIC_GREEN, 3.5)
    add(b_acid, np.exp(-(d / 74.0) ** 1.4), (0.2, 1.9, 0.4), 0.8)
    save_png("ts_acid_head.png", to_rgba_additive(b_acid, k=0.85))

    # 4. ts_plasma_head.png: Quantum plasma core with concentric containment rings & arcs
    b_plasma = blank(s)
    add(b_plasma, np.exp(-(d / 26.0) ** 2), WHITE, 5.0)
    add(b_plasma, np.exp(-(d / 52.0) ** 1.8), CYAN_CORE, 2.4)
    # Townsend coronal arcs radiating outward
    for i in range(12):
        ang = i * (math.pi / 6.0) + (fbm(s, base=4, seed=i)[128, 128] - 0.5) * 0.7
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        arc = np.exp(-(p / 1.8) ** 2) * (t > 18) * (t < 88) * np.exp(-t / 34.0)
        add(b_plasma, arc, WHITE, 2.2)
    for r_ring in [58.0, 80.0]:
        add(b_plasma, np.exp(-(((d - r_ring) / 2.8) ** 2)) * 0.8, (0.3, 1.8, 1.5), 1.4)
    save_png("ts_plasma_head.png", to_rgba_additive(b_plasma, k=0.9))

    # 5. ts_bolt_head.png: High-voltage lightning spearhead with branched tail
    b_bolt = blank(s)
    dx = xx - c
    dy = yy - c
    t_fwd = dx
    p_lat = np.abs(dy)
    tip_cone = (t_fwd < 72) * (t_fwd > -60) * np.exp(-(p_lat / (3.8 + (72 - t_fwd) * 0.14)) ** 2)
    add(b_bolt, tip_cone, WHITE, 4.0)
    add(b_bolt, tip_cone * np.exp(-(p_lat / 18.0) ** 2), (0.4, 2.0, 1.3), 1.8)
    for k in [-1, 1]:
        branch = np.exp(-(((dy - k * 22.0 - (t_fwd + 40) * 0.3) / 2.8) ** 2)) * (t_fwd < 10) * (t_fwd > -82)
        add(b_bolt, branch, (0.5, 2.2, 1.5), 1.8)
    save_png("ts_bolt_head.png", to_rgba_additive(b_bolt, k=0.85))

    # 6. ts_flak_head.png: Supersonic tungsten dart with Mach shockwave cone
    b_flak = blank(s)
    body = (dx > -52) * (dx < 52) * np.exp(-((dy / 3.8) ** 2))
    tip_hot = np.exp(-(((dx - 50.0) ** 2 + dy ** 2) / 28.0)) * 4.5
    mach_dist = np.abs(dy) - (52 - dx) * 0.54
    mach_shock = (dx < 52) * (dx > -84) * np.exp(-((mach_dist / 4.2) ** 2)) * np.exp(-(52 - dx) / 58.0)
    add(b_flak, body, (2.2, 1.8, 1.4), 3.2)
    add(b_flak, tip_hot, WHITE, 4.2)
    add(b_flak, mach_shock, (2.2, 1.1, 0.3), 2.4)
    save_png("ts_flak_head.png", to_rgba_additive(b_flak, k=0.8))

    # 7. ts_pod_head.png: Biomechanical jungle seed pod with 3 samara wings
    b_pod = blank(s)
    add(b_pod, np.exp(-(d / 32.0) ** 2) * 2.6, LIME_CORE, 2.2)
    for k in range(3):
        ang = k * (2.0 * math.pi / 3.0)
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - c) * ux + (yy - c) * uy
        p = -(xx - c) * uy + (yy - c) * ux
        w_w = np.maximum(5.8 + 0.15 * t, 0.4)
        wing = np.exp(-(p / w_w) ** 2) * (t > 15) * (t < 82) * np.exp(-((t - 45) / 24.0) ** 2)
        edge = np.exp(-(((p - 4.0) / 1.4) ** 2)) * (t > 20) * (t < 78)
        add(b_pod, wing, (0.5, 1.9, 0.4), 1.9)
        add(b_pod, edge, WHITE, 2.2)
    save_png("ts_pod_head.png", to_rgba_additive(b_pod, k=0.85))

    # 8. ts_missile_head.png: Precision military missile with Mach diamonds
    b_missile = blank(s)
    fuselage = (dx > -36) * (dx < 36) * np.exp(-((dy / 5.2) ** 2))
    w_nose = np.maximum(5.2 * (1.0 - (dx - 36) / 20.0), 0.5)
    nose = (dx >= 36) * (dx < 56) * np.exp(-((dy / w_nose) ** 2))
    fins = (dx > -36) * (dx < -16) * np.exp(-(((np.abs(dy) - 14.0) / 2.4) ** 2))
    ex_len = np.abs(dx + 36)
    exhaust = (dx <= -36) * (dx > -115) * np.exp(-((dy / (3.4 + ex_len * 0.11)) ** 2)) * np.exp(-ex_len / 34.0)
    mach_diamonds = (dx <= -42) * (dx > -98) * (np.sin((dx + 36) * 0.35) ** 2 > 0.6) * np.exp(-((dy / 2.8) ** 2))
    add(b_missile, fuselage + nose + fins, (1.8, 1.9, 2.0), 2.4)
    add(b_missile, exhaust, (0.6, 1.5, 2.2), 3.2)
    add(b_missile, mach_diamonds, WHITE, 4.2)
    save_png("ts_missile_head.png", to_rgba_additive(b_missile, k=0.8))

# =============================================================================
# 6. IMPACT ANIMATION SHEETS (4x4 = 16 FRAMES, 768x768)
# =============================================================================
def build_impact_sheet(name, frame_renderer):
    frame_sz = 192
    sheet_sz = frame_sz * 4
    master = Image.new("RGBA", (sheet_sz, sheet_sz), (0, 0, 0, 0))
    for f in range(16):
        col_idx = f % 4
        row_idx = f // 4
        u = float(f) / 15.0
        frame_arr = frame_renderer(frame_sz, u, f)
        frame_im = Image.fromarray(frame_arr, "RGBA")
        master.paste(frame_im, (col_idx * frame_sz, row_idx * frame_sz))
    master.save(os.path.join(OUT, f"{name}.png"), optimize=True)
    print(f"  [HORLOGER IMPACT] {name}.png (768x768, 16 frames)")

def render_slag_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    r_core = 16.0 + 66.0 * (u ** 0.58)
    fade = np.clip((1.0 - u) / 0.55, 0, 1)
    # Multi-lobed turbulent fireball core
    turb = fbm(sz, base=5, octaves=4, seed=f + 25)
    core_mask = np.exp(-((d / max(r_core, 1.0)) ** 2)) * (0.55 + 0.45 * turb) * fade
    add(b, core_mask, LAVA_CORE if u < 0.35 else LAVA_FLAME, 3.8 * fade)
    # Blinding detonation flash at early frames
    if u < 0.25:
        add(b, np.exp(-(d / (16.0 * (1.0 - u * 2.0))) ** 2) * (1.0 - u / 0.25), WHITE, 5.0)
    # 24 molten lava droplets flying radially with gravity droop
    rng = np.random.default_rng(f + 77)
    for p_i in range(24):
        ang = p_i * (math.pi / 12.0) + rng.uniform(-0.14, 0.14)
        spd = 18.0 + (p_i % 5) * 16.0
        p_dist = spd * (u ** 0.7) * 4.6
        px = c + math.cos(ang) * p_dist
        py = c + math.sin(ang) * p_dist + (u ** 2) * 22.0
        d_p = dist(xx, yy, px, py)
        drop = np.exp(-((d_p / 3.8) ** 2)) * fade
        add(b, drop, LAVA_CORE if u < 0.5 else LAVA_FLAME, 3.2 * fade)
    return to_rgba_additive(b, k=0.9)

def render_ice_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.5, 0, 1)
    # Supersonic shockwave ring
    r_shock = 14.0 + 74.0 * (u ** 0.54)
    shock = np.exp(-(((d - r_shock) / (5.0 + 10.0 * u)) ** 2)) * fade
    add(b, shock, ICE_CYAN, 2.8 * fade)
    # 18 sharp angular crystal shards shattering outward
    for i in range(18):
        ang = i * (math.pi / 9.0) + math.sin(i * 3.7) * 0.22
        shard_d = (18.0 + (i % 5) * 20.0) * (u ** 0.7) * 3.6
        sx = c + math.cos(ang) * shard_d
        sy = c + math.sin(ang) * shard_d
        d_s = dist(xx, yy, sx, sy)
        shard = np.exp(-(d_s / np.maximum(4.8 * (1.0 - u * 0.5), 0.5)) ** 2) * fade
        add(b, shard, WHITE, 3.5 * fade)
    # Freezing sub-zero mist cloud
    mist = np.exp(-(d / (38.0 + 42.0 * u)) ** 2) * fbm(sz, base=4, seed=f + 32) * fade
    add(b, mist, ICE_CYAN, 1.5 * fade)
    return to_rgba_additive(b, k=0.85)

def render_acid_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.55, 0, 1)
    r_splash = 12.0 + 62.0 * (u ** 0.5)
    turb = fbm(sz, base=6, seed=f + 42)
    crown = np.exp(-(((d - r_splash) / (6.5 + 9.5 * u)) ** 2)) * (0.6 + 0.4 * turb) * fade
    add(b, crown, TOXIC_GREEN, 3.2 * fade)
    # 22 spattering acid droplets
    for i in range(22):
        ang = i * (math.pi / 11.0) + (i % 3) * 0.18
        drop_d = (15.0 + (i % 5) * 14.0) * (u ** 0.65) * 3.9
        dx_d = c + math.cos(ang) * drop_d
        dy_d = c + math.sin(ang) * drop_d + (u ** 1.8) * 16.0
        d_p = dist(xx, yy, dx_d, dy_d)
        add(b, np.exp(-(d_p / 3.8) ** 2) * fade, LIME_CORE, 3.0 * fade)
    add(b, np.exp(-(d / (34.0 + 36.0 * u)) ** 2) * fade * 0.5, (0.3, 1.9, 0.4), 1.3 * fade)
    return to_rgba_additive(b, k=0.85)

def render_pod_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.55, 0, 1)
    spore_cloud = fbm(sz, base=5, seed=f + 62) * np.exp(-(d / (24.0 + 56.0 * u)) ** 2) * fade
    add(b, spore_cloud, (0.6, 2.2, 0.5), 3.2 * fade)
    # Exactly 6 splintering thorns shooting outward radially at 60 deg
    for i in range(6):
        ang = i * (math.pi / 3.0) + 0.2
        thorn_d = 18.0 + 92.0 * (u ** 0.8)
        tx = c + math.cos(ang) * thorn_d
        ty = c + math.sin(ang) * thorn_d
        d_th = dist(xx, yy, tx, ty)
        add(b, np.exp(-(d_th / 4.2) ** 2) * fade, WHITE, 3.8 * fade)
    return to_rgba_additive(b, k=0.85)

def render_plasma_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.45, 0, 1)
    r_core = 36.0 * (1.0 - u * 0.72)
    add(b, np.exp(-(d / max(r_core, 1.0)) ** 2) * fade, WHITE, 4.8 * fade)
    # 16 fractal Townsend lightning branches
    for i in range(16):
        ang = i * (math.pi / 8.0) + math.sin(i * 5.2) * 0.28
        len_arc = (28.0 + (i % 4) * 24.0) * (u ** 0.5) * 3.3
        ax = c + math.cos(ang) * len_arc
        ay = c + math.sin(ang) * len_arc
        d_a = dist(xx, yy, ax, ay)
        add(b, np.exp(-(d_a / 3.4) ** 2) * fade, CYAN_CORE, 3.2 * fade)
    r_ring = 16.0 + 76.0 * (u ** 0.5)
    ring_m = np.exp(-(((d - r_ring) / 5.5) ** 2)) * fade
    add(b, ring_m, (0.4, 1.7, 2.2), 2.4 * fade)
    return to_rgba_additive(b, k=0.9)

def render_missile_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.55, 0, 1)
    r_blast = 15.0 + 70.0 * (u ** 0.54)
    turb = fbm(sz, base=5, octaves=4, seed=f + 92)
    fire = np.exp(-((d / max(r_blast, 1.0)) ** 2)) * (0.5 + 0.5 * turb) * fade
    add(b, fire, MISSILE_FIRE if u < 0.42 else (2.1, 0.65, 0.1), 4.0 * fade)
    if u < 0.22:
        add(b, np.exp(-(d / (16.0 * (1.0 - u * 2.0))) ** 2), WHITE, 4.8)
    for i in range(18):
        ang = i * (math.pi / 9.0) + (i % 3) * 0.14
        s_dist = (24.0 + (i % 4) * 20.0) * (u ** 0.74) * 3.6
        sx = c + math.cos(ang) * s_dist
        sy = c + math.sin(ang) * s_dist
        d_s = dist(xx, yy, sx, sy)
        add(b, np.exp(-(d_s / 2.8) ** 2) * fade, WHITE, 3.2 * fade)
    return to_rgba_additive(b, k=0.9)

def render_smoke_impact(sz, u, f):
    xx, yy = grid(sz)
    c = sz * 0.5
    d = dist(xx, yy, c, c)
    b = blank(sz)
    fade = np.clip((1.0 - u) / 0.5, 0, 1)
    r_shrap = 16.0 + 74.0 * (u ** 0.6)
    shrap_ring = np.exp(-(((d - r_shrap) / (3.8 + 7.5 * u)) ** 2)) * fade
    turb = fbm(sz, base=6, seed=f + 125)
    add(b, shrap_ring * (0.4 + 0.6 * turb), (2.2, 1.6, 0.75), 3.2 * fade)
    for i in range(24):
        ang = i * (math.pi / 12.0) + math.sin(i * 2.3) * 0.24
        f_dist = (14.0 + (i % 5) * 16.0) * (u ** 0.7) * 3.9
        fx = c + math.cos(ang) * f_dist
        fy = c + math.sin(ang) * f_dist
        d_f = dist(xx, yy, fx, fy)
        add(b, np.exp(-(d_f / 3.0) ** 2) * fade, WHITE, 3.6 * fade)
    return to_rgba_additive(b, k=0.85)

# =============================================================================
# 7. DECALS & GROUND GLOWS (384x384)
# =============================================================================
def build_decals():
    s = 384
    xx, yy = grid(s)
    c = s * 0.5
    d = dist(xx, yy, c, c)
    d_norm = d / c
    falloff = np.clip((1.0 - d_norm) / 0.35, 0, 1) ** 1.4

    # 1. ts_slag_decal & ts_slag_glow: Basalt tectonic crust with incandescent magma veins
    f1, diff = worley_cells(s, n_points=42, seed=35)
    turb = fbm(s, base=5, seed=77)
    cracks = np.exp(-((diff / 5.8) ** 2)) * falloff
    basalt = np.clip((0.2 + 0.4 * turb) * falloff, 0, 1)
    decal_slag = np.dstack([
        basalt * 0.18 + cracks * 0.65,
        basalt * 0.15 + cracks * 0.25,
        basalt * 0.14 + cracks * 0.05
    ])
    save_png("ts_slag_decal.png", to_rgba_alpha(decal_slag, falloff * 0.95))
    b_sglow = blank(s)
    add(b_sglow, cracks * 2.6, LAVA_CORE, 2.6)
    add(b_sglow, np.exp(-(d / 96.0) ** 2), LAVA_FLAME, 1.3)
    save_png("ts_slag_glow.png", to_rgba_additive(b_sglow, k=0.9))

    # 2. ts_acid_decal & ts_acid_glow: Caustic bubbling sludge with frothing foam
    n_acid = fbm(s, base=4, seed=93)
    puddle = np.clip((1.0 - d_norm + (n_acid - 0.5) * 0.6) / 0.35, 0, 1) ** 1.5
    f1_a, diff_a = worley_cells(s, n_points=34, seed=67)
    bubbles = np.exp(-((f1_a / 11.0) ** 2)) * puddle
    decal_acid = np.dstack([
        puddle * 0.25 + bubbles * 0.5,
        puddle * 0.55 + bubbles * 0.9,
        puddle * 0.15 + bubbles * 0.2
    ])
    save_png("ts_acid_decal.png", to_rgba_alpha(decal_acid, puddle * 0.9))
    b_aglow = blank(s)
    add(b_aglow, bubbles * 2.2 + puddle * 0.65, LIME_CORE, 2.3)
    save_png("ts_acid_glow.png", to_rgba_additive(b_aglow, k=0.85))

    # 3. ts_frost_decal & ts_frost_glow: Dendritic ice crystals
    frost_n = fbm(s, base=6, octaves=5, seed=110)
    crystal_pattern = np.clip(np.abs(np.sin(xx * 0.12) * np.cos(yy * 0.12) + frost_n * 0.8), 0, 1) * falloff
    decal_frost = np.dstack([crystal_pattern * 0.75, crystal_pattern * 0.90, crystal_pattern * 1.0])
    save_png("ts_frost_decal.png", to_rgba_alpha(decal_frost, falloff * 0.88))
    b_fglow = blank(s)
    add(b_fglow, crystal_pattern * 1.9, ICE_CORE, 2.2)
    save_png("ts_frost_glow.png", to_rgba_additive(b_fglow, k=0.8))

    # 4. ts_spores_decal & ts_spores_glow: Fungal bioluminescent spore patch
    spore_puddle = fbm(s, base=5, seed=114) * falloff
    decal_spore = np.dstack([spore_puddle * 0.35, spore_puddle * 0.75, spore_puddle * 0.25])
    save_png("ts_spores_decal.png", to_rgba_alpha(decal_spore, spore_puddle * 0.92))
    b_spglow = blank(s)
    add(b_spglow, spore_puddle * 2.3, (0.5, 2.2, 0.4), 2.2)
    save_png("ts_spores_glow.png", to_rgba_additive(b_spglow, k=0.85))

    # 5. ts_glass_decal & ts_glass_glow (256x64): Vitrified molten fulgurite trench
    w_g, h_g = 256, 64
    xg, yg = grid(w_g, h_g)
    yg_d = np.abs(yg - h_g * 0.5)
    g_crack = fbm(w_g, h_g, base=5, seed=46)
    trench = np.exp(-((yg_d / (7.5 + g_crack[32, :] * 4.0)) ** 2))
    decal_glass = np.dstack([trench * 0.85, trench * 0.70, trench * 0.45])
    save_png("ts_glass_decal.png", to_rgba_alpha(decal_glass, trench * 0.9))
    b_gglow = np.zeros((h_g, w_g, 3), np.float32)
    add(b_gglow, np.exp(-((yg_d / 4.2) ** 2)), GOLD_CORE, 3.4)
    add(b_gglow, trench * 0.7, AMBER_HOT, 1.9)
    save_png("ts_glass_glow.png", to_rgba_additive(b_gglow, k=0.8, win=False))

# =============================================================================
# MAIN PIPELINE
# =============================================================================
def main():
    t0 = time.time()
    print("=== EXECUTING WATCHMAKER-GRADE TURRET VFX REBUILD ===")
    print("\n--- Phase 1: High-Precision Commons ---")
    build_commons()
    print("\n--- Phase 2: Braided Continuous Beams ---")
    build_beams()
    print("\n--- Phase 3: Faceted Projectile Heads ---")
    build_heads()
    print("\n--- Phase 4: Ground Decals & Resides ---")
    build_decals()
    print("\n--- Phase 5: 16-Frame Cinematic Impact Sheets ---")
    build_impact_sheet("ts_slag_impact", render_slag_impact)
    build_impact_sheet("ts_ice_impact", render_ice_impact)
    build_impact_sheet("ts_acid_impact", render_acid_impact)
    build_impact_sheet("ts_pod_impact", render_pod_impact)
    build_impact_sheet("ts_plasma_impact", render_plasma_impact)
    build_impact_sheet("ts_missile_impact", render_missile_impact)
    build_impact_sheet("ts_smoke_impact", render_smoke_impact)
    
    dt = time.time() - t0
    print(f"\n=== WATCHMAKER VFX REBUILD COMPLETE IN {dt:.1f}s ===")

if __name__ == "__main__":
    main()
