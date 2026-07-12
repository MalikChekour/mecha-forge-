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
	var col: Color = Palette.CYAN if k == "xp" else (Palette.BONUS if k == "bonus" else Palette.ACCENT)
	_spr.texture = Tex.get_tex("res://assets/pickups/%s.png" % k, col, 24)
	var th: float = float(_spr.texture.get_height())
	if th > 0.0:
		_spr.scale = Vector2.ONE * ((26.0 if k == "bonus" else 18.0) / th)
	_light.color = col
	_light.energy = 1.0 if k == "bonus" else 0.5
	_light.texture = _spr.texture

func _physics_process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return
	var to: Vector2 = player.global_position - global_position
	var d: float = to.length()
	if d < 360.0 or GameState.overdrive_active:   # Overdrive vacuums every pickup on the map
		_homing = true
	if _homing:
		# vacuum speed stays above player speed so gems catch a fleeing player
		global_position += to.normalized() * (400.0 + (360.0 - min(d, 360.0))) * delta
	else:
		global_position.y = _base_y + sin(_t * 3.0) * 3.0
	if d < 30.0:
		if kind == "xp":
			GameState.add_xp(value)
		elif kind == "bonus":
			if player.has_method("heal"):
				player.heal(25.0)
			GameState.add_overdrive(0.18)
			GameState.add_scrap(6)
		else:
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
