extends Area2D
class_name Pickup
## XP gem / scrap drop. Bobs in place until the player is near, then vacuums in
## (magnet). No physics signals — proximity handled by distance so nothing can
## crash inside area callbacks.

var kind: String = "xp"
var value: int = 1
var player: Node2D

var _spr: Sprite2D
var _t: float = 0.0
var _base_y: float = 0.0
var _homing: bool = false

func setup(pos: Vector2, k: String, val: int, plr: Node2D) -> void:
	global_position = pos
	_base_y = pos.y
	kind = k
	value = val
	player = plr
	monitoring = false
	monitorable = false
	add_to_group("pickups")
	if _spr == null:
		_spr = Sprite2D.new()
		var col: Color = Palette.CYAN if k == "xp" else Palette.ACCENT
		_spr.texture = Tex.get_tex("res://assets/pickups/%s.png" % k, col, 24)
		var th: float = float(_spr.texture.get_height())
		if th > 0.0:
			_spr.scale = Vector2.ONE * (18.0 / th)
		add_child(_spr)
		var light: PointLight2D = PointLight2D.new()
		light.color = (Palette.CYAN if k == "xp" else Palette.ACCENT)
		light.energy = 0.5
		light.texture = _spr.texture
		add_child(light)

func _physics_process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return
	var to: Vector2 = player.global_position - global_position
	var d: float = to.length()
	if d < 360.0:
		_homing = true
	if _homing:
		# vacuum speed stays above player speed so gems catch a fleeing player
		global_position += to.normalized() * (400.0 + (360.0 - min(d, 360.0))) * delta
	else:
		global_position.y = _base_y + sin(_t * 3.0) * 3.0
	if d < 30.0:
		if kind == "xp":
			GameState.add_xp(value)
		else:
			GameState.add_scrap(value)
		queue_free()
