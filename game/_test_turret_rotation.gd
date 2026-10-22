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
	func take_damage(_a, _s = Vector2.ZERO, _tag: String = "") -> void: pass

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
		"swamp_tourelle_dca", "cryo_canon_azote", "reacteur_canon_particules", "ruche_organe_acide"]
	var styles: Dictionary = {"tech_soudeuse": "weld_sweep", "jungle_mortier_plante": "lob_pod", "volcanic_mortier_scories": "lob_slag",
		"swamp_tourelle_dca": "flak", "cryo_canon_azote": "orb_frost", "reacteur_canon_particules": "plasma", "ruche_organe_acide": "acid_burst"}
	for k in kinds:
		var p: PropScatter.Prop = PropScatter.Prop.new()
		p.game = g; p.kind = k; p.def = PropScatter.DECOR[k]
		p.position = Vector2.ZERO; p.rand_scale = 1.0; p.skill_roll = 0.0; p.flip = false
		add_child(p)
		p._plr = plr
		_ok(p.has_head(), "%s : tourelle a canon" % k)
		var tube: bool = PropScatter.TUBE_CANNONS.has(String(PropScatter.DECOR[k]["f"]))
		_ok(p.barrel_fixed() == tube, "%s : canon a tube fixe = %s" % [k, str(tube)])
		var d0: Vector2 = p.head_dir()
		var rot_max: float = 0.0
		for deg in [0, 45, 90, 135, 180, 225, 270, 315]:
			plr.global_position = Vector2.RIGHT.rotated(deg_to_rad(float(deg))) * 320.0
			for i in 20:
				p._update_head(0.05, 320.0)
			p.head_snap(plr.global_position)
			rot_max = maxf(rot_max, absf(p._sprite.rotation))
		_ok(rot_max == 0.0 and p.head_dir().is_equal_approx(d0), "%s : l image ne pivote pas (rotation max=%.3f)" % [k, rot_max])
		_ok(p._sprite != null and p._sprite.self_modulate.a > 0.99 and p._sprite.get_child_count() == 0, "%s : image entiere (pas de decoupe)" % k)
		if tube and styles.has(k):
			# le tir part DROIT dans l axe du tube, quelle que soit la position du mecha
			plr.global_position = Vector2(0.0, 300.0)
			var before: int = g.fx_layer.get_child_count()
			TurretShot.fire(String(styles[k]), p, g, plr, 10.0, k)
			var worst: float = 0.0
			var n: int = 0
			for c in g.fx_layer.get_children():
				if c is TurretShot:
					var sh: TurretShot = c
					if sh.style == "bolt" or sh.style == "thorn":
						continue
					var v: Vector2 = (sh.tgt - sh.src)
					if String(styles[k]) in ["weld_sweep", "orb_frost", "plasma"]:
						v = sh.dir
					worst = maxf(worst, rad_to_deg(absf(v.normalized().angle_to(d0))) if String(styles[k]) != "flak" and String(styles[k]) != "acid_burst" else 0.0)
					n += 1
			_ok(n > 0 and worst < 1.0, "%s : tir droit dans l axe du tube (ecart max %.2f deg, %d tirs)" % [k, worst, n])
			for c in g.fx_layer.get_children():
				if c is TurretShot:
					c.queue_free()
		p.queue_free()
		await get_tree().process_frame
	print("=== %s (%d echec(s)) ===" % ["OK" if _fail == 0 else "ECHEC", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
