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
	var solids: Array[String] = []
	var booms: Array[String] = []
	var hazards: Array[String] = []
	var loots: Array[String] = []
	var others: Array[String] = []

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

## Génère les positions et types de props pour un chunk donné
static func generate_layout(c: Vector2i, kinds: Array, rng: RandomNumberGenerator, ppos: Vector2, clear_r: float) -> Array:
	var origin: Vector2 = Vector2(float(c.x) * CHUNK_SIZE, float(c.y) * CHUNK_SIZE)
	var cat: Dictionary = categorize_props(kinds)
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
