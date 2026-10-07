extends Node
## Verifie la PROGRESSION PAR MAP ajoutee le 03/10 : au sein d'un biome "15 maps", le tirage de
## decor doit deriver de la 1ere map source vers la derniere avec le temps de run, au lieu de tout
## melanger des la minute 0 (correctif demande par le patron, cf. PropScatter._pick_kind).
##   godot --headless --path game res://_test_decor_map_phase.tscn

## Game.gd n'a pas de class_name -> acces a MAP_PHASE_NAMES via le script preload.
const GameScript = preload("res://scenes/Game.gd")

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

## Tire N fois et compte combien de fois un kind de `segment` sort, pour un `run_time` donne.
func _count_segment(ps: PropScatter, kinds: Array, segment: Array, run_time: float, n: int) -> int:
	GameState.run_time = run_time
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var seg_set: Dictionary = {}
	for k in segment:
		seg_set[k] = true
	var hits: int = 0
	for i in n:
		if seg_set.has(ps._pick_kind(kinds, rng)):
			hits += 1
	return hits

func _ready() -> void:
	print("=== TEST PROGRESSION PAR MAP (biomes '15 maps') ===")
	GameState.reset()
	var N: int = 4000

	var ps: PropScatter = PropScatter.new()
	add_child(ps)

	# --- Zone Cryo : Map 4 (debut) vs Map 6 (fin) ---
	ps.biome = "cryo"
	var kinds_cryo: Array = PropScatter.BIOME_DECOR["cryo"]
	var map4: Array = PropScatter.BIOME_MAP_SEGMENTS["cryo"][0]
	var map6: Array = PropScatter.BIOME_MAP_SEGMENTS["cryo"][2]

	var map4_at_0: int = _count_segment(ps, kinds_cryo, map4, 0.0, N)
	var map6_at_0: int = _count_segment(ps, kinds_cryo, map6, 0.0, N)
	_ok(map4_at_0 > map6_at_0 * 3, "cryo t=0min : Map4 domine largement Map6",
		"map4=%d map6=%d (sur %d)" % [map4_at_0, map6_at_0, N])
	_ok(map6_at_0 > 0, "cryo t=0min : Map6 reste possible (plancher, pas coupee a zero)",
		"map6=%d" % map6_at_0)

	var map4_at_10: int = _count_segment(ps, kinds_cryo, map4, 600.0, N)
	var map6_at_10: int = _count_segment(ps, kinds_cryo, map6, 600.0, N)
	_ok(map6_at_10 > map4_at_10 * 3, "cryo t=10min : Map6 domine largement Map4",
		"map4=%d map6=%d (sur %d)" % [map4_at_10, map6_at_10, N])
	_ok(map4_at_10 > 0, "cryo t=10min : Map4 reste possible (plancher)",
		"map4=%d" % map4_at_10)

	var map5: Array = PropScatter.BIOME_MAP_SEGMENTS["cryo"][1]
	var map5_at_5: int = _count_segment(ps, kinds_cryo, map5, 300.0, N)
	_ok(map5_at_5 > map4_at_0, "cryo t=5min : Map5 (milieu) domine a son propre pic",
		"map5@5min=%d vs map4@0min=%d" % [map5_at_5, map4_at_0])

	# --- Noyau Instable : meme principe, biome a 3 segments inegaux (2/3/3) ---
	ps.biome = "reacteur"
	var kinds_r: Array = PropScatter.BIOME_DECOR["reacteur"]
	var map7: Array = PropScatter.BIOME_MAP_SEGMENTS["reacteur"][0]
	var map9: Array = PropScatter.BIOME_MAP_SEGMENTS["reacteur"][2]
	var r_map7_0: int = _count_segment(ps, kinds_r, map7, 0.0, N)
	var r_map9_0: int = _count_segment(ps, kinds_r, map9, 0.0, N)
	_ok(r_map7_0 > r_map9_0 * 3, "reacteur t=0min : Map7 domine largement Map9",
		"map7=%d map9=%d" % [r_map7_0, r_map9_0])
	var r_map7_10: int = _count_segment(ps, kinds_r, map7, 600.0, N)
	var r_map9_10: int = _count_segment(ps, kinds_r, map9, 600.0, N)
	_ok(r_map9_10 > r_map7_10 * 3, "reacteur t=10min : Map9 domine largement Map7",
		"map7=%d map9=%d" % [r_map7_10, r_map9_10])

	# --- Base generique (tourelle/capaciteur/...) : toujours tiree, peu importe la phase ---
	var base_0: int = _count_segment(ps, kinds_r, ["tourelle", "capaciteur", "generateur", "baril", "epave", "caisses"], 0.0, N)
	var base_10: int = _count_segment(ps, kinds_r, ["tourelle", "capaciteur", "generateur", "baril", "epave", "caisses"], 600.0, N)
	_ok(base_0 > 0 and base_10 > 0, "reacteur : la base generique reste tiree a toute phase",
		"base@0=%d base@10min=%d" % [base_0, base_10])

	# --- Biome LEGACY (hors plan 15 maps) : tirage inchange, pas de phase ---
	ps.biome = "earth"
	var kinds_earth: Array = PropScatter.BIOME_DECOR["earth"]
	GameState.run_time = 0.0
	var rng_e: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_e.seed = 1
	var all_valid: bool = true
	for i in 200:
		if not kinds_earth.has(ps._pick_kind(kinds_earth, rng_e)):
			all_valid = false
	_ok(all_valid, "earth (biome legacy, hors BIOME_MAP_SEGMENTS) : tirage toujours valide, inchange")

	# --- 04/10, trou signale par le patron : 10 decors "tech" herites n'etaient dans AUCUN segment
	# -> maintenant rattaches aux 3 maps, ne reste que la vraie base neutre (5 items) orpheline ---
	var tech_segs: Array = PropScatter.BIOME_MAP_SEGMENTS["tech"]
	var tech_all_segmented: Array = []
	for seg in tech_segs:
		tech_all_segmented.append_array(seg)
	var tech_orphelins_attendus: Array = ["conduit", "antenne", "emetteur", "cristaux", "container", "aimant", "terminal", "archives", "quai", "convoyeur"]
	var tech_bien_rattaches: bool = true
	for k in tech_orphelins_attendus:
		if not tech_all_segmented.has(k):
			tech_bien_rattaches = false
	_ok(tech_bien_rattaches, "tech : les 10 decors herites sont bien rattaches a une map (plus d'orphelins)")
	var tech_base_restante: Array = ["generateur", "capaciteur", "tourelle", "baril", "caisses"]
	var tech_base_hors_segments: bool = true
	for k in tech_base_restante:
		if tech_all_segmented.has(k):
			tech_base_hors_segments = false
	_ok(tech_base_hors_segments, "tech : la base neutre restante (5 items) n'est dans aucun segment, comme les autres biomes")

	# --- current_map_phase() : meme seuil que _pick_kind, utilise par la banniere (Game.gd) ---
	ps.biome = "cryo"
	GameState.run_time = 0.0
	_ok(ps.current_map_phase() == 0, "current_map_phase() : phase 0 au debut du run")
	GameState.run_time = 300.0
	_ok(ps.current_map_phase() == 1, "current_map_phase() : phase 1 a 5 minutes")
	GameState.run_time = 600.0
	_ok(ps.current_map_phase() == 2, "current_map_phase() : phase 2 a 10 minutes")
	GameState.run_time = 9999.0
	_ok(ps.current_map_phase() == 2, "current_map_phase() : reste a la phase 2 au-dela (jamais hors limites)")

	# --- MAP_PHASE_NAMES (Game.gd) : un triplet par biome "15 maps", aligne avec BIOME_MAP_SEGMENTS ---
	for b in ["tech", "cryo", "reacteur", "ruche", "citadelle"]:
		_ok(GameScript.MAP_PHASE_NAMES.has(b) and GameScript.MAP_PHASE_NAMES[b].size() == 3,
			"MAP_PHASE_NAMES['%s'] a bien 3 noms" % b)

	# --- 04/10, pop-in/out signale par le patron (mode defilement infini) : la frontiere de
	# dechargement (LOAD_R*CHUNK) doit rester largement hors du champ visible le plus large
	# realiste (petit ecran, zoom au plancher 0.4 -> jusqu'a ~2.5x la largeur de viewport visible).
	_ok(PropScatter.LOAD_R >= 2, "LOAD_R assez genereux pour que le decor se charge/decharge hors champ",
		"LOAD_R=%d (frontiere a %.0f-%.0fu du joueur)" % [PropScatter.LOAD_R, float(PropScatter.LOAD_R) * PropScatter.CHUNK, (float(PropScatter.LOAD_R) + 1.0) * PropScatter.CHUNK])

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
