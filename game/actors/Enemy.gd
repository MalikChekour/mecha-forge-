extends Area2D
class_name Enemy
## Enemy = Meshy sprite (animated sheet if it has one) that chases the player and
## deals contact damage. Takes projectile hits (hit-flash), and on death defers the
## loot/free so we never toggle physics state inside an area signal (the notorious
## Godot Area2D crash). collision_layer 2 = "enemies"; projectiles mask this.

var game: Node
var player: Node2D
var kind: String = "crawler"
var hp: float = 20.0
var speed: float = 90.0
var contact_dmg: float = 8.0
var rank: int = 0
var alive: bool = true

var _spr: Sprite2D
var _mat: ShaderMaterial
var _frames: int = 1
var _fps: float = 8.0
var _t: float = 0.0
var _flash: float = 0.0
var _contact_cd: float = 0.0

func setup(k: String, def: Dictionary, plr: Node2D, g: Node) -> void:
	kind = k
	player = plr
	game = g
	hp = float(def.get("hp", 20.0))
	speed = float(def.get("speed", 90.0))
	contact_dmg = float(def.get("dmg", 8.0))
	rank = int(def.get("rank", 0))
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = float(def.get("radius", 24.0))
	cs.shape = c
	add_child(cs)

	_spr = Sprite2D.new()
	_spr.centered = true
	var motion: String = String(def.get("motion", ""))
	var tex: Texture2D = null
	if motion != "":
		var sheet: String = "res://assets/enemies/%s_%s.png" % [kind, motion]
		if ResourceLoader.exists(sheet):
			var r: Variant = load(sheet)
			if r is Texture2D:
				tex = r
				_frames = 8
				_spr.hframes = 8
	if tex == null:
		tex = Tex.get_tex("res://assets/enemies/%s.png" % kind, Palette.STEEL_DK, 160)
	_spr.texture = tex
	var fh: float = float(tex.get_height())
	if fh > 0.0:
		_spr.scale = Vector2.ONE * (float(def.get("size", 92.0)) / fh)
	_mat = ShaderMaterial.new()
	if ResourceLoader.exists("res://shaders/hit_flash.gdshader"):
		_mat.shader = load("res://shaders/hit_flash.gdshader")
		_spr.material = _mat
	add_child(_spr)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if player != null and is_instance_valid(player) and GameState.alive:
		var to: Vector2 = player.global_position - global_position
		var d: float = to.length()
		if d > 1.0:
			global_position += (to / d) * speed * delta
		# face movement by horizontal flip
		if abs(to.x) > 2.0:
			_spr.flip_h = to.x < 0.0
		_contact_cd -= delta
		if d < 44.0 and _contact_cd <= 0.0:
			_contact_cd = 0.5
			if player.has_method("take_damage"):
				player.take_damage(contact_dmg)
	if _frames > 1:
		_t += delta * _fps
		_spr.frame = int(_t) % _frames
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		if _mat.shader != null:
			_mat.set_shader_parameter("flash", _flash)

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	_flash = 1.0
	if _mat.shader != null:
		_mat.set_shader_parameter("flash", 1.0)
	Events.hit_spark.emit(global_position, Palette.CYAN)
	if hp <= 0.0:
		alive = false
		remove_from_group("enemies")     # synchronous — safe inside a signal
		call_deferred("_die")

func _die() -> void:
	GameState.add_kill(global_position, rank)
	if game != null and game.has_method("spawn_xp"):
		game.spawn_xp(global_position, 1 + rank)
	queue_free()
