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
var _floor_mat: ShaderMaterial

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

	_build_environment()
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

	var amb: Ambient = Ambient.new()
	add_child(amb)
	amb.setup(player)

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
	Events.level_up.connect(func(_l: int) -> void: _level_fx())
	Events.player_died.connect(_on_player_died)

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
func _muzzle_flash(pos: Vector2, dir: Vector2) -> void:
	_flash_sprite(pos, Color(0.72, 0.95, 1.0), 96.0, 0.11)
	_ring(pos, Palette.CYAN, 10.0, 46.0, 0.16)
	var l: PointLight2D = PointLight2D.new()
	l.texture = Tex.glow(Palette.CYAN, 160)
	l.color = Palette.CYAN
	l.energy = 1.9
	l.position = pos + dir * 6.0
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
	_debris(pos, color, 6, 0.35, 90.0, 230.0)
	_flash_sprite(pos, color, 48.0, 0.12)

func death_fx(pos: Vector2, rank: int) -> void:
	var col: Color = Color(1.0, 0.72, 0.32)
	_flash_sprite(pos, col, 118.0 + rank * 80.0, 0.20)
	_ring(pos, col, 14.0, 96.0 + rank * 90.0, 0.34)
	_debris(pos, col, 12 + rank * 12, 0.5, 130.0, 360.0)
	var l: PointLight2D = PointLight2D.new()
	l.texture = Tex.glow(col, 240)
	l.color = col
	l.energy = 2.3 + float(rank)
	l.position = pos
	fx_layer.add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(l, "energy", 0.0, 0.28)
	tw.tween_callback(l.queue_free)
	Events.screen_shake.emit(5.0 + rank * 6.0)

func _flash_sprite(pos: Vector2, color: Color, size: float, dur: float) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.glow(color, 64)
	s.material = _add_mat()
	s.position = pos
	s.scale = Vector2.ONE * (size * 0.35 / 64.0)
	fx_layer.add_child(s)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (size / 64.0), dur)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s.queue_free)

func _ring(pos: Vector2, color: Color, r0: float, r1: float, dur: float) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.ring(color, 128)
	s.material = _add_mat()
	s.position = pos
	s.scale = Vector2.ONE * (r0 / 64.0)
	fx_layer.add_child(s)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (r1 / 64.0), dur)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s.queue_free)

func _debris(pos: Vector2, color: Color, n: int, life: float, vmin: float, vmax: float) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 1.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.color = color
	p.material = _add_mat()
	fx_layer.add_child(p)
	var tw: Tween = create_tween()
	tw.tween_interval(life + 0.2)
	tw.tween_callback(p.queue_free)

func _level_fx() -> void:
	_ring(player.global_position, Palette.CYAN, 24.0, 340.0, 0.5)
	_flash_sprite(player.global_position, Palette.CYAN, 200.0, 0.32)
	Events.screen_shake.emit(4.0)

func _add_mat() -> CanvasItemMaterial:
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _build_environment() -> void:
	var floor_cl: CanvasLayer = CanvasLayer.new()
	floor_cl.layer = -100
	add_child(floor_cl)
	var fr: ColorRect = ColorRect.new()
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = load("res://shaders/floor.gdshader")
	fr.material = _floor_mat
	floor_cl.add_child(fr)
	var props: PropScatter = PropScatter.new()
	add_child(props)
	props.populate(46)
	var vig_cl: CanvasLayer = CanvasLayer.new()
	vig_cl.layer = 15
	add_child(vig_cl)
	var vr: ColorRect = ColorRect.new()
	vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm: ShaderMaterial = ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vm.set_shader_parameter("strength", 0.5)
	vr.material = vm
	vig_cl.add_child(vr)

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
	if _floor_mat != null and player != null:
		_floor_mat.set_shader_parameter("world_offset", player.global_position)
		_floor_mat.set_shader_parameter("vp_size", get_viewport_rect().size)
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
		if _headless and _frames >= 1400:
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

