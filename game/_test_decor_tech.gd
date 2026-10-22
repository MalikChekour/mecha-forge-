extends Node
## Headless regression harness pour le DECOR INTERACTIF "Secteur Tech" (refonte 15-maps, maps 1-3
## fusionnees en un decor enrichi pour le biome "tech" - voir le plan). Teste directement les
## nouvelles branches de PropScatter.Prop + l'extension shape="line" de GroundZone, sans passer
## par un vrai chunk/scene de jeu (meme moule que _test_enemies.gd : appel manuel de _process()).
##   godot --headless --path game res://_test_decor_tech.tscn

class StubGame extends Node:
	var enemy_layer: Node2D
	var zone_calls: int = 0
	var vfx_calls: int = 0
	func _init() -> void:
		enemy_layer = Node2D.new()
		add_child(enemy_layer)
	func spawn_ground_zone(_pos: Vector2, _radius: float, _delay: float, _dmg: float, _color: Color = Color.WHITE, _fx_kind: String = "decor_hit") -> void:
		zone_calls += 1
	func spawn_vfx(_kind: String, _pos: Vector2, _rot: float, _scale: float, _color: Color) -> void:
		vfx_calls += 1
	# 04/10, mise a niveau VFX : les explosions GroundZone passent maintenant par impact_fx (meme
	# composite que le combat) au lieu de spawn_vfx seul.
	var impact_calls: int = 0
	func impact_fx(_pos: Vector2, _color: Color, _kind: String, _dir: Vector2 = Vector2.ZERO, _scale: float = 1.0) -> void:
		impact_calls += 1

class DummyPlayer extends Node2D:
	var dmg_calls: int = 0
	var last_dmg: float = 0.0
	var stun_calls: int = 0
	var last_stun: float = 0.0
	func take_damage(amount: float, _pos: Vector2 = Vector2.ZERO, _tag: String = "") -> void:
		dmg_calls += 1; last_dmg = amount
	func stun(duration: float) -> void:
		stun_calls += 1; last_stun = duration

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST DECOR INTERACTIF (SECTEUR TECH) ===")
	GameState.reset()

	# --- 0. les 9 nouvelles cles existent, cote DECOR et cote pool du biome "tech" ---
	var tech_kinds: Array = PropScatter.BIOME_DECOR["tech"]
	var new_kinds: Array[String] = ["convoyeur_sol", "console_convoyeur", "bras_presseur",
		"piston_hydraulique", "vanne_refroidissement", "surchauffe_sol", "porte_automatique",
		"zone_chargement", "container_mobile"]
	for k in new_kinds:
		_ok(tech_kinds.has(k), "BIOME_DECOR['tech'] contient '%s'" % k)
		_ok(PropScatter.DECOR.has(k), "DECOR['%s'] existe" % k)

	# --- 1. GroundZone shape="line" (bras presseur) : touche sur la ligne, pas a cote ---
	var plr_on: DummyPlayer = DummyPlayer.new()
	add_child(plr_on)
	plr_on.global_position = Vector2(50.0, 10.0)   # a 10px de l'axe -> dans le rayon 30
	var z1: GroundZone = GroundZone.new()
	z1.shape = "line"; z1.line_from = Vector2(-100.0, 0.0); z1.line_to = Vector2(100.0, 0.0)
	z1.radius = 30.0; z1.damage = 15.0; z1.stun_duration = 0.5
	z1.player = plr_on; z1.game = null
	add_child(z1)
	_ok(z1._beam != null, "GroundZone shape=line : construit bien un sprite de ligne visible (04/10, etait un cercle fixe avant)")
	z1._explode()
	_ok(plr_on.dmg_calls == 1, "bras presseur : touche un joueur SUR la ligne")
	_ok(plr_on.stun_calls == 1 and plr_on.last_stun == 0.5, "bras presseur : applique le stun (0.5s)")

	# 04/10, mise a niveau VFX (demande du patron) : l'explosion GroundZone (bras_presseur et TOUS
	# les dangers qui la reutilisent : jet_de_cryo, pic_de_glace, grille_ventilation...) passe
	# maintenant par impact_fx (meme composite riche que le combat) au lieu de spawn_vfx seul.
	var gs_vfx: StubGame = StubGame.new()
	add_child(gs_vfx)
	var z1b: GroundZone = GroundZone.new()
	z1b.shape = "line"; z1b.line_from = Vector2(-100.0, 0.0); z1b.line_to = Vector2(100.0, 0.0)
	z1b.radius = 30.0; z1b.damage = 15.0
	z1b.player = null; z1b.game = gs_vfx
	add_child(z1b)
	z1b._explode()
	_ok(gs_vfx.impact_calls == 1, "bras presseur : l'explosion appelle bien impact_fx (composite riche, plus de spawn_vfx seul)")

	var plr_off: DummyPlayer = DummyPlayer.new()
	add_child(plr_off)
	plr_off.global_position = Vector2(50.0, 200.0)   # loin de l'axe -> hors du rayon 30
	var z2: GroundZone = GroundZone.new()
	z2.shape = "line"; z2.line_from = Vector2(-100.0, 0.0); z2.line_to = Vector2(100.0, 0.0)
	z2.radius = 30.0; z2.damage = 15.0
	z2.player = plr_off; z2.game = null
	add_child(z2)
	z2._explode()
	_ok(plr_off.dmg_calls == 0, "bras presseur : ne touche PAS un joueur a cote de la ligne")

	# --- 2. CONVOYEUR SOL pousse le joueur ; une CONSOLE voisine le coupe temporairement ---
	var game_stub: StubGame = StubGame.new()
	add_child(game_stub)
	var plr: DummyPlayer = DummyPlayer.new()
	add_child(plr)
	plr.add_to_group("player")
	plr.global_position = Vector2(0.0, 0.0)

	var conv: PropScatter.Prop = PropScatter.Prop.new()
	conv.game = game_stub; conv.kind = "convoyeur_sol"; conv.def = PropScatter.DECOR["convoyeur_sol"]
	conv.position = Vector2(0.0, 0.0); conv.rand_scale = 1.0; conv.skill_roll = 0.0; conv.flip = false
	add_child(conv)
	# 04/10, mise a niveau VFX (demande du patron) : le glow de base generique ("glow": "orange" sur
	# convoyeur_sol) a maintenant un coeur enfant, comme les 15 autres anneaux ambiants du decor.
	var found_halo_with_core: bool = false
	for c in conv.get_children():
		if c is Sprite2D and c.get_child_count() > 0:
			found_halo_with_core = true
	_ok(found_halo_with_core, "convoyeur_sol : le glow de base generique a bien un coeur (04/10, halo+coeur)")

	var dt: float = 0.1
	for i in 10:   # 1.0s simule : joueur a 0px du convoyeur (rayon 150) -> pousse chaque tick
		conv._process(dt)
	_ok(plr.global_position.x > 0.0, "convoyeur_sol : pousse le joueur (direction RIGHT, skill_roll=0)",
		"x=%.1f" % plr.global_position.x)
	_ok(conv._conveyor_vfx_t > 0.0, "convoyeur_sol : pulse un VFX periodique (via FxKit)",
		"vfx_t=%.1f" % conv._conveyor_vfx_t)

	var x_avant_console: float = plr.global_position.x
	var console: PropScatter.Prop = PropScatter.Prop.new()
	console.game = game_stub; console.kind = "console_convoyeur"; console.def = PropScatter.DECOR["console_convoyeur"]
	console.position = Vector2(0.0, 0.0); console.rand_scale = 1.0; console.skill_roll = 0.0; console.flip = false
	add_child(console)
	for i in 15:   # 1.5s simule : fill_time par defaut 1.0s, le joueur est dans son rayon (dwell_r 90)
		console._console_zone._physics_process(dt)
		console._process(dt)
	_ok(conv._conveyor_stop_t > 0.0, "console_convoyeur : a coupe le convoyeur voisin (meme groupe)")

	for i in 10:   # 1.0s simule : doit rester coupe (console_stop_dur = 8.0)
		conv._process(dt)
	_ok(plr.global_position.x == x_avant_console, "convoyeur_sol : reste coupe pendant console_stop_dur")

	for i in 90:   # 9.0s simule de plus (> 8s de coupure restante) -> doit reprendre
		conv._process(dt)
	_ok(plr.global_position.x > x_avant_console, "convoyeur_sol : reprend apres console_stop_dur")

	# --- 3. PISTON (reutilise _cycle, meme precedent que "quai") : la collision bascule bien ---
	var piston: PropScatter.Prop = PropScatter.Prop.new()
	piston.game = game_stub; piston.kind = "piston_hydraulique"; piston.def = PropScatter.DECOR["piston_hydraulique"]
	piston.position = Vector2(500.0, 0.0); piston.rand_scale = 1.0; piston.skill_roll = 0.0; piston.flip = false
	add_child(piston)
	_ok(piston._cycle_present, "piston_hydraulique : present au depart (cycle_on en premier)")
	for i in 25:   # 2.5s simule > cycle_on (2.0s) -> doit basculer absent/disabled
		piston._process(dt)
	_ok(not piston._cycle_present and piston._cycle_col.disabled,
		"piston_hydraulique : bascule absent + collision desactivee apres cycle_on")

	# --- 4. CONTAINER MOBILE (seule piece reellement neuve) : oscille entre les 2 bouts du rail ---
	var cont: PropScatter.Prop = PropScatter.Prop.new()
	cont.game = game_stub; cont.kind = "container_mobile"; cont.def = PropScatter.DECOR["container_mobile"]
	cont.position = Vector2(1000.0, 0.0); cont.rand_scale = 1.0; cont.skill_roll = 0.0; cont.flip = false
	add_child(cont)
	var x0: float = cont.global_position.x
	for i in 20:
		cont._process(dt)
	var x_mid: float = cont.global_position.x
	_ok(x_mid != x0, "container_mobile : sa position a bouge sur le rail", "x0=%.1f x_mid=%.1f" % [x0, x_mid])

	# --- 5. SURCHAUFFE DU SOL : respawn une GroundZone dans l'intervalle attendu (~2s) ---
	var over: PropScatter.Prop = PropScatter.Prop.new()
	over.game = game_stub; over.kind = "surchauffe_sol"; over.def = PropScatter.DECOR["surchauffe_sol"]
	over.position = Vector2(0.0, 0.0); over.rand_scale = 1.0; over.skill_roll = 0.0; over.flip = false
	add_child(over)
	var calls_avant: int = game_stub.zone_calls
	for i in 30:   # 3.0s simule > 2.0s d'intervalle -> au moins un appel
		over._process(dt)
	_ok(game_stub.zone_calls > calls_avant, "surchauffe_sol : spawn_ground_zone appele dans l'intervalle attendu",
		"appels=%d" % (game_stub.zone_calls - calls_avant))

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
