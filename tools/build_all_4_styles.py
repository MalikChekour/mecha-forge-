#!/usr/bin/env python3
"""
Générateur des 3 STYLES VFX RETENUS (SANS ANIME SAKUGA) :
1. SIMULATION 3D MATIÈRE (Diablo / Unreal) : magma, fumée dense, débris physiques
2. CYBERPUNK HUD NÉON (The Ascent / Sci-Fi) : lasers purs, réticules vectoriels, géométrie néon
3. DARK FANTASY PEINT (Elden Ring) : empâtement organique, matière texturée, goudron et spores

Génère les 3 dossiers complets de planches 4x4 (768x768) :
- game/assets/vfx/ts/sim3d/
- game/assets/vfx/ts/cyber/
- game/assets/vfx/ts/paint/

Et déploie la composition harmonieuse sans anime à la racine de ts/ :
- Forge, Cité Déchue -> SIM3D
- Usine, Terres Calcinées, Cryo, Noyau Instable, Citadelle -> CYBER
- Ruche, Ruine Verte -> PAINT
"""
import os, shutil
import numpy as np
from scipy.ndimage import gaussian_filter, zoom
from PIL import Image, ImageDraw, ImageFont
import imageio

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE_VFX = os.path.join(ROOT, "game", "assets", "vfx", "ts")
OUT_SHOWCASE = os.path.join(ROOT, "refs", "vfx_showcase")
ART = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\f4d60812-8c84-40f0-9aad-921d86be3fca"
os.makedirs(BASE_VFX, exist_ok=True)
os.makedirs(OUT_SHOWCASE, exist_ok=True)

S = 192
GRID = 4
SHEET_S = S * GRID

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

def ramp_color(t, stops):
    t_flat = np.clip(t.flatten(), 0.0, 1.0)
    pos = np.array([s[0] for s in stops], dtype=np.float32)
    cols = np.array([s[1] for s in stops], dtype=np.float32)
    out = np.zeros((len(t_flat), 3), dtype=np.float32)
    for c in range(3):
        out[:, c] = np.interp(t_flat, pos, cols[:, c])
    return out.reshape(t.shape + (3,))

def render_frame(kind, style, u, f_idx):
    # ------------------ 1. SIMULATION 3D MATIÈRE ------------------
    if style == "sim3d":
        noise = fbm2d(S, octaves=3, base=10, seed=100 + f_idx)
        r_blast = 15.0 + (u ** 0.6) * 65.0
        crown = np.exp(-((R - r_blast) / 7.0)**2) * (0.6 + 0.4 * np.sin(TH * 12.0))
        puddle = np.clip(1.0 - R / (r_blast * 0.95), 0.0, 1.0) ** 1.3
        smoke = np.clip(1.0 - (R / (r_blast + 12.0)) * (0.5 + 0.5 * noise), 0.0, 1.0) * (1.0 - u * 0.5)
        heat = np.exp(-(R / (12.0 + 25.0 * (1.0 - u)))**2) * (1.0 - u * 0.4)
        total = np.clip(crown * 1.5 + puddle * 1.2 + heat * 2.0, 0.0, 1.0)
        
        if kind in ["slag", "smoke", "missile"]:
            rgb = ramp_color(total, [(0.0, (0.1, 0.08, 0.08)), (0.3, (0.8, 0.2, 0.02)), (0.7, (1.0, 0.65, 0.1)), (1.0, (1.0, 0.98, 0.85))])
        elif kind == "ice":
            rgb = ramp_color(total, [(0.0, (0.05, 0.1, 0.15)), (0.35, (0.2, 0.6, 0.95)), (0.75, (0.6, 0.9, 1.0)), (1.0, (1.0, 1.0, 1.0))])
        elif kind in ["acid", "pod"]:
            rgb = ramp_color(total, [(0.0, (0.05, 0.1, 0.05)), (0.35, (0.2, 0.7, 0.1)), (0.75, (0.6, 1.0, 0.3)), (1.0, (0.95, 1.0, 0.8))])
        else:
            rgb = ramp_color(total, [(0.0, (0.1, 0.05, 0.15)), (0.35, (0.5, 0.15, 0.85)), (0.75, (0.3, 0.8, 1.0)), (1.0, (1.0, 1.0, 1.0))])
            
        alpha = np.clip(total * 1.5 + smoke * 0.6, 0.0, 1.0) * (1.0 - u * 0.3)
        return rgb, alpha

    # ------------------ 2. CYBERPUNK HUD NÉON ------------------
    elif style == "cyber":
        r_ring = (1.0 - u**1.4) * 60.0 + 12.0
        ring = np.exp(-((R - r_ring) / 1.6)**2)
        shock = np.exp(-((R - u * 85.0) / 2.5)**2) * (1.0 - u)
        calipers = ((np.abs(X) < 1.6) | (np.abs(Y) < 1.6)) & (R > r_ring * 0.6) & (R < r_ring * 1.4)
        spikes = (0.5 + 0.5 * np.cos(TH * 8.0))**20 * np.exp(-(R / (r_ring + 20.0))**2)
        core = np.exp(-(R / (6.0 + 14.0 * (1.0 - u)))**2) * 2.0
        neon_val = np.clip(ring * 1.8 + shock * 1.6 + calipers * 1.4 + spikes * 2.0 + core, 0.0, 1.0)
        
        if kind in ["slag", "smoke", "missile"]:
            rgb = ramp_color(neon_val, [(0.0, (0, 0, 0)), (0.3, (0.9, 0.3, 0.05)), (0.7, (1.0, 0.75, 0.15)), (1.0, (1.0, 1.0, 1.0))])
        elif kind in ["ice", "plasma"]:
            rgb = ramp_color(neon_val, [(0.0, (0, 0, 0)), (0.3, (0.05, 0.6, 1.0)), (0.7, (0.4, 0.9, 1.0)), (1.0, (1.0, 1.0, 1.0))])
        else:
            rgb = ramp_color(neon_val, [(0.0, (0, 0, 0)), (0.3, (0.1, 0.8, 0.1)), (0.7, (0.5, 1.0, 0.3)), (1.0, (1.0, 1.0, 1.0))])
            
        alpha = np.clip(neon_val * 1.6, 0.0, 1.0)
        return rgb, alpha

    # ------------------ 3. DARK FANTASY PEINT ------------------
    else: # "paint"
        tex = fbm2d(S, octaves=4, base=8, seed=300 + f_idx)
        r_paint = 16.0 + (u ** 0.65) * 60.0
        splatter = np.clip(1.0 - (R / r_paint) + (tex - 0.5) * 0.45, 0.0, 1.0)
        fire = np.exp(-(R / (14.0 + 24.0 * (1.0 - u)))**2) * (1.0 - u * 0.4)
        total = np.clip(splatter * 1.3 + fire * 1.8, 0.0, 1.0)
        
        if kind in ["slag", "smoke", "missile"]:
            rgb = ramp_color(total, [(0.0, (0.15, 0.1, 0.08)), (0.35, (0.75, 0.22, 0.05)), (0.75, (0.98, 0.7, 0.15)), (1.0, (1.0, 0.96, 0.85))])
        elif kind == "ice":
            rgb = ramp_color(total, [(0.0, (0.08, 0.12, 0.16)), (0.35, (0.2, 0.55, 0.85)), (0.75, (0.55, 0.85, 0.98)), (1.0, (1.0, 1.0, 1.0))])
        elif kind in ["acid", "pod"]:
            rgb = ramp_color(total, [(0.0, (0.08, 0.14, 0.08)), (0.35, (0.3, 0.7, 0.15)), (0.75, (0.7, 0.95, 0.35)), (1.0, (0.95, 1.0, 0.8))])
        else:
            rgb = ramp_color(total, [(0.0, (0.12, 0.08, 0.18)), (0.35, (0.55, 0.15, 0.75)), (0.75, (0.4, 0.75, 0.98)), (1.0, (1.0, 1.0, 1.0))])
            
        alpha = np.clip(total * 1.5, 0.0, 1.0) * (1.0 - u * 0.3)
        return rgb, alpha

def generate_sheet(kind, style):
    sheet_arr = np.zeros((SHEET_S, SHEET_S, 4), dtype=np.uint8)
    for i in range(16):
        u = i / 15.0
        rgb, a = render_frame(kind, style, u, i)
        r, c = divmod(i, GRID)
        y0, x0 = r * S, c * S
        rgba = np.zeros((S, S, 4), dtype=np.uint8)
        rgba[..., :3] = np.clip(rgb * 255.0, 0, 255).astype(np.uint8)
        rgba[..., 3] = np.clip(a * 255.0, 0, 255).astype(np.uint8)
        sheet_arr[y0:y0+S, x0:x0+S] = rgba
    return Image.fromarray(sheet_arr, "RGBA")

def main():
    print("=== DÉPLOIEMENT DES 3 STYLES CHOISIS (SANS ANIME SAKUGA) ===")
    styles = ["sim3d", "cyber", "paint"]
    kinds = ["slag", "ice", "acid", "pod", "smoke", "plasma", "missile"]
    
    for st in styles:
        st_dir = os.path.join(BASE_VFX, st)
        os.makedirs(st_dir, exist_ok=True)
        print(f"\n--- Style : {st.upper()} -> {st_dir} ---")
        for k in kinds:
            sheet_img = generate_sheet(k, st)
            filename = f"ts_{k}_impact.png"
            out_p = os.path.join(st_dir, filename)
            sheet_img.save(out_p)
            print(f"  [OK] {filename}")
            
    # Déploiement optimal sans anime :
    # Artillerie lourde & physique -> SIM3D
    # Énergie & Lasers purs -> CYBER
    # Biologique & Toxique -> PAINT
    print("\n--- Déploiement harmonieux à la racine ts/ ---")
    mapping = {
        "ts_slag_impact.png": ("sim3d", "Forge (Lave lourde & fumée)"),
        "ts_smoke_impact.png": ("sim3d", "Cité Déchue (Flak & éclats)"),
        "ts_ice_impact.png": ("cyber", "Cryo (Cristaux néon & nova cyan)"),
        "ts_plasma_impact.png": ("cyber", "Noyau Instable (Plasma laser)"),
        "ts_missile_impact.png": ("cyber", "Citadelle (Verrouillage HUD)"),
        "ts_acid_impact.png": ("paint", "Ruche (Goudron acide visqueux)"),
        "ts_pod_impact.png": ("paint", "Ruine Verte (Cosse organique & spores)"),
    }
    
    for fname, (st, desc) in mapping.items():
        src_p = os.path.join(BASE_VFX, st, fname)
        dst_p = os.path.join(BASE_VFX, fname)
        if os.path.exists(src_p):
            shutil.copyfile(src_p, dst_p)
            print(f"  {fname:22s} <- [{st.upper()}] {desc}")
            
    # Génération du comparatif animé 1x3 pour les 3 styles retenus
    print("\n--- Assemblage du GIF comparatif 1x3 des 3 styles retenus ---")
    comp_frames = []
    NF_C = 24
    cell_w = 220
    cell_h = 220
    W_C = cell_w * 3 + 40
    H_C = cell_h + 60
    
    try:
        font_t = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 15)
        font_l = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 12)
    except Exception:
        font_t = font_l = ImageFont.load_default()
        
    gif_3d = imageio.mimread(os.path.join(OUT_SHOWCASE, "anim_style2_3d.gif"))
    gif_cyber = imageio.mimread(os.path.join(OUT_SHOWCASE, "anim_style3_cyberpunk.gif"))
    gif_paint = imageio.mimread(os.path.join(OUT_SHOWCASE, "anim_style4_painterly.gif"))
    
    for f in range(min(len(gif_3d), len(gif_cyber), len(gif_paint))):
        board = Image.new("RGB", (W_C, H_C), (12, 14, 18))
        draw = ImageDraw.Draw(board)
        draw.rectangle([(0, 0), (W_C, 30)], fill=(18, 22, 30))
        draw.text((15, 6), "LES 3 STYLES RETENUS (SANS ANIME SAKUGA)", font=font_t, fill=(240, 245, 255))
        
        cards = [
            (10, gif_3d[f], "1. SIMULATION 3D MATIÈRE (Forge, Cité)"),
            (cell_w + 20, gif_cyber[f], "2. CYBERPUNK HUD NÉON (Cryo, Noyau, Citadelle)"),
            (cell_w * 2 + 30, gif_paint[f], "3. DARK FANTASY PEINT (Ruche, Ruine)"),
        ]
        
        for px, fr_data, title in cards:
            im_tile = Image.fromarray(fr_data).resize((cell_w, cell_h), Image.LANCZOS)
            board.paste(im_tile, (px, 35))
            draw.rectangle([(px, 35), (px + cell_w, 53)], fill=(10, 12, 16))
            draw.text((px + 6, 37), title, font=font_l, fill=(220, 230, 255))
            draw.rectangle([(px, 35), (px + cell_w, 35 + cell_h)], outline=(35, 45, 60), width=1)
            
        comp_frames.append(board)
        
    out_3_gif = os.path.join(OUT_SHOWCASE, "anim_3_styles_retenus.gif")
    comp_frames[0].save(out_3_gif, save_all=True, append_images=comp_frames[1:], duration=45, loop=0)
    print(f"GIF comparatif 3 styles sauvegardé : {out_3_gif}")
    if os.path.exists(ART):
        shutil.copyfile(out_3_gif, os.path.join(ART, "anim_3_styles_retenus.gif"))
        print("Copié dans artéfacts.")

    print("\n=== TOUT EST DÉPLOYÉ AVEC SUCCÈS ===")

if __name__ == "__main__":
    main()
