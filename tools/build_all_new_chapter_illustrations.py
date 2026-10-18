# -*- coding: utf-8 -*-
"""Génère les 9 illustrations cinématiques 16:9 pour les chapitres 10 à 18
en compositant en haute résolution les décors et cartes réelles de chaque biome.
"""

import os
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw

CHAPTERS_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\chapters"
DECOR_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\decor"

LEVEL_COMPS = [
    (10, "abyss", "ground_abyss.png",
     "abyss_terrain_colonne_recif.png", 390, (540, 90),
     "abyss_tourelle_torpille.png", 290, (320, 190),
     (5, 20, 40)),

    (11, "ether", "ground_ether.png",
     "ether_terrain_fongus_arbre.png", 410, (550, 80),
     "ether_tourelle_spores.png", 280, (330, 200),
     (35, 10, 45)),

    (12, "titans", "ground_titans.png",
     "titans_terrain_main_colosse.png", 380, (530, 100),
     "titans_tourelle_artillerie.png", 310, (310, 180),
     (45, 25, 10)),

    (13, "orbit", "ground_orbit.png",
     "orbit_terrain_panneau_solaire_brise.png", 360, (520, 100),
     "orbit_tourelle_laser_impulsion.png", 280, (340, 200),
     (10, 15, 35)),

    (14, "quantum", "ground_quantum.png",
     "quantum_terrain_monolithe_flottant.png", 390, (550, 80),
     "quantum_tourelle_faisceau_vecteur.png", 290, (330, 190),
     (40, 35, 10)),

    (15, "ozone", "ground_ozone.png",
     "ozone_terrain_fleche_fulgurite.png", 400, (540, 80),
     "ozone_tourelle_arc_eclair.png", 290, (320, 190),
     (35, 15, 45)),

    (16, "prism", "ground_prism.png",
     "prism_terrain_grappe_cristaux.png", 390, (540, 90),
     "prism_tourelle_refracteur.png", 290, (330, 190),
     (15, 35, 40)),

    (17, "steampunk", "ground_steampunk.png",
     "steampunk_terrain_engrenage_monumental.png", 400, (530, 80),
     "steampunk_tourelle_gatling_vapeur.png", 300, (310, 180),
     (45, 28, 12)),

    (18, "colosseum", "ground_colosseum.png",
     "colosseum_terrain_pilier_holomur.png", 380, (540, 90),
     "colosseum_tourelle_simulation.png", 280, (330, 190),
     (15, 25, 45))
]

def make_chapter_art(num, biome, ground_name, p1_name, p1_h, p1_pos, p2_name, p2_h, p2_pos, tint_rgb):
    ground_path = os.path.join(DECOR_DIR, ground_name)
    p1_path = os.path.join(DECOR_DIR, p1_name)
    p2_path = os.path.join(DECOR_DIR, p2_name)
    out_path = os.path.join(CHAPTERS_DIR, f"chap_{num}_{biome}.jpg")

    bg = Image.open(ground_path).convert("RGBA")
    w, h = bg.size
    target_h = int(w * 536 / 960)
    bg = bg.crop((0, (h - target_h) // 2, w, (h - target_h) // 2 + target_h))
    bg = bg.resize((960, 536), Image.Resampling.LANCZOS)

    # Ambient light / atmosphere gradient
    grad = Image.new("RGBA", (960, 536), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    r, g, b = tint_rgb
    for y in range(536):
        a = int(140 * (1.0 - y / 536.0) + 35)
        gd.line([(0, y), (960, y)], fill=(r, g, b, a))
    bg = Image.alpha_composite(bg, grad)

    # Prop 1 (Background focal obstacle)
    if os.path.exists(p1_path):
        p1 = Image.open(p1_path).convert("RGBA")
        p1_w = int(p1.width * (p1_h / p1.height))
        p1 = p1.resize((p1_w, p1_h), Image.Resampling.LANCZOS)

        # Drop shadow for p1
        p1_shadow = Image.new("RGBA", (960, 536), (0, 0, 0, 0))
        sd1 = ImageDraw.Draw(p1_shadow)
        x1, y1 = p1_pos
        sd1.ellipse([x1 + 10, y1 + p1_h - 40, x1 + p1_w - 10, y1 + p1_h + 15], fill=(0, 0, 0, 110))
        p1_shadow = p1_shadow.filter(ImageFilter.GaussianBlur(14))
        bg = Image.alpha_composite(bg, p1_shadow)

        bg.paste(p1, p1_pos, p1)

    # Prop 2 (Foreground signature turret / interactive hazard)
    if os.path.exists(p2_path):
        p2 = Image.open(p2_path).convert("RGBA")
        p2_w = int(p2.width * (p2_h / p2.height))
        p2 = p2.resize((p2_w, p2_h), Image.Resampling.LANCZOS)

        # Drop shadow for p2
        p2_shadow = Image.new("RGBA", (960, 536), (0, 0, 0, 0))
        sd2 = ImageDraw.Draw(p2_shadow)
        x2, y2 = p2_pos
        sd2.ellipse([x2 + 10, y2 + p2_h - 35, x2 + p2_w - 10, y2 + p2_h + 15], fill=(0, 0, 0, 130))
        p2_shadow = p2_shadow.filter(ImageFilter.GaussianBlur(16))
        bg = Image.alpha_composite(bg, p2_shadow)

        bg.paste(p2, p2_pos, p2)

    # Cinematic Vignette (darkened edges + bottom-left for card text legibility)
    vignette = Image.new("RGBA", (960, 536), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    for x in range(320):
        # Left fade to black (where text and chapter title sit)
        a = int((1.0 - x / 320.0) * 110)
        vd.line([(x, 0), (x, 536)], fill=(0, 0, 0, a))
    for y in range(80):
        # Top edge
        a = int((1.0 - y / 80.0) * 80)
        vd.line([(0, y), (960, y)], fill=(0, 0, 0, a))
    for y in range(456, 536):
        # Bottom edge
        a = int(((y - 456) / 80.0) * 100)
        vd.line([(0, y), (960, y)], fill=(0, 0, 0, a))

    bg = Image.alpha_composite(bg, vignette)
    final_rgb = bg.convert("RGB")
    final_rgb.save(out_path, "JPEG", quality=92)
    print(f"[OK] Chapitre {num} ({biome}) -> {out_path} ({os.path.getsize(out_path)} bytes)")

def main():
    print("=== FABRICATION DES 9 ILLUSTRATIONS DE SÉLECTEUR DE NIVEAU ===")
    for item in LEVEL_COMPS:
        make_chapter_art(*item)
    print("=== TOUTES LES ILLUSTRATIONS SONT CRÉÉES ===")

if __name__ == "__main__":
    main()
