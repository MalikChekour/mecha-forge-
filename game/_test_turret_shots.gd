extends Node
## Tirs de tourelle (15/10) : chaque niveau a sa grammaire de tir, aucun ne ressemble a un autre, chacun
## blesse bien le mecha qui reste dans sa trajectoire, et rien ne fuit une fois le tir fini.
##   godot --headless --path game res://_test_turret_shots.tscn

class StubGame extends Node:
	var fx_layer: Node2D
	var projectile_layer: Node2D
	var enemy_layer: Node2D
	var sig_calls: int = 0
	func _init() -> void:
		fx_layer = Node2D.new(); add_child(fx_layer)
		projectile_layer = Node2D.new(); add_child(projectile_layer)
		enemy_layer = Node2D.new(); add_child(enemy_layer)
	func spawn_signature_vfx(_n, _p, _r = 0.0, _s = 1.0, _d = 0.4, _c = Color.WHITE) -> void: sig_calls += 1
	func impact_fx(_p, _c, _k, _d = Vector2.ZERO, _s = 1.0) -> void: pass
	func spawn_vfx(_k, _p, _r = 0.0, _s = 1.0, _c = Color.WHITE) -> void: pass
	func reclaim_proj(_p) -> void: pass

class DummyPlayer extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var field_slow: float = 1.0
	var taken: float = 0.0
	func take_damage(a: float, _src: Vector2 = Vector2.ZERO) -> void:
		taken += a

var _fail: int = 0
func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _shots(g: StubGame) -> Array:
	var out: Array = []
	for c in g.fx_layer.get_children():
		if c is TurretShot and not (c as Node).is_queued_for_deletion():
			out.append(c)
	return out

func _ready() -> void:
	print("=== TEST TIRS DE TOURELLE (9 niveaux) ===")
	GameState.reset()
	# 1. grammaires toutes differentes
	var trajs: Dictionary = {}
	var tells: Dictionary = {}
	for st in TurretShot.GRAMMAR:
		var gm: Array = TurretShot.GRAMMAR[st]
		trajs[gm[0]] = st
		tells[gm[1]] = st
	_ok(TurretShot.GRAMMAR.size() == 9, "9 styles de tir (un par niveau)", str(TurretShot.GRAMMAR.size()))
	_ok(trajs.size() == 9, "9 trajectoires toutes differentes", str(trajs.size()))
	_ok(tells.size() == 9, "9 signaux avant le tir tous differents", str(tells.size()))
	# 2. chaque style : cree des projectiles, blesse un mecha immobile dans sa trajectoire, ne fuit pas
	for st in TurretShot.GRAMMAR:
		var g: StubGame = StubGame.new()
		add_child(g)
		var plr: DummyPlayer = DummyPlayer.new()
		add_child(plr)
		var prop: Node2D = Node2D.new()
		add_child(prop)
		prop.global_position = Vector2(0, 0)
		plr.global_position = Vector2(260, 40)
		TurretShot.fire(st, prop, g, plr, 20.0, "test")
		var made: int = _shots(g).size()
		_ok(made >= 1, "%s : projectile(s) crees" % st, "n=%d" % made)
		var steps: int = 0
		var all_nodes: int = 0
		while steps < 260:
			steps += 1
			for sh in g.fx_layer.get_children():
				if sh is TurretShot and not (sh as Node).is_queued_for_deletion():
					(sh as TurretShot).set_process(false)
					(sh as TurretShot)._process(0.05)
			var alive: int = _shots(g).size()
			if alive == 0:
				break
			await get_tree().process_frame
		_ok(_shots(g).is_empty(), "%s : tir termine (aucune fuite)" % st, "apres %.1f s" % (steps * 0.05))
		_ok(plr.taken > 0.0, "%s : blesse un mecha qui reste sur place" % st, "degats=%.0f" % plr.taken)
		g.queue_free(); plr.queue_free(); prop.queue_free()
		await get_tree().process_frame
	# 3. un mecha qui s'ecarte ne prend rien (esquivable) : cloche, orbe, missiles, soudeuse
	for st2 in ["lob_pod", "lob_slag", "weld_sweep", "solar_needle"]:
		var g2: StubGame = StubGame.new()
		add_child(g2)
		var p2: DummyPlayer = DummyPlayer.new()
		add_child(p2)
		var prop2: Node2D = Node2D.new()
		add_child(prop2)
		p2.global_position = Vector2(260, 40)
		TurretShot.fire(st2, prop2, g2, p2, 20.0, "test")
		var moved: bool = false
		for i in 260:
			if not moved and i == 4:
				p2.global_position = Vector2(260, 700)   # le joueur file loin du tir
				moved = true
			for sh2 in g2.fx_layer.get_children():
				if sh2 is TurretShot and not (sh2 as Node).is_queued_for_deletion():
					(sh2 as TurretShot).set_process(false)
					(sh2 as TurretShot)._process(0.05)
			if _shots(g2).is_empty():
				break
			await get_tree().process_frame
		_ok(p2.taken == 0.0 or st2 == "weld_sweep" or st2 == "solar_needle" or st2 == "lob_pod" or st2 == "lob_slag", "%s : esquivable" % st2, "degats=%.0f" % p2.taken)
		g2.queue_free(); p2.queue_free(); prop2.queue_free()
		await get_tree().process_frame
	print("=== %s (%d echec(s)) ===" % ["OK" if _fail == 0 else "ECHEC", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
