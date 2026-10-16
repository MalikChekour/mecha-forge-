import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF_DIR = os.path.join(ROOT, "refs", "mk_concepts")
SHOW_DIR = os.path.join(ROOT, "cine", "_show")

# Load fonts
try:
    font_title = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 26)
    font_section = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 19)
    font_label = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 14)
    font_sub = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 14)
    font_desc = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 13)
except Exception:
    font_title = font_section = font_label = font_sub = font_desc = ImageFont.load_default()

# 1. Load the original "before" planche (we saved original crop in memory earlier, but let's check git)
comp_prev = Image.open(os.path.join(REF_DIR, "planche_mk_avant_apres.png")).convert("RGB")

specs = [
    ("vortexmk2", 0, 0, "1. VORTEX Mk II (Renforcé)",
     "Pauldrons biseautés à 2 plaques néon · Canon d'avant-bras usiné · Émetteur de paume gauche · Crête pointue · Genouillères"),
    ("vortexmk3", 1, 0, "2. VORTEX Mk III (Spécialisé)",
     "Pauldrons à 3 plaques · Canons jumeaux d'avant-bras gauche et droit · Plastron V avec bandeau cyan · Propulseurs dorsaux"),
    ("vortexmk4", 2, 0, "3. VORTEX Mk IV (Élite)",
     "Gatling rotative 3 canons · Plaques flottantes avec halos orbitaux cyan · Halo de casque holographique · Liserés or et chrome"),
    ("bluestrikemk2", 0, 1, "4. BLUESTRIKE Mk II (Renforcé)",
     "Orange vif haute saturation (anti-blanchiment beige) · Épaulières dôme avec bague mécanique et évents · Blasters de dispersion aux mains"),
    ("bluestrikemk3", 1, 1, "5. BLUESTRIKE Mk III (Assaut)",
     "Canons jumeaux courts intégrés aux avant-bras · Conduits d'énergie lumineux chauds · Double intake pectoral · Propulseurs dorsaux"),
    ("bluestrikemk4", 2, 1, "6. BLUESTRIKE Mk IV (Élite)",
     "Gatling rotative lourde 6 canons · Émetteur de paume gauche · Ailes d'énergie holographiques cyan · Finitions blanc/or"),
]

def crop_and_fit(img, target_h=215, bg_color=(30, 33, 42)):
    # Find bounding box of mech
    diff = Image.new('L', img.size)
    for x in range(img.width):
        for y in range(img.height):
            p = img.getpixel((x, y))
            if max(abs(p[i] - bg_color[i]) for i in range(3)) > 14:
                diff.putpixel((x, y), 255)
    bb = diff.getbbox()
    if not bb:
        return img
    cropped = img.crop(bb)
    # Scale so height is target_h
    scale = target_h / max(cropped.height, 1)
    new_w = max(1, int(cropped.width * scale))
    new_h = target_h
    if new_w > 240:
        scale = 240 / cropped.width
        new_w = 240
        new_h = int(cropped.height * scale)
    resized = cropped.resize((new_w, new_h), Image.LANCZOS)
    # Paste into 256x256
    out = Image.new("RGB", (256, 256), bg_color)
    out.paste(resized, ((256 - new_w) // 2, (256 - new_h) // 2 + 5))
    return out

# --------------------------------------------------------------------------
# BUILD COMPREHENSIVE BEFORE/AFTER COMPARISON BOARD (planche_mk_avant_apres.png)
# --------------------------------------------------------------------------
board_w = 1800
row_h = 390
header_h = 130
total_h = header_h + len(specs) * row_h + 30

board = Image.new("RGB", (board_w, total_h), (20, 23, 30))
draw = ImageDraw.Draw(board)

# Header
draw.rectangle([(0, 0), (board_w, header_h)], fill=(13, 15, 20))
draw.text((40, 24), "MECHA-FORGE — VERSIONS MK II / III / IV : COMPARATIF AVANT / APRÈS", fill=(255, 255, 255), font=font_title)
draw.text((40, 68), "Modélisation hard-surface procédurale avec chanfreins (Bevel 35°) · Correction saturation orange (anti-beige) · Armes intégrées de bras et de main · Flammes et conduits", fill=(140, 152, 172), font=font_sub)
draw.line([(0, header_h - 1), (board_w, header_h - 1)], fill=(40, 46, 60), width=2)

for idx, (ch, col, row_idx, title, desc) in enumerate(specs):
    y_start = header_h + idx * row_h
    
    # Alternating background band for clarity
    bg_band = (23, 26, 35) if idx % 2 == 0 else (17, 19, 26)
    draw.rectangle([(0, y_start), (board_w, y_start + row_h)], fill=bg_band)
    draw.line([(0, y_start), (board_w, y_start)], fill=(34, 39, 52), width=1)
    
    # Section Header & Subtitle with proper clearance
    draw.text((40, y_start + 14), title, fill=(255, 255, 255), font=font_section)
    draw.text((40, y_start + 42), desc, fill=(140, 155, 175), font=font_sub)
    
    x_b_f = 40
    x_b_r = 40 + 256 + 18
    x_div = x_b_r + 256 + 25
    x_a_f = x_div + 45
    x_a_r = x_a_f + 256 + 18
    x_notes = x_a_r + 256 + 35
    
    y_img = y_start + 105
    
    # Labels above images
    draw.text((x_b_f + 55, y_img - 26), "[ AVANT — Face ]", fill=(230, 95, 105), font=font_label)
    draw.text((x_b_r + 55, y_img - 26), "[ AVANT — Profil ]", fill=(230, 95, 105), font=font_label)
    
    draw.text((x_a_f + 55, y_img - 26), "[ APRÈS — Face ]", fill=(55, 220, 145), font=font_label)
    draw.text((x_a_r + 55, y_img - 26), "[ APRÈS — Profil ]", fill=(55, 220, 145), font=font_label)
    
    # Extract Before from comp_prev
    y_prev = 130 + idx * 370 + 50
    b_f_raw = comp_prev.crop((40, y_prev, 40 + 256, y_prev + 256))
    b_r_raw = comp_prev.crop((314, y_prev, 314 + 256, y_prev + 256))
    
    # Extract After
    a_f_raw = Image.open(os.path.join(SHOW_DIR, f"{ch}_gun_front.png")).convert("RGB")
    a_r_raw = Image.open(os.path.join(SHOW_DIR, f"{ch}_gun_right.png")).convert("RGB")
    
    # Fit both to uniform 215px height for direct comparison
    b_f = crop_and_fit(b_f_raw, target_h=215)
    b_r = crop_and_fit(b_r_raw, target_h=215)
    a_f = crop_and_fit(a_f_raw, target_h=215)
    a_r = crop_and_fit(a_r_raw, target_h=215)
    
    board.paste(b_f, (x_b_f, y_img))
    board.paste(b_r, (x_b_r, y_img))
    board.paste(a_f, (x_a_f, y_img))
    board.paste(a_r, (x_a_r, y_img))
    
    # Frames around sprites
    for bx in (x_b_f, x_b_r):
        draw.rectangle([(bx, y_img), (bx + 255, y_img + 255)], outline=(60, 68, 85), width=1)
    for ax in (x_a_f, x_a_r):
        accent_col = (0, 210, 255) if "vortex" in ch else (255, 125, 30)
        draw.rectangle([(ax, y_img), (ax + 255, y_img + 255)], outline=accent_col, width=2)
    
    # Clean arrow drawn with polygon (triangle + stem)
    ay = y_img + 115
    draw.rectangle([(x_div + 4, ay + 6), (x_div + 20, ay + 14)], fill=(100, 120, 150))
    draw.polygon([(x_div + 20, ay), (x_div + 34, ay + 10), (x_div + 20, ay + 20)], fill=(100, 120, 150))
    
    # Notes box on the right
    notes_w = board_w - x_notes - 40
    draw.rectangle([(x_notes, y_img), (x_notes + notes_w, y_img + 256)], fill=(13, 15, 21), outline=(42, 48, 64), width=1)
    
    # Bullet points per Mk
    draw.text((x_notes + 18, y_img + 16), "AMÉLIORATIONS CLÉS :", fill=(255, 255, 255), font=font_label)
    
    if ch == "vortexmk2":
        bullets = [
            "• Pauldrons étagés avec bordures biseautées et liseré cyan",
            "• Canon d'avant-bras usiné : culasse, carter, frette et bouche",
            "• Émetteur de paume concentrique avec lentille de focalisation",
            "• Crête de casque effilée + antennes de détection",
            "• Matériau noir furtif calibré (évite l'aspect plastique plat)"
        ]
    elif ch == "vortexmk3":
        bullets = [
            "• Pauldrons profilés à 3 étages de blindage superposés",
            "• Canons jumeaux d'avant-bras gauche et droit",
            "• Plastron V biseauté encadrant le réacteur orange",
            "• Double tuyère dorsale avec panache de flamme cyan",
            "• Genouillères massives renforcées"
        ]
    elif ch == "vortexmk4":
        bullets = [
            "• Gatling rotative 3 canons avec colliers de maintien or",
            "• Boucliers flottants latéraux détachés avec halos orbitaux",
            "• Halo de casque holographique + finitions chrome & or",
            "• Plastron biseauté liseré or et réacteur optimisé",
            "• Propulseurs quadruples dorsaux haute intensité"
        ]
    elif ch == "bluestrikemk2":
        bullets = [
            "• Albedo orange vif haute saturation (adieu l'orange beige !)",
            "• Épaulières dôme hard-surface avec bague mécanique sombre",
            "• Évents latéraux avec rétro-éclairage chaud",
            "• Blasters de dispersion montés sur les mains",
            "• Finition blindage semi-mat haute fidélité"
        ]
    elif ch == "bluestrikemk3":
        bullets = [
            "• Canons d'assaut jumeaux courts intégrés aux avant-bras",
            "• Conduits d'énergie chauds visibles sur bras et tibias",
            "• Gorgerin lourd avec double sensor pectoral actif",
            "• Tuyères dorsales à poussée orange vive",
            "• Blindage épaulières renforcé double couche"
        ]
    else: # bluestrikemk4
        bullets = [
            "• Gatling d'assaut lourde à 6 canons rotatifs usinés",
            "• Ailes holographiques d'énergie cyan translucides (3 paires)",
            "• Gorgerin d'élite avec anneaux or et capteurs magenta",
            "• Émetteur de paume de stabilisation gauche",
            "• Halo de tête et propulseurs d'assaut quadruples"
        ]
    
    for b_idx, bullet in enumerate(bullets):
        draw.text((x_notes + 18, y_img + 48 + b_idx * 38), bullet, fill=(180, 195, 215), font=font_desc)

out_comp_path = os.path.join(REF_DIR, "planche_mk_avant_apres.png")
board.save(out_comp_path)
print("Saved polished comparison board:", out_comp_path)
