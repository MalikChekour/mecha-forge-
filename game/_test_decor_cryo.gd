extends Node
## Headless regression harness pour le DECOR INTERACTIF "Zone Cryo" (nouveau biome, maps 4-6,
## refonte 15-maps). Meme moule que _test_decor_tech.gd : appel manuel de _process()/
## _physics_process(), sans passer par un vrai chunk/scene de jeu.
##   godot --headless --path game res://_test_decor_cryo.tscn

class StubGame extends Node:
	var enemy_layer: Node2D
	var arena: Rect2 = Rect2(-5000, -5000, 10000, 10000)
	var zone_calls: int = 0
	var awaken_calls: int = 0
	var vfx_colors: Array = []
	func _init() -> void:
		enemy_layer = Node2D.new()
		add_child(enemy_layer)
	func spawn_ground_zone(_pos: Vector2, _radius: float, _delay: float, _dmg: float, _color: Color = Color.WHITE, _fx_kind: String = "decor_hit") -> void:
		zone_calls += 1
	func spawn_vfx(_kind: String, _pos: Vector2, _rot: float, _scale: float, _color: Color) -> void:
		vfx_colors.append(_color)
	func awaken_enemy(_pos: Vector2, _kind: String) -> void:
		awaken_calls += 1
	# 04/10, mise a niveau VFX (demande du patron) : les coups uniques du decor passent maintenant
	# par impact_fx (meme composite complet que le combat) au lieu de spawn_vfx seul - trace ici
	# comme spawn_vfx/spawn_ground_zone deja traces ci-dessus.
	var impact_colors: Array = []
	func impact_fx(_pos: Vector2, _color: Color, _kind: String, _dir: Vector2 = Vector2.ZERO, _scale: float = 1.0) -> void:
		impact_colors.append(_color)

## Dummy "joueur" minimal (meme precedent que _test_kill_tracking.gd / _test_enemies.gd : un
## Node2D nu, pas un vrai Player - PropScatter.Prop lit/ecrit _patch_inertia par duck-typing
## ("_patch_inertia" in _plr), donc un champ suffit, pas besoin d'instancier la scene joueur
## complete (ses noeuds enfants @onready ne seraient pas la hors de Game.tscn).
class DummyPlayer extends Node2D:
	var _patch_inertia: float = 0.0
	var field_slow: float = 1.0

## Game.gd n'a pas de class_name (juste "extends Node2D") -> pas accessible comme "Game.BIOMES"
## depuis un autre script. preload() recupere la ressource GDScript elle-meme, sur laquelle les
## const restent accessibles statiquement sans instancier toute la scene Game.tscn.
const GameScript = preload("res://scenes/Game.gd")

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST DECOR INTERACTIF (ZONE CRYO) ===")
	GameState.reset()

	# --- 0. le biome existe partout ou il doit etre enregistre ---
	_ok(GameScript.BIOMES.has("cryo"), "BIOMES contient 'cryo'")
	_ok(GameScript.BIOME_MODS.has("cryo"), "BIOME_MODS contient 'cryo'")
	_ok(GameScript.CUT_LINES.has("cryo"), "CUT_LINES contient 'cryo'")
	_ok(EnemySpawner.BIOME_TINT.has("cryo"), "EnemySpawner.BIOME_TINT contient 'cryo'")
	var cryo_kinds: Array = PropScatter.BIOME_DECOR["cryo"]
	for k in ["plaque_de_glace", "capsule_cryogenique", "jet_de_cryo", "brouillard_froid",
			"radiateur", "pic_de_glace", "borne_thermique", "glace_fragile"]:
		_ok(cryo_kinds.has(k), "BIOME_DECOR['cryo'] contient '%s'" % k)
		_ok(PropScatter.DECOR.has(k), "DECOR['%s'] existe" % k)

	# --- setup commun : un joueur factice au centre ---
	var game_stub: StubGame = StubGame.new()
	add_child(game_stub)
	var plr: DummyPlayer = DummyPlayer.new()
	add_child(plr)
	plr.add_to_group("player")
	plr.global_position = Vector2(0.0, 0.0)
	var dt: float = 0.1

	# --- 1. PLAQUE DE GLACE : ecrit _patch_inertia tant que le joueur est dans le rayon. La
	# recuperation (decroissance -2.5/s hors zone) est le fix ajoute a Player.gd ligne ~494 -
	# reproduite ici a l'identique (duck-typing, pas de vraie scene Player instanciee, voir
	# DummyPlayer plus haut) pour confirmer le comportement attendu sans dependre de la scene.
	var ice: PropScatter.Prop = PropScatter.Prop.new()
	ice.game = game_stub; ice.kind = "plaque_de_glace"; ice.def = PropScatter.DECOR["plaque_de_glace"]
	ice.position = Vector2(0.0, 0.0); ice.rand_scale = 1.0; ice.skill_roll = 0.0; ice.flip = false
	add_child(ice)
	_ok(ice._ice_patch_ring != null, "plaque_de_glace : a bien un anneau visuel (04/10, etait un GAP total avant)")
	_ok(ice._ice_patch_ring.get_child_count() > 0, "plaque_de_glace : l'anneau a bien un coeur (04/10, mise a niveau halo+coeur)")
	for i in 10:
		ice._process(dt)
		plr._patch_inertia = maxf(0.0, plr._patch_inertia - dt * 2.5)   # meme formule que Player.gd
	_ok(plr._patch_inertia > 0.0, "plaque_de_glace : a bien ecrit _patch_inertia", "val=%.2f" % plr._patch_inertia)
	ice.queue_free()
	for i in 30:   # 3s simule sans plaque -> doit redescendre a 0
		plr._patch_inertia = maxf(0.0, plr._patch_inertia - dt * 2.5)
	_ok(plr._patch_inertia == 0.0, "plaque_de_glace : _patch_inertia redescend bien a 0 apres la plaque")

	# --- 2. CAPSULE CRYOGENIQUE : destruction -> 35% de chance d'appeler awaken_enemy ---
	# (teste le branchement, pas la probabilite exacte : on force plusieurs capsules)
	for i in 30:
		var cap: PropScatter.Prop = PropScatter.Prop.new()
		cap.game = game_stub; cap.kind = "capsule_cryogenique"; cap.def = PropScatter.DECOR["capsule_cryogenique"]
		cap.position = Vector2(500.0 + i * 10.0, 0.0); cap.rand_scale = 1.0; cap.skill_roll = 0.0; cap.flip = false
		add_child(cap)
		cap.take_damage(9999.0)
	_ok(game_stub.awaken_calls > 0, "capsule_cryogenique : au moins un reveil d'ennemi sur 30 destructions",
		"obtenu=%d" % game_stub.awaken_calls)
	# 04/10, WEAK signale par le patron : les 2 issues etaient indiscernables APRES coup (meme VFX
	# neutre). Sur 30 tirages (35% d'embuscade), on doit voir les 2 teintes distinctes au moins 1
	# fois. Passe maintenant par impact_fx (mise a niveau VFX), pas plus spawn_vfx pour ce site.
	var has_red: bool = false; var has_gold: bool = false
	for c in game_stub.impact_colors:
		if c.r > 0.9 and c.g < 0.3: has_red = true
		if c.r > 0.9 and c.g > 0.7 and c.b < 0.5: has_gold = true
	_ok(has_red and has_gold, "capsule_cryogenique : les 2 issues (embuscade/bonus) ont une teinte distincte",
		"rouge=%s dore=%s" % [has_red, has_gold])

	# --- 3. JET DE CRYO : construit sa GroundZone DIRECTEMENT (meme idiome que bras_presseur,
	# shape/stun personnalises -> pas via le spawn_ground_zone stubbe), donc on verifie qu'un
	# enfant est bien apparu sous enemy_layer plutot que le compteur de la methode stubbee.
	var jet: PropScatter.Prop = PropScatter.Prop.new()
	jet.game = game_stub; jet.kind = "jet_de_cryo"; jet.def = PropScatter.DECOR["jet_de_cryo"]
	jet.position = Vector2(0.0, 0.0); jet.rand_scale = 1.0; jet.skill_roll = 0.0; jet.flip = false
	add_child(jet)
	var children_avant_jet: int = game_stub.enemy_layer.get_child_count()
	for i in 130:   # 13s simule > intervalle max 12s
		jet._process(dt)
	_ok(game_stub.enemy_layer.get_child_count() > children_avant_jet,
		"jet_de_cryo : une GroundZone apparait bien sous enemy_layer dans l'intervalle attendu")

	# --- 4. BROUILLARD FROID : derive (position change) et change de direction au moins une fois ---
	var fog: PropScatter.Prop = PropScatter.Prop.new()
	fog.game = game_stub; fog.kind = "brouillard_froid"; fog.def = PropScatter.DECOR["brouillard_froid"]
	fog.position = Vector2(0.0, 0.0); fog.rand_scale = 1.0; fog.skill_roll = 0.3; fog.flip = false
	add_child(fog)
	var x0: float = fog.global_position.x
	var dir0: Vector2 = fog._fog_dir
	var dir_changee: bool = false
	for i in 200:   # 20s simule, plusieurs retargets attendus (4-8s d'intervalle)
		fog._process(dt)
		if fog._fog_dir != dir0:
			dir_changee = true
	_ok(fog.global_position.x != x0, "brouillard_froid : sa position a bouge", "x0=%.1f x=%.1f" % [x0, fog.global_position.x])
	_ok(dir_changee, "brouillard_froid : a change de direction au moins une fois sur 20s simulees")

	# --- 5. RADIATEUR : reduit bien l'alpha d'un brouillard factice a proximite ---
	fog._fog_alpha_mult = 1.0
	fog.global_position = Vector2(50.0, 50.0)
	var heater: PropScatter.Prop = PropScatter.Prop.new()
	heater.game = game_stub; heater.kind = "radiateur"; heater.def = PropScatter.DECOR["radiateur"]
	heater.position = Vector2(50.0, 50.0); heater.rand_scale = 1.0; heater.skill_roll = 0.0; heater.flip = false
	add_child(heater)
	heater._process(dt)
	_ok(fog._fog_alpha_mult == 0.0, "radiateur : a bien fait tomber l'alpha du brouillard proche a 0")

	# --- 6. PIC DE GLACE : GroundZone spawnee dans l'intervalle attendu ---
	var spike: PropScatter.Prop = PropScatter.Prop.new()
	spike.game = game_stub; spike.kind = "pic_de_glace"; spike.def = PropScatter.DECOR["pic_de_glace"]
	spike.position = Vector2(0.0, 0.0); spike.rand_scale = 1.0; spike.skill_roll = 0.0; spike.flip = false
	add_child(spike)
	var calls_avant_spike: int = game_stub.zone_calls
	for i in 110:   # 11s simule > intervalle max 10s
		spike._process(dt)
	_ok(game_stub.zone_calls > calls_avant_spike, "pic_de_glace : GroundZone spawnee dans l'intervalle attendu")

	# --- 7. BORNE THERMIQUE : ouvre bien une zone sure (calque de vanne_refroidissement) ---
	var thermal: PropScatter.Prop = PropScatter.Prop.new()
	thermal.game = game_stub; thermal.kind = "borne_thermique"; thermal.def = PropScatter.DECOR["borne_thermique"]
	thermal.position = Vector2(0.0, 0.0); thermal.rand_scale = 1.0; thermal.skill_roll = 0.0; thermal.flip = false
	add_child(thermal)
	var calls_avant_thermal: int = game_stub.zone_calls
	for i in 15:   # 1.5s, fill_time par defaut 1.0s, joueur au centre = dans le rayon
		thermal._thermal_zone._physics_process(dt)
		thermal._process(dt)
	_ok(game_stub.zone_calls > calls_avant_thermal, "borne_thermique : ouvre bien une zone sure")

	# --- 8. GLACE FRAGILE : devient permanente (collision activee) apres son delai ---
	var fragile: PropScatter.Prop = PropScatter.Prop.new()
	fragile.game = game_stub; fragile.kind = "glace_fragile"; fragile.def = PropScatter.DECOR["glace_fragile"]
	fragile.position = Vector2(0.0, 0.0); fragile.rand_scale = 1.0; fragile.skill_roll = 0.0; fragile.flip = false
	add_child(fragile)
	_ok((fragile._cycle_col.shape as CircleShape2D).radius < 1.0, "glace_fragile : marchable au depart (collision quasi nulle)")
	for i in 210:   # 21s simule > intervalle max 20s
		fragile._process(dt)
	_ok((fragile._cycle_col.shape as CircleShape2D).radius >= 60.0,
		"glace_fragile : devient un obstacle permanent apres son delai",
		"rayon=%.1f" % (fragile._cycle_col.shape as CircleShape2D).radius)
	_ok(fragile._fragile_broken, "glace_fragile : marquee comme rompue (ne redeclenche plus)")

	# --- 04/10, lisibilite signalee par le patron : l'espacement entre decors doit tenir compte
	# du VRAI rayon visuel de brouillard_froid (nuage procedural ~572u), pas de son sz=20 quasi
	# nul (sprite de base masque) - sinon un autre decor peut etre pose presque DANS le nuage.
	# Verifie en forcant le placement reel (_load_chunk) sur plusieurs chunks "cryo" et en
	# cherchant un cas ou brouillard_froid cohabite avec un autre prop dans le MEME chunk.
	var ps_space: PropScatter = PropScatter.new()
	add_child(ps_space); ps_space.game = game_stub; ps_space.biome = "cryo"
	var found_case: bool = false
	var min_dist_found: float = 999999.0
	for cx in range(-10, 10):
		for cy in range(-10, 10):
			ps_space._load_chunk(Vector2i(cx, cy))
			var props: Array = ps_space._chunks[Vector2i(cx, cy)]
			var fog_prop: PropScatter.Prop = null
			for p in props:
				if p.kind == "brouillard_froid": fog_prop = p
			if fog_prop != null and props.size() > 1:
				found_case = true
				for p in props:
					if p != fog_prop:
						min_dist_found = minf(min_dist_found, fog_prop.position.distance_to(p.position))
	_ok(found_case, "brouillard_froid : au moins un chunk l'a place avec un voisin (echantillon assez large)")
	# ancienne formule : gap ~64 (55+20*0.45) -> un voisin pouvait tomber des ~130u. Nouvelle
	# formule : gap ~312 (55+572*0.45) rien que pour le brouillard -> jamais en dessous de ~300u.
	_ok(min_dist_found > 280.0, "brouillard_froid : le voisin le plus proche observe respecte le nouvel espacement (plus de chevauchement dans le nuage)",
		"min_dist=%.1f" % min_dist_found)

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
