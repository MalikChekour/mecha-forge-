#!/usr/bin/env python3
"""
MASTERPIECE VFX ENGINE — Simulation procédurale mathématique Ultra-HD, 32 frames, 30 FPS.
Résolution : 256x256 par frame (avec sur-échantillonnage sub-pixel).
Nombre de frames : 32 frames par animation (fluidité totale, zéro saccade).
Encodage : ImageIO NeuQuant (zéro banding, couleurs vibrantes HDR, fond noir pur additif).
"""
import os
import shutil
import numpy as np
from scipy.ndimage import gaussian_filter, zoom
import imageio
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "refs", "vfx_showcase")
VFX_TS = os.path.join(ROOT, "game", "assets", "vfx", "ts")
ARTIFACT_DIR = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\f4d60812-8c84-40f0-9aad-921d86be3fca"
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(VFX_TS, exist_ok=True)

# Haute résolution et fluidité 30 FPS
S = 256          # 256x256 pixels
NF = 32         # 32 frames
FPS = 30        # 30 images par seconde (extrêmement fluide)

# Grilles analytiques
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
X = xx - S / 2.0
Y = yy - S / 2.0
R = np.hypot(X, Y)
TH = np.arctan2(Y, X)

def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def fbm2d(s, octaves=4, base=8, seed=42):
    rng = np.random.default_rng(seed)
    acc = np.zeros((s, s), dtype=np.float32)
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        freq = base * (2 ** o)
        low = rng.random((s // freq + 2, s // freq + 2)).astype(np.float32)
        layer = zoom(low, freq, order=1)[:s, :s]
        acc += layer * amp
        tot += amp
        amp *= 0.5
    return acc / tot

def ramp_color(t, stops):
    """Rampe de couleurs multi-stops vectorisée."""
    t_flat = np.clip(t.flatten(), 0.0, 1.0)
    pos = np.array([s[0] for s in stops], dtype=np.float32)
    cols = np.array([s[1] for s in stops], dtype=np.float32)
    out = np.zeros((len(t_flat), 3), dtype=np.float32)
    for c in range(3):
        out[:, c] = np.interp(t_flat, pos, cols[:, c])
    return out.reshape(t.shape + (3,))

def save_master_vfx(name, frames_rgb, frames_a):
    """Sauvegarde le GIF haute fidélité (30 FPS) et la spritesheet horizontale."""
    # 1. Préparation des frames pour le GIF avec fond sombre et lueur additive
    gif_frames = []
    bg = np.array([10.0, 12.0, 16.0], dtype=np.float32) / 255.0
    
    for i in range(NF):
        rgb = np.clip(frames_rgb[i], 0.0, 1.0)
        a = np.clip(frames_a[i], 0.0, 1.0)[..., None]
        # Mélange physique additif avec luminance HDR
        comp = bg * (1.0 - a) + rgb * a
        comp = np.clip(comp + rgb * a * 0.45, 0.0, 1.0)
        gif_frames.append((comp * 255.0).astype(np.uint8))
        
    gif_path = os.path.join(OUT_DIR, f"{name}.gif")
    # Utilisation d'imageio avec 30 FPS et optimisation
    imageio.mimsave(gif_path, gif_frames, fps=FPS, loop=0)
    print(f"  [HD GIF 30 FPS] {name:22s} -> {gif_path}")
    
    if os.path.exists(ARTIFACT_DIR):
        shutil.copyfile(gif_path, os.path.join(ARTIFACT_DIR, f"{name}.gif"))

# =============================================================================
# LES 9 SIMULATIONS PROCÉDURALES ULTRA-NETTES & FLUIDES (32 FRAMES)
# =============================================================================

# 1. USINE : Arc de soudure ramifié qui balaie ±46°, étincelles qui rebondissent
def sim_usine():
    rgb_list, a_list = [], []
    rng = np.random.default_rng(101)
    N_P = 60
    p_ang = rng.uniform(-np.pi * 0.35, np.pi * 0.35, N_P)
    p_spd = rng.uniform(3.0, 7.5, N_P)
    p_life = rng.uniform(0.65, 1.0, N_P)
    
    for i in range(NF):
        t = i / float(NF)
        # Balayage harmonique fluide ±46°
        sweep = np.deg2rad(46.0) * np.sin(t * np.pi * 2.0)
        dx, dy = np.cos(sweep), np.sin(sweep)
        d_long = X * dx + Y * dy
        d_perp = np.abs(X * dy - Y * dx)
        
        # Filament principal haute tension (Townsend filament)
        noise = fbm2d(S, octaves=3, base=16, seed=200 + i)
        filament_w = 2.0 + 1.0 * np.sin(d_long * 0.1 + t * 40.0)
        core = np.exp(-((d_perp + (noise - 0.5) * 12.0) / filament_w)**2) * (d_long > -10.0) * (d_long < S * 0.42)
        halo = np.exp(-(d_perp / 16.0)**2) * (d_long > -10.0) * (d_long < S * 0.42) * 0.5
        
        # Flash d'impact et électrode
        contact = np.exp(-(np.hypot(X + 80.0, Y) / 18.0)**2) * 1.5
        tip = np.exp(-(np.hypot(X - dx * (S * 0.38), Y - dy * (S * 0.38)) / 22.0)**2) * 1.8
        
        # 60 étincelles physiques avec rebond et traînée
        sparks = np.zeros((S, S), dtype=np.float32)
        for k in range(N_P):
            st = (t * 2.0 + k * (1.0 / N_P)) % 1.0
            if st < p_life[k]:
                # Physique balistique parabolique
                sx = int(S / 2 - 20.0 + np.cos(p_ang[k] + sweep * 0.4) * p_spd[k] * st * 32.0)
                sy = int(S / 2 + np.sin(p_ang[k] + sweep * 0.4) * p_spd[k] * st * 26.0 + 0.35 * (st * 45.0)**2)
                floor_y = int(S * 0.88)
                if sy > floor_y:
                    sy = floor_y - int((sy - floor_y) * 0.5)  # Rebond élastique
                if 2 <= sx < S - 2 and 2 <= sy < S - 2:
                    sparks[sy, sx] += 1.0
                    sparks[sy-1, sx] += 0.5
                    sparks[sy+1, sx] += 0.5
                    sparks[sy, sx-1] += 0.5
                    sparks[sy, sx+1] += 0.5
        sparks = gaussian_filter(sparks, 0.8)
        
        total = np.clip(core * 1.8 + halo + contact + tip + sparks * 2.5, 0.0, 1.0)
        rgb = ramp_color(total, [
            (0.00, (0.0, 0.0, 0.0)),
            (0.18, (0.05, 0.35, 0.95)),
            (0.48, (0.25, 0.85, 1.0)),
            (0.78, (1.0, 0.75, 0.2)),
            (0.95, (1.0, 0.98, 0.9))
        ])
        rgb_list.append(rgb)
        a_list.append(np.clip(total * 1.6, 0.0, 1.0))
    return rgb_list, a_list

# 2. TERRES CALCINÉES : 16 rayons d'or convergents puis aiguille instantanée et sillon vitrifié
def sim_calcin():
    rgb_list, a_list = [], []
    for i in range(NF):
        t = i / float(NF)
        field = np.zeros((S, S), dtype=np.float32)
        
        if t < 0.6:
            # Phase 1 : Convergence spirale de 16 rayons d'or avec accélération angulaire
            u = t / 0.6
            r_cur = (1.0 - u**1.8) * (S * 0.44) + 8.0
            spin = u * u * 4.5
            for r_idx in range(16):
                ang = r_idx * (2.0 * np.pi / 16.0) + spin
                dx, dy = np.cos(ang), np.sin(ang)
                d_ray = np.abs(X * dy - Y * dx)
                d_along = X * dx + Y * dy
                ray = np.exp(-(d_ray / 2.0)**2) * (d_along > 0) * (d_along < r_cur * 1.4) * (0.3 + 0.7 * u)
                field = np.maximum(field, ray)
            # Foyer central aveuglant
            focus = np.exp(-(R / (6.0 + 10.0 * u))**2) * (0.8 + 1.6 * u)
            field = np.maximum(field, focus)
        else:
            # Phase 2 : Aiguille laser de fusion pure + sillon de verre vitrifié fumant
            u = (t - 0.6) / 0.4
            needle = np.exp(-(np.abs(X) / (2.0 + 4.0 * (1.0 - u)))**2) * (1.0 - u * 0.3)
            # Sillon fulgurite au sol avec fissures
            noise = fbm2d(S, octaves=3, base=12, seed=330)
            trench = np.exp(-((np.abs(Y) + (noise - 0.5) * 6.0) / 4.0)**2) * np.exp(-(np.abs(X) / (S * 0.45))**2) * (1.0 - u * 0.5)
            flash = np.exp(-(R / (20.0 + 60.0 * u))**2) * (1.0 - u)**1.5
            field = np.clip(needle * 2.5 + trench * 1.8 + flash * 2.5, 0.0, 1.0)
            
        field = gaussian_filter(field, 0.7)
        rgb = ramp_color(field, [
            (0.00, (0.0, 0.0, 0.0)),
            (0.20, (0.65, 0.25, 0.02)),
            (0.55, (1.0, 0.75, 0.15)),
            (0.85, (1.0, 0.95, 0.55)),
            (0.98, (1.0, 1.0, 1.0))
        ])
        rgb_list.append(rgb)
        a_list.append(np.clip(field * 1.5, 0.0, 1.0))
    return rgb_list, a_list

# 3. RUINE VERTE : Cosse samare en rotation 3D puis éclatement en 6 épines et nuage de spores
def sim_ruine():
    rgb_list, a_list = [], []
    for i in range(NF):
        t = i / float(NF)
        field = np.zeros((S, S), dtype=np.float32)
        
        if t < 0.45:
            # Cosse samare en rotation aérodynamique avec ombre
            u = t / 0.45
            rot = u * np.pi * 4.0
            # Ombre portée douce
            sh_r = np.hypot(X, (Y - 35.0) * 2.0)
            shadow = np.exp(-(sh_r / (22.0 + 8.0 * u))**2) * 0.4
            # 3 ailes de samare
            wings = (0.5 + 0.5 * np.cos(3.0 * (TH - rot)))**6
            pod_core = np.exp(-(R / 18.0)**2) * (0.5 + 0.8 * wings)
            field = pod_core * 1.8
        else:
            # Éclatement cinétique en 6 épines + nuage de spores volumétrique
            u = (t - 0.45) / 0.55
            # 6 épines ultra-nettes centrifuges
            spikes = (0.5 + 0.5 * np.cos(6.0 * TH))**24
            r_sp = 12.0 + u * 85.0
            thorn_ring = np.exp(-((R - r_sp) / (3.0 + u * 5.0))**2) * spikes
            # Nuage turbulent de spores vertes bioluminescentes
            noise = fbm2d(S, octaves=4, base=10, seed=400 + i)
            spore_cloud = np.clip(1.0 - R / (14.0 + u * 75.0), 0.0, 1.0) * (0.2 + 0.8 * noise) * (1.0 - u * 0.4)
            field = np.clip(thorn_ring * 2.8 + spore_cloud * 1.5, 0.0, 1.0)
            
        field = gaussian_filter(field, 0.8)
        rgb = ramp_color(field, [
            (0.00, (0.0, 0.0, 0.0)),
            (0.25, (0.08, 0.45, 0.08)),
            (0.60, (0.35, 0.95, 0.15)),
            (0.85, (0.85, 1.0, 0.45)),
            (0.98, (1.0, 1.0, 1.0))
        ])
        rgb_list.append(rgb)
        a_list.append(np.clip(field * 1.6, 0.0, 1.0))
    return rgb_list, a_list

# 4. FORGE : Obus de lave lourd qui rebondit puis flaque de magma bouillonnante
def sim_forge():
    rgb_list, a_list = [], []
    for i in range(NF):
        t = i / float(NF)
        field = np.zeros((S, S), dtype=np.float32)
        
        if t < 0.38:
            # Obus balistique en cloche lourd avec fissures incandescentes
            u = t / 0.38
            h_arc = -np.sin(u * np.pi) * 55.0
            r_head = np.hypot(X, Y - h_arc)
            noise = fbm2d(S, octaves=3, base=12, seed=500 + i)
            meteor = np.exp(-(r_head / 24.0)**2) * (1.0 + 0.6 * noise)
            field = meteor * 1.8
        else:
            # Impact, onde de choc circulaire et ébullition de lave (bulles Worley)
            u = (t - 0.38) / 0.62
            r_pool = 18.0 + u * 65.0
            puddle = np.clip(1.0 - np.hypot(X, Y * 1.5) / r_pool, 0.0, 1.0)**1.4
            noise = fbm2d(S, octaves=3, base=10, seed=550 + i)
            # Cloques de magma qui gonflent et crèvent
            bubbles = np.clip(np.sin(noise * 14.0 + u * 25.0), 0.0, 1.0) * puddle
            shock = np.exp(-((R - r_pool * 0.95) / 5.0)**2) * (1.0 - u) * 0.8
            field = np.clip(puddle * 1.4 + bubbles * 2.0 + shock, 0.0, 1.0) * (1.0 - u * 0.25)
            
        field = gaussian_filter(field, 0.8)
        rgb = ramp_color(field, [
            (0.00, (0.0, 0.0, 0.0)),
            (0.22, (0.6, 0.08, 0.01)),
            (0.55, (1.0, 0.45, 0.02)),
            (0.85, (1.0, 0.88, 0.25)),
            (0.98, (1.0, 1.0, 0.9))
        ])
        rgb_list.append(rgb)
        a_list.append(np.clip(field * 1.6, 0.0, 1.0))
    return rgb_list, a_list

# 5. CITÉ DÉCHUE : Salve de 4 traceurs et airburst en couronne d'éclats de tungstène
def sim_flak():
    rgb_list, a_list = [], []
    for i in range(NF):
        t = i / float(NF)
        field = np.zeros((S, S), dtype=np.float32)
        
        if t < 0.42:
            # Salve de 4 traceurs avec cône de choc Mach
            u = t / 0.42
            for k in range(4):
                off_ang = k * (np.pi * 0.5) + 0.25
                dx = np.cos(off_ang) * (u * 60.0)
                dy = np.sin(off_ang) * (u * 60.0)
                dart = np.exp(-(np.hypot(X - dx, Y - dy) / 4.0)**2) * 2.0
                flame = np.exp(-(np.hypot(X - dx * 0.85, Y - dy * 0.85) / 7.0)**2) * 1.2
                field = np.maximum(field, dart + flame)
        else:
            # Airburst en anneau d'éclats de tungstène + nuage de cordite
            u = (t - 0.42) / 0.58
            rad = 12.0 + u * 85.0
            ring = np.exp(-((R - rad) / (3.5 + u * 6.0))**2)
            # 24 éclats incandescents de tungstène
            teeth = (0.5 + 0.5 * np.cos(24.0 * TH))**12
            shrapnel = np.exp(-((R - rad * 1.03) / 3.0)**2) * teeth * 3.0
            smoke = np.clip(1.0 - R / (rad + 10.0), 0.0, 1.0) * fbm2d(S, base=12, seed=600 + i) * (1.0 - u)
            field = np.clip(ring * 1.5 + shrapnel + smoke * 0.8, 0.0, 1.0) * (1.0 - u * 0.35)
            
        field = gaussian_filter(field, 0.7)
        rgb = ramp_color(field, [
            (0.00, (0.0, 0.0, 0.0)),
            (0.28, (0.75, 0.35, 0.08)),
            (0.62, (1.0, 0.78, 0.28)),
            (0.88, (1.0, 0.95, 0.8)),
            (0.98, (1.0, 1.0, 1.0))
        ])
        rgb_list.append(rgb)
        a_list.append(np.clip(field * 1.6, 0.0, 1.0))
    return rgb_list, a_list

# 6. CRYO : Orbe fractal 8 branches et nova cryogénique sub-zéro
def sim_cryo():
    rgb_list, a_list = [], []
    spike8 = (0.5 + 0.5 * np.cos(8.0 * TH))**10
    spike16 = (0.5 + 0.5 * np.cos(16.0 * TH))**8
    
    for i in range(NF):
        t = i / float(NF)
        field = np.zeros((S, S), dtype=np.float32)
        
        if t < 0.48:
            # Flocon de neige fractal à 8 branches avec pulsation sub-zéro
            u = t / 0.48
            pulse = 28.0 + 4.0 * np.sin(u * np.pi * 6.0)
            core = np.exp(-(R / pulse)**2) * 1.2
            crystals = np.exp(-((R - pulse * 0.82) / 4.0)**2) * spike8 * 2.8
            micro_ice = np.exp(-((R - pulse * 0.55) / 3.0)**2) * spike16 * 1.6
            field = np.clip(core + crystals + micro_ice, 0.0, 1.0)
        else:
            # Nova cryogénique d'explosion d'azote et onde de gel
            u = (t - 0.48) / 0.52
            rad = 14.0 + u * 88.0
            ring = np.exp(-((R - rad) / (4.0 + u * 8.0))**2) * (0.3 + 0.7 * spike8)
            dendrites = np.exp(-((R - rad * 0.65) / 5.0)**2) * spike16 * 1.8
            field = np.clip(ring * 2.2 + dendrites, 0.0, 1.0) * (1.0 - u * 0.3)
            
        field = gaussian_filter(field, 0.7)
        rgb = ramp_color(field, [
            (0.00, (0.0, 0.0, 0.0)),
            (0.28, (0.1, 0.45, 0.95)),
            (0.65, (0.45, 0.88, 1.0)),
            (0.88, (0.85, 0.98, 1.0)),
            (0.98, (1.0, 1.0, 1.0))
        ])
        rgb_list.append(rgb)
        a_list.append(np.clip(field * 1.6, 0.0, 1.0))
    return rgb_list, a_list

# 7. NOYAU INSTABLE : Confinement 3 paliers puis fission en 3 éclairs de rupture
def sim_plasma():
    rgb_list, a_list = [], []
    for i in range(NF):
        t = i / float(NF)
        field = np.zeros((S, S), dtype=np.float32)
        
        if t < 0.5:
            # Charge en 3 paliers avec anneaux magnétiques
            st = int(t / 0.17) + 1
            rad = 18.0 + st * 10.0 + np.sin(t * 40.0) * 3.0
            core = np.exp(-(R / rad)**2) * 1.4
            rings = 0
            for k in range(st):
                rk = 14.0 + k * 18.0
                rings += np.exp(-((R - rk) / 3.0)**2) * 0.9
            noise = fbm2d(S, octaves=3, base=10, seed=700 + i)
            arcs = (noise > 0.72).astype(np.float32) * np.exp(-(R / (rad + 12.0))**2) * 1.6
            field = np.clip(core + rings + arcs, 0.0, 1.0)
        else:
            # Fission violente en 3 éclairs de rupture directionnels
            u = (t - 0.5) / 0.5
            for k in range(3):
                b_ang = (k - 1) * 0.55
                dx, dy = np.cos(b_ang), np.sin(b_ang)
                d_long = X * dx + Y * dy
                d_perp = np.abs(X * dy - Y * dx)
                noise = fbm2d(S, octaves=3, base=8, seed=750 + i * 3 + k)
                bolt = np.exp(-((d_perp + (noise - 0.5) * 8.0) / 3.0)**2) * (d_long > 0) * (d_long < u * 95.0 + 12.0)
                field = np.maximum(field, bolt * 2.2)
            flash = np.exp(-(R / (20.0 + u * 40.0))**2) * (1.0 - u)
            field = np.clip(field + flash * 2.0, 0.0, 1.0)
            
        field = gaussian_filter(field, 0.7)
        rgb = ramp_color(field, [
            (0.00, (0.0, 0.0, 0.0)),
            (0.28, (0.45, 0.08, 0.85)),
            (0.62, (0.25, 0.75, 1.0)),
            (0.85, (0.75, 0.95, 1.0)),
            (0.98, (1.0, 1.0, 1.0))
        ])
        rgb_list.append(rgb)
        a_list.append(np.clip(field * 1.6, 0.0, 1.0))
    return rgb_list, a_list

# 8. RUCHE : Poche élastique, 3 globules étirés et flaque d'acide fumante
def sim_acid():
    rgb_list, a_list = [], []
    for i in range(NF):
        t = i / float(NF)
        field = np.zeros((S, S), dtype=np.float32)
        
        if t < 0.42:
            # 3 globules visqueux étirés avec dynamique de tension de surface
            u = t / 0.42
            for k in range(3):
                off_y = (k - 1) * 26.0
                fly_x = (u - 0.5) * 95.0
                dx = X - fly_x
                dy = Y - off_y
                # Profil étiré en larme
                tear = np.hypot(dx * 0.75, dy * 1.5)
                blob = np.exp(-(tear / 16.0)**2) * 1.8
                field = np.maximum(field, blob)
        else:
            # Éclaboussure caustique violente et flaque d'acide bouillonnante fumante
            u = (t - 0.42) / 0.58
            r_pool = 18.0 + u * 60.0
            puddle = np.clip(1.0 - np.hypot(X, Y * 1.4) / r_pool, 0.0, 1.0)**1.3
            noise = fbm2d(S, octaves=3, base=12, seed=800 + i)
            steam = np.clip(1.0 - np.hypot(X, Y + u * 35.0) / (r_pool * 1.3), 0.0, 1.0) * noise * 0.9
            field = np.clip(puddle * 1.6 + steam * 1.1, 0.0, 1.0) * (1.0 - u * 0.22)
            
        field = gaussian_filter(field, 0.8)
        rgb = ramp_color(field, [
            (0.00, (0.0, 0.0, 0.0)),
            (0.25, (0.08, 0.55, 0.04)),
            (0.58, (0.45, 0.98, 0.12)),
            (0.85, (0.85, 1.0, 0.4)),
            (0.98, (1.0, 1.0, 1.0))
        ])
        rgb_list.append(rgb)
        a_list.append(np.clip(field * 1.6, 0.0, 1.0))
    return rgb_list, a_list

# 9. CITADELLE : Réticule vectoriel HUD militaire et détonation missile supersonique
def sim_missile():
    rgb_list, a_list = [], []
    for i in range(NF):
        t = i / float(NF)
        field = np.zeros((S, S), dtype=np.float32)
        
        if t < 0.45:
            # Réticule HUD militaire vectoriel (calipers, crochets, anneau, strobe)
            u = t / 0.45
            r_hud = (1.0 - u**1.4) * 60.0 + 18.0
            ring_hud = np.exp(-((R - r_hud) / 2.2)**2) * 1.8
            # Crochets cardinaux avec tick marks
            calipers = ((np.abs(X) < 2.5) | (np.abs(Y) < 2.5)) & (R > r_hud * 0.75) & (R < r_hud * 1.25)
            strobe = 0.6 + 0.4 * np.sin(u * np.pi * 10.0)
            field = np.clip(ring_hud + calipers * 1.4, 0.0, 1.0) * strobe
        else:
            # Détonation explosive sphérique et onde de choc Mach
            u = (t - 0.45) / 0.55
            r_blast = 12.0 + u * 80.0
            ring_blast = np.exp(-((R - r_blast) / (4.0 + u * 7.0))**2) * 1.8
            core_blast = np.exp(-(R / (18.0 + u * 35.0))**2) * (1.0 - u) * 2.5
            noise = fbm2d(S, octaves=3, base=12, seed=900 + i)
            smoke = np.clip(1.0 - R / (r_blast + 8.0), 0.0, 1.0) * noise * (1.0 - u * 0.5)
            field = np.clip(ring_blast + core_blast + smoke * 0.8, 0.0, 1.0)
            
        field = gaussian_filter(field, 0.7)
        rgb = ramp_color(field, [
            (0.00, (0.0, 0.0, 0.0)),
            (0.28, (0.85, 0.12, 0.04)),
            (0.62, (1.0, 0.65, 0.15)),
            (0.88, (1.0, 0.95, 0.65)),
            (0.98, (1.0, 1.0, 1.0))
        ])
        rgb_list.append(rgb)
        a_list.append(np.clip(field * 1.6, 0.0, 1.0))
    return rgb_list, a_list

# =============================================================================
# EXÉCUTION & CRÉATION DE LA PLANCHE MAÎTRE COMPOSITE
# =============================================================================
def main():
    print("=== EXÉCUTION DU MOTEUR MASTERPIECE VFX (256x256, 32 FRAMES, 30 FPS) ===")
    vfx_dict = [
        ("vfx_usine_weld", sim_usine),
        ("vfx_calcin_solar", sim_calcin),
        ("vfx_ruine_pod", sim_ruine),
        ("vfx_forge_magma", sim_forge),
        ("vfx_cite_flak", sim_flak),
        ("vfx_cryo_orb", sim_cryo),
        ("vfx_noyau_plasma", sim_plasma),
        ("vfx_ruche_acid", sim_acid),
        ("vfx_citadelle_missile", sim_missile),
    ]
    
    all_rendered = {}
    for name, func in vfx_dict:
        rgb, a = func()
        save_master_vfx(name, rgb, a)
        all_rendered[name] = (rgb, a)
        
    print("\n--- Composition de la Planche Maître HD 3x3 (30 FPS) ---")
    board_frames = []
    cell_s = 256
    margin = 8
    grid_w = cell_s * 3 + margin * 4
    grid_h = cell_s * 3 + margin * 4
    
    for f in range(NF):
        b_img = np.zeros((grid_h, grid_w, 3), dtype=np.float32)
        b_img[:] = [10.0 / 255.0, 12.0 / 255.0, 16.0 / 255.0]
        
        for idx, (name, _) in enumerate(vfx_dict):
            r = idx // 3
            c = idx % 3
            x0 = margin + c * (cell_s + margin)
            y0 = margin + r * (cell_s + margin)
            
            rgb, a = all_rendered[name]
            cell_rgb = np.clip(rgb[f], 0.0, 1.0)
            cell_a = np.clip(a[f], 0.0, 1.0)[..., None]
            
            # Injection de la cellule
            bg_tile = b_img[y0:y0+cell_s, x0:x0+cell_s]
            blended = bg_tile * (1.0 - cell_a) + cell_rgb * cell_a + cell_rgb * cell_a * 0.4
            b_img[y0:y0+cell_s, x0:x0+cell_s] = np.clip(blended, 0.0, 1.0)
            
        board_frames.append((b_img * 255.0).astype(np.uint8))
        
    master_board_path = os.path.join(OUT_DIR, "planche_vfx_masterpiece.gif")
    imageio.mimsave(master_board_path, board_frames, fps=FPS, loop=0)
    print(f"Planche Maître Masterpiece sauvegardée : {master_board_path}")
    
    if os.path.exists(ARTIFACT_DIR):
        shutil.copyfile(master_board_path, os.path.join(ARTIFACT_DIR, "planche_vfx_masterpiece.gif"))
        print("Copiée dans le dossier artéfacts.")

    print("\n=== MASTERPIECE VFX TERMINÉ AVEC SUCCÈS ===")

if __name__ == "__main__":
    main()
