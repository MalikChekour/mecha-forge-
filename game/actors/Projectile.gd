extends Area2D
class_name Projectile
## Bolt fired by the player. collision_mask 2 = detects enemies; never monitorable
## (nothing detects the bolt), so no physics-signal state toggling. Frees on hit
## (unless piercing) or when its life expires.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var pierce: int = 0
var life: float = 2.0
var alive: bool = true

var _spr: Sprite2D
var _light: PointLight2D
var _built: bool = false

func setup(pos: Vector2, dir: Vector2, dmg: float, spd: float = 760.0) -> void:
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
		_spr = Sprite2D.new()
		_spr.texture = Tex.get_tex("res://assets/weapons/bolt.png", Palette.ACCENT, 20)
		var th: float = float(_spr.texture.get_height())
		if th > 0.0:
			_spr.scale = Vector2.ONE * (20.0 / th)
		add_child(_spr)
		_light = PointLight2D.new()
		_light.color = Palette.CYAN
		_light.energy = 0.7
		_light.texture = _spr.texture
		add_child(_light)
		area_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		_recycle()

func _on_hit(area: Area2D) -> void:
	if not alive:
		return
	if area is Enemy and (area as Enemy).alive:
		(area as Enemy).take_damage(damage)
		Events.damage_dealt.emit(global_position, int(damage), false)
		if pierce <= 0:
			_recycle()
		else:
			pierce -= 1

func _recycle() -> void:
	alive = false
	queue_free()
