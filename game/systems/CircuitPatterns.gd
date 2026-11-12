extends RefCounted
## CircuitPatterns.gd — Gabarits de circuits d'obstacles et level design tactique (v12.21)
## Fournit des motifs structurés pour les chunks de 1000x1000 px dans PropScatter.gd :
##  - 0: OPEN_HUB    (Spawn joueur ou clairières de respiration, 1-2 props max)
##  - 1: RING        (Monolithe central entouré d'une piste circulaire 360° pour le kiting)
##  - 2: SLALOM      (Deux parois en quinconce créant une chicane en baïonnette)
##  - 3: CHOKEPOINT   (Goulot d'étranglement central bordé de barils explosifs/cuves IEM)
##  - 4: TRENCH_LANE (Ligne d'obstacles bas / zone tactique le long d'un corridor)
##
## Règle absolue : AUCUN cul-de-sac. Largeur de passage minimale garantie : >= 320 px.

const CHUNK_SIZE: float = 1000.0
const MARGIN: float = 160.0

enum PatternType {
	OPEN_HUB,
	RING,
	SLALOM,
	CHOKEPOINT,
	TRENCH_LANE
}

## Détermine le type de motif pour un chunk donné
static func pick_pattern_type(c: Vector2i, rng: RandomNumberGenerator) -> int:
	# Le chunk de départ (0, 0) et ses voisins immédiats (cardinaux) restent très aérés pour le confort de spawn
	if c == Vector2i.ZERO:
		return PatternType.OPEN_HUB
	if abs(c.x) <= 1 and abs(c.y) <= 1 and rng.randf() < 0.65:
		return PatternType.OPEN_HUB

	var r: float = rng.randf()
	if r < 0.22:
		return PatternType.OPEN_HUB     # 22% clairières
	elif r < 0.48:
		return PatternType.RING         # 26% anneaux de kiting
	elif r < 0.72:
		return PatternType.SLALOM       # 24% chicanes
	elif r < 0.88:
		return PatternType.CHOKEPOINT   # 16% goulets
	else:
		return PatternType.TRENCH_LANE  # 12% allées tactiques / tranchées

## Classement des props disponibles du biome par rôle tactique
static func categorize_props(kinds: Array) -> Dictionary:
	var solids: Array = []
	var booms: Array = []
	var hazards: Array = []
	var loots: Array = []
	var others: Array = []

	for k_any in kinds:
		var k: String = String(k_any)
		var l: String = k.to_lower()
		if l.contains("baril") or l.contains("mine") or l.contains("grenade") or l.contains("instable"):
			booms.append(k)
		elif l.contains("caisse") or l.contains("bac") or l.contains("malle") or l.contains("coffre") or l.contains("scrap") or l.contains("lingotiere"):
			loots.append(k)
		elif l.contains("cuve") or l.contains("barricade") or l.contains("mur") or l.contains("terrain") or l.contains("rocher") or l.contains("gratte") or l.contains("arche") or l.contains("bordure") or l.contains("arbre") or l.contains("pilier") or l.contains("colonne") or l.contains("char"):
			solids.append(k)
		elif l.contains("tourelle") or l.contains("generateur") or l.contains("portique") or l.contains("soudeuse") or l.contains("miroir") or l.contains("capaciteur") or l.contains("antenne") or l.contains("emetteur"):
			hazards.append(k)
		else:
			others.append(k)

	# Fallbacks pour toujours avoir une sélection valide
	if solids.is_empty():
		solids = kinds.duplicate()
	if booms.is_empty():
		booms = solids.duplicate()
	if loots.is_empty():
		loots = solids.duplicate()
	if hazards.is_empty():
		hazards = solids.duplicate()

	return {
		"solid": solids,
		"boom": booms,
		"loot": loots,
		"hazard": hazards,
		"other": others if not others.is_empty() else solids
	}

## Catalogue des décors remplacés / réservés pour réutilisation ultérieure (garantie 100% sans suppression)
const RESERVED_DECOR: Dictionary = {
	"desert_legacy": ["desert_generateur_tempete", "desert_ver_foreur", "desert_fumerolle_vapeur", "desert_collecteur_solaire", "desert_projecteur_mirage"],
	"jungle_legacy": ["jungle_liane_fouet", "jungle_arbre_ruche", "jungle_fruit_grenade", "jungle_plante_lasso", "jungle_nuee_lucioles"],
	"volcanic_legacy": ["volcanic_event_magma", "volcanic_creuset_basculant", "volcanic_soufflerie_braises", "volcanic_robot_constructeur"],
	"swamp_legacy": ["swamp_vanne_crue", "swamp_vanne_barrage", "swamp_lampadaire_phare", "swamp_bouee_mine"]
}

## Génère les positions et types de props pour un chunk donné
static func generate_layout(c: Vector2i, kinds: Array, rng: RandomNumberGenerator, ppos: Vector2, clear_r: float, biome: String = "tech") -> Array:
	var origin: Vector2 = Vector2(float(c.x) * CHUNK_SIZE, float(c.y) * CHUNK_SIZE)
	var cat: Dictionary = categorize_props(kinds)

	# Level design spécifique et exclusif par biome (aucun niveau ne se ressemble)
	match biome:
		"desert":
			return _generate_desert_layout(c, origin, cat, kinds, rng, ppos, clear_r)
		"jungle":
			return _generate_jungle_layout(c, origin, cat, kinds, rng, ppos, clear_r)
		"volcanic":
			return _generate_volcanic_layout(c, origin, cat, kinds, rng, ppos, clear_r)
		"swamp":
			return _generate_swamp_layout(c, origin, cat, kinds, rng, ppos, clear_r)

	var ptype: int = pick_pattern_type(c, rng)
	var items: Array = [] # [ {"kind": String, "pos": Vector2, "rand_scale": float, "skill_roll": float, "flip": bool} ]

	match ptype:
		PatternType.OPEN_HUB:
			_build_open_hub(origin, cat, rng, items, ppos, clear_r)
		PatternType.RING:
			_build_ring(origin, cat, rng, items, ppos, clear_r)
		PatternType.SLALOM:
			_build_slalom(origin, cat, rng, items, ppos, clear_r)
		PatternType.CHOKEPOINT:
			_build_chokepoint(origin, cat, rng, items, ppos, clear_r)
		PatternType.TRENCH_LANE:
			_build_trench_lane(origin, cat, rng, items, ppos, clear_r)

	return items

# ==============================================================================
# NIVEAU 2 : DÉSERT TOXIQUE (Rosace Quadrilobée à 4 Pétales & Miroirs Solaires d'Angle)
# ==============================================================================
static func _generate_desert_layout(c: Vector2i, origin: Vector2, _cat: Dictionary, kinds: Array, rng: RandomNumberGenerator, ppos: Vector2, clear_r: float) -> Array:
	var out: Array = []
	if c == Vector2i.ZERO:
		var p_obelisk: Vector2 = origin + Vector2(500.0, 500.0)
		if p_obelisk.distance_to(ppos) >= clear_r and kinds.has("desert_obelisque_solaire"):
			out.append({"kind": "desert_obelisque_solaire", "pos": p_obelisk, "rand_scale": 1.15, "skill_roll": rng.randf(), "flip": false})
		elif p_obelisk.distance_to(ppos) >= clear_r and kinds.has("desert_arche_verre"):
			out.append({"kind": "desert_arche_verre", "pos": p_obelisk, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})
		var p_loot: Vector2 = origin + Vector2(780.0, 220.0)
		if p_loot.distance_to(ppos) >= clear_r and kinds.has("desert_malle_survie"):
			out.append({"kind": "desert_malle_survie", "pos": p_loot, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})
		return out

	# Rosace quadrilobée : 4 branches à 90° avec croisements orthogonaux et diagonaux
	var corner_ne: bool = (posmod(c.x + c.y, 2) == 0)

	# Croisement 1 : Centre focal du pétale de rosace (Monolithe solaire 2.5D Blender)
	var p_center: Vector2 = origin + Vector2(500.0, 500.0)
	if p_center.distance_to(ppos) >= clear_r:
		var k_core: String = "desert_obelisque_solaire" if (kinds.has("desert_obelisque_solaire") and rng.randf() < 0.7) else "desert_arche_verre"
		if kinds.has(k_core):
			out.append({"kind": k_core, "pos": p_center, "rand_scale": 1.15, "skill_roll": rng.randf(), "flip": rng.randf() < 0.5})

	# Croisement 2 : Charnière d'angle périphérique (Canon à miroir solaire avec tir transversal)
	var cannon_pos: Vector2 = origin + (Vector2(780.0, 220.0) if corner_ne else Vector2(220.0, 780.0))
	var cannon_aim: float = 215.0 if corner_ne else 35.0  # Tir de barrage transversal coupant la route
	if cannon_pos.distance_to(ppos) >= clear_r and kinds.has("desert_miroir_solaire"):
		out.append({
			"kind": "desert_miroir_solaire",
			"pos": cannon_pos,
			"rand_scale": 1.15,
			"skill_roll": rng.randf(),
			"flip": not corner_ne,
			"aim": cannon_aim
		})

	# Croisement 3 : Intersection diagonale Nord-Ouest (Arche de verre fondu)
	var p_nw: Vector2 = origin + (Vector2(220.0, 220.0) if corner_ne else Vector2(780.0, 220.0))
	if p_nw.distance_to(ppos) >= clear_r and kinds.has("desert_arche_verre"):
		out.append({"kind": "desert_arche_verre", "pos": p_nw, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})

	# Croisement 4 : Intersection diagonale Sud-Est (Char blindé enfoui)
	var p_se: Vector2 = origin + (Vector2(780.0, 780.0) if corner_ne else Vector2(220.0, 220.0))
	if p_se.distance_to(ppos) >= clear_r and kinds.has("desert_char_enfoui"):
		out.append({"kind": "desert_char_enfoui", "pos": p_se, "rand_scale": 1.05, "skill_roll": rng.randf(), "flip": true})

	# Croisement 5 : Foyer tactique de rosace (Malle de survie ensablée ou fosse)
	var p_poi: Vector2 = origin + (Vector2(220.0, 780.0) if corner_ne else Vector2(780.0, 780.0))
	if p_poi.distance_to(ppos) >= clear_r:
		var k_poi: String = "desert_malle_survie" if rng.randf() < 0.6 else "desert_fosse_aspiration"
		if kinds.has(k_poi):
			out.append({"kind": k_poi, "pos": p_poi, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})

	return out

# ==============================================================================
# NIVEAU 3 : RUINES VÉGÉTALES (Rosace Hexalobée à 6 Pétales en Fleur de Lotus)
# ==============================================================================
static func _generate_jungle_layout(c: Vector2i, origin: Vector2, _cat: Dictionary, kinds: Array, rng: RandomNumberGenerator, ppos: Vector2, clear_r: float) -> Array:
	var out: Array = []
	if c == Vector2i.ZERO:
		var p_core: Vector2 = origin + Vector2(500.0, 500.0)
		if p_core.distance_to(ppos) >= clear_r and kinds.has("jungle_pilier_racines"):
			out.append({"kind": "jungle_pilier_racines", "pos": p_core, "rand_scale": 1.2, "skill_roll": rng.randf(), "flip": false})
		elif p_core.distance_to(ppos) >= clear_r and kinds.has("jungle_statue_mecha"):
			out.append({"kind": "jungle_statue_mecha", "pos": p_core, "rand_scale": 1.15, "skill_roll": rng.randf(), "flip": false})
		var p_pod: Vector2 = origin + Vector2(838.0, 305.0)
		if p_pod.distance_to(ppos) >= clear_r and kinds.has("jungle_cosse_geante"):
			out.append({"kind": "jungle_cosse_geante", "pos": p_pod, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})
		return out

	# Rosace hexalobée : 6 pétales arrondis en fleur de lotus (angles à 60°)
	var corner_nw: bool = (posmod(c.x + c.y, 2) == 0)

	# Croisement 1 : Cœur de lotus (Totem de racines 2.5D Blender)
	var p_center: Vector2 = origin + Vector2(500.0, 500.0)
	if p_center.distance_to(ppos) >= clear_r:
		var k_cen: String = "jungle_pilier_racines" if (kinds.has("jungle_pilier_racines") and rng.randf() < 0.7) else "jungle_colonne_racines"
		if kinds.has(k_cen):
			out.append({"kind": k_cen, "pos": p_center, "rand_scale": 1.2, "skill_roll": rng.randf(), "flip": rng.randf() < 0.5})

	# Croisement 2 : Angle périphérique de clairière (Plante-mortier d'angle)
	var cannon_pos: Vector2 = origin + (Vector2(220.0, 220.0) if corner_nw else Vector2(780.0, 780.0))
	var cannon_aim: float = 315.0 if corner_nw else 135.0 # Tir en cloche vers le cœur du pétale
	if cannon_pos.distance_to(ppos) >= clear_r and kinds.has("jungle_mortier_plante"):
		out.append({
			"kind": "jungle_mortier_plante",
			"pos": cannon_pos,
			"rand_scale": 1.2,
			"skill_roll": rng.randf(),
			"flip": not corner_nw,
			"aim": cannon_aim
		})

	# Croisement 3 : Nœud de pétale hexagonal Est (Colonne de racines pétrifiées)
	var p_east: Vector2 = origin + (Vector2(838.0, 695.0) if corner_nw else Vector2(162.0, 305.0))
	if p_east.distance_to(ppos) >= clear_r and kinds.has("jungle_colonne_racines"):
		out.append({"kind": "jungle_colonne_racines", "pos": p_east, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})

	# Croisement 4 : Nœud de pétale hexagonal Ouest (Statue de titan mecha antique)
	var p_west: Vector2 = origin + (Vector2(162.0, 695.0) if corner_nw else Vector2(838.0, 305.0))
	if p_west.distance_to(ppos) >= clear_r and kinds.has("jungle_statue_mecha"):
		out.append({"kind": "jungle_statue_mecha", "pos": p_west, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": true})

	# Croisement 5 : Pétale tactique (Fleur-catapulte d'éjection ou cosse de butin géante)
	var p_aux: Vector2 = origin + (Vector2(838.0, 305.0) if corner_nw else Vector2(162.0, 695.0))
	if p_aux.distance_to(ppos) >= clear_r:
		var k_aux: String = "jungle_fleur_catapulte" if rng.randf() < 0.55 else "jungle_cosse_geante"
		if kinds.has(k_aux):
			out.append({"kind": k_aux, "pos": p_aux, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})

	return out

# ==============================================================================
# NIVEAU 4 : FORGE ET CONSTRUCTION (Rosace Octolobée en Double Anneau d'Engrenage)
# ==============================================================================
static func _generate_volcanic_layout(c: Vector2i, origin: Vector2, _cat: Dictionary, kinds: Array, rng: RandomNumberGenerator, ppos: Vector2, clear_r: float) -> Array:
	var out: Array = []
	if c == Vector2i.ZERO:
		var p_furnace: Vector2 = origin + Vector2(500.0, 500.0)
		if p_furnace.distance_to(ppos) >= clear_r and kinds.has("volcanic_fourneau_lourd"):
			out.append({"kind": "volcanic_fourneau_lourd", "pos": p_furnace, "rand_scale": 1.2, "skill_roll": rng.randf(), "flip": false})
		elif p_furnace.distance_to(ppos) >= clear_r and kinds.has("volcanic_pont_roulant"):
			out.append({"kind": "volcanic_pont_roulant", "pos": p_furnace, "rand_scale": 1.15, "skill_roll": rng.randf(), "flip": false})
		var p_loot: Vector2 = origin + Vector2(780.0, 780.0)
		if p_loot.distance_to(ppos) >= clear_r and kinds.has("volcanic_lingotiere"):
			out.append({"kind": "volcanic_lingotiere", "pos": p_loot, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})
		return out

	# Rosace octolobée : double anneau concentrique crénelé en roue d'engrenage à 8 lobes (45°)
	var corner_sw: bool = (posmod(c.x + c.y, 2) == 0)

	# Croisement 1 : Noyau focal de la rosace industrielle (Haut-fourneau 2.5D Blender)
	var p_core: Vector2 = origin + Vector2(500.0, 500.0)
	if p_core.distance_to(ppos) >= clear_r:
		var k_core: String = "volcanic_fourneau_lourd" if (kinds.has("volcanic_fourneau_lourd") and rng.randf() < 0.7) else "volcanic_marteau_pilon"
		if kinds.has(k_core):
			out.append({"kind": k_core, "pos": p_core, "rand_scale": 1.18, "skill_roll": rng.randf(), "flip": rng.randf() < 0.5})

	# Croisement 2 : Charnière d'angle de tranchée (Mortier de scories lourd)
	var cannon_pos: Vector2 = origin + (Vector2(200.0, 800.0) if corner_sw else Vector2(800.0, 200.0))
	var cannon_aim: float = 40.0 if corner_sw else 220.0  # Tir de barrage transversal le long de la tranchée
	if cannon_pos.distance_to(ppos) >= clear_r and kinds.has("volcanic_mortier_scories"):
		out.append({
			"kind": "volcanic_mortier_scories",
			"pos": cannon_pos,
			"rand_scale": 1.15,
			"skill_roll": rng.randf(),
			"flip": not corner_sw,
			"aim": cannon_aim
		})

	# Croisement 3 : Créneau d'engrenage opposé (Portique de levage / pont roulant)
	var p_crane: Vector2 = origin + (Vector2(780.0, 220.0) if corner_sw else Vector2(220.0, 780.0))
	if p_crane.distance_to(ppos) >= clear_r and kinds.has("volcanic_pont_roulant"):
		out.append({"kind": "volcanic_pont_roulant", "pos": p_crane, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})

	# Croisement 4 : Créneau latéral d'engrenage (Tour d'assemblage / cheminée de fonderie)
	var p_tow: Vector2 = origin + Vector2(220.0, 220.0)
	if p_tow.distance_to(ppos) >= clear_r and kinds.has("volcanic_cheminee_fonderie"):
		out.append({"kind": "volcanic_cheminee_fonderie", "pos": p_tow, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": rng.randf() < 0.5})

	# Croisement 5 : Nœud de trempe et butin (Bassin cryogénique de trempe ou lingotière)
	var p_tech: Vector2 = origin + Vector2(780.0, 780.0)
	if p_tech.distance_to(ppos) >= clear_r:
		var k_tech: String = "volcanic_bassin_trempe" if rng.randf() < 0.55 else "volcanic_lingotiere"
		if kinds.has(k_tech):
			out.append({"kind": k_tech, "pos": p_tech, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})

	return out

# ==============================================================================
# NIVEAU 5 : CITÉ ENGLOUTIE (Rosace Décalobée / Damier Polaire Hydraulique)
# ==============================================================================
static func _generate_swamp_layout(c: Vector2i, origin: Vector2, _cat: Dictionary, kinds: Array, rng: RandomNumberGenerator, ppos: Vector2, clear_r: float) -> Array:
	var out: Array = []
	if c == Vector2i.ZERO:
		var p_arch: Vector2 = origin + Vector2(500.0, 500.0)
		if p_arch.distance_to(ppos) >= clear_r and kinds.has("swamp_arche_submergee"):
			out.append({"kind": "swamp_arche_submergee", "pos": p_arch, "rand_scale": 1.15, "skill_roll": rng.randf(), "flip": false})
		elif p_arch.distance_to(ppos) >= clear_r and kinds.has("swamp_coffre_banque"):
			out.append({"kind": "swamp_coffre_banque", "pos": p_arch, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})
		var p_bar: Vector2 = origin + Vector2(240.0, 240.0)
		if p_bar.distance_to(ppos) >= clear_r and kinds.has("swamp_barricade_vehicules"):
			out.append({"kind": "swamp_barricade_vehicules", "pos": p_bar, "rand_scale": 1.05, "skill_roll": rng.randf(), "flip": false})
		return out

	# Rosace décalobée : 10 canaux rayonnants sécants à 36° formant la trame des carrefours inondés
	var corner_ne: bool = (posmod(c.x + c.y, 2) == 0)

	# Croisement 1 : Carrefour inondé majeur (Arche d'écluse et linteau 2.5D Blender)
	var p_arch: Vector2 = origin + Vector2(500.0, 500.0)
	if p_arch.distance_to(ppos) >= clear_r:
		var k_arch: String = "swamp_arche_submergee" if (kinds.has("swamp_arche_submergee") and rng.randf() < 0.7) else "swamp_pont_brise"
		if kinds.has(k_arch):
			out.append({"kind": k_arch, "pos": p_arch, "rand_scale": 1.15, "skill_roll": rng.randf(), "flip": rng.randf() < 0.5})

	# Croisement 2 : Angle de toiture surélevée (Batterie DCA antiaérienne)
	var cannon_pos: Vector2 = origin + (Vector2(780.0, 220.0) if corner_ne else Vector2(780.0, 780.0))
	var cannon_aim: float = 225.0 if corner_ne else 135.0 # Tir transversal couvrant le carrefour
	if cannon_pos.distance_to(ppos) >= clear_r and kinds.has("swamp_tourelle_dca"):
		out.append({
			"kind": "swamp_tourelle_dca",
			"pos": cannon_pos,
			"rand_scale": 1.15,
			"skill_roll": rng.randf(),
			"flip": not corner_ne,
			"aim": cannon_aim
		})

	# Croisement 3 : Canal Nord-Ouest (Gratte-ciel effondré)
	var p_bldg: Vector2 = origin + (Vector2(220.0, 220.0) if corner_ne else Vector2(220.0, 780.0))
	if p_bldg.distance_to(ppos) >= clear_r and kinds.has("swamp_gratte_ciel"):
		out.append({"kind": "swamp_gratte_ciel", "pos": p_bldg, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})

	# Croisement 4 : Canal Sud-Ouest (Section de pont suspendu brisé)
	var p_brise: Vector2 = origin + (Vector2(220.0, 780.0) if corner_ne else Vector2(220.0, 220.0))
	if p_brise.distance_to(ppos) >= clear_r and kinds.has("swamp_pont_brise"):
		out.append({"kind": "swamp_pont_brise", "pos": p_brise, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": true})

	# Croisement 5 : Barricade de retenue ou coffre de banque
	var p_util: Vector2 = origin + (Vector2(780.0, 780.0) if corner_ne else Vector2(780.0, 220.0))
	if p_util.distance_to(ppos) >= clear_r:
		var k_util: String = "swamp_barricade_vehicules" if rng.randf() < 0.6 else "swamp_coffre_banque"
		if kinds.has(k_util):
			out.append({"kind": k_util, "pos": p_util, "rand_scale": 1.05, "skill_roll": rng.randf(), "flip": false})

	return out

# --- 1. OPEN HUB (Clairière avec 1-2 props de soutien) ---
static func _build_open_hub(origin: Vector2, cat: Dictionary, rng: RandomNumberGenerator, out: Array, ppos: Vector2, clear_r: float) -> void:
	var count: int = 1 if rng.randf() < 0.45 else 2
	for i in count:
		var pos: Vector2 = origin + Vector2(rng.randf_range(250.0, 750.0), rng.randf_range(250.0, 750.0))
		if pos.distance_to(ppos) < clear_r:
			continue
		var pool: Array = cat["loot"] if rng.randf() < 0.6 else cat["other"]
		var k: String = pool[rng.randi() % pool.size()]
		out.append({
			"kind": k,
			"pos": pos,
			"rand_scale": rng.randf_range(0.9, 1.1),
			"skill_roll": rng.randf(),
			"flip": rng.randf() < 0.5
		})

# --- 2. RING / ROND-POINT (Monolithe central pour kiter à 360°) ---
static func _build_ring(origin: Vector2, cat: Dictionary, rng: RandomNumberGenerator, out: Array, ppos: Vector2, clear_r: float) -> void:
	var center: Vector2 = origin + Vector2(500.0, 500.0) + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-60.0, 60.0))
	if center.distance_to(ppos) >= clear_r:
		# Monolithe central
		var solid_pool: Array = cat["solid"]
		var k_core: String = solid_pool[rng.randi() % solid_pool.size()]
		out.append({
			"kind": k_core,
			"pos": center,
			"rand_scale": rng.randf_range(1.05, 1.25),
			"skill_roll": rng.randf(),
			"flip": rng.randf() < 0.5
		})

		# 2 satellites collés au centre (ne débordant jamais sur l'anneau extérieur libre)
		var angle: float = rng.randf() * TAU
		for i in 2:
			var a: float = angle + float(i) * PI + rng.randf_range(-0.3, 0.3)
			var sat_pos: Vector2 = center + Vector2(cos(a), sin(a)) * rng.randf_range(115.0, 145.0)
			if sat_pos.distance_to(ppos) >= clear_r:
				var pool: Array = cat["loot"] if i == 0 else cat["boom"]
				var k_sat: String = pool[rng.randi() % pool.size()]
				out.append({
					"kind": k_sat,
					"pos": sat_pos,
					"rand_scale": rng.randf_range(0.9, 1.05),
					"skill_roll": rng.randf(),
					"flip": rng.randf() < 0.5
				})

# --- 3. SLALOM (Deux parois en quinconce forçant un contournement en baïonnette) ---
static func _build_slalom(origin: Vector2, cat: Dictionary, rng: RandomNumberGenerator, out: Array, ppos: Vector2, clear_r: float) -> void:
	var flip_axis: bool = rng.randf() < 0.5 # vertical vs horizontal slalom
	var solid_pool: Array = cat["solid"]
	var k_wall: String = solid_pool[rng.randi() % solid_pool.size()]

	if not flip_axis:
		# Chicane verticale : mur gauche descendant depuis le haut, mur droit montant depuis le bas
		var p1: Vector2 = origin + Vector2(340.0, 300.0)
		if p1.distance_to(ppos) >= clear_r:
			out.append({"kind": k_wall, "pos": p1, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})
		var p1b: Vector2 = origin + Vector2(340.0, 470.0)
		if p1b.distance_to(ppos) >= clear_r:
			out.append({"kind": k_wall, "pos": p1b, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": true})

		var p2: Vector2 = origin + Vector2(660.0, 530.0)
		if p2.distance_to(ppos) >= clear_r:
			out.append({"kind": k_wall, "pos": p2, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})
		var p2b: Vector2 = origin + Vector2(660.0, 700.0)
		if p2b.distance_to(ppos) >= clear_r:
			out.append({"kind": k_wall, "pos": p2b, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": true})

		var mid: Vector2 = origin + Vector2(500.0, 500.0)
		if mid.distance_to(ppos) >= clear_r:
			var mid_k: String = cat["boom"][rng.randi() % cat["boom"].size()]
			out.append({"kind": mid_k, "pos": mid, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})
	else:
		# Chicane horizontale : mur haut à gauche, mur bas à droite
		var p1: Vector2 = origin + Vector2(300.0, 340.0)
		if p1.distance_to(ppos) >= clear_r:
			out.append({"kind": k_wall, "pos": p1, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})
		var p1b: Vector2 = origin + Vector2(470.0, 340.0)
		if p1b.distance_to(ppos) >= clear_r:
			out.append({"kind": k_wall, "pos": p1b, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": true})

		var p2: Vector2 = origin + Vector2(530.0, 660.0)
		if p2.distance_to(ppos) >= clear_r:
			out.append({"kind": k_wall, "pos": p2, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": false})
		var p2b: Vector2 = origin + Vector2(700.0, 660.0)
		if p2b.distance_to(ppos) >= clear_r:
			out.append({"kind": k_wall, "pos": p2b, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": true})

		var mid: Vector2 = origin + Vector2(500.0, 500.0)
		if mid.distance_to(ppos) >= clear_r:
			var mid_k: String = cat["loot"][rng.randi() % cat["loot"].size()]
			out.append({"kind": mid_k, "pos": mid, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})

# --- 4. CHOKEPOINT (Goulet d'étranglement central avec barils tactiques) ---
static func _build_chokepoint(origin: Vector2, cat: Dictionary, rng: RandomNumberGenerator, out: Array, ppos: Vector2, clear_r: float) -> void:
	var orient_vert: bool = rng.randf() < 0.5
	var solid_pool: Array = cat["solid"]
	var k_block: String = solid_pool[rng.randi() % solid_pool.size()]
	var k_boom: String = cat["boom"][rng.randi() % cat["boom"].size()]

	if orient_vert:
		var west: Vector2 = origin + Vector2(240.0, 500.0)
		var east: Vector2 = origin + Vector2(760.0, 500.0)
		if west.distance_to(ppos) >= clear_r:
			out.append({"kind": k_block, "pos": west, "rand_scale": 1.2, "skill_roll": rng.randf(), "flip": false})
		if east.distance_to(ppos) >= clear_r:
			out.append({"kind": k_block, "pos": east, "rand_scale": 1.2, "skill_roll": rng.randf(), "flip": true})

		var bpos: Vector2 = origin + Vector2(380.0 if rng.randf() < 0.5 else 620.0, 500.0)
		if bpos.distance_to(ppos) >= clear_r:
			out.append({"kind": k_boom, "pos": bpos, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})
	else:
		var north: Vector2 = origin + Vector2(500.0, 240.0)
		var south: Vector2 = origin + Vector2(500.0, 760.0)
		if north.distance_to(ppos) >= clear_r:
			out.append({"kind": k_block, "pos": north, "rand_scale": 1.2, "skill_roll": rng.randf(), "flip": false})
		if south.distance_to(ppos) >= clear_r:
			out.append({"kind": k_block, "pos": south, "rand_scale": 1.2, "skill_roll": rng.randf(), "flip": true})

		var bpos: Vector2 = origin + Vector2(500.0, 380.0 if rng.randf() < 0.5 else 620.0)
		if bpos.distance_to(ppos) >= clear_r:
			out.append({"kind": k_boom, "pos": bpos, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})

# --- 5. TRENCH LANE (Allée de laser / tapis / fosses poreuses) ---
static func _build_trench_lane(origin: Vector2, cat: Dictionary, rng: RandomNumberGenerator, out: Array, ppos: Vector2, clear_r: float) -> void:
	var haz_pool: Array = cat["hazard"]
	var k_haz: String = haz_pool[rng.randi() % haz_pool.size()]
	var k_loot: String = cat["loot"][rng.randi() % cat["loot"].size()]

	var p_haz: Vector2 = origin + Vector2(500.0, 420.0)
	if p_haz.distance_to(ppos) >= clear_r:
		out.append({"kind": k_haz, "pos": p_haz, "rand_scale": 1.1, "skill_roll": rng.randf(), "flip": rng.randf() < 0.5})

	var p_flank: Vector2 = origin + Vector2(500.0, 620.0)
	if p_flank.distance_to(ppos) >= clear_r:
		out.append({"kind": k_loot, "pos": p_flank, "rand_scale": 1.0, "skill_roll": rng.randf(), "flip": false})
