extends Node
## Les canons PIVOTENT (15/10, patron : « si le projectile poursuit, le canon doit pivoter pour etre aligne avec
## le tir » / « fais pivoter l'image integrale du canon ») : l'image entiere tourne, la bouche pointe vers le mecha.
##   godot --headless --path game res://_test_turret_rotation.tscn

class StubGame extends Node:
	var fx_layer: Node2D
	var projectile_layer: Node2D
	var enemy_layer: Node2D
	var cover_list: Array = []
	var arena: Rect2 = Rect2(-6000, -6000, 12000, 12000)
	func _init() -> void:
		fx_layer = Node2D.new(); add_child(fx_layer)
		projectile_layer = Node2D.new(); add_child(projectile_layer)
		enemy_layer = Node2D.new(); add_child(enemy_layer)
	func spawn_signature_vfx(_n, _p, _r = 0.0, _s = 1.0, _d = 0.4, _c = Color.WHITE) -> void: pass
	func impact_fx(_p, _c, _k, _d = Vector2.ZERO, _s = 1.0) -> void: pass
	func spawn_vfx(_k, _p, _r = 0.0, _s = 1.0, _c = Color.WHITE) -> void: pass
	func spawn_ground_zone(_p, _r, _d, _dmg, _c = Color.WHITE, _k = "decor_hit") -> void: pass

class DummyPlayer extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var field_slow: float = 1.0
	func take_damage(_a, _s = Vector2.ZERO) -> void: pass

var _fail: int = 0
func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST CANONS QUI PIVOTENT ===")
	GameState.reset()
	var g: StubGame = StubGame.new()
	add_child(g)
	var plr: DummyPlayer = DummyPlayer.new()
	add_child(plr)
	plr.add_to_group("player")
	var kinds: Array = ["tourelle", "tech_soudeuse", "desert_miroir_solaire", "jungle_mortier_plante", "volcanic_mortier_scories",
		"swamp_tourelle_dca", "cryo_canon_azote", "reacteur_canon_particules"]
	for k in kinds:
		var p: PropScatter.Prop = PropScatter.Prop.new()
		p.game = g; p.kind = k; p.def = PropScatter.DECOR[k]
		p.position = Vector2.ZERO; p.rand_scale = 1.0; p.skill_roll = 0.0; p.flip = false
		add_child(p)
		p._plr = plr
		_ok(p.has_head(), "%s : canon pivotant" % k)
		var worst: float = 0.0
		for deg in [0, 45, 90, 135, 180, 225, 270, 315]:
			var dirv: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(deg)))
			plr.global_position = dirv * 320.0
			for i in 140:
				p._update_head(0.05, 320.0)
			# la ligne bouche -> direction du canon doit passer par le mecha (ecart lateral en pixels)
			var line_pt: Vector2 = p.muzzle_world()
			var ang: float = Geometry2D.get_closest_point_to_segment(plr.global_position, line_pt - p.head_dir() * 900.0, line_pt + p.head_dir() * 900.0).distance_to(plr.global_position)
			worst = maxf(worst, ang)
		_ok(worst < 8.0, "%s : le canon vise le mecha dans les 8 directions" % k, "ecart lateral max=%.1f px a 320 px" % worst)
		# l'image entiere tourne : le sprite principal est visible et ses enfants ne sont pas decoupes
		_ok(p._sprite != null and p._sprite.self_modulate.a > 0.99 and p._sprite.get_child_count() == 0, "%s : image entiere (pas de decoupe)" % k)
		p.queue_free()
		await get_tree().process_frame
	print("=== %s (%d echec(s)) ===" % ["OK" if _fail == 0 else "ECHEC", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
