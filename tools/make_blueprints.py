import os
from PIL import Image, ImageDraw, ImageFont

font_title = None
font_body = None
font_mono = None

try:
    font_title = ImageFont.truetype(r"C:\Windows\Fonts\consolab.ttf", 20)
    font_sub = ImageFont.truetype(r"C:\Windows\Fonts\consolab.ttf", 16)
    font_body = ImageFont.truetype(r"C:\Windows\Fonts\consola.ttf", 15)
    font_badge = ImageFont.truetype(r"C:\Windows\Fonts\consolab.ttf", 14)
except Exception:
    font_title = ImageFont.load_default()
    font_sub = font_title
    font_body = font_title
    font_badge = font_title

mechas_data = [
    {
        'folder': 'tech_mecha', 'ch': 1, 'name': 'Assembly-Walker', 'title': 'Cadenceur de Fonderie',
        'biome': "L'Usine (tech)", 'accent': '#f59e0b', 'accent_rgb': (245, 158, 11),
        'weapons': 'R: Cloueuse a Rivets / L: Cisaille Hydraulique Geante',
        'chassis': 'Caisson blinde rectangulaire jaune chantier + gyrophares',
        'legs': 'Chicken-legs a double verins hydrauliques chromes',
        'atk': 'Rafale 3 rivets lourds + charge de cisaillement rapide'
    },
    {
        'folder': 'desert_mecha', 'ch': 2, 'name': 'Dune-Drifter', 'title': 'Bastion des Sables',
        'biome': 'Terres Calcinecs (desert)', 'accent': '#d97706', 'accent_rgb': (217, 119, 6),
        'weapons': 'R: Double Canon 50mm / L: Harpon Sismique a Treuil',
        'chassis': 'Bunker biseaute ocre avec ecopes a filtration cyclonique',
        'legs': 'Pattes inversees a patins triangulaires de portance sable',
        'atk': 'Harponnage d ancrage au sol + ecran de poussiere aveuglant'
    },
    {
        'folder': 'jungle_mecha', 'ch': 3, 'name': 'Flora-Crusher', 'title': 'Broyeur Forestier Lourd',
        'biome': 'La Ruine Verte (jungle)', 'accent': '#10b981', 'accent_rgb': (16, 185, 129),
        'weapons': 'R: Doubles Scies Circulaires / L: Pulverisateur Defoliant',
        'chassis': 'Cabine blindee vert olive avec pare-buffle et arceaux forges',
        'legs': 'Jambes digitigrades lourdes avec patins auto-nettoyants',
        'atk': 'Projection d acide defoliant ralentissant + charge rotative'
    },
    {
        'folder': 'volcanic_mecha', 'ch': 4, 'name': 'Magma-Foundry', 'title': 'Creuset Mobile',
        'biome': 'La Forge (volcanic)', 'accent': '#ef4444', 'accent_rgb': (239, 68, 68),
        'weapons': 'R: Tromblon a Scories Magmatiques / L: Pince-Creuset Forge',
        'chassis': 'Fonte et dalles de basalte avec coeur de fourneau incandescent',
        'legs': 'Jambes inversees a verins thermo-blindes et semelles de forge',
        'atk': 'Bombes magmatiques en cloche + slam de pince thermique'
    },
    {
        'folder': 'swamp_mecha', 'ch': 5, 'name': 'Sludge-Excavator', 'title': "Dragueur d Envasement",
        'biome': 'La Cite Dechue (swamp)', 'accent': '#84cc16', 'accent_rgb': (132, 204, 22),
        'weapons': 'R: Pompe Haute Pression de Boue / L: Godet d Excavation Lourd',
        'chassis': 'Coque etanche bronze oxyde, mat periscope, ballasts lateraux',
        'legs': 'Jambes digitigrades a larges raquettes anti-enlisement',
        'atk': 'Geysers de vase collante (malus vitesse) + etourdissement godet'
    },
    {
        'folder': 'cryo_mecha', 'ch': 6, 'name': 'Glacier-Borer', 'title': 'Foreur Cryogenique',
        'biome': 'Le Cryo-Laboratoire (cryo)', 'accent': '#38bdf8', 'accent_rgb': (56, 189, 248),
        'weapons': 'R: Foreuse Rotative Carbure / L: Cryo-Projecteur Azote Liquide',
        'chassis': 'Aluminium blanc polaire et bleu givre, 3 bouteilles N2 dorsales',
        'legs': 'Chicken-legs anti-gel avec crampons thermiques a pointe acier',
        'atk': 'Cone d azote figeant la cible + perforation par la foreuse'
    },
    {
        'folder': 'reacteur_mecha', 'ch': 7, 'name': 'Radiation-Core', 'title': 'Bunker Radiologique',
        'biome': 'Le Noyau Instable (reacteur)', 'accent': '#06b6d4', 'accent_rgb': (6, 182, 212),
        'weapons': 'R: Accelerateur Faisceau Gamma / L: Bras Confinement Matiere',
        'chassis': 'Bloc de plomb et graphite lourd, hublot avec coeur Cherenkov',
        'legs': 'Jambes inversees a amortisseurs lourds et semelles plombees',
        'atk': 'Pulsation radioactive de zone vidant le bouclier + faisceau continu'
    },
    {
        'folder': 'ruche_mecha', 'ch': 8, 'name': 'Hive-Breaker', 'title': 'Exterminateur Thermique',
        'biome': 'La Ruche (ruche)', 'accent': '#eab308', 'accent_rgb': (234, 179, 8),
        'weapons': 'R: Double Lance-Flammes Napalm / L: Emetteur Sonique Dispersion',
        'chassis': 'Blindage assaut ceramique noir et jaune (aucun trait animal)',
        'legs': 'Bipede reverse-joint blinde anti-acide avec griffes d ancrage',
        'atk': 'Balayage incendiaire continu + onde sonique repoussant les tirs'
    },
    {
        'folder': 'citadelle_mecha', 'ch': 9, 'name': 'Orbital-Bastion', 'title': 'Tourelle Mobile de Siege',
        'biome': 'La Citadelle Orbitale (citadelle)', 'accent': '#f43f5e', 'accent_rgb': (244, 63, 94),
        'weapons': 'R: Railgun Jumeau Electromagnetique / L: Pod 6 Missiles Verticaux',
        'chassis': 'Forteresse octogonale anthracite avec volets de bouclier blindes',
        'legs': 'Ultra-heavy chicken-legs avec verins de verrouillage au sol',
        'atk': 'Mode Siege ancre (+50% armure) + pluie missiles + tir railgun'
    }
]

base_dir = r"C:\Users\Administrator\mecha-forge\meshy_in"

for m in mechas_data:
    folder_path = os.path.join(base_dir, m['folder'])
    os.makedirs(folder_path, exist_ok=True)
    out_file = os.path.join(folder_path, 'blueprint.png')
    
    img = Image.new('RGB', (1024, 1024), color='#070b14')
    draw = ImageDraw.Draw(img)
    
    # Grid
    for x in range(0, 1024, 32):
        draw.line([(x, 0), (x, 1024)], fill='#0b1526', width=1)
    for y in range(0, 1024, 32):
        draw.line([(0, y), (1024, y)], fill='#0b1526', width=1)
    for x in range(0, 1024, 160):
        draw.line([(x, 0), (x, 1024)], fill='#132742', width=1)
    for y in range(0, 1024, 160):
        draw.line([(0, y), (1024, y)], fill='#132742', width=1)
        
    # Borders
    acc = m['accent_rgb']
    draw.rectangle([(24, 24), (1000, 1000)], outline=acc, width=2)
    draw.rectangle([(32, 32), (992, 992)], outline='#1e293b', width=1)
    
    # Corner brackets
    for cx, cy in [(24, 24), (1000, 24), (24, 1000), (1000, 1000)]:
        dx = 20 if cx == 24 else -20
        dy = 20 if cy == 24 else -20
        draw.line([(cx, cy), (cx + dx, cy)], fill=acc, width=3)
        draw.line([(cx, cy), (cx, cy + dy)], fill=acc, width=3)
        
    # Header
    ch_num = m['ch']
    name_str = m['name'].upper()
    title_str = m['title'].upper()
    biome_str = m['biome']
    draw.text((48, 48), f"MECHA-FORGE CAD SPECIFICATION // CHAPTER {ch_num}", fill=acc, font=font_title)
    draw.text((48, 76), f"{name_str} - {title_str}", fill=(255, 255, 255), font=font_sub)
    draw.text((48, 102), f"BIOME: {biome_str} | STATUT: MESHY AUTO-RIG READY", fill=(148, 163, 184), font=font_body)
    
    # Central CAD Schematic Box
    draw.rectangle([(160, 140), (864, 620)], outline='#1e293b', fill='#090f1d')
    # Crosshairs
    draw.line([(512, 140), (512, 620)], fill='#122236', width=1)
    draw.line([(160, 380), (864, 380)], fill='#122236', width=1)
    
    # Central Hull (angular bunker/turret)
    draw.polygon([(420, 240), (604, 240), (640, 340), (580, 400), (444, 400), (384, 340)], outline=acc, width=3)
    draw.rectangle([(460, 280), (564, 305)], outline=acc, fill='#0d1b2a', width=2) # Visor
    draw.rectangle([(475, 290), (549, 295)], fill=acc) # Glowing eye slot
    
    # Pelvis
    draw.polygon([(470, 400), (554, 400), (540, 440), (484, 440)], outline=acc, width=2)
    
    # Reverse-joint chicken legs
    # Left hip joint
    draw.ellipse([(450, 430), (480, 460)], outline=acc, width=2)
    # Thigh forward
    draw.line([(465, 450), (410, 500)], fill=acc, width=5)
    draw.ellipse([(395, 485), (425, 515)], outline=acc, width=2) # Knee
    # Shin backward
    draw.line([(410, 500), (440, 570)], fill=acc, width=5)
    # Piston cylinder parallel to shin
    draw.line([(395, 475), (425, 555)], fill='#64748b', width=2)
    # Foot
    draw.polygon([(400, 575), (465, 575), (470, 590), (390, 590)], outline=acc, width=3)
    
    # Right hip joint
    draw.ellipse([(544, 430), (574, 460)], outline=acc, width=2)
    # Thigh forward
    draw.line([(559, 450), (614, 500)], fill=acc, width=5)
    draw.ellipse([(599, 485), (629, 515)], outline=acc, width=2) # Knee
    # Shin backward
    draw.line([(614, 500), (584, 570)], fill=acc, width=5)
    # Piston cylinder
    draw.line([(629, 475), (599, 555)], fill='#64748b', width=2)
    # Foot
    draw.polygon([(559, 575), (624, 575), (634, 590), (554, 590)], outline=acc, width=3)
    
    # Left Weapon Hardpoint (mounted directly on hull flank)
    draw.rectangle([(320, 270), (384, 330)], outline=acc, fill='#0d1b2a', width=2)
    draw.polygon([(260, 280), (320, 290), (320, 310), (260, 320)], outline=acc, width=3)
    draw.text((180, 290), 'L-WEAPON', fill=acc, font=font_badge)
    
    # Right Weapon Hardpoint (mounted directly on hull flank)
    draw.rectangle([(640, 270), (704, 330)], outline=acc, fill='#0d1b2a', width=2)
    draw.polygon([(704, 290), (764, 280), (764, 320), (704, 310)], outline=acc, width=3)
    draw.text((720, 260), 'R-WEAPON', fill=acc, font=font_badge)
    
    # Ground plane line
    draw.line([(240, 590), (784, 590)], fill='#334155', width=2)
    
    # Badges inside schematic box
    draw.text((180, 160), '[NON-HUMANOIDE]', fill='#10b981', font=font_badge)
    draw.text((340, 160), '[AUCUN ANIMAL]', fill='#10b981', font=font_badge)
    draw.text((490, 160), '[CHICKEN-LEGS]', fill='#10b981', font=font_badge)
    draw.text((640, 160), '[A-POSE 45 DEG]', fill=acc, font=font_badge)
    
    # Bottom Technical Specs
    y_text = 640
    draw.rectangle([(48, y_text), (976, 976)], fill='#0c1322', outline='#1e293b')
    
    chassis_str = m['chassis']
    legs_str = m['legs']
    weapons_str = m['weapons']
    atk_str = m['atk']
    folder_str = m['folder']
    
    draw.text((72, y_text + 20), "SPECIFICATIONS POUR RIGGING AUTOMATIQUE MESHY 3D :", fill=acc, font=font_sub)
    draw.text((72, y_text + 55), f"- CHASSIS CENTRAL : {chassis_str}", fill=(241, 245, 249), font=font_body)
    draw.text((72, y_text + 85), f"- LOCOMOTION      : {legs_str}", fill=(241, 245, 249), font=font_body)
    draw.text((72, y_text + 115), f"- ARMEMENT FLANC  : {weapons_str}", fill=(241, 245, 249), font=font_body)
    draw.text((72, y_text + 145), f"- ATTAQUE UNIQUE  : {atk_str}", fill=(241, 245, 249), font=font_body)
    draw.text((72, y_text + 185), "REGLES MESHY : Membres decolles du torse, semelles horizontales a plat, fond neutre 45 deg", fill=(148, 163, 184), font=font_body)
    draw.text((72, y_text + 215), f"PROMPT PRET A L EMPLOI : Voir meshy_in/{folder_str}/prompt.txt", fill=acc, font=font_body)
    
    img.save(out_file)
    print(f"Generated clean blueprint: {out_file}")

print("All 9 blueprints regenerated cleanly!")
