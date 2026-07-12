class_name EnemyProjectile
extends Area2D

var _dir: Vector2 = Vector2.ZERO
var _dmg: float = 0.0
var _speed: float = 300.0
var _life: float = 3.0
var tint: Color = Color(1.0, 0.55, 0.25)   # per-enemy bolt colour (set before add)

var _trail: Line2D
var _trail_points: Array[Vector2] = []

func setup(pos: Vector2, dir: Vector2, dmg: float, speed: float = 300.0) -> void:
	global_position = pos
	_dir = dir.normalized()
	_dmg = dmg
	_speed = speed
	rotation = _dir.angle()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 8
	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)

	# Core sprite
	var core: Sprite2D = Sprite2D.new()
	core.centered = true
	core.texture = Tex.glow(tint, 40)
	core.material = CanvasItemMaterial.new()
	core.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	core.scale = Vector2(1.1, 0.5)
	add_child(core)

	# Collision
	var cs: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = 8.0
	cs.shape = c
	add_child(cs)

	# Light
	var light: PointLight2D = PointLight2D.new()
	light.color = tint
	light.energy = 1.5
	light.texture_scale = 0.5
	add_child(light)

	# Trail
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = 6.0
	_trail.material = CanvasItemMaterial.new()
	_trail.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_trail.gradient = Gradient.new()
	_trail.gradient.set_color(0, Color(tint.r, tint.g, tint.b, 0.8))
	_trail.gradient.set_color(1, Color(tint.r * 0.6, tint.g * 0.4, tint.b * 0.4, 0.0))
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)

	# Muzzle flash
	var flash: Sprite2D = Sprite2D.new()
	flash.centered = true
	flash.texture = Tex.glow(tint, 40)
	flash.material = CanvasItemMaterial.new()
	flash.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.global_position = global_position
	flash.scale = Vector2(0.2, 0.2)
	add_child(flash)

	var tween: Tween = create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.5, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flash, "modulate", Color(1,1,1,0), 0.1)
	tween.tween_callback(flash.queue_free)

func _physics_process(delta: float) -> void:
	global_position += _dir * _speed * delta

	# Update trail
	_trail_points.push_front(global_position)
	if _trail_points.size() > 10:
		_trail_points.pop_back()
	_trail.points = PackedVector2Array(_trail_points)

	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		_spawn_impact()
		body.take_damage(_dmg)
		queue_free()
	elif body.is_in_group("cover"):
		_spawn_impact()
		queue_free()

func _spawn_impact() -> void:
	var impact: Sprite2D = Sprite2D.new()
	impact.centered = true
	impact.texture = Tex.glow(tint, 40)
	impact.material = CanvasItemMaterial.new()
	impact.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	impact.global_position = global_position
	impact.scale = Vector2(0.3, 0.3)
	add_child(impact)

	var tween: Tween = create_tween()
	tween.tween_property(impact, "scale", Vector2.ONE * 2.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(impact, "modulate", Color(1,1,1,0), 0.2)
	tween.tween_callback(impact.queue_free)
