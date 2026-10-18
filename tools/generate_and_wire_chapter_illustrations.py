# -*- coding: utf-8 -*-
"""Génère les 9 illustrations 16:9 cinématographiques pour les chapitres 10 à 18
(Abyss, Ether, Titans, Orbit, Quantum, Ozone, Prism, Steampunk, Colosseum)
et les câble dans le sélecteur de chapitre de Game.gd.
"""

import os
import sys
import json
import base64
import urllib.request
import urllib.error
from PIL import Image

CF_ACCOUNT_ID = os.environ.get("CF_ACCOUNT_ID")
CF_API_TOKEN = os.environ.get("CF_API_TOKEN")

CHAPTERS_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\chapters"
GAME_GD_PATH = r"C:\Users\Administrator\mecha-forge\game\scenes\Game.gd"

CHAPTER_PROMPTS = [
    (10, "abyss",
     "Cinematic wide-angle sci-fi concept art landscape of a colossal submerged underwater city ruins in the oceanic abyss, ancient high-tech metallic domes and submerged catwalks overgrown with glowing aqua bioluminescent anemones, underwater volcanic vents puffing bubbles, deep midnight blue and cyan waters, atmospheric dramatic lighting, stylized digital painting, 16:9 ratio"),

    (11, "ether",
     "Cinematic wide-angle sci-fi concept art landscape of an alien ether fungal forest at twilight, giant towering shelf bracket mushrooms with dripping luminous spores, twisted bioluminescent purple roots, floating glowing magenta spore clouds, ethereal cyan mist, mysterious extraterrestrial flora, atmospheric dramatic lighting, stylized digital painting, 16:9 ratio"),

    (12, "titans",
     "Cinematic wide-angle sci-fi concept art landscape of a monumental mecha graveyard, colossal fallen robot titans half-buried in rusted sepia soil, massive skeletal warship hull girders, smoking blast craters, dramatic sunset sky with amber and orange smog, gritty industrial apocalyptic wasteland, stylized digital painting, 16:9 ratio"),

    (13, "orbit",
     "Cinematic wide-angle sci-fi concept art landscape of an orbital zero-gravity space debris belt, shattered modular space station modules and glittering solar panel arrays drifting in vacuum, curved blue planet Earth visible in the deep black starry background, sparkling purple EMP electric arcs, stylized digital painting, 16:9 ratio"),

    (14, "quantum",
     "Cinematic wide-angle sci-fi concept art landscape of the Quantum Archives data matrix, towering monolith black obsidian server obelisks in magnetic levitation, pure glowing gold geometric circuit lines and holographic code cascades, mirror reflective obsidian floor, majestic abstract cyber architecture, stylized digital painting, 16:9 ratio"),

    (15, "ozone",
     "Cinematic wide-angle sci-fi concept art landscape of the Ozone Rift perpetual lightning storm canyon, towering dark basalt cliffs struck by violent violet and magenta lightning bolts, vitrified glowing fulgurite glass towers, ionized storm clouds glowing with electrical energy, dramatic cinematic scale, stylized digital painting, 16:9 ratio"),

    (16, "prism",
     "Cinematic wide-angle sci-fi concept art landscape of a massive prismatic crystal cavern, monumental translucent quartz pillars and geode formations refracting blinding rainbow laser light beams, sparkling diamond silica dust in the turquoise air, ethereal opalescent subterranean world, stylized digital painting, 16:9 ratio"),

    (17, "steampunk",
     "Cinematic wide-angle sci-fi concept art landscape of a monumental Victorian steampunk foundry citadel, colossal interlocking brass gears and copper boiler towers billowing white steam plumes, glowing molten bronze rivers, towering cast-iron chimneys at dusk, warm amber furnace glow, stylized digital painting, 16:9 ratio"),

    (18, "colosseum",
     "Cinematic wide-angle sci-fi concept art landscape of a futuristic high-tech virtual combat arena colosseum, towering armored stadium bleachers with dazzling cyan floodlights, neon holographic grid markings on the combat arena floor, floating tactical scoreboards, electrifying arena atmosphere, stylized digital painting, 16:9 ratio")
]

def generate_cloudflare(prompt, out_jpg):
    url = f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT_ID}/ai/run/@cf/black-forest-labs/flux-1-schnell"
    req = urllib.request.Request(
        url,
        data=json.dumps({"prompt": prompt, "steps": 4}).encode("utf-8"),
        headers={"Authorization": f"Bearer {CF_API_TOKEN}", "Content-Type": "application/json"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            d = json.loads(r.read().decode("utf-8"))
            if d.get("success") and "result" in d and "image" in d["result"]:
                raw_bytes = base64.b64decode(d["result"]["image"])
                import io
                im = Image.open(io.BytesIO(raw_bytes))
                # Crop square 1024x1024 to 16:9 (1024 x 572)
                w, h = im.size
                target_h = int(w * (536 / 960)) # 572
                y0 = (h - target_h) // 2
                im_cropped = im.crop((0, y0, w, y0 + target_h))
                im_resized = im_cropped.resize((960, 536), Image.Resampling.LANCZOS)
                im_resized.convert("RGB").save(out_jpg, "JPEG", quality=88)
                print(f"  [OK] Saved -> {out_jpg} ({im_resized.size})")
                return True
            else:
                print("  [CF Error]", d.get("errors"))
    except Exception as e:
        print(f"  [Network Error]: {e}")
    return False

def generate_all_images():
    print("=== GÉNÉRATION DES 9 ILLUSTRATIONS DU SÉLECTEUR DE NIVEAU ===")
    for n, biome, prompt in CHAPTER_PROMPTS:
        out_f = os.path.join(CHAPTERS_DIR, f"chap_{n}_{biome}.jpg")
        if os.path.exists(out_f) and os.path.getsize(out_f) > 10000:
            print(f"  [Existe déjà] {out_f}")
            continue
        print(f"Génération Chapitre {n} ({biome})...")
        ok = generate_cloudflare(prompt, out_f)
        if not ok:
            print(f"  [ERREUR] Échec pour {out_f}")

def update_game_gd():
    print("=== CÂBLAGE DANS GAME.GD ===")
    with open(GAME_GD_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Update CHAPTERS
    old_chapters_end = '\t{"name": "La Citadelle Orbitale","sub": "La Forge Finale",             "biome": "citadelle", "diff": 3, "gate": 40000},\n]'
    new_chapters_end = """\t{"name": "La Citadelle Orbitale","sub": "La Forge Finale",             "biome": "citadelle", "diff": 3, "gate": 40000},
\t{"name": "Les Abysses",          "sub": "La Cité Engloutie",           "biome": "abyss",     "diff": 3, "gate": 46000},
\t{"name": "La Forêt d'Éther",     "sub": "Les Spores Luissantes",       "biome": "ether",     "diff": 3, "gate": 52000},
\t{"name": "La Nécropole d'Acier", "sub": "Le Tombeau des Titans",       "biome": "titans",    "diff": 3, "gate": 58000},
\t{"name": "Le Champ Orbital",     "sub": "Dérive Zéro-G",               "biome": "orbit",     "diff": 3, "gate": 64000},
\t{"name": "Archives Quantiques",  "sub": "La Matrice Pure",             "biome": "quantum",   "diff": 3, "gate": 70000},
\t{"name": "La Faille d'Ozone",    "sub": "L'Orage Perpétuel",           "biome": "ozone",     "diff": 3, "gate": 76000},
\t{"name": "L'Abîme Prismatique",  "sub": "Les Grottes Réfringentes",    "biome": "prism",     "diff": 3, "gate": 82000},
\t{"name": "Le Bastion Vapeur",    "sub": "La Fournaise Victorienne",    "biome": "steampunk", "diff": 3, "gate": 88000},
\t{"name": "Le Colisée Virtuel",   "sub": "L'Épreuve Finale",            "biome": "colosseum", "diff": 3, "gate": 95000},
]"""
    if old_chapters_end in content:
        content = content.replace(old_chapters_end, new_chapters_end)
        print("  [Game.gd] CHAPTERS mis à jour avec les chapitres 10 à 18")

    # 2. Update BIOME_ART
    old_art = '\t"citadelle": "res://assets/chapters/chap_9_citadelle.jpg",\n'
    new_art = """\t"citadelle": "res://assets/chapters/chap_9_citadelle.jpg",
\t"abyss":     "res://assets/chapters/chap_10_abyss.jpg",
\t"ether":     "res://assets/chapters/chap_11_ether.jpg",
\t"titans":    "res://assets/chapters/chap_12_titans.jpg",
\t"orbit":     "res://assets/chapters/chap_13_orbit.jpg",
\t"quantum":   "res://assets/chapters/chap_14_quantum.jpg",
\t"ozone":     "res://assets/chapters/chap_15_ozone.jpg",
\t"prism":     "res://assets/chapters/chap_16_prism.jpg",
\t"steampunk": "res://assets/chapters/chap_17_steampunk.jpg",
\t"colosseum": "res://assets/chapters/chap_18_colosseum.jpg",
"""
    if old_art in content and '"abyss":' not in content[content.find("const BIOME_ART"):content.find("func _load_cut")]:
        content = content.replace(old_art, new_art)
        print("  [Game.gd] BIOME_ART mis à jour")

    # 3. Update _biome_label
    old_label = '\t\t"citadelle": return "Citadelle Orbitale"\n\t\t_: return b.capitalize()'
    new_label = """\t\t"citadelle": return "Citadelle Orbitale"
\t\t"abyss": return "Abysses Englouties"
\t\t"ether": return "Forêt d'Éther"
\t\t"titans": return "Nécropole des Titans"
\t\t"orbit": return "Champ Orbital 0G"
\t\t"quantum": return "Archives Quantiques"
\t\t"ozone": return "Faille d'Ozone"
\t\t"prism": return "Abîme Prismatique"
\t\t"steampunk": return "Bastion Vapeur"
\t\t"colosseum": return "Colisée Virtuel"
\t\t_: return b.capitalize()"""
    if old_label in content:
        content = content.replace(old_label, new_label)
        print("  [Game.gd] _biome_label mis à jour")

    with open(GAME_GD_PATH, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    generate_all_images()
    update_game_gd()
    print("=== FIN DU TRAITEMENT DES ILLUSTRATIONS ===")
