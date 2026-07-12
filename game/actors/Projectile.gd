extends Area2D
class_name Projectile

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var pierce: int = 0
var homing: bool = false
var aoe: float = 0.0
var bolt_color: Color = Color(0.75, 0.96, 1.0)
var life: float = 2.0
var alive: bool = true
var game: Node = null
var impact_kind: String = ""       # weapon family -> signature impact FX

var _spr: Sprite2D
var _light: PointLight2D
var _trail: Line2D
var _built: bool = false
var _turn_rate: float = 3.0

func setup(pos: Vector2, dir: Vector2, params: Dictionary) -> void:
	global_position = pos
	visible = true
	set_physics_process(true)          # reactivate if reused from the pool
	var spd: float = float(params.get("speed", 780.0))
	velocity = dir * spd
	damage = float(params.get("dmg", 10.0))
	pierce = int(params.get("pierce", 0))
	homing = bool(params.get("homing", false))
	aoe = float(params.get("aoe", 0.0))
	bolt_color = Color(params.get("color", Color(0.75, 0.96, 1.0)))
	impact_kind = String(params.get("impact", ""))
	alive = true
	life = 2.0
	rotation = dir.angle()
	collision_layer = 0
	collision_mask = 2 | 8
	monitoring = true
	monitorable = false
	if not _built:
		_built = true
		var cs: CollisionShape2D = CollisionShape2D.new()
		var c: CircleShape2D = CircleShape2D.new()
		c.radius = 9.0
		cs.shape = c
		add_child(cs)
		var add: CanvasItemMaterial = CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_spr = Sprite2D.new()
		_spr.texture = Tex.glow(Color(0.75, 0.96, 1.0), 44)
		_spr.material = add
		_spr.scale = Vector2(1.0, 0.42)
		add_child(_spr)
		_light = PointLight2D.new()
		_light.texture = Tex.glow(Palette.CYAN, 128)
		_light.color = Palette.CYAN
		_light.energy = 0.95
		add_child(_light)
		_trail = Line2D.new()
		_trail.top_level = true
		_trail.width = 11.0
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0.3, 0.85, 1.0, 0.0))
		g.set_color(1, Color(0.8, 0.97, 1.0, 0.7))
		_trail.gradient = g
		var tm: CanvasItemMaterial = CanvasItemMaterial.new()
		tm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_trail.material = tm
		add_child(_trail)
		area_entered.connect(_on_hit)
		body_entered.connect(_on_body)
	
	_spr.texture = Tex.glow(bolt_color, 44)
	_light.texture = Tex.glow(bolt_color, 128)
	_light.color = bolt_color
	var g2: Gradient = Gradient.new()
	g2.set_color(0, Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.0))
	g2.set_color(1, Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.7))
	_trail.gradient = g2
	_trail.clear_points()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if homing:
		var tgt: Node2D = _find_nearest_enemy()
		if tgt != null and is_instance_valid(tgt):
			var cur_ang: float = velocity.angle()
			var des_ang: float = global_position.angle_to_point(tgt.global_position)
			var diff: float = wrapf(des_ang - cur_ang, -PI, PI)
			var max_turn: float = _turn_rate * delta
			if abs(diff) <= max_turn:
				cur_ang = des_ang
			else:
				cur_ang += signf(diff) * max_turn
			var spd2: float = velocity.length()
			velocity = Vector2.from_angle(cur_ang) * spd2
			rotation = cur_ang
	global_position += velocity * delta
	_trail.add_point(global_position)
	while _trail.get_point_count() > 9:
		_trail.remove_point(0)
	life -= delta
	if life <= 0.0:
		_recycle()

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d: float = 99999999.0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e is Node2D and is_instance_valid(e):
			var d: float = global_position.distance_squared_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

func _on_hit(area: Area2D) -> void:
	if not alive:
		return
	if area is Enemy and (area as Enemy).alive:
		if aoe > 0.0:
			_do_splash()
		else:
			(area as Enemy).take_damage(damage)
			Events.damage_dealt.emit(global_position, int(damage), false)
		if game != null and game.has_method("impact_fx"):
			game.impact_fx(global_position, bolt_color, impact_kind)
		else:
			Events.hit_spark.emit(global_position, bolt_color)
		if pierce <= 0:
			_recycle()
		else:
			pierce -= 1

func _do_splash() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var aoe_sq: float = aoe * aoe
	for e in enemies:
		if e is Enemy and is_instance_valid(e) and (e as Enemy).alive:
			var d: float = global_position.distance_squared_to((e as Node2D).global_position)
			if d <= aoe_sq:
				(e as Enemy).take_damage(damage)
				Events.damage_dealt.emit((e as Node2D).global_position, int(damage), false)

func _on_body(body: Node) -> void:
	if not alive:
		return
	if body.is_in_group("cover") and body.has_method("take_damage"):
		body.take_damage(damage)
		Events.hit_spark.emit(global_position, Palette.ACCENT)
		_recycle()

func _recycle() -> void:
	alive = false
	if game != null and game.has_method("reclaim_proj"):
		game.reclaim_proj(self)
	else:
		queue_free()

# Park far off-screen + stop processing (monitoring stays on -> no signal-time toggle,
# and nothing overlaps way out there). Reused via setup().
func deactivate() -> void:
	set_physics_process(false)
	visible = false
	global_position = Vector2(1.0e7, 1.0e7)
	if _trail != null:
		_trail.clear_points()
