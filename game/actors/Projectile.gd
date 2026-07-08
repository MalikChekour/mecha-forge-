extends Area2D
class_name Projectile
## Energy bolt: additive glow core + light + a fading trail. collision_mask 2 =
## detects enemies; never monitorable (nothing detects the bolt) so no physics-
## signal state toggling. Frees on hit (unless piercing) or when its life expires.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var pierce: int = 0
var life: float = 2.0
var alive: bool = true

var _spr: Sprite2D
var _light: PointLight2D
var _trail: Line2D
var _built: bool = false

func setup(pos: Vector2, dir: Vector2, dmg: float, spd: float = 780.0) -> void:
	global_position = pos
	velocity = dir * spd
	damage = dmg
	alive = true
	life = 2.0
	rotation = dir.angle()
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	if not _built:
		_built = true
		var cs: CollisionShape2D = CollisionShape2D.new()
		var c: CircleShape2D = CircleShape2D.new(); c.radius = 9.0
		cs.shape = c
		add_child(cs)
		var add: CanvasItemMaterial = CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_spr = Sprite2D.new()
		_spr.texture = Tex.glow(Color(0.75, 0.96, 1.0), 44)
		_spr.material = add
		_spr.scale = Vector2(1.0, 0.42)          # elongated along travel
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
	_trail.clear_points()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	global_position += velocity * delta
	_trail.add_point(global_position)
	while _trail.get_point_count() > 9:
		_trail.remove_point(0)
	life -= delta
	if life <= 0.0:
		_recycle()

func _on_hit(area: Area2D) -> void:
	if not alive:
		return
	if area is Enemy and (area as Enemy).alive:
		(area as Enemy).take_damage(damage)
		Events.damage_dealt.emit(global_position, int(damage), false)
		Events.hit_spark.emit(global_position, Palette.CYAN)
		if pierce <= 0:
			_recycle()
		else:
			pierce -= 1

func _recycle() -> void:
	alive = false
	queue_free()
