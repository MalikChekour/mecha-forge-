#!/usr/bin/env python3
"""
VFX TOURELLES ANIMÉES — Moteur de simulation procédurale mathématique haute fidélité (NumPy / SciPy).
Génère pour chacun des 9 biomes une planche de sprites 16 frames (fond noir, additif) et son GIF animé fluide.
Architecture identique au standard de haute horlogerie établi dans tools/vfx_showcase.py :
- Mathématiques pures (R, TH, FBM, Worley, Bessel, filtres gaussiens)
- Rampes de couleurs HDR (blanc aveuglant au cœur, dégradés thermiques)
- Zéro asset externe, 100 % paramétrable, 60 FPS en jeu.
"""
import os
import numpy as np
from scipy.ndimage import zoom, gaussian_filter
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "refs", "vfx_showcase")
VFX_TS = os.path.join(ROOT, "game", "assets", "vfx", "ts")
ARTIFACT_DIR = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\f4d60812-8c84-40f0-9aad-921d86be3fca"
os.makedirs(OUT, exist_ok=True)
os.makedirs(VFX_TS, exist_ok=True)

S = 128          # Résolution par frame (128x128 pour finesse horlogère)
NF = 16          # 16 frames par cycle d'animation

# Grille de coordonnées polaires et cartésiennes
yy, xx = np.mgrid[0:S, 0:S].astype(float)
X = xx - S / 2.0
Y = yy - S / 2.0
R = np.hypot(X, Y)
TH = np.arctan2(Y, X)

def vnoise(h, w, cell, seed):
    rng = np.random.default_rng(seed)
    low = rng.random((h // cell + 2, w // cell + 2))
    return zoom(low, cell, order=1)[:h, :w]

def ramp(t, stops):
    """Interpolation de couleur multi-stops le long de la valeur t (0..1)."""
    pos = np.array([s[0] for s in stops])
    cols = np.array([s[1] for s in stops], float)
    out = np.zeros(t.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(t, pos, cols[:, c])
    return out

def save_vfx(name, frames, gif_bg=(10, 12, 16)):
    """Sauvegarde la planche de sprites horizontale 16 frames et le GIF animé en boucle."""
    # 1. Spritesheet horizontale RGBA
    sheet = Image.new("RGBA", (S * NF, S), (0, 0, 0, 0))
    for i, (rgb, a) in enumerate(frames):
        arr = np.zeros((S, S, 4), np.uint8)
        arr[..., :3] = np.clip(rgb, 0, 1) * 255
        arr[..., 3] = np.clip(a, 0, 1) * 255
        sheet.paste(Image.fromarray(arr, "RGBA"), (i * S, 0))
    sheet_path = os.path.join(OUT, f"{name}.png")
    sheet.save(sheet_path)
    
    # 2. GIF animé en boucle avec composition additive sur fond sombre
    gif_frames = []
    for rgb, a in frames:
        base = np.array(gif_bg, float) / 255.0
        # Compositing additif luma
        comp = base[None, None, :] * (1.0 - a[..., None]) + np.clip(rgb, 0, 1) * a[..., None]
        comp = np.clip(comp + np.clip(rgb, 0, 1) * a[..., None] * 0.45, 0, 1)
        im = Image.fromarray((comp * 255.0).astype(np.uint8)).convert("P", palette=Image.ADAPTIVE)
        gif_frames.append(im)
    
    gif_path = os.path.join(OUT, f"{name}.gif")
    gif_frames[0].save(gif_path, save_all=True, append_images=gif_frames[1:], duration=60, loop=0, disposal=2)
    print(f"  [OK] {name:20s} -> {sheet_path} & {gif_path}")
    
    # Copie dans le dossier artéfact pour prévisualisation immédiate
    if os.path.exists(ARTIFACT_DIR):
        import shutil
        shutil.copyfile(gif_path, os.path.join(ARTIFACT_DIR, f"{name}.gif"))

# =============================================================================
# LES 9 EFFETS SPÉCIAUX DE TOURELLES (MODÈLES PROCÉDURAUX MATHÉMATIQUES)
# =============================================================================

# 1. USINE : Arc de soudure ramifié qui balaie ±46°, étincelles qui rebondissent
def vfx_usine_weld():
    fr = []
    # Génération d'un essaim de 36 étincelles physiques
    rng = np.random.default_rng(42)
    N_SP = 36
    sp_ang = rng.uniform(-np.pi * 0.35, np.pi * 0.35, N_SP)
    sp_spd = rng.uniform(2.5, 6.0, N_SP)
    sp_life = rng.uniform(0.6, 1.0, N_SP)
    
    for i in range(NF):
        t = i / (NF - 1)
        sweep_ang = np.deg2rad(46.0) * np.sin(t * np.pi * 2.0)
        
        # Tronc principal de l'arc de soudure
        line_dist = np.abs(X * np.sin(sweep_ang) - Y * np.cos(sweep_ang))
        long_dist = X * np.cos(sweep_ang) + Y * np.sin(sweep_ang)
        mask_cone = np.clip(long_dist / (S * 0.4), 0, 1)
        
        n_arc = vnoise(S, S, 8, 10 + i)
        weld_core = np.exp(-((line_dist + (n_arc - 0.5) * 8.0) / 2.2) ** 2) * mask_cone
        weld_halo = np.exp(-(line_dist / 8.5) ** 2) * mask_cone * 0.6
        
        # Étincelles projetées avec parabole de gravité et rebond
        spark_layer = np.zeros((S, S))
        for k in range(N_SP):
            st = (t * 2.5 + k * 0.08) % 1.0
            if st < sp_life[k]:
                # Trajectoire balistique
                sx = int(S / 2 + np.cos(sp_ang[k] + sweep_ang * 0.5) * sp_spd[k] * st * 28.0)
                sy = int(S / 2 + np.sin(sp_ang[k] + sweep_ang * 0.5) * sp_spd[k] * st * 22.0 + 0.3 * (st * 30.0)**2)
                # Rebond au sol
                floor = int(S * 0.85)
                if sy > floor:
                    sy = floor - int((sy - floor) * 0.4)
                if 1 <= sx < S - 1 and 1 <= sy < S - 1:
                    spark_layer[sy, sx] = 1.0
                    spark_layer[sy - 1, sx] = 0.6
                    spark_layer[sy + 1, sx] = 0.6
        spark_layer = gaussian_filter(spark_layer, 0.7)
        
        v = np.clip(weld_core * 1.6 + weld_halo * 0.8 + spark_layer * 2.0, 0, 1)
        rgb = ramp(v, [
            (0.0, (0, 0, 0)),
            (0.2, (0.1, 0.4, 0.9)),
            (0.5, (0.4, 0.85, 1.0)),
            (0.8, (1.0, 0.75, 0.3)),
            (1.0, (1.0, 1.0, 1.0))
        ])
        a = np.clip(v * 1.5, 0, 1)
        fr.append((rgb, a))
    return fr

# 2. TERRES CALCINÉES : Rayons d'or convergents puis aiguille instantanée et sillon de verre
def vfx_calcin_solar():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        img = np.zeros((S, S))
        if t < 0.65:
            # Phase 1 : 16 rayons d'or convergents en iris accélérée
            u1 = t / 0.65
            r_iris = (1.0 - u1**1.5) * (S * 0.45) + 6.0
            n_rays = 16
            for r_idx in range(n_rays):
                ang = r_idx * (2.0 * np.pi / n_rays) + u1 * 2.2
                dx = np.cos(ang)
                dy = np.sin(ang)
                d_ray = np.abs(X * dy - Y * dx)
                d_along = X * dx + Y * dy
                in_ray = (d_along > 0) & (d_along < r_iris * 1.5)
                ray_v = np.exp(-(d_ray / 1.5)**2) * in_ray * (0.3 + 0.7 * u1)
                img = np.maximum(img, ray_v)
            # Point de focalisation
            foc = np.exp(-(R / (4.0 + 8.0 * u1))**2) * (0.5 + 1.2 * u1)
            img = np.maximum(img, foc)
        else:
            # Phase 2 : Aiguille instantanée et vitrification du verre
            u2 = (t - 0.65) / 0.35
            needle = np.exp(-(np.abs(X) / (1.8 + 6.0 * (1.0 - u2)))**2) * (1.0 - u2 * 0.4)
            # Tranchée de fulgurite au sol
            trench = np.exp(-(np.abs(Y) / 3.5)**2) * np.exp(-(np.abs(X) / (S * 0.45))**2) * (1.0 - u2 * 0.6)
            flash = np.exp(-(R / (15.0 + 35.0 * u2))**2) * (1.0 - u2)
            img = np.clip(needle * 2.2 + trench * 1.4 + flash * 2.0, 0, 1)
        
        img = gaussian_filter(img, 0.6)
        rgb = ramp(img, [
            (0.0, (0, 0, 0)),
            (0.25, (0.7, 0.35, 0.05)),
            (0.6, (1.0, 0.8, 0.2)),
            (0.85, (1.0, 0.95, 0.6)),
            (1.0, (1.0, 1.0, 1.0))
        ])
        fr.append((rgb, np.clip(img * 1.4, 0, 1)))
    return fr

# 3. RUINE VERTE : Cosse qui tourne en cloche, ombre ovale, éclate en 6 épines et en spores
def vfx_ruine_pod():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        img = np.zeros((S, S))
        if t < 0.45:
            # Phase 1 : Cosse samare en rotation 3D et ombre
            u1 = t / 0.45
            rot = u1 * np.pi * 3.0
            # Ombre ovale au sol
            sh_r = np.hypot(X, (Y - 25) * 2.2)
            shadow = np.exp(-(sh_r / (14.0 + 6.0 * u1))**2) * 0.45
            # Cosse 3 pales
            pales = (0.5 + 0.5 * np.cos(3 * (TH - rot)))**4
            pod = np.exp(-(R / 12.0)**2) * (0.4 + 0.6 * pales)
            img = pod * 1.5
        else:
            # Phase 2 : Éclatement en 6 épines + nuage de spores volumétrique
            u2 = (t - 0.45) / 0.55
            # 6 épines centrifuges
            spikes = (0.5 + 0.5 * np.cos(6 * TH))**16
            r_spikes = 8.0 + u2 * 48.0
            ring_sp = np.exp(-((R - r_spikes) / (2.5 + u2 * 4.0))**2) * spikes
            # Nuage de spores
            n_spores = vnoise(S, S, 10, 50 + i)
            cloud = np.clip(1.0 - R / (10.0 + u2 * 42.0), 0, 1) * (0.3 + 0.7 * n_spores) * (1.0 - u2 * 0.5)
            img = np.clip(ring_sp * 2.0 + cloud * 1.3, 0, 1)
            
        img = gaussian_filter(img, 0.7)
        rgb = ramp(img, [
            (0.0, (0, 0, 0)),
            (0.3, (0.1, 0.45, 0.1)),
            (0.65, (0.4, 0.95, 0.2)),
            (0.88, (0.85, 1.0, 0.4)),
            (1.0, (1.0, 1.0, 1.0))
        ])
        fr.append((rgb, np.clip(img * 1.5, 0, 1)))
    return fr

# 4. FORGE : Obus de lave lourd qui rebondit une fois, puis flaque de magma qui bulle 5 s
def vfx_forge_magma():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        if t < 0.35:
            # Obus balistique en cloche avec croûte de basalte
            u1 = t / 0.35
            h_arc = -np.sin(u1 * np.pi) * 30.0
            dy = Y - h_arc
            r_b = np.hypot(X, dy)
            n_crust = vnoise(S, S, 8, 30 + i)
            core = np.exp(-(r_b / 14.0)**2) * (1.0 + 0.5 * n_crust)
            crust = (n_crust > 0.65).astype(float) * np.exp(-(r_b / 15.0)**2) * 0.5
            v = np.clip(core - crust, 0, 1) * 1.8
        else:
            # Impact, rebond et flaque bouillonnante avec cloques Worley
            u2 = (t - 0.35) / 0.65
            r_pool = 12.0 + u2 * 36.0
            puddle = np.clip(1.0 - np.hypot(X, Y * 1.6) / r_pool, 0, 1)**1.3
            # Bulles de magma qui montent et éclatent
            n_bub = vnoise(S, S, 8, 70 + i)
            bub = np.clip(np.sin(n_bub * 12.0 + u2 * 20.0), 0, 1) * puddle
            v = np.clip(puddle * 1.2 + bub * 1.5, 0, 1) * (1.0 - u2 * 0.25)
            
        v = gaussian_filter(v, 0.8)
        rgb = ramp(v, [
            (0.0, (0, 0, 0)),
            (0.25, (0.6, 0.08, 0.0)),
            (0.55, (1.0, 0.45, 0.05)),
            (0.85, (1.0, 0.85, 0.25)),
            (1.0, (1.0, 1.0, 0.9))
        ])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

# 5. CITÉ DÉCHUE : Salve de 4 obus traceurs qui éclatent en l'air en anneau d'éclats
def vfx_cite_flak():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        if t < 0.4:
            # 4 obus traceurs supersoniques avec onde de Mach
            u1 = t / 0.4
            img = np.zeros((S, S))
            for k in range(4):
                off_ang = k * (np.pi * 0.5) + 0.2
                dx = np.cos(off_ang) * (u1 * 35.0)
                dy = np.sin(off_ang) * (u1 * 35.0)
                dart_d = np.hypot(X - dx, Y - dy)
                img = np.maximum(img, np.exp(-(dart_d / 3.0)**2) * 1.6)
            v = img
        else:
            # Airburst en anneau d'éclats de tungstène et onde de choc
            u2 = (t - 0.4) / 0.6
            rad = 8.0 + u2 * 46.0
            ring = np.exp(-((R - rad) / (2.5 + u2 * 4.0))**2)
            # 16 éclats incandescents réguliers
            teeth = (0.5 + 0.5 * np.cos(16 * TH))**10
            shrap = np.exp(-((R - rad * 1.05) / 2.0)**2) * teeth * 2.2
            smoke_cloud = np.clip(1.0 - R / (rad + 6.0), 0, 1) * vnoise(S, S, 12, 85 + i) * (1.0 - u2)
            v = np.clip(ring * 1.2 + shrap + smoke_cloud * 0.7, 0, 1) * (1.0 - u2 * 0.4)
            
        v = gaussian_filter(v, 0.6)
        rgb = ramp(v, [
            (0.0, (0, 0, 0)),
            (0.3, (0.8, 0.4, 0.1)),
            (0.65, (1.0, 0.8, 0.3)),
            (0.9, (1.0, 0.95, 0.8)),
            (1.0, (1.0, 1.0, 1.0))
        ])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

# 6. CRYO : Orbe lent qui vous suit, ligne de givre, traînée de glace, nova
def vfx_cryo_orb():
    fr = []
    spike8 = (0.5 + 0.5 * np.cos(8 * TH))**8
    for i in range(NF):
        t = i / (NF - 1)
        if t < 0.5:
            # Orbe cristallin fractal à 8 branches avec pulsation sub-zéro
            u1 = t / 0.5
            pulse = 16.0 + 3.0 * np.sin(u1 * np.pi * 4.0)
            core = np.exp(-(R / pulse)**2)
            crystals = np.exp(-((R - pulse * 0.8) / 3.0)**2) * spike8 * 2.0
            n_frost = vnoise(S, S, 8, 90 + i)
            v = np.clip(core * 0.8 + crystals + n_frost * 0.25 * (R < pulse), 0, 1)
        else:
            # Nova cryogénique d'explosion d'azote et onde de gel
            u2 = (t - 0.5) / 0.5
            rad_nova = 10.0 + u2 * 48.0
            ring_ice = np.exp(-((R - rad_nova) / (3.0 + u2 * 6.0))**2) * (0.3 + 0.7 * spike8)
            dendrites = np.exp(-((R - rad_nova * 0.6) / 4.0)**2) * (0.5 + 0.5 * np.cos(16 * TH))**6
            v = np.clip(ring_ice * 1.8 + dendrites * 1.4, 0, 1) * (1.0 - u2 * 0.3)
            
        v = gaussian_filter(v, 0.7)
        rgb = ramp(v, [
            (0.0, (0, 0, 0)),
            (0.3, (0.15, 0.5, 0.9)),
            (0.65, (0.5, 0.85, 1.0)),
            (0.88, (0.85, 0.98, 1.0)),
            (1.0, (1.0, 1.0, 1.0))
        ])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

# 7. NOYAU INSTABLE : Charge en 3 paliers (canon vibre), boule qui se scinde en 3 éclairs
def vfx_noyau_plasma():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        if t < 0.5:
            # Charge en 3 paliers avec anneaux magnétiques
            palier = int(t / 0.17) + 1
            rad_core = 10.0 + palier * 6.0 + np.sin(t * 30.0) * 2.0
            core = np.exp(-(R / rad_core)**2)
            rings = 0
            for k in range(palier):
                rk = 8.0 + k * 12.0
                rings += np.exp(-((R - rk) / 2.0)**2) * 0.8
            n_arc = vnoise(S, S, 6, 120 + i)
            arcs = (n_arc > 0.75).astype(float) * np.exp(-(R / (rad_core + 8.0))**2)
            v = np.clip(core * 1.2 + rings + arcs * 1.5, 0, 1)
        else:
            # Scission en 3 éclairs de rupture
            u2 = (t - 0.5) / 0.5
            v = np.zeros((S, S))
            for k in range(3):
                b_ang = (k - 1) * 0.55 + 0.0
                dx = np.cos(b_ang)
                dy = np.sin(b_ang)
                d_long = X * dx + Y * dy
                d_perp = np.abs(X * dy - Y * dx)
                n_b = vnoise(S, S, 6, 150 + i * 3 + k)
                bolt = np.exp(-((d_perp + (n_b - 0.5) * 6.0) / 2.2)**2) * (d_long > 0) * (d_long < u2 * 54.0 + 8.0)
                v = np.maximum(v, bolt * 1.8)
            flash = np.exp(-(R / (12.0 + u2 * 25.0))**2) * (1.0 - u2)
            v = np.clip(v + flash * 1.4, 0, 1)
            
        v = gaussian_filter(v, 0.7)
        rgb = ramp(v, [
            (0.0, (0, 0, 0)),
            (0.3, (0.4, 0.1, 0.8)),
            (0.65, (0.2, 0.7, 1.0)),
            (0.85, (0.7, 0.95, 1.0)),
            (1.0, (1.0, 1.0, 1.0))
        ])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

# 8. RUCHE : La poche gonfle, 3 globules qui s'étirent, flaques d'acide qui fument
def vfx_ruche_acid():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        if t < 0.4:
            # 3 globules d'acide étirés en goutte visqueuse à tension de surface
            u1 = t / 0.4
            v = np.zeros((S, S))
            for k in range(3):
                off_y = (k - 1) * 14.0
                fly_x = (u1 - 0.5) * 50.0
                # Profil de goutte étirée
                dx = X - fly_x
                dy = Y - off_y
                tear = np.hypot(dx * 0.7, dy * 1.4)
                blob = np.exp(-(tear / 10.0)**2)
                v = np.maximum(v, blob * 1.6)
        else:
            # Éclaboussure caustique et flaque d'acide fumante
            u2 = (t - 0.4) / 0.6
            r_acid = 12.0 + u2 * 34.0
            puddle = np.clip(1.0 - np.hypot(X, Y * 1.4) / r_acid, 0, 1)**1.2
            # Bulles et vapeur toxique montante
            n_steam = vnoise(S, S, 10, 180 + i)
            steam = np.clip(1.0 - np.hypot(X, Y + u2 * 20.0) / (r_acid * 1.2), 0, 1) * n_steam * 0.8
            v = np.clip(puddle * 1.4 + steam * 0.9, 0, 1) * (1.0 - u2 * 0.2)
            
        v = gaussian_filter(v, 0.7)
        rgb = ramp(v, [
            (0.0, (0, 0, 0)),
            (0.25, (0.1, 0.5, 0.05)),
            (0.6, (0.5, 0.95, 0.15)),
            (0.85, (0.85, 1.0, 0.4)),
            (1.0, (1.0, 1.0, 1.0))
        ])
        fr.append((rgb, np.clip(v * 1.5, 0, 1)))
    return fr

# 9. CITADELLE : Réticule de verrouillage qui se resserre, 5 missiles verticaux puis guidés
def vfx_citadelle_missile():
    fr = []
    for i in range(NF):
        t = i / (NF - 1)
        if t < 0.45:
            # Réticule de verrouillage HUD militaire (4 crochets + anneau + strobe)
            u1 = t / 0.45
            r_hud = (1.0 - u1**1.4) * 36.0 + 12.0
            ring_hud = np.exp(-((R - r_hud) / 1.5)**2)
            # Crochets cardinaux
            brackets = ((np.abs(X) < 2.0) | (np.abs(Y) < 2.0)) & (R > r_hud * 0.7) & (R < r_hud * 1.3)
            # Alarme strobe
            strobe = 0.5 + 0.5 * np.sin(u1 * np.pi * 8.0)
            v = np.clip(ring_hud * 1.4 + brackets * 1.0, 0, 1) * strobe
        else:
            # Détonation explosive de missile guidé avec onde de compression et shrapnel
            u2 = (t - 0.45) / 0.55
            r_blast = 8.0 + u2 * 45.0
            ring_blast = np.exp(-((R - r_blast) / (3.0 + u2 * 5.0))**2)
            core_blast = np.exp(-(R / (10.0 + u2 * 20.0))**2) * (1.0 - u2)
            smoke = np.clip(1.0 - R / (r_blast + 4.0), 0, 1) * vnoise(S, S, 10, 200 + i) * 0.7 * (1.0 - u2 * 0.6)
            v = np.clip(ring_blast * 1.5 + core_blast * 2.2 + smoke, 0, 1)
            
        v = gaussian_filter(v, 0.6)
        rgb = ramp(v, [
            (0.0, (0, 0, 0)),
            (0.3, (0.8, 0.1, 0.05)),
            (0.65, (1.0, 0.65, 0.15)),
            (0.88, (1.0, 0.95, 0.6)),
            (1.0, (1.0, 1.0, 1.0))
        ])
        fr.append((rgb, np.clip(v * 1.6, 0, 1)))
    return fr

# =============================================================================
# EXÉCUTION DU PIPELINE
# =============================================================================
def main():
    print("=== GÉNÉRATION DES 9 EFFETS SPÉCIAUX DE TOURELLES ANIMÉS (VFX HORLOGER) ===")
    vfx_list = [
        ("vfx_usine_weld", vfx_usine_weld),
        ("vfx_calcin_solar", vfx_calcin_solar),
        ("vfx_ruine_pod", vfx_ruine_pod),
        ("vfx_forge_magma", vfx_forge_magma),
        ("vfx_cite_flak", vfx_cite_flak),
        ("vfx_cryo_orb", vfx_cryo_orb),
        ("vfx_noyau_plasma", vfx_noyau_plasma),
        ("vfx_ruche_acid", vfx_ruche_acid),
        ("vfx_citadelle_missile", vfx_citadelle_missile),
    ]
    
    for name, func in vfx_list:
        frames = func()
        save_vfx(name, frames)
        
    print("\n=== TOUS LES 9 EFFETS ANIMÉS ONT ÉTÉ GÉNÉRÉS AVEC SUCCÈS ===")

if __name__ == "__main__":
    main()
