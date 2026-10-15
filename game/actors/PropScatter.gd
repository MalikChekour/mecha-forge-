extends Node2D
class_name PropScatter
const DwellZone = preload("res://actors/DwellZone.gd")   # voir la note dans Player.gd
## Scatters the Gemini decor sprites across the arena, coherently per biome. Every prop is a
## StaticBody2D (blocks the player; enemies steer around it via Game.cover_list). Some crates are
## DESTRUCTIBLE and drop a skill bonus; the rest are indestructible obstacles.
##
## STREAMING: the arena is unbounded, so decor is generated in CHUNKS around the player and
## recycled behind them -> the whole map is decorated, not just the start area. Each chunk's
## layout is seeded from its coordinates, so leaving and coming back gives the same scenery.

var game: Node
var biome: String = "tech"

# Sized against the CAMERA, not guessed: the view is 1280x720 world units (zoom 1), so the
# player never sees past ~840 units even on an ultrawide. LOAD_R=1 guarantees a full CHUNK
# (1000 u) of decor in every direction — covers the view with margin. The old 900/LOAD_R=2 kept
# 50 props alive over 22x the visible area: 50 sprites+shadows+colliders+lights for nothing,
# and every one of 220 enemies rescanned all of them each physics frame.
const CHUNK: float = 1000.0        # world units per chunk
# 04/10, pop-in/pop-out signale par le patron (mode defilement infini, BOUNDED=false, le mode en
# prod) : la camera peut voir jusqu'a ~viewport/zoom unites de monde (zoom descend a 0.4 sur petit
# ecran -> jusqu'a 2.5x la largeur de viewport visible), largement plus que la frontiere de
# dechargement a LOAD_R=1 (zone 3x3 = 3000 unites, frontiere reelle a 1000-2000 unites du joueur
# selon sa position dans son chunk). Un decor pouvait donc disparaitre/apparaitre a l'ecran, pas
# hors champ. LOAD_R=2 (zone 5x5 = 5000 unites, frontiere a 1500-3000 unites) pousse la frontiere
# bien au-dela du champ visible dans les cas realistes - cout memoire/CPU negligeable (jusqu'a 75
# props simultanes au lieu de 27, aucune boucle par-ennemi sur _chunks, seul cover_list l'est et
# reste borne separement par COVER_R).
const LOAD_R: int = 2              # chunks kept alive around the player (5x5 -> jusqu'a 75 props)
const PER_CHUNK: int = 2           # props per chunk (density 2.0 per million units^2)
const MARGIN: float = 170.0        # inset from chunk edges >= max gap -> no cross-border overlap
const CLEAR_R: float = 340.0       # never drop a prop on top of the player
# props that threaten the player — capped at one per chunk so you meet them at a readable cadence
const HAZARDS: Array = [
	"generateur", "antenne", "conduit", "tourelle", "capaciteur", "baril", "emetteur",
	"bras_presseur", "surchauffe_sol", "zone_chargement",
	"tech_soudeuse", "tech_portique_laser",
	"desert_miroir_solaire", "desert_generateur_tempete", "desert_ver_foreur", "desert_fumerolle_vapeur",
	"jungle_mortier_plante", "jungle_liane_fouet", "jungle_arbre_ruche", "jungle_fruit_grenade",
	"volcanic_mortier_scories", "volcanic_event_magma", "volcanic_marteau_pilon", "volcanic_creuset_basculant", "volcanic_soufflerie_braises",
	"swamp_tourelle_dca", "swamp_vanne_crue", "swamp_bouee_mine", "swamp_lampadaire_phare",
	"cryo_canon_azote", "cryo_condenseur_givre", "jet_de_cryo", "pic_de_glace",
	"reacteur_canon_particules", "reacteur_bobine_tesla", "grille_ventilation", "zone_alternante", "pulse_energie",
	"ruche_organe_acide", "ruche_pondoir", "ruche_vessie_explosive", "tentacule_emergence",
	"citadelle_lanceur_guide", "citadelle_relais_satellite", "emetteur_laser_rotatif", "zone_depressurisation"
]

var _chunks: Dictionary = {}       # Vector2i -> Array[Prop]  (ALL chunks, placed once, never freed)
var _last_cell: Vector2i = Vector2i(9999999, 9999999)
var arena_half: float = 0.0        # set by Game: the bounded arena half-size. 0 = legacy streaming.
const COVER_R: int = 1             # chunks around the player kept in cover_list (enemy steering)

# DESTRUCTIBILITY RULE (patron):
#   * NATURE is scenery you cannot break — rock, tree, plant, roots, ice, lava, arch, mushroom,
#     crystals. It is there to shape the arena, not to farm. ("nature": true)
#   * EVERYTHING MAN-MADE / ROBOT DEBRIS breaks — easily, but not for free (HP band below) — and
#     leaves a drop (see DROPS): xp, scrap, health, overdrive charge, a competence, or a laugh.
#   * The mecha CARCASS is the exception: it is not loot, it wakes a guardian (see "awaken").
# HP band: crates 38-50 | gear 70-90 | wrecks 110-140 | structures 180-220.
# key -> f(ile g<n>), hp, sz(on-screen height px), destruct, nature, skill(chance the crate is a
# gold competence cache), glow, boom(fuel barrel), shoot*(hostile turret), awaken(carcass)
const DECOR: Dictionary = {
	# --- fuel barrels: get close and they arm, then blow up (see BOOM_* in Prop) ---
	"baril":      {"f": "g20", "hp": 40.0,  "sz": 118.0, "destruct": true,  "skill": 0.30, "boom": true, "glow": "orange"},
	"caisses":    {"f": "g21", "hp": 38.0,  "sz": 120.0, "destruct": true,  "skill": 0.50},
	# ARC PYLON: zaps the nearest enemies with lightning, and blows an EMP shockwave when destroyed.
	# Neutral-helpful — lead the horde past it and it thins them; break it for a burst. Tougher HP.
	"generateur": {"f": "g22", "hp": 170.0, "sz": 175.0, "destruct": true, "glow": "cyan",
	               "arc": true, "arc_cd": 1.5, "arc_dmg": 22.0, "arc_r": 300.0},
	# BEACON: spawns enemies until destroyed -> a PRIORITY target. It makes standing still costly
	# and pushing in to silence it rewarding (the aggression the game was missing). Tougher HP so
	# killing it is a real commitment, not a stray shot.
	"antenne":    {"f": "g23", "hp": 220.0, "sz": 190.0, "destruct": true, "glow": "orange",
	               "beacon": true, "beacon_cd": 3.4, "beacon_kind": "drone"},
	# SLOW FIELD: a persistent zone that bogs down the player AND the horde. A trap AND a tool —
	# lead the swarm into it and hold the edge. Destroy it (low HP) to clear the zone.
	"conduit":    {"f": "g24", "hp": 90.0,  "sz": 145.0, "destruct": true, "glow": "cyan",
	               "slow": true, "slow_r": 200.0, "slow_mult": 0.5},
	# EMETTEUR — enemy REPAIR node: heals nearby foes over time, so it's a priority target (green glow
	# to read as "healing", distinct from the magenta beam capaciteur that shares this sprite).
	"emetteur":   {"f": "g25", "hp": 90.0,  "sz": 148.0, "destruct": true,  "glow": "green",
	               "aura": "heal", "aura_r": 260.0, "aura_p1": 5.0},
	# EPAVE — a DORMANT war robot: walk close and it wakes into a live enemy (ambush). Shoot it first
	# to kill it in its sleep. (awaken hook already handled in _process.)
	"epave":      {"f": "g26", "hp": 130.0, "sz": 215.0, "destruct": true, "awaken": "brute"},
	# Leftover war machine: still online and hostile, and DESTRUCTIBLE so you can silence it.
	# Its cannon is BAKED into the 3/4 art and cannot rotate (rotating a 3/4 head in 2D would
	# tip it onto its back). So it behaves like a fixed emplacement gun: it only fires ALONG its
	# real barrel axis, and only when you walk into that arc — the shot always matches the art.
	#   aim  = barrel axis in the art, degrees (measured off the sprite: down-left)
	#   arc  = half-angle of the firing cone
	#   muzzle = barrel tip, local px at the texture's native size (centered origin)
	"tourelle":   {"f": "g27", "hp": 140.0, "sz": 160.0, "destruct": true, "glow": "orange",
	               "shoot": 470.0, "shoot_cd": 1.7, "shoot_dmg": 8.0,
	               "aim": 140.0, "arc": 30.0, "muzzle": [-162.5, 117.0]},
	"container":  {"f": "g28", "hp": 45.0,  "sz": 185.0, "destruct": true,  "skill": 0.55},
	# CAPACITEUR — the arena's neutral hazard. Sweeps a beam along a FIXED cardinal axis on a
	# FIXED 4.4s cycle: predictable on purpose, so it can be learned and then exploited. It hurts
	# the player AND the horde, and hurts the horde ~4x more — that ratio is what turns it from a
	# tax into a weapon (lead the swarm across the line, strafe out, let it clear the field).
	# It is the answer to "the mech can retreat forever for free": dodging it demands a LATERAL
	# move, which breaks a straight-line retreat and lets the horde close.
	# Destructible (220 HP) because every hazard must have counterplay.
	"capaciteur": {"f": "g25", "hp": 220.0, "sz": 140.0, "destruct": true, "glow": "magenta",
	               "beam": true, "beam_dmg": 45.0, "beam_dmg_enemy": 170.0},
	# --- NATURE: indestructible scenery ---
	"rocher":     {"f": "g29", "hp": 170.0, "sz": 175.0, "nature": true},
	# CRISTAUX — shatters into damaging shards on destruction (+ a little Overdrive). Break it in a crowd.
	"cristaux":   {"f": "g30", "hp": 70.0,  "sz": 125.0, "nature": true, "destruct": true, "glow": "cyan", "shatter": true},
	"arbre":      {"f": "g31", "hp": 70.0,  "sz": 178.0, "nature": true},
	# PLANTE — toxic SPORE cloud: poisons + slows the player AND the horde in a radius.
	"plante":     {"f": "g32", "hp": 55.0,  "sz": 115.0, "nature": true, "destruct": true, "glow": "green",
	               "aura": "spore", "aura_r": 150.0, "aura_p1": 7.0, "aura_p2": 0.7},
	# GLACE — FROST field: strongly slows any enemy nearby (a tactical tool — herd the swarm into it).
	"glace":      {"f": "g33", "hp": 70.0,  "sz": 150.0, "nature": true, "destruct": true, "glow": "cyan",
	               "aura": "frost", "aura_r": 170.0, "aura_p1": 0.4},
	# arche (catalogue no 16) — GARDEE, rendue solide : collider elargi (block 0.46 au lieu de 0.30)
	# pour qu'on ne passe plus / ne tire plus a travers l'ouverture de l'arche.
	"arche":      {"f": "g34", "hp": 190.0, "sz": 235.0, "nature": true, "block": 0.46},
	# LAVE — a BURNING pool: continuous fire damage to the player AND enemies standing in it.
	"lave":       {"f": "g35", "hp": 150.0, "sz": 145.0, "nature": true, "destruct": true, "glow": "orange",
	               "aura": "burn", "aura_r": 130.0, "aura_p1": 10.0},
	# RACINES — a SNARE: whatever enters (player or foe) is dragged to a crawl (a trap zone).
	"racines":    {"f": "g36", "hp": 95.0,  "sz": 132.0, "nature": true, "destruct": true, "glow": "green",
	               "aura": "snare", "aura_r": 120.0, "aura_p1": 0.35},
	# Catalogue nos 19-35 supprimes (patron) : immeuble(s), vaisseau(x), voiture, gravats, pylone,
	# panneau, barricade, carcasse, lave_geyser, champignon, campement, epave_gel, serveurs, capsule.

	# ===== 27/09, rapports "Gravité faible" / "Quatre cartes inedites" : le jeu ne place pas de
	# SALLES a geometrie fixe (streaming procedural par chunk, voir l'entete du fichier) — la
	# lecture "salle en losange" des rapports ne correspond a rien ici. Meme intention (une
	# decision spatiale locale par prop), reexprimee avec le systeme de decor generique existant
	# (def-driven, comme aura/slow/arc ci-dessus) au lieu d'inventer un systeme de salles. Chassis
	# reutilises (g22/g24 deja en jeu ; g38 etait au catalogue mais JAMAIS reference nulle part).
	"impulsion": {"f": "g24", "hp": 90.0,  "sz": 118.0, "destruct": true, "glow": "cyan",
	              "push": true, "push_cd": 3.2, "push_force": 380.0, "push_r": 260.0},
	"aimant":    {"f": "g22", "hp": 130.0, "sz": 128.0, "destruct": true, "glow": "cyan",
	              "guard": true, "guard_r": 170.0, "guard_cd": 3.5, "guard_force": 300.0},
	"terminal":  {"f": "g38", "hp": 90.0,  "sz": 118.0, "destruct": true, "glow": "cyan",
	              "dwell": true, "dwell_r": 100.0, "dwell_time": 1.2, "dwell_force": 260.0},
	"archives":  {"f": "g23", "hp": 110.0, "sz": 185.0, "destruct": true, "glow": "cyan",
	              "spot": true, "spot_r": 340.0, "spot_boost": 0.55, "spot_hold": 3.0},
	"quai":      {"f": "g28", "hp": 130.0, "sz": 140.0, "nature": true, "block": 0.34,
	              "cycle": true, "cycle_on": 6.0, "cycle_off": 3.0},
	"convoyeur": {"f": "convoyeur_sol", "hp": 150.0, "sz": 150.0, "destruct": true, "glow": "orange",
	              "block": 0.0, "conveyor": true, "conveyor_r": 280.0, "conveyor_speed": 75.0},

	# ===== 30/09, refonte decor "Secteur Tech" (plan "15 maps" - maps 1-3 fusionnees en un seul
	# decor enrichi pour "tech", voir le plan d'implementation). Memes idiomes que ci-dessus. =====
	"convoyeur_sol":      {"f": "convoyeur_sol", "hp": 150.0, "sz": 150.0, "destruct": true, "glow": "orange",
	                       "block": 0.0, "conveyor": true, "conveyor_r": 280.0, "conveyor_speed": 75.0},
	"console_convoyeur":  {"f": "console_convoyeur", "hp": 90.0,  "sz": 118.0, "destruct": true, "glow": "cyan",
	                       "console": true, "console_r": 400.0},
	"bras_presseur":      {"f": "bras_presseur", "hp": 150.0, "sz": 160.0, "destruct": true, "glow": "orange",
	                       "presser": true, "presser_len": 240.0, "presser_dmg": 15.0, "presser_stun": 0.5},
	"piston_hydraulique": {"f": "piston_hydraulique", "hp": 150.0, "sz": 155.0, "nature": true, "block": 0.30,
	                       "cycle": true, "cycle_on": 2.0, "cycle_off": 2.0},
	"vanne_refroidissement": {"f": "vanne_refroidissement", "hp": 90.0, "sz": 118.0, "destruct": true, "glow": "cyan",
	                       "valve": true, "valve_r": 150.0, "valve_cd": 30.0},
	"surchauffe_sol":     {"f": "surchauffe_sol", "hp": 90.0,  "sz": 150.0, "nature": true,
	                       "overheat": true, "overheat_max": 260.0},
	"porte_automatique":  {"f": "porte_automatique", "hp": 150.0, "sz": 185.0, "nature": true, "block": 0.40,
	                       "cycle": true, "cycle_on": 6.0, "cycle_off": 5.0},
	"zone_chargement":    {"f": "zone_chargement", "hp": 90.0,  "sz": 150.0, "destruct": true, "glow": "orange",
	                       "dropzone": true},
	"container_mobile":   {"f": "container_mobile", "hp": 160.0, "sz": 185.0, "destruct": true,
	                       "rail": true, "rail_span": 220.0, "rail_speed": 15.0},

	# ===== Bible des niveaux — Niveau 1 (L'Usine / tech) =====
	"tech_soudeuse":          {"f": "tech_tourelle_soudeuse", "hp": 160.0, "sz": 165.0, "destruct": true, "glow": "cyan",
	                           "welder": true, "sweep_half": 45.0, "fire_dur": 3.0, "idle_dur": 2.0, "welder_dmg": 28.0},
	"tech_portique_laser":    {"f": "tech_emetteur_portique_laser", "hp": 150.0, "sz": 170.0, "destruct": true, "glow": "cyan",
	                           "gantry": true, "gantry_cd": 6.0, "gantry_tell": 1.2, "gantry_len": 240.0, "gantry_dmg": 22.0},
	"tech_bac_composants":    {"f": "tech_butin_bac_composants", "hp": 45.0,  "sz": 125.0, "destruct": true,  "skill": 0.55, "glow": "cyan"},
	"tech_cuve_vapeur":       {"f": "tech_terrain_cuve_vapeur", "hp": 220.0, "sz": 180.0, "nature": true, "block": 0.38},
	"tech_chariot_robot":     {"f": "tech_terrain_chariot_robot", "hp": 140.0, "sz": 125.0, "nature": true, "block": 0.30, "glow": "cyan"},
	"tech_bordure_paroi_usine": {"f": "tech_bordure_paroi_usine", "hp": 260.0, "sz": 220.0, "nature": true, "block": 0.45},

	# ===== Bible des niveaux — Niveau 2 (Terres Calcinées / desert) =====
	"desert_miroir_solaire":      {"f": "desert_tourelle_miroir_solaire", "hp": 160.0, "sz": 165.0, "destruct": true, "glow": "orange",
	                               "solar_mirror": true, "aim": 135.0, "solar_cd": 4.5, "solar_charge": 1.8, "solar_dmg": 32.0, "burn_trail": 3.0},
	"desert_generateur_tempete":  {"f": "desert_emetteur_generateur_tempete", "hp": 180.0, "sz": 190.0, "destruct": true, "glow": "orange",
	                               "storm_gen": true, "storm_cd": 9.0, "storm_dur": 8.0, "storm_speed": 40.0, "storm_dmg": 12.0},
	"desert_malle_survie":        {"f": "desert_butin_malle_survie", "hp": 45.0,  "sz": 125.0, "destruct": true,  "skill": 0.55, "glow": "orange"},
	"desert_fosse_aspiration":    {"f": "desert_inter_fosse_aspiration", "hp": 90.0, "sz": 150.0, "nature": true, "block": 0.0,
	                               "sinkhole": true, "sinkhole_r": 150.0, "sinkhole_pull": 55.0, "sinkhole_slow": 0.5},
	"desert_collecteur_solaire":  {"f": "desert_inter_collecteur_solaire", "hp": 110.0, "sz": 145.0, "destruct": true, "glow": "orange",
	                               "solar_collector": true, "dwell_r": 100.0, "dwell_time": 1.5, "collector_cd": 40.0},
	"desert_projecteur_mirage":   {"f": "desert_inter_projecteur_mirage", "hp": 90.0,  "sz": 135.0, "destruct": true, "glow": "cyan",
	                               "mirage": true, "mirage_cd": 20.0, "mirage_dur": 6.0, "mirage_r": 340.0},
	"desert_ver_foreur":          {"f": "desert_inter_ver_foreur", "hp": 140.0, "sz": 175.0, "destruct": true, "glow": "orange",
	                               "sandworm": true, "sandworm_r": 220.0, "sandworm_tell": 1.0, "sandworm_dmg": 25.0},
	"desert_fumerolle_vapeur":    {"f": "desert_inter_fumerolle_vapeur", "hp": 90.0,  "sz": 125.0, "nature": true, "block": 0.0,
	                               "fumerolle": true, "fumerolle_cd": 5.0, "fumerolle_tell": 1.0, "fumerolle_r": 120.0, "fumerolle_dmg": 15.0, "fumerolle_push": 300.0},
	"desert_char_enfoui":         {"f": "desert_terrain_char_enfoui", "hp": 240.0, "sz": 195.0, "nature": true, "block": 0.40},
	"desert_arche_verre":         {"f": "desert_terrain_arche_verre", "hp": 200.0, "sz": 210.0, "nature": true, "block": 0.42},
	"desert_bordure_mesa":        {"f": "desert_bordure_mesa", "hp": 280.0, "sz": 230.0, "nature": true, "block": 0.45},

	# ===== Bible des niveaux — Niveau 3 (La Ruine Verte / jungle) =====
	"jungle_mortier_plante":      {"f": "jungle_tourelle_mortier_plante", "hp": 160.0, "sz": 170.0, "destruct": true, "glow": "green",
	                               "plant_mortar": true, "mortar_cd": 4.5, "mortar_dmg": 26.0, "mortar_r": 90.0},
	"jungle_liane_fouet":         {"f": "jungle_emetteur_liane_fouet", "hp": 170.0, "sz": 180.0, "destruct": true, "glow": "green",
	                               "whip_vine": true, "whip_cd": 5.0, "whip_dmg": 22.0, "whip_arc": 120.0, "whip_r": 160.0},
	"jungle_cosse_geante":        {"f": "jungle_butin_cosse_geante", "hp": 50.0,  "sz": 130.0, "destruct": true,  "skill": 0.55, "glow": "green"},
	"jungle_fleur_catapulte":     {"f": "jungle_inter_fleur_catapulte", "hp": 90.0, "sz": 135.0, "nature": true, "block": 0.0,
	                               "catapult": true, "catapult_dist": 300.0, "catapult_cd": 3.0},
	"jungle_plante_lasso":        {"f": "jungle_inter_plante_lasso", "hp": 100.0, "sz": 140.0, "destruct": true, "glow": "orange",
	                               "lasso": true, "lasso_snare": 1.5, "lasso_cd": 8.0, "lasso_r": 85.0},
	"jungle_nuee_lucioles":       {"f": "jungle_inter_nuee_lucioles", "hp": 80.0,  "sz": 120.0, "nature": true, "block": 0.0,
	                               "fireflies": true, "heal_dps": 3.0, "firefly_r": 110.0, "firefly_dur": 10.0},
	"jungle_arbre_ruche":         {"f": "jungle_inter_arbre_ruche", "hp": 200.0, "sz": 200.0, "destruct": true, "glow": "orange",
	                               "beacon": 9.0},
	"jungle_fruit_grenade":       {"f": "jungle_inter_fruit_grenade", "hp": 35.0,  "sz": 110.0, "destruct": true, "boom": true, "glow": "orange"},
	"jungle_colonne_racines":     {"f": "jungle_terrain_colonne_racines", "hp": 240.0, "sz": 195.0, "nature": true, "block": 0.40},
	"jungle_statue_mecha":        {"f": "jungle_terrain_statue_mecha", "hp": 300.0, "sz": 220.0, "nature": true, "block": 0.45},
	"jungle_mur_vegetal":         {"f": "jungle_bordure_mur_vegetal", "hp": 280.0, "sz": 230.0, "nature": true, "block": 0.45},

	# ===== Bible des niveaux — Niveau 4 (La Forge / volcanic) =====
	"volcanic_mortier_scories":   {"f": "volcanic_tourelle_mortier_scories", "hp": 170.0, "sz": 175.0, "destruct": true, "glow": "orange",
	                               "slag_mortar": true, "mortar_cd": 5.0, "mortar_dmg": 28.0, "mortar_r": 95.0, "burn_dur": 5.0},
	"volcanic_event_magma":       {"f": "volcanic_emetteur_event_magma", "hp": 160.0, "sz": 160.0, "nature": true, "block": 0.0,
	                               "magma_vent": true, "vent_cd": 4.5, "vent_tell": 1.2, "vent_dmg": 20.0, "vent_r": 110.0},
	"volcanic_lingotiere":        {"f": "volcanic_butin_lingotiere", "hp": 50.0,  "sz": 125.0, "destruct": true,  "skill": 0.55, "glow": "orange"},
	"volcanic_marteau_pilon":     {"f": "volcanic_inter_marteau_pilon", "hp": 250.0, "sz": 200.0, "destruct": true, "glow": "orange",
	                               "power_hammer": true, "hammer_cd": 7.0, "hammer_tell": 1.4, "hammer_dmg": 35.0, "hammer_r": 140.0},
	"volcanic_creuset_basculant": {"f": "volcanic_inter_creuset_basculant", "hp": 180.0, "sz": 180.0, "destruct": true, "glow": "orange",
	                               "crucible": true, "crucible_cd": 6.0, "crucible_tell": 1.2, "crucible_dmg": 24.0, "crucible_len": 260.0},
	"volcanic_bassin_trempe":     {"f": "volcanic_inter_bassin_trempe", "hp": 120.0, "sz": 160.0, "nature": true, "block": 0.0,
	                               "quench_pool": true, "quench_r": 120.0},
	"volcanic_electroaimant":     {"f": "volcanic_inter_electroaimant", "hp": 140.0, "sz": 155.0, "destruct": true, "glow": "cyan",
	                               "scrap_magnet": true, "magnet_r": 450.0},
	"volcanic_soufflerie_braises":{"f": "volcanic_inter_soufflerie_braises", "hp": 110.0, "sz": 140.0, "destruct": true, "glow": "orange",
	                               "ember_bellows": true, "bellows_cd": 5.5, "bellows_tell": 1.0, "bellows_r": 170.0, "bellows_dmg": 18.0},
	"volcanic_cheminee_fonderie": {"f": "volcanic_terrain_cheminee_fonderie", "hp": 260.0, "sz": 190.0, "nature": true, "block": 0.40},
	"volcanic_pont_roulant":      {"f": "volcanic_terrain_pont_roulant", "hp": 280.0, "sz": 215.0, "nature": true, "block": 0.42},
	"volcanic_bordure_basalte":   {"f": "volcanic_bordure_basalte", "hp": 320.0, "sz": 240.0, "nature": true, "block": 0.50},

	# ===== Bible des niveaux — Niveau 5 (La Cité Déchue / swamp) =====
	"swamp_tourelle_dca":         {"f": "swamp_tourelle_dca_toit", "hp": 180.0, "sz": 170.0, "destruct": true, "glow": "orange",
	                               "flak_turret": true, "flak_cd": 5.0, "flak_dmg": 18.0, "flak_r": 110.0},
	"swamp_vanne_crue":           {"f": "swamp_emetteur_vanne_crue", "hp": 170.0, "sz": 170.0, "nature": true, "block": 0.0,
	                               "flood_gate": true, "gate_cd": 6.0, "gate_tell": 1.5, "gate_dmg": 22.0, "gate_len": 400.0, "gate_w": 120.0, "gate_push": 380.0},
	"swamp_coffre_banque":        {"f": "swamp_butin_coffre_banque", "hp": 50.0,  "sz": 125.0, "destruct": true,  "skill": 0.60, "glow": "magenta"},
	"swamp_vanne_barrage":        {"f": "swamp_inter_vanne_barrage", "hp": 150.0, "sz": 160.0, "destruct": true, "glow": "orange",
	                               "drain_valve": true, "drain_r": 130.0, "drain_dur": 10.0, "drain_cd": 25.0},
	"swamp_bouee_mine":           {"f": "swamp_inter_bouee_mine", "hp": 45.0,  "sz": 120.0, "destruct": true, "glow": "magenta",
	                               "floating_mine": true, "mine_trigger_r": 160.0, "mine_dmg": 35.0, "mine_boom_r": 140.0},
	"swamp_lampadaire_phare":     {"f": "swamp_inter_lampadaire_phare", "hp": 130.0, "sz": 180.0, "destruct": true, "glow": "orange",
	                               "searchlight": true, "searchlight_cd": 4.0, "searchlight_r": 280.0},
	"swamp_barricade_vehicules":  {"f": "swamp_inter_barricade_vehicules", "hp": 350.0, "sz": 220.0, "destruct": true, "glow": "orange", "block": 0.45},
	"swamp_brouilleur_radio":     {"f": "swamp_inter_brouilleur_radio", "hp": 160.0, "sz": 190.0, "destruct": true, "glow": "magenta",
	                               "radio_jammer": true, "jammer_r": 300.0},
	"swamp_gratte_ciel":          {"f": "swamp_terrain_gratte_ciel", "hp": 300.0, "sz": 230.0, "nature": true, "block": 0.48},
	"swamp_pont_brise":           {"f": "swamp_terrain_pont_brise", "hp": 280.0, "sz": 210.0, "nature": true, "block": 0.45},
	"swamp_bordure_facades":      {"f": "swamp_bordure_facades", "hp": 320.0, "sz": 240.0, "nature": true, "block": 0.50},

	# ===== 03/10, refonte decor "Zone Cryo" (plan 15 maps, maps 4-6, nouveau biome "cryo").
	# Memes idiomes que le Secteur Tech ci-dessus. Tous ont recu leur art dedie (03/10) sauf
	# brouillard_froid qui reste procedural (g20, aucun art externe necessaire, cf. nuage_spores).
	"plaque_de_glace":    {"f": "plaque_de_glace", "hp": 90.0,  "sz": 140.0, "nature": true, "block": 0.0,
	                       "ice_patch": true, "ice_patch_r": 130.0, "ice_patch_amt": 0.8},
	"capsule_cryogenique": {"f": "capsule_cryogenique", "hp": 60.0, "sz": 130.0, "destruct": true, "glow": "cyan",
	                       "capsule": true},
	"jet_de_cryo":        {"f": "jet_de_cryo", "hp": 90.0,  "sz": 110.0, "destruct": true, "glow": "cyan",
	                       "cryo_jet": true, "cryo_jet_r": 70.0, "cryo_jet_stun": 1.0},
	"brouillard_froid":   {"f": "g20", "hp": 90.0,  "sz": 20.0,  "nature": true, "block": 0.0,
	                       "fog": true, "fog_r": 260.0},
	"radiateur":          {"f": "radiateur", "hp": 90.0, "sz": 118.0, "destruct": true, "glow": "orange",
	                       "defroster": true, "defroster_r": 320.0},
	"pic_de_glace":       {"f": "pic_de_glace", "hp": 110.0, "sz": 120.0, "destruct": true, "glow": "cyan",
	                       "ice_spike": true},
	"borne_thermique":    {"f": "borne_thermique", "hp": 90.0, "sz": 118.0, "destruct": true, "glow": "orange",
	                       "thermal": true, "thermal_r": 150.0},
	"glace_fragile":      {"f": "glace_fragile", "hp": 90.0,  "sz": 130.0, "nature": true, "block": 0.0,
	                       "fragile_ice": true},
	# ===== Bible des niveaux — Niveau 6 (Le Cryo-Laboratoire / cryo) =====
	"cryo_canon_azote":           {"f": "cryo_tourelle_canon_azote", "hp": 180.0, "sz": 170.0, "destruct": true, "glow": "cyan",
	                               "nitrogen_cannon": true, "ncannon_cd": 4.5, "ncannon_dmg": 24.0, "ncannon_r": 100.0},
	"cryo_condenseur_givre":      {"f": "cryo_emetteur_condenseur_givre", "hp": 160.0, "sz": 165.0, "destruct": true, "glow": "cyan",
	                               "frost_condenser": true, "condenser_cd": 6.0, "condenser_r": 250.0},
	"cryo_caisson_echantillons":  {"f": "cryo_butin_caisson_echantillons", "hp": 50.0,  "sz": 125.0, "destruct": true,  "skill": 0.55, "glow": "cyan"},
	"cryo_teleporteur_paire":     {"f": "cryo_inter_teleporteur_paire", "hp": 200.0, "sz": 160.0, "destruct": true, "glow": "cyan",
	                               "teleporter": true, "teleport_cd": 6.0, "teleport_r": 80.0},
	"cryo_mur_glace_regen":       {"f": "cryo_inter_mur_glace_regen", "hp": 150.0, "sz": 170.0, "destruct": true, "glow": "cyan", "block": 0.45,
	                               "regen_ice_wall": true, "regen_time": 10.0},
	"cryo_cuve_stase":            {"f": "cryo_terrain_cuve_stase", "hp": 260.0, "sz": 200.0, "nature": true, "block": 0.42},
	"cryo_serveur_givre":         {"f": "cryo_terrain_serveur_givre", "hp": 280.0, "sz": 190.0, "nature": true, "block": 0.40},
	"cryo_bordure_cloison":       {"f": "cryo_bordure_cloison", "hp": 320.0, "sz": 240.0, "nature": true, "block": 0.50},

	# ===== 03/10, refonte decor "Noyau Instable" (plan 15 maps, maps 7-9, nouveau biome
	# "reacteur"). Memes idiomes que ci-dessus. Les 8 ont leur art final (zone_alternante/
	# pulse_energie integres le 03/10).
	"reacteur_canon_particules":   {"f": "reacteur_tourelle_canon_particules", "hp": 180.0, "sz": 160.0, "destruct": true, "glow": "green",
	                                "particle_cannon": true, "cannon_cd": 4.0, "cannon_dmg": 22.0, "cannon_r": 350.0},
	"reacteur_bobine_tesla":       {"f": "reacteur_emetteur_bobine_tesla", "hp": 200.0, "sz": 150.0, "destruct": true, "glow": "green",
	                                "tesla_coil": true, "tesla_cd": 3.0, "tesla_r": 300.0},
	"reacteur_barre_combustible":  {"f": "reacteur_butin_barre_combustible", "hp": 50.0, "sz": 125.0, "destruct": true, "skill": 0.55, "glow": "green"},
	"reacteur_barre_controle":     {"f": "reacteur_inter_barre_controle", "hp": 200.0, "sz": 160.0, "destruct": true, "glow": "green",
	                                "control_rod": true, "control_rod_r": 120.0},
	"reacteur_cellule_confinement": {"f": "reacteur_inter_cellule_confinement", "hp": 180.0, "sz": 150.0, "destruct": true, "glow": "green",
	                                "containment_cell": true, "containment_r": 220.0, "containment_cd": 25.0},
	"reacteur_turbine_hs":         {"f": "reacteur_terrain_turbine_hs", "hp": 300.0, "sz": 200.0, "nature": true, "block": 0.45},
	"reacteur_cuve_plomb":         {"f": "reacteur_terrain_cuve_plomb", "hp": 320.0, "sz": 190.0, "nature": true, "block": 0.48},
	"reacteur_bordure_blindage":   {"f": "reacteur_bordure_blindage", "hp": 350.0, "sz": 240.0, "nature": true, "block": 0.50},
	"bassin_toxique":     {"f": "bassin_liquide_toxique", "hp": 90.0, "sz": 180.0, "nature": true, "block": 0.0,
	                       "toxic_pool": true, "toxic_r": 150.0, "toxic_dps": 6.0},
	"vanne_drainage":     {"f": "vanne_drainage", "hp": 90.0, "sz": 118.0, "destruct": true, "glow": "cyan",
	                       "drain": true, "drain_r": 250.0},
	"poche_de_vent":      {"f": "turbine_geante", "hp": 130.0, "sz": 205.0, "destruct": true, "glow": "orange",
	                       "wind": true, "wind_r": 220.0, "wind_speed": 50.0},
	"console_vent":       {"f": "console_controle_vent", "hp": 90.0, "sz": 118.0, "destruct": true, "glow": "cyan",
	                       "wind_console": true, "wind_console_r": 400.0},
	"grille_ventilation": {"f": "grille_ventilation", "hp": 90.0, "sz": 110.0, "nature": true, "block": 0.0,
	                       "vent_grate": true},
	"zone_alternante":    {"f": "zone_alternante", "hp": 110.0, "sz": 150.0, "destruct": true, "glow": "green",
	                       "alt_zone": true, "alt_zone_r": 100.0, "alt_zone_dps": 10.0, "cycle_on": 5.0, "cycle_off": 5.0,
	                       "block": 0.0},
	"cristal_instable":   {"f": "cristal_energie_instable", "hp": 0.0, "sz": 125.0, "nature": true, "block": 0.0,
	                       "unstable_crystal": true},
	"pulse_energie":      {"f": "pulse_energie", "hp": 130.0, "sz": 140.0, "destruct": true, "glow": "green",
	                       "energy_pulse": true},

	# ===== 03/10, refonte decor "Biomecanique" (plan 15 maps, maps 10-12, nouveau biome
	# "ruche"). Memes idiomes que ci-dessus. 4/6 ont deja leur art final ; nuage_spores est
	# procedural comme brouillard_froid (aucun art externe necessaire) ; residu_biomecanique
	# (ajoute 03/10, separee de sol_collant qui etait a tort fusionnee avec elle) en placeholder.
	"ruche_organe_acide":          {"f": "ruche_tourelle_organe_acide", "hp": 180.0, "sz": 150.0, "destruct": true, "glow": "green",
	                                "acid_turret": true, "acid_cd": 4.5, "acid_r": 320.0},
	"ruche_pondoir":               {"f": "ruche_emetteur_pondoir", "hp": 220.0, "sz": 165.0, "destruct": true, "glow": "magenta",
	                                "spawner_egg": true, "spawn_cd": 5.0},
	"ruche_bulbe_nutritif":        {"f": "ruche_butin_bulbe_nutritif", "hp": 50.0, "sz": 125.0, "destruct": true, "skill": 0.55, "glow": "cyan"},
	"ruche_veine_pulsatile":       {"f": "ruche_inter_veine_pulsatile", "hp": 150.0, "sz": 160.0, "destruct": true, "glow": "magenta",
	                                "vein_pulse": true, "vein_r": 250.0, "vein_force": 180.0},
	"ruche_vessie_explosive":      {"f": "ruche_inter_vessie_explosive", "hp": 1.0, "sz": 130.0, "destruct": true, "glow": "orange",
	                                "acid_bladder": true, "barrel": true},
	"ruche_colonne_os":            {"f": "ruche_terrain_colonne_os", "hp": 280.0, "sz": 190.0, "nature": true, "block": 0.42},
	"ruche_champignon_geant":      {"f": "ruche_terrain_champignon_geant", "hp": 260.0, "sz": 180.0, "nature": true, "block": 0.40},
	"ruche_bordure_paroi_chair":   {"f": "ruche_bordure_paroi_chair", "hp": 320.0, "sz": 240.0, "nature": true, "block": 0.50},
	"cocon":              {"f": "cocon", "hp": 60.0, "sz": 155.0, "destruct": true, "glow": "cyan",
	                       "capsule": true},
	"residu_biomecanique": {"f": "g33", "hp": 90.0, "sz": 140.0, "nature": true, "block": 0.0,
	                       "bio_residue": true, "bio_residue_r": 150.0, "bio_residue_slow": 0.6, "bio_residue_pull": 40.0},
	"sol_collant":        {"f": "sol_collant", "hp": 90.0, "sz": 140.0, "nature": true, "block": 0.0,
	                       "sticky": true, "sticky_r": 150.0, "sticky_mult": 0.45},
	"tentacule_emergence": {"f": "tentacule_emergence", "hp": 110.0, "sz": 155.0, "destruct": true, "glow": "green",
	                       "tentacle": true},
	"nuage_spores":       {"f": "g20", "hp": 90.0, "sz": 20.0, "nature": true, "block": 0.0,
	                       "spore_cloud": true, "spore_r": 220.0, "spore_dps": 5.0},
	"plante_lumineuse":   {"f": "plante_lumineuse", "hp": 60.0, "sz": 115.0, "destruct": true, "glow": "green",
	                       "light_plant": true, "light_plant_r": 300.0},

	# ===== 03/10, refonte decor "Forge Finale" (plan 15 maps, maps 13-15, nouveau biome
	# "citadelle"). Memes idiomes que ci-dessus. Les 6 ont leur art final (zone_depressurisation/
	# zone_push_pull integres le 03/10).
	"citadelle_lanceur_guide":     {"f": "citadelle_tourelle_lanceur_guide", "hp": 220.0, "sz": 165.0, "destruct": true, "glow": "orange",
	                                "guided_launcher": true, "launcher_cd": 5.0, "launcher_dmg": 25.0, "launcher_r": 400.0},
	"citadelle_relais_satellite":  {"f": "citadelle_emetteur_relais_satellite", "hp": 200.0, "sz": 155.0, "destruct": true, "glow": "cyan",
	                                "satellite_relay": true, "relay_cd": 6.0, "relay_r": 350.0},
	"citadelle_module_ravitaillement": {"f": "citadelle_butin_module_ravitaillement", "hp": 60.0, "sz": 130.0, "destruct": true, "skill": 0.60, "glow": "gold"},
	"citadelle_sas_pressurise":    {"f": "citadelle_inter_sas_pressurise", "hp": 200.0, "sz": 170.0, "nature": true, "block": 0.40,
	                                "airlock": true, "airlock_cd": 6.0},
	"citadelle_dome_bouclier":     {"f": "citadelle_inter_dome_bouclier", "hp": 200.0, "sz": 160.0, "destruct": true, "glow": "cyan",
	                                "dome_shield": true, "dome_r": 200.0, "dome_cd": 20.0},
	"citadelle_grappin_magnetique": {"f": "citadelle_inter_grappin_magnetique", "hp": 160.0, "sz": 150.0, "destruct": true, "glow": "cyan",
	                                "magnetic_hook": true, "hook_r": 250.0, "hook_force": 120.0, "hook_cd": 4.0},
	"citadelle_panneau_solaire":   {"f": "citadelle_terrain_panneau_solaire", "hp": 260.0, "sz": 190.0, "nature": true, "block": 0.40},
	"citadelle_reacteur_orbital":  {"f": "citadelle_terrain_reacteur_orbital", "hp": 320.0, "sz": 220.0, "nature": true, "block": 0.48},
	"citadelle_bordure_coque":     {"f": "citadelle_bordure_coque", "hp": 380.0, "sz": 240.0, "nature": true, "block": 0.50},
	"porte_securite_orbitale": {"f": "porte_securite_orbitale", "hp": 170.0, "sz": 185.0, "nature": true, "block": 0.40,
	                       "cycle": true, "cycle_on": 6.0, "cycle_off": 5.0},
	"zone_depressurisation": {"f": "zone_depressurisation", "hp": 110.0, "sz": 150.0, "destruct": true, "glow": "orange",
	                       "depress": true, "depress_r": 200.0, "depress_force": 220.0},
	"zone_push_pull":     {"f": "zone_push_pull", "hp": 110.0, "sz": 150.0, "destruct": true, "glow": "cyan",
	                       "grav_zone": true, "grav_r": 180.0, "grav_force": 60.0},
	"emetteur_laser_rotatif": {"f": "emetteur_laser_rotatif", "hp": 170.0, "sz": 150.0, "destruct": true, "glow": "orange",
	                       "rot_laser": true},
	"pilier_energie":     {"f": "pilier_energie", "hp": 260.0, "sz": 255.0, "destruct": true, "glow": "orange",
	                       "pillar": true},
	"segment_mur_modulaire": {"f": "segment_mur_modulaire", "hp": 220.0, "sz": 170.0, "nature": true, "block": 0.40,
	                       "cycle": true, "cycle_on": 10.0, "cycle_off": 8.0},
}

# PANCARTES (14/10, patron : « certains decors n'ont aucun effet visible, on ne sait pas a quoi
# ils servent ») : chaque decor qui FAIT quelque chose affiche, la PREMIERE fois qu'on le croise
# (toutes parties confondues, memorise dans SaveManager.data["seen_props"]), une pancarte avec son
# nom, son effet et — quand il y en a une — l'ACTION a faire pour l'activer. kind -> [nom, texte,
# teinte]. Un decor absent d'ici (rocher, arbre...) est du simple terrain : pas de pancarte.
const INFO: Dictionary = {
	"baril": ["Baril explosif", "S'arme quand vous approchez, puis explose. Tirez dessus de loin pour blesser la horde.", "orange"],
	"caisses": ["Caisse", "Détruisez-la : XP, ferraille, soin ou compétence (lueur dorée = compétence garantie).", "gold"],
	"container": ["Container", "Détruisez-le : XP, ferraille, soin ou compétence (lueur dorée = compétence garantie).", "gold"],
	"generateur": ["Pylône à arc", "Foudroie les ennemis proches. Détruit, il libère une onde EMP.", "cyan"],
	"antenne": ["Balise d'invasion", "Fait apparaître des drones tant qu'elle est debout : détruisez-la en priorité.", "orange"],
	"conduit": ["Champ ralentisseur", "Ralentit vous ET la horde dans sa zone. Détruisez-le pour l'éteindre.", "cyan"],
	"emetteur": ["Nœud de réparation", "Soigne les ennemis proches : cible prioritaire.", "green"],
	"epave": ["Épave dormante", "Un robot s'y réveille si vous approchez. Détruisez-la de loin pour l'achever dans son sommeil.", "orange"],
	"tourelle": ["Tourelle ennemie", "Tire un rayon selon un axe fixe. Affaiblie, elle est piratée et foudroie les ennemis.", "orange"],
	"capaciteur": ["Capaciteur", "Balaie un rayon à cycle fixe qui blesse vous ET la horde (bien plus la horde). Esquivez latéralement.", "magenta"],
	"cristaux": ["Cristaux", "Brisés, ils projettent des éclats qui blessent la horde.", "cyan"],
	"plante": ["Plante toxique", "Nuage de spores : poison et ralentissement autour d'elle, pour vous comme pour la horde.", "green"],
	"glace": ["Bloc de glace", "Ralentit fortement les ennemis proches : attirez la horde à côté.", "cyan"],
	"lave": ["Flaque de lave", "Brûle tout ce qui s'y tient, vous compris.", "orange"],
	"racines": ["Racines", "Piège : ralentit à l'extrême ce qui entre dans leur zone.", "green"],
	"impulsion": ["Pulseur", "Repousse vous ET les ennemis proches à intervalle régulier.", "cyan"],
	"aimant": ["Aimant de garde", "Tant que vous restez près de lui, il repousse les ennemis.", "cyan"],
	"terminal": ["Terminal de délestage", "RESTEZ dans son cercle ~1 s : onde de choc qui repousse les ennemis proches.", "cyan"],
	"archives": ["Archives-machines", "Marque l'ennemi le plus proche : vos tirs le visent en priorité.", "cyan"],
	"quai": ["Caisse-écran", "Apparaît et disparaît : bloque le passage par intervalles.", "orange"],
	"convoyeur": ["Tapis roulant", "Pousse les ennemis proches sur son axe.", "orange"],
	"convoyeur_sol": ["Tapis ralentisseur", "Vous ralentit et vous entraîne dans le sens des chevrons, vous et la horde. Une console voisine l'arrête 8 s.", "orange"],
	"console_convoyeur": ["Console de tapis", "RESTEZ dans son cercle : arrête les tapis proches pendant 8 s.", "cyan"],
	"bras_presseur": ["Bras presseur", "Écrase une ligne au sol à intervalle. Quittez la bande marquée avant l'impact.", "orange"],
	"piston_hydraulique": ["Piston hydraulique", "Barrière qui sort et rentre toutes les 2 s : passez quand elle est rentrée.", "orange"],
	"vanne_refroidissement": ["Vanne de refroidissement", "RESTEZ dans son cercle : soigne 20 % de vos PV et éteint les sols en surchauffe proches (recharge 30 s).", "cyan"],
	"surchauffe_sol": ["Sol en surchauffe", "Zone de feu qui grandit par à-coups : ne restez pas dessus.", "orange"],
	"porte_automatique": ["Porte automatique", "S'ouvre et se ferme à intervalle : franchissez-la quand elle est ouverte.", "orange"],
	"zone_chargement": ["Zone de chargement", "Marque des impacts au sol à intervalle : sortez des cercles.", "orange"],
	"container_mobile": ["Container mobile", "Glisse sur un rail : obstacle mouvant, ne vous faites pas coincer.", "orange"],
	"tech_soudeuse": ["Soudeuse-sentinelle", "Balaie un arc de soudure électrique sur ±45° pendant 3 s puis se refroidit. Restez hors de son arc !", "cyan"],
	"tech_portique_laser": ["Portique laser", "Une tête laser glisse et trace une ligne de découpe au sol toutes les 6 s (marquée 1,2 s avant). Évitez la ligne !", "orange"],
	"tech_bac_composants": ["Bac de composants", "Détruisez-le : pièces, XP, ferraille, soin ou compétence.", "gold"],
	"tech_cuve_vapeur": ["Cuve à vapeur", "Réservoir sous pression solide : bloque les tirs et les trajectoires.", "cyan"],
	"tech_chariot_robot": ["Chariot-robot", "Châssis d'usine éteint servant d'obstacle et de couverture basse.", "cyan"],
	"desert_miroir_solaire": ["Canon à miroir solaire", "Charge 1,8 s puis tire un rayon qui vitrifie le sol pendant 3 s : restez hors du sillon.", "orange"],
	"desert_generateur_tempete": ["Générateur de tempête", "Libère périodiquement un tourbillon de sable qui pousse et blesse pendant 8 s.", "orange"],
	"desert_malle_survie": ["Malle ensablée", "Détruisez-la : XP, ferraille, soin ou compétence (lueur dorée = compétence garantie).", "gold"],
	"desert_fosse_aspiration": ["Fosse d'aspiration", "Attire vers son centre et ralentit tout ce qui entre dans ses sables mouvants.", "orange"],
	"desert_collecteur_solaire": ["Collecteur solaire", "RESTEZ 1,5 s dedans : recharge +25 % de votre jauge de surcharge (recharge 40 s).", "gold"],
	"desert_projecteur_mirage": ["Projecteur de mirage", "RESTEZ dedans : projette un leurre holographique qui détourne la horde pendant 6 s.", "cyan"],
	"desert_ver_foreur": ["Ver foreur enfoui", "Épave piégée : si vous approchez, le ver jaillit du sol. Écartez-vous de la zone !", "orange"],
	"desert_fumerolle_vapeur": ["Fumerolle surchauffée", "Geyser brûlant à intervalle régulier : repousse et inflige des dégâts.", "orange"],
	"desert_char_enfoui": ["Char enfoui", "Carcasse blindée ensevelie dans les dunes : couverture lourde arrêtant les tirs.", "orange"],
	"desert_arche_verre": ["Arche de verre fondu", "Formation naturelle de verre fondu translucide : obstacle rocheux solide.", "cyan"],
	# ===== Bible des niveaux — Niveau 3 (jungle) =====
	"jungle_mortier_plante": ["Plante-mortier", "Tire des cosses de graines en cloche par-dessus les obstacles : explose en nuage d'épines.", "green"],
	"jungle_liane_fouet": ["Liane-fouet épineuse", "Fouette violemment un arc de 120 degrés autour de sa base : surveillez le sol.", "green"],
	"jungle_cosse_geante": ["Cosse de graines géante", "Détruisez-la : XP, ferraille, soin ou compétence (lueur dorée = compétence garantie).", "gold"],
	"jungle_fleur_catapulte": ["Fleur-catapulte", "Marchez dessus pour être propulsé de 300 unités dans votre direction de déplacement.", "green"],
	"jungle_plante_lasso": ["Plante-lasso", "Piège naturel : se referme sur la première cible qui entre et l'immobilise pendant 1,5 s.", "orange"],
	"jungle_nuee_lucioles": ["Nuée de lucioles", "RESTEZ dans la lueur : régénère vos PV (+3 PV/s) pendant 10 s avant de s'épuiser.", "gold"],
	"jungle_arbre_ruche": ["Arbre-balise", "Arbre-ruche biomécanique : génère des drones-guêpes tant qu'il n'est pas abattu.", "orange"],
	"jungle_fruit_grenade": ["Fruit-grenade", "Fruit instable : explose après amorçage si vous restez trop près ou s'il est touché.", "orange"],
	"jungle_colonne_racines": ["Colonne envahie", "Vestige de béton armé étranglé par de massives racines végétales : obstacle solide.", "green"],
	"jungle_statue_mecha": ["Statue de mecha envahie", "Carcasse d'un titan antique figée sous la végétation tropicale : couverture lourde.", "green"],
	"jungle_mur_vegetal": ["Mur végétal", "Frontière impénétrable de jungle dense et de ruines enchevêtrées.", "green"],
	# ===== Bible des niveaux — Niveau 4 (volcanic) =====
	"volcanic_mortier_scories": ["Mortier à scories", "Tire des obus de lave en cloche qui laissent une flaque de magma brûlante pendant 5 s.", "orange"],
	"volcanic_event_magma": ["Évent de magma", "Éruption volcanique périodique : jaillissement de lave qui enflamme le sol pendant 3 s.", "orange"],
	"volcanic_lingotiere": ["Lingotière de fonderie", "Détruisez-la : XP, ferraille, soin ou compétence (lueur dorée = compétence garantie).", "gold"],
	"volcanic_marteau_pilon": ["Marteau-pilon géant", "Frappe lourde toutes les 7 s : onde de choc écrasante qui repousse et inflige de lourds dégâts.", "orange"],
	"volcanic_creuset_basculant": ["Creuset basculant", "Bascule périodiquement et déverse une ligne de métal en fusion incandescente.", "orange"],
	"volcanic_bassin_trempe": ["Bassin de trempe", "RESTEZ 1 s dedans : éteint les brûlures et réduit de 50 % les dégâts de feu pendant 8 s.", "cyan"],
	"volcanic_electroaimant": ["Électroaimant de ferrailleur", "Approchez-vous : attire puissamment tous les pickups et gemmes dans un rayon de 450 u.", "cyan"],
	"volcanic_soufflerie_braises": ["Soufflerie à braises", "Rafale brûlante périodique : repousse violemment et applique une brûlure pendant 4 s.", "orange"],
	"volcanic_cheminee_fonderie": ["Cheminée de fonderie", "Cheminée en briques noircies et scories : obstacle solide bloquant tirs et déplacements.", "orange"],
	"volcanic_pont_roulant": ["Pont roulant effondré", "Poutrelle d'acier torsadée et chaînes pendantes : couverture lourde de fonderie.", "orange"],
	"volcanic_bordure_basalte": ["Paroi de basalte", "Muraille infranchissable de colonnes de basalte noir et de veines de lave.", "orange"],
	# ===== Bible des niveaux — Niveau 5 (swamp) =====
	"swamp_tourelle_dca": ["Batterie antiaérienne", "Tire une salve de 4 obus à fusée qui éclatent en anneau de shrapnel dévastateur.", "orange"],
	"swamp_vanne_crue": ["Vanne de crue", "Libère périodiquement une vague torrentielle sur 400 u qui repousse violemment.", "cyan"],
	"swamp_coffre_banque": ["Coffre de banque éventré", "Détruisez-le : XP, ferraille, soin ou compétence (lueur dorée = compétence).", "gold"],
	"swamp_vanne_barrage": ["Vanne de barrage", "RESTEZ 1,5 s dedans : assèche la zone et annule le ralentissement de l'eau pendant 10 s.", "cyan"],
	"swamp_bouee_mine": ["Bouée-mine dérivante", "Mine dérivante armée : explose au contact ou après amorçage si vous vous approchez.", "orange"],
	"swamp_lampadaire_phare": ["Phare de toit", "Projecteur rotatif : balaye la zone et excite les ennemis touchés. Destructible.", "orange"],
	"swamp_barricade_vehicules": ["Barricade de véhicules", "Épaves de véhicules de métropole empilées : couverture lourde arrêtant tous les tirs.", "orange"],
	"swamp_brouilleur_radio": ["Brouilleur radio", "Tour de brouillage : ralentit de 50 % tous les projectiles ennemis dans un rayon de 300 u.", "magenta"],
	"swamp_gratte_ciel": ["Gratte-ciel effondré", "Vestige de tour de verre et de béton noyé dans l'eau trouble : obstacle massif.", "cyan"],
	"swamp_pont_brise": ["Pont suspendu brisé", "Tablier de pont affaissé et câbles rompus : obstacle infranchissable.", "cyan"],
	"swamp_bordure_facades": ["Façades noyées", "Ligne d'immeubles submergés et néons brisés marquant la limite de l'arène.", "cyan"],
	"plaque_de_glace": ["Plaque de glace", "Vous fait glisser : votre mecha perd de l'adhérence tant que vous êtes dessus.", "cyan"],
	"capsule_cryogenique": ["Capsule cryogénique", "Détruisez-la : un bonus… ou un ennemi en sort (1 chance sur 3).", "cyan"],
	"jet_de_cryo": ["Jet cryogénique", "Gèle (étourdit) quiconque reste dans le cercle marqué.", "cyan"],
	"brouillard_froid": ["Brouillard glacial", "Nuage glacial mobile : ralentit tout ce qui le traverse, vous comme la horde. Un radiateur proche le dissipe.", "cyan"],
	"radiateur": ["Radiateur", "Dissipe le brouillard glacial proche, donc supprime son ralentissement.", "orange"],
	"pic_de_glace": ["Pic de glace", "Éclat périodique au sol : ralentit si vous êtes dessus.", "cyan"],
	"borne_thermique": ["Borne thermique", "RESTEZ dans son cercle : soigne 20 % de vos PV (recharge 25 s).", "orange"],
	"glace_fragile": ["Glace fragile", "Se fissure puis s'effondre en obstacle solide au bout de 10 à 20 s.", "cyan"],
	# ===== Bible des niveaux — Niveau 6 (cryo) =====
	"cryo_canon_azote": ["Canon à azote", "Tire des orbes de givre lents explosant en nova glacée qui ralentit et laisse du verglas.", "cyan"],
	"cryo_condenseur_givre": ["Condenseur à givre", "Émet des anneaux de givre concentriques qui s'étendent et ralentissent les mechas.", "cyan"],
	"cryo_caisson_echantillons": ["Caisson d'échantillons", "Détruisez-le : XP, ferraille, soin ou compétence (lueur cyan = cryo-technologie).", "cyan"],
	"cryo_teleporteur_paire": ["Téléporteur de laboratoire", "Marcher sur la dalle vous téléporte instantanément sur sa balise jumelle (recharge 6 s).", "cyan"],
	"cryo_mur_glace_regen": ["Mur de glace régénérant", "Bloc de glace défensif arrêtant les tirs : se reforme entièrement 10 s après destruction.", "cyan"],
	"cryo_cuve_stase": ["Cuve de stase", "Cylindre de stase fendu et givré avec câbles au sol : obstacle solide de laboratoire.", "cyan"],
	"cryo_serveur_givre": ["Baie serveur givrée", "Armoire informatique congelée avec voyants clignotants : couverture résistante.", "cyan"],
	"cryo_bordure_cloison": ["Cloison de laboratoire", "Panneaux isolés blancs et hublots givrés formant la paroi hermétique du secteur.", "cyan"],
	"bassin_toxique": ["Bassin toxique", "Dégâts continus tant que vous restez dedans. Une vanne de drainage le suspend.", "green"],
	"vanne_drainage": ["Vanne de drainage", "RESTEZ dans son cercle : suspend les bassins toxiques proches pendant 10 s.", "cyan"],
	"poche_de_vent": ["Turbine géante", "Pousse en continu vous ET les ennemis dans une direction. Une console de vent l'inverse.", "orange"],
	"console_vent": ["Console de vent", "RESTEZ dans son cercle : inverse le sens des turbines proches.", "cyan"],
	"grille_ventilation": ["Grille de ventilation", "Souffle à intervalle : sortez du cercle marqué.", "orange"],
	"zone_alternante": ["Dalle alternante", "Alterne danger et sécurité : le cercle clignote juste avant de devenir dangereux.", "green"],
	"cristal_instable": ["Cristal instable", "Le toucher l'arme : il explose 3 s plus tard. Éloignez-vous (ou attirez-y la horde).", "green"],
	"pulse_energie": ["Pulsation d'énergie", "Émet trois anneaux qui s'étendent : sortez de leur trajet.", "green"],
	"cocon": ["Cocon", "Détruisez-le : un bonus… ou un ennemi en sort (1 chance sur 3).", "cyan"],
	"residu_biomecanique": ["Résidu biomécanique", "Vous ralentit et attire les ennemis vers son centre.", "green"],
	"sol_collant": ["Sol collant", "Ralentit fortement tout ce qui y marche.", "green"],
	"tentacule_emergence": ["Tentacule", "Jaillit du sol à intervalle : quittez le cercle marqué.", "green"],
	"nuage_spores": ["Nuage de spores", "Dérive et inflige des dégâts continus. Une plante lumineuse proche le dissipe.", "green"],
	"plante_lumineuse": ["Plante lumineuse", "RESTEZ dans son cercle : dissipe les nuages de spores proches pendant 8 s.", "green"],
	"porte_securite_orbitale": ["Porte de sécurité", "S'ouvre et se ferme à intervalle : franchissez-la quand elle est ouverte.", "orange"],
	"zone_depressurisation": ["Zone de dépressurisation", "Aspire vers son centre à intervalle (clignote avant) : éloignez-vous avant l'aspiration.", "orange"],
	"zone_push_pull": ["Anneau de gravité", "Repousse puis attire en alternance : teinte bleue = pousse, orange = attire.", "cyan"],
	"emetteur_laser_rotatif": ["Laser rotatif", "Balaie une ligne qui tourne à chaque tir : évitez la bande marquée.", "orange"],
	"pilier_energie": ["Pilier d'énergie", "Détruit, il repousse violemment les ennemis proches.", "orange"],
	"segment_mur_modulaire": ["Mur modulaire", "Apparaît et disparaît par intervalles : bloque le passage quand il est là.", "orange"],
	# ===== Bible des niveaux — Niveau 7 (reacteur) =====
	"reacteur_canon_particules": ["Canon à particules", "Tir à charge qui se divise en 3 fragments. En surchauffe, il explose.", "green"],
	"reacteur_bobine_tesla": ["Bobine de Tesla", "Deux bobines reliées par un arc électrique continu qui inflige de lourds dégâts.", "green"],
	"reacteur_barre_combustible": ["Barre de combustible", "Détruisez-la : XP, ferraille, soin ou compétence radioactive.", "green"],
	"reacteur_barre_controle": ["Barre de contrôle", "RESTEZ 1,5 s près d'elle : réduit de 60 % tous les dégâts d'énergie pendant 8 s.", "yellow"],
	"reacteur_cellule_confinement": ["Cellule de confinement", "Active un dôme protecteur de 220 u bloquant tous les projectiles ennemis pendant 6 s.", "green"],
	"reacteur_turbine_hs": ["Turbine de refroidissement HS", "Rotor géant broyé et tordu d'une turbine nucléaire : obstacle métallique massif.", "green"],
	"reacteur_cuve_plomb": ["Cuve de plomb éventrée", "Réservoir lourd de rétention fissuré fuyant des vapeurs toxiques : couverture solide.", "green"],
	"reacteur_bordure_blindage": ["Blindage lourd du réacteur", "Paroi de confinement renforcée au plomb marquant la limite du secteur radioactif.", "green"],
	# ===== Bible des niveaux — Niveau 8 (ruche) =====
	"ruche_organe_acide": ["Organe cracheur d'acide", "Crache 3 globules d'acide en cloche créant des flaques toxiques corrosives.", "green"],
	"ruche_pondoir": ["Pondoir de la ruche", "Pond régulièrement des larves agressives : cible prioritaire à détruire.", "magenta"],
	"ruche_bulbe_nutritif": ["Bulbe nutritif", "Détruisez-le : XP, ferraille, soin ou compétence bioluminescente.", "cyan"],
	"ruche_veine_pulsatile": ["Veine pulsatile", "Pulse violemment toutes les 3 s et repousse tout le long de son axe.", "magenta"],
	"ruche_vessie_explosive": ["Vessie explosive", "Touchée, elle explose violemment en projetant une gerbe d'acide corrosive.", "orange"],
	"ruche_colonne_os": ["Colonne d'ossements fusionnés", "Pilier imposant de chitine et de structures osseuses fossilisées : obstacle infranchissable.", "magenta"],
	"ruche_champignon_geant": ["Champignon parasite géant", "Spécimen fongique boursouflé et spongieux servant d'obstacle organique dans le nid.", "green"],
	"ruche_bordure_paroi_chair": ["Paroi organique de la ruche", "Biomasse alien dense et pulsatile formant les parois étanches du nid xénomorphe.", "magenta"],
	# ===== Bible des niveaux — Niveau 9 (citadelle) =====
	"citadelle_lanceur_guide": ["Lanceur orbital", "Tire des missiles guidés à tête chercheuse qui traquent le mecha.", "orange"],
	"citadelle_relais_satellite": ["Relais satellite", "Émet des pulsations orbitales périodiques électrifiant la zone.", "cyan"],
	"citadelle_module_ravitaillement": ["Module de ravitaillement", "Détruisez-le : cargaison de haute technologie, ferraille et compétences.", "gold"],
	"citadelle_sas_pressurise": ["Sas pressurisé", "Sas orbital étanche qui s'ouvre et se ferme selon un cycle régulier.", "orange"],
	"citadelle_dome_bouclier": ["Dôme-bouclier", "Projette une barrière énergétique impénétrable repoussant les assauts.", "cyan"],
	"citadelle_grappin_magnetique": ["Grappin magnétique", "Attire périodiquement les ennemis et débris vers son ancrage.", "cyan"],
	"citadelle_panneau_solaire": ["Panneau solaire orbital", "Réseau de capteurs photovoltaïques spatiaux déployés : structure réfléchissante fragile.", "cyan"],
	"citadelle_reacteur_orbital": ["Réacteur à fusion orbital", "Noyau de propulsion secondaire suspendu : générateur massif faisant obstacle aux tirs.", "orange"],
	"citadelle_bordure_coque": ["Coque orbitale blindée", "Blindage spatial composite formant la limite extérieure de la station orbitale.", "cyan"],
}

# What a smashed man-made prop leaves. A gold-glow crate ("skill" pre-rolled at spawn) always
# gives a competence — that promise stays readable. Everything else rolls here.
const DROPS: Array = [
	["xp", 34], ["scrap", 28], ["heal", 16], ["od", 14], ["emoji", 8],
]

# ROCK FAMILY — mineral scenery that now (a) is DESTRUCTIBLE and (b) gets placed in aligned
# RIDGES (a row of rocks reads as a natural outcrop; a row of trees would look planted, so only
# rocks form ridges). A ridge is a barrier: it blocks the player AND funnels the horde, so a
# straight-line retreat runs into a wall you must round or grind through. Destructible "but not
# too easily" — the HP band below is a real detour cost, not a speed bump. No loot: these are
# TERRAIN, not a farm (that keeps the patron's old anti-farm rule while dropping the old
# indestructible rule).
const ROCK_FAMILY: Array = ["rocher", "arche", "lave", "glace", "cristaux"]
const ROCK_HP: Dictionary = {
	"rocher": 210.0, "arche": 210.0, "lave": 175.0, "glace": 120.0, "cristaux": 110.0,
}
const RIDGE_CHANCE: float = 0.5   # per chunk, when the biome has a rock-family prop

# BORDER — the ring of indestructible natural elements that walls the bounded arena. Big biome
# props, rendered oversized, packed shoulder-to-shoulder so the edge reads as a solid, impassable
# natural barrier (mountains / rock / ruins). Purely decorative: the hard clamp on the player and
# spawns is the real wall, so these carry NO collider and are NOT in cover_list (60 props scanned
# by 220 enemies every frame would be the opposite of an optimisation).
const BIOME_BORDER: Dictionary = {
	# 14/10 (patron : « ne laisse que ce qui est specifique a chaque niveau ») : chaque piece de mur
	# n'apparait plus que dans UN seul biome — plus de rocher/arbre/cristaux/glace repetes.
	"tech":      ["tech_bordure_paroi_usine"],
	"desert":    ["desert_bordure_mesa"],
	"jungle":    ["jungle_mur_vegetal"],
	"volcanic":  ["volcanic_bordure_basalte"],
	"swamp":     ["swamp_bordure_facades"],
	"ice":       ["glace"],
	"spaceship": ["impulsion"],
	"cryo":      ["cryo_bordure_cloison"],
	"reacteur":  ["reacteur_bordure_blindage"],
	"ruche":     ["ruche_bordure_paroi_chair"],
	"citadelle": ["citadelle_bordure_coque"],
	# earth / ruines : plus aucun decor propre (tout etait partage) -> pas de mur decoratif
	"earth":     [],
	"ruines":    [],
}
const BORDER_STEP: float = 300.0    # spacing along the wall (props are rendered wider -> they overlap)
const BORDER_SZ: float = 320.0      # oversized wall props: big enough to touch at BORDER_STEP

## Build the arena wall: a packed ring of oversized biome props along the square perimeter at
## ±half. Called from Game._scatter_decor, so it is rebuilt with the right material each biome.
func build_border(half: float) -> void:
	var kinds: Array = BIOME_BORDER.get(biome, [])
	if kinds.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("border:%s" % biome)
	var n_side: int = int((half * 2.0) / BORDER_STEP) + 1
	for side in 4:
		for i in n_side:
			var t: float = -half + float(i) * BORDER_STEP + rng.randf_range(-24.0, 24.0)
			var jit: float = rng.randf_range(-18.0, 18.0)   # slight inward wobble -> organic, not a fence
			var pos: Vector2
			match side:
				0: pos = Vector2(t, -half + jit)   # top
				1: pos = Vector2(t, half - jit)    # bottom
				2: pos = Vector2(-half + jit, t)   # left
				_: pos = Vector2(half - jit, t)    # right
			_place_border(String(kinds[rng.randi() % kinds.size()]), pos, rng.randf_range(0.92, 1.22),
				rng.randf() < 0.5)

## One wall prop: sprite + ground shadow, no collider, no logic. Rendered from the shared decor art.
func _place_border(kind: String, pos: Vector2, scl: float, flip: bool) -> void:
	var d: Dictionary = DECOR.get(kind, {})
	var tex: Texture2D = load("res://assets/decor/%s.png" % String(d.get("f", "g29")))
	if tex == null:
		return
	var th: float = maxf(1.0, float(tex.get_height()))
	var d_mult: float = SaveManager.get_decor_scale(kind, "borders") if (SaveManager != null and SaveManager.has_method("get_decor_scale")) else 1.0
	var sc: float = scl * (BORDER_SZ / th) * d_mult
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.5)
	shadow.position = pos + Vector2(0.0, th * sc * 0.36)
	shadow.scale = Vector2(float(tex.get_width()) * sc / 64.0 * 0.66, th * sc / 64.0 * 0.20)
	shadow.z_index = -2
	add_child(shadow)
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2.ONE * sc
	s.flip_h = flip
	s.z_index = clampi(int(pos.y), -4090, 4090)   # y-sort against actors so the wall overlaps correctly
	add_child(s)
# BIOME COHERENCE — every NATURE prop belongs ONLY to its own map: no rocks on the ice sheet,
# no trees in the desert, no ice in the spaceship. The ONLY props allowed everywhere are the
# DESTROYED ROBOTS (epave/carcasse — this is a robot war, wreckage is everywhere) and the BONUS
# crates (caisses/baril/container), which are man-made and carry the competences.
#   rocher -> earth/desert/volcanic | arbre -> earth/jungle/swamp | plante+racines+champignon ->
#   jungle/swamp | glace+epave_gel -> ice | lave+lave_geyser -> volcanic | arche+campement ->
#   desert | generateur/conduit/emetteur/antenne/tourelle/serveurs/capsule -> tech+spaceship
# EVERY biome now carries active battlefield hazards (turret + beam cannon + a spawn/slow emplacement)
# on top of its native flora/terrain — it is a ROBOT WAR, war-machines and wreckage litter every zone.
# So no level is ever a passive stroll: cannons fire, beams sweep, nests spew, whatever the biome.
static func _decor_cat(k: String) -> String:
	if k in ["baril", "caisses", "container", "crate", "tech_bac_composants", "desert_malle_survie", "jungle_cosse_geante", "volcanic_lingotiere", "swamp_coffre_banque", "cryo_caisson_echantillons", "reacteur_barre_combustible", "ruche_bulbe_nutritif", "citadelle_module_ravitaillement", "ruche_vessie_explosive"]:
		return "crates_barrels"
	if k in ["generateur", "antenne", "conduit", "emetteur", "epave", "tourelle", "capaciteur", "archives", "tech_soudeuse", "tech_portique_laser", "desert_miroir_solaire", "desert_generateur_tempete", "desert_ver_foreur", "jungle_mortier_plante", "jungle_liane_fouet", "jungle_arbre_ruche", "jungle_fruit_grenade", "volcanic_mortier_scories", "volcanic_event_magma", "volcanic_marteau_pilon", "volcanic_creuset_basculant", "volcanic_soufflerie_braises", "swamp_tourelle_dca", "swamp_brouilleur_radio", "swamp_lampadaire_phare", "cryo_canon_azote", "cryo_condenseur_givre", "reacteur_canon_particules", "reacteur_bobine_tesla", "ruche_organe_acide", "ruche_pondoir", "citadelle_lanceur_guide", "citadelle_relais_satellite"]:
		return "machines_towers"
	if k in ["convoyeur_sol", "console_convoyeur", "bras_presseur", "piston_hydraulique", "surchauffe_sol", "plaque_de_glace", "jet_de_cryo", "bassin_toxique", "poche_de_vent", "zone_alternante", "zone_depressurisation", "desert_fosse_aspiration", "desert_collecteur_solaire", "desert_projecteur_mirage", "desert_fumerolle_vapeur", "jungle_fleur_catapulte", "jungle_plante_lasso", "jungle_nuee_lucioles", "volcanic_bassin_trempe", "volcanic_electroaimant", "swamp_vanne_crue", "swamp_vanne_barrage", "swamp_bouee_mine", "swamp_barricade_vehicules", "cryo_teleporteur_paire", "cryo_mur_glace_regen", "reacteur_barre_controle", "reacteur_cellule_confinement", "ruche_veine_pulsatile", "citadelle_sas_pressurise", "citadelle_dome_bouclier", "citadelle_grappin_magnetique"]:
		return "interactive_hazards"
	if k in ["rocher", "cristaux", "arbre", "plante", "glace", "arche", "lave", "racines", "pilier_energie", "tech_cuve_vapeur", "tech_chariot_robot", "desert_char_enfoui", "desert_arche_verre", "jungle_colonne_racines", "jungle_statue_mecha", "volcanic_cheminee_fonderie", "volcanic_pont_roulant", "swamp_gratte_ciel", "swamp_pont_brise", "cryo_cuve_stase", "cryo_serveur_givre", "reacteur_turbine_hs", "reacteur_cuve_plomb", "ruche_colonne_os", "ruche_champignon_geant", "citadelle_panneau_solaire", "citadelle_reacteur_orbital"]:
		return "nature_minerals"
	return "borders"

# Decor « de support » -> [cible a poser juste a cote, distance]. Voir _load_chunk. La distance reste
# SOUS le rayon d'action du support (console_convoyeur/console_vent 400, vanne_drainage 250,
# plante_lumineuse 300, radiateur 320). Les nuages (brouillard/spores) exigent > ~280 u d'espacement
# avec tout autre decor (lisibilite, cf. _load_chunk) : leurs supports ont donc un rayon d'action large.
# Les nuages derivent lentement (14-18 u/s) : le support agit tant qu'ils passent a portee.
const COMPANION: Dictionary = {
	"console_convoyeur": ["convoyeur_sol", 190.0],
	"vanne_drainage":    ["bassin_toxique", 190.0],
	"console_vent":      ["poche_de_vent", 200.0],
	"plante_lumineuse":  ["nuage_spores", 290.0],
	"radiateur":         ["brouillard_froid", 300.0],
}

const BIOME_DECOR: Dictionary = {
	# 14/10 (patron : « ne laisse que ce qui est specifique a chaque niveau ») : CHAQUE decor n'apparait
	# plus que dans UN SEUL biome. Avant, tourelle/capaciteur/generateur/baril/caisses/epave se
	# repetaient dans les 13 biomes, et rocher/arbre/cristaux/glace/plante/racines dans 2 a 4.
	# Le « kit generique » (tourelle, capaciteur, generateur, baril, antenne, emetteur, caisses,
	# container, conduit) appartient au niveau 1 (L'Usine) ; les nouveaux decors propres a chaque
	# niveau arriveront avec leurs images (voir la bible des niveaux). Une liste vide = biome sans decor.
	"tech":      ["tech_soudeuse", "tech_portique_laser", "tech_bac_composants", "tech_cuve_vapeur", "tech_chariot_robot",
	              "generateur", "conduit", "antenne", "capaciteur", "tourelle", "emetteur", "baril", "container", "caisses", "aimant", "terminal", "archives", "quai", "convoyeur",
	              "convoyeur_sol", "console_convoyeur", "bras_presseur", "piston_hydraulique", "vanne_refroidissement", "surchauffe_sol", "porte_automatique", "zone_chargement", "container_mobile"],
	"desert":    ["desert_miroir_solaire", "desert_generateur_tempete", "desert_malle_survie", "desert_fosse_aspiration",
	              "desert_collecteur_solaire", "desert_projecteur_mirage", "desert_ver_foreur", "desert_fumerolle_vapeur",
	              "desert_char_enfoui", "desert_arche_verre"],
	"jungle":    ["jungle_mortier_plante", "jungle_liane_fouet", "jungle_cosse_geante",
	              "jungle_fleur_catapulte", "jungle_plante_lasso", "jungle_nuee_lucioles",
	              "jungle_arbre_ruche", "jungle_fruit_grenade", "jungle_colonne_racines", "jungle_statue_mecha"],
	"volcanic":  ["volcanic_mortier_scories", "volcanic_event_magma", "volcanic_lingotiere",
	              "volcanic_marteau_pilon", "volcanic_creuset_basculant", "volcanic_bassin_trempe",
	              "volcanic_electroaimant", "volcanic_soufflerie_braises", "volcanic_cheminee_fonderie", "volcanic_pont_roulant"],
	"swamp":     ["swamp_tourelle_dca", "swamp_vanne_crue", "swamp_coffre_banque", "swamp_vanne_barrage", "swamp_bouee_mine", "swamp_lampadaire_phare", "swamp_barricade_vehicules", "swamp_brouilleur_radio", "swamp_gratte_ciel", "swamp_pont_brise"],
	"cryo":      ["cryo_canon_azote", "cryo_condenseur_givre", "cryo_caisson_echantillons", "cryo_teleporteur_paire", "cryo_mur_glace_regen", "cryo_cuve_stase", "cryo_serveur_givre",
	              "plaque_de_glace", "capsule_cryogenique", "jet_de_cryo", "brouillard_froid", "radiateur", "pic_de_glace", "borne_thermique", "glace_fragile"],
	"reacteur":  ["reacteur_canon_particules", "reacteur_bobine_tesla", "reacteur_barre_combustible", "reacteur_barre_controle", "reacteur_cellule_confinement", "reacteur_turbine_hs", "reacteur_cuve_plomb",
	              "bassin_toxique", "vanne_drainage", "poche_de_vent", "console_vent", "grille_ventilation", "zone_alternante", "cristal_instable", "pulse_energie"],
	"ruche":     ["ruche_organe_acide", "ruche_pondoir", "ruche_bulbe_nutritif", "ruche_veine_pulsatile", "ruche_vessie_explosive", "ruche_colonne_os", "ruche_champignon_geant",
	              "cocon", "residu_biomecanique", "sol_collant", "tentacule_emergence", "nuage_spores", "plante_lumineuse"],
	"citadelle": ["citadelle_lanceur_guide", "citadelle_relais_satellite", "citadelle_module_ravitaillement", "citadelle_sas_pressurise", "citadelle_dome_bouclier", "citadelle_grappin_magnetique", "citadelle_panneau_solaire", "citadelle_reacteur_orbital",
	              "porte_securite_orbitale", "zone_depressurisation", "zone_push_pull", "emetteur_laser_rotatif", "pilier_energie", "segment_mur_modulaire"],
	# biomes hors campagne (SANS FIN) : un seul decor propre, ou aucun
	"ice":       ["glace"],
	"spaceship": ["impulsion"],
	"earth":     [],
	"ruines":    [],
}

# ===== 03/10, PROGRESSION PAR MAP (plan "15 maps") =====
# Le patron a releve que les 5 biomes "15 maps" melangeaient leurs 3 maps sources dans UNE SEULE
# liste plate (BIOME_DECOR ci-dessus) : un tirage uniforme ne respecte aucun "ordre" entre les
# maps 4/5/6 (ou 1/2/3, 7/8/9, etc.) — tout pouvait apparaitre des la premiere minute. Correctif :
# chaque biome "15 maps" associe ses kinds a l'une de ses 3 maps sources (verifie ligne a ligne
# contre le PDF d'origine), et _pick_kind() ci-dessous fait deriver un tirage PONDERE par le temps
# ecoule (GameState.run_time) d'une map vers la suivante, sans jamais couper une map a zero (pour
# garder de la surprise). Les biomes HORS de ce dict (earth/volcanic/...) n'ont pas de notion de
# "map" dans le document source : ils gardent le tirage uniforme a l'identique (code inchange).
const MAP_PHASE_DURATION: float = 300.0   # 5 min/segment -> une run de 15 min traverse les 3 maps
const MAP_PHASE_FLOOR: float = 0.15       # une map "pas encore due"/"deja passee" reste possible
const BIOME_MAP_SEGMENTS: Dictionary = {
	"tech": [
		# 04/10, trou signale par le patron : les 10 decors generiques herites d'avant la refonte
		# (conduit/antenne/emetteur/cristaux/container/aimant/terminal/archives/quai/convoyeur)
		# n'etaient dans AUCUN segment -> toujours tires a poids fixe, jamais concernes par la
		# progression. Rattaches par affinite thematique avec chaque map du document source ; les 5
		# restants (generateur/capaciteur/tourelle/baril/caisses) deviennent la vraie base neutre de
		# "tech", symetrique avec les 6 items de base des 4 autres biomes "15 maps".
		["convoyeur_sol", "console_convoyeur", "bras_presseur", "convoyeur", "terminal", "archives", "tech_soudeuse", "tech_cuve_vapeur"],      # Map 1 - Hall d'Assemblage
		["piston_hydraulique", "vanne_refroidissement", "surchauffe_sol", "conduit", "emetteur", "aimant", "tech_portique_laser", "tech_chariot_robot"], # Map 2 - Fonderie des Pistons
		["porte_automatique", "zone_chargement", "container_mobile", "antenne", "container", "quai", "tech_bac_composants"], # Map 3 - Quai de Chargement
	],
	"desert": [
		["desert_arche_verre", "desert_fosse_aspiration", "desert_fumerolle_vapeur"],    # Map 1 - Dunes de Silice
		["desert_char_enfoui", "desert_generateur_tempete", "desert_projecteur_mirage"], # Map 2 - Mer de Verre
		["desert_miroir_solaire", "desert_collecteur_solaire", "desert_ver_foreur", "desert_malle_survie"], # Map 3 - Cratère Solaire
	],
	"jungle": [
		["jungle_colonne_racines", "jungle_plante_lasso", "jungle_fleur_catapulte"],     # Map 1 - Lisière Envahie
		["jungle_statue_mecha", "jungle_liane_fouet", "jungle_nuee_lucioles"],        # Map 2 - Canopée Profonde
		["jungle_mortier_plante", "jungle_arbre_ruche", "jungle_fruit_grenade", "jungle_cosse_geante"], # Map 3 - Cœur Végétal
	],
	"volcanic": [
		["volcanic_cheminee_fonderie", "volcanic_event_magma", "volcanic_soufflerie_braises"], # Map 1 - Failles de Lave
		["volcanic_pont_roulant", "volcanic_creuset_basculant", "volcanic_marteau_pilon"],       # Map 2 - Haut Fourneau
		["volcanic_mortier_scories", "volcanic_bassin_trempe", "volcanic_electroaimant", "volcanic_lingotiere"], # Map 3 - Cœur de Magma
	],
	"swamp": [
		["swamp_gratte_ciel", "swamp_bouee_mine", "swamp_barricade_vehicules"],          # Map 1 - Quartiers Noyés
		["swamp_pont_brise", "swamp_vanne_crue", "swamp_lampadaire_phare"],           # Map 2 - Ponts Submergés
		["swamp_tourelle_dca", "swamp_brouilleur_radio", "swamp_vanne_barrage", "swamp_coffre_banque"], # Map 3 - Centre Inondé
	],
	"cryo": [
		["plaque_de_glace", "capsule_cryogenique", "jet_de_cryo", "cryo_canon_azote", "cryo_cuve_stase"],           # Map 4 - Cryo-Voute
		["brouillard_froid", "radiateur", "pic_de_glace", "cryo_condenseur_givre", "cryo_serveur_givre"],           # Map 5 - Serres Gelees
		["borne_thermique", "glace_fragile", "cryo_caisson_echantillons", "cryo_teleporteur_paire", "cryo_mur_glace_regen"], # Map 6 - Lac de Permafrost
	],
	"reacteur": [
		["bassin_toxique", "vanne_drainage", "reacteur_canon_particules", "reacteur_cuve_plomb"],                    # Map 7 - Bassins Toxiques
		["poche_de_vent", "console_vent", "grille_ventilation", "reacteur_bobine_tesla", "reacteur_turbine_hs"],    # Map 8 - Salle des Turbines
		["zone_alternante", "cristal_instable", "pulse_energie", "reacteur_barre_combustible", "reacteur_barre_controle", "reacteur_cellule_confinement"], # Map 9 - Noyau Fissure
	],
	"ruche": [
		["cocon", "residu_biomecanique", "ruche_organe_acide", "ruche_champignon_geant"],                           # Map 10 - Couvoir Mecanique
		["sol_collant", "tentacule_emergence", "ruche_veine_pulsatile", "ruche_colonne_os"],                       # Map 11 - Veines Vivantes
		["nuage_spores", "plante_lumineuse", "ruche_pondoir", "ruche_bulbe_nutritif", "ruche_vessie_explosive"],    # Map 12 - Jardin de Spores
	],
	"citadelle": [
		["porte_securite_orbitale", "zone_depressurisation", "citadelle_lanceur_guide", "citadelle_panneau_solaire"], # Map 13 - Pont Orbital
		["zone_push_pull", "emetteur_laser_rotatif", "citadelle_relais_satellite", "citadelle_sas_pressurise", "citadelle_reacteur_orbital"], # Map 14 - Anneau de Gravite
		["pilier_energie", "segment_mur_modulaire", "citadelle_module_ravitaillement", "citadelle_dome_bouclier", "citadelle_grappin_magnetique"], # Map 15 - Chambre de la Forge
	],
}

## Poids triangulaires sur les 3 segments pour le temps de run courant : le segment i culmine a la
## minute (i+1)*5 et retombe lineairement vers ses voisins (derive, pas de couperet). Plancher a
## MAP_PHASE_FLOOR pour qu'une map "pas encore due" garde une petite chance (surprise > purete).
func _map_phase_weights() -> Array:
	var pos: float = clampf(GameState.run_time / MAP_PHASE_DURATION, 0.0, 2.0)
	var w: Array = [0.0, 0.0, 0.0]
	for i in 3:
		w[i] = maxf(MAP_PHASE_FLOOR, 1.0 - absf(pos - float(i)))
	var total: float = w[0] + w[1] + w[2]
	return [w[0] / total, w[1] / total, w[2] / total]

## 04/10, pour la banniere de transition (Game.gd) : quel segment (0/1/2) DOMINE actuellement, sur
## la seule base du temps ecoule - meme seuil que _map_phase_weights ci-dessus (une seule source de
## verite pour MAP_PHASE_DURATION), mais arrondi a l'indice le plus proche plutot qu'une ponderation.
func current_map_phase() -> int:
	return clampi(int(round(clampf(GameState.run_time / MAP_PHASE_DURATION, 0.0, 2.0))), 0, 2)

## Pioche un kind dans la liste du biome. Pour les biomes "15 maps" (BIOME_MAP_SEGMENTS) : les
## kinds HORS segment (tourelle/capaciteur/...) gardent un poids de 1.0 chacun comme avant ; les
## kinds DANS un segment se partagent un poids total egal a (poids_de_phase x nb_kinds_thematiques)
## -> la proportion globale "base generique vs decor thematique" ne change pas (meme densite de
## danger par chunk qu'avant), seul le kind thematique qui gagne derive avec le temps. Les biomes
## absents de BIOME_MAP_SEGMENTS gardent le tirage uniforme d'origine, inchange.
func _pick_kind(kinds: Array, rng: RandomNumberGenerator) -> String:
	var segs: Array = BIOME_MAP_SEGMENTS.get(biome, [])
	if segs.is_empty():
		return String(kinds[rng.randi() % kinds.size()])
	var themed_total: int = 0
	for seg in segs:
		themed_total += (seg as Array).size()
	var themed_set: Dictionary = {}
	for seg in segs:
		for k in seg:
			themed_set[k] = true
	var w: Array = _map_phase_weights()
	var entry_kinds: Array = []
	var entry_weights: Array = []
	var total_w: float = 0.0
	for k in kinds:
		var ks: String = String(k)
		if themed_set.has(ks):
			continue
		entry_kinds.append(ks); entry_weights.append(1.0); total_w += 1.0
	for i in segs.size():
		var seg: Array = segs[i]
		if seg.is_empty():
			continue
		var per_kind_w: float = (float(w[i]) * float(themed_total)) / float(seg.size())
		for k in seg:
			entry_kinds.append(String(k)); entry_weights.append(per_kind_w); total_w += per_kind_w
	var roll: float = rng.randf() * total_w
	for i in entry_kinds.size():
		roll -= entry_weights[i]
		if roll <= 0.0:
			return entry_kinds[i]
	return entry_kinds[entry_kinds.size() - 1]

## Kept for the old call site: seeds the chunks around the player straight away. The `count`
## argument is now ignored — density comes from PER_CHUNK and coverage is endless.
## Bounded arena: place ALL decor ONCE and leave it — the map is finite now, so nothing streams in
## or out as you move (that pop-in was what read as "the decor isn't fixed"). Props exist for the
## whole run and block the player physically via the collision engine (free, broad-phase). Only the
## ENEMY-steering list (cover_list) is kept small — see _refresh_cover.

func populate(_count: int = 28) -> void:
	if arena_half > 0.0:
		var cr: int = int(ceil(arena_half / CHUNK))   # chunks out to the wall (border hides any spill)
		for cy in range(-cr, cr + 1):
			for cx in range(-cr, cr + 1):
				_load_chunk(Vector2i(cx, cy))
		_refresh_cover(_cell_of(_player_pos()))
	else:
		_refresh(_cell_of(_player_pos()))   # legacy infinite streaming (unused once Game sets bounds)

## cover_list drives enemy steering and is O(enemies x list) every frame, so it must stay small.
## With fixed decor we can't let every prop self-register (200+ props x 220 enemies would melt a
## phone), so cover_list holds only the props in the 3x3 chunks around the player — the only props
## any enemy is ever near, since enemies chase the player.
func _refresh_cover(cell: Vector2i) -> void:
	if game == null or not ("cover_list" in game):
		return
	game.cover_list.clear()
	for dy in range(-COVER_R, COVER_R + 1):
		for dx in range(-COVER_R, COVER_R + 1):
			var props: Variant = _chunks.get(cell + Vector2i(dx, dy))
			if props == null:
				continue
			for p in props:
				if is_instance_valid(p):
					game.cover_list.append(p)

var _player: Node2D = null
func _player_pos() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		return _player.global_position
	return Vector2.ZERO   # built before the player exists -> seed around the spawn

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK)), int(floor(p.y / CHUNK)))

func _process(delta: float) -> void:
	# decor is fixed (placed once); only the near-player cover set is refreshed, and only when the
	# player crosses into a new chunk.
	var cell: Vector2i = _cell_of(_player_pos())
	if cell != _last_cell:
		_last_cell = cell
		if arena_half > 0.0:
			_refresh_cover(cell)
		else:
			_refresh(cell)
	_scan_new_kinds(delta)

# --- PANCARTES : premiere rencontre d'un decor a effet -------------------------------------
const SIGN_R: float = 380.0        # 14/10 (patron : « pas assez reactif ») : se declenche des qu'on approche (~3 longueurs de mecha)
const SIGN_SCAN: float = 0.1       # periode du balayage (etait 0,3 s : jusqu'a 0,3 s de retard avant meme la file)
var _sign_scan_t: float = 0.0

## Toutes les 0,3 s, cherche un decor a effet (INFO) a portee de vue dont la pancarte n'a jamais ete
## montree et la demande a Game.pancarte_prop (qui memorise + met en file). Un seul passage par
## decor : Game refuse un kind deja vu, donc le cout reste un simple balayage de quelques centaines
## de props toutes les 0,3 s.
func _scan_new_kinds(delta: float) -> void:
	_sign_scan_t -= delta
	if _sign_scan_t > 0.0 or game == null or not game.has_method("pancarte_prop"):
		return
	_sign_scan_t = SIGN_SCAN
	# Position du VRAI joueur (Game.player) : _player_pos() renvoie (0,0) tant que le joueur n'existe
	# pas, et le balayage d'avant sa creation mettait en file des decors proches de l'origine — que
	# le rechargement des chunks liberait ensuite. Pas de joueur = pas de balayage.
	var pp: Vector2 = Vector2.ZERO
	if "player" in game:
		var gp: Variant = game.get("player")
		if gp == null or not is_instance_valid(gp):
			return
		pp = (gp as Node2D).global_position
	else:
		pp = _player_pos()   # bancs de test (StubGame sans joueur)
	var r2: float = SIGN_R * SIGN_R
	# seuls les chunks voisins du joueur (3x3 de 1000 u) peuvent contenir un decor a <= SIGN_R :
	# balayage 3x plus frequent sans surcout.
	var pc: Vector2i = _cell_of(pp)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var ck: Vector2i = pc + Vector2i(dx, dy)
			if not _chunks.has(ck):
				continue
			_scan_chunk_for_signs(ck, pp, r2)

func _scan_chunk_for_signs(c: Vector2i, pp: Vector2, r2: float) -> void:
	if true:
		for p in _chunks[c]:
			if not is_instance_valid(p) or not INFO.has((p as Prop).kind):
				continue
			# le tapis : la pancarte apparait des qu'on entre dans sa ZONE d'effet (rayon > SIGN_R)
			var rr2: float = r2
			if (p as Prop)._conveyor:
				rr2 = maxf(r2, (p as Prop)._conveyor_r * (p as Prop)._conveyor_r)
			if (p as Node2D).global_position.distance_squared_to(pp) <= rr2:
				game.pancarte_prop((p as Prop).kind, (p as Prop).get_sprite_texture(), p as Node2D)

## Distance (unites) au decor de ce type LE PLUS PROCHE de `pos` (1e9 s'il n'y en a aucun). Pancartes :
## la nouveaute la plus proche passe en premier (voir Game._pancarte_pump).
func kind_dist(kind: String, pos: Vector2) -> float:
	var best: float = 1e9
	var pc: Vector2i = _cell_of(pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var ck: Vector2i = pc + Vector2i(dx, dy)
			if not _chunks.has(ck):
				continue
			for p in _chunks[ck]:
				if is_instance_valid(p) and (p as Prop).kind == kind:
					best = minf(best, (p as Node2D).global_position.distance_to(pos))
	return best

## Un decor de ce type se trouve-t-il a moins de `r` unites de `pos` ? (pancartes : voir Game.)
func kind_near(kind: String, pos: Vector2, r: float) -> bool:
	var r2: float = r * r
	for c in _chunks:
		for p in _chunks[c]:
			if not is_instance_valid(p) or (p as Prop).kind != kind:
				continue
			if (p as Node2D).global_position.distance_squared_to(pos) <= r2:
				return true
	return false

func _refresh(cell: Vector2i) -> void:
	_last_cell = cell
	for dy in range(-LOAD_R, LOAD_R + 1):
		for dx in range(-LOAD_R, LOAD_R + 1):
			var c: Vector2i = cell + Vector2i(dx, dy)
			if not _chunks.has(c):
				_load_chunk(c)
	for c in _chunks.keys():
		if absi(c.x - cell.x) > LOAD_R or absi(c.y - cell.y) > LOAD_R:
			_unload_chunk(c)

## Props smashed THIS RUN, keyed by rounded world position (stable: positions come from the chunk's
## seeded RNG). Chunks stream in and out as you walk, and without this a destroyed prop came back
## on every revisit — a 2000-unit round trip regenerated the scenery, so a gold crate handed out a
## free, uncapped draft upgrade roughly every 15 seconds, forever.
var _destroyed: Dictionary = {}

## 🚨 TEMPORAIRE (banc du 23/09) : le decor destructible n'avait AUCUNE trace de banc, contrairement
## a Enemy._palier_max_run pour l'IQ. Impossible de confirmer en headless qu'un rocher a seulement
## ete detruit une fois. A retirer une fois le systeme rejoue en vrai (souris/clavier).
static var _detruits_bench: int = 0

func mark_destroyed(pos: Vector2) -> void:
	_destroyed[Vector2i(pos.round())] = true
	_detruits_bench += 1

## Props that actively threaten the player. They are GATED BY RUN TIME so the arena escalates:
## the map at minute 12 must not be the map at minute 2. That sameness is the real source of
## boredom — the run got harder, the terrain never did.
##   0-3 min  : none (the player is learning the loop)
##   3-8 min  : hazards appear at 55% of their weight
##   8+ min   : full weight, plus an extra prop per chunk
## First kind in the biome list that is not a hazard (used to cap one hazard per chunk).
func _nonhazard(kinds: Array) -> String:
	for k in kinds:
		if not HAZARDS.has(String(k)):
			return String(k)
	return String(kinds[0]) if not kinds.is_empty() else ""

## Rayon d'encombrement d'un decor (les nuages et zones larges comptent pour leur VRAIE taille).
func _gap_of(kind: String) -> float:
	var kdef: Dictionary = DECOR.get(kind, {}) as Dictionary
	var eff_sz: float = float(kdef.get("sz", 110.0))
	if kdef.has("fog_r"): eff_sz = maxf(eff_sz, float(kdef["fog_r"]) * 2.2)
	if kdef.has("spore_r"): eff_sz = maxf(eff_sz, float(kdef["spore_r"]) * 2.2)
	if kdef.has("sinkhole_r"): eff_sz = maxf(eff_sz, float(kdef["sinkhole_r"]) * 1.8)
	if kdef.has("toxic_r"): eff_sz = maxf(eff_sz, float(kdef["toxic_r"]) * 1.8)
	if kdef.has("sticky_r"): eff_sz = maxf(eff_sz, float(kdef["sticky_r"]) * 1.8)
	if kdef.has("bio_residue_r"): eff_sz = maxf(eff_sz, float(kdef["bio_residue_r"]) * 1.8)
	return 55.0 + eff_sz * 0.45

func _load_chunk(c: Vector2i) -> void:
	var kinds: Array = BIOME_DECOR.get(biome, BIOME_DECOR["tech"])
	if kinds.is_empty():
		_chunks[c] = []   # biome sans decor propre
		return
	# deterministic per chunk (and per biome) -> revisiting a zone shows the same scenery
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [biome, c.x, c.y])
	var origin: Vector2 = Vector2(float(c.x) * CHUNK, float(c.y) * CHUNK)
	var lo: float = MARGIN
	var hi: float = CHUNK - MARGIN
	var ppos: Vector2 = _player_pos()
	var made: Array = []
	var placed: Array = []               # [{pos, gap}] — gap scales with prop size
	var tries: int = 0
	# LAYOUT: chunks vary between OPEN (few props -> the horde surrounds you) and CLUSTERED (a rock
	# outcrop / nest of structures = cover, but your shots get blocked too). Density is seeded and
	# capped at 3 so cover_list stays bounded. At most ONE hazard per chunk -> turrets/pylons come
	# at a readable cadence, never a wall of them.
	var dr: float = rng.randf()
	# No empty chunks any more (was 16% empty -> dead stretches you could run through unthreatened).
	# Denser average, same max of 3 so cover_list stays bounded (3x3 chunks -> <=27 props).
	var want: int = 1 if dr < 0.22 else (2 if dr < 0.60 else 3)
	var clustered: bool = want >= 2 and rng.randf() < 0.55
	var anchor: Vector2 = origin + Vector2(rng.randf_range(lo, hi), rng.randf_range(lo, hi))
	var haz_count: int = 0   # up to TWO hazards per chunk (was one) -> cannons come thick enough to matter
	while placed.size() < want and tries < want * 10:
		tries += 1
		var pos: Vector2
		if clustered:
			var ca: float = rng.randf() * TAU
			pos = anchor + Vector2(cos(ca), sin(ca)) * rng.randf_range(40.0, 210.0)
			pos.x = clampf(pos.x, origin.x + lo, origin.x + hi)
			pos.y = clampf(pos.y, origin.y + lo, origin.y + hi)
		else:
			pos = origin + Vector2(rng.randf_range(lo, hi), rng.randf_range(lo, hi))
		if pos.distance_to(ppos) < CLEAR_R:
			continue                     # never spawn a prop on the player (spawn is at origin)
		var kind: String = _pick_kind(kinds, rng)
		if HAZARDS.has(kind):            # cap hazards per chunk -> swap extras for a harmless prop
			if haz_count >= 2:
				kind = _nonhazard(kinds)
			else:
				haz_count += 1
		# footprint radius: big props need far more room so their enemy-repulsion bubbles never overlap.
		# 04/10, lisibilite signalee par le patron : brouillard_froid/nuage_spores masquent leur
		# sprite de base (sz=20, quasi nul) et affichent UNIQUEMENT un nuage procedural bien plus
		# grand (fog_r/spore_r * 2.2, ~500-600 unites) - l'espacement calcule sur le seul "sz"
		# laissait donc poser d'autres decors presque DANS le nuage, illisible. Utilise le plus
		# grand des deux (generalise a tout futur "nuage procedural", pas un cas particulier fige).
		var gap: float = _gap_of(kind)
		var ok: bool = true
		for e in placed:
			if pos.distance_to(e["pos"]) < gap + float(e["gap"]):
				ok = false; break
		if not ok:
			continue
		placed.append({"pos": pos, "gap": gap})
		# Draw the seeded variation ALWAYS, before deciding to skip: bailing out early would leave
		# the RNG stream shifted and every later prop in the chunk would move.
		var rs: float = rng.randf_range(0.86, 1.16)
		var sr: float = rng.randf()
		var fl: bool = rng.randf() < 0.5
		if _destroyed.has(Vector2i(pos.round())):
			continue                     # smashed earlier this run — the spot stays empty
		made.append(_place(kind, pos, rs, sr, fl))
		# 14/10 (patron : decors « sans effet ») : une console/vanne/radiateur n'agit que sur SA cible
		# a portee (tapis, bassin, turbine, nuage). Avec 2-3 props par chunk de 1000 unites, la
		# cible se trouvait rarement a moins de 400 unites -> la console ne faisait jamais rien.
		# On pose donc toujours une cible juste a cote (rng DEDIE : ne decale pas le flux du chunk).
		if COMPANION.has(kind):
			var cp: Array = COMPANION[kind]
			var rc: RandomNumberGenerator = RandomNumberGenerator.new()
			rc.seed = hash("comp:%s:%d:%d:%d:%d" % [biome, c.x, c.y, int(pos.x), int(pos.y)])
			var cgap: float = _gap_of(String(cp[0]))
			var cdist: float = float(cp[1])
			var cpos: Vector2 = Vector2.ZERO
			var cfound: bool = false
			for _t in 16:   # meme regle d'espacement que le reste du chunk (lisibilite des nuages)
				var ang: float = rc.randf() * TAU
				var cand: Vector2 = pos + Vector2(cos(ang), sin(ang)) * cdist
				if cand.x < origin.x + 60.0 or cand.x > origin.x + CHUNK - 60.0 						or cand.y < origin.y + 60.0 or cand.y > origin.y + CHUNK - 60.0:
					continue
				if cand.distance_to(ppos) < CLEAR_R:
					continue
				var free: bool = true
				for e2 in placed:
					if e2["pos"] != pos and cand.distance_to(e2["pos"]) < cgap + float(e2["gap"]):
						free = false; break
				if free:
					cpos = cand; cfound = true; break
			var cflip: bool = rc.randf() < 0.5
			if cfound and not _destroyed.has(Vector2i(cpos.round())):
				placed.append({"pos": cpos, "gap": cgap})
				made.append(_place(String(cp[0]), cpos, 1.0, 0.5, cflip))
			elif not cfound:
				# aucune place pour la cible : un support SANS cible serait un decor « sans effet »
				# -> on le retire plutot que de le laisser inerte.
				var orphan: Node = made.pop_back()
				placed.erase(placed.back())
				orphan.queue_free()
	_chunks[c] = made

func _unload_chunk(c: Vector2i) -> void:
	for p in _chunks[c]:
		if is_instance_valid(p):
			(p as Node).queue_free()     # Prop._exit_tree pulls it out of cover_list
	_chunks.erase(c)

## Variation values are drawn by the caller so a skipped (already-destroyed) prop cannot desync
## the chunk's RNG stream.
func _place(kind: String, pos: Vector2, rand_scale: float, skill_roll: float, flip: bool) -> Prop:
	var prop: Prop = Prop.new()
	prop.game = game
	prop.kind = kind
	prop.def = DECOR.get(kind, {})
	prop.position = pos
	prop.rand_scale = rand_scale
	prop.skill_roll = skill_roll
	prop.flip = flip                   # mirrored turrets cover the opposite arc (seeded -> stable)
	add_child(prop)
	return prop

class Prop extends StaticBody2D:
	var game: Node
	var kind: String
	var def: Dictionary
	var hp: float
	var block_r: float = 40.0        # radius enemies steer around (read by Enemy)
	var rand_scale: float = 1.0      # from the chunk's seeded RNG (stable across reloads)
	var skill_roll: float = 1.0      # ditto
	var _sprite: Sprite2D
	var _skill: bool = false
	var _awaken: String = ""         # non-empty on a robot carcass: the foe it frees on approach
	var _awoken: bool = false
	var _plr: Node2D = null
	const AWAKEN_R: float = 230.0    # walk this close to the wreck and it stands up
	# hostile turret: still-online war machine that shoots the player
	var _shoot_r: float = 0.0
	var _shoot_cd: float = 1.7
	var _shoot_dmg: float = 8.0
	var _shoot_t: float = 0.0
	var _cannon: Vector2 = Vector2.RIGHT   # world direction the baked barrel actually points
	# TOURELLE PIRATABLE (plan direction artistique, 26/09 : "Secteur Tech — tourelles
	# piratables"). Affaiblie sous 40% de PV SANS mourir -> elle bascule au lieu d'exploser :
	# meme canon FIXE, meme cone, mais elle cherche desormais un ennemi dans son arc au lieu du
	# joueur. Pas de nouveau bouton d'interaction : "l'affaiblir sans l'achever" EST le geste.
	var _hp_start: float = 0.0
	var _hacked: bool = false
	const HACK_THRESHOLD: float = 0.4
	var _arc: float = 0.52                 # half-angle of the firing cone (rad)
	var _muzzle: Vector2 = Vector2.ZERO    # barrel tip, local px (already scaled)
	var flip: bool = false                 # mirrored copy -> cannon points down-RIGHT instead
	# CANON A RAYON AUTOMATIQUE A INTERVALLE REGULIER
	var _cannon_beam: bool = false
	var _cannon_beam_state: int = 0        # 0 idle, 1 telegraph/charge, 2 tir de rayon
	var _cannon_beam_t: float = 0.0
	var _cannon_beam_line: Line2D = null
	var _cannon_beam_glow: Line2D = null
	var _cannon_beam_core: Line2D = null
	var _cannon_beam_flash: Sprite2D = null
	var _cannon_hit_set: Dictionary = {}
	const CANNON_IDLE: float = 1.4
	const CANNON_TELL: float = 0.6
	const CANNON_FIRE: float = 0.35
	const CANNON_LEN: float = 2200.0
	const CANNON_HALF_W: float = 26.0
	# fuel barrel: arms when you come near, then blows. 4s is enough to walk clear on purpose —
	# so it's a TOOL (lead the horde over it) as much as a hazard.
	var _boom: bool = false
	var _armed: float = -1.0         # >=0 -> counting down
	const BOOM_ARM_R: float = 190.0
	const BOOM_FUSE: float = 4.0
	const BOOM_R: float = 250.0
	const BOOM_DMG: float = 68.0
	# --- BEACON: emits enemies until destroyed (see the DECOR entry) ---
	var _beacon: bool = false
	var _beacon_cd: float = 3.5
	var _beacon_kind: String = "drone"
	var _beacon_t: float = 0.0
	var _beacon_pulse: Sprite2D = null
	const BEACON_R: float = 1100.0    # only active while the player is near enough to see/reach it
	# --- ARC PYLON: zaps nearest enemies with lightning, EMP burst on destruction ---
	var _pylon: bool = false
	var _pylon_cd: float = 1.5
	var _pylon_dmg: float = 22.0
	var _pylon_r: float = 300.0
	var _pylon_t: float = 0.0
	# --- SLOW FIELD: persistent zone that dampens player + enemy movement ---
	var _slow: bool = false
	var _slow_r: float = 200.0
	var _slow_mult: float = 0.5
	var _slow_ring: Sprite2D = null
	# --- FIELD AURA: lave(burn) / plante(spore) / glace(frost) / racines(snare) / emetteur(heal) ---
	var _aura: String = ""
	var _aura_r: float = 160.0
	var _aura_p1: float = 10.0   # dmg-or-heal per tick, or slow-mult, depending on the kind
	var _aura_p2: float = 0.7    # secondary (spore's slow-mult)
	var _aura_ring: Sprite2D = null
	var _aura_t: float = 0.0
	const AURA_TICK: float = 0.4
	var _shatter: bool = false   # crystal: burst damaging shards on destruction
	# ===== 27/09 : six props "def-driven" supplementaires, meme idiome que arc/slow/aura ci-dessus =====
	# IMPULSION (Gravite faible) : pousse joueur+ennemis dans UN axe fixe (seede, comme le beam du
	# capaciteur), a intervalle. Jamais de degats — un choix entre securite et raccourci.
	var _push: bool = false
	var _push_cd: float = 3.2
	var _push_force: float = 380.0
	var _push_r: float = 260.0
	var _push_t: float = 0.0
	var _push_dir: Vector2 = Vector2.RIGHT
	var _push_ring: Sprite2D = null
	# AIMANT (Casse magnetique) : repousse les ennemis proches QUAND le joueur est pres du prop —
	# un outil defensif de positionnement, pas une invincibilite.
	var _guard: bool = false
	var _guard_r: float = 170.0
	var _guard_cd: float = 3.5
	var _guard_force: float = 300.0
	var _guard_t: float = 0.0
	var _guard_ring: Sprite2D = null
	# TERMINAL (Terminal de delestage) : DwellZone (rester pres du module remplit une jauge) ->
	# onde qui repousse les petits ennemis proches. "Quitter le rayon annule" deja gere par DwellZone.
	var _dwell: bool = false
	var _dwell_zone: DwellZone = null
	var _dwell_force: float = 260.0
	# ARCHIVES (Archives-machines) : marque periodiquement l'ennemi le plus proche avec
	# priority_boost (Player._nearest_enemy/_cone_target le preferent), SANS bonus de degats.
	var _spot: bool = false
	var _spot_r: float = 340.0
	var _spot_boost: float = 0.55
	var _spot_hold: float = 3.0
	var _spot_t: float = 0.0
	var _spot_marked: Enemy = null
	var _spot_beam: Line2D = null
	# QUAI (Quai de chargement) : caisse-ecran qui alterne presente/absente sur un cycle fixe —
	# une couverture qui a un debut et une fin, pas une permanente.
	var _cycle: bool = false
	var _cycle_on: float = 6.0
	var _cycle_off: float = 3.0
	var _cycle_t: float = 0.0
	var _cycle_present: bool = true
	var _cycle_col: CollisionShape2D = null
	# CONVOYEUR (Chaine de fonderie) : deplace les ennemis proches d'une courte distance le long
	# d'un axe fixe. Precedent deja valide en jeu par le comportement "pusher" (Enemy.gd) : une
	# nudge externe de global_position compose sans conflit, chaque ennemi redérive son
	# desired_vel depuis sa position COURANTE a chaque frame. Ne JAMAIS l'ajouter a cover_list :
	# cette liste sert aux ennemis a se repousser HORS des props, ca annulerait sa propre nudge.
	var _convey: bool = false
	var _convey_r: float = 200.0
	var _convey_cd: float = 2.2
	var _convey_dist: float = 90.0
	var _convey_t: float = 0.0
	var _convey_dir: Vector2 = Vector2.RIGHT

	# ===== 30/09, refonte decor "Secteur Tech" (plan 15 maps, maps 1-3 fusionnees en un seul
	# decor enrichi pour le biome "tech" - voir le plan). Memes idiomes que les mecaniques
	# ci-dessus (nudge direct de global_position, DwellZone, _cycle, spawn_ground_zone depuis un
	# timer comme le boss _phase_crusher) : aucun nouveau moteur generique. =====

	# CONVOYEUR SOL (Hall d'Assemblage) : pousse le JOUEUR et les ennemis en continu tant qu'ils
	# restent dans le rayon - meme nudge que IMPULSION mais CHAQUE frame au lieu d'un burst a
	# intervalle. Une CONSOLE voisine peut le couper temporairement.
	var _conveyor: bool = false
	var _conveyor_r: float = 160.0
	var _conveyor_speed: float = 75.0
	var _conveyor_dir: Vector2 = Vector2.RIGHT
	var _conveyor_stop_t: float = 0.0   # >0 = coupe, decremente chaque frame ; pose par une console
	var _conveyor_vfx_t: float = 0.0    # pulse periodique via FxKit
	var _conveyor_ring: Sprite2D = null # disque de zone centre au sol pour le tapis ralentisseur
	var _conveyor_edge: Sprite2D = null # bord net de la zone (meme rayon que l'effet)

	# CONSOLE DE CONVOYEUR (Hall d'Assemblage) : DwellZone DEDIEE (pas celle de "terminal", pour
	# ne jamais risquer de mélanger les deux comportements) -> coupe les convoyeurs proches 8s.
	# Cooldown en float decremente chaque frame, comme toutes les autres mecaniques du fichier
	# (_push_t/_guard_t/...) — donc _console rejoint le set_process plus bas.
	var _console: bool = false
	var _console_r: float = 400.0
	var _console_stop_dur: float = 8.0
	var _console_cd: float = 25.0
	var _console_cd_t: float = 0.0
	var _console_zone: DwellZone = null

	# BRAS PRESSEUR (Hall d'Assemblage) : GroundZone en LIGNE a intervalle aleatoire, meme idiome
	# que le boss _phase_crusher (Enemy.gd:899-910) qui appelle deja spawn_ground_zone depuis un
	# timer. Stun court via Player.stun(), jamais de knockback (aucune API de knockback joueur
	# n'existe dans ce projet, voir le plan).
	var _presser: bool = false
	var _presser_t: float = 0.0
	var _presser_len: float = 240.0
	var _presser_dmg: float = 15.0
	var _presser_stun: float = 0.5
	var _presser_dir: Vector2 = Vector2.RIGHT

	# VANNE DE REFROIDISSEMENT (Fonderie) : DwellZone DEDIEE -> ouvre une zone sure temporaire
	# (GroundZone a 0 degat, sert de repere visuel + petit repit). Le "contre-effet" qui
	# surchauffe une autre zone (propose par le document) est HORS SCOPE : ca demanderait une
	# coordination entre deux zones distantes, ecarte pour la stabilite (voir le plan).
	var _valve: bool = false
	var _valve_r: float = 150.0
	var _valve_cd: float = 30.0
	var _valve_cd_t: float = 0.0
	var _valve_zone: DwellZone = null

	# SURCHAUFFE DU SOL (Fonderie) : re-spawn une GroundZone un peu plus grande toutes les ~2s
	# jusqu'a un rayon max - simule une croissance SANS vraie persistance (GroundZone.gd ne peut
	# pas durer indefiniment, voir le plan).
	var _overheat: bool = false
	var _overheat_t: float = 0.0
	var _overheat_r: float = 70.0
	var _overheat_max: float = 260.0

	# ZONE DE CHARGEMENT (Quai de chargement) : cercle telegraphie classique a intervalle, aucune
	# nouveaute au-dela d'un appel periodique a spawn_ground_zone.
	var _dropzone: bool = false
	var _dropzone_t: float = 0.0

	# CONTAINER MOBILE (Quai de chargement) : seule piece reellement NEUVE de ce plan - translate
	# entre 2 points sur un rail fixe. Reste un StaticBody2D statique au sens Godot (jamais
	# move_and_slide) : rien d'autre dans ce fichier ne deplace un prop par la physique, donc une
	# simple interpolation de position reste l'option la plus previsible.
	var _rail: bool = false
	var _rail_span: float = 220.0
	var _rail_speed: float = 15.0
	var _rail_dir: Vector2 = Vector2.RIGHT
	var _rail_inited: bool = false
	var _rail_origin: Vector2 = Vector2.ZERO
	var _rail_t: float = 0.0        # 0..1 le long du rail
	var _rail_fwd: bool = true

	# ===== 03/10, refonte decor "Zone Cryo" (plan 15 maps, maps 4-6, nouveau biome "cryo") :
	# memes idiomes que le Secteur Tech ci-dessus. Deux vraies nouveautes assumees dans le plan
	# (brouillard qui derive librement, glace fragile qui devient permanente) ; le reste calque
	# un precedent deja prouve. =====

	# PLAQUE DE GLACE (Cryo-Voute) : glisse - ecrit Player._patch_inertia (canal dedie, voir
	# Player.gd) chaque frame tant que le joueur reste dans le rayon, meme idiome que _slow qui
	# ecrit field_slow. Walkable ("block":0 dans la DECOR entry) : ce n'est pas un obstacle
	# comme les "glace"/"lave" existants (qui sont des rochers solides, pas des flaques au sol).
	var _ice_patch: bool = false
	var _ice_patch_r: float = 130.0
	var _ice_patch_amt: float = 0.8
	var _ice_patch_ring: Sprite2D = null

	# CAPSULE CRYOGENIQUE (Cryo-Voute) : destruction-hook, voir take_damage() plus bas.
	var _capsule: bool = false

	# JET DE CRYO (Cryo-Voute) : meme idiome que bras_presseur (Secteur Tech) - un emetteur
	# decoratif qui spawn periodiquement une GroundZone (cercle + stun, pas la forme ligne).
	var _cryo_jet: bool = false
	var _cryo_jet_t: float = 0.0
	var _cryo_jet_r: float = 70.0
	var _cryo_jet_stun: float = 1.0

	# BROUILLARD FROID (Serres Gelees) : SEULE vraie nouveaute de mouvement de cette phase -
	# derive en ligne droite et change de direction a intervalle aleatoire (contrairement au
	# rail a 2 points fixes de container_mobile). Sprite procedural (meme helper _glow_sprite
	# que les autres champs/auras) : aucun nouvel asset necessaire pour cette mecanique.
	var _fog: bool = false
	var _fog_r: float = 260.0
	var _fog_dir: Vector2 = Vector2.RIGHT
	var _fog_retarget_t: float = 0.0
	var _fog_sprite: Sprite2D = null
	var _fog_alpha_mult: float = 1.0   # reduit localement par un radiateur proche

	# RADIATEUR (Serres Gelees) : a portee, reduit l'alpha du brouillard le plus proche - meme
	# idiome que console_convoyeur qui parcourt un groupe de props voisins (ici "cryo_fog").
	var _defroster: bool = false
	var _defroster_r: float = 180.0
	var _defroster_ring: Sprite2D = null   # 04/10, WEAK signale par le patron : rien ne se voyait
	                                        # sur le radiateur lui-meme quand il agissait

	# PIC DE GLACE (Serres Gelees) : meme idiome que bras_presseur/surchauffe_sol - cercle
	# classique a intervalle (pas de forme ligne), degats + ralentissement court (field_slow,
	# aucune nouveaute).
	var _ice_spike: bool = false
	var _ice_spike_t: float = 0.0

	# BORNE THERMIQUE (Lac de Permafrost) : calque exact de vanne_refroidissement (DwellZone
	# dediee).
	var _thermal: bool = false
	var _thermal_r: float = 150.0
	var _thermal_cd: float = 25.0
	var _thermal_cd_t: float = 0.0
	var _thermal_zone: DwellZone = null

	# GLACE FRAGILE (Lac de Permafrost) : simplification assumee dans le plan - PAS un vrai
	# compteur de passages : sur un timer, la glace cede et devient un obstacle PERMANENT pour
	# le reste de cette map. Reutilise exactement le motif _cycle_col ("quai") - une collision
	# qui lui appartient deja, juste activee une fois pour de bon au lieu d'alterner.
	var _fragile_ice: bool = false
	var _fragile_ice_t: float = 0.0
	var _fragile_broken: bool = false

	# ===== 03/10, refonte decor "Noyau Instable" (plan 15 maps, maps 7-9, nouveau biome
	# "reacteur"). Memes idiomes que Zone Cryo/Secteur Tech ci-dessus. =====

	# BASSIN TOXIQUE (Bassins Toxiques) : zone de sol marchable a degats continus, meme idiome
	# que plaque_de_glace (ecrit un champ tant que le joueur est dedans) mais degat au lieu de
	# glisse. Une vanne de drainage proche peut la suspendre temporairement.
	var _toxic_pool: bool = false
	var _toxic_r: float = 150.0
	var _toxic_dps: float = 6.0
	var _toxic_suppressed_t: float = 0.0
	var _toxic_ring: Sprite2D = null

	# VANNE DE DRAINAGE (Bassins Toxiques) : DwellZone dediee -> suspend les bassins voisins,
	# meme idiome que console_convoyeur qui parcourt un groupe de props voisins.
	var _drain: bool = false
	var _drain_r: float = 250.0
	var _drain_cd: float = 25.0
	var _drain_cd_t: float = 0.0
	var _drain_zone: DwellZone = null

	# POCHE DE VENT (Salle des Turbines, simplifiee en zone locale plutot qu'une force globale
	# sur toute l'arene + les projectiles - cf. le plan, stabilite avant fidelite) : pousse le
	# joueur et les ennemis en continu dans un axe, meme idiome que convoyeur_sol.
	var _wind: bool = false
	var _wind_r: float = 220.0
	var _wind_speed: float = 50.0
	var _wind_dir: Vector2 = Vector2.RIGHT

	# CONSOLE DE VENT (Salle des Turbines) : DwellZone dediee -> inverse la direction des poches
	# de vent voisines, meme idiome que console_convoyeur.
	var _wind_console: bool = false
	var _wind_console_r: float = 400.0
	var _wind_console_cd: float = 15.0
	var _wind_console_cd_t: float = 0.0
	var _wind_console_zone: DwellZone = null

	# GRILLE DE VENTILATION (Salle des Turbines) : cercle classique a intervalle, meme idiome
	# que bras_presseur/pic_de_glace, stun au lieu de degats de ligne.
	var _vent_grate: bool = false
	var _vent_grate_t: float = 0.0

	# ZONE ALTERNANTE (Noyau Fissure) : bascule sure/dangereuse sur un cycle fixe, reutilise
	# EXACTEMENT _cycle (meme pattern que piston_hydraulique/porte_automatique) pour le on/off,
	# plus un tick de degats pendant la phase "danger".
	var _alt_zone: bool = false
	var _alt_zone_r: float = 100.0
	var _alt_zone_dps: float = 10.0
	var _alt_warn_ring: Sprite2D = null   # 04/10, WEAK signale par le patron : le sprite est MASQUE
	                                       # pendant la phase sure (_sprite.visible=_cycle_present),
	                                       # donc le clignoter lui-meme ne marche pas - anneau dedie,
	                                       # ignore le masquage, qui rampe dans la derniere seconde
	                                       # avant le basculement en danger (meme idiome que le baril)

	# CRISTAL D'ENERGIE INSTABLE (Noyau Fissure) : ramasse au contact (DwellZone a fill_time
	# quasi nul), puis explose apres un delai - combine proximite + le timer de surchauffe_sol.
	var _unstable_crystal: bool = false
	var _crystal_zone: DwellZone = null
	var _crystal_armed: bool = false
	var _crystal_t: float = 0.0

	# PULSE D'ENERGIE (Noyau Fissure) : anneau qui "s'etend" - meme idiome que surchauffe_sol
	# (respawn une GroundZone un peu plus grande a chaque tick, pas de vraie persistance).
	var _energy_pulse: bool = false
	var _energy_pulse_t: float = 0.0

	# ===== 03/10, refonte decor "Biomecanique" (plan 15 maps, maps 10-12, nouveau biome
	# "ruche"). Memes idiomes que ci-dessus. =====

	# COCON (Couvoir Mecanique) : destruction-hook - reutilise DIRECTEMENT le flag "capsule"
	# (meme comportement exact que capsule_cryogenique, voir sa DECOR entry), pas de nouveau
	# champ necessaire.

	# SOL COLLANT (Veines Vivantes) : ralentit le joueur en continu, reutilise DIRECTEMENT
	# field_slow (meme canal que le champ de ralentissement _slow deja en jeu, pas besoin d'un
	# canal dedie comme pour inertia - field_slow se relache deja tout seul chaque frame).
	var _sticky: bool = false
	var _sticky_r: float = 150.0
	var _sticky_mult: float = 0.45
	var _sticky_ring: Sprite2D = null

	# 03/10 RESIDU BIOMECANIQUE (Couvoir Mecanique, Map 10) : distinct de sol_collant (Map 11) -
	# signale par le patron apres verif contre le doc source, les deux etaient fusionnees a tort.
	# Ralentit le joueur (field_slow, meme canal que _sticky) ET attire en continu les ennemis
	# proches vers son centre (meme math que _guard/AIMANT mais direction inversee et en continu,
	# pas a cooldown - un piege organique, pas une pulsation).
	var _bio_residue: bool = false
	var _bio_residue_r: float = 150.0
	var _bio_residue_slow: float = 0.6
	var _bio_residue_pull: float = 40.0
	var _bio_residue_ring: Sprite2D = null

	# EMERGENCE DE TENTACULE (Veines Vivantes) : cercle classique a intervalle, meme idiome que
	# bras_presseur/pic_de_glace/grille_ventilation.
	var _tentacle: bool = false
	var _tentacle_t: float = 0.0

	# NUAGE DE SPORES (Jardin de Spores) : derive comme brouillard_froid + degats continus comme
	# bassin_toxique - combine les deux idiomes deja prouves, aucune nouveaute de mouvement.
	var _spore_cloud: bool = false
	var _spore_r: float = 220.0
	var _spore_dir: Vector2 = Vector2.RIGHT
	var _spore_retarget_t: float = 0.0
	var _spore_dps: float = 5.0
	var _spore_sprite: Sprite2D = null
	var _spore_suppressed_t: float = 0.0

	# PLANTE LUMINEUSE (Jardin de Spores) : DwellZone dediee -> dissipe les nuages de spores
	# voisins, meme idiome que radiateur (dissipe le brouillard) / vanne_drainage.
	var _light_plant: bool = false
	var _light_plant_r: float = 180.0
	var _light_plant_cd: float = 15.0
	var _light_plant_cd_t: float = 0.0
	var _light_plant_zone: DwellZone = null

	# ===== 03/10, refonte decor "Forge Finale" (plan 15 maps, maps 13-15, nouveau biome
	# "citadelle"). Memes idiomes que ci-dessus. =====

	# PORTE DE SECURITE ORBITALE (Pont Orbital) : reutilise EXACTEMENT _cycle, comme
	# porte_automatique (Secteur Tech). Pas de controle manuel (simplification deja faite pour
	# vanne_refroidissement/le "contre-effet" - meme principe).

	# ZONE DE DEPRESSURISATION (Pont Orbital) : aspire le joueur PERIODIQUEMENT vers son centre -
	# meme idiome que _push (Secteur Tech "impulsion") mais direction INVERSEE (vers soi, pas loin).
	var _depress: bool = false
	var _depress_t: float = 0.0
	var _depress_r: float = 200.0
	var _depress_warn: Sprite2D = null   # 04/10, WEAK signale par le patron : l'aspiration et son
	                                      # VFX arrivaient dans la MEME frame, aucune alarme avant
	var _depress_force: float = 220.0

	# ZONE PUSH/PULL (Anneau de Gravite) : pousse ou attire en CONTINU selon la phase - minuteur
	# INDEPENDANT (_grav_phase_on/_grav_phase_t, 04/10) plutot que de partager _cycle (voir le
	# commentaire dans _ready : partager _cycle masquait le sprite pendant la moitie "attire").
	var _grav_zone: bool = false
	var _grav_r: float = 180.0
	var _grav_force: float = 60.0
	var _grav_phase_on: bool = true
	var _grav_phase_t: float = 0.0
	var _grav_on_dur: float = 4.0
	var _grav_off_dur: float = 4.0

	# EMETTEUR DE LASER ROTATIF (Anneau de Gravite) : meme idiome que bras_presseur/jet_de_cryo
	# (GroundZone en ligne spawnee a intervalle), mais l'angle AVANCE a chaque tir -> balayage
	# qui tourne au fil des activations, sans vrai objet "laser continu" a animer.
	var _rot_laser: bool = false
	var _rot_laser_t: float = 0.0
	var _rot_laser_angle: float = 0.0

	# PILIER D'ENERGIE (Chambre de la Forge) : destruction-hook qui repousse les ennemis proches
	# avant de se detruire normalement - reutilise le nudge de _on_dwell_filled ("terminal").
	var _pillar: bool = false

	# SEGMENT DE MUR MODULAIRE (Chambre de la Forge) : reutilise EXACTEMENT _cycle avec un
	# "block" solide (pas 0 comme les zones de sol) - simplification assumee dans le plan : un
	# mur qui apparait/disparait, pas une vraie reconfiguration dynamique de la geometrie de
	# l'arene (chantier a part entiere, hors scope decor).

	# ===== Bible des niveaux — Niveau 1 (tech) =====
	var _welder: bool = false
	var _sweep_half: float = 0.785398
	var _welder_dmg: float = 28.0

	var _gantry: bool = false
	var _gantry_cd: float = 6.0
	var _gantry_t: float = 0.0
	var _gantry_tell: float = 1.2
	var _gantry_len: float = 240.0
	var _gantry_dmg: float = 22.0
	var _gantry_dir: Vector2 = Vector2.RIGHT

	# ===== Bible des niveaux — Niveau 2 (desert) =====
	var _solar_mirror: bool = false
	var _solar_dmg: float = 32.0
	var _solar_charge: float = 1.8
	var _burn_trail: float = 3.0

	var _storm_gen: bool = false
	var _storm_cd: float = 9.0
	var _storm_t: float = 0.0
	var _storm_dur: float = 8.0
	var _storm_speed: float = 40.0
	var _storm_dmg: float = 12.0

	var _sinkhole: bool = false
	var _sinkhole_r: float = 150.0
	var _sinkhole_pull: float = 55.0
	var _sinkhole_slow: float = 0.5
	var _sinkhole_ring: Sprite2D = null

	var _solar_collector: bool = false
	var _collector_cd: float = 40.0
	var _collector_cd_t: float = 0.0
	var _collector_zone: DwellZone = null

	var _mirage: bool = false
	var _mirage_cd: float = 20.0
	var _mirage_cd_t: float = 0.0
	var _mirage_dur: float = 6.0
	var _mirage_active_t: float = 0.0
	var _mirage_r: float = 340.0
	var _mirage_zone: DwellZone = null

	var _sandworm: bool = false
	var _sandworm_r: float = 220.0
	var _sandworm_tell: float = 1.0
	var _sandworm_dmg: float = 25.0
	var _sandworm_t: float = 0.0

	var _fumerolle: bool = false
	var _fumerolle_cd: float = 5.0
	var _fumerolle_t: float = 0.0
	var _fumerolle_r: float = 120.0
	var _fumerolle_dmg: float = 15.0
	var _fumerolle_push: float = 300.0

	# ===== Bible des niveaux — Niveau 3 (La Ruine Verte / jungle) =====
	var _plant_mortar: bool = false
	var _mortar_cd: float = 4.5
	var _mortar_t: float = 0.0
	var _mortar_dmg: float = 26.0
	var _mortar_r: float = 90.0

	var _whip_vine: bool = false
	var _whip_cd: float = 5.0
	var _whip_t: float = 0.0
	var _whip_dmg: float = 22.0
	var _whip_r: float = 160.0
	var _whip_arc: float = 120.0
	var _whip_aim: float = 0.0

	var _catapult: bool = false
	var _catapult_dist: float = 300.0
	var _catapult_cd: float = 3.0
	var _catapult_cd_t: float = 0.0

	var _lasso: bool = false
	var _lasso_snare: float = 1.5
	var _lasso_cd: float = 8.0
	var _lasso_cd_t: float = 0.0
	var _lasso_r: float = 85.0

	var _fireflies: bool = false
	var _heal_dps: float = 3.0
	var _firefly_r: float = 110.0
	var _firefly_dur: float = 10.0
	var _firefly_life: float = 10.0
	var _firefly_cd_t: float = 0.0

	# ===== Bible des niveaux — Niveau 4 (La Forge / volcanic) =====
	var _slag_mortar: bool = false
	var _smortar_cd: float = 5.0
	var _smortar_t: float = 0.0
	var _smortar_dmg: float = 28.0
	var _smortar_r: float = 95.0

	var _magma_vent: bool = false
	var _vent_cd: float = 4.5
	var _vent_t: float = 0.0
	var _vent_tell: float = 1.2
	var _vent_dmg: float = 20.0
	var _vent_r: float = 110.0

	var _power_hammer: bool = false
	var _hammer_cd: float = 7.0
	var _hammer_t: float = 0.0
	var _hammer_tell: float = 1.4
	var _hammer_dmg: float = 35.0
	var _hammer_r: float = 140.0

	var _crucible: bool = false
	var _crucible_cd: float = 6.0
	var _crucible_t: float = 0.0
	var _crucible_tell: float = 1.2
	var _crucible_dmg: float = 24.0
	var _crucible_len: float = 260.0
	var _crucible_dir: Vector2 = Vector2.DOWN

	var _quench_pool: bool = false
	var _quench_r: float = 120.0
	var _quench_cd: float = 15.0
	var _quench_cd_t: float = 0.0

	var _scrap_magnet: bool = false
	var _magnet_r: float = 450.0

	var _ember_bellows: bool = false
	var _bellows_cd: float = 5.5
	var _bellows_t: float = 0.0
	var _bellows_tell: float = 1.0
	var _bellows_r: float = 170.0
	var _bellows_dmg: float = 18.0
	var _bellows_dir: Vector2 = Vector2.RIGHT

	# ===== Bible des niveaux — Niveau 5 (La Cité Déchue / swamp) =====
	var _flak_turret: bool = false
	var _flak_cd: float = 5.0
	var _flak_t: float = 0.0
	var _flak_dmg: float = 18.0
	var _flak_r: float = 110.0

	var _flood_gate: bool = false
	var _gate_cd: float = 6.0
	var _gate_t: float = 0.0
	var _gate_tell: float = 1.5
	var _gate_dmg: float = 22.0
	var _gate_len: float = 400.0
	var _gate_w: float = 120.0
	var _gate_push: float = 380.0
	var _gate_dir: Vector2 = Vector2.DOWN

	var _swamp_drain_valve: bool = false
	var _swamp_drain_r: float = 130.0
	var _swamp_drain_dur: float = 10.0
	var _swamp_drain_cd: float = 25.0
	var _swamp_drain_t: float = 0.0
	var _swamp_drain_dwell: float = 0.0

	var _floating_mine: bool = false
	var _mine_trigger_r: float = 160.0
	var _mine_dmg: float = 35.0
	var _mine_boom_r: float = 140.0
	var _mine_beep_t: float = 0.0
	var _mine_armed: bool = false

	var _searchlight: bool = false
	var _searchlight_cd: float = 4.0
	var _searchlight_t: float = 0.0
	var _searchlight_r: float = 280.0

	var _radio_jammer: bool = false
	var _jammer_r: float = 300.0

	# ===== Bible des niveaux — Niveau 6 (Le Cryo-Laboratoire / cryo) =====
	var _nitrogen_cannon: bool = false
	var _ncannon_cd: float = 4.5
	var _ncannon_t: float = 0.0
	var _ncannon_dmg: float = 24.0
	var _ncannon_r: float = 100.0

	var _frost_condenser: bool = false
	var _condenser_cd: float = 6.0
	var _condenser_t: float = 0.0
	var _condenser_r: float = 250.0

	var _teleporter: bool = false
	var _teleport_cd: float = 6.0
	var _teleport_t: float = 0.0
	var _teleport_r: float = 80.0

	var _regen_ice_wall: bool = false
	var _regen_time: float = 10.0
	var _regen_t: float = 0.0

	# ===== Bible des niveaux — Niveau 7 (Le Noyau Instable / reacteur) =====
	var _particle_cannon: bool = false
	var _pcannon_cd: float = 4.0
	var _pcannon_t: float = 0.0
	var _pcannon_dmg: float = 22.0
	var _pcannon_r: float = 350.0

	var _tesla_coil: bool = false
	var _tesla_cd: float = 3.0
	var _tesla_t: float = 0.0
	var _tesla_r: float = 300.0

	var _control_rod: bool = false
	var _control_rod_r: float = 120.0
	var _control_rod_t: float = 0.0
	var _control_rod_active_t: float = 0.0

	var _containment_cell: bool = false
	var _containment_r: float = 220.0
	var _containment_cd: float = 25.0
	var _containment_cd_t: float = 0.0
	var _containment_active_t: float = 0.0

	# ===== Bible des niveaux — Niveau 8 (La Ruche / ruche) =====
	var _acid_turret: bool = false
	var _acid_cd: float = 4.5
	var _acid_t: float = 0.0
	var _acid_r: float = 320.0

	var _spawner_egg: bool = false
	var _egg_spawn_cd: float = 5.0
	var _egg_spawn_t: float = 0.0

	var _vein_pulse: bool = false
	var _vein_cd: float = 3.0
	var _vein_t: float = 0.0
	var _vein_r: float = 250.0
	var _vein_force: float = 180.0

	var _acid_bladder: bool = false

	# ===== Bible des niveaux — Niveau 9 (La Citadelle Orbitale / citadelle) =====
	var _guided_launcher: bool = false
	var _glauncher_cd: float = 5.0
	var _glauncher_t: float = 0.0
	var _glauncher_dmg: float = 25.0
	var _glauncher_r: float = 400.0

	var _satellite_relay: bool = false
	var _srelay_cd: float = 6.0
	var _srelay_t: float = 0.0
	var _srelay_r: float = 350.0

	var _airlock: bool = false
	var _airlock_cd: float = 6.0
	var _airlock_t: float = 0.0
	var _airlock_open: bool = false

	var _dome_shield: bool = false
	var _dome_r: float = 200.0
	var _dome_cd: float = 20.0
	var _dome_cd_t: float = 0.0
	var _dome_active_t: float = 0.0

	var _magnetic_hook: bool = false
	var _hook_r: float = 250.0
	var _hook_force: float = 120.0
	var _hook_cd: float = 4.0
	var _hook_t: float = 0.0

	# --- CAPACITEUR: neutral sweeping beam (see the DECOR entry for the design intent) ---
	var _beam: bool = false
	var _beam_dir: Vector2 = Vector2.RIGHT   # ONE fixed cardinal, chosen at build from the seed
	var _beam_dmg: float = 45.0
	var _beam_dmg_enemy: float = 170.0
	var _beam_state: int = 0                 # 0 idle, 1 telegraph, 2 firing
	var _beam_t: float = 0.0
	var _beam_line: Line2D = null    # mid layer: the coloured beam body
	var _beam_glow: Line2D = null    # wide additive halo under the body
	var _beam_core: Line2D = null    # white-hot thin core over the body
	var _beam_flash: Sprite2D = null # muzzle bloom at the emitter while firing
	const BEAM_IDLE: float = 4.4             # fixed cadence — learnable, never random
	const BEAM_TELL: float = 1.25            # well above mobile reaction time (~250 ms)
	const BEAM_FIRE: float = 0.4
	const BEAM_LEN: float = 2400.0           # crosses the screen on any aspect
	const BEAM_HALF_W: float = 26.0          # damage half-width (visual is a touch thinner)
	const BEAM_COL: Color = Color(1.0, 0.25, 0.85)   # magenta: unused by player shots (cyan/violet)
	                                                  # and by enemy bolts (orange/red)

	func _ready() -> void:
		hp = float(def.get("hp", 60.0))
		_hp_start = hp
		_awaken = String(def.get("awaken", ""))
		_boom = bool(def.get("boom", false))
		_shoot_r = float(def.get("shoot", 0.0))
		_shoot_cd = float(def.get("shoot_cd", 1.7))
		_shoot_dmg = float(def.get("shoot_dmg", 8.0))
		_shoot_t = randf() * _shoot_cd     # desync turrets so they never volley in unison
		_arc = deg_to_rad(float(def.get("arc", 30.0)))
		_beacon = bool(def.get("beacon", false))
		if _beacon:
			_beacon_cd = float(def.get("beacon_cd", 3.5))
			_beacon_kind = String(def.get("beacon_kind", "drone"))
			_beacon_t = randf() * _beacon_cd   # desync so beacons don't all emit on the same frame
			# a slow red pulse ring reads as "this is producing enemies — take it out"
			_beacon_pulse = _glow_sprite(Color(1.0, 0.3, 0.2), float(def.get("sz", 120.0)) * 1.6, 0.0)
			add_child(_beacon_pulse)
			_core_child(_beacon_pulse, Color(1.0, 0.3, 0.2))
		_beam = bool(def.get("beam", false))
		if _beam:
			_beam_dmg = float(def.get("beam_dmg", 45.0))
			_beam_dmg_enemy = float(def.get("beam_dmg_enemy", 170.0))
			# axis from the chunk seed (skill_roll) -> the same emitter always sweeps the same way,
			# so a returning player can rely on what they learned
			_beam_dir = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][int(skill_roll * 4.0) % 4]
			_beam_t = randf() * BEAM_IDLE      # desync so emitters never fire in unison
			_beam_glow = _mk_beam(29)          # wide additive halo (under)
			_beam_line = _mk_beam(30)          # coloured beam body
			_beam_core = _mk_beam(31)          # white-hot core (over)
			_beam_flash = Sprite2D.new()       # emitter muzzle bloom while firing
			_beam_flash.texture = Tex.glow(BEAM_COL, 128)
			_beam_flash.material = Tex.add_mat()
			_beam_flash.top_level = true
			_beam_flash.z_index = 31
			_beam_flash.visible = false
			add_child(_beam_flash)
		_pylon = bool(def.get("arc", false))
		if _pylon:
			_pylon_cd = float(def.get("arc_cd", 1.5)); _pylon_dmg = float(def.get("arc_dmg", 22.0))
			_pylon_r = float(def.get("arc_r", 300.0)); _pylon_t = randf() * _pylon_cd
		_slow = bool(def.get("slow", false))
		if _slow:
			_slow_r = float(def.get("slow_r", 200.0)); _slow_mult = float(def.get("slow_mult", 0.5))
			# persistent field ring so the zone READS on the ground (violet = distinct from magenta beam)
			_slow_ring = _glow_sprite(Color(0.55, 0.4, 1.0), _slow_r * 2.0, 0.16)
			add_child(_slow_ring)
			_core_child(_slow_ring, Color(0.55, 0.4, 1.0))
		_aura = String(def.get("aura", ""))
		if _aura != "":
			_aura_r = float(def.get("aura_r", 160.0))
			_aura_p1 = float(def.get("aura_p1", 10.0))
			_aura_p2 = float(def.get("aura_p2", 0.7))
			var arc_col: Color = {"burn": Color(1.0, 0.4, 0.12), "spore": Color(0.5, 0.95, 0.25),
				"frost": Color(0.55, 0.85, 1.0), "snare": Color(0.5, 0.9, 0.35),
				"heal": Color(0.35, 1.0, 0.5)}.get(_aura, Color.WHITE)
			_aura_ring = _glow_sprite(arc_col, _aura_r * 2.0, 0.18)
			add_child(_aura_ring)
			_core_child(_aura_ring, arc_col)
		_shatter = bool(def.get("shatter", false))
		_push = bool(def.get("push", false))
		if _push:
			_push_cd = float(def.get("push_cd", 3.2)); _push_force = float(def.get("push_force", 380.0))
			_push_r = float(def.get("push_r", 260.0)); _push_t = randf() * _push_cd
			_push_dir = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][int(skill_roll * 4.0) % 4]
			_push_ring = _glow_sprite(Color(0.5, 0.9, 1.0), _push_r * 2.0, 0.14)
			add_child(_push_ring)
			_core_child(_push_ring, Color(0.5, 0.9, 1.0))
		_guard = bool(def.get("guard", false))
		if _guard:
			_guard_r = float(def.get("guard_r", 170.0)); _guard_cd = float(def.get("guard_cd", 3.5))
			_guard_force = float(def.get("guard_force", 300.0)); _guard_t = randf() * _guard_cd
			_guard_ring = _glow_sprite(Palette.CYAN, _guard_r * 2.0, 0.14)
			add_child(_guard_ring)
			_core_child(_guard_ring, Palette.CYAN)
		_dwell = bool(def.get("dwell", false))
		if _dwell:
			_dwell_force = float(def.get("dwell_force", 260.0))
			_dwell_zone = DwellZone.new()
			_dwell_zone.radius = float(def.get("dwell_r", 100.0))
			_dwell_zone.fill_time = float(def.get("dwell_time", 1.2))
			_dwell_zone.col = Palette.CYAN
			_dwell_zone.filled.connect(_on_dwell_filled)
			add_child(_dwell_zone)
		_spot = bool(def.get("spot", false))
		if _spot:
			_spot_r = float(def.get("spot_r", 340.0)); _spot_boost = float(def.get("spot_boost", 0.55))
			_spot_hold = float(def.get("spot_hold", 3.0))
			_spot_beam = _mk_beam(6)
			_spot_beam.width = 10.0
			_spot_beam.default_color = Color(0.4, 0.9, 1.0, 0.35)
		_cycle = bool(def.get("cycle", false))
		if _cycle:
			_cycle_on = float(def.get("cycle_on", 6.0)); _cycle_off = float(def.get("cycle_off", 3.0))
			_cycle_t = _cycle_on
		_convey = bool(def.get("convey", false))
		if _convey:
			_convey_r = float(def.get("convey_r", 200.0)); _convey_cd = float(def.get("convey_cd", 2.2))
			_convey_dist = float(def.get("convey_dist", 90.0)); _convey_t = randf() * _convey_cd
			_convey_dir = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][int(skill_roll * 4.0) % 4]
		_conveyor = bool(def.get("conveyor", false))
		if _conveyor:
			_conveyor_r = float(def.get("conveyor_r", 160.0))
			_conveyor_speed = float(def.get("conveyor_speed", 75.0))
			# 14/10 : le tapis poussait selon un axe CARDINAL tire au hasard alors que les chevrons du
			# dessin pointent en diagonale (bas-droite, ~31 deg) -> on glissait « de travers » par
			# rapport au tapis. Direction = celle des chevrons ; flip_h miroite dessin ET poussee.
			_conveyor_dir = Vector2(0.857, 0.515)
			if flip:
				_conveyor_dir.x = -_conveyor_dir.x
			# 14/10 (patron : « recentre et agrandis le perimetre de l'effet tapis ») : le halo additif
			# a alpha 0,14-0,22 etait INVISIBLE sur le sol clair -> on ne voyait jamais ou s'arretait
			# la zone. Disque + BORD net centres sur l'origine du tapis (= centre du dessin), au
			# rayon exact de l'effet : ce qu'on voit est ce qui agit.
			_conveyor_ring = Sprite2D.new()
			_conveyor_ring.texture = Tex.disc_tex()
			_conveyor_ring.material = Tex.add_mat()
			_conveyor_ring.scale = Vector2.ONE * (_conveyor_r * 2.0 / 128.0)
			_conveyor_ring.z_index = -1
			add_child(_conveyor_ring)
			_conveyor_edge = Sprite2D.new()
			_conveyor_edge.texture = Tex.shock_tex()
			_conveyor_edge.material = Tex.add_mat()
			_conveyor_edge.scale = Vector2.ONE * (_conveyor_r * 2.0 / 256.0)
			_conveyor_edge.z_index = -1
			add_child(_conveyor_edge)
			add_to_group("tech_convoyeur")
		_console = bool(def.get("console", false))
		if _console:
			_console_r = float(def.get("console_r", 400.0))
			_console_stop_dur = float(def.get("console_stop_dur", 8.0))
			_console_cd = float(def.get("console_cd", 25.0))
			_console_zone = DwellZone.new()
			_console_zone.radius = float(def.get("dwell_r", 90.0))
			_console_zone.fill_time = float(def.get("dwell_time", 1.0))
			_console_zone.col = Palette.CYAN
			_console_zone.filled.connect(_on_console_filled)
			add_child(_console_zone)
		_presser = bool(def.get("presser", false))
		if _presser:
			_presser_len = float(def.get("presser_len", 240.0))
			_presser_dmg = float(def.get("presser_dmg", 15.0))
			_presser_stun = float(def.get("presser_stun", 0.5))
			_presser_t = randf_range(8.0, 15.0)
			_presser_dir = [Vector2.RIGHT, Vector2.DOWN, Vector2(1, 1).normalized(), Vector2(1, -1).normalized()][int(skill_roll * 4.0) % 4]
		_valve = bool(def.get("valve", false))
		if _valve:
			_valve_r = float(def.get("valve_r", 150.0))
			_valve_cd = float(def.get("valve_cd", 30.0))
			_valve_zone = DwellZone.new()
			_valve_zone.radius = float(def.get("dwell_r", 90.0))
			_valve_zone.fill_time = float(def.get("dwell_time", 1.0))
			_valve_zone.col = Palette.CYAN
			_valve_zone.filled.connect(_on_valve_filled)
			add_child(_valve_zone)
		_overheat = bool(def.get("overheat", false))
		if _overheat:
			_overheat_max = float(def.get("overheat_max", 260.0))
			_overheat_t = randf_range(0.0, 2.0)
		_dropzone = bool(def.get("dropzone", false))
		if _dropzone:
			_dropzone_t = randf_range(10.0, 18.0)
		_rail = bool(def.get("rail", false))
		if _rail:
			_rail_span = float(def.get("rail_span", 220.0))
			_rail_speed = float(def.get("rail_speed", 15.0))
			_rail_dir = [Vector2.RIGHT, Vector2.DOWN][int(skill_roll * 2.0) % 2]
		_ice_patch = bool(def.get("ice_patch", false))
		if _ice_patch:
			_ice_patch_r = float(def.get("ice_patch_r", 130.0))
			_ice_patch_amt = float(def.get("ice_patch_amt", 0.8))
			# 04/10, GAP signale par le patron : plaque_de_glace n'avait AUCUN effet visuel (pas
			# meme le glow de base, aucune cle "glow" dans sa DECOR entry) - la glisse etait
			# invisible a l'ecran. Meme idiome que _slow_ring (anneau pulsant sur le rayon reel).
			_ice_patch_ring = _glow_sprite(Color(0.65, 0.88, 1.0), _ice_patch_r * 2.0, 0.16)
			add_child(_ice_patch_ring)
			_core_child(_ice_patch_ring, Color(0.65, 0.88, 1.0))
		_capsule = bool(def.get("capsule", false))
		_cryo_jet = bool(def.get("cryo_jet", false))
		if _cryo_jet:
			_cryo_jet_r = float(def.get("cryo_jet_r", 70.0))
			_cryo_jet_stun = float(def.get("cryo_jet_stun", 1.0))
			_cryo_jet_t = randf_range(6.0, 12.0)
		_fog = bool(def.get("fog", false))
		if _fog:
			_fog_r = float(def.get("fog_r", 260.0))
			_fog_dir = Vector2.RIGHT.rotated(randf() * TAU)
			_fog_retarget_t = randf_range(4.0, 8.0)
			if _sprite != null:
				_sprite.visible = false   # le nuage procedural est le seul visuel, pas l'icone de base
			_fog_sprite = _glow_sprite(Color(0.85, 0.92, 1.0), _fog_r * 2.2, 0.42)
			add_child(_fog_sprite)
			_core_child(_fog_sprite, Color(0.85, 0.92, 1.0))
			add_to_group("cryo_fog")
		_defroster = bool(def.get("defroster", false))
		if _defroster:
			_defroster_r = float(def.get("defroster_r", 180.0))
			_defroster_ring = _glow_sprite(Color(1.0, 0.6, 0.2), _defroster_r * 2.0, 0.0)
			add_child(_defroster_ring)
			_core_child(_defroster_ring, Color(1.0, 0.6, 0.2))
		_ice_spike = bool(def.get("ice_spike", false))
		if _ice_spike:
			_ice_spike_t = randf_range(5.0, 10.0)
		_thermal = bool(def.get("thermal", false))
		if _thermal:
			_thermal_r = float(def.get("thermal_r", 150.0))
			_thermal_cd = float(def.get("thermal_cd", 25.0))
			_thermal_zone = DwellZone.new()
			_thermal_zone.radius = float(def.get("dwell_r", 90.0))
			_thermal_zone.fill_time = float(def.get("dwell_time", 1.0))
			_thermal_zone.col = Palette.CYAN
			_thermal_zone.filled.connect(_on_thermal_filled)
			add_child(_thermal_zone)
		_fragile_ice = bool(def.get("fragile_ice", false))
		if _fragile_ice:
			_fragile_ice_t = randf_range(10.0, 20.0)
		_toxic_pool = bool(def.get("toxic_pool", false))
		if _toxic_pool:
			_toxic_r = float(def.get("toxic_r", 150.0))
			_toxic_dps = float(def.get("toxic_dps", 6.0))
			add_to_group("reacteur_toxic")
			# 04/10, GAP signale par le patron : bassin_toxique infligeait des degats CONTINUS sans
			# le moindre avertissement (pas de glow du tout). Priorite sur les 4 GAP trouves : c'est
			# le seul qui punit le joueur sans jamais le prevenir.
			_toxic_ring = _glow_sprite(Color(0.3, 1.0, 0.3), _toxic_r * 2.0, 0.18)
			add_child(_toxic_ring)
			_core_child(_toxic_ring, Color(0.3, 1.0, 0.3))
		_drain = bool(def.get("drain", false))
		if _drain:
			_drain_r = float(def.get("drain_r", 250.0))
			_drain_zone = DwellZone.new()
			_drain_zone.radius = float(def.get("dwell_r", 90.0))
			_drain_zone.fill_time = float(def.get("dwell_time", 1.0))
			_drain_zone.col = Palette.CYAN
			_drain_zone.filled.connect(_on_drain_filled)
			add_child(_drain_zone)
		_wind = bool(def.get("wind", false))
		if _wind:
			_wind_r = float(def.get("wind_r", 220.0))
			_wind_speed = float(def.get("wind_speed", 50.0))
			_wind_dir = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][int(skill_roll * 4.0) % 4]
			add_to_group("reacteur_wind")
		_wind_console = bool(def.get("wind_console", false))
		if _wind_console:
			_wind_console_r = float(def.get("wind_console_r", 400.0))
			_wind_console_zone = DwellZone.new()
			_wind_console_zone.radius = float(def.get("dwell_r", 90.0))
			_wind_console_zone.fill_time = float(def.get("dwell_time", 1.0))
			_wind_console_zone.col = Palette.CYAN
			_wind_console_zone.filled.connect(_on_wind_console_filled)
			add_child(_wind_console_zone)
		_vent_grate = bool(def.get("vent_grate", false))
		if _vent_grate:
			_vent_grate_t = randf_range(7.0, 14.0)
		_alt_zone = bool(def.get("alt_zone", false))
		if _alt_zone:
			_alt_zone_r = float(def.get("alt_zone_r", 100.0))
			_alt_zone_dps = float(def.get("alt_zone_dps", 10.0))
			_alt_warn_ring = _glow_sprite(Color(1.0, 0.55, 0.2), _alt_zone_r * 2.0, 0.0)
			add_child(_alt_warn_ring)
			_core_child(_alt_warn_ring, Color(1.0, 0.55, 0.2))
			_cycle = true   # reutilise EXACTEMENT le on/off de _cycle (voir DECOR : cycle_on/off)
			_cycle_on = float(def.get("cycle_on", 5.0)); _cycle_off = float(def.get("cycle_off", 5.0))
			_cycle_t = _cycle_on
		_unstable_crystal = bool(def.get("unstable_crystal", false))
		if _unstable_crystal:
			_crystal_zone = DwellZone.new()
			_crystal_zone.radius = float(def.get("dwell_r", 70.0))
			_crystal_zone.fill_time = 0.15   # "ramasse au contact" - quasi instantane
			_crystal_zone.col = Color(0.8, 1.0, 0.2)
			_crystal_zone.filled.connect(_on_crystal_armed)
			add_child(_crystal_zone)
		_energy_pulse = bool(def.get("energy_pulse", false))
		if _energy_pulse:
			_energy_pulse_t = randf_range(6.0, 10.0)
		_sticky = bool(def.get("sticky", false))
		if _sticky:
			_sticky_r = float(def.get("sticky_r", 150.0))
			_sticky_mult = float(def.get("sticky_mult", 0.45))
			# 04/10, GAP signale par le patron : sol_collant n'avait aucun effet visuel.
			_sticky_ring = _glow_sprite(Color(0.55, 0.3, 0.6), _sticky_r * 2.0, 0.16)
			add_child(_sticky_ring)
			_core_child(_sticky_ring, Color(0.55, 0.3, 0.6))
		_bio_residue = bool(def.get("bio_residue", false))
		if _bio_residue:
			_bio_residue_r = float(def.get("bio_residue_r", 150.0))
			_bio_residue_slow = float(def.get("bio_residue_slow", 0.6))
			_bio_residue_pull = float(def.get("bio_residue_pull", 40.0))
			# 04/10, GAP signale par le patron : residu_biomecanique n'avait aucun effet visuel.
			# Teinte legerement distincte de sol_collant (plus vert) pour rester lisible si les 2
			# se chevauchent un jour sur la meme carte.
			_bio_residue_ring = _glow_sprite(Color(0.45, 0.55, 0.3), _bio_residue_r * 2.0, 0.16)
			add_child(_bio_residue_ring)
			_core_child(_bio_residue_ring, Color(0.45, 0.55, 0.3))
		_tentacle = bool(def.get("tentacle", false))
		if _tentacle:
			_tentacle_t = randf_range(6.0, 12.0)
		_spore_cloud = bool(def.get("spore_cloud", false))
		if _spore_cloud:
			_spore_r = float(def.get("spore_r", 220.0))
			_spore_dps = float(def.get("spore_dps", 5.0))
			_spore_dir = Vector2.RIGHT.rotated(randf() * TAU)
			_spore_retarget_t = randf_range(4.0, 8.0)
			if _sprite != null:
				_sprite.visible = false
			_spore_sprite = _glow_sprite(Color(0.55, 0.9, 0.35), _spore_r * 2.2, 0.38)
			add_child(_spore_sprite)
			_core_child(_spore_sprite, Color(0.55, 0.9, 0.35))
			add_to_group("ruche_spores")
		_light_plant = bool(def.get("light_plant", false))
		if _light_plant:
			_light_plant_r = float(def.get("light_plant_r", 180.0))
			_light_plant_zone = DwellZone.new()
			_light_plant_zone.radius = float(def.get("dwell_r", 90.0))
			_light_plant_zone.fill_time = float(def.get("dwell_time", 1.0))
			_light_plant_zone.col = Color(0.55, 1.0, 0.4)
			_light_plant_zone.filled.connect(_on_light_plant_filled)
			add_child(_light_plant_zone)
		_depress = bool(def.get("depress", false))
		if _depress:
			_depress_t = randf_range(10.0, 18.0)
			_depress_r = float(def.get("depress_r", 200.0))
			_depress_force = float(def.get("depress_force", 220.0))
			_depress_warn = _glow_sprite(Color(1.0, 0.25, 0.15), _depress_r * 2.0, 0.0)
			add_child(_depress_warn)
			_core_child(_depress_warn, Color(1.0, 0.25, 0.15))
		_grav_zone = bool(def.get("grav_zone", false))
		if _grav_zone:
			_grav_r = float(def.get("grav_r", 180.0))
			_grav_force = float(def.get("grav_force", 60.0))
			# 04/10, vrai bug signale par le patron : reutiliser _cycle (partage avec les murs/portes
			# qui DOIVENT disparaitre) pour le seul rythme pousse/attire masquait AUSSI le sprite et
			# desactivait le collider pendant toute la moitie "attire" (_cycle pilote les deux sans
			# distinction, voir le bloc "if _cycle:" plus bas) alors que la force s'applique
			# justement cette moitie-la. Minuteur INDEPENDANT, ne touche jamais sprite/collider.
			_grav_on_dur = float(def.get("cycle_on", 4.0)); _grav_off_dur = float(def.get("cycle_off", 4.0))
			_grav_phase_t = _grav_on_dur
		_rot_laser = bool(def.get("rot_laser", false))
		if _rot_laser:
			_rot_laser_t = randf_range(3.0, 6.0)
			_rot_laser_angle = randf() * TAU
		_pillar = bool(def.get("pillar", false))
		_welder = bool(def.get("welder", false))
		if _welder:
			_sweep_half = deg_to_rad(float(def.get("sweep_half", 45.0)))
			_welder_dmg = float(def.get("welder_dmg", 28.0))
		_gantry = bool(def.get("gantry", false))
		if _gantry:
			_gantry_cd = float(def.get("gantry_cd", 6.0))
			_gantry_t = randf_range(1.0, _gantry_cd)
			_gantry_tell = float(def.get("gantry_tell", 1.2))
			_gantry_len = float(def.get("gantry_len", 240.0))
			_gantry_dmg = float(def.get("gantry_dmg", 22.0))
			_gantry_dir = Vector2.DOWN if flip else Vector2.RIGHT

		# --- Level 2 (desert) inits ---
		_solar_mirror = bool(def.get("solar_mirror", false))
		if _solar_mirror:
			_solar_dmg = float(def.get("solar_dmg", 32.0))
			_solar_charge = float(def.get("solar_charge", 1.8))
			_burn_trail = float(def.get("burn_trail", 3.0))
		_storm_gen = bool(def.get("storm_gen", false))
		if _storm_gen:
			_storm_cd = float(def.get("storm_cd", 9.0))
			_storm_t = randf_range(2.0, _storm_cd)
			_storm_dmg = float(def.get("storm_dmg", 12.0))
		_sinkhole = bool(def.get("sinkhole", false))
		if _sinkhole:
			_sinkhole_r = float(def.get("sinkhole_r", 150.0))
			_sinkhole_pull = float(def.get("sinkhole_pull", 55.0))
			_sinkhole_slow = float(def.get("sinkhole_slow", 0.5))
			_sinkhole_ring = _glow_sprite(Color(0.85, 0.6, 0.25), _sinkhole_r * 2.0, 0.16)
			add_child(_sinkhole_ring)
			_core_child(_sinkhole_ring, Color(0.85, 0.6, 0.25))
		_solar_collector = bool(def.get("solar_collector", false))
		if _solar_collector:
			_collector_cd = float(def.get("collector_cd", 40.0))
			_collector_zone = DwellZone.new()
			_collector_zone.radius = float(def.get("dwell_r", 100.0))
			_collector_zone.fill_time = float(def.get("dwell_time", 1.5))
			_collector_zone.col = Color(1.0, 0.85, 0.2)
			_collector_zone.filled.connect(_on_solar_collector_filled)
			add_child(_collector_zone)
		_mirage = bool(def.get("mirage", false))
		if _mirage:
			_mirage_cd = float(def.get("mirage_cd", 20.0))
			_mirage_dur = float(def.get("mirage_dur", 6.0))
			_mirage_r = float(def.get("mirage_r", 340.0))
			_mirage_zone = DwellZone.new()
			_mirage_zone.radius = float(def.get("dwell_r", 90.0))
			_mirage_zone.fill_time = 0.8
			_mirage_zone.col = Palette.CYAN
			_mirage_zone.filled.connect(_on_mirage_filled)
			add_child(_mirage_zone)
		_sandworm = bool(def.get("sandworm", false))
		if _sandworm:
			_sandworm_r = float(def.get("sandworm_r", 220.0))
			_sandworm_dmg = float(def.get("sandworm_dmg", 25.0))
			_sandworm_tell = float(def.get("sandworm_tell", 1.0))
		_fumerolle = bool(def.get("fumerolle", false))
		if _fumerolle:
			_fumerolle_cd = float(def.get("fumerolle_cd", 5.0))
			_fumerolle_r = float(def.get("fumerolle_r", 120.0))
			_fumerolle_dmg = float(def.get("fumerolle_dmg", 15.0))
			_fumerolle_t = randf_range(1.0, _fumerolle_cd)

		# --- Level 3 (jungle) inits ---
		_plant_mortar = bool(def.get("plant_mortar", false))
		if _plant_mortar:
			_mortar_cd = float(def.get("mortar_cd", 4.5))
			_mortar_t = randf_range(1.5, _mortar_cd)
			_mortar_dmg = float(def.get("mortar_dmg", 26.0))
			_mortar_r = float(def.get("mortar_r", 90.0))
		_whip_vine = bool(def.get("whip_vine", false))
		if _whip_vine:
			_whip_cd = float(def.get("whip_cd", 5.0))
			_whip_t = randf_range(1.0, _whip_cd)
			_whip_dmg = float(def.get("whip_dmg", 22.0))
			_whip_r = float(def.get("whip_r", 160.0))
			_whip_aim = randf_range(0.0, TAU)
		_catapult = bool(def.get("catapult", false))
		if _catapult:
			_catapult_dist = float(def.get("catapult_dist", 300.0))
			_catapult_cd = float(def.get("catapult_cd", 3.0))
		_lasso = bool(def.get("lasso", false))
		if _lasso:
			_lasso_snare = float(def.get("lasso_snare", 1.5))
			_lasso_cd = float(def.get("lasso_cd", 8.0))
			_lasso_r = float(def.get("lasso_r", 85.0))
		_fireflies = bool(def.get("fireflies", false))
		if _fireflies:
			_heal_dps = float(def.get("heal_dps", 3.0))
			_firefly_r = float(def.get("firefly_r", 110.0))
			_firefly_dur = float(def.get("firefly_dur", 10.0))
			_firefly_life = _firefly_dur

		# --- Level 4 (volcanic) inits ---
		_slag_mortar = bool(def.get("slag_mortar", false))
		if _slag_mortar:
			_smortar_cd = float(def.get("mortar_cd", 5.0))
			_smortar_t = randf_range(1.5, _smortar_cd)
			_smortar_dmg = float(def.get("mortar_dmg", 28.0))
			_smortar_r = float(def.get("mortar_r", 95.0))
		_magma_vent = bool(def.get("magma_vent", false))
		if _magma_vent:
			_vent_cd = float(def.get("vent_cd", 4.5))
			_vent_t = randf_range(1.0, _vent_cd)
			_vent_tell = float(def.get("vent_tell", 1.2))
			_vent_dmg = float(def.get("vent_dmg", 20.0))
			_vent_r = float(def.get("vent_r", 110.0))
		_power_hammer = bool(def.get("power_hammer", false))
		if _power_hammer:
			_hammer_cd = float(def.get("hammer_cd", 7.0))
			_hammer_t = randf_range(2.0, _hammer_cd)
			_hammer_tell = float(def.get("hammer_tell", 1.4))
			_hammer_dmg = float(def.get("hammer_dmg", 35.0))
			_hammer_r = float(def.get("hammer_r", 140.0))
		_crucible = bool(def.get("crucible", false))
		if _crucible:
			_crucible_cd = float(def.get("crucible_cd", 6.0))
			_crucible_t = randf_range(1.5, _crucible_cd)
			_crucible_tell = float(def.get("crucible_tell", 1.2))
			_crucible_dmg = float(def.get("crucible_dmg", 24.0))
			_crucible_len = float(def.get("crucible_len", 260.0))
			_crucible_dir = Vector2.DOWN if flip else Vector2.RIGHT
		_quench_pool = bool(def.get("quench_pool", false))
		if _quench_pool:
			_quench_r = float(def.get("quench_r", 120.0))
		_scrap_magnet = bool(def.get("scrap_magnet", false))
		if _scrap_magnet:
			_magnet_r = float(def.get("magnet_r", 450.0))
		_ember_bellows = bool(def.get("ember_bellows", false))
		if _ember_bellows:
			_bellows_cd = float(def.get("bellows_cd", 5.5))
			_bellows_t = randf_range(1.0, _bellows_cd)
			_bellows_tell = float(def.get("bellows_tell", 1.0))
			_bellows_r = float(def.get("bellows_r", 170.0))
			_bellows_dmg = float(def.get("bellows_dmg", 18.0))
			_bellows_dir = Vector2.LEFT if flip else Vector2.RIGHT

		# ===== Bible des niveaux — Niveau 5 (La Cité Déchue / swamp) =====
		_flak_turret = bool(def.get("flak_turret", false))
		if _flak_turret:
			_flak_cd = float(def.get("flak_cd", 5.0))
			_flak_t = randf_range(1.0, _flak_cd)
			_flak_dmg = float(def.get("flak_dmg", 18.0))
			_flak_r = float(def.get("flak_r", 110.0))
		_flood_gate = bool(def.get("flood_gate", false))
		if _flood_gate:
			_gate_cd = float(def.get("gate_cd", 6.0))
			_gate_t = randf_range(1.5, _gate_cd)
			_gate_tell = float(def.get("gate_tell", 1.5))
			_gate_dmg = float(def.get("gate_dmg", 22.0))
			_gate_len = float(def.get("gate_len", 400.0))
			_gate_w = float(def.get("gate_w", 120.0))
			_gate_push = float(def.get("gate_push", 380.0))
			_gate_dir = Vector2.DOWN.rotated(randf_range(-0.4, 0.4))
		_swamp_drain_valve = bool(def.get("drain_valve", false))
		if _swamp_drain_valve:
			_swamp_drain_r = float(def.get("drain_r", 130.0))
			_swamp_drain_dur = float(def.get("drain_dur", 10.0))
			_swamp_drain_cd = float(def.get("drain_cd", 25.0))
		_floating_mine = bool(def.get("floating_mine", false))
		if _floating_mine:
			_mine_trigger_r = float(def.get("mine_trigger_r", 160.0))
			_mine_dmg = float(def.get("mine_dmg", 35.0))
			_mine_boom_r = float(def.get("mine_boom_r", 140.0))
		_searchlight = bool(def.get("searchlight", false))
		if _searchlight:
			_searchlight_cd = float(def.get("searchlight_cd", 4.0))
			_searchlight_t = randf_range(1.0, _searchlight_cd)
			_searchlight_r = float(def.get("searchlight_r", 280.0))
		_radio_jammer = bool(def.get("radio_jammer", false))
		if _radio_jammer:
			_jammer_r = float(def.get("jammer_r", 300.0))

		# ===== Bible des niveaux — Niveau 6 (Le Cryo-Laboratoire / cryo) =====
		_nitrogen_cannon = bool(def.get("nitrogen_cannon", false))
		if _nitrogen_cannon:
			_ncannon_cd = float(def.get("ncannon_cd", 4.5))
			_ncannon_t = randf_range(1.0, _ncannon_cd)
			_ncannon_dmg = float(def.get("ncannon_dmg", 24.0))
			_ncannon_r = float(def.get("ncannon_r", 100.0))
		_frost_condenser = bool(def.get("frost_condenser", false))
		if _frost_condenser:
			_condenser_cd = float(def.get("condenser_cd", 6.0))
			_condenser_t = randf_range(1.5, _condenser_cd)
			_condenser_r = float(def.get("condenser_r", 250.0))
		_teleporter = bool(def.get("teleporter", false))
		if _teleporter:
			_teleport_cd = float(def.get("teleport_cd", 6.0))
			_teleport_r = float(def.get("teleport_r", 80.0))
			add_to_group("teleporters")
		_regen_ice_wall = bool(def.get("regen_ice_wall", false))
		if _regen_ice_wall:
			_regen_time = float(def.get("regen_time", 10.0))

		# ===== Bible des niveaux — Niveau 7 (Le Noyau Instable / reacteur) =====
		_particle_cannon = bool(def.get("particle_cannon", false))
		if _particle_cannon:
			_pcannon_cd = float(def.get("cannon_cd", 4.0))
			_pcannon_t = randf_range(1.0, _pcannon_cd)
			_pcannon_dmg = float(def.get("cannon_dmg", 22.0))
			_pcannon_r = float(def.get("cannon_r", 350.0))
		_tesla_coil = bool(def.get("tesla_coil", false))
		if _tesla_coil:
			_tesla_cd = float(def.get("tesla_cd", 3.0))
			_tesla_t = randf_range(1.0, _tesla_cd)
			_tesla_r = float(def.get("tesla_r", 300.0))
		_control_rod = bool(def.get("control_rod", false))
		if _control_rod:
			_control_rod_r = float(def.get("control_rod_r", 120.0))
		_containment_cell = bool(def.get("containment_cell", false))
		if _containment_cell:
			_containment_r = float(def.get("containment_r", 220.0))
			_containment_cd = float(def.get("containment_cd", 25.0))

		# ===== Bible des niveaux — Niveau 8 (La Ruche / ruche) =====
		_acid_turret = bool(def.get("acid_turret", false))
		if _acid_turret:
			_acid_cd = float(def.get("acid_cd", 4.5))
			_acid_t = randf_range(1.0, _acid_cd)
			_acid_r = float(def.get("acid_r", 320.0))
		_spawner_egg = bool(def.get("spawner_egg", false))
		if _spawner_egg:
			_egg_spawn_cd = float(def.get("spawn_cd", 5.0))
			_egg_spawn_t = randf_range(1.5, _egg_spawn_cd)
		_vein_pulse = bool(def.get("vein_pulse", false))
		if _vein_pulse:
			_vein_cd = float(def.get("vein_cd", 3.0))
			_vein_t = randf_range(0.5, _vein_cd)
			_vein_r = float(def.get("vein_r", 250.0))
			_vein_force = float(def.get("vein_force", 180.0))
		_acid_bladder = bool(def.get("acid_bladder", false))

		# ===== Bible des niveaux — Niveau 9 (La Citadelle Orbitale / citadelle) =====
		_guided_launcher = bool(def.get("guided_launcher", false))
		if _guided_launcher:
			_glauncher_cd = float(def.get("launcher_cd", 5.0))
			_glauncher_t = randf_range(1.0, _glauncher_cd)
			_glauncher_dmg = float(def.get("launcher_dmg", 25.0))
			_glauncher_r = float(def.get("launcher_r", 400.0))
		_satellite_relay = bool(def.get("satellite_relay", false))
		if _satellite_relay:
			_srelay_cd = float(def.get("relay_cd", 6.0))
			_srelay_t = randf_range(1.5, _srelay_cd)
			_srelay_r = float(def.get("relay_r", 350.0))
		_airlock = bool(def.get("airlock", false))
		if _airlock:
			_airlock_cd = float(def.get("airlock_cd", 6.0))
			_airlock_t = randf_range(1.0, _airlock_cd)
		_dome_shield = bool(def.get("dome_shield", false))
		if _dome_shield:
			_dome_r = float(def.get("dome_r", 200.0))
			_dome_cd = float(def.get("dome_cd", 20.0))
		_magnetic_hook = bool(def.get("magnetic_hook", false))
		if _magnetic_hook:
			_hook_r = float(def.get("hook_r", 250.0))
			_hook_force = float(def.get("hook_force", 120.0))
			_hook_cd = float(def.get("hook_cd", 4.0))
			_hook_t = randf_range(1.0, _hook_cd)

		# props that need a per-frame tick
		set_process(_awaken != "" or _shoot_r > 0.0 or _boom or _beam or _beacon or _pylon or _slow
			or _aura != "" or _push or _guard or _spot or _cycle or _convey
			or _conveyor or _console or _presser or _valve or _overheat or _dropzone or _rail
			or _ice_patch or _cryo_jet or _fog or _defroster or _ice_spike or _thermal or _fragile_ice
			or _toxic_pool or _drain or _wind or _wind_console or _vent_grate or _alt_zone
			or _unstable_crystal or _energy_pulse
			or _sticky or _bio_residue or _tentacle or _spore_cloud or _light_plant
			or _depress or _grav_zone or _rot_laser or _welder or _gantry
			or _solar_mirror or _storm_gen or _sinkhole or _solar_collector or _mirage or _sandworm or _fumerolle
			or _plant_mortar or _whip_vine or _catapult or _lasso or _fireflies
			or _slag_mortar or _magma_vent or _power_hammer or _crucible or _quench_pool or _scrap_magnet or _ember_bellows
			or _flak_turret or _flood_gate or _swamp_drain_valve or _floating_mine or _searchlight or _radio_jammer
			or _nitrogen_cannon or _frost_condenser or _teleporter or _regen_ice_wall
			or _particle_cannon or _tesla_coil or _control_rod or _containment_cell
			or _acid_turret or _spawner_egg or _vein_pulse
			or _guided_launcher or _satellite_relay or _airlock or _dome_shield or _magnetic_hook)
		var tex: Texture2D = load("res://assets/decor/%s.png" % String(def.get("f", "g20")))
		var th: float = maxf(1.0, float(tex.get_height()))
		var d_mult: float = SaveManager.get_decor_scale(kind, PropScatter._decor_cat(kind)) if (SaveManager != null and SaveManager.has_method("get_decor_scale")) else 1.0
		var sc: float = rand_scale * (float(def.get("sz", 110.0)) / th) * d_mult
		var spanx: float = float(tex.get_width()) * sc
		var spany: float = th * sc

		# ground contact shadow -> the prop sits in the world instead of floating
		var shadow: Sprite2D = Sprite2D.new()
		shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.position = Vector2(0.0, spany * 0.36)
		shadow.scale = Vector2(spanx / 64.0 * 0.66, spany / 64.0 * 0.20)
		shadow.z_index = -2
		add_child(shadow)

		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.scale = Vector2.ONE * sc
		if _conveyor:
			_sprite.flip_h = flip
		add_child(_sprite)

		# Fixed emplacement gun: derive the FIRING AXIS from the art itself so the bolt always
		# leaves the barrel we drew, never the opposite side. Mirroring the sprite mirrors both
		# the axis and the muzzle, which buys a second orientation for free.
		# Tourelle canon : tout decor avec _shoot_r > 0 OU utilisant l'art g27 OU nomme tourelle/canon
		# EST un canon fonctionnel a tir de rayon automatique a intervalle regulier.
		var is_cannon: bool = _shoot_r > 0.0 or String(def.get("f", "")) == "g27" or kind == "tourelle" or kind.begins_with("canon") or _welder or _solar_mirror
		if is_cannon:
			_shoot_r = maxf(_shoot_r, 470.0)
			set_process(true)
			_sprite.flip_h = flip
			var a: float = deg_to_rad(float(def.get("aim", 135.0 if (_welder or _solar_mirror) else 140.0)))
			_cannon = Vector2.RIGHT.rotated(a)
			var m: Array = def.get("muzzle", [0.0, 30.0] if _solar_mirror else ([-20.0, 40.0] if _welder else [-162.5, 117.0]))
			_muzzle = Vector2(float(m[0]), float(m[1])) * sc
			if flip:
				_cannon.x = -_cannon.x
				_muzzle.x = -_muzzle.x
			_cannon_beam = true
			_cannon_beam_t = randf_range(0.2, 0.9)
			_cannon_beam_glow = _mk_beam(27)
			_cannon_beam_line = _mk_beam(28)
			_cannon_beam_core = _mk_beam(29)
			_cannon_beam_flash = Sprite2D.new()
			var flash_col: Color = Color(1.0, 0.9, 0.4) if _solar_mirror else (Color(0.2, 0.85, 1.0) if _welder else Color(1.0, 0.6, 0.15))
			_cannon_beam_flash.texture = Tex.glow(flash_col, 128)
			_cannon_beam_flash.material = Tex.add_mat()
			_cannon_beam_flash.top_level = true
			_cannon_beam_flash.z_index = 29
			_cannon_beam_flash.visible = false
			add_child(_cannon_beam_flash)

		# Prop glow — was a persistent PointLight2D per glowing prop. With chunk streaming that's
		# a stack of always-on dynamic lights (each a canvas re-render) = a constant mobile tax.
		# An ADDITIVE glow sprite gives the same look for ~free.
		var glow: String = String(def.get("glow", ""))
		if glow != "":
			var gc: Color = Palette.CYAN
			if glow == "green": gc = Color(0.4, 1.0, 0.5)
			elif glow == "orange": gc = Color(1.0, 0.55, 0.2)
			var base_glow: Sprite2D = _glow_sprite(gc, maxf(spanx, spany) * 0.9, 0.5)
			add_child(base_glow)
			_core_child(base_glow, gc)

		# a destructible crate MAY hold a competence -> warm gold tell so the player breaks it
		if bool(def.get("destruct", false)) and skill_roll < float(def.get("skill", 0.0)):
			_skill = true
			var skill_glow: Sprite2D = _glow_sprite(Palette.BONUS, maxf(spanx, spany) * 1.05, 0.7)
			add_child(skill_glow)
			_core_child(skill_glow, Palette.BONUS)

		# collision: blocks the player (mask 8) and bullets; enemies avoid via Game.cover_list.
		# "block" overrides the footprint fraction — arche uses a wider one so it reads as SOLID
		# (no passing or shooting through the archway opening).
		block_r = maxf(spanx, spany) * float(def.get("block", 0.30))
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = block_r
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = shape
		col.position = Vector2(0.0, spany * 0.12)   # centre the collider on the base, not the top
		add_child(col)
		_cycle_col = col   # QUAI : bascule disabled/visible sur son propre cycle, voir _process
		add_to_group("cover")
		collision_layer = 8   # blocks the player physically (broad-phase, free) regardless of cover_list
		collision_mask = 0
		# NOTE: props do NOT self-register in cover_list any more. With fixed decor across a big
		# arena that would put 200+ props in the per-frame enemy-steering scan. PropScatter keeps
		# cover_list to the props near the player instead (see _refresh_cover).

	func get_sprite_texture() -> Texture2D:
		return _sprite.texture if _sprite != null else null

	## Cheap additive glow used instead of a real Light2D (see call sites): same soft halo look,
	## none of the per-frame dynamic-light re-render cost that was hurting mobile.
	func _glow_sprite(c: Color, diameter: float, alpha: float) -> Sprite2D:
		var s: Sprite2D = Sprite2D.new()
		s.texture = Tex.glow(c, 128)
		var m: CanvasItemMaterial = CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
		s.scale = Vector2.ONE * (diameter / 128.0)
		s.modulate = Color(c.r, c.g, c.b, alpha)
		s.z_index = -1
		return s

	## 04/10, mise a niveau VFX (demande du patron, "effets speciaux vraiment nuls") : chaque anneau
	## ambiant du decor (toxique, glace, collant, alerte...) n'etait qu'UN SEUL cercle plat -> ajoute
	## un "coeur" plus petit et plus clair, EN ENFANT du halo (pas un frere) pour heriter directement
	## de sa pulsation de modulate deja en place (zero changement a la logique _process existante).
	## Diametre-parametre de 51.2 (= 128*0.4) donne une echelle LOCALE de 0.4 une fois composee avec
	## celle du parent -> le coeur fait toujours 40% du halo, quel que soit le rayon de ce dernier
	## (voir le calcul : echelle_globale = echelle_parent * echelle_locale).
	func _core_child(halo: Sprite2D, color: Color) -> void:
		halo.add_child(_glow_sprite(color.lerp(Color.WHITE, 0.5), 51.2, 1.8))

	## Only runs on props that need it (see set_process in _ready): CARCASSES watch for the player
	## walking close (the wreck IS the sleeping robot and stands up), TURRETS shoot at the player.
	func _process(delta: float) -> void:
		if game == null or not is_instance_valid(game) or not GameState.alive:
			return
		if _plr == null or not is_instance_valid(_plr):
			_plr = get_tree().get_first_node_in_group("player") as Node2D
			if _plr == null:
				return
		var dist: float = global_position.distance_to(_plr.global_position)

		# --- CANON A RAYON AUTOMATIQUE A INTERVALLE REGULIER ---
		if _cannon_beam and (dist < 2200.0 or _cannon_beam_state != 0):
			_tick_cannon_beam(delta)

		# --- beacon: emit an enemy on a fixed cadence while the player is in range ---
		if _beacon:
			if _beacon_pulse != null:
				# breathe the warning ring so it reads as an active threat, not scenery
				var b: float = 0.28 + 0.22 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004))
				_beacon_pulse.modulate.a = b if dist < BEACON_R else 0.12
			if dist < BEACON_R:
				_beacon_t -= delta
				if _beacon_t <= 0.0:
					_beacon_t = _beacon_cd
					if game.has_method("beacon_spawn"):
						game.beacon_spawn(global_position, _beacon_kind)

		# --- arc pylon: zap the nearest enemy periodically while the player is near ---
		if _pylon and dist < 1300.0:
			_pylon_t -= delta
			if _pylon_t <= 0.0:
				_pylon_t = _pylon_cd
				_zap_nearest()

		# --- slow field: dampen the player and any enemy inside the ring, every frame ---
		if _slow:
			if _slow_ring != null:
				_slow_ring.modulate.a = 0.12 + 0.06 * sin(Time.get_ticks_msec() * 0.003)
			if dist < _slow_r and "field_slow" in _plr:
				_plr.field_slow = minf(_plr.field_slow, _slow_mult)
			if dist < 1300.0:   # only bother with enemies when the player is near this field
				var r2s: float = _slow_r * _slow_r
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and "field_slow" in e:
						if global_position.distance_squared_to((e as Node2D).global_position) <= r2s:
							e.field_slow = minf(e.field_slow, _slow_mult)

		# --- IMPULSION (Gravite faible) : pousse joueur+ennemis dans un axe fixe, a intervalle ---
		if _push and dist < 1300.0:
			if _push_ring != null:
				_push_ring.modulate.a = 0.10 + 0.10 * absf(sin(Time.get_ticks_msec() * 0.0025))
			_push_t -= delta
			if _push_t <= 0.0:
				_push_t = _push_cd
				# 🚨 Player.gd ECRASE velocity chaque frame (velocity = target_vel, jamais additif) :
				# un += ici serait efface avant meme de bouger le mecha d'un pixel. Nudge direct de
				# global_position, comme pour les ennemis juste en dessous.
				if dist < _push_r:
					_plr.global_position += _push_dir * (_push_force * 0.12)
				var r2p: float = _push_r * _push_r
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and global_position.distance_squared_to((e as Node2D).global_position) <= r2p:
						(e as Node2D).global_position += _push_dir * (_push_force * 0.12)
				if game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, _push_r / 95.0, Color(0.5, 0.9, 1.0))

		# --- AIMANT (Casse magnetique) : QUAND le joueur est pres, repousse les ennemis proches —
		# un outil defensif de positionnement, jamais une invincibilite ni un vol d'XP/ferraille.
		if _guard:
			if _guard_ring != null:
				_guard_ring.modulate.a = (0.22 if dist < _guard_r else 0.10)
			if dist < _guard_r:
				_guard_t -= delta
				if _guard_t <= 0.0:
					_guard_t = _guard_cd
					var r2g: float = _guard_r * _guard_r
					for e in get_tree().get_nodes_in_group("enemies"):
						if e is Node2D:
							var away: Vector2 = (e as Node2D).global_position - global_position
							var d2: float = away.length_squared()
							if d2 <= r2g and d2 > 1.0:
								(e as Node2D).global_position += away.normalized() * (_guard_force * 0.12)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, _guard_r / 95.0, Palette.CYAN)

		# --- ARCHIVES (Archives-machines) : marque periodiquement l'ennemi le plus proche pour
		# l'auto-visee (priority_boost), jamais de bonus de degats ni d'attaque du decor.
		if _spot and dist < _spot_r + 200.0:
			if _spot_marked != null:
				if not is_instance_valid(_spot_marked) or not _spot_marked.alive:
					_spot_marked = null
				else:
					_spot_t -= delta
					if _spot_t <= 0.0:
						_spot_marked.priority_boost = 0.0   # le hold expire : priorite normale
						_spot_marked = null
			if _spot_marked == null:
				var best: Enemy = null
				var bd: float = _spot_r * _spot_r
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Enemy and (e as Enemy).alive:
						var d: float = global_position.distance_squared_to((e as Node2D).global_position)
						if d < bd:
							bd = d; best = e
				if best != null:
					_spot_marked = best
					_spot_marked.priority_boost = _spot_boost
					_spot_t = _spot_hold
			if _spot_beam != null:
				if _spot_marked != null and is_instance_valid(_spot_marked):
					# top_level=true (voir _mk_beam) : points en coordonnees MONDE, comme _tick_beam
					# juste plus bas — to_local() serait fausse ici (pas d'ancrage sur le parent).
					_spot_beam.points = PackedVector2Array([global_position, _spot_marked.global_position])
					_spot_beam.visible = true
				else:
					_spot_beam.visible = false

		# --- QUAI (Quai de chargement) : caisse-ecran qui alterne presente/absente sur un cycle fixe ---
		if _cycle:
			_cycle_t -= delta
			if _cycle_t <= 0.0:
				_cycle_present = not _cycle_present
				_cycle_t = _cycle_on if _cycle_present else _cycle_off
				if _sprite != null:
					_sprite.visible = _cycle_present
				if _cycle_col != null:
					_cycle_col.disabled = not _cycle_present

		# --- CONVOYEUR (Chaine de fonderie) : deplace les ennemis proches d'une courte distance,
		# le long d'un axe fixe. Nudge additive de global_position uniquement (jamais velocity/
		# desired_vel) : chaque ennemi redérive son mouvement depuis sa position courante la frame
		# suivante (meme precedent que le comportement "pusher" deja en jeu, Enemy.gd).
		if _convey and dist < 1300.0:
			_convey_t -= delta
			if _convey_t <= 0.0:
				_convey_t = _convey_cd
				var r2c: float = _convey_r * _convey_r
				var moved: bool = false
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and global_position.distance_squared_to((e as Node2D).global_position) <= r2c:
						(e as Node2D).global_position += _convey_dir * _convey_dist
						moved = true
				if moved and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, _convey_r / 140.0, Color(1.0, 0.6, 0.2))

		# --- CONVOYEUR SOL / TAPIS RALENTISSEUR (Hall d'Assemblage) :
		# Zone de tapis ralentisseur centree au sol. Ralentit le joueur (field_slow = 0.52)
		# et les ennemis, tout en les entrainant en continu selon la direction du tapis.
		# Une console voisine peut le suspendre temporairement (8s).
		if _conveyor:
			if _conveyor_stop_t > 0.0:
				_conveyor_stop_t -= delta
				if _conveyor_ring != null:
					_conveyor_ring.modulate = Color(0.3, 0.7, 0.9, 0.05)
					_conveyor_edge.modulate = Color(0.3, 0.7, 0.9, 0.18)   # coupe : bleu, quasi eteint
			else:
				# clignotement FRANC (periode ~1,3 s, synchrone avec l'onde) : le disque et son bord
				# respirent ensemble, tous deux centres sur le tapis.
				var blink: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0048)
				if _conveyor_ring != null:
					_conveyor_ring.modulate = Color(1.0, 0.55, 0.15, 0.08 + 0.20 * blink)
					_conveyor_edge.modulate = Color(1.0, 0.62, 0.22, 0.30 + 0.65 * blink)
				var cv_step: Vector2 = _conveyor_dir * _conveyor_speed * delta
				if dist < _conveyor_r:
					if "field_slow" in _plr:
						_plr.field_slow = minf(float(_plr.field_slow), 0.52)
					_plr.global_position += cv_step
				if dist < 1400.0:
					var r2cv: float = _conveyor_r * _conveyor_r
					for e in get_tree().get_nodes_in_group("enemies"):
						if e is Node2D and is_instance_valid(e):
							if global_position.distance_squared_to((e as Node2D).global_position) <= r2cv:
								if "field_slow" in e:
									e.field_slow = minf(float(e.field_slow), 0.52)
								(e as Node2D).global_position += cv_step
				_conveyor_vfx_t -= delta
				if _conveyor_vfx_t <= 0.0 and game != null and game.has_method("spawn_vfx"):
					_conveyor_vfx_t = 1.3
					const FxKit = preload("res://scenes/FxKit.gd")
					FxKit.conveyor_pulse(game, global_position, Color(1.0, 0.6, 0.18), _conveyor_dir, _conveyor_r / 128.0)

		# --- CONSOLE / VANNE : juste la decrementation du cooldown, le declenchement vient du
		# signal DwellZone.filled (_on_console_filled/_on_valve_filled plus bas).
		if _console:
			if _console_cd_t > 0.0:
				_console_cd_t -= delta
			if _console_zone != null:
				_console_zone.active = _console_cd_t <= 0.0   # anneau eteint pendant la recharge
		if _valve:
			if _valve_cd_t > 0.0:
				_valve_cd_t -= delta
			if _valve_zone != null:
				_valve_zone.active = _valve_cd_t <= 0.0   # anneau eteint pendant la recharge

		# --- BRAS PRESSEUR (Hall d'Assemblage) : GroundZone en ligne a intervalle aleatoire, meme
		# idiome que le boss _phase_crusher (Enemy.gd) qui appelle deja spawn_ground_zone depuis
		# un timer. Construit une GroundZone directement (shape="line" n'est pas expose par
		# Game.spawn_ground_zone, volontairement pas touche - voir le plan).
		if _presser and dist < 1300.0:
			_presser_t -= delta
			if _presser_t <= 0.0:
				_presser_t = randf_range(8.0, 15.0)
				if game != null and game.has_method("spawn_vfx") and "enemy_layer" in game:
					var half: Vector2 = _presser_dir * (_presser_len * 0.5)
					var z: GroundZone = GroundZone.new()
					z.radius = 40.0; z.delay = 1.5; z.damage = _presser_dmg
					z.color = Color(1.0, 0.85, 0.2)
					z.shape = "line"; z.line_from = -half; z.line_to = half
					z.stun_duration = _presser_stun; z.fx_kind = kind
					z.game = game; z.player = _plr
					game.enemy_layer.add_child(z)
					z.global_position = global_position

		# --- PORTIQUE DE DECOUPE LASER (L'Usine / tech) : trace une ligne de decoupe au sol toutes les 6 s
		if _gantry and dist < 1300.0:
			_gantry_t -= delta
			if _gantry_t <= 0.0:
				_gantry_t = _gantry_cd
				if game != null and game.has_method("spawn_vfx") and "enemy_layer" in game:
					var half: Vector2 = _gantry_dir * (_gantry_len * 0.5)
					var z: GroundZone = GroundZone.new()
					z.radius = 35.0; z.delay = _gantry_tell; z.damage = _gantry_dmg
					z.color = Color(1.0, 0.35, 0.15)
					z.shape = "line"; z.line_from = -half; z.line_to = half
					z.stun_duration = 0.2; z.fx_kind = kind
					z.game = game; z.player = _plr
					game.enemy_layer.add_child(z)
					z.global_position = global_position

		# --- Bible des niveaux — Niveau 2 (Terres Calcinées / desert) ---
		# Fosse d'aspiration : attire vers le centre et ralentit tout ce qui entre
		if _sinkhole and dist < 1200.0:
			if dist < _sinkhole_r and dist > 2.0:
				var to_c: Vector2 = (global_position - _plr.global_position).normalized()
				_plr.global_position += to_c * _sinkhole_pull * delta
				_plr.field_slow = minf(_plr.field_slow, _sinkhole_slow)
			var r2_sink: float = _sinkhole_r * _sinkhole_r
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node2D and is_instance_valid(e):
					var to_e: Vector2 = global_position - (e as Node2D).global_position
					var d2e: float = to_e.length_squared()
					if d2e <= r2_sink and d2e > 4.0:
						(e as Node2D).global_position += to_e.normalized() * (_sinkhole_pull * 0.8) * delta

		# Collecteur solaire : gestion cooldown du socle de recharge
		if _solar_collector:
			if _collector_cd_t > 0.0:
				_collector_cd_t -= delta
			if _collector_zone != null:
				_collector_zone.active = _collector_cd_t <= 0.0

		# Projecteur de mirage : leurre holographique qui détourne la horde
		if _mirage:
			if _mirage_cd_t > 0.0:
				_mirage_cd_t -= delta
			if _mirage_zone != null:
				_mirage_zone.active = _mirage_cd_t <= 0.0 and _mirage_active_t <= 0.0
			if _mirage_active_t > 0.0:
				_mirage_active_t -= delta
				var r2_mir: float = _mirage_r * _mirage_r
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and is_instance_valid(e):
						var to_m: Vector2 = global_position - (e as Node2D).global_position
						var d2m: float = to_m.length_squared()
						if d2m <= r2_mir and d2m > 9.0:
							(e as Node2D).global_position += to_m.normalized() * 75.0 * delta

		# Ver foreur enfoui : jaillit du sol à l'approche du joueur
		if _sandworm and dist < _sandworm_r:
			if _sandworm_t <= 0.0:
				_sandworm_t = 12.0
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, 110.0, _sandworm_tell, _sandworm_dmg, Color(1.0, 0.5, 0.15), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 1.8, Color(0.9, 0.6, 0.2))
			else:
				_sandworm_t -= delta
		elif _sandworm and _sandworm_t > 0.0:
			_sandworm_t -= delta

		# Fumerolle surchauffée : geyser périodique qui repousse et brûle
		if _fumerolle and dist < 1300.0:
			_fumerolle_t -= delta
			if _fumerolle_t <= 0.0:
				_fumerolle_t = _fumerolle_cd
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, _fumerolle_r, 1.0, _fumerolle_dmg, Color(1.0, 0.55, 0.2), kind)
				if dist < _fumerolle_r * 1.4 and dist > 1.0:
					var push_dir: Vector2 = (_plr.global_position - global_position).normalized()
					_plr.global_position += push_dir * 50.0

		# Générateur de tempête : libère un tourbillon de sable périodique
		if _storm_gen and dist < 1400.0:
			_storm_t -= delta
			if _storm_t <= 0.0:
				_storm_t = _storm_cd
				if game != null and game.has_method("spawn_ground_zone"):
					var wander_off: Vector2 = Vector2(randf_range(-140.0, 140.0), randf_range(-140.0, 140.0))
					game.spawn_ground_zone(global_position + wander_off, 120.0, 1.2, _storm_dmg, Color(0.85, 0.65, 0.3), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position + wander_off, 0.0, 2.0, Color(0.9, 0.7, 0.3))

		# --- Bible des niveaux — Niveau 3 (La Ruine Verte / jungle) ---
		# Plante-mortier : tire des cosses de graines en cloche (GroundZone sur le joueur)
		if _plant_mortar and dist < 1300.0:
			_mortar_t -= delta
			if _mortar_t <= 0.0:
				_mortar_t = _mortar_cd
				if game != null and game.has_method("spawn_ground_zone"):
					var target_pos: Vector2 = _plr.global_position + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
					game.spawn_ground_zone(target_pos, _mortar_r, 1.6, _mortar_dmg, Color(0.4, 0.85, 0.2), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 1.5, Color(0.5, 0.8, 0.2))
					Audio.sfx("shoot", 0.08)

		# Liane-fouet : fouette un arc de 120° autour de sa base
		if _whip_vine and dist < 1200.0:
			_whip_t -= delta
			if _whip_t <= 0.0:
				_whip_t = _whip_cd
				_whip_aim = fmod(_whip_aim + deg_to_rad(75.0), TAU)
				if game != null and game.has_method("spawn_ground_zone"):
					var whip_dir: Vector2 = Vector2.RIGHT.rotated(_whip_aim)
					var whip_pos: Vector2 = global_position + whip_dir * (_whip_r * 0.6)
					game.spawn_ground_zone(whip_pos, _whip_r * 0.6, 1.0, _whip_dmg, Color(0.3, 0.8, 0.25), kind)
					if dist < _whip_r:
						var away: Vector2 = (_plr.global_position - global_position).normalized()
						_plr.global_position += away * 60.0

		# Fleur-catapulte : marcher dessus propulse le joueur de 300 u
		if _catapult:
			if _catapult_cd_t > 0.0:
				_catapult_cd_t -= delta
			elif dist < 80.0:
				_catapult_cd_t = _catapult_cd
				var l_dir: Vector2 = _plr.velocity.normalized() if (_plr.velocity != null and _plr.velocity.length_squared() > 100.0) else (_plr.global_position - global_position).normalized()
				if l_dir.length_squared() < 0.1:
					l_dir = Vector2.RIGHT
				_plr.global_position += l_dir * _catapult_dist
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, 2.2, Color(0.85, 0.3, 0.65))
				Audio.sfx("dash", 0.15)
				Events.screen_shake.emit(3.0)

		# Plante-lasso : se referme et immobilise 1.5 s
		if _lasso:
			if _lasso_cd_t > 0.0:
				_lasso_cd_t -= delta
			elif dist < _lasso_r:
				_lasso_cd_t = _lasso_cd
				_plr.field_slow = 0.05
				_plr.take_damage(8.0, global_position)
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("impact", global_position, 0.0, 1.8, Color(0.4, 0.8, 0.2))
				Audio.sfx("hit", 0.12)

		# Nuée de lucioles : soigne le joueur (+3 PV/s) pendant 10 s
		if _fireflies:
			if _firefly_cd_t > 0.0:
				_firefly_cd_t -= delta
				if _firefly_cd_t <= 0.0:
					_firefly_life = _firefly_dur
			elif dist < _firefly_r:
				_firefly_life -= delta
				if _plr.has_method("heal"):
					_plr.heal(_heal_dps * delta)
				if game != null and game.has_method("spawn_vfx") and randf() < 0.1:
					game.spawn_vfx("heal", _plr.global_position, 0.0, 0.8)
				if _firefly_life <= 0.0:
					_firefly_cd_t = 30.0
					if game != null and game.has_method("impact_fx"):
						game.impact_fx(global_position, Color(0.8, 0.9, 0.3), kind, Vector2.ZERO, 1.5)

		# --- Bible des niveaux — Niveau 4 (La Forge / volcanic) ---
		# Mortier à scories : lance un obus de lave en cloche laissant une flaque brûlante
		if _slag_mortar and dist < 1300.0:
			_smortar_t -= delta
			if _smortar_t <= 0.0:
				_smortar_t = _smortar_cd
				if game != null and game.has_method("spawn_ground_zone"):
					var target_pos: Vector2 = _plr.global_position + Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
					game.spawn_ground_zone(target_pos, _smortar_r, 1.5, _smortar_dmg, Color(1.0, 0.4, 0.1), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 1.8, Color(1.0, 0.4, 0.1))
					Audio.sfx("shoot", 0.08)

		# Évent de magma : éruption volcanique périodique
		if _magma_vent and dist < 1200.0:
			_vent_t -= delta
			if _vent_t <= 0.0:
				_vent_t = _vent_cd
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, _vent_r, _vent_tell, _vent_dmg, Color(1.0, 0.35, 0.1), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 1.6, Color(1.0, 0.5, 0.1))

		# Marteau-pilon géant : frappe écrasante et onde de choc
		if _power_hammer and dist < 1300.0:
			_hammer_t -= delta
			if _hammer_t <= 0.0:
				_hammer_t = _hammer_cd
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, _hammer_r, _hammer_tell, _hammer_dmg, Color(1.0, 0.55, 0.1), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 2.5, Color(1.0, 0.6, 0.2))
					Events.screen_shake.emit(5.0)
					if dist < _hammer_r * 1.5 and dist > 1.0:
						var away: Vector2 = (_plr.global_position - global_position).normalized()
						_plr.global_position += away * 65.0

		# Creuset basculant : déverse du métal en fusion en ligne
		if _crucible and dist < 1300.0:
			_crucible_t -= delta
			if _crucible_t <= 0.0:
				_crucible_t = _crucible_cd
				if game != null and "enemy_layer" in game:
					var half: Vector2 = _crucible_dir * (_crucible_len * 0.5)
					var z: GroundZone = GroundZone.new()
					z.radius = 36.0; z.delay = _crucible_tell; z.damage = _crucible_dmg
					z.color = Color(1.0, 0.45, 0.1)
					z.shape = "line"; z.line_from = -half; z.line_to = half
					z.stun_duration = 0.0; z.fx_kind = kind
					z.game = game; z.player = _plr
					game.enemy_layer.add_child(z)
					z.global_position = global_position + half

		# Bassin de trempe : éteint les brûlures et soigne 15 %
		if _quench_pool:
			if _quench_cd_t > 0.0:
				_quench_cd_t -= delta
			elif dist < _quench_r:
				_quench_cd_t = _quench_cd
				_cool_down_player(0.15)
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, 2.0, Color(0.4, 0.85, 1.0))
				Audio.sfx("powerup", 0.08)

		# Électroaimant de ferrailleur : aspire les pickups proches
		if _scrap_magnet and dist < 220.0:
			var r2_mag: float = _magnet_r * _magnet_r
			for p in get_tree().get_nodes_in_group("pickups"):
				if p is Node2D and is_instance_valid(p):
					var to_p: Vector2 = global_position - (p as Node2D).global_position
					if to_p.length_squared() <= r2_mag and to_p.length_squared() > 16.0:
						(p as Node2D).global_position += to_p.normalized() * 320.0 * delta

		# Soufflerie à braises : rafale brûlante périodique
		if _ember_bellows and dist < 1200.0:
			_bellows_t -= delta
			if _bellows_t <= 0.0:
				_bellows_t = _bellows_cd
				if game != null and game.has_method("spawn_ground_zone"):
					var b_pos: Vector2 = global_position + _bellows_dir * (_bellows_r * 0.6)
					game.spawn_ground_zone(b_pos, _bellows_r * 0.5, _bellows_tell, _bellows_dmg, Color(1.0, 0.45, 0.15), kind)
					if dist < _bellows_r:
						_plr.global_position += _bellows_dir * 55.0

		# --- Bible des niveaux — Niveau 5 (La Cité Déchue / swamp) ---
		# Batterie antiaérienne : salve de 4 obus à fusée éclatant en anneau d'éclats
		if _flak_turret and dist < 1300.0:
			_flak_t -= delta
			if _flak_t <= 0.0:
				_flak_t = _flak_cd
				if game != null and game.has_method("spawn_ground_zone"):
					for i in 4:
						var ang: float = float(i) * (PI * 0.5) + randf_range(-0.2, 0.2)
						var burst_target: Vector2 = _plr.global_position + Vector2.RIGHT.rotated(ang) * randf_range(40.0, 90.0)
						game.spawn_ground_zone(burst_target, _flak_r * 0.7, 1.2, _flak_dmg, Color(1.0, 0.5, 0.15), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 2.0, Color(1.0, 0.45, 0.2))
					Audio.sfx("shoot", 0.08)

		# Vanne de crue : vague torrentielle qui balaie 400 u et pousse
		if _flood_gate and dist < 1300.0:
			_gate_t -= delta
			if _gate_t <= 0.0:
				_gate_t = _gate_cd
				if game != null and "enemy_layer" in game:
					var half_len: Vector2 = _gate_dir * (_gate_len * 0.5)
					var gz: GroundZone = GroundZone.new()
					gz.radius = _gate_w * 0.5; gz.delay = _gate_tell; gz.damage = _gate_dmg
					gz.color = Color(0.25, 0.65, 0.75)
					gz.shape = "line"; gz.line_from = -half_len; gz.line_to = half_len
					gz.stun_duration = 0.0; gz.fx_kind = kind
					gz.game = game; gz.player = _plr
					game.enemy_layer.add_child(gz)
					gz.global_position = global_position + half_len
					if dist < _gate_len and dist > 1.0:
						_plr.global_position += _gate_dir * 80.0
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 2.2, Color(0.3, 0.7, 0.8))

		# Vanne de barrage : RESTER 1,5 s dedans -> assèche la zone (annule slow) pendant 10 s
		if _swamp_drain_valve:
			if _swamp_drain_t > 0.0:
				_swamp_drain_t -= delta
			else:
				if dist < _swamp_drain_r:
					_swamp_drain_dwell += delta
					if _swamp_drain_dwell >= 1.5:
						_swamp_drain_dwell = 0.0
						_swamp_drain_t = _swamp_drain_cd
						if _plr != null and "field_slow" in _plr:
							_plr.field_slow = 1.0
						if game != null and game.has_method("spawn_vfx"):
							game.spawn_vfx("shockwave", global_position, 0.0, 2.5, Color(0.3, 0.8, 0.9))
						Audio.sfx("powerup", 0.08)
				else:
					_swamp_drain_dwell = maxf(0.0, _swamp_drain_dwell - delta * 2.0)

		# Bouée-mine dérivante : dérive lentement et explose au contact
		if _floating_mine and dist < 1200.0:
			global_position += Vector2(cos(Time.get_ticks_msec() * 0.001), sin(Time.get_ticks_msec() * 0.0008)) * 12.0 * delta
			if not _mine_armed and dist < _mine_trigger_r:
				_mine_armed = true
				_mine_beep_t = 1.2
			if _mine_armed:
				_mine_beep_t -= delta
				if _mine_beep_t <= 0.0:
					_mine_armed = false
					if game != null and game.has_method("spawn_ground_zone"):
						game.spawn_ground_zone(global_position, _mine_boom_r, 0.3, _mine_dmg, Color(1.0, 0.3, 0.2), kind)
					if game != null and game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 2.5, Color(1.0, 0.4, 0.2))
					take_damage(999.0)

		# Phare de toit : projecteur balayant la zone
		if _searchlight and dist < 1200.0:
			_searchlight_t -= delta
			if _searchlight_t <= 0.0:
				_searchlight_t = _searchlight_cd
				var sweep_ang: float = randf_range(0.0, TAU)
				var spot_pos: Vector2 = global_position + Vector2.RIGHT.rotated(sweep_ang) * (_searchlight_r * 0.6)
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", spot_pos, 0.0, 1.8, Color(0.9, 0.7, 0.2))
				if _plr != null and _plr.global_position.distance_to(spot_pos) < _searchlight_r * 0.5:
					for e in get_tree().get_nodes_in_group("enemies"):
						if e is Node2D and (e as Node2D).global_position.distance_to(global_position) < 500.0:
							if "speed_mult" in e:
								e.speed_mult = 1.4

		# Brouilleur radio : ralentit de 50 % les projectiles ennemis dans 300 u
		if _radio_jammer and dist < 1200.0:
			var r2_j: float = _jammer_r * _jammer_r
			for b in get_tree().get_nodes_in_group("enemy_bullets"):
				if b is Node2D and is_instance_valid(b):
					if global_position.distance_squared_to((b as Node2D).global_position) <= r2_j:
						if "speed_mult" in b:
							b.speed_mult = 0.5

		# --- Bible des niveaux — Niveau 6 (Le Cryo-Laboratoire / cryo) ---
		# Canon à azote : tire des orbes de givre lents explosant en nova glacée
		if _nitrogen_cannon and dist < 1300.0:
			_ncannon_t -= delta
			if _ncannon_t <= 0.0:
				_ncannon_t = _ncannon_cd
				if game != null and game.has_method("spawn_ground_zone"):
					var target_pos: Vector2 = _plr.global_position + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
					game.spawn_ground_zone(target_pos, _ncannon_r, 1.4, _ncannon_dmg, Color(0.6, 0.85, 1.0), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 1.8, Color(0.6, 0.9, 1.0))
					Audio.sfx("shoot", 0.08)

		# Condenseur à givre : anneaux de givre périodiques qui s'étendent et ralentissent
		if _frost_condenser and dist < 1200.0:
			_condenser_t -= delta
			if _condenser_t <= 0.0:
				_condenser_t = _condenser_cd
				if game != null and game.has_method("spawn_ground_zone"):
					for ring in 3:
						var r_dist: float = (float(ring) + 1.0) * (_condenser_r / 3.0)
						game.spawn_ground_zone(global_position, r_dist, 0.8 + float(ring) * 0.4, 12.0, Color(0.7, 0.9, 1.0), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 2.4, Color(0.7, 0.95, 1.0))

		# Téléporteur de laboratoire : téléporte le mecha
		if _teleporter:
			if _teleport_t > 0.0:
				_teleport_t -= delta
			elif dist < _teleport_r:
				_teleport_t = _teleport_cd
				var pads: Array = get_tree().get_nodes_in_group("teleporters")
				var target_pad: Node2D = null
				for p in pads:
					if p != self and is_instance_valid(p):
						target_pad = p as Node2D
						break
				var dest: Vector2 = target_pad.global_position if target_pad != null else global_position + Vector2.RIGHT.rotated(randf_range(0, TAU)) * 350.0
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, 2.0, Color(0.4, 0.9, 1.0))
					game.spawn_vfx("shockwave", dest, 0.0, 2.0, Color(0.4, 0.9, 1.0))
				_plr.global_position = dest
				Audio.sfx("powerup", 0.08)

		# Mur de glace régénérant : réapparaît 10 s après destruction
		if _regen_ice_wall and hp <= 0.0 and _regen_t > 0.0:
			_regen_t -= delta
			if _regen_t <= 0.0:
				hp = _hp_start
				if _sprite != null:
					_sprite.visible = true
				if _cycle_col != null:
					_cycle_col.set_deferred("disabled", false)
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, 1.5, Color(0.6, 0.9, 1.0))

		# --- Bible des niveaux — Niveau 7 (Le Noyau Instable / reacteur) ---
		# Canon à particules instable : charge et divise son tir en 3
		if _particle_cannon and dist < 1400.0:
			_pcannon_t -= delta
			if _pcannon_t <= 0.0:
				_pcannon_t = _pcannon_cd
				if game != null and game.has_method("spawn_ground_zone"):
					for frag in 3:
						var ang: float = float(frag - 1) * 0.4
						var target_dir: Vector2 = (_plr.global_position - global_position).normalized().rotated(ang)
						var target_pos: Vector2 = global_position + target_dir * minf(dist, _pcannon_r)
						game.spawn_ground_zone(target_pos, 70.0, 1.2, _pcannon_dmg, Color(0.4, 1.0, 0.5), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 2.0, Color(0.4, 1.0, 0.5))
					Audio.sfx("shoot", 0.08)

		# Bobine de Tesla : arc électrique reliant à distance
		if _tesla_coil and dist < 1200.0:
			_tesla_t -= delta
			if _tesla_t <= 0.0:
				_tesla_t = _tesla_cd
				if game != null and "enemy_layer" in game:
					var gz: GroundZone = GroundZone.new()
					gz.radius = 45.0; gz.delay = 1.0; gz.damage = 25.0
					gz.color = Color(0.4, 1.0, 0.5)
					gz.shape = "line"; gz.line_from = Vector2.ZERO; gz.line_to = Vector2.RIGHT.rotated(randf_range(0, TAU)) * _tesla_r
					gz.game = game; gz.player = _plr
					game.enemy_layer.add_child(gz)
					gz.global_position = global_position
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 1.6, Color(0.5, 1.0, 0.6))

		# Barre de contrôle : réduit les dégâts de zone d'énergie si le joueur reste à portée
		if _control_rod:
			if dist < _control_rod_r:
				_control_rod_t += delta
				if _control_rod_t >= 1.5:
					_control_rod_active_t = 8.0
					_control_rod_t = 0.0
					if game != null and game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 1.8, Color(1.0, 0.85, 0.2))
					Audio.sfx("powerup", 0.08)
			else:
				_control_rod_t = maxf(0.0, _control_rod_t - delta * 0.5)
			if _control_rod_active_t > 0.0:
				_control_rod_active_t -= delta

		# Cellule de confinement : dôme bloquant les projectiles ennemis pendant 6 s
		if _containment_cell:
			if _containment_active_t > 0.0:
				_containment_active_t -= delta
				var r2_dome: float = _containment_r * _containment_r
				for b in get_tree().get_nodes_in_group("enemy_bullets"):
					if b is Node2D and is_instance_valid(b):
						if global_position.distance_squared_to((b as Node2D).global_position) <= r2_dome:
							b.call_deferred("queue_free")
			elif _containment_cd_t > 0.0:
				_containment_cd_t -= delta
			elif dist < _containment_r * 0.6:
				_containment_active_t = 6.0
				_containment_cd_t = _containment_cd
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, 2.2, Color(0.4, 1.0, 0.5))
				Audio.sfx("powerup", 0.08)

		# --- Bible des niveaux — Niveau 8 (La Ruche / ruche) ---
		# Organe cracheur d'acide : crache 3 globules laissant des flaques
		if _acid_turret and dist < 1300.0:
			_acid_t -= delta
			if _acid_t <= 0.0:
				_acid_t = _acid_cd
				if game != null and game.has_method("spawn_ground_zone"):
					for i in 3:
						var offset: Vector2 = Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(40.0, _acid_r)
						game.spawn_ground_zone(global_position + offset, 60.0, 1.0 + float(i) * 0.3, 16.0, Color(0.8, 0.9, 0.3), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 1.8, Color(0.8, 0.9, 0.3))
					Audio.sfx("shoot", 0.08)

		# Pondoir : génère des petites larves
		if _spawner_egg and dist < 1200.0:
			_egg_spawn_t -= delta
			if _egg_spawn_t <= 0.0:
				_egg_spawn_t = _egg_spawn_cd
				if game != null and game.has_method("awaken_enemy"):
					game.awaken_enemy(global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), "rush")
				if game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, 1.5, Color(0.7, 0.3, 0.8))

		# Veine pulsatile : pulse et repousse tout le long de son axe
		if _vein_pulse and dist < 1200.0:
			_vein_t -= delta
			if _vein_t <= 0.0:
				_vein_t = _vein_cd
				var r2_v: float = _vein_r * _vein_r
				if _plr != null and global_position.distance_squared_to(_plr.global_position) <= r2_v:
					var p_dir: Vector2 = (_plr.global_position - global_position).normalized()
					_plr.global_position += p_dir * (_vein_force * 0.4)
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and is_instance_valid(e):
						if global_position.distance_squared_to((e as Node2D).global_position) <= r2_v:
							var e_dir: Vector2 = ((e as Node2D).global_position - global_position).normalized()
							(e as Node2D).global_position += e_dir * (_vein_force * 0.6)
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, 2.0, Color(0.6, 0.2, 0.7))

		# --- Bible des niveaux — Niveau 9 (La Citadelle Orbitale / citadelle) ---
		# Lanceur orbital : missiles guidés à tête chercheuse
		if _guided_launcher and dist < 1400.0:
			_glauncher_t -= delta
			if _glauncher_t <= 0.0:
				_glauncher_t = _glauncher_cd
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(_plr.global_position, 85.0, 1.6, _glauncher_dmg, Color(1.0, 0.5, 0.1), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 2.0, Color(1.0, 0.6, 0.2))
					Audio.sfx("shoot", 0.08)

		# Relais satellite : pulsations orbitales périodiques
		if _satellite_relay and dist < 1300.0:
			_srelay_t -= delta
			if _srelay_t <= 0.0:
				_srelay_t = _srelay_cd
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, _srelay_r, 1.2, 20.0, Color(0.3, 0.8, 1.0), kind)
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, 2.5, Color(0.4, 0.9, 1.0))

		# Sas pressurisé : bloque / débloque périodiquement
		if _airlock:
			_airlock_t -= delta
			if _airlock_t <= 0.0:
				_airlock_t = _airlock_cd
				_airlock_open = not _airlock_open
				if _cycle_col != null:
					_cycle_col.set_deferred("disabled", _airlock_open)
				if _sprite != null:
					_sprite.modulate.a = 0.4 if _airlock_open else 1.0

		# Dôme-bouclier orbital : dôme déviant les tirs ennemis
		if _dome_shield:
			if _dome_active_t > 0.0:
				_dome_active_t -= delta
				var r2_d: float = _dome_r * _dome_r
				for b in get_tree().get_nodes_in_group("enemy_bullets"):
					if b is Node2D and is_instance_valid(b):
						if global_position.distance_squared_to((b as Node2D).global_position) <= r2_d:
							b.call_deferred("queue_free")
			elif _dome_cd_t > 0.0:
				_dome_cd_t -= delta
			elif dist < _dome_r * 0.7:
				_dome_active_t = 8.0
				_dome_cd_t = _dome_cd
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, 2.2, Color(0.4, 0.9, 1.0))
				Audio.sfx("powerup", 0.08)

		# Grappin magnétique : attire périodiquement les ennemis
		if _magnetic_hook and dist < 1200.0:
			_hook_t -= delta
			if _hook_t <= 0.0:
				_hook_t = _hook_cd
				var r2_h: float = _hook_r * _hook_r
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and is_instance_valid(e):
						if global_position.distance_squared_to((e as Node2D).global_position) <= r2_h:
							var pull_dir: Vector2 = (global_position - (e as Node2D).global_position).normalized()
							(e as Node2D).global_position += pull_dir * _hook_force
				if game != null and game.has_method("spawn_vfx"):
					game.spawn_vfx("shockwave", global_position, 0.0, 1.8, Color(0.3, 0.8, 1.0))

		# --- SURCHAUFFE DU SOL (Fonderie) : re-spawn une GroundZone un peu plus grande toutes les
		# ~2s jusqu'a un rayon max - simule une croissance SANS vraie persistance (GroundZone ne
		# peut pas durer indefiniment, voir le plan).
		if _overheat and dist < 1300.0:
			_overheat_t -= delta
			if _overheat_t <= 0.0:
				_overheat_t = 2.0
				_overheat_r = minf(_overheat_r + 20.0, _overheat_max)
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, _overheat_r, 0.6, 8.0, Color(1.0, 0.25, 0.05), kind)

		# --- ZONE DE CHARGEMENT (Quai de chargement) : cercle telegraphie classique a intervalle,
		# rien de nouveau au-dela d'un appel periodique a spawn_ground_zone.
		if _dropzone and dist < 1300.0:
			_dropzone_t -= delta
			if _dropzone_t <= 0.0:
				_dropzone_t = randf_range(10.0, 18.0)
				if game != null and game.has_method("spawn_ground_zone"):
					var off: Vector2 = Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0))
					game.spawn_ground_zone(global_position + off, 80.0, 1.5, 30.0, Color(1.0, 0.6, 0.0), kind)

		# --- CONTAINER MOBILE (Quai de chargement) : translate entre 2 points sur un rail fixe.
		# Origine capturee au premier tick (pas en _ready) pour ne jamais dependre de l'ordre
		# position/add_child de l'appelant.
		if _rail:
			if not _rail_inited:
				_rail_inited = true
				_rail_origin = global_position
			_rail_t += delta * _rail_speed / maxf(_rail_span, 1.0) * (1.0 if _rail_fwd else -1.0)
			if _rail_t >= 1.0:
				_rail_t = 1.0; _rail_fwd = false
			elif _rail_t <= 0.0:
				_rail_t = 0.0; _rail_fwd = true
			global_position = _rail_origin + _rail_dir * (_rail_span * (_rail_t - 0.5))

		# --- PLAQUE DE GLACE (Cryo-Voute) : glisse continue tant que le joueur reste dans le
		# rayon, meme idiome que le champ de ralentissement (_slow) mais sur le canal dedie
		# _patch_inertia (voir Player.gd : inertia sert deja de reglage fixe par biome).
		if _ice_patch:
			if _ice_patch_ring != null:
				_ice_patch_ring.modulate.a = 0.14 + 0.06 * sin(Time.get_ticks_msec() * 0.0032)
			if dist < _ice_patch_r and "_patch_inertia" in _plr:
				_plr._patch_inertia = maxf(_plr._patch_inertia, _ice_patch_amt)

		# --- JET DE CRYO (Cryo-Voute) : cercle classique a intervalle qui gele (stun) au lieu de
		# frapper en ligne - meme idiome que bras_presseur (Secteur Tech).
		if _cryo_jet and dist < 1300.0:
			_cryo_jet_t -= delta
			if _cryo_jet_t <= 0.0:
				_cryo_jet_t = randf_range(6.0, 12.0)
				if game != null and game.has_method("spawn_ground_zone"):
					var z: GroundZone = GroundZone.new()
					z.radius = _cryo_jet_r; z.delay = 1.0; z.damage = 0.0
					z.color = Color(0.6, 0.85, 1.0); z.stun_duration = _cryo_jet_stun; z.fx_kind = kind
					z.game = game; z.player = _plr
					game.enemy_layer.add_child(z)
					z.global_position = global_position

		# --- BROUILLARD FROID (Serres Gelees) : derive en ligne droite, change de direction a
		# intervalle aleatoire - seule vraie nouveaute de mouvement de cette phase (container_mobile
		# restait sur un rail a 2 points fixes). Reste dans l'arene de jeu (meme clamp que le joueur).
		if _fog:
			_fog_retarget_t -= delta
			if _fog_retarget_t <= 0.0:
				_fog_retarget_t = randf_range(4.0, 8.0)
				_fog_dir = Vector2.RIGHT.rotated(randf() * TAU)
			global_position += _fog_dir * 18.0 * delta
			if game != null and "arena" in game:
				global_position.x = clampf(global_position.x, game.arena.position.x, game.arena.end.x)
				global_position.y = clampf(global_position.y, game.arena.position.y, game.arena.end.y)
			if _fog_sprite != null:
				_fog_sprite.modulate.a = 0.42 * _fog_alpha_mult
			_fog_alpha_mult = minf(1.0, _fog_alpha_mult + delta * 0.3)   # recupere lentement hors radiateur
			# 14/10 (patron : decors « sans effet ») : le brouillard n'etait qu'un voile visuel et le
			# radiateur ne dissipait donc... rien d'utile. Effet reel : le froid ralentit tout ce qui
			# traverse un brouillard EPAIS (>50 %), joueur et horde ; le radiateur l'annule.
			if _fog_alpha_mult > 0.5:
				if dist < _fog_r and "field_slow" in _plr:
					_plr.field_slow = minf(float(_plr.field_slow), 0.72)
				if dist < 1300.0:
					var r2f: float = _fog_r * _fog_r
					for e in get_tree().get_nodes_in_group("enemies"):
						if e is Node2D and "field_slow" in e and global_position.distance_squared_to((e as Node2D).global_position) <= r2f:
							e.field_slow = minf(float(e.field_slow), 0.72)

		# --- RADIATEUR (Serres Gelees) : a portee, dissipe localement le brouillard le plus
		# proche - meme idiome que console_convoyeur qui parcourt un groupe de props voisins.
		if _defroster:
			var _defroster_active: bool = false
			for f in get_tree().get_nodes_in_group("cryo_fog"):
				if f is Node2D and "_fog_alpha_mult" in f:
					if global_position.distance_to((f as Node2D).global_position) <= _defroster_r:
						f._fog_alpha_mult = 0.0
						_defroster_active = true
			if _defroster_ring != null:
				var target_a: float = (0.22 + 0.06 * sin(Time.get_ticks_msec() * 0.01)) if _defroster_active else 0.0
				_defroster_ring.modulate.a = lerpf(_defroster_ring.modulate.a, target_a, 0.2)

		# --- PIC DE GLACE (Serres Gelees) : cercle classique a intervalle, meme idiome que
		# bras_presseur/surchauffe_sol, pas de nouveaute au-dela d'un ralentissement court.
		if _ice_spike and dist < 1300.0:
			_ice_spike_t -= delta
			if _ice_spike_t <= 0.0:
				_ice_spike_t = randf_range(5.0, 10.0)
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, 55.0, 1.2, 12.0, Color(0.7, 0.9, 1.0), kind)
				if dist < 55.0 and "field_slow" in _plr:
					_plr.field_slow = minf(_plr.field_slow, 0.5)

		# --- BORNE THERMIQUE / GLACE FRAGILE : juste la decrementation du cooldown pour la borne
		# (le declenchement vient du signal DwellZone.filled, _on_thermal_filled plus bas) ; pour
		# la glace fragile, un simple timer qui bascule la collision partagee en permanent.
		if _thermal:
			if _thermal_cd_t > 0.0:
				_thermal_cd_t -= delta
			if _thermal_zone != null:
				_thermal_zone.active = _thermal_cd_t <= 0.0   # anneau eteint pendant la recharge
		if _fragile_ice and not _fragile_broken:
			_fragile_ice_t -= delta
			if _fragile_ice_t <= 0.0:
				_fragile_broken = true
				if _cycle_col != null and _cycle_col.shape is CircleShape2D:
					(_cycle_col.shape as CircleShape2D).radius = maxf(60.0, block_r)
				if _sprite != null:
					_sprite.modulate = Color(0.55, 0.65, 0.78)   # glace sombre/effondree, lecture claire
				if game != null and game.has_method("impact_fx"):
					game.impact_fx(global_position, Color(0.6, 0.8, 1.0), kind, Vector2.ZERO, 1.2)

		# --- BASSIN TOXIQUE (Bassins Toxiques) : degats continus tant que le joueur reste dans
		# le rayon, meme idiome que plaque_de_glace mais degat au lieu de glisse. Une vanne de
		# drainage proche peut le suspendre (voir _on_drain_filled).
		if _toxic_pool:
			if _toxic_ring != null:
				_toxic_ring.modulate.a = (0.08 if _toxic_suppressed_t > 0.0 else 0.18) + 0.07 * sin(Time.get_ticks_msec() * 0.004)
			if _toxic_suppressed_t > 0.0:
				_toxic_suppressed_t -= delta
			elif dist < _toxic_r and _plr.has_method("take_damage"):
				_plr.take_damage(_toxic_dps * delta, global_position)

		# --- VANNE DE DRAINAGE : juste la decrementation du cooldown, le declenchement vient du
		# signal DwellZone.filled (_on_drain_filled plus bas).
		if _drain:
			if _drain_cd_t > 0.0:
				_drain_cd_t -= delta
			if _drain_zone != null:
				_drain_zone.active = _drain_cd_t <= 0.0   # anneau eteint pendant la recharge

		# --- POCHE DE VENT (Salle des Turbines, simplifiee en zone locale) : pousse le joueur ET
		# les ennemis en continu, meme idiome que convoyeur_sol (Secteur Tech).
		if _wind:
			var wind_step: Vector2 = _wind_dir * _wind_speed * delta
			if dist < _wind_r:
				_plr.global_position += wind_step
			var r2w: float = _wind_r * _wind_r
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node2D and global_position.distance_squared_to((e as Node2D).global_position) <= r2w:
					(e as Node2D).global_position += wind_step

		# --- CONSOLE DE VENT : juste la decrementation du cooldown, le declenchement vient du
		# signal DwellZone.filled (_on_wind_console_filled plus bas).
		if _wind_console:
			if _wind_console_cd_t > 0.0:
				_wind_console_cd_t -= delta
			if _wind_console_zone != null:
				_wind_console_zone.active = _wind_console_cd_t <= 0.0   # anneau eteint pendant la recharge

		# --- GRILLE DE VENTILATION (Salle des Turbines) : cercle classique a intervalle, meme
		# idiome que bras_presseur/pic_de_glace - stun (projection approchee) au lieu de ligne.
		if _vent_grate and dist < 1300.0:
			_vent_grate_t -= delta
			if _vent_grate_t <= 0.0:
				_vent_grate_t = randf_range(7.0, 14.0)
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, 55.0, 1.0, 10.0, Color(1.0, 0.7, 0.2), kind)

		# --- ZONE ALTERNANTE (Noyau Fissure) : reutilise le on/off de _cycle pour le rythme
		# sure/danger ; degats continus seulement pendant la phase "presente" (danger).
		if _alt_zone:
			if _alt_warn_ring != null:
				if not _cycle_present and _cycle_t <= 1.0:
					var warn_urg: float = 1.0 - clampf(_cycle_t / 1.0, 0.0, 1.0)
					var ablink: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * (6.0 + warn_urg * 40.0))
					_alt_warn_ring.modulate.a = warn_urg * ablink * 0.6
				else:
					_alt_warn_ring.modulate.a = 0.0
			if _cycle_present and dist < _alt_zone_r and _plr.has_method("take_damage"):
				_plr.take_damage(_alt_zone_dps * delta, global_position)

		# --- CRISTAL D'ENERGIE INSTABLE (Noyau Fissure) : une fois arme (DwellZone au contact),
		# explose apres un court delai - meme idiome que surchauffe_sol pour le timer.
		if _unstable_crystal and _crystal_armed:
			_crystal_t -= delta
			if _crystal_t <= 0.0:
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, 100.0, 0.3, 25.0, Color(0.8, 1.0, 0.2), kind)
				call_deferred("queue_free")

		# --- PULSE D'ENERGIE (Noyau Fissure) : anneau qui "s'etend" - meme idiome que
		# surchauffe_sol (respawn une GroundZone un peu plus grande a chaque tick).
		if _energy_pulse and dist < 1300.0:
			_energy_pulse_t -= delta
			if _energy_pulse_t <= 0.0:
				_energy_pulse_t = randf_range(6.0, 10.0)
				if game != null and game.has_method("spawn_ground_zone"):
					for ring in 3:   # 3 anneaux successifs qui s'eloignent, cf. "pulse qui s'etend"
						game.spawn_ground_zone(global_position, 60.0 + float(ring) * 50.0,
							0.4 + float(ring) * 0.2, 12.0, Color(0.8, 1.0, 0.2), kind)

		# --- SOL COLLANT (Veines Vivantes) : ralentit le joueur en continu - reutilise field_slow
		# directement, meme idiome que le champ de ralentissement _slow deja en jeu.
		if _sticky:
			if _sticky_ring != null:
				_sticky_ring.modulate.a = 0.14 + 0.06 * sin(Time.get_ticks_msec() * 0.0028)
			if dist < _sticky_r and "field_slow" in _plr:
				_plr.field_slow = minf(_plr.field_slow, _sticky_mult)

		# --- RESIDU BIOMECANIQUE (Couvoir Mecanique) : ralentit le joueur (meme canal field_slow
		# que _sticky) ET attire en continu les ennemis proches vers son centre - meme math que
		# _guard/AIMANT mais direction inversee (vers soi, pas loin) et sans cooldown (piege
		# organique permanent, pas une pulsation).
		if _bio_residue:
			if _bio_residue_ring != null:
				_bio_residue_ring.modulate.a = 0.14 + 0.06 * sin(Time.get_ticks_msec() * 0.0028 + 1.7)
			if dist < _bio_residue_r and "field_slow" in _plr:
				_plr.field_slow = minf(_plr.field_slow, _bio_residue_slow)
			if dist < 1300.0:
				var r2b: float = _bio_residue_r * _bio_residue_r
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D:
						var to_center: Vector2 = global_position - (e as Node2D).global_position
						var d2b: float = to_center.length_squared()
						if d2b <= r2b and d2b > 1.0:
							(e as Node2D).global_position += to_center.normalized() * (_bio_residue_pull * delta)

		# --- EMERGENCE DE TENTACULE (Veines Vivantes) : cercle classique a intervalle, meme
		# idiome que bras_presseur/pic_de_glace/grille_ventilation.
		if _tentacle and dist < 1300.0:
			_tentacle_t -= delta
			if _tentacle_t <= 0.0:
				_tentacle_t = randf_range(6.0, 12.0)
				if game != null and game.has_method("spawn_ground_zone"):
					game.spawn_ground_zone(global_position, 70.0, 1.0, 12.0, Color(0.5, 0.2, 0.7), kind)

		# --- NUAGE DE SPORES (Jardin de Spores) : derive comme brouillard_froid + degats continus
		# comme bassin_toxique - combine deux idiomes deja prouves, aucune nouveaute.
		if _spore_cloud:
			_spore_retarget_t -= delta
			if _spore_retarget_t <= 0.0:
				_spore_retarget_t = randf_range(4.0, 8.0)
				_spore_dir = Vector2.RIGHT.rotated(randf() * TAU)
			global_position += _spore_dir * 14.0 * delta
			if game != null and "arena" in game:
				global_position.x = clampf(global_position.x, game.arena.position.x, game.arena.end.x)
				global_position.y = clampf(global_position.y, game.arena.position.y, game.arena.end.y)
			if _spore_suppressed_t > 0.0:
				_spore_suppressed_t -= delta
			elif dist < _spore_r and _plr.has_method("take_damage"):
				_plr.take_damage(_spore_dps * delta, global_position)
			if _spore_sprite != null:
				_spore_sprite.modulate.a = 0.38 if _spore_suppressed_t <= 0.0 else 0.08

		# --- PLANTE LUMINEUSE : juste la decrementation du cooldown, le declenchement vient du
		# signal DwellZone.filled (_on_light_plant_filled plus bas).
		if _light_plant:
			if _light_plant_cd_t > 0.0:
				_light_plant_cd_t -= delta
			if _light_plant_zone != null:
				_light_plant_zone.active = _light_plant_cd_t <= 0.0   # anneau eteint pendant la recharge

		# --- ZONE DE DEPRESSURISATION (Pont Orbital) : aspire le joueur vers le centre a
		# intervalle, meme idiome que _push (impulsion) mais direction inversee (vers soi).
		if _depress and dist < 1300.0:
			_depress_t -= delta
			if _depress_warn != null:
				var dwarn_urg: float = 1.0 - clampf(_depress_t / 0.7, 0.0, 1.0)
				_depress_warn.modulate.a = dwarn_urg * (0.3 + 0.25 * sin(Time.get_ticks_msec() * 0.001 * (8.0 + dwarn_urg * 30.0)))
			if _depress_t <= 0.0:
				_depress_t = randf_range(10.0, 18.0)
				if _depress_warn != null:
					_depress_warn.modulate.a = 0.0
				if dist < _depress_r and dist > 1.0:
					var to_center: Vector2 = (global_position - _plr.global_position).normalized()
					_plr.global_position += to_center * (_depress_force * 0.12)
				if game != null and game.has_method("impact_fx"):
					game.impact_fx(global_position, Color(1.0, 0.3, 0.2), kind, Vector2.ZERO, _depress_r / 95.0)

		# --- ZONE PUSH/PULL (Anneau de Gravite) : pousse en continu en phase "push", attire en
		# continu en phase "pull" - minuteur INDEPENDANT (_grav_phase_on), le sprite/collider reste
		# TOUJOURS visible (04/10, corrige le bug ou l'ancien partage de _cycle le masquait
		# justement pendant la phase ou la force s'applique). La teinte distingue les 2 phases.
		if _grav_zone:
			_grav_phase_t -= delta
			if _grav_phase_t <= 0.0:
				_grav_phase_on = not _grav_phase_on
				_grav_phase_t = _grav_on_dur if _grav_phase_on else _grav_off_dur
			if _sprite != null:
				_sprite.modulate = Color(0.6, 1.0, 1.0) if _grav_phase_on else Color(1.0, 0.75, 0.55)
			if dist < _grav_r and dist > 1.0:
				var away: Vector2 = (_plr.global_position - global_position).normalized()
				var grav_step: Vector2 = away * _grav_force * delta * (1.0 if _grav_phase_on else -1.0)
				_plr.global_position += grav_step

		# --- EMETTEUR DE LASER ROTATIF (Anneau de Gravite) : GroundZone en ligne a intervalle,
		# meme idiome que bras_presseur/jet_de_cryo, mais l'angle avance a chaque tir -> le
		# balayage tourne au fil des activations (pas un vrai laser continu anime).
		if _rot_laser and dist < 1300.0:
			_rot_laser_t -= delta
			if _rot_laser_t <= 0.0:
				_rot_laser_t = randf_range(3.0, 6.0)
				_rot_laser_angle = fmod(_rot_laser_angle + deg_to_rad(35.0), TAU)
				if game != null and "enemy_layer" in game:
					var ldir: Vector2 = Vector2.RIGHT.rotated(_rot_laser_angle)
					var lhalf: Vector2 = ldir * 220.0
					var z: GroundZone = GroundZone.new()
					z.radius = 35.0; z.delay = 1.0; z.damage = 18.0
					z.color = Color(1.0, 0.75, 0.2); z.fx_kind = kind
					z.shape = "line"; z.line_from = -lhalf; z.line_to = lhalf
					z.game = game; z.player = _plr
					game.enemy_layer.add_child(z)
					z.global_position = global_position

		# --- capaciteur: idle -> telegraph -> fire, on a fixed loop ---
		# Only while the player is near enough to see it: with fixed decor there are capacitors all
		# over the arena, and a far one firing would waste work and play off-screen sounds.
		if _beam and dist < 1500.0:
			_tick_beam(delta)

		# --- field aura: lave burns / plante poisons / glace frosts / racines snares / emetteur heals ---
		if _aura != "" and dist < 1400.0:
			_tick_aura(delta, dist)

		# --- fuel barrel: arm on approach, blink faster as the fuse burns, then blow ---
		if _boom:
			if _armed < 0.0 and dist <= BOOM_ARM_R:
				_armed = BOOM_FUSE
				Audio.sfx("click", 0.1)
			if _armed >= 0.0:
				_armed -= delta
				# blink rate ramps from ~3Hz to ~14Hz as the fuse runs out -> readable urgency
				var urg: float = 1.0 - clampf(_armed / BOOM_FUSE, 0.0, 1.0)
				var blink: float = sin(Time.get_ticks_msec() * 0.001 * (18.0 + urg * 70.0))
				if _sprite != null:
					_sprite.modulate = Color(1.0, 1.0, 1.0).lerp(Color(3.0, 0.5, 0.35), 0.5 + 0.5 * blink)
				if _armed <= 0.0:
					_explode()
					return

		# --- carcass: the guardian inside wakes when you come close ---
		if _awaken != "" and not _awoken and dist <= AWAKEN_R:
			_awoken = true
			set_process(false)
			if game.has_method("awaken_enemy"):
				game.awaken_enemy(global_position, _awaken)
			call_deferred("queue_free")   # _exit_tree pulls us out of cover_list

	## Arc pylon: forks a lightning bolt to the nearest enemy in range and damages it. Reads as a
	## friendly-ish hazard — lead the horde past and it chips them.
	## TERMINAL DE DELESTAGE : la jauge (DwellZone, voir _ready) vient de se remplir -> une onde
	## unique repousse les petits ennemis proches et ouvre une fenetre de fuite. Position directe
	## (jamais velocity, voir la note dans le bloc IMPULSION plus haut).
	func _on_dwell_filled() -> void:
		var r2: float = 260.0 * 260.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D:
				var away: Vector2 = (e as Node2D).global_position - global_position
				var d2: float = away.length_squared()
				if d2 <= r2 and d2 > 1.0:
					(e as Node2D).global_position += away.normalized() * _dwell_force
		if game != null and game.has_method("impact_fx"):
			game.impact_fx(global_position, Palette.CYAN, kind, Vector2.ZERO, 3.0)
		Events.screen_shake.emit(2.5)

	## CONSOLE DE CONVOYEUR (Hall d'Assemblage) : la jauge (DwellZone dediee, voir _ready) vient
	## de se remplir -> coupe les convoyeurs proches pendant console_stop_dur. Cooldown en
	## timestamp absolu (pas de _process dedie a ce prop, comme "terminal").
	func _on_console_filled() -> void:
		if _console_cd_t > 0.0:
			return
		_console_cd_t = _console_cd
		var r2: float = _console_r * _console_r
		for p in get_tree().get_nodes_in_group("tech_convoyeur"):
			if p is Node2D and "_conveyor_stop_t" in p:
				if global_position.distance_squared_to((p as Node2D).global_position) <= r2:
					p._conveyor_stop_t = _console_stop_dur
		if game != null and game.has_method("impact_fx"):
			game.impact_fx(global_position, Palette.CYAN, kind, Vector2.ZERO, 2.5)

	## Soin reel des vannes/bornes : un pourcentage des PV max, avec l'effet vert habituel des soins.
	func _cool_down_player(frac: float) -> void:
		if _plr == null or not is_instance_valid(_plr):
			return
		if _plr.has_method("heal") and "max_hp" in _plr:
			_plr.heal(float(_plr.max_hp) * frac)
		if game != null and game.has_method("spawn_vfx"):
			game.spawn_vfx("heal", _plr.global_position, 0.0, 1.3)

	## VANNE DE REFROIDISSEMENT (Fonderie) : la jauge (DwellZone dediee, voir _ready) vient de se
	## remplir -> ouvre une zone sure temporaire (GroundZone a 0 degat, repere visuel + petit
	## repit). Pas de contre-effet ailleurs (hors scope, voir le plan).
	func _on_valve_filled() -> void:
		if _valve_cd_t > 0.0:
			return
		_valve_cd_t = _valve_cd
		# 14/10 (patron : « certains decors n'ont aucun effet ») : la « zone sure » n'etait qu'une
		# GroundZone a 0 degat = un cercle d'avertissement qui ne fait RIEN. Effet reel : soigne 20 %
		# des PV et eteint les sols en surchauffe voisins (reset + gel 12 s de leur croissance).
		_cool_down_player(0.20)
		var r2v: float = _valve_r * _valve_r * 4.0
		for q in get_tree().get_nodes_in_group("cover"):
			if q is Prop and (q as Prop)._overheat and global_position.distance_squared_to((q as Node2D).global_position) <= r2v:
				(q as Prop)._overheat_r = 60.0
				(q as Prop)._overheat_t = 12.0
		if game != null and game.has_method("impact_fx"):
			game.impact_fx(global_position, Color(0.5, 0.9, 1.0), kind, Vector2.ZERO, _valve_r / 95.0)

	## BORNE THERMIQUE (Lac de Permafrost) : la jauge (DwellZone dediee, voir _ready) vient de se
	## remplir -> ouvre une zone sure temporaire, calque exact de _on_valve_filled (Fonderie).
	func _on_thermal_filled() -> void:
		if _thermal_cd_t > 0.0:
			return
		_thermal_cd_t = _thermal_cd
		_cool_down_player(0.20)   # 14/10 : la « zone sure » a 0 degat ne faisait rien -> soin reel
		if game != null and game.has_method("impact_fx"):
			game.impact_fx(global_position, Color(1.0, 0.7, 0.3), kind, Vector2.ZERO, _thermal_r / 95.0)

	## VANNE DE DRAINAGE (Bassins Toxiques) : suspend temporairement les bassins toxiques
	## voisins, meme idiome que _on_console_filled (Secteur Tech) qui parcourt un groupe voisin.
	func _on_drain_filled() -> void:
		if _drain_cd_t > 0.0:
			return
		_drain_cd_t = _drain_cd
		var r2: float = _drain_r * _drain_r
		for p in get_tree().get_nodes_in_group("reacteur_toxic"):
			if p is Node2D and "_toxic_suppressed_t" in p:
				if global_position.distance_squared_to((p as Node2D).global_position) <= r2:
					p._toxic_suppressed_t = 10.0
		if game != null and game.has_method("impact_fx"):
			game.impact_fx(global_position, Palette.CYAN, kind, Vector2.ZERO, 2.5)

	## CONSOLE DE VENT (Salle des Turbines) : inverse la direction des poches de vent voisines.
	func _on_wind_console_filled() -> void:
		if _wind_console_cd_t > 0.0:
			return
		_wind_console_cd_t = _wind_console_cd
		# 04/10, WEAK signale par le patron : le VFX de confirmation ne jouait QU'a la console, donc
		# l'inversion de la poche de vent elle-meme etait invisible. Joue maintenant A CHAQUE poche
		# de vent reellement inversee, en plus de la confirmation a la console.
		var r2: float = _wind_console_r * _wind_console_r
		for p in get_tree().get_nodes_in_group("reacteur_wind"):
			if p is Node2D and "_wind_dir" in p:
				if global_position.distance_squared_to((p as Node2D).global_position) <= r2:
					p._wind_dir = -p._wind_dir
					if game != null and game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", (p as Node2D).global_position, 0.0, 2.0, Palette.CYAN)
		if game != null and game.has_method("spawn_vfx"):
			game.spawn_vfx("shockwave", global_position, 0.0, 2.5, Palette.CYAN)

	## CRISTAL D'ENERGIE INSTABLE (Noyau Fissure) : le joueur l'a touche -> arme le compte a
	## rebours avant explosion (voir le tick plus haut).
	func _on_crystal_armed() -> void:
		if _crystal_armed:
			return
		_crystal_armed = true
		_crystal_t = 3.0
		if _sprite != null:
			_sprite.modulate = Color(1.6, 1.8, 0.8)   # lueur vive : "ramasse, va exploser"
		if game != null and game.has_method("impact_fx"):
			game.impact_fx(global_position, Color(0.8, 1.0, 0.2), kind, Vector2.ZERO, 1.5)

	## PLANTE LUMINEUSE (Jardin de Spores) : dissipe les nuages de spores voisins, meme idiome
	## que _on_drain_filled (Noyau Instable) / radiateur (Zone Cryo).
	func _on_light_plant_filled() -> void:
		if _light_plant_cd_t > 0.0:
			return
		_light_plant_cd_t = _light_plant_cd
		var r2: float = _light_plant_r * _light_plant_r
		for p in get_tree().get_nodes_in_group("ruche_spores"):
			if p is Node2D and "_spore_suppressed_t" in p:
				if global_position.distance_squared_to((p as Node2D).global_position) <= r2:
					p._spore_suppressed_t = 8.0
		if game != null and game.has_method("impact_fx"):
			game.impact_fx(global_position, Color(0.55, 1.0, 0.4), kind, Vector2.ZERO, 2.0)

	## COLLECTEUR SOLAIRE (Terres Calcinées / desert) : +25 % de jauge de surcharge
	func _on_solar_collector_filled() -> void:
		if _collector_cd_t > 0.0:
			return
		_collector_cd_t = _collector_cd
		GameState.add_overdrive(0.25)
		if game != null and game.has_method("spawn_vfx"):
			game.spawn_vfx("shockwave", global_position, 0.0, 2.5, Color(1.0, 0.85, 0.2))
			if _plr != null and is_instance_valid(_plr):
				game.spawn_vfx("energy", _plr.global_position, 0.0, 1.5, Color(1.0, 0.85, 0.2))
		Audio.sfx("powerup", 0.1)

	## PROJECTEUR DE MIRAGE (Terres Calcinées / desert) : leurre holographique 6 s
	func _on_mirage_filled() -> void:
		if _mirage_cd_t > 0.0 or _mirage_active_t > 0.0:
			return
		_mirage_cd_t = _mirage_cd
		_mirage_active_t = _mirage_dur
		if game != null and game.has_method("spawn_vfx"):
			game.spawn_vfx("shockwave", global_position, 0.0, 2.8, Palette.CYAN)
		Audio.sfx("teleport", 0.08)

	func _zap_nearest() -> void:
		var best: Node2D = null
		var bd: float = _pylon_r * _pylon_r
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and is_instance_valid(e) and "alive" in e and e.alive:
				var d: float = global_position.distance_squared_to((e as Node2D).global_position)
				if d < bd:
					bd = d; best = e
		if best == null:
			return
		if best.has_method("take_damage"):
			best.take_damage(_pylon_dmg)
		Audio.sfx("hit", 0.15)
		if game != null and game.has_method("spawn_arc"):
			game.spawn_arc(global_position + Vector2(0, -float(def.get("sz", 128.0)) * 0.35),
				best.global_position, Color(1.0, 0.95, 0.4))

	## EMP burst on destruction: damages + knocks back every enemy nearby. The reward for breaking it.
	func _emp_burst() -> void:
		var pos: Vector2 = global_position
		if game != null and game.has_method("impact_fx"):
			game.impact_fx(pos, Color(1.0, 0.95, 0.4), kind, Vector2.ZERO, 2.0)
		Events.screen_shake.emit(6.0)
		var r2: float = 320.0 * 320.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and is_instance_valid(e) and "alive" in e and e.alive:
				var to: Vector2 = (e as Node2D).global_position - pos
				if to.length_squared() <= r2 and e.has_method("take_damage"):
					e.take_damage(_pylon_dmg * 1.6)
					if "velocity" in e:
						e.velocity += to.normalized() * 260.0   # knockback

	## Beam cycle. The telegraph is a thin bright line along the exact path the beam will take —
	## no guesswork, no tracking: the terrain does not chase the player, it simply exists, and a
	## hazard that aims at you reads as the game cheating.
	## Field-aura tick. burn/spore deal damage (every AURA_TICK); spore/frost/snare apply field_slow
	## every frame (it recovers each frame, so it must be re-applied); heal tops up nearby foes.
	func _tick_aura(delta: float, dist: float) -> void:
		if _aura_ring != null:
			_aura_ring.modulate.a = 0.12 + 0.07 * sin(Time.get_ticks_msec() * 0.004)
		_aura_t -= delta
		var tick: bool = _aura_t <= 0.0
		if tick:
			_aura_t = AURA_TICK
		var r2: float = _aura_r * _aura_r
		var plr_in: bool = dist < _aura_r
		match _aura:
			"burn":
				if plr_in and tick and _plr.has_method("take_damage"):
					_plr.take_damage(_aura_p1)
				if tick:
					for e in get_tree().get_nodes_in_group("enemies"):
						if e is Node2D and global_position.distance_squared_to((e as Node2D).global_position) <= r2 and e.has_method("take_damage"):
							e.take_damage(_aura_p1 * 1.4)
			"spore":
				if plr_in:
					if "field_slow" in _plr:
						_plr.field_slow = minf(_plr.field_slow, _aura_p2)
					if tick and _plr.has_method("take_damage"):
						_plr.take_damage(_aura_p1)
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
						if "field_slow" in e:
							e.field_slow = minf(e.field_slow, _aura_p2)
						if tick and e.has_method("take_damage"):
							e.take_damage(_aura_p1)
			"frost":   # enemies only — a tactical slow you herd the horde into
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and "field_slow" in e and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
						e.field_slow = minf(e.field_slow, _aura_p1)
			"snare":   # traps player AND foes
				if plr_in and "field_slow" in _plr:
					_plr.field_slow = minf(_plr.field_slow, _aura_p1)
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and "field_slow" in e and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
						e.field_slow = minf(e.field_slow, _aura_p1)
			"heal":    # repair node: tops up nearby foes -> a priority target
				if tick:
					for e in get_tree().get_nodes_in_group("enemies"):
						if e is Node2D and "hp" in e and "hp_max" in e and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
							e.hp = minf(float(e.hp_max), float(e.hp) + _aura_p1)

	## Crystal shatter on destruction: a damaging shard ring + a bright shockwave + a little Overdrive.
	func _shatter_burst() -> void:
		if game == null:
			return
		var r: float = 240.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and global_position.distance_squared_to((e as Node2D).global_position) <= r * r and e.has_method("take_damage"):
				e.take_damage(60.0)
		if game.has_method("aura_discharge_fx"):
			game.aura_discharge_fx(global_position, r, Color(0.5, 0.95, 1.0))
		GameState.add_overdrive(0.10)
		Audio.sfx("explosion", 0.1)

	## One additive round-capped beam layer at z-order `z` (glow/body/core share this).
	func _mk_beam(z: int) -> Line2D:
		var ln: Line2D = Line2D.new()
		ln.top_level = true                    # world space: not scaled by the prop
		ln.material = Tex.add_mat()
		ln.z_index = z
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		ln.visible = false
		add_child(ln)
		return ln

	## Layered energy beam: wide halo + coloured body + white-hot core + a muzzle bloom, with a
	## readable charge (thin bright warning line that thickens) then a fat pulsing discharge.
	func _tick_beam(delta: float) -> void:
		_beam_t -= delta
		var a: Vector2 = global_position
		var b: Vector2 = a + _beam_dir * BEAM_LEN
		var pts: PackedVector2Array = PackedVector2Array([a, b])
		match _beam_state:
			0:
				if _beam_t <= 0.0:
					_beam_state = 1
					_beam_t = BEAM_TELL
					for ln in [_beam_glow, _beam_line, _beam_core]:
						ln.points = pts; ln.visible = true
					Audio.sfx("w_railgun", 0.05)      # rising "capacitor charging" whine
			1:
				# thin bright warning line that thickens + brightens as the shot nears (readable)
				var k: float = 1.0 - clampf(_beam_t / BEAM_TELL, 0.0, 1.0)
				var puls: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
				_beam_core.width = 1.5 + k * 3.0
				_beam_core.default_color = Color(1, 1, 1, 0.35 + k * 0.5)
				_beam_line.width = 2.0 + k * 8.0
				_beam_line.default_color = Color(BEAM_COL.r, BEAM_COL.g, BEAM_COL.b, 0.22 + k * 0.4)
				_beam_glow.width = 6.0 + k * 26.0
				_beam_glow.default_color = Color(BEAM_COL.r, BEAM_COL.g, BEAM_COL.b, (0.10 + k * 0.20) * (0.6 + 0.4 * puls))
				if _beam_t <= 0.0:
					_beam_state = 2
					_beam_t = BEAM_FIRE
					_beam_flash.position = a
					_beam_flash.visible = true
					_fire_beam(a, b)
					Audio.sfx("w_plasma", 0.04)       # heavy discharge
			2:
				# fat, white-hot, flickering discharge that fades over BEAM_FIRE
				var f: float = clampf(_beam_t / BEAM_FIRE, 0.0, 1.0)
				var flick: float = 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.09)
				_beam_core.width = BEAM_HALF_W * 0.6 * flick
				_beam_core.default_color = Color(1, 1, 1, f)
				_beam_line.width = BEAM_HALF_W * 1.7 * flick
				_beam_line.default_color = Color(1.0, 0.6, 1.0, f * 0.95)
				_beam_glow.width = BEAM_HALF_W * 4.4 * flick
				_beam_glow.default_color = Color(BEAM_COL.r, BEAM_COL.g, BEAM_COL.b, f * 0.5)
				_beam_flash.scale = Vector2.ONE * (BEAM_HALF_W * 4.5 / 128.0) * (0.8 + 0.4 * flick)
				_beam_flash.modulate = Color(1.0, 0.7, 1.0, f)
				if _beam_t <= 0.0:
					_beam_state = 0
					_beam_t = BEAM_IDLE
					for ln in [_beam_glow, _beam_line, _beam_core]:
						ln.visible = false
					_beam_flash.visible = false

	## Damage is applied ONCE at discharge, not per frame: a per-frame beam would delete the player
	## instantly and read as unfair. Enemies take ~4x the player's hit, which is what makes leading
	## the horde into the line the strongest play available.
	func _fire_beam(a: Vector2, b: Vector2) -> void:
		Audio.sfx("explosion", 0.12)
		if game != null and game.has_method("spawn_vfx"):
			game.spawn_vfx("energy", a, 0.0, 1.1, BEAM_COL)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and is_instance_valid(e) and e.has_method("take_damage"):
				var p: Vector2 = (e as Node2D).global_position
				if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= BEAM_HALF_W + 34.0:
					e.take_damage(_beam_dmg_enemy)
		if _plr != null and is_instance_valid(_plr) and _plr.has_method("take_damage"):
			var pp: Vector2 = _plr.global_position
			if Geometry2D.get_closest_point_to_segment(pp, a, b).distance_to(pp) <= BEAM_HALF_W + 22.0:
				_plr.take_damage(_beam_dmg, global_position)
				Events.screen_shake.emit(7.0)

	## Tourelle canon a rayon : tire automatiquement un rayon energetique a intervalle regulier
	## dans la direction de son canon fixe (ou balayage angulaire si soudeuse). Phase de charge (telegraph lumineux croissant)
	## suivie d'un tir de rayon fulgurant penetrant. Si pirate ou soudeuse, le rayon devient cyan et foudroie
	## les ennemis au lieu du joueur.
	func _tick_cannon_beam(delta: float) -> void:
		_cannon_beam_t -= delta
		var cur_cannon: Vector2 = _cannon
		var fire_time: float = float(def.get("fire_dur", 3.0)) if _welder else CANNON_FIRE
		var idle_time: float = float(def.get("idle_dur", 2.0)) if _welder else CANNON_IDLE
		var tell_time: float = _solar_charge if _solar_mirror else CANNON_TELL
		if _welder:
			var dur: float = fire_time if _cannon_beam_state == 2 else CANNON_TELL
			var progress: float = 1.0 - clampf(_cannon_beam_t / maxf(dur, 0.001), 0.0, 1.0)
			var cur_angle: float = lerpf(-_sweep_half, _sweep_half, progress)
			cur_cannon = _cannon.rotated(cur_angle)
		var a: Vector2 = global_position + _muzzle
		var b: Vector2 = a + cur_cannon * CANNON_LEN
		var pts: PackedVector2Array = PackedVector2Array([a, b])
		var base_col: Color = Color(1.0, 0.9, 0.4) if _solar_mirror else (Color(0.2, 0.85, 1.0) if (_hacked or _welder) else Color(1.0, 0.35, 0.1))

		match _cannon_beam_state:
			0:
				if _cannon_beam_t <= 0.0:
					_cannon_beam_state = 1
					_cannon_beam_t = tell_time
					for ln in [_cannon_beam_glow, _cannon_beam_line, _cannon_beam_core]:
						if ln != null and is_instance_valid(ln):
							ln.points = pts
							ln.visible = true
					Audio.sfx("w_railgun", 0.05)
					if game != null and game.has_method("spawn_vfx"):
						game.spawn_vfx("muzzle", a, cur_cannon.angle() + PI * 0.5, 0.25, base_col)
			1:
				# Telegraph : ligne laser fine de ciblage qui s'intensifie
				var k: float = 1.0 - clampf(_cannon_beam_t / maxf(tell_time, 0.001), 0.0, 1.0)
				var puls: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.035)
				for ln in [_cannon_beam_glow, _cannon_beam_line, _cannon_beam_core]:
					if ln != null and is_instance_valid(ln):
						ln.points = pts
				if _cannon_beam_core != null and is_instance_valid(_cannon_beam_core):
					_cannon_beam_core.width = 1.5 + k * 3.5
					_cannon_beam_core.default_color = Color(1.0, 1.0, 1.0, 0.35 + k * 0.55)
				if _cannon_beam_line != null and is_instance_valid(_cannon_beam_line):
					_cannon_beam_line.width = 2.0 + k * 9.0
					_cannon_beam_line.default_color = Color(base_col.r, base_col.g, base_col.b, 0.25 + k * 0.45)
				if _cannon_beam_glow != null and is_instance_valid(_cannon_beam_glow):
					_cannon_beam_glow.width = 6.0 + k * 26.0
					_cannon_beam_glow.default_color = Color(base_col.r, base_col.g, base_col.b, (0.10 + k * 0.22) * (0.6 + 0.4 * puls))
				if _cannon_beam_t <= 0.0:
					_cannon_beam_state = 2
					_cannon_beam_t = fire_time
					_cannon_hit_set.clear()
					if _cannon_beam_flash != null and is_instance_valid(_cannon_beam_flash):
						_cannon_beam_flash.position = a
						_cannon_beam_flash.visible = true
					_fire_cannon_beam(a, b, base_col, cur_cannon)
					Audio.sfx("w_plasma", 0.06)
			2:
				# Decharge de rayon laser : faisceau epais incandescent avec micro-flicker
				var f: float = clampf(_cannon_beam_t / maxf(fire_time, 0.001), 0.0, 1.0)
				var flick: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.1)
				for ln in [_cannon_beam_glow, _cannon_beam_line, _cannon_beam_core]:
					if ln != null and is_instance_valid(ln):
						ln.points = pts
				if _cannon_beam_core != null and is_instance_valid(_cannon_beam_core):
					_cannon_beam_core.width = CANNON_HALF_W * 0.65 * flick
					_cannon_beam_core.default_color = Color(1.0, 1.0, 1.0, f)
				if _cannon_beam_line != null and is_instance_valid(_cannon_beam_line):
					_cannon_beam_line.width = CANNON_HALF_W * 1.7 * flick
					_cannon_beam_line.default_color = Color(minf(base_col.r * 1.3, 1.0), minf(base_col.g * 1.3, 1.0), minf(base_col.b * 1.3, 1.0), f * 0.95)
				if _cannon_beam_glow != null and is_instance_valid(_cannon_beam_glow):
					_cannon_beam_glow.width = CANNON_HALF_W * 4.4 * flick
					_cannon_beam_glow.default_color = Color(base_col.r, base_col.g, base_col.b, f * 0.5)
				if _cannon_beam_flash != null and is_instance_valid(_cannon_beam_flash):
					_cannon_beam_flash.position = a
					_cannon_beam_flash.scale = Vector2.ONE * (CANNON_HALF_W * 4.5 / 128.0) * (0.8 + 0.4 * flick)
					_cannon_beam_flash.modulate = Color(base_col.r, base_col.g, base_col.b, f)
				_check_cannon_beam_hits(a, b, cur_cannon)
				if _cannon_beam_t <= 0.0:
					_cannon_beam_state = 0
					_cannon_beam_t = idle_time
					for ln in [_cannon_beam_glow, _cannon_beam_line, _cannon_beam_core]:
						if ln != null and is_instance_valid(ln):
							ln.visible = false
					if _cannon_beam_flash != null and is_instance_valid(_cannon_beam_flash):
						_cannon_beam_flash.visible = false

	func _fire_cannon_beam(a: Vector2, b: Vector2, base_col: Color, shot_dir: Vector2 = _cannon) -> void:
		Audio.sfx("explosion", 0.08)
		if game != null and game.has_method("spawn_vfx"):
			game.spawn_vfx("muzzle", a, shot_dir.angle() + PI * 0.5, 0.55, base_col)
			game.spawn_vfx("energy", a, 0.0, 1.0, base_col)
		if _solar_mirror and game != null and "enemy_layer" in game:
			var mid: Vector2 = (a + b) * 0.5
			var z: GroundZone = GroundZone.new()
			z.radius = 28.0; z.delay = 0.05; z.damage = _solar_dmg * 0.8
			z.color = Color(1.0, 0.8, 0.25)
			z.shape = "line"; z.line_from = a - mid; z.line_to = b - mid
			z.stun_duration = 0.0; z.fx_kind = kind
			z.game = game; z.player = _plr
			game.enemy_layer.add_child(z)
			z.global_position = mid
		_check_cannon_beam_hits(a, b, shot_dir)

	func _check_cannon_beam_hits(a: Vector2, b: Vector2, shot_dir: Vector2 = _cannon) -> void:
		# Toucher des ennemis : les tourelles (meme hostiles) transpercent et blessent les ennemis dans la ligne !
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and is_instance_valid(e) and e.has_method("take_damage"):
				if _cannon_hit_set.has(e):
					continue
				var p: Vector2 = (e as Node2D).global_position
				if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= CANNON_HALF_W + 32.0:
					_cannon_hit_set[e] = true
					var edmg: float = _solar_dmg * 2.5 if _solar_mirror else (_welder_dmg * 2.0 if _welder else (_shoot_dmg * 6.0 if _hacked else _shoot_dmg * 3.5))
					e.take_damage(edmg)
					if game != null and game.has_method("impact_fx"):
						var col: Color = Color(1.0, 0.85, 0.3) if _solar_mirror else (Color(0.3, 0.9, 1.0) if (_hacked or _welder) else Color(1.0, 0.45, 0.15))
						game.impact_fx(p, col, "laser", shot_dir, 1.6)

		# Toucher du joueur : seulement si non pirate
		if not _hacked and _plr != null and is_instance_valid(_plr) and _plr.has_method("take_damage"):
			if not _cannon_hit_set.has(_plr):
				var pp: Vector2 = _plr.global_position
				if Geometry2D.get_closest_point_to_segment(pp, a, b).distance_to(pp) <= CANNON_HALF_W + 24.0:
					_cannon_hit_set[_plr] = true
					var pdmg: float = _solar_dmg if _solar_mirror else (_welder_dmg * 0.7 if _welder else _shoot_dmg * 1.5)
					_plr.take_damage(pdmg, global_position)
					Events.screen_shake.emit(6.0)
					if game != null and game.has_method("impact_fx"):
						var col: Color = Color(1.0, 0.85, 0.3) if _solar_mirror else (Color(0.3, 0.9, 1.0) if _welder else Color(1.0, 0.4, 0.1))
						game.impact_fx(pp, col, "laser", shot_dir, 1.8)

	## Fuel barrel detonation: hurts EVERYTHING in BOOM_R, the player included — the 4s fuse is
	## the fair warning. Leading the horde over a barrel is the reward.
	func _explode() -> void:
		set_process(false)
		var pos: Vector2 = global_position
		_mark_gone(pos)
		GameState.props_destroyed += 1   # barrels count for the daily quest too (they did not before)
		if game != null and is_instance_valid(game):
			if game.has_method("death_fx"):
				game.death_fx(pos, 2, true)      # the big lightning burst is EARNED here (rare event)
			if game.has_method("impact_fx"):
				game.impact_fx(pos, Color(1.0, 0.6, 0.25), kind, Vector2.ZERO, 2.4)
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node2D and is_instance_valid(e) and "alive" in e and e.alive:
					if pos.distance_to((e as Node2D).global_position) <= BOOM_R and e.has_method("take_damage"):
						e.take_damage(BOOM_DMG)
			if _plr != null and is_instance_valid(_plr) and pos.distance_to(_plr.global_position) <= BOOM_R:
				if _plr.has_method("take_damage"):
					_plr.take_damage(BOOM_DMG * 0.35)   # you were warned; painful, not lethal on its own
			_drop_loot(pos)
			if "cover_list" in game:
				game.cover_list.erase(self)
		call_deferred("queue_free")

	## Roll what a smashed prop leaves behind. Gold-glow crates always pay a competence.
	func _drop_loot(pos: Vector2) -> void:
		if game == null or not is_instance_valid(game):
			return
		if _skill and game.has_method("spawn_skill"):
			game.spawn_skill(pos)
			return
		var total: int = 0
		for d in DROPS:
			total += int(d[1])
		var r: int = randi() % maxi(1, total)
		for d in DROPS:
			r -= int(d[1])
			if r < 0:
				match String(d[0]):
					"xp":    if game.has_method("spawn_xp"): game.spawn_xp(pos, 1 + randi() % 2)
					"scrap": if game.has_method("spawn_scrap"): game.spawn_scrap(pos, 2 + randi() % 3)
					"heal":  if game.has_method("spawn_heal"): game.spawn_heal(pos)
					"od":    if game.has_method("spawn_od"): game.spawn_od(pos)
					"emoji": if game.has_method("spawn_emoji"): game.spawn_emoji(pos)
				return

	## Tell the scatter this spot is spent. Uses `position` (chunk-local placement), which is what
	## _load_chunk keys on — global_position matches since the scatter sits at the origin.
	func _mark_gone(pos: Vector2) -> void:
		var s: Node = get_parent()
		if s != null and s.has_method("mark_destroyed"):
			s.mark_destroyed(pos)

	## The beam Line2D is top_level, so it does NOT follow the prop out of the tree — it would hang
	## in the world as an orphan bright line after the emitter is destroyed or streamed out.
	func _clear_beam() -> void:
		if _beam_line != null and is_instance_valid(_beam_line):
			_beam_line.visible = false
		for ln in [_cannon_beam_glow, _cannon_beam_line, _cannon_beam_core]:
			if ln != null and is_instance_valid(ln):
				ln.visible = false
		if _cannon_beam_flash != null and is_instance_valid(_cannon_beam_flash):
			_cannon_beam_flash.visible = false

	func _exit_tree() -> void:
		_clear_beam()
		# streaming unload (or a break) must pull us out of cover_list, else it grows with
		# freed nodes that every enemy re-scans each frame
		if game != null and is_instance_valid(game) and "cover_list" in game:
			game.cover_list.erase(self)
		# ARCHIVES : le prop peut disparaitre (destruction, dechargement de chunk) en tenant encore
		# une marque — sinon priority_boost resterait fige sur cet ennemi pour toujours.
		if _spot_marked != null and is_instance_valid(_spot_marked):
			_spot_marked.priority_boost = 0.0

	func take_damage(amount: float) -> void:
		if not bool(def.get("destruct", false)):
			return   # NATURE / carcass: indestructible (bullets already stopped by the collider)
		hp -= amount
		if _shoot_r > 0.0 and not _hacked and hp > 0.0 and hp <= _hp_start * HACK_THRESHOLD:
			_hacked = true
			hp = maxf(hp, 1.0)   # affaiblie, jamais a 0 par le coup qui declenche le piratage
			if _sprite != null:
				_sprite.modulate = Color(0.5, 1.4, 1.6)   # cyan — "allie", cf. la hierarchie de couleurs
			if game != null and game.has_method("show_hint"):
				game.show_hint("Tourelle piratée — son rayon automatique foudroie les ennemis !",
					Color(0.5, 1.0, 1.0), 4.5)
			return
		if hp <= 0.0:
			_clear_beam()
			if _boom:
				_explode()      # shooting a fuel barrel sets it off — no fuse, you chose this
				return
			if _regen_ice_wall:
				_regen_t = _regen_time
				if _sprite != null:
					_sprite.visible = false
				if _cycle_col != null:
					_cycle_col.set_deferred("disabled", true)
				return
			GameState.props_destroyed += 1   # daily-quest tracking (flushed at run end)
			if game != null and game.has_method("hint_prop_destroyed"):
				game.hint_prop_destroyed()   # explique le decor destructible, une fois, jamais revu
			_mark_gone(global_position)      # stays broken when this chunk streams back in
			if _pylon:
				_emp_burst()                 # breaking an arc pylon releases an EMP shockwave
			if _shatter:
				_shatter_burst()             # breaking a crystal sprays damaging shards
			if _capsule and game != null:
				# CAPSULE CRYOGENIQUE (Cryo-Voute) : reutilise le hook "epave" (reveil d'un
				# ennemi), mais declenche a la DESTRUCTION plutot qu'a la proximite -> le risque
				# du document (65% bonus via le loot normal ci-dessous / 35% ennemi en plus). Le
				# mystere AVANT ouverture est voulu (le document le demande) ; 04/10, WEAK signale
				# par le patron : les 2 issues etaient indiscernables APRES coup (meme shockwave
				# neutre). Les 2 branches ont maintenant un tell distinct et immediat.
				if randf() < 0.35 and game.has_method("awaken_enemy"):
					game.awaken_enemy(global_position, "brute")
					if game.has_method("impact_fx"):
						game.impact_fx(global_position, Color(1.0, 0.2, 0.2), "decor_hit", Vector2.ZERO, 2.2)
					if Events != null:
						Events.screen_shake.emit(2.5)
				elif game.has_method("impact_fx"):
					game.impact_fx(global_position, Color(1.0, 0.85, 0.3), "decor_hit", Vector2.ZERO, 1.6)
			if _pillar:
				# PILIER D'ENERGIE (Chambre de la Forge) : vague d'energie qui repousse les
				# ennemis proches - meme nudge que _on_dwell_filled ("terminal"), rayon plus large.
				var r2pil: float = 300.0 * 300.0
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D:
						var awayp: Vector2 = (e as Node2D).global_position - global_position
						var d2p: float = awayp.length_squared()
						if d2p <= r2pil and d2p > 1.0:
							(e as Node2D).global_position += awayp.normalized() * 80.0
				if game != null and game.has_method("impact_fx"):
					game.impact_fx(global_position, Color(1.0, 0.85, 0.3), kind, Vector2.ZERO, 3.2)
			if game != null:
				if _beacon:
					# silencing a beacon is a real objective -> a proper burst + a scrap payout so
					# the commitment (220 HP under fire) is worth it
					if game.has_method("death_fx"):
						game.death_fx(global_position, 1, true)
					if game.has_method("spawn_scrap"):
						game.spawn_scrap(global_position, 14 + randi() % 10)
				elif game.has_method("death_fx"):
					game.death_fx(global_position, 0, false)   # no lightning on a plain crate
				_drop_loot(global_position)
				if "cover_list" in game:
					game.cover_list.erase(self)
			call_deferred("queue_free")
		else:
			var tw: Tween = create_tween()
			tw.tween_property(_sprite, "modulate", Color(2.2, 2.2, 2.4), 0.05)
			tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
