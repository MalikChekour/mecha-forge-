extends Node2D
## Rendu de la LINEUP des ennemis (diversite 29/10) -> PNG. Lancer SANS --headless (il faut un rendu).
class StubGame extends Node:
	var enemy_layer: Node2D = Node2D.new()
	var projectile_layer: Node2D = Node2D.new()
	var cover_list: Array = []
	var spawner: EnemySpawner = null
	func _ready() -> void:
		add_child(enemy_layer)
		add_child(projectile_layer)
	func spawn_enemy_bolt(_a, _b, _c, _d = Color.WHITE, _e = 1.0, _f = 300.0, _g = false, _h = 0.0, _i: String = "") -> void: pass
	func spawn_vfx(_k, _p, _r = 0.0, _s = 1.0, _c = Color.WHITE, _st = Vector2.ONE) -> void: pass
	func show_banner(_t: String, _c = Color.WHITE) -> void: pass

class FakePlayer extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var base_speed: float = 336.0
	var hp: float = 100.0
	var max_hp: float = 100.0
	var field_slow: float = 1.0
	func take_damage(_a, _b = Vector2.ZERO, _c: String = "") -> void: pass
	func stun(_d: float) -> void: pass

var ROWS: Array = [[1, 1], [7, 2], [16, 3]]   # [chapitre, difficulte] ; surcharge : -- out.png 4:1,10:1,13:1
const DIFF_N: Array = ["Facile", "Normal", "Difficile", "Veteran"]
const COLS: Array = ["", "_swarm", "_shield", "_sniper", "_artillery", "_kami", "_summoner", "_repair", "_elite", "MK2", "INTER"]
const COL_N: Array = ["Fantassin", "Essaim", "Bouclier", "Sniper", "Artilleur", "Kamikaze", "Invocateur", "Reparateur", "Elite", "Mk2", "Intermediaire"]

func _lab(t: String, pos: Vector2, size: int, col: Color) -> void:
	var l: Label = Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 20
	add_child(l)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.16, 0.17, 0.19))
	var ua: PackedStringArray = OS.get_cmdline_user_args()
	if ua.size() > 1:
		ROWS = []
		for r in ua[1].split(","):
			ROWS.append([int(r.get_slice(":", 0)), int(r.get_slice(":", 1))])
	GameState.reset()
	GameState.alive = true
	var g: StubGame = StubGame.new()
	add_child(g)
	await get_tree().process_frame
	var pl: FakePlayer = FakePlayer.new()
	pl.position = Vector2(-5000, -5000)
	add_child(pl)
	var sp: EnemySpawner = EnemySpawner.new()
	sp.game = g
	sp.player = pl
	g.spawner = sp
	add_child(sp)
	sp.set_process(false)
	sp._ensure_phase2()
	var dx: float = 150.0
	var dy: float = 230.0
	var x0: float = 120.0
	var y0: float = 150.0
	for ci in COLS.size():
		_lab(String(COL_N[ci]), Vector2(x0 + dx * ci - 60.0, 18.0), 17, Color(1.0, 0.95, 0.75))
	for ri in ROWS.size():
		var ch: int = int(ROWS[ri][0])
		var d: int = int(ROWS[ri][1])
		EnemyDiv.diff_override = d
		sp.current_biome = EnemyDiv.BIOMES[ch - 1]
		var t: int = sp._sync_div()
		var base: String = "mech%02d" % ch
		var y: float = y0 + dy * ri + 40.0
		_lab("Ch%d %s - %s - palier %d" % [ch, sp.current_biome, DIFF_N[d], t], Vector2(10.0, y - 128.0), 15, Color(0.7, 0.9, 1.0))
		for ci in COLS.size():
			var e: Enemy = null
			var c: String = String(COLS[ci])
			if c == "MK2" or c == "INTER":
				var dd: Dictionary = sp._tier_def(c.to_lower())
				e = Enemy.new()
				g.enemy_layer.add_child(e)
				e.setup(base + "_" + c.to_lower(), dd, pl, g)
			else:
				e = sp.spawn_kind_at(base + c, Vector2.ZERO)
			if e == null:
				continue
			e.global_position = Vector2(x0 + dx * ci, y)
			e._dir = "front"
			e.set_physics_process(false)
			e.set_process(false)
			if e.has_method("play"):
				e.play(e._base_loop, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/Users/Administrator/mecha-forge/qa_div/lineup.png"
	img.save_png(out)
	print("LINEUP saved ", out, " ", img.get_size())
	get_tree().quit()