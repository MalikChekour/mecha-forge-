#!/usr/bin/env python3
"""
Générateur des 4 STYLES VFX ANIMÉS pour comparaison directe.
Produit 4 animations 24 frames distinctes + 1 planche comparative 2x2 animée en boucle :
- Style 1 : Anime / Sakuga 2D (formes tranchantes, contours nets, cell-shading 3 tons, étoiles d'impact)
- Style 2 : Simulation 3D Cinématique (couronne de fluide magma visqueux, éclats de roche, fumée volumétrique)
- Style 3 : Cyberpunk High-Tech HUD (vecteurs néon, anneaux holographiques, lasers haute saturation, zéro fumée)
- Style 4 : Dark Fantasy Peint (matière texturée, coups de pinceau impasto, goudron organique et braises)
"""
import os, shutil, math
import numpy as np
from scipy.ndimage import gaussian_filter, zoom
import imageio
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "refs", "vfx_showcase")
ART = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\f4d60812-8c84-40f0-9aad-921d86be3fca"
os.makedirs(OUT, exist_ok=True)

S = 256
NF = 24
FPS = 24

yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
X = xx - S / 2.0
Y = yy - S / 2.0
R = np.hypot(X, Y)
TH = np.arctan2(Y, X)

def fbm2d(s, octaves=3, base=12, seed=42):
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

# -----------------------------------------------------------------------------
# 1. STYLE 1 : ANIME / SAKUGA 2D
# -----------------------------------------------------------------------------
def gen_style1_anime():
    frames = []
    for f in range(NF):
        u = f / float(NF)
        img = np.zeros((S, S, 3), dtype=np.float32)
        
        # Fond sombre
        img[:] = [0.08, 0.09, 0.11]
        
        # Explosion en 3 phases typiques Anime : Snap instantané -> Peak stylisé -> Étoiles & fumée graphique
        if u < 0.15:
            # Phase 0 : Flash de contact net
            rad = 20.0 + u * 150.0
            flash = (R < rad).astype(np.float32)
            img = np.where(flash[..., None] > 0, [1.0, 1.0, 1.0], img)
        else:
            # Forme en lobes dentelés cartoonesques (Sakuga cloud)
            lobes = np.sin(TH * 7.0 + 1.2) * 18.0 + np.cos(TH * 4.0) * 12.0
            r_peak = 35.0 + (u ** 0.5) * 85.0
            
            mask_out = (R < (r_peak + lobes)).astype(np.float32)
            mask_mid = (R < (r_peak * 0.75 + lobes * 0.7)).astype(np.float32)
            mask_core = (R < (r_peak * 0.45 + lobes * 0.4)).astype(np.float32)
            
            # Contour à l'encre noire nette (Ink outline)
            edge = gaussian_filter(mask_out, 1.0)
            outline = ((edge > 0.15) & (edge < 0.85)).astype(np.float32)
            
            # Palette cell-shading 3 tons franche
            # Fond orange feu, milieu jaune vif, cœur blanc/crème
            fill = np.zeros_like(img)
            fill[mask_out > 0] = [0.98, 0.35, 0.05]   # Orange vif
            fill[mask_mid > 0] = [1.0, 0.85, 0.1]    # Jaune punch
            fill[mask_core > 0] = [1.0, 0.98, 0.85]  # Blanc chaud
            
            # Étoiles d'impact magenta / violet stylisées (marqueurs visuels Trigger)
            star_shape = np.zeros((S, S), dtype=np.float32)
            for s_idx in range(5):
                s_ang = s_idx * (np.pi * 2.0 / 5.0) + 0.3
                s_dist = 25.0 + u * 95.0
                sx = X - np.cos(s_ang) * s_dist
                sy = Y - np.sin(s_ang) * s_dist
                d_cross = np.minimum(np.abs(sx) + np.abs(sy) * 0.25, np.abs(sy) + np.abs(sx) * 0.25)
                star_shape = np.maximum(star_shape, (d_cross < 6.0).astype(np.float32))
            
            # Croissants de flammes détachés
            crescents = np.zeros((S, S), dtype=np.float32)
            for c_idx in range(6):
                c_ang = c_idx * 1.05 + 0.2
                c_dist = 40.0 + u * 80.0
                cx_ = X - np.cos(c_ang) * c_dist
                cy_ = Y - np.sin(c_ang) * c_dist
                c_r = np.hypot(cx_, cy_)
                crescents = np.maximum(crescents, ((c_r > 8.0) & (c_r < 14.0) & (cx_ > 0)).astype(np.float32))
            
            # Assemblage cell-shaded sans dégradé flou
            img = np.where(mask_out[..., None] > 0, fill, img)
            img = np.where(star_shape[..., None] > 0, [0.95, 0.15, 0.65], img) # Magenta vif
            img = np.where(crescents[..., None] > 0, [1.0, 0.65, 0.1], img)
            img = np.where(outline[..., None] > 0, [0.08, 0.08, 0.1], img)     # Ligne d'encre noire
            
        frames.append((img * 255.0).astype(np.uint8))
    return frames

# -----------------------------------------------------------------------------
# 2. STYLE 2 : CINEMATIC 3D SIMULATION (Lave fluide + Fumée + Éclats)
# -----------------------------------------------------------------------------
def gen_style2_3d():
    frames = []
    rng = np.random.default_rng(202)
    N_ROCKS = 24
    r_ang = rng.uniform(0, np.pi * 2.0, N_ROCKS)
    r_spd = rng.uniform(30.0, 85.0, N_ROCKS)
    r_sz = rng.uniform(4.0, 9.0, N_ROCKS)
    
    for f in range(NF):
        u = f / float(NF)
        img = np.zeros((S, S, 3), dtype=np.float32)
        img[:] = [0.07, 0.08, 0.09]
        
        # 1. Nappe volumétrique de fumée noire dense et lourde
        smoke_r = 15.0 + (u ** 0.6) * 85.0
        n_smoke = fbm2d(S, octaves=4, base=10, seed=300 + f)
        smoke_mask = np.clip(1.0 - (R / smoke_r) * (0.6 + 0.6 * n_smoke), 0.0, 1.0) ** 1.8
        smoke_col = np.array([0.14, 0.13, 0.12], dtype=np.float32)
        
        # 2. Couronne de fluide magma (splatter crown de lave en fusion)
        splash_r = 18.0 + u * 65.0
        crown_edge = np.exp(-((R - splash_r) / 8.0) ** 2) * (0.6 + 0.4 * np.sin(TH * 14.0))
        puddle = np.clip(1.0 - np.hypot(X, Y * 1.5) / (splash_r * 0.9), 0.0, 1.0) ** 1.4
        
        # Émission thermique interne (foyer incandescent qui éclaire la fumée par en-dessous)
        core_heat = np.exp(-(R / (15.0 + 35.0 * (1.0 - u))) ** 2) * (1.0 - u * 0.6)
        
        # 3. Éclats de basalte solides qui volent
        rocks = np.zeros((S, S), dtype=np.float32)
        for k in range(N_ROCKS):
            rx = int(S / 2 + np.cos(r_ang[k]) * r_spd[k] * (u ** 0.85))
            ry = int(S / 2 + np.sin(r_ang[k]) * r_spd[k] * (u ** 0.85) * 0.7 - (u - u**2) * 35.0)
            if 3 <= rx < S - 3 and 3 <= ry < S - 3:
                rsz = int(r_sz[k])
                rocks[ry-rsz:ry+rsz, rx-rsz:rx+rsz] = 1.0
        rocks = gaussian_filter(rocks, 0.5)
        
        # Assemblage physique 3D
        # Fumée
        img = img * (1.0 - smoke_mask[..., None]) + smoke_col * smoke_mask[..., None]
        # Éclairage de la fumée par le cœur
        img += np.array([0.9, 0.4, 0.1]) * core_heat[..., None] * smoke_mask[..., None] * 0.8
        # Lave en fusion
        lava_tex = crown_edge + puddle * 1.5 + core_heat * 2.0
        lava_col = np.array([1.0, 0.5, 0.08]) * lava_tex[..., None]
        img = np.maximum(img, lava_col)
        # Point blanc chaud au cœur
        img += np.array([1.0, 0.95, 0.8]) * (core_heat[..., None] ** 2) * 1.5
        # Roches de basalte
        img = np.where(rocks[..., None] > 0.3, [0.22, 0.18, 0.17], img)
        
        frames.append(np.clip(img * 255.0, 0, 255).astype(np.uint8))
    return frames

# -----------------------------------------------------------------------------
# 3. STYLE 3 : CYBERPUNK / HIGH-TECH HUD (Vecteurs néon, lasers, anneaux)
# -----------------------------------------------------------------------------
def gen_style3_cyberpunk():
    frames = []
    for f in range(NF):
        u = f / float(NF)
        img = np.zeros((S, S, 3), dtype=np.float32)
        img[:] = [0.06, 0.07, 0.09]
        
        # 1. Anneaux holographiques vectoriels ultra-nets
        r1 = (1.0 - u**1.5) * 80.0 + 16.0
        r2 = r1 * 0.65
        ring1 = np.exp(-((R - r1) / 1.5) ** 2)
        ring2 = np.exp(-((R - r2) / 1.0) ** 2)
        
        # Graduations et calipers cardinaux
        ticks = ((np.cos(TH * 32.0) > 0.7) & (np.abs(R - r1) < 4.0)).astype(np.float32)
        cross = ((np.abs(X) < 1.5) | (np.abs(Y) < 1.5)) & (R > r1 * 0.5) & (R < r1 * 1.3)
        
        # 2. Lasers haute saturation croisés (Cyan pur et Orange ambre)
        l1 = np.exp(-(np.abs(X + Y * 0.5) / 2.0) ** 2) * (1.0 - u * 0.3)
        l2 = np.exp(-(np.abs(Y - X * 0.3) / 1.5) ** 2) * (1.0 - u * 0.3)
        
        # 3. Spikes d'énergie vectoriels
        spikes = (0.5 + 0.5 * np.cos(TH * 8.0)) ** 18 * np.exp(-(R / (r1 + 25.0)) ** 2)
        
        # Onde de choc numérique en expansion
        shock = np.exp(-((R - u * 110.0) / 3.0) ** 2) * (1.0 - u)
        
        # Cœur néon
        core = np.exp(-(R / (8.0 + 16.0 * (1.0 - u))) ** 2) * 2.0
        
        # Couleurs néon pures additives (Cyan néon + Ambre chaud)
        cyan_chan = (ring1 * 1.5 + ring2 + cross * 1.2 + l1 * 2.0 + shock * 1.5 + core)
        orange_chan = (ticks * 1.5 + l2 * 2.2 + spikes * 2.0 + core * 0.8)
        
        img[..., 0] += orange_chan * 1.0 + cyan_chan * 0.1
        img[..., 1] += orange_chan * 0.6 + cyan_chan * 0.85
        img[..., 2] += orange_chan * 0.1 + cyan_chan * 1.0
        
        frames.append(np.clip(img * 255.0, 0, 255).astype(np.uint8))
    return frames

# -----------------------------------------------------------------------------
# 4. STYLE 4 : PAINTERLY DARK FANTASY (Coups de pinceau texturés, empâtement)
# -----------------------------------------------------------------------------
def gen_style4_painterly():
    frames = []
    for f in range(NF):
        u = f / float(NF)
        img = np.zeros((S, S, 3), dtype=np.float32)
        img[:] = [0.12, 0.09, 0.08]
        
        # Bruit de texture de toile / coup de pinceau (directional brush strokes)
        brush_tex = fbm2d(S, octaves=4, base=8, seed=400)
        angle_stroke = np.sin(X * 0.15 + Y * 0.05 + brush_tex * 4.0)
        
        # Masse organique de goudron / braises qui explose
        r_blast = 20.0 + (u ** 0.7) * 75.0
        splatter = np.clip(1.0 - (R / r_blast) + (angle_stroke * 0.3), 0.0, 1.0)
        
        # Éclats de matière dense et giclées épaisses (empâtement)
        tar_droplets = (brush_tex > 0.68).astype(np.float32) * np.exp(-(R / (r_blast + 25.0)) ** 2)
        
        # Braises peintes à la main
        fire_core = np.exp(-(R / (18.0 + 30.0 * (1.0 - u))) ** 2) * (1.0 - u * 0.4)
        
        # Couleurs de peinture à l'huile : Sienne brûlée, Noir de fumée, Ocre d'or, Blanc de titane
        c_tar = np.array([0.18, 0.12, 0.10])
        c_burnt = np.array([0.72, 0.22, 0.05])
        c_gold = np.array([0.98, 0.65, 0.12])
        c_white = np.array([1.0, 0.95, 0.85])
        
        # Application par couches texturées (comme un tableau)
        paint = c_tar * splatter[..., None]
        paint = np.where(splatter[..., None] > 0.4, c_burnt * splatter[..., None] * 1.3, paint)
        paint = np.where(fire_core[..., None] > 0.3, c_gold * fire_core[..., None] * 1.6, paint)
        paint = np.where(fire_core[..., None] > 0.75, c_white * fire_core[..., None] * 2.0, paint)
        paint = np.where(tar_droplets[..., None] > 0.5, c_tar * 1.4, paint)
        
        img = img * (1.0 - np.clip(splatter[..., None] * 1.2, 0, 1)) + paint
        frames.append(np.clip(img * 255.0, 0, 255).astype(np.uint8))
    return frames

# -----------------------------------------------------------------------------
# MAIN & PLANCHE COMPARATIVE 2x2
# -----------------------------------------------------------------------------
def main():
    print("=== GÉNÉRATION DES 4 STYLES VFX ANIMÉS EN PARALLÈLE ===")
    
    styles = [
        ("anim_style1_anime", "Style 1: Anime / Sakuga 2D (Hades)", gen_style1_anime),
        ("anim_style2_3d", "Style 2: Simulation 3D (Diablo/Unreal)", gen_style2_3d),
        ("anim_style3_cyberpunk", "Style 3: Cyberpunk HUD (Hi-Tech)", gen_style3_cyberpunk),
        ("anim_style4_painterly", "Style 4: Dark Fantasy Peint", gen_style4_painterly),
    ]
    
    rendered = {}
    for filename, title, generator in styles:
        print(f"Génération de {title}...")
        frames = generator()
        rendered[filename] = frames
        gif_path = os.path.join(OUT, f"{filename}.gif")
        imageio.mimsave(gif_path, frames, fps=FPS, loop=0)
        print(f"  -> Sauvegardé : {gif_path}")
        if os.path.exists(ART):
            shutil.copyfile(gif_path, os.path.join(ART, f"{filename}.gif"))
            
    # Planche comparative 2x2 animée en boucle
    print("\n--- Assemblage de la planche 2x2 comparative animée ---")
    comp_frames = []
    W_comp = S * 2 + 30
    H_comp = S * 2 + 70
    
    try:
        font_t = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 15)
        font_lbl = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 12)
    except Exception:
        font_t = font_lbl = ImageFont.load_default()
        
    for f in range(NF):
        board = Image.new("RGB", (W_comp, H_comp), (12, 14, 18))
        draw = ImageDraw.Draw(board)
        draw.rectangle([(0, 0), (W_comp, 32)], fill=(18, 22, 30))
        draw.text((15, 6), "COMPARAISON DES 4 STYLES VFX ANIMÉS (60 FPS LOOP)", font=font_t, fill=(240, 245, 255))
        
        pos_map = [
            (10, 40, "anim_style1_anime", "1. ANIME / SAKUGA 2D"),
            (S + 20, 40, "anim_style2_3d", "2. SIMULATION 3D MATIÈRE"),
            (10, S + 55, "anim_style3_cyberpunk", "3. CYBERPUNK HUD NÉON"),
            (S + 20, S + 55, "anim_style4_painterly", "4. DARK FANTASY PEINT"),
        ]
        
        for px, py, key, lbl in pos_map:
            fr_arr = rendered[key][f]
            im_tile = Image.fromarray(fr_arr)
            board.paste(im_tile, (px, py))
            draw.rectangle([(px, py), (px + S, py + 18)], fill=(10, 12, 16))
            draw.text((px + 6, py + 2), lbl, font=font_lbl, fill=(220, 230, 255))
            draw.rectangle([(px, py), (px + S, py + S)], outline=(35, 45, 60), width=1)
            
        comp_frames.append(board)
        
    comp_gif_path = os.path.join(OUT, "anim_palette_comparison.gif")
    comp_frames[0].save(comp_gif_path, save_all=True, append_images=comp_frames[1:], duration=42, loop=0)
    print(f"Planche comparative 2x2 animée sauvegardée : {comp_gif_path}")
    if os.path.exists(ART):
        shutil.copyfile(comp_gif_path, os.path.join(ART, "anim_palette_comparison.gif"))
        print("Copiée dans artéfacts.")

    print("\n=== TOUS LES STYLES ANIMÉS ONT ÉTÉ GÉNÉRÉS ===")

if __name__ == "__main__":
    main()
