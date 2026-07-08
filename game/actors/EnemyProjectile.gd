class_name EnemyProjectile
extends Area2D

var _dir: Vector2 = Vector2.ZERO
var _dmg: float = 0.0
var _speed: float = 300.0
var _life: float = 3.0

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
	collision_mask = 1 | 8 # player body (1) + cover (8) so cover blocks enemy fire
	monitoring = true
	monitorable = false
	
	body_entered.connect(_on_body_entered)
	
	# Visuals
	var cs: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = 8.0
	cs.shape = c
	add_child(cs)
	
	var spr: Sprite2D = Sprite2D.new()
	spr.centered = true
	spr.texture = Tex.glow(Color(1.0, 0.45, 0.2), 36)
	spr.modulate = Color(2.0, 1.2, 0.5) # Additive feel via HDR modulate
	add_child(spr)
	
	var light: PointLight2D = PointLight2D.new()
	light.color = Color(1.0, 0.45, 0.2)
	light.energy = 1.5
	light.texture_scale = 0.5
	add_child(light)
	
	# Trail
	_trail = Line2D.new()
	_trail.width = 4.0
	_trail.default_color = Color(1.0, 0.45, 0.2, 0.8)
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)

func _physics_process(delta: float) -> void:
	global_position += _dir * _speed * delta
	
	# Update trail
	var local_pos: Vector2 = Vector2.ZERO
	_trail_points.push_front(local_pos)
	if _trail_points.size() > 8:
		_trail_points.pop_back()
	_trail.points = PackedVector2Array(_trail_points)
	
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(_dmg)
		queue_free()
	elif body.is_in_group("cover"):
		queue_free()   # cover blocks enemy fire
