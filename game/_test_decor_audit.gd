extends Node
## Audit decor (14/10) : chaque decor a effet a une pancarte, les supports (console/vanne/radiateur/
## plante) ont TOUJOURS une cible a cote, vanne+borne soignent vraiment, le brouillard ralentit.
##   godot --headless --path game res://_test_decor_audit.tscn

const GameScript = preload("res://scenes/Game.gd")

class StubGame extends Node:
	var enemy_layer: Node2D
	var arena: Rect2 = Rect2(-6000, -6000, 12000, 12000)
	var cover_list: Array = []
	var pancartes: Array = []
	func _init() -> void:
		enemy_layer = Node2D.new()
		add_child(enemy_layer)
	func spawn_ground_zone(_p, _r, _d, _dmg, _c = Color.WHITE, _k = "decor_hit") -> void: pass
	func spawn_vfx(_k, _p, _r, _s, _c = Color.WHITE) -> void: pass
	func impact_fx(_p, _c, _k, _d = Vector2.ZERO, _s = 1.0) -> void: pass
	func pancarte_prop(kind: String, _tex, _prop = null) -> void:
		if not pancartes.has(kind):
			pancartes.append(kind)

class DummyPlayer extends Node2D:
	var field_slow: float = 1.0
	var _patch_inertia: float = 0.0
	var hp: float = 40.0
	var max_hp: float = 100.0
	func heal(a: float) -> void:
		hp = minf(max_hp, hp + a)

var _fail: int = 0
func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _mk(g: Node, kind: String, pos: Vector2) -> PropScatter.Prop:
	var p: PropScatter.Prop = PropScatter.Prop.new()
	p.game = g; p.kind = kind; p.def = PropScatter.DECOR[kind]
	p.position = pos; p.rand_scale = 1.0; p.skill_roll = 0.0; p.flip = false
	add_child(p)
	return p

func _near(p: Node2D, grp: String, rng: float) -> bool:
	for q in get_tree().get_nodes_in_group(grp):
		if (q as Node2D).global_position.distance_to(p.global_position) <= rng:
			return true
	return false

func _check_support(biome: String, kind: String, grp: String, rng: float) -> void:
	var game_stub: StubGame = StubGame.new()
	add_child(game_stub)
	var plr: DummyPlayer = DummyPlayer.new()
	add_child(plr)
	plr.add_to_group("player")
	var ps: PropScatter = PropScatter.new()
	ps.game = game_stub; ps.biome = biome; ps.arena_half = 5000.0
	add_child(ps)
	ps.populate()
	var n_sup: int = 0
	var n_ok: int = 0
	for c in ps._chunks:
		for p in ps._chunks[c]:
			if is_instance_valid(p) and (p as PropScatter.Prop).kind == kind:
				n_sup += 1
				if _near(p as Node2D, grp, rng):
					n_ok += 1
	_ok(n_sup > 0, "%s : au moins un %s place" % [biome, kind], "n=%d" % n_sup)
	_ok(n_sup == n_ok, "%s : chaque %s a une cible (%s) a portee" % [biome, kind, grp], "%d/%d" % [n_ok, n_sup])
	ps.queue_free(); game_stub.queue_free(); plr.queue_free()
	await get_tree().process_frame

func _ready() -> void:
	print("=== AUDIT DECOR : pancartes / supports / soins ===")
	GameState.reset()

	# 1. chaque INFO pointe un decor reel, chaque decor a effet a une INFO
	for k in PropScatter.INFO:
		_ok(PropScatter.DECOR.has(k), "INFO['%s'] -> DECOR existe" % k)
		var inf: Array = PropScatter.INFO[k]
		_ok(inf.size() == 3 and String(inf[0]) != "" and String(inf[1]).length() > 15, "INFO['%s'] bien formee" % k)
	var terrain: Array = ["rocher", "arbre", "arche"]
	var neutres: Array = ["f", "hp", "sz", "destruct", "nature", "skill", "glow", "block"]
	for k in PropScatter.DECOR:
		var has_effect: bool = false
		for key in PropScatter.DECOR[k]:
			if not (key in neutres):
				has_effect = true
		if k in terrain:
			continue
		_ok(PropScatter.INFO.has(k) or not has_effect, "decor '%s' a effet -> a une pancarte" % k)
	for b in PropScatter.BIOME_DECOR:
		for k in PropScatter.BIOME_DECOR[b]:
			if k in terrain:
				continue
			_ok(PropScatter.INFO.has(k), "biome %s / %s : pancarte" % [b, k])

	# 2. supports : une cible TOUJOURS a portee
	await _check_support("tech", "console_convoyeur", "tech_convoyeur", 400.0)
	await _check_support("reacteur", "vanne_drainage", "reacteur_toxic", 250.0)
	await _check_support("reacteur", "console_vent", "reacteur_wind", 400.0)
	await _check_support("ruche", "plante_lumineuse", "ruche_spores", 300.0)
	await _check_support("cryo", "radiateur", "cryo_fog", 320.0)

	# 3. vanne + borne : soin reel ; vanne eteint un sol en surchauffe voisin
	var g: StubGame = StubGame.new()
	add_child(g)
	var plr3: DummyPlayer = DummyPlayer.new()
	add_child(plr3)
	plr3.add_to_group("player")
	var valve: PropScatter.Prop = _mk(g, "vanne_refroidissement", Vector2.ZERO)
	var hot: PropScatter.Prop = _mk(g, "surchauffe_sol", Vector2(120, 0))
	hot._overheat_r = 240.0
	valve._plr = plr3
	valve._on_valve_filled()
	_ok(plr3.hp > 55.0, "vanne : soigne 20 pour cent des PV max", "hp=%.0f" % plr3.hp)
	_ok(hot._overheat_r < 100.0, "vanne : eteint le sol en surchauffe voisin", "r=%.0f" % hot._overheat_r)
	var therm: PropScatter.Prop = _mk(g, "borne_thermique", Vector2.ZERO)
	therm._plr = plr3
	var before: float = plr3.hp
	therm._on_thermal_filled()
	_ok(plr3.hp > before + 15.0, "borne thermique : soigne 20 pour cent des PV max", "%.0f -> %.0f" % [before, plr3.hp])
	valve._process(0.1)
	_ok(valve._valve_zone != null and not valve._valve_zone.active, "vanne : anneau eteint pendant la recharge")
	valve._valve_cd_t = 0.05
	valve._process(0.1)
	_ok(valve._valve_zone.active, "vanne : anneau reactive apres la recharge")

	# 4. brouillard : ralentit le joueur DANS le nuage, plus apres un radiateur
	var fog: PropScatter.Prop = _mk(g, "brouillard_froid", Vector2(20, 0))
	plr3.field_slow = 1.0
	fog._process(0.1)
	_ok(plr3.field_slow < 0.8, "brouillard epais : ralentit le joueur", "field_slow=%.2f" % plr3.field_slow)
	plr3.field_slow = 1.0
	fog._fog_alpha_mult = 0.0
	fog._process(0.1)
	_ok(plr3.field_slow == 1.0, "brouillard dissipe (radiateur) : plus de ralentissement")

	plr3.remove_from_group("player")
	plr3.queue_free()
	await get_tree().process_frame
	# 5. pancarte : PropScatter signale un decor INFO proche, rien quand le joueur est loin
	var gs5: StubGame = StubGame.new()
	add_child(gs5)
	var pl5: DummyPlayer = DummyPlayer.new()
	add_child(pl5)
	pl5.add_to_group("player")
	var ps5: PropScatter = PropScatter.new()
	ps5.game = gs5; ps5.biome = "tech"; ps5.arena_half = 5000.0
	add_child(ps5)
	ps5.populate()
	var target: PropScatter.Prop = null
	for c in ps5._chunks:
		for p in ps5._chunks[c]:
			if is_instance_valid(p) and PropScatter.INFO.has((p as PropScatter.Prop).kind):
				target = p
				break
		if target != null:
			break
	pl5.global_position = target.global_position + Vector2(200, 0)
	ps5._sign_scan_t = 0.0
	ps5._scan_new_kinds(0.1)
	_ok(gs5.pancartes.has(target.kind), "pancarte : decor a 200 u signale a Game (rayon 380)", target.kind)
	pl5.global_position = target.global_position + Vector2(450, 0)
	gs5.pancartes.clear()
	ps5._sign_scan_t = 0.0
	ps5._scan_new_kinds(0.1)
	_ok(not gs5.pancartes.has(target.kind), "pancarte : decor a 450 u (hors rayon 380) PAS signale")
	pl5.global_position = Vector2(99999, 99999)
	gs5.pancartes.clear()
	ps5._sign_scan_t = 0.0
	ps5._scan_new_kinds(0.1)
	_ok(gs5.pancartes.is_empty(), "pancarte : rien de signale quand le joueur est loin")

	# 6. tapis : grand, pousse dans le sens des chevrons, miroir avec flip
	var tp: PropScatter.Prop = _mk(g, "convoyeur_sol", Vector2(5000, 5000))
	_ok(tp._conveyor_r >= 260.0, "tapis : perimetre d'effet agrandi", "r=%.0f" % tp._conveyor_r)
	_ok(tp._conveyor_dir.x > 0.8 and tp._conveyor_dir.y > 0.4, "tapis : poussee dans le sens des chevrons (bas-droite)", str(tp._conveyor_dir))
	var tf: PropScatter.Prop = PropScatter.Prop.new()
	tf.game = g; tf.kind = "convoyeur_sol"; tf.def = PropScatter.DECOR["convoyeur_sol"]
	tf.position = Vector2(-5000, 5000); tf.rand_scale = 1.0; tf.skill_roll = 0.0; tf.flip = true
	add_child(tf)
	_ok(tf._conveyor_dir.x < -0.8 and tf._sprite.flip_h, "tapis miroir : poussee ET dessin inverses", str(tf._conveyor_dir))

	# 7. ennemis : chaque comportement code dans Enemy.gd a sa pancarte (+ boss)
	var src: String = FileAccess.get_file_as_string("res://actors/Enemy.gd")
	var rx: RegEx = RegEx.new()
	rx.compile('behavior == "([a-z_]+)"')
	var behs: Dictionary = {"rush": true}
	for m in rx.search_all(src):
		behs[m.get_string(1)] = true
	for b in behs:
		_ok(GameScript.ENEMY_INFO.has(b), "ennemi '%s' : pancarte" % b)
	_ok(GameScript.ENEMY_INFO.has("boss"), "boss : pancarte")
	for k in GameScript.ENEMY_INFO:
		var ei: Array = GameScript.ENEMY_INFO[k]
		_ok(ei.size() == 3 and String(ei[1]).length() > 15, "ENEMY_INFO['%s'] bien formee" % k)

	print("=== %s (%d echec(s)) ===" % ["OK" if _fail == 0 else "ECHEC", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
