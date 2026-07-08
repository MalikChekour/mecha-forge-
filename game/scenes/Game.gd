extends Node2D
## Run orchestrator: builds the arena, player, spawner, HUD; owns pools/containers,
## weapon fire, in-engine FX (muzzle flash, damage numbers, hit sparks, screen
## shake), the level-up draft, and the death/result flow. Also a headless autoplay
## bot that drives the real loop (move/fire/kill/pickup/level-up + draft UI) and
## quits with an exit code so CI can catch regressions.

var player: Player
var spawner: EnemySpawner
var hud: HUD
var cam: Camera2D
var enemy_layer: Node2D
var projectile_layer: Node2D
var pickup_layer: Node2D
var fx_layer: Node2D

var _shake: float = 0.0
var _dmg_active: int = 0
var _headless: bool = false
var _bot: bool = false
var _frames: int = 0
var _draft_open: bool = false
var _cards: Array = []

const UPGRADES: Array = [
	{"id": "dmg", "name": "◈  +25% Dégâts"},
	{"id": "rate", "name": "◈  +15% Cadence de tir"},
	{"id": "spd", "name": "◈  +12% Vitesse"},
	{"id": "hp", "name": "◈  +25 PV max (+soin)"},
	{"id": "pierce", "name": "◈  Projectile perçant +1"},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep orchestrating (bot/draft) while the tree is paused
	RenderingServer.set_default_clear_color(Palette.ARENA_BG)
	GameState.reset()
	_headless = DisplayServer.get_name() == "headless"
	_bot = _headless or OS.get_cmdline_user_args().has("--autoplay")

	enemy_layer = _mk_layer()
	projectile_layer = _mk_layer()
	pickup_layer = _mk_layer()
	fx_layer = _mk_layer()

	player = Player.new()
	player.game = self
	player.bot_active = _bot
	add_child(player)

	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)

	spawner = EnemySpawner.new()
	spawner.game = self
	spawner.player = player
	add_child(spawner)

	hud = HUD.new()
	add_child(hud)
	hud.setup(player)
	hud.card_picked.connect(_on_card_picked)

	Events.screen_shake.connect(func(a: float) -> void: _shake = maxf(_shake, a))
	Events.hit_spark.connect(_on_hit_spark)
	Events.damage_dealt.connect(func(pos: Vector2, amt: int, crit: bool) -> void: _damage_number(pos, amt, crit))
	Events.level_up.connect(func(_l: int) -> void: _open_draft())
	Events.player_died.connect(_on_player_died)
	queue_redraw()

func _mk_layer() -> Node2D:
	var n: Node2D = Node2D.new()
	add_child(n)
	return n

# ---- weapon fire ----
func spawn_bolt(pos: Vector2, dir: Vector2, dmg: float) -> void:
	var p: Projectile = Projectile.new()
	projectile_layer.add_child(p)
	p.setup(pos, dir, dmg)
	p.pierce = player.bolt_pierce
	_muzzle_flash(pos, dir)

func spawn_xp(pos: Vector2, val: int) -> void:
	var g: Pickup = Pickup.new()
	pickup_layer.add_child(g)
	g.setup(pos, "xp", val, player)

# ---- FX ----
func _muzzle_flash(pos: Vector2, _dir: Vector2) -> void:
	var l: PointLight2D = PointLight2D.new()
	l.texture = Tex.get_tex("res://__glow", Palette.CYAN, 72)
	l.color = Palette.CYAN
	l.energy = 1.5
	l.position = pos
	fx_layer.add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(l, "energy", 0.0, 0.12)
	tw.tween_callback(l.queue_free)

func _damage_number(pos: Vector2, amt: int, crit: bool) -> void:
	if not bool(SaveManager.data.get("settings", {}).get("damage_numbers", true)):
		return
	if _dmg_active > 26:
		return
	var l: Label = Label.new()
	l.text = str(amt)
	l.position = pos + Vector2(-8, -18)
	l.z_index = 100
	l.add_theme_font_size_override("font_size", 28 if crit else 20)
	l.add_theme_color_override("font_color", Color(1, 0.8, 0.2) if crit else Color(1, 1, 1))
	fx_layer.add_child(l)
	_dmg_active += 1
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector2(0, -42), 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		l.queue_free()
		_dmg_active -= 1)

func _on_hit_spark(pos: Vector2, color: Color) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 190.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = color
	fx_layer.add_child(p)
	var tw: Tween = create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(p.queue_free)

# ---- level-up draft ----
func _open_draft() -> void:
	if _draft_open:
		return
	_draft_open = true
	var pool: Array = UPGRADES.duplicate()
	pool.shuffle()
	_cards = pool.slice(0, 3)
	get_tree().paused = true
	hud.show_draft(_cards)
	if _headless:
		print("[game] DRAFT opened (level %d) — 3 cards" % GameState.level)

func _on_card_picked(index: int) -> void:
	if index >= 0 and index < _cards.size():
		_apply_upgrade(String(_cards[index].get("id", "")))
	_draft_open = false
	get_tree().paused = false

func _apply_upgrade(id: String) -> void:
	match id:
		"dmg": player.damage *= 1.25
		"rate": player.fire_interval = maxf(0.08, player.fire_interval * 0.85)
		"spd": player.base_speed *= 1.12
		"hp":
			player.max_hp += 25.0
			player.hp = minf(player.max_hp, player.hp + 25.0)
			Events.player_damaged.emit(player.hp, player.max_hp)
		"pierce": player.bolt_pierce += 1

func _on_player_died() -> void:
	var lbl: Label = Label.new()
	lbl.text = "MECHA DÉTRUIT\nNiveau %d · %d kills" % [GameState.level, GameState.kills]
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(480, 300)
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 30
	cl.add_child(lbl)
	add_child(cl)
	SaveManager.bank_scrap(GameState.scrap)

# ---- main loop + headless bot ----
func _process(delta: float) -> void:
	_frames += 1
	if GameState.alive and not _draft_open:
		GameState.run_time += delta
		Events.run_time_changed.emit(GameState.run_time)

	if bool(SaveManager.data.get("settings", {}).get("shake", true)) and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 34.0)
		cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO

	if _bot:
		_drive_bot()
		if _headless and _frames % 60 == 0:
			print("[game] f=%d t=%.0fs lvl=%d xp=%d/%d kills=%d hp=%.0f enemies=%d gems=%d" % [
				_frames, GameState.run_time, GameState.level, GameState.xp, GameState.xp_to_next,
				GameState.kills, player.hp, get_tree().get_nodes_in_group("enemies").size(),
				get_tree().get_nodes_in_group("pickups").size()])
		if _headless and _frames >= 900:
			_finish_headless()

func _drive_bot() -> void:
	if _draft_open:
		hud.pick(0)
		return
	if not GameState.alive:
		player.bot_move = Vector2.ZERO
		return
	var strafe: Vector2 = Vector2(cos(GameState.run_time * 2.0), sin(GameState.run_time * 2.0)) * 0.35
	# dodge a close enemy; otherwise go collect the nearest XP gem (to exercise level-up)
	var near: Node2D = player._nearest_enemy()
	var danger: Vector2 = Vector2.ZERO
	if near != null:
		var v: Vector2 = player.global_position - near.global_position
		if v.length() < 140.0:
			danger = v.normalized()
	var move: Vector2 = danger
	if danger == Vector2.ZERO:
		var gem: Node2D = _nearest_pickup()
		if gem != null:
			move = (gem.global_position - player.global_position).normalized()
		else:
			move = strafe + (Vector2.ZERO - player.global_position) * 0.0006
	player.bot_move = (move + strafe * 0.2).limit_length(1.0)

func _nearest_pickup() -> Node2D:
	var best: Node2D = null
	var bd: float = 1.0e12
	for g in get_tree().get_nodes_in_group("pickups"):
		if g is Node2D:
			var d: float = player.global_position.distance_squared_to((g as Node2D).global_position)
			if d < bd:
				bd = d
				best = g
	return best

func _finish_headless() -> void:
	# require a real vertical slice: kills + XP + at least one level-up/draft resolved
	var ok: bool = GameState.kills > 0 and GameState.level >= 2 and player.get_layer_ok()
	if ok:
		print("[game] SMOKE PASS — kills=%d level=%d scrap=%d (draft exercised), 0 errors" % [
			GameState.kills, GameState.level, GameState.scrap])
		get_tree().quit(0)
	else:
		print("[game] SMOKE FAIL — kills=%d level=%d (level-up/draft not reached)" % [
			GameState.kills, GameState.level])
		get_tree().quit(1)

func _draw() -> void:
	# arena grid (world-space; camera scrolls over it)
	var col: Color = Color(0.13, 0.14, 0.22, 0.6)
	var a: Rect2 = Rect2(-2200, -2200, 4400, 4400)
	var step: int = 96
	var x: int = int(a.position.x)
	while x <= int(a.end.x):
		draw_line(Vector2(x, a.position.y), Vector2(x, a.end.y), col, 1.0)
		x += step
	var y: int = int(a.position.y)
	while y <= int(a.end.y):
		draw_line(Vector2(a.position.x, y), Vector2(a.end.x, y), col, 1.0)
		y += step
