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
	var map4_at_5: int = _count_segment(ps, kinds_cryo, map4, 300.0, N)
	var map6_at_5: int = _count_segment(ps, kinds_cryo, map6, 300.0, N)
	# (14/10 : plus de base generique -> tous les tirages sont thematiques ; on compare les 3 maps
	# entre elles a leur propre phase, plus a une autre phase)
	_ok(map5_at_5 > map4_at_5 and map5_at_5 > map6_at_5, "cryo t=5min : Map5 (milieu) domine a son propre pic",
		"map4=%d map5=%d map6=%d" % [map4_at_5, map5_at_5, map6_at_5])

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

	# --- 14/10 : AUCUN decor partage entre niveaux (patron) : ni base generique ni doublon ---
	var generiques: Array = ["tourelle", "capaciteur", "generateur", "baril", "epave", "caisses", "antenne", "emetteur", "conduit", "container"]
	var base_r: int = _count_segment(ps, kinds_r, generiques, 600.0, N)
	_ok(base_r == 0, "reacteur : aucun decor generique (tourelle, caisses...) : tout est propre au niveau", "base=%d" % base_r)
	var vus: Dictionary = {}
	var doublons: Array = []
	for b in PropScatter.BIOME_DECOR:
		for k in PropScatter.BIOME_DECOR[b]:
			if vus.has(k) and vus[k] != b:
				doublons.append("%s (%s + %s)" % [k, vus[k], b])
			vus[k] = b
	_ok(doublons.is_empty(), "chaque decor n'apparait que dans UN seul biome", str(doublons))
	var vus_b: Dictionary = {}
	var doublons_b: Array = []
	for b in PropScatter.BIOME_BORDER:
		for k in PropScatter.BIOME_BORDER[b]:
			if vus_b.has(k) and vus_b[k] != b:
				doublons_b.append("%s (%s + %s)" % [k, vus_b[k], b])
			vus_b[k] = b
	_ok(doublons_b.is_empty(), "chaque piece de mur d'arene n'apparait que dans UN seul biome", str(doublons_b))

	# --- Biome LEGACY (hors plan 15 maps) : tirage inchange, pas de phase ---
	ps.biome = "ice"
	var kinds_earth: Array = PropScatter.BIOME_DECOR["ice"]
	GameState.run_time = 0.0
	var rng_e: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_e.seed = 1
	var all_valid: bool = true
	for i in 200:
		if not kinds_earth.has(ps._pick_kind(kinds_earth, rng_e)):
			all_valid = false
	_ok(all_valid, "ice (biome legacy, hors BIOME_MAP_SEGMENTS) : tirage toujours valide, inchange")

	# --- 04/10, trou signale par le patron : 10 decors "tech" herites n'etaient dans AUCUN segment
	# -> maintenant rattaches aux 3 maps, ne reste que la vraie base neutre (5 items) orpheline ---
	var tech_segs: Array = PropScatter.BIOME_MAP_SEGMENTS["tech"]
	var tech_all_segmented: Array = []
	for seg in tech_segs:
		tech_all_segmented.append_array(seg)
	var tech_orphelins_attendus: Array = ["conduit", "antenne", "emetteur", "container", "aimant", "terminal", "archives", "quai", "convoyeur"]
	var tech_bien_rattaches: bool = true
	for k in tech_orphelins_attendus:
		if not tech_all_segmented.has(k):
			tech_bien_rattaches = false
	_ok(tech_bien_rattaches, "tech : les decors herites sont bien rattaches a une map (plus d'orphelins)")
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

	# --- MAP_PHASE_NAMES (Game.gd) : un triplet par biome, aligne avec BIOME_MAP_SEGMENTS ---
	for b in ["tech", "desert", "jungle", "volcanic", "swamp", "cryo", "reacteur", "ruche", "citadelle", "abyss", "ether", "titans", "orbit", "quantum", "ozone", "prism", "steampunk", "colosseum"]:
		_ok(GameScript.MAP_PHASE_NAMES.has(b) and GameScript.MAP_PHASE_NAMES[b].size() == 3,
			"MAP_PHASE_NAMES['%s'] a bien 3 noms" % b)

	# --- 04/10, pop-in/out signale par le patron (mode defilement infini) : la frontiere de
	# dechargement (LOAD_R*CHUNK) doit rester largement hors du champ visible le plus large
	# realiste (petit ecran, zoom au plancher 0.4 -> jusqu'a ~2.5x la largeur de viewport visible).
	_ok(PropScatter.LOAD_R >= 2, "LOAD_R assez genereux pour que le decor se charge/decharge hors champ",
		"LOAD_R=%d (frontiere a %.0f-%.0fu du joueur)" % [PropScatter.LOAD_R, float(PropScatter.LOAD_R) * PropScatter.CHUNK, (float(PropScatter.LOAD_R) + 1.0) * PropScatter.CHUNK])

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
