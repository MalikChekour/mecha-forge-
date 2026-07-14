extends Area2D
class_name Pickup
## XP gem / scrap / bonus drop. Bobs in place until the player is near, then vacuums in
## (magnet). No physics signals — proximity handled by distance so nothing can crash
## inside area callbacks. Pooled by Game (deactivate/reactivate instead of free).

var kind: String = "xp"
var value: int = 1
var player: Node2D
var game: Node

var _spr: Sprite2D
var _light: PointLight2D
var _t: float = 0.0
var _base_y: float = 0.0
var _homing: bool = false

func setup(pos: Vector2, k: String, val: int, plr: Node2D) -> void:
	global_position = pos
	_base_y = pos.y
	kind = k
	value = val
	player = plr
	_t = 0.0
	_homing = false
	monitoring = false
	monitorable = false
	visible = true
	set_physics_process(true)
	add_to_group("pickups")
	if _spr == null:
		_spr = Sprite2D.new()
		add_child(_spr)
		_light = PointLight2D.new()
		add_child(_light)
	# refresh appearance every time (a pooled xp gem may be reused as scrap/bonus)
	# XP gems are colour-tiered by value so the player reads a swarm-drop vs an elite-drop at a glance
	var col: Color
	if k == "xp":
		col = Color(0.45, 1.0, 0.55) if val <= 1 else (Color(0.35, 0.7, 1.0) if val == 2 else Palette.BONUS)  # green<blue<gold
	elif k == "bonus":
		col = Palette.BONUS
	elif k == "skill":
		col = Color(0.78, 0.52, 1.0)          # violet competence orb (from a broken skill-crate)
	elif k == "scrap":
		col = Palette.ACCENT
	else:
		col = Palette.CYAN
	_spr.texture = Tex.get_tex("res://assets/pickups/%s.png" % k, col, 24)
	_spr.modulate = col if k == "xp" else Color.WHITE   # tint the gem itself (texture may ignore fallback colour)
	var th: float = float(_spr.texture.get_height())
	if th > 0.0:
		_spr.scale = Vector2.ONE * ((28.0 if (k == "bonus" or k == "skill") else 18.0) / th)
	_light.color = col
	_light.energy = 1.1 if (k == "bonus" or k == "skill") else 0.5
	_light.texture = _spr.texture

func _physics_process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return
	var to: Vector2 = player.global_position - global_position
	var d: float = to.length()
	var mrange: float = float(player.magnet_range) if "magnet_range" in player else 360.0
	if d < mrange or GameState.overdrive_active:   # Overdrive vacuums every pickup on the map
		_homing = true
	if _homing:
		# vacuum speed stays above player speed so gems catch a fleeing player
		global_position += to.normalized() * (400.0 + (360.0 - min(d, 360.0))) * delta
	else:
		global_position.y = _base_y + sin(_t * 3.0) * 3.0
	if d < 30.0:
		Audio.sfx("scrap" if kind == "scrap" else "xp", 0.12)
		if kind == "xp":
			GameState.add_xp(value)
		elif kind == "skill":
			if game != null and game.has_method("grant_skill"):
				game.grant_skill()                                          # free random competence
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("levelup", player.global_position, 0.0, 1.2)  # golden burst
		elif kind == "bonus":
			if player.has_method("heal"):
				player.heal(25.0)
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("heal", player.global_position, 0.0, 1.3)   # green rising sparkles on the player
			GameState.add_overdrive(0.18)
			GameState.add_scrap(6)
		else:
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("pickup", global_position, 0.0, 0.42, Color(1.0, 0.85, 0.4))   # small sparkle on scrap
			GameState.add_scrap(value)
		_collected()

func _collected() -> void:
	if game != null and game.has_method("reclaim_pickup"):
		game.reclaim_pickup(self)
	else:
		queue_free()

func deactivate() -> void:
	set_physics_process(false)
	visible = false
	global_position = Vector2(1.0e7, 1.0e7)
	remove_from_group("pickups")
