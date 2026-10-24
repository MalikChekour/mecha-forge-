extends Node
## Escouades, grades, visee et garde active (21/10). Simulation sans scene de jeu : un faux Game fournit les calques.

class StubGame extends Node:
	var enemy_layer: Node2D = Node2D.new()
	var projectile_layer: Node2D = Node2D.new()
	var cover_list: Array = []
	var spawner: EnemySpawner = null
	var bolts: Array = []
	var banners: Array = []
	func _ready() -> void:
		add_child(enemy_layer)
		add_child(projectile_layer)
	func spawn_enemy_bolt(pos: Vector2, dir: Vector2, dmg: float, _c = Color.WHITE, _s = 1.0, _v = 300.0, _m = false, _h = 0.0, _tag: String = "") -> void:
		bolts.append([pos, dir])
	func spawn_vfx(_k, _p, _r = 0.0, _s = 1.0, _c = Color.WHITE) -> void: pass
	func shield_ripple(_p, _r, _c) -> void: pass
	func shield_break(_p, _r, _c) -> void: pass
	func show_banner(t: String, _c = Color.WHITE) -> void: banners.append(t)

class FakePlayer extends Node2D:
	var velocity: Vector2 = Vector2(200, 0)
	var base_speed: float = 300.0
	var chassis_family: String = "vortex"
	func take_damage(_a = 0.0, _b = Vector2.ZERO, _c = null, _d = null) -> void: pass

var _fail: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + msg)
	if not ok: _fail += 1

var rows: Array = []

func _ready() -> void:
	GameState.reset()
	Engine.time_scale = 6.0
	var g: StubGame = StubGame.new()
	add_child(g)
	await get_tree().process_frame
	var pl: FakePlayer = FakePlayer.new()
	pl.add_to_group("player")
	add_child(pl)
	var sp: EnemySpawner = EnemySpawner.new()
	sp.game = g
	sp.player = pl
	g.spawner = sp
	add_child(sp)
	sp.set_process(false)
	var biomes: Array = []
	for b in EnemySpawner.PROFILES.keys():
		biomes.append([int(EnemySpawner.PROFILES[b]["tier"]), b])
	biomes.sort()
	for pb in biomes:
		for scen in ["fixe", "mobile"]:
			await _run(g, sp, pl, String(pb[1]), int(pb[0]), scen)
	Engine.time_scale = 1.0
	var f: FileAccess = FileAccess.open("res://../tools/audit_deplacement.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows))
	f.close()
	print("AUDIT fini : ", rows.size(), " lignes")
	get_tree().quit(0)

func _run(g: StubGame, sp: EnemySpawner, pl: FakePlayer, biome: String, tier: int, scen: String) -> void:
	for c in g.enemy_layer.get_children():
		c.queue_free()
	await get_tree().physics_frame
	sp._squads.clear()
	sp.current_biome = biome
	GameState.run_time = 400.0                         # roles secondaires + Mark 2 deja en jeu
	pl.global_position = Vector2.ZERO
	pl.velocity = Vector2.ZERO
	var base: float = 336.0
	for i in 24:
		sp._spawn()
	for tn in ["mk2", "inter", "mini", "boss"]:
		sp._spawn_tier(tn)
	sp._spawn_squad(true)
	sp._spawn_squad(true)
	var st: Dictionary = {}
	var last: Dictionary = {}
	var d0: Dictionary = {}
	var dirs: Dictionary = {}
	for e in g.enemy_layer.get_children():
		if e is Enemy:
			var grp: String = _grp(e)
			e.set_meta("grp", grp)
			last[e] = e.global_position
			d0[e] = e.global_position.distance_to(pl.global_position)
			dirs[e] = {}
			if not st.has(grp):
				st[grp] = {"n": 0, "v": 0.0, "stat": 0, "samples": 0, "flip": 0, "approach": 0.0, "dirs": {}}
	var frames: int = 20 * 60
	var ang: float = 0.0
	var prevv: Dictionary = {}
	for f in frames:
		GameState.run_time += 1.0 / 60.0
		if scen == "mobile":
			ang += 0.9 / 60.0
			var np: Vector2 = Vector2.from_angle(ang) * 320.0
			pl.velocity = (np - pl.global_position) * 60.0
			pl.global_position = np
		sp._squad_tick(1.0 / 60.0)
		await get_tree().physics_frame
		for e in last.keys():
			if not is_instance_valid(e) or not e.alive:
				continue
			var grp2: String = e.get_meta("grp")
			var s: Dictionary = st[grp2]
			var v: Vector2 = (e.global_position - last[e]) * 60.0
			last[e] = e.global_position
			s["samples"] += 1
			s["v"] += v.length()
			if v.length() < 8.0:
				s["stat"] += 1
			if prevv.has(e) and v.length() > 40.0 and (prevv[e] as Vector2).length() > 40.0 and v.normalized().dot((prevv[e] as Vector2).normalized()) < 0.0:
				s["flip"] += 1
			prevv[e] = v
			(s["dirs"] as Dictionary)[e._dir] = 1
	for e in last.keys():
		if is_instance_valid(e) and e.alive:
			var s2: Dictionary = st[e.get_meta("grp")]
			s2["n"] += 1
			s2["approach"] += float(d0[e]) - e.global_position.distance_to(pl.global_position)
	for grp3 in st.keys():
		var s3: Dictionary = st[grp3]
		if int(s3["n"]) == 0 or int(s3["samples"]) == 0:
			continue
		rows.append({"niveau": tier, "biome": biome, "scen": scen, "groupe": grp3, "n": s3["n"],
			"vit": snappedf(float(s3["v"]) / float(s3["samples"]), 0.1), "immobile_pct": snappedf(100.0 * float(s3["stat"]) / float(s3["samples"]), 0.1),
			"demi_tours_par_min": snappedf(float(s3["flip"]) / float(s3["samples"]) * 3600.0, 0.1),
			"approche_px": snappedf(float(s3["approach"]) / float(s3["n"]), 1.0), "dirs": (s3["dirs"] as Dictionary).size()})

func _grp(e: Enemy) -> String:
	var k: String = e.kind
	if k.contains("_"):
		return "rang_" + k.get_slice("_", 1)
	if e.grade != "":
		return "grade_" + e.grade
	return e.behavior + ("+" + e.tir_style if e.tir_style != "" else "")
