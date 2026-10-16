#!/usr/bin/env python3
"""
Générateur de la planche comparative et de validation des 9 effets spéciaux d'armes (VFX).
Création d'une planche maître 1920x1080 haute définition présentant chaque arme, son projectile,
son faisceau/traînée, son impact 16-frames et son résidu au sol.
"""
import os
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VFX_DIR = os.path.join(ROOT, "game", "assets", "vfx", "ts")
OUT_DIR = os.path.join(ROOT, "refs", "vfx_showcase")
os.makedirs(OUT_DIR, exist_ok=True)
OUT_PATH = os.path.join(OUT_DIR, "planche_vfx_premium.png")
ARTIFACT_DIR = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\f4d60812-8c84-40f0-9aad-921d86be3fca"

# Configuration typographique
try:
    font_title = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 26)
    font_subtitle = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 15)
    font_card_title = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 15)
    font_card_sub = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 11)
    font_badge = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 11)
except Exception:
    font_title = font_subtitle = font_card_title = font_card_sub = font_badge = ImageFont.load_default()

def load_tex(name, size=None):
    p = os.path.join(VFX_DIR, name)
    if not os.path.exists(p):
        return None
    im = Image.open(p).convert("RGBA")
    if size:
        im = im.resize(size, Image.Resampling.LANCZOS)
    return im

def extract_sheet_frame(name, frame_idx=5, grid_size=4):
    p = os.path.join(VFX_DIR, name)
    if not os.path.exists(p):
        return None
    sheet = Image.open(p).convert("RGBA")
    sw, sh = sheet.size
    fw, fh = sw // grid_size, sh // grid_size
    col = frame_idx % grid_size
    row = frame_idx // grid_size
    return sheet.crop((col * fw, row * fh, (col + 1) * fw, (row + 1) * fh))

def build_board():
    W, H = 1920, 1080
    board = Image.new("RGBA", (W, H), (14, 16, 22, 255))
    draw = ImageDraw.Draw(board)

    # Grille subtile en arrière-plan
    for x in range(0, W, 40):
        draw.line([(x, 0), (x, H)], fill=(20, 24, 32, 255), width=1)
    for y in range(0, H, 40):
        draw.line([(0, y), (W, y)], fill=(20, 24, 32, 255), width=1)

    # En-tête
    draw.rectangle([(0, 0), (W, 70)], fill=(18, 22, 30, 255))
    draw.line([(0, 70), (W, 70)], fill=(40, 50, 70, 255), width=2)
    draw.text((36, 14), "MECHA-FORGE  —  REFONTE HORLOGÈRE DES EFFETS SPÉCIAUX (9 BIOMES)", font=font_title, fill=(245, 248, 255))
    draw.text((38, 44), "Zéro texture floue · Rendu multi-couches additif · Particules physiques & Spritesheets 16-frames · Logique préservée à 100%", font=font_subtitle, fill=(130, 155, 190))

    # Configuration des 9 cartes (grille 3 x 3)
    cols, rows = 3, 3
    margin_x, margin_y = 36, 85
    gap_x, gap_y = 20, 16
    card_w = (W - margin_x * 2 - gap_x * (cols - 1)) // cols
    card_h = (H - margin_y - 25 - gap_y * (rows - 1)) // rows

    cards_data = [
        {
            "id": "1. USINE",
            "name": "Arc de soudure ramifié ±46°",
            "accent": (255, 170, 50),
            "desc": "Filament haute tension, pré-visée calibrée, étincelles avec gravité et rebond.",
            "head": "ts_flare.png",
            "beam": "ts_beam_weld.png",
            "impact": "ts_smoke_impact.png",
            "impact_frame": 4,
            "badge": "BEAM + BOUNCING SPARKS",
        },
        {
            "id": "2. TERRES CALCINÉES",
            "name": "Rayons solaires convergents",
            "accent": (255, 215, 60),
            "desc": "16 rayons orbitaux focalisés, aiguille instantanée et sillon fulgurite vitrifié (3 s).",
            "head": "ts_flare.png",
            "beam": "ts_beam_solar.png",
            "decal": "ts_glass_glow.png",
            "badge": "ORBITAL CONVERGENCE + GLASS",
        },
        {
            "id": "3. RUINE VERTE",
            "name": "Cosse samare & Spores",
            "accent": (110, 230, 80),
            "desc": "Vol balistique en cloche, ombre portée, éclatement en 6 épines et nuage de spores.",
            "head": "ts_pod_head.png",
            "impact": "ts_pod_impact.png",
            "impact_frame": 6,
            "decal": "ts_spores_glow.png",
            "badge": "ROTATING POD + SPORE BURST",
        },
        {
            "id": "4. FORGE",
            "name": "Obus de lave & Magma",
            "accent": (255, 90, 30),
            "desc": "Balistique lourde, rebond au sol, flaque bouillonnante avec cloques actives (5 s).",
            "head": "ts_slag_head.png",
            "impact": "ts_slag_impact.png",
            "impact_frame": 5,
            "decal": "ts_slag_glow.png",
            "badge": "HEAVY SLAG + BUBBLING POOL",
        },
        {
            "id": "5. CITÉ DÉCHUE",
            "name": "Flak traceur & Anneau tungstène",
            "accent": (255, 230, 140),
            "desc": "Salve rythmée de 4 ogives Mach, airburst en anneau d'éclats et sillage cordite.",
            "head": "ts_flak_head.png",
            "impact": "ts_smoke_impact.png",
            "impact_frame": 5,
            "extra": "ts_ring.png",
            "badge": "QUAD FLAK + AIRBURST RING",
        },
        {
            "id": "6. CRYO",
            "name": "Orbe givré fractal & Nova",
            "accent": (90, 200, 255),
            "desc": "Flocon à 8 branches, ligne de givre fractale au sol, nova cryogénique sub-zéro.",
            "head": "ts_frost_head.png",
            "impact": "ts_ice_impact.png",
            "impact_frame": 6,
            "decal": "ts_frost_glow.png",
            "badge": "CRYSTAL ORB + FROST LINE",
        },
        {
            "id": "7. NOYAU INSTABLE",
            "name": "Fission à 3 paliers",
            "accent": (200, 110, 255),
            "desc": "Vibration de tourelle, arcs de confinement, orbe scindé en 3 éclairs de rupture.",
            "head": "ts_plasma_head.png",
            "beam": "ts_beam_plasma.png",
            "impact": "ts_plasma_impact.png",
            "impact_frame": 5,
            "badge": "3-TIER CHARGE + TRIPLE BOLT",
        },
        {
            "id": "8. RUCHE",
            "name": "Poche organique & Acide",
            "accent": (160, 255, 40),
            "desc": "Poche pulsante, 3 globules étirés en goutte, flaques corrosives qui fument.",
            "head": "ts_acid_head.png",
            "impact": "ts_acid_impact.png",
            "impact_frame": 5,
            "decal": "ts_acid_glow.png",
            "badge": "TEARDROP GLOBULES + FUMING ACID",
        },
        {
            "id": "9. CITADELLE",
            "name": "Verrouillage HUD & Salve guidée",
            "accent": (255, 70, 70),
            "desc": "Réticule d'acquisition stroboscopique, lancement vertical puis guidage Mach.",
            "head": "ts_missile_head.png",
            "impact": "ts_missile_impact.png",
            "impact_frame": 6,
            "extra": "ts_ring.png",
            "badge": "TACTICAL RETICLE + GUIDED SWARM",
        },
    ]

    for idx, card in enumerate(cards_data):
        r = idx // cols
        c = idx % cols
        x0 = margin_x + c * (card_w + gap_x)
        y0 = margin_y + r * (card_h + gap_y)
        x1 = x0 + card_w
        y1 = y0 + card_h

        # Fond carte
        draw.rectangle([(x0, y0), (x1, y1)], fill=(20, 24, 34, 255))
        draw.rectangle([(x0, y0), (x1, y1)], outline=(35, 42, 58, 255), width=1)
        # Liseré supérieur accentué
        draw.line([(x0, y0), (x1, y0)], fill=card["accent"], width=3)

        # Textes carte
        draw.text((x0 + 14, y0 + 10), card["id"], font=font_badge, fill=card["accent"])
        draw.text((x0 + 14, y0 + 26), card["name"], font=font_card_title, fill=(240, 245, 255))
        draw.text((x0 + 14, y0 + 46), card["desc"], font=font_card_sub, fill=(140, 155, 180))

        # Badge technique à droite
        bbox = font_badge.getbbox(card["badge"])
        bw = bbox[2] - bbox[0] + 12
        bh = 18
        bx = x1 - bw - 14
        by = y0 + 10
        draw.rectangle([(bx, by), (bx + bw, by + bh)], fill=(28, 34, 48, 255), outline=card["accent"], width=1)
        draw.text((bx + 6, by + 3), card["badge"], font=font_badge, fill=card["accent"])

        # Zone d'exposition des éléments visuels (plateau sombre)
        disp_x0 = x0 + 12
        disp_y0 = y0 + 68
        disp_x1 = x1 - 12
        disp_y1 = y1 - 12
        disp_w = disp_x1 - disp_x0
        disp_h = disp_y1 - disp_y0

        draw.rectangle([(disp_x0, disp_y0), (disp_x1, disp_y1)], fill=(12, 14, 18, 255), outline=(28, 34, 46, 255))

        # Placement des visuels dans l'espace d'exposition
        # 1. Projectile Head (à gauche)
        head_tex = load_tex(card.get("head"), (88, 88))
        if head_tex:
            board.alpha_composite(head_tex, (disp_x0 + 12, disp_y0 + (disp_h - 88) // 2))

        # 2. Faisceau ou Traînée ou Extra (au centre)
        if "beam" in card:
            beam_tex = load_tex(card["beam"], (200, 48))
            if beam_tex:
                board.alpha_composite(beam_tex, (disp_x0 + 115, disp_y0 + (disp_h - 48) // 2))
        elif "decal" in card and "impact" not in card:
            decal_tex = load_tex(card["decal"], (190, 80))
            if decal_tex:
                board.alpha_composite(decal_tex, (disp_x0 + 120, disp_y0 + (disp_h - 80) // 2))

        # 3. Impact Sheet Frame (à droite)
        if "impact" in card:
            imp_frame = extract_sheet_frame(card["impact"], frame_idx=card.get("impact_frame", 5))
            if imp_frame:
                imp_frame = imp_frame.resize((100, 100), Image.Resampling.LANCZOS)
                board.alpha_composite(imp_frame, (disp_x1 - 115, disp_y0 + (disp_h - 100) // 2))

        # 4. Decal / Séquelle supplémentaire si disponible
        if "decal" in card and "impact" in card:
            decal_mini = load_tex(card["decal"], (64, 64))
            if decal_mini:
                board.alpha_composite(decal_mini, (disp_x0 + 115, disp_y0 + (disp_h - 64) // 2))

        # 5. Anneau d'onde de choc si extra
        if "extra" in card and "decal" not in card:
            ring_tex = load_tex(card["extra"], (72, 72))
            if ring_tex:
                board.alpha_composite(ring_tex, (disp_x0 + 115, disp_y0 + (disp_h - 72) // 2))

    # Sauvegarde
    board.save(OUT_PATH, "PNG")
    print(f"Planche sauvegardée : {OUT_PATH}")

    # Copie dans le dossier des artéfacts pour visualisation immédiate
    if os.path.exists(ARTIFACT_DIR):
        art_path = os.path.join(ARTIFACT_DIR, "planche_vfx_premium.png")
        shutil.copyfile(OUT_PATH, art_path)
        print(f"Planche copiée dans les artéfacts : {art_path}")

if __name__ == "__main__":
    build_board()
