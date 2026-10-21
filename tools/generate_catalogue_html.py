import os

html_path = r"C:\Users\Administrator\mecha-forge\catalogue_mechas.html"

mechas = [
    {
        "ch": 1, "biome": "L'Usine (tech)", "code": "MA-01 Valiant-Worker",
        "type": "Mobile Suit Fonderie", "status": "ready",
        "folder": "tech_mecha", "accent": "#f59e0b",
        "desc": "Châssis Gundam angulaire jaune chantier et blanc Federation, doubles gyrophares et réacteurs vernier arrière. Deux jambes Gundam à vérins chromés, bras droit avec canon Gatling lourd à bande d'alimentation et bras gauche avec bras articulé mécanique à doigts robotisés.",
        "atk_name": "Barrage Gatling & Stabilisation d'Angle",
        "atk_desc": "Rafale de projectiles perforants lourds à haute cadence, suivie d'un repositionnement agile sur ses deux jambes Gundam pour un tir focalisé."
    },
    {
        "ch": 2, "biome": "Terres Calcinées (desert)", "code": "MA-02 Dune-Zeal",
        "type": "Mobile Suit de Siège Désertique", "status": "ready",
        "folder": "desert_mecha", "accent": "#d97706",
        "desc": "Châssis biseauté couleur sable/coyote façon Hildolfr avec mono-œil rouge Zeon sous fente blindée et écopes à filtration cyclonique. Deux jambes Gundam tout-terrain avec patins larges, bras droit avec canon linéaire 180mm et bras gauche avec bras articulé mécanique.",
        "atk_name": "Tir Linéaire 180mm & Rideau de Silice",
        "atk_desc": "Tir supersonique perçant à longue distance soulevant une onde tellurique aveuglante, couplé à des tirs de barrage continus."
    },
    {
        "ch": 3, "biome": "La Ruine Verte (jungle)", "code": "MA-03 Jungle-Goliath",
        "type": "Mobile Suit d'Assaut Forestier", "status": "ready",
        "folder": "jungle_mecha", "accent": "#10b981",
        "desc": "Châssis militaire kaki et vert olive avec pare-buffle biseauté et stencils d'alerte. Deux jambes Gundam à micro-verniers jaunes de genou, bras droit avec méga-canon beam d'épaule à câbles d'énergie et bras gauche avec bras articulé mécanique manipulateur.",
        "atk_name": "Méga-Faisceau Perforant & Nappe Corrosive",
        "atk_desc": "Décharge un rayon beam destructeur en ligne droite, forçant le joueur à esquiver tout en maintenant une pression constante à mi-distance."
    },
    {
        "ch": 4, "biome": "La Forge (volcanic)", "code": "MA-04 Magma-Dom",
        "type": "Mobile Suit Volcanique Lourd", "status": "ready",
        "folder": "volcanic_mecha", "accent": "#ef4444",
        "desc": "Châssis massif Dom Tropen en fonte noire et rouge vermillon avec cheminées d'échappement verticales et cœur de fourneau incandescent. Deux jambes lourdes Gundam, bras droit avec canon plasma à scories magmatiques et bras gauche avec bras articulé mécanique thermorésistant.",
        "atk_name": "Bombardement Magmatique & Fissure Thermique",
        "atk_desc": "Projette des bombes magmatiques à résidus de lave persistants et déclenche une onde thermique radiale repoussant la cible."
    },
    {
        "ch": 5, "biome": "La Cité Déchue (swamp)", "code": "MA-05 Sludge-Amphibian",
        "type": "Mobile Suit Submersible Amphibie", "status": "ready",
        "folder": "swamp_mecha", "accent": "#84cc16",
        "desc": "Coque profilée étanche en bronze oxydé vert-de-gris et gris sous-marin avec hydrojets dorsaux et mât périscope. Deux véritables jambes Gundam à semelles de stabilisation, bras droit avec canon torpille/slurry haute pression et bras gauche avec bras articulé mécanique à 3 doigts articulés.",
        "atk_name": "Geysers Fangeux & Verrouillage Hydrojet",
        "atk_desc": "Projette une masse de boue corrosive qui réduit la vélocité et la cadence du joueur, suivie d'une poussée hydrojet rapide."
    },
    {
        "ch": 6, "biome": "Le Cryo-Laboratoire (cryo)", "code": "MA-06 Polar-Blizzard",
        "type": "Mobile Suit Arctique Sub-Zéro", "status": "ready",
        "folder": "cryo_mecha", "accent": "#38bdf8",
        "desc": "Blindage blanc arctique et bleu marine façon Tallgeese Polar avec 3 réservoirs d'azote liquide dorsaux sous pression. Deux jambes Gundam à crampons thermiques, bras droit avec cryo-canon à détente instantanée et bras gauche avec bras articulé mécanique isolé.",
        "atk_name": "Souffle Cryogénique & Stalagmites",
        "atk_desc": "Projette un cône de givre intense (-196°C) figeant temporairement le joueur et dressant des cristaux de glace obstructifs."
    },
    {
        "ch": 7, "biome": "Le Noyau Instable (reacteur)", "code": "MA-07 Cherenkov-Core",
        "type": "Mobile Suit Radiologique Fissile", "status": "ready",
        "folder": "reacteur_mecha", "accent": "#06b6d4",
        "desc": "Châssis de pointe en dalles de plomb et graphite poli avec hublot blindé révélant le réacteur Cherenkov cyan incandescent. Deux jambes Gundam à micro-verniers, bras droit avec accélérateur linéaire gamma à supraconducteurs et bras gauche avec bras articulé mécanique de confinement.",
        "atk_name": "Pulsion Cherenkov & Faisceau Gamma",
        "atk_desc": "Pulsion circulaire d'irradiation cyan vidant les boucliers dans un rayon d'action moyen, couplée à un tir direct de faisceau gamma rectiligne."
    },
    {
        "ch": 8, "biome": "La Ruche (ruche)", "code": "MA-08 Exterminator-Unit",
        "type": "Mobile Suit Éradicateur Biohazard", "status": "ready",
        "folder": "ruche_mecha", "accent": "#eab308",
        "desc": "Châssis militaire lourd en céramique composite noir mat et jaune d'alerte avec filtres épurateurs frontaux. Deux jambes Gundam renforcées anti-acide, bras droit avec double canon lance-flammes napalm à haute pression et bras gauche avec bras articulé mécanique.",
        "atk_name": "Rideau de Napalm & Balayage Frontal",
        "atk_desc": "Balaye le terrain avec un rideau de flammes haute vélocité en cône large, forçant un repositionnement immédiat en retrait."
    },
    {
        "ch": 9, "biome": "La Citadelle Orbitale (citadelle)", "code": "MA-09 Citadel-Bastion",
        "type": "Mobile Suit Forteresse de Siège", "status": "ready",
        "folder": "citadelle_mecha", "accent": "#f43f5e",
        "desc": "Carapace forteresse octogonale en acier trempé anthracite façon Big Zam avec volets de bouclier déployables et 4 réacteurs vernier arrière. Deux jambes Gundam ultra-lourdes à vérins d'ancrage, bras droit avec double railgun jumeau et bras gauche avec bras articulé mécanique.",
        "atk_name": "Ancrage de Siège & Salve Railgun",
        "atk_desc": "Verrouille ses vérins d'ancrage pour augmenter son blindage de 50%, libère une volée de micro-missiles et décoche un tir de railgun supersonique dévastateur."
    },
    {
        "ch": 10, "biome": "Les Abysses (abyss)", "code": "Nautilus-01",
        "type": "Bathyscaphe Submersible Lourd", "status": "ready",
        "folder": "abyss_mecha", "accent": "#06b6d4",
        "desc": "Coque sphérique rivetée en titane vert-de-gris, hublots étanches allumés, doubles turbines marines, bras canon-torpille et bras pince de récupération.",
        "atk_name": "Torpille Sonique & Vortex",
        "atk_desc": "Tir sous-marin explosant en créant un tourbillon qui aspire et ralentit le joueur de 35% pendant 1.5s."
    },
    {
        "ch": 11, "biome": "Forêt Psychédélique (ether)", "code": "Spore-Strider",
        "type": "Infiltrateur Mycélien", "status": "ready",
        "folder": "ether_mecha", "accent": "#c084fc",
        "desc": "Châssis compact anthracite mat avec conduits bioluminescents violets, silo dorsal à double cartouche de spores, canon rotatif lance-capsules.",
        "atk_name": "Mortier de Spores en Cloche",
        "atk_desc": "Tire des capsules en cloche créant au sol une nappe toxique persistante infligeant des dégâts continus."
    },
    {
        "ch": 12, "biome": "Sanctuaire Titans (titans)", "code": "Goliath-Relic",
        "type": "Colosse de Siège Antique", "status": "ready",
        "folder": "titans_mecha", "accent": "#f97316",
        "desc": "Châssis bunker en fonte d'acier rouillée rivetée, fente mono-œil orange incandescent, cheminées fumantes, bélier pneumatique et double canon.",
        "atk_name": "Frappe Sismique Tellurique",
        "atk_desc": "Martele le sol pour déclencher une onde de choc concentrique repoussant violemment le joueur et les tirs."
    },
    {
        "ch": 13, "biome": "Le Champ Orbital (orbit)", "code": "Astro-Vecteur",
        "type": "Walker Zéro-G Vectoriel", "status": "ready",
        "folder": "orbit_mecha", "accent": "#facc15",
        "desc": "Dôme panoramique doré réfléchissant sur coque blanche et or avec tuyères RCS, railgun haute vélocité et pod lance-micromissiles.",
        "atk_name": "Strafe IEM & Salve Magnétique",
        "atk_desc": "Accélérations latérales brusques suivies d'une salve de fléchettes IEM perturbant la cadence du joueur."
    },
    {
        "ch": 14, "biome": "Archives Quantiques (quantum)", "code": "Cipher-Byte",
        "type": "Matrice Cybernétique", "status": "ready",
        "folder": "quantum_mecha", "accent": "#06b6d4",
        "desc": "Châssis furtif polygonal en obsidienne biseautée, bus de données cyan/vert fluo, cœur quantique hypercube holographique, canon laser vectoriel.",
        "atk_name": "Glitch-Step & Tir Vectoriel",
        "atk_desc": "Micro-téléportation instantanée de 150 px pour changer d'angle d'approche, suivie d'un tir laser rectiligne."
    },
    {
        "ch": 15, "biome": "Faille d'Ozone (Orage) (ozone)", "code": "Volt-Jumper",
        "type": "Châssis Conducteur Ionique", "status": "ready",
        "folder": "ozone_mecha", "accent": "#eab308",
        "desc": "Châssis titane et jaune isolant, sphère Tesla centrale avec orbe électrique bleu, paratonnerres dorsaux, canon à arc de foudre et condensateurs.",
        "atk_name": "Arc de Foudre & Balises Statiques",
        "atk_desc": "Décharge un éclair en chaîne qui ricoche sur les obstacles et dépose des mines électrostatiques sur sa trajectoire."
    },
    {
        "ch": 16, "biome": "Grotte Prismatique (prism)", "code": "Spectra-Mech",
        "type": "Réfracteur de Quartz & Géode", "status": "ready",
        "folder": "prism_mecha", "accent": "#e0e7ff",
        "desc": "Châssis géodésique en chrome poli miroir incrusté de facettes de quartz cristallin, canon à lentilles de cristal et bouclier miroir hexagonal.",
        "atk_name": "Faisceau Diffracté Prismatique",
        "atk_desc": "Faisceau photonique qui se fragmente en 3 rayons secondaires en arc-en-ciel après 200 px ou à l'impact."
    },
    {
        "ch": 17, "biome": "Le Bastion Vapeur (steampunk)", "code": "Steam-Dread",
        "type": "Chaudronnier à Vapeur Victorien", "status": "ready",
        "folder": "steampunk_mecha", "accent": "#d97706",
        "desc": "Chaudière ronde en fonte rivetée de bronze, foyer rougeoyant visible, manomètre circulaire, cheminées de cuivre, Gatling en laiton et marteau-pilon.",
        "atk_name": "Jet de Vapeur & Ruée Pistons",
        "atk_desc": "Cône de vapeur surchauffée aveuglant la zone suivi d'une courte charge brutale propulsée par un sursaut de vapeur."
    },
    {
        "ch": 18, "biome": "L'Arène Éternelle (colosseum)", "code": "Colosseum-Gladiator",
        "type": "Champion Cyber-Gladiateur", "status": "ready",
        "folder": "colosseum_mecha", "accent": "#ef4444",
        "desc": "Blindage d'arène en céramique rouge sang et titane martelé, dôme dorsal doré avec flamme holographique, lance-grappin énergétique et canon-fusil.",
        "atk_name": "Ruée de Gladiateur & Coup de Grâce",
        "atk_desc": "Charge circulaire autour du joueur puis déclenche une frappe tranchante thermique dévastatrice de courte portée."
    }
]

def build_card(m):
    folder = m["folder"]
    concept_path = f"meshy_in/{folder}/concept.png"
    blueprint_path = f"meshy_in/{folder}/blueprint.png"
    
    if os.path.exists(os.path.join(r"C:\Users\Administrator\mecha-forge", concept_path)):
        img_src = concept_path
        badge = '<span class="badge badge-ready">✓ RENDU 3D MESHY DISPONIBLE</span>'
        status_flag = "ready"
    else:
        img_src = blueprint_path
        badge = '<span class="badge badge-blueprint">📐 CAD BLUEPRINT & PROMPT PRÊT</span>'
        status_flag = "blueprint"
        
    prompt_file = os.path.join(r"C:\Users\Administrator\mecha-forge", f"meshy_in/{folder}/prompt.txt")
    prompt_text = ""
    if os.path.exists(prompt_file):
        with open(prompt_file, "r", encoding="utf-8") as pf:
            prompt_text = pf.read().strip()
            
    escaped_prompt = prompt_text.replace('"', '&quot;').replace("'", "&#39;")

    return f"""
    <div class="mecha-card" style="--accent: {m['accent']};" data-chapter="{m['ch']}" data-status="{status_flag}">
      <div class="card-header">
        <span class="ch-tag">CHAPITRE {m['ch']}</span>
        {badge}
      </div>
      <div class="card-img-wrap" onclick="openModal('{img_src}', '{m['code']} — {m['type']}')">
        <img src="{img_src}" alt="{m['code']}" class="card-img" loading="lazy">
        <div class="img-overlay"><span>🔍 Cliquer pour examiner en haute résolution</span></div>
      </div>
      <div class="card-body">
        <div class="mecha-title-wrap">
          <h2 class="mecha-code">{m['code']}</h2>
          <span class="mecha-type">{m['type']}</span>
        </div>
        <div class="biome-tag">📍 {m['biome']}</div>
        <p class="mecha-desc">{m['desc']}</p>
        <div class="atk-box">
          <div class="atk-header">
            <span class="atk-icon">⚡</span>
            <span class="atk-title">{m['atk_name']}</span>
          </div>
          <p class="atk-desc">{m['atk_desc']}</p>
        </div>
        <div class="prompt-box">
          <div class="prompt-header">
            <span>PROMPT MESHY (CANON + BRAS ARTICULÉ)</span>
            <button class="btn-copy" onclick="copyPrompt('{escaped_prompt}', event)">Copier Prompt</button>
          </div>
          <div class="prompt-content">{prompt_text[:140]}...</div>
        </div>
      </div>
    </div>
    """

cards_html = "\n".join(build_card(m) for m in mechas)

full_html = f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MECHA-FORGE — Catalogue des 18 Méchas Ennemis Non-Humanoïdes (Style Gundam)</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@400;600;700&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<style>
  :root {{
    --bg-dark: #0a0d14;
    --card-bg: rgba(18, 24, 38, 0.85);
    --card-border: rgba(255, 255, 255, 0.08);
    --text-main: #f1f5f9;
    --text-muted: #94a3b8;
    --neon-cyan: #06b6d4;
    --neon-orange: #f97316;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background-color: var(--bg-dark);
    background-image: 
      radial-gradient(circle at 15% 15%, rgba(6, 182, 212, 0.08) 0%, transparent 40%),
      radial-gradient(circle at 85% 85%, rgba(249, 115, 22, 0.08) 0%, transparent 40%),
      linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px),
      linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px);
    background-size: 100% 100%, 100% 100%, 40px 40px, 40px 40px;
    color: var(--text-main);
    font-family: 'Inter', system-ui, sans-serif;
    padding: 30px 20px 80px;
    min-height: 100vh;
  }}
  .container {{
    max-width: 1440px;
    margin: 0 auto;
  }}
  header {{
    text-align: center;
    margin-bottom: 40px;
    padding: 34px 24px;
    background: rgba(18, 24, 38, 0.65);
    border: 1px solid var(--card-border);
    border-radius: 16px;
    backdrop-filter: blur(14px);
    box-shadow: 0 10px 40px rgba(0,0,0,0.5);
  }}
  .eyebrow {{
    font-family: 'Chakra Petch', sans-serif;
    font-size: 13px;
    letter-spacing: 0.25em;
    color: var(--neon-cyan);
    text-transform: uppercase;
    margin-bottom: 10px;
  }}
  h1 {{
    font-family: 'Chakra Petch', sans-serif;
    font-size: 38px;
    font-weight: 700;
    letter-spacing: 0.02em;
    background: linear-gradient(135deg, #ffffff 0%, #cbd5e1 50%, #94a3b8 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    margin-bottom: 14px;
  }}
  .subtitle {{
    font-size: 15.5px;
    color: var(--text-muted);
    max-width: 900px;
    margin: 0 auto 24px;
    line-height: 1.6;
  }}
  .spec-banner {{
    display: flex;
    justify-content: center;
    gap: 16px;
    flex-wrap: wrap;
    margin-bottom: 24px;
  }}
  .spec-pill {{
    background: rgba(6, 182, 212, 0.12);
    border: 1px solid rgba(6, 182, 212, 0.3);
    color: var(--neon-cyan);
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 12.5px;
    font-family: 'JetBrains Mono', monospace;
    font-weight: 600;
  }}
  .filter-bar {{
    display: flex;
    justify-content: center;
    gap: 12px;
    flex-wrap: wrap;
    margin-top: 15px;
  }}
  .btn-filter {{
    font-family: 'Chakra Petch', sans-serif;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.12);
    color: var(--text-main);
    padding: 9px 20px;
    border-radius: 8px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 600;
    transition: all 0.2s ease;
  }}
  .btn-filter:hover, .btn-filter.active {{
    background: var(--neon-cyan);
    color: #000;
    border-color: var(--neon-cyan);
    box-shadow: 0 0 15px rgba(6, 182, 212, 0.4);
  }}
  .grid {{
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(380px, 1fr));
    gap: 28px;
  }}
  .mecha-card {{
    background: var(--card-bg);
    border: 1px solid var(--card-border);
    border-radius: 14px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    position: relative;
    transition: transform 0.25s ease, box-shadow 0.25s ease, border-color 0.25s ease;
    backdrop-filter: blur(10px);
  }}
  .mecha-card:hover {{
    transform: translateY(-5px);
    box-shadow: 0 14px 35px rgba(0, 0, 0, 0.6), 0 0 20px rgba(var(--accent-rgb, 6, 182, 212), 0.2);
    border-color: var(--accent);
  }}
  .card-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 14px 18px;
    background: rgba(0, 0, 0, 0.4);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }}
  .ch-tag {{
    font-family: 'Chakra Petch', sans-serif;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.1em;
    color: var(--accent);
  }}
  .badge {{
    font-size: 11px;
    font-weight: 600;
    padding: 4px 10px;
    border-radius: 20px;
    font-family: 'JetBrains Mono', monospace;
  }}
  .badge-ready {{
    background: rgba(16, 185, 129, 0.15);
    color: #10b981;
    border: 1px solid rgba(16, 185, 129, 0.35);
  }}
  .badge-blueprint {{
    background: rgba(6, 182, 212, 0.15);
    color: #06b6d4;
    border: 1px solid rgba(6, 182, 212, 0.35);
  }}
  .card-img-wrap {{
    position: relative;
    width: 100%;
    aspect-ratio: 1 / 1;
    background: #070b14;
    overflow: hidden;
    cursor: pointer;
  }}
  .card-img {{
    width: 100%;
    height: 100%;
    object-fit: contain;
    transition: transform 0.4s ease;
    display: block;
  }}
  .card-img-wrap:hover .card-img {{
    transform: scale(1.04);
  }}
  .img-overlay {{
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    opacity: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: opacity 0.2s ease;
    font-size: 13px;
    font-weight: 600;
    color: #fff;
    backdrop-filter: blur(2px);
  }}
  .card-img-wrap:hover .img-overlay {{
    opacity: 1;
  }}
  .card-body {{
    padding: 20px;
    display: flex;
    flex-direction: column;
    flex: 1;
  }}
  .mecha-title-wrap {{
    margin-bottom: 8px;
  }}
  .mecha-code {{
    font-family: 'Chakra Petch', sans-serif;
    font-size: 20px;
    font-weight: 700;
    color: #fff;
    margin-bottom: 2px;
  }}
  .mecha-type {{
    font-size: 13px;
    color: var(--accent);
    font-weight: 500;
  }}
  .biome-tag {{
    display: inline-block;
    font-size: 12px;
    color: var(--text-muted);
    margin-bottom: 12px;
    font-weight: 500;
  }}
  .mecha-desc {{
    font-size: 13px;
    line-height: 1.55;
    color: #cbd5e1;
    margin-bottom: 16px;
    flex-grow: 1;
  }}
  .atk-box {{
    background: rgba(0, 0, 0, 0.35);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-left: 3px solid var(--accent);
    padding: 12px 14px;
    border-radius: 6px;
    margin-bottom: 12px;
  }}
  .atk-header {{
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 4px;
  }}
  .atk-icon {{
    font-size: 14px;
  }}
  .atk-title {{
    font-family: 'Chakra Petch', sans-serif;
    font-size: 13px;
    font-weight: 600;
    color: #fff;
  }}
  .atk-desc {{
    font-size: 12px;
    line-height: 1.45;
    color: #94a3b8;
  }}
  .prompt-box {{
    background: rgba(0, 0, 0, 0.45);
    border: 1px solid rgba(255, 255, 255, 0.04);
    border-radius: 6px;
    padding: 10px;
    font-size: 11px;
    font-family: 'JetBrains Mono', monospace;
  }}
  .prompt-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    color: var(--text-muted);
    margin-bottom: 6px;
    font-weight: 600;
  }}
  .btn-copy {{
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.15);
    color: var(--text-main);
    padding: 2px 8px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 10.5px;
    transition: all 0.2s;
  }}
  .btn-copy:hover {{
    background: var(--neon-cyan);
    color: #000;
  }}
  .prompt-content {{
    color: #64748b;
    line-height: 1.35;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }}
  
  /* Modal */
  .modal {{
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.9);
    backdrop-filter: blur(10px);
    display: none;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 30px;
  }}
  .modal.active {{
    display: flex;
  }}
  .modal-content {{
    position: relative;
    max-width: 900px;
    width: 100%;
    background: var(--card-bg);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 25px 60px rgba(0, 0, 0, 0.8);
  }}
  .modal-img-wrap {{
    width: 100%;
    max-height: 70vh;
    background: #000;
    display: flex;
    align-items: center;
    justify-content: center;
  }}
  .modal-img {{
    max-width: 100%;
    max-height: 70vh;
    object-fit: contain;
  }}
  .modal-footer {{
    padding: 16px 24px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: rgba(0, 0, 0, 0.6);
  }}
  .modal-title {{
    font-family: 'Chakra Petch', sans-serif;
    font-size: 18px;
    font-weight: 700;
    color: #fff;
  }}
  .modal-close {{
    background: rgba(255, 255, 255, 0.1);
    border: none;
    color: #fff;
    font-size: 20px;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s;
  }}
  .modal-close:hover {{
    background: #ef4444;
  }}
</style>
</head>
<body>
  <div class="container">
    <header>
      <div class="eyebrow">Roster Stratégique Global &middot; Meshy 3D Auto-Rigging Ready</div>
      <h1>Catalogue des 18 Méchas de Combat (Style Gundam Mobile Armor)</h1>
      <p class="subtitle">
        Châssis <strong>100% NON-HUMANOÏDES & STRICTEMENT NON-ANIMAUX / NON-ALIENS</strong> : Deux jambes Gundam articulées, un bras avec canon lourd d'assaut et un bras articulé mécanique de manipulation (<strong>zéro scie, zéro arme contondante</strong>).
      </p>
      
      <div class="spec-banner">
        <span class="spec-pill">🛡️ ZÉRO ANATOMIE HUMAINE / ALIEN</span>
        <span class="spec-pill">🚫 ZÉRO SCIE / ZÉRO ARME CONTONDANTE</span>
        <span class="spec-pill">🦾 CANON LOURD + BRAS ARTICULÉ</span>
        <span class="spec-pill">⚙️ DEUX JAMBES GUNDAM & POSE EN A 45°</span>
      </div>
      
      <div class="filter-bar">
        <button class="btn-filter active" onclick="filterCards('all', event)">Tous les 18 Méchas (Ch. 1 à 18)</button>
        <button class="btn-filter" onclick="filterCards('base', event)">9 Méchas Ch. 1 à 9 (Style Gundam)</button>
        <button class="btn-filter" onclick="filterCards('new', event)">9 Méchas Ch. 10 à 18</button>
      </div>
    </header>

    <div class="grid" id="mechaGrid">
      {cards_html}
    </div>
  </div>

  <div class="modal" id="imgModal" onclick="closeModal(event)">
    <div class="modal-content" onclick="event.stopPropagation()">
      <div class="modal-img-wrap">
        <img src="" alt="" class="modal-img" id="modalImg">
      </div>
      <div class="modal-footer">
        <div class="modal-title" id="modalTitle"></div>
        <button class="modal-close" onclick="closeModal(event)">&times;</button>
      </div>
    </div>
  </div>

  <script>
    function filterCards(type, e) {{
      document.querySelectorAll('.btn-filter').forEach(btn => btn.classList.remove('active'));
      e.target.classList.add('active');

      const cards = document.querySelectorAll('.mecha-card');
      cards.forEach(card => {{
        const ch = parseInt(card.getAttribute('data-chapter'));
        if (type === 'all') {{
          card.style.display = 'flex';
        }} else if (type === 'base') {{
          card.style.display = ch <= 9 ? 'flex' : 'none';
        }} else if (type === 'new') {{
          card.style.display = ch >= 10 ? 'flex' : 'none';
        }}
      }});
    }}

    function openModal(imgSrc, title) {{
      document.getElementById('modalImg').src = imgSrc;
      document.getElementById('modalTitle').textContent = title;
      document.getElementById('imgModal').classList.add('active');
    }}

    function closeModal(e) {{
      document.getElementById('imgModal').classList.remove('active');
    }}

    function copyPrompt(text, e) {{
      e.stopPropagation();
      navigator.clipboard.writeText(text).then(() => {{
        const btn = e.target;
        const originalText = btn.textContent;
        btn.textContent = 'Copié !';
        btn.style.background = '#10b981';
        btn.style.color = '#fff';
        setTimeout(() => {{
          btn.textContent = originalText;
          btn.style.background = '';
          btn.style.color = '';
        }}, 1800);
      }}).catch(err => {{
        alert('Impossible de copier automatiquement : ' + err);
      }});
    }}

    document.addEventListener('keydown', (e) => {{
      if (e.key === 'Escape') closeModal();
    }});
  </script>
</body>
</html>
"""

with open(html_path, "w", encoding="utf-8") as f:
    f.write(full_html)

print("catalogue_mechas.html updated successfully with clean cannon + articulated arm specs!")
