# -*- coding: utf-8 -*-
"""Comprehensively registers all 9 new biomes (abyss, ether, titans, orbit, quantum, ozone, prism, steampunk, colosseum)
into PropScatter.gd, EnemySpawner.gd, Game.gd, Palette.gd, and Audio.gd.
"""

import sys

PROPSCATTER_PATH = r"C:\Users\Administrator\mecha-forge\game\actors\PropScatter.gd"
ENEMYSPAWNER_PATH = r"C:\Users\Administrator\mecha-forge\game\systems\EnemySpawner.gd"
GAME_PATH = r"C:\Users\Administrator\mecha-forge\game\scenes\Game.gd"
PALETTE_PATH = r"C:\Users\Administrator\mecha-forge\game\autoload\Palette.gd"
AUDIO_PATH = r"C:\Users\Administrator\mecha-forge\game\autoload\Audio.gd"

DECOR_ITEMS = """
	# ===== NIVEAU 10 : ABYSS =====
	"abyss_tourelle_torpille":     {"f": "abyss_tourelle_torpille", "hp": 220.0, "sz": 165.0, "destruct": true, "glow": "cyan",
	                                "shoot": 450.0, "shoot_cd": 2.2, "shoot_dmg": 18.0, "aim": 135.0, "arc": 45.0, "muzzle": [-60.0, 70.0]},
	"abyss_emetteur_geyser":       {"f": "abyss_emetteur_geyser", "hp": 240.0, "sz": 175.0, "destruct": true, "glow": "orange",
	                                "geyser": true, "geyser_cd": 4.5, "geyser_r": 180.0, "geyser_dmg": 20.0},
	"abyss_butin_caisson_etanche": {"f": "abyss_butin_caisson_etanche", "hp": 55.0, "sz": 130.0, "destruct": true, "skill": 0.55, "glow": "cyan"},
	"abyss_inter_dome_oxygene":    {"f": "abyss_inter_dome_oxygene", "hp": 180.0, "sz": 160.0, "destruct": true, "glow": "cyan",
	                                "dome_shield": true, "dome_r": 180.0, "dome_cd": 15.0},
	"abyss_inter_mine_ancree":     {"f": "abyss_inter_mine_ancree", "hp": 45.0, "sz": 140.0, "destruct": true, "glow": "orange",
	                                "boom": true, "boom_r": 220.0, "boom_dmg": 45.0},
	"abyss_terrain_colonne_recif": {"f": "abyss_terrain_colonne_recif", "hp": 300.0, "sz": 200.0, "nature": true, "block": 0.45},
	"abyss_bordure_faille":        {"f": "abyss_bordure_faille", "hp": 400.0, "sz": 220.0, "nature": true, "block": 0.50},

	# ===== NIVEAU 11 : ETHER =====
	"ether_tourelle_spores":       {"f": "ether_tourelle_spores", "hp": 210.0, "sz": 160.0, "destruct": true, "glow": "magenta", "shoot": 420.0, "shoot_cd": 2.4, "shoot_dmg": 16.0, "aim": 135.0, "arc": 40.0, "muzzle": [-50.0, 60.0]},
	"ether_emetteur_gaz":          {"f": "ether_emetteur_gaz", "hp": 220.0, "sz": 170.0, "destruct": true, "glow": "cyan", "hazard": true, "hazard_cd": 4.0, "hazard_r": 170.0, "hazard_dmg": 18.0},
	"ether_butin_cosse_fluo":      {"f": "ether_butin_cosse_fluo", "hp": 50.0, "sz": 130.0, "destruct": true, "skill": 0.55, "glow": "magenta"},
	"ether_inter_pollen_regen":    {"f": "ether_inter_pollen_regen", "hp": 170.0, "sz": 160.0, "destruct": true, "glow": "cyan", "aura": "heal", "aura_r": 220.0, "aura_p1": 4.0},
	"ether_inter_champignon_rebond": {"f": "ether_inter_champignon_rebond", "hp": 160.0, "sz": 150.0, "nature": true, "block": 0.35, "grav_zone": true, "grav_r": 180.0, "grav_force": 120.0},
	"ether_terrain_fongus_arbre":  {"f": "ether_terrain_fongus_arbre", "hp": 320.0, "sz": 220.0, "nature": true, "block": 0.45},
	"ether_bordure_mycelium":      {"f": "ether_bordure_mycelium", "hp": 380.0, "sz": 230.0, "nature": true, "block": 0.50},

	# ===== NIVEAU 12 : TITANS =====
	"titans_tourelle_artillerie":   {"f": "titans_tourelle_artillerie", "hp": 260.0, "sz": 180.0, "destruct": true, "glow": "orange", "shoot": 500.0, "shoot_cd": 3.0, "shoot_dmg": 30.0, "aim": 135.0, "arc": 35.0, "muzzle": [-70.0, 80.0]},
	"titans_emetteur_fuite_huile": {"f": "titans_emetteur_fuite_huile", "hp": 230.0, "sz": 160.0, "destruct": true, "glow": "orange", "slow": true, "slow_r": 200.0, "slow_mult": 0.45},
	"titans_butin_coffre_blindage": {"f": "titans_butin_coffre_blindage", "hp": 70.0, "sz": 135.0, "destruct": true, "skill": 0.60, "glow": "orange"},
	"titans_inter_electroaimant_epave": {"f": "titans_inter_electroaimant_epave", "hp": 190.0, "sz": 165.0, "destruct": true, "glow": "orange", "arc": true, "arc_cd": 2.0, "arc_dmg": 25.0, "arc_r": 280.0},
	"titans_inter_mine_antichar":   {"f": "titans_inter_mine_antichar", "hp": 50.0, "sz": 140.0, "destruct": true, "glow": "orange", "boom": true, "boom_r": 240.0, "boom_dmg": 60.0},
	"titans_terrain_main_colosse":  {"f": "titans_terrain_main_colosse", "hp": 350.0, "sz": 220.0, "nature": true, "block": 0.50},
	"titans_bordure_squelette":    {"f": "titans_bordure_squelette", "hp": 420.0, "sz": 240.0, "nature": true, "block": 0.50},

	# ===== NIVEAU 13 : ORBIT =====
	"orbit_tourelle_laser_impulsion": {"f": "orbit_tourelle_laser_impulsion", "hp": 220.0, "sz": 160.0, "destruct": true, "glow": "cyan", "shoot": 480.0, "shoot_cd": 2.0, "shoot_dmg": 22.0, "aim": 135.0, "arc": 45.0, "muzzle": [-60.0, 70.0]},
	"orbit_emetteur_propulseur_rcs":  {"f": "orbit_emetteur_propulseur_rcs", "hp": 200.0, "sz": 155.0, "destruct": true, "glow": "cyan", "hazard": true, "hazard_cd": 3.8, "hazard_r": 180.0, "hazard_dmg": 24.0},
	"orbit_butin_capsule_cargo":     {"f": "orbit_butin_capsule_cargo", "hp": 55.0, "sz": 130.0, "destruct": true, "skill": 0.60, "glow": "cyan"},
	"orbit_inter_borne_antigravite": {"f": "orbit_inter_borne_antigravite", "hp": 180.0, "sz": 150.0, "destruct": true, "glow": "cyan", "grav_zone": true, "grav_r": 200.0, "grav_force": 90.0},
	"orbit_inter_piege_emp":         {"f": "orbit_inter_piege_emp", "hp": 45.0, "sz": 135.0, "destruct": true, "glow": "magenta", "boom": true, "boom_r": 220.0, "boom_dmg": 40.0},
	"orbit_terrain_panneau_solaire_brise": {"f": "orbit_terrain_panneau_solaire_brise", "hp": 280.0, "sz": 190.0, "nature": true, "block": 0.40},
	"orbit_bordure_paroi_station":   {"f": "orbit_bordure_paroi_station", "hp": 400.0, "sz": 230.0, "nature": true, "block": 0.50},

	# ===== NIVEAU 14 : QUANTUM =====
	"quantum_tourelle_faisceau_vecteur": {"f": "quantum_tourelle_faisceau_vecteur", "hp": 240.0, "sz": 170.0, "destruct": true, "glow": "gold", "shoot": 520.0, "shoot_cd": 2.5, "shoot_dmg": 26.0, "aim": 135.0, "arc": 30.0, "muzzle": [-60.0, 75.0]},
	"quantum_emetteur_grille_code":      {"f": "quantum_emetteur_grille_code", "hp": 210.0, "sz": 160.0, "destruct": true, "glow": "gold", "hazard": true, "hazard_cd": 4.2, "hazard_r": 190.0, "hazard_dmg": 22.0},
	"quantum_butin_cube_memoire":        {"f": "quantum_butin_cube_memoire", "hp": 50.0, "sz": 125.0, "destruct": true, "skill": 0.65, "glow": "gold"},
	"quantum_inter_dalle_transfert":     {"f": "quantum_inter_dalle_transfert", "hp": 190.0, "sz": 160.0, "destruct": true, "glow": "gold", "grav_zone": true, "grav_r": 180.0, "grav_force": 140.0},
	"quantum_inter_cube_glitch":         {"f": "quantum_inter_cube_glitch", "hp": 45.0, "sz": 130.0, "destruct": true, "glow": "gold", "boom": true, "boom_r": 200.0, "boom_dmg": 50.0},
	"quantum_terrain_monolithe_flottant": {"f": "quantum_terrain_monolithe_flottant", "hp": 320.0, "sz": 210.0, "nature": true, "block": 0.45},
	"quantum_bordure_paroi_matrice":     {"f": "quantum_bordure_paroi_matrice", "hp": 400.0, "sz": 220.0, "nature": true, "block": 0.50},

	# ===== NIVEAU 15 : OZONE =====
	"ozone_tourelle_arc_eclair":          {"f": "ozone_tourelle_arc_eclair", "hp": 230.0, "sz": 165.0, "destruct": true, "glow": "magenta", "shoot": 460.0, "shoot_cd": 2.1, "shoot_dmg": 20.0, "aim": 135.0, "arc": 40.0, "muzzle": [-55.0, 70.0]},
	"ozone_emetteur_parafoudre":          {"f": "ozone_emetteur_parafoudre", "hp": 220.0, "sz": 170.0, "destruct": true, "glow": "magenta", "hazard": true, "hazard_cd": 3.6, "hazard_r": 180.0, "hazard_dmg": 25.0},
	"ozone_butin_accumulateur":           {"f": "ozone_butin_accumulateur", "hp": 55.0, "sz": 130.0, "destruct": true, "skill": 0.55, "glow": "magenta"},
	"ozone_inter_condensateur_surcharge": {"f": "ozone_inter_condensateur_surcharge", "hp": 180.0, "sz": 155.0, "destruct": true, "glow": "magenta", "dwell": true, "dwell_time": 1.0, "dwell_r": 150.0, "buff": "overdrive", "buff_dur": 8.0},
	"ozone_inter_cristal_piezo":          {"f": "ozone_inter_cristal_piezo", "hp": 40.0, "sz": 135.0, "destruct": true, "glow": "magenta", "boom": true, "boom_r": 210.0, "boom_dmg": 45.0},
	"ozone_terrain_fleche_fulgurite":     {"f": "ozone_terrain_fleche_fulgurite", "hp": 300.0, "sz": 200.0, "nature": true, "block": 0.45},
	"ozone_bordure_mur_ionique":          {"f": "ozone_bordure_mur_ionique", "hp": 390.0, "sz": 220.0, "nature": true, "block": 0.50},

	# ===== NIVEAU 16 : PRISM =====
	"prism_tourelle_refracteur":       {"f": "prism_tourelle_refracteur", "hp": 220.0, "sz": 165.0, "destruct": true, "glow": "cyan", "shoot": 490.0, "shoot_cd": 2.3, "shoot_dmg": 24.0, "aim": 135.0, "arc": 35.0, "muzzle": [-60.0, 75.0]},
	"prism_emetteur_faisceau_laser":   {"f": "prism_emetteur_faisceau_laser", "hp": 210.0, "sz": 160.0, "destruct": true, "glow": "cyan", "hazard": true, "hazard_cd": 4.0, "hazard_r": 185.0, "hazard_dmg": 21.0},
	"prism_butin_geode_cristal":       {"f": "prism_butin_geode_cristal", "hp": 50.0, "sz": 130.0, "destruct": true, "skill": 0.60, "glow": "cyan"},
	"prism_inter_miroir_deflexion":    {"f": "prism_inter_miroir_deflexion", "hp": 180.0, "sz": 150.0, "nature": true, "block": 0.40, "dome_shield": true, "dome_r": 170.0, "dome_cd": 12.0},
	"prism_inter_stalagmite_fragile":  {"f": "prism_inter_stalagmite_fragile", "hp": 40.0, "sz": 135.0, "destruct": true, "glow": "cyan", "boom": true, "boom_r": 200.0, "boom_dmg": 40.0},
	"prism_terrain_grappe_cristaux":   {"f": "prism_terrain_grappe_cristaux", "hp": 310.0, "sz": 210.0, "nature": true, "block": 0.45},
	"prism_bordure_paroi_silice":      {"f": "prism_bordure_paroi_silice", "hp": 410.0, "sz": 230.0, "nature": true, "block": 0.50},

	# ===== NIVEAU 17 : STEAMPUNK =====
	"steampunk_tourelle_gatling_vapeur":   {"f": "steampunk_tourelle_gatling_vapeur", "hp": 250.0, "sz": 170.0, "destruct": true, "glow": "orange", "shoot": 440.0, "shoot_cd": 1.6, "shoot_dmg": 12.0, "aim": 135.0, "arc": 45.0, "muzzle": [-65.0, 75.0]},
	"steampunk_emetteur_purge_vapeur":     {"f": "steampunk_emetteur_purge_vapeur", "hp": 220.0, "sz": 165.0, "destruct": true, "glow": "orange", "hazard": true, "hazard_cd": 3.5, "hazard_r": 170.0, "hazard_dmg": 20.0},
	"steampunk_butin_coffre_fort_laiton":  {"f": "steampunk_butin_coffre_fort_laiton", "hp": 60.0, "sz": 135.0, "destruct": true, "skill": 0.55, "glow": "gold"},
	"steampunk_inter_vanne_surchauffe":    {"f": "steampunk_inter_vanne_surchauffe", "hp": 180.0, "sz": 150.0, "destruct": true, "glow": "orange", "aura": "heal", "aura_r": 200.0, "aura_p1": 5.0},
	"steampunk_inter_chaudiere_instable":  {"f": "steampunk_inter_chaudiere_instable", "hp": 45.0, "sz": 140.0, "destruct": true, "glow": "orange", "boom": true, "boom_r": 230.0, "boom_dmg": 50.0},
	"steampunk_terrain_engrenage_monumental": {"f": "steampunk_terrain_engrenage_monumental", "hp": 340.0, "sz": 220.0, "nature": true, "block": 0.48},
	"steampunk_bordure_mur_briques_fonte": {"f": "steampunk_bordure_mur_briques_fonte", "hp": 420.0, "sz": 240.0, "nature": true, "block": 0.50},

	# ===== NIVEAU 18 : COLOSSEUM =====
	"colosseum_tourelle_simulation":     {"f": "colosseum_tourelle_simulation", "hp": 230.0, "sz": 165.0, "destruct": true, "glow": "cyan", "shoot": 470.0, "shoot_cd": 2.0, "shoot_dmg": 20.0, "aim": 135.0, "arc": 40.0, "muzzle": [-60.0, 70.0]},
	"colosseum_emetteur_barre_exercice": {"f": "colosseum_emetteur_barre_exercice", "hp": 210.0, "sz": 160.0, "destruct": true, "glow": "cyan", "rot_laser": true},
	"colosseum_butin_module_test":       {"f": "colosseum_butin_module_test", "hp": 55.0, "sz": 130.0, "destruct": true, "skill": 0.60, "glow": "cyan"},
	"colosseum_inter_pod_overdrive":     {"f": "colosseum_inter_pod_overdrive", "hp": 190.0, "sz": 160.0, "destruct": true, "glow": "cyan", "dwell": true, "dwell_time": 1.2, "dwell_r": 160.0, "buff": "overdrive", "buff_dur": 10.0},
	"colosseum_inter_mine_exercice":     {"f": "colosseum_inter_mine_exercice", "hp": 45.0, "sz": 135.0, "destruct": true, "glow": "orange", "boom": true, "boom_r": 200.0, "boom_dmg": 40.0},
	"colosseum_terrain_pilier_holomur":  {"f": "colosseum_terrain_pilier_holomur", "hp": 300.0, "sz": 200.0, "nature": true, "block": 0.45},
	"colosseum_bordure_paroi_blindee":   {"f": "colosseum_bordure_paroi_blindee", "hp": 410.0, "sz": 230.0, "nature": true, "block": 0.50},
"""

INFO_ITEMS = """
	# ===== NIVEAU 10 : ABYSS =====
	"abyss_tourelle_torpille": ["Tourelle torpille", "Tire des torpilles à cavitation sous-marine sur son axe frontal.", "cyan"],
	"abyss_emetteur_geyser": ["Geyser hydrothermal", "Cheminée volcanique sous-marine qui crache une onde d'eau brûlante.", "orange"],
	"abyss_butin_caisson_etanche": ["Caisson étanche", "Détruisez-le : butin de plongée, ferraille et compétences scellées.", "cyan"],
	"abyss_inter_dome_oxygene": ["Dôme d'oxygène", "RESTEZ dans le dôme : active un champ défensif temporaire.", "cyan"],
	"abyss_inter_mine_ancree": ["Mine sous-marine", "Mine dérivante armée : explose violemment si un mecha s'approche.", "orange"],
	"abyss_terrain_colonne_recif": ["Colonne de récif", "Monolithe ancien de la cité engloutie colonisé par des coraux.", "cyan"],
	"abyss_bordure_faille": ["Cloison de faille abyssale", "Batardeau étanche blindé marquant la limite de la fosse sous-marine.", "cyan"],

	# ===== NIVEAU 11 : ETHER =====
	"ether_tourelle_spores": ["Tourelle à spores", "Tire des cosses de spores luminescentes toxiques en cloche.", "magenta"],
	"ether_emetteur_gaz": ["Cheminée d'éther", "Évent fongique qui pulse des nuages de gaz éthéré en continu.", "cyan"],
	"ether_butin_cosse_fluo": ["Cosse bioluminescente", "Détruisez-la : enzymes xénomorphes, ferraille et compétences.", "magenta"],
	"ether_inter_pollen_regen": ["Cercle de fées régénérant", "RESTEZ dans le cercle : régénère la santé du mecha et absorbe les chocs.", "cyan"],
	"ether_inter_champignon_rebond": ["Champignon trampoline", "Chapeau élastique : repousse violemment tout ce qui le percute.", "magenta"],
	"ether_terrain_fongus_arbre": ["Arbre fongique géant", "Tronc spongieux colossal surmonté d'amadous luminescents.", "cyan"],
	"ether_bordure_mycelium": ["Paroi de mycélium", "Barrière infranchissable de chitine et de filaments fongiques denses.", "magenta"],

	# ===== NIVEAU 12 : TITANS =====
	"titans_tourelle_artillerie": ["Canon de cuirassé terrestre", "Canonnade d'artillerie lourde 400mm à longue portée.", "orange"],
	"titans_emetteur_fuite_huile": ["Fuite hydraulique de titan", "Flaque de pétrole et de boue noire ralentissant fortement quiconque s'y aventure.", "orange"],
	"titans_butin_coffre_blindage": ["Boîte noire blindée", "Détruisez-la : composants militaires de haute valeur et compétences.", "orange"],
	"titans_inter_electroaimant_epave": ["Électroaimant de récupération", "Attire les ferrailles et foudroie les ennemis proches avec des arcs EMP.", "orange"],
	"titans_inter_mine_antichar": ["Mine antichar géante", "Mine à déclencheur de pression provoquant un souffle dévastateur.", "orange"],
	"titans_terrain_main_colosse": ["Poing de colosse écroulé", "Main mécanique géante rouillée servant d'abri fortifié contre les tirs.", "orange"],
	"titans_bordure_squelette": ["Côtes d'acier du vaisseau amiral", "Squelette de poutrelles géantes délimitant la nécropole.", "orange"],

	# ===== NIVEAU 13 : ORBIT =====
	"orbit_tourelle_laser_impulsion": ["Tourelle de point-défense", "Tir laser pulsé ultraviolet à balayage rapide de sécurité spatiale.", "cyan"],
	"orbit_emetteur_propulseur_rcs": ["Tuyère RCS défaillante", "Éjecte périodiquement un jet de plasma de correction de trajectoire.", "cyan"],
	"orbit_butin_capsule_cargo": ["Capsule de fret spatial", "Détruisez-la : conteneur orbital avec module de surclassement.", "gold"],
	"orbit_inter_borne_antigravite": ["Balise d'annulation d'inertie", "Champ d'apesanteur : confère une vitesse de déplacement décuplée.", "cyan"],
	"orbit_inter_piege_emp": ["Mine IEM spatiale", "Mine satellite dérivante libérant une décharge disruptive.", "magenta"],
	"orbit_terrain_panneau_solaire_brise": ["Panneau solaire disloqué", "Structure photovoltaïque réflective faisant barrage aux attaques.", "cyan"],
	"orbit_bordure_paroi_station": ["Bouclier micrométéorique", "Cloison de confinement étanche fermant le sas du secteur orbital.", "cyan"],

	# ===== NIVEAU 14 : QUANTUM =====
	"quantum_tourelle_faisceau_vecteur": ["Spindle vectoriel quantique", "Faisceau laser géométrique doré pur découpant l'espace à cadence fixe.", "gold"],
	"quantum_emetteur_grille_code": ["Scanner de matrice", "Pyramide à facettes balayant le sol avec des rideaux de scanlines dorées.", "gold"],
	"quantum_butin_cube_memoire": ["Tesseract de données", "Détruisez-le : banque de mémoire quantique renfermant des compétences rares.", "gold"],
	"quantum_inter_dalle_transfert": ["Dalle de saut quantique", "Marcher sur la dalle propulse instantanément le mecha hors de danger.", "gold"],
	"quantum_inter_cube_glitch": ["Cube de glitch spatial", "Anomalie géométrique instable implosant en ondes de fragmentation voxel.", "gold"],
	"quantum_terrain_monolithe_flottant": ["Monolithe de serveurs d'obsidienne", "Pilier de données en lévitation magnétique indestructible.", "gold"],
	"quantum_bordure_paroi_matrice": ["Mur d'enceinte du noyau", "Enceinte architecturale d'obsidienne miroir verrouillant les archives.", "gold"],

	# ===== NIVEAU 15 : OZONE =====
	"ozone_tourelle_arc_eclair": ["Bobine à foudre ionique", "Décharge un éclair ramifié violent vers la cible la plus proche.", "magenta"],
	"ozone_emetteur_parafoudre": ["Tour paratonnerre", "Canalise les décharges atmosphériques en cercles de surtension au sol.", "magenta"],
	"ozone_butin_accumulateur": ["Batterie haute tension", "Détruisez-la : condensateurs, cellules d'énergie et compétences.", "magenta"],
	"ozone_inter_condensateur_surcharge": ["Pylône de surcharge cinétique", "RESTEZ dedans : charge les générateurs du mecha pour une cadence accélérée.", "magenta"],
	"ozone_inter_cristal_piezo": ["Cristal piézoélectrique instable", "Touché, il libère un arc en chaîne électrocutant mechas et ennemis.", "magenta"],
	"ozone_terrain_fleche_fulgurite": ["Flèche de fulgurite vitrifiée", "Colonne de silice fondue par la foudre formant un abri isolant.", "magenta"],
	"ozone_bordure_mur_ionique": ["Grille ionique haute tension", "Clôture d'arcs de plasma ininterrompus délimitant la faille d'ozone.", "magenta"],

	# ===== NIVEAU 16 : PRISM =====
	"prism_tourelle_refracteur": ["Réfracteur prismatique", "Focalise la lumière en un rayon laser concentré à haute intensité.", "cyan"],
	"prism_emetteur_faisceau_laser": ["Prisme d'émanation", "Balaie le sol de lames spectrales étincelantes découpant la roche.", "cyan"],
	"prism_butin_geode_cristal": ["Géode scintillante", "Détruisez-la : cristaux précieux de haute pureté et compétences.", "cyan"],
	"prism_inter_miroir_deflexion": ["Miroir optique déflecteur", "Défléchit les tirs ennemis et renvoie les faisceaux laser démultipliés.", "cyan"],
	"prism_inter_stalagmite_fragile": ["Stalagmite de verre fragile", "S'effondre en éclats tranchants dès qu'un choc physique se produit.", "cyan"],
	"prism_terrain_grappe_cristaux": ["Piliers de quartz géant", "Formation minérale translucide indestructible reflétant les projectiles.", "cyan"],
	"prism_bordure_paroi_silice": ["Paroi de géode brute", "Muraille étincelante de cristaux de calcite fermant l'abîme prismatique.", "cyan"],

	# ===== NIVEAU 17 : STEAMPUNK =====
	"steampunk_tourelle_gatling_vapeur": ["Mitrailleuse à vapeur", "Tire des rafales frénétiques de cartouches de bronze propulsées à la vapeur.", "orange"],
	"steampunk_emetteur_purge_vapeur": ["Purgeur de chaudière", "Libère cycliquement des jets de vapeur brûlante sous haute pression.", "orange"],
	"steampunk_butin_coffre_fort_laiton": ["Coffre d'horlogerie", "Détruisez-le : mécanismes de précision, laiton et compétences.", "gold"],
	"steampunk_inter_vanne_surchauffe": ["Console de régulation", "Actionner le volant déploie un écran de vapeur bienfaisant dissipant les dégâts.", "orange"],
	"steampunk_inter_chaudiere_instable": ["Chaudière en surpression", "Réservoir instable prêt à exploser en un violent souffle de vapeur.", "orange"],
	"steampunk_terrain_engrenage_monumental": ["Roue d'horlogerie monumentale", "Engrenage géant d'acier et de laiton servant de barricade blindée.", "orange"],
	"steampunk_bordure_mur_briques_fonte": ["Façade de fonderie victorienne", "Mur de briques sombres et piliers en fonte délimitant l'usine.", "orange"],

	# ===== NIVEAU 18 : COLOSSEUM =====
	"colosseum_tourelle_simulation": ["Tourelle d'entraînement", "Canon d'exercice tactique tirant des salves de calibrage militaire.", "cyan"],
	"colosseum_emetteur_barre_exercice": ["Balise rotative d'exercice", "Balaie le sol d'un faisceau laser continu rotatif à franchir au bon moment.", "cyan"],
	"colosseum_butin_module_test": ["Caisson d'évaluation tactique", "Détruisez-le : récompense d'entraînement et modules d'amélioration.", "cyan"],
	"colosseum_inter_pod_overdrive": ["Pod de recharge d'Overdrive", "RESTEZ dans la borne : remplit instantanément la jauge d'Overdrive.", "cyan"],
	"colosseum_inter_mine_exercice": ["Disque de répulsion cinétique", "Déclenchement d'une onde de choc projetant ennemis et projectiles à distance.", "orange"],
	"colosseum_terrain_pilier_holomur": ["Pilier de projection holographique", "Balise projetant des données tactiques et servant de couverture solide.", "cyan"],
	"colosseum_bordure_paroi_blindee": ["Blindage du colisée", "Muraille fortifiée d'arène d'exercice avec projecteurs de stade.", "cyan"],
"""

def update_propscatter():
    with open(PROPSCATTER_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Update DECOR
    decor_anchor = '"segment_mur_modulaire": {"f": "segment_mur_modulaire", "hp": 220.0, "sz": 170.0, "nature": true, "block": 0.40,\n\t                       "cycle": true, "cycle_on": 10.0, "cycle_off": 8.0},\n}'
    if decor_anchor in content:
        content = content.replace(decor_anchor, decor_anchor[:-2] + ",\n" + DECOR_ITEMS.strip() + "\n}")
        print("[PropScatter] DECOR updated successfully")
    elif "abyss_tourelle_torpille" in content:
        print("[PropScatter] DECOR already contains abyss props")
    else:
        print("[PropScatter] ERROR: decor_anchor not found!")
        sys.exit(1)

    # 2. Update INFO
    info_anchor = '"citadelle_bordure_coque": ["Coque orbitale blindée", "Blindage spatial composite formant la limite extérieure de la station orbitale.", "cyan"],\n}'
    if info_anchor in content:
        content = content.replace(info_anchor, info_anchor[:-2] + ",\n" + INFO_ITEMS.strip() + "\n}")
        print("[PropScatter] INFO updated successfully")
    elif '"abyss_tourelle_torpille":' in content:
        print("[PropScatter] INFO already contains abyss props")
    else:
        print("[PropScatter] ERROR: info_anchor not found!")
        sys.exit(1)

    with open(PROPSCATTER_PATH, "w", encoding="utf-8") as f:
        f.write(content)

def update_enemyspawner():
    with open(ENEMYSPAWNER_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. BIOME_TINT
    tint_anchor = '\t"citadelle": Color(1.15, 1.05, 0.75),\n}'
    tints_new = """\t"citadelle": Color(1.15, 1.05, 0.75),
\t"abyss":     Color(0.65, 0.95, 1.20),
\t"ether":     Color(0.85, 0.65, 1.15),
\t"titans":    Color(1.15, 0.85, 0.65),
\t"orbit":     Color(0.80, 0.95, 1.15),
\t"quantum":   Color(1.10, 1.05, 0.70),
\t"ozone":     Color(1.10, 0.70, 1.15),
\t"prism":     Color(0.95, 1.10, 1.15),
\t"steampunk": Color(1.15, 0.90, 0.70),
\t"colosseum": Color(0.90, 1.05, 1.10),
}"""
    if tint_anchor in content:
        content = content.replace(tint_anchor, tints_new)
        print("[EnemySpawner] BIOME_TINT updated successfully")
    elif '"abyss":     Color(' in content:
        print("[EnemySpawner] BIOME_TINT already contains abyss")
    else:
        print("[EnemySpawner] WARNING: tint_anchor not found")

    # 2. BIOME_ORDER
    order_old = 'const BIOME_ORDER: Array = ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "cryo", "reacteur", "ruche", "citadelle"]'
    order_new = 'const BIOME_ORDER: Array = ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "cryo", "reacteur", "ruche", "citadelle", "abyss", "ether", "titans", "orbit", "quantum", "ozone", "prism", "steampunk", "colosseum"]'
    if order_old in content:
        content = content.replace(order_old, order_new)
        print("[EnemySpawner] BIOME_ORDER updated successfully")
    elif '"colosseum"]' in content:
        print("[EnemySpawner] BIOME_ORDER already updated")
    else:
        print("[EnemySpawner] WARNING: order_old not found")

    with open(ENEMYSPAWNER_PATH, "w", encoding="utf-8") as f:
        f.write(content)

def update_game():
    with open(GAME_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. BIOMES
    biomes_old = 'const BIOMES: Array = ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "cryo", "reacteur", "ruche", "citadelle"]'
    biomes_new = 'const BIOMES: Array = ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "cryo", "reacteur", "ruche", "citadelle", "abyss", "ether", "titans", "orbit", "quantum", "ozone", "prism", "steampunk", "colosseum"]'
    if biomes_old in content:
        content = content.replace(biomes_old, biomes_new)
        print("[Game.gd] BIOMES updated successfully")

    # 2. BIOME_MODS
    mods_anchor = '\t"citadelle": {"label": "FORGE FINALE  —  citadelle orbitale"},\n}'
    mods_new = """\t"citadelle": {"label": "FORGE FINALE  —  citadelle orbitale"},
\t"abyss":     {"label": "CITÉ SUBMERGÉE  —  ruines abyssales", "player_speed_mult": 0.88},
\t"ether":     {"label": "FORÊT D'ÉTHER  —  canopée fongique bioluminescente"},
\t"titans":    {"label": "NÉCROPOLE DES TITANS  —  cimetière d'acier colossal"},
\t"orbit":     {"label": "CHAMP ORBITAL  —  gravité zéro & débris spatiaux", "player_speed_mult": 1.12, "player_proj_speed": 1.25},
\t"quantum":   {"label": "ARCHIVES QUANTIQUES  —  matrice de données & réfractions"},
\t"ozone":     {"label": "FAILLE D'OZONE  —  orage ionique perpétuel"},
\t"prism":     {"label": "ABÎME PRISMATIQUE  —  cavernes de quartz réflectif"},
\t"steampunk": {"label": "BASTION VAPEUR  —  usine victorienne d'airain & de laiton"},
\t"colosseum": {"label": "COLISÉE VIRTUEL  —  arène tactique de calibrage militaire"},
}"""
    if mods_anchor in content:
        content = content.replace(mods_anchor, mods_new)
        print("[Game.gd] BIOME_MODS updated successfully")

    # 3. CUT_LINES
    cut_anchor = '\t"citadelle": {"in": "La citadelle orbitale tourne encore. Le vide n\'attend personne.", "out": "La forge se refroidit. Le silence a un poids, ici."},\n}'
    cut_new = """\t"citadelle": {"in": "La citadelle orbitale tourne encore. Le vide n'attend personne.", "out": "La forge se refroidit. Le silence a un poids, ici."},
\t"abyss":     {"in": "La pression des abysses broie les coques. Les néons bleus percent l'obscurité.", "out": "L'océan s'apaise. Les secrets engloutis demeurent."},
\t"ether":     {"in": "Des spores incandescentes flottent dans l'air lourd. La forêt observe chaque pas.", "out": "La brume d'éther se disperse sous vos tirs."},
\t"titans":    {"in": "Des carcasses d'automates géants dorment sous la rouille. Quelque chose veille encore.", "out": "Les colosses de fer s'effondrent enfin dans le silence."},
\t"orbit":     {"in": "La station est en morceaux. Le silence de l'espace est brisé par les arcs IEM.", "out": "L'orbite est nettoyée. Cap vers l'infini."},
\t"quantum":   {"in": "Les serveurs d'obsidienne vibrent de code pur. La matrice calcule votre fin.", "out": "Les algorithmes s'éteignent. Les données sont purgées."},
\t"ozone":     {"in": "La foudre déchire le ciel sans fin. L'air sent l'ozone et le plasma brûlé.", "out": "L'orage s'éloigne. La terre ionisée fume encore."},
\t"prism":     {"in": "Les cristaux démultiplient chaque reflet et chaque tir. La lumière est une arme.", "out": "Les géodes scintillent doucement dans le calme retrouvé."},
\t"steampunk": {"in": "Le grondement des pistons résonne dans la vapeur brûlante. L'industrie ne dort jamais.", "out": "Les cheminées cessent de fumer. La machinerie est vaincue."},
\t"colosseum": {"in": "Les projecteurs de l'arène s'allument. L'épreuve suprême commence.", "out": "Victoire écrasante. Le protocole d'exercice est validé."},
}"""
    if cut_anchor in content:
        content = content.replace(cut_anchor, cut_new)
        print("[Game.gd] CUT_LINES updated successfully")

    # 4. MAP_PHASE_NAMES
    phase_anchor = '\t"citadelle": ["Pont Orbital", "Anneau de Gravite", "Chambre de la Forge"],\n}'
    phase_new = """\t"citadelle": ["Pont Orbital", "Anneau de Gravite", "Chambre de la Forge"],
\t"abyss":     ["Quais Immergés", "Faille Abyssale", "Nécropole Sous-Marine"],
\t"ether":     ["Sous-Bois Toxique", "Canopée Luminescente", "Cœur de Mycélium"],
\t"titans":    ["Fosse des Châssis", "Chantier des Cuirassés", "Trône du Roi d'Acier"],
\t"orbit":     ["Sas Dépressurisé", "Champ de Panneaux", "Noyau de Propulsion"],
\t"quantum":   ["Portail Vectoriel", "Couloirs de Monolithes", "Sanctuaire du Noyau"],
\t"ozone":     ["Plaine des Fulgurites", "Pylônes Parafoudres", "Œil de la Tempête"],
\t"prism":     ["Galerie de Silice", "Forêt de Calcite", "Chambre Réfringente"],
\t"steampunk": ["Fonderie de Cuivre", "Salle des Soupapes", "Beffroi d'Horlogerie"],
\t"colosseum": ["Gradins Blindés", "Fosse d'Échauffement", "Noyau des Champions"],
}"""
    if phase_anchor in content:
        content = content.replace(phase_anchor, phase_new)
        print("[Game.gd] MAP_PHASE_NAMES updated successfully")

    with open(GAME_PATH, "w", encoding="utf-8") as f:
        f.write(content)

def update_palette():
    with open(PALETTE_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    pal_anchor = '\t"ruines":    Color(0.95, 0.88, 0.80),\n}'
    pal_new = """\t"ruines":    Color(0.95, 0.88, 0.80),
\t"abyss":     Color(0.65, 0.95, 1.20),
\t"ether":     Color(0.85, 0.65, 1.15),
\t"titans":    Color(1.15, 0.85, 0.65),
\t"orbit":     Color(0.80, 0.95, 1.15),
\t"quantum":   Color(1.10, 1.05, 0.70),
\t"ozone":     Color(1.10, 0.70, 1.15),
\t"prism":     Color(0.95, 1.10, 1.15),
\t"steampunk": Color(1.15, 0.90, 0.70),
\t"colosseum": Color(0.90, 1.05, 1.10),
}"""
    if pal_anchor in content:
        content = content.replace(pal_anchor, pal_new)
        print("[Palette.gd] BIOME_TINT updated successfully")
    elif '"abyss":' in content:
        print("[Palette.gd] already updated")
    else:
        print("[Palette.gd] WARNING: pal_anchor not found")

    with open(PALETTE_PATH, "w", encoding="utf-8") as f:
        f.write(content)

def update_audio():
    with open(AUDIO_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    aud_anchor = '\t"citadelle": "spaceship",\n}'
    aud_new = """\t"citadelle": "spaceship",
\t"abyss": "swamp",
\t"ether": "jungle",
\t"titans": "desert",
\t"orbit": "spaceship",
\t"quantum": "tech",
\t"ozone": "volcanic",
\t"prism": "ice",
\t"steampunk": "tech",
\t"colosseum": "spaceship",
}"""
    if aud_anchor in content:
        content = content.replace(aud_anchor, aud_new)
        print("[Audio.gd] MUSIC_FALLBACK updated successfully")
    elif '"abyss":' in content:
        print("[Audio.gd] already updated")
    else:
        print("[Audio.gd] WARNING: aud_anchor not found")

    with open(AUDIO_PATH, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    print("=== REGISTERING ALL 9 BIOMES ACROSS ENGINE ===")
    update_propscatter()
    update_enemyspawner()
    update_game()
    update_palette()
    update_audio()
    print("=== REGISTRATION COMPLETE ===")
