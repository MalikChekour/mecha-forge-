extends Area2D
class_name Enemy

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

# Movement internals
var velocity: Vector2 = Vector2.ZERO
var _speed_mult: float = 1.0
var _wander_phase: float = 0.0

# Tuning constants
const _ACCEL: float = 700.0
const _SEP_RADIUS: float = 50.0
const _SEP_FORCE: float = 200.0
const _WANDER_STR: float = 35.0

func setup(k: String, def: Dictionary, plr: Node2D, g: Node) -> void:
	kind = k
	player = plr
	game = g
	hp = float(def.get("hp", 20.0))
	speed = float(def.get("speed", 90.0))
	contact_dmg = float(def.get("dmg", 8.0))
	rank = int(def.get("rank", 0))
	
	# Initialize per-enemy variety
	_speed_mult = randf_range(0.85, 1.15)
	_wander_phase = randf() * TAU
	velocity = Vector2.ZERO
	
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
		
	var desired_vel: Vector2 = Vector2.ZERO
	var player_valid: bool = player != null and is_instance_valid(player) and GameState.alive
	
	if player_valid:
		var to_player: Vector2 = player.global_position - global_position
		var dist_sq: float = to_player.length_squared()
		var dist: float = sqrt(dist_sq)
		
		if dist > 1.0:
			var dir: Vector2 = to_player / dist
			
			# 1. Base Seek Velocity
			desired_vel = dir * speed * _speed_mult
			
			# 2. Separation (Anti-stacking)
			var separation: Vector2 = Vector2.ZERO
			var count: int = 0
			var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
			var sep_rad_sq: float = _SEP_RADIUS * _SEP_RADIUS
			
			for e: Node in enemies:
				if count >= 10:
					break
				count += 1
				
				if e == self or not (e is Enemy) or not e.alive:
					continue
				
				var to_other: Vector2 = global_position - e.global_position
				var d2: float = to_other.length_squared()
				
				# Avoid sqrt for cheap check; use squared ratio for weight
				if d2 > 0.0 and d2 < sep_rad_sq:
					var push: Vector2 = to_other.normalized()
					var weight: float = 1.0 - (d2 / sep_rad_sq)
					separation += push * weight
			
			if separation != Vector2.ZERO:
				desired_vel += separation * _SEP_FORCE

			# 3. Wander (Sine offset)
			var time_sec: float = Time.get_ticks_msec() / 1000.0
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			desired_vel += perp * sin(time_sec * 3.0 + _wander_phase) * _WANDER_STR

		# Contact Damage
		_contact_cd -= delta
		if dist < 44.0 and _contact_cd <= 0.0:
			_contact_cd = 0.5
			if player.has_method("take_damage"):
				player.take_damage(contact_dmg)
	else:
		# Friction if no target
		desired_vel = Vector2.ZERO

	# Steering Physics
	velocity = velocity.move_toward(desired_vel, _ACCEL * delta)
	global_position += velocity * delta
	
	# Orientation
	if abs(velocity.x) > 2.0:
		_spr.flip_h = velocity.x < 0.0

	# Animation (Speed Driven)
	if _frames > 1:
		var current_speed: float = velocity.length()
		var max_speed: float = speed * _speed_mult
		var speed_factor: float = (current_speed / max_speed) if max_speed > 0 else 0.0
		# Keep minimum subtle movement for "alive" feel when idle
		speed_factor = maxf(0.1, speed_factor)
		_t += delta * _fps * speed_factor
		_spr.frame = int(_t) % _frames

	# Hit Flash Decay
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		if _mat != null and _mat.shader != null:
			_mat.set_shader_parameter("flash", _flash)

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	_flash = 1.0
	if _mat != null and _mat.shader != null:
		_mat.set_shader_parameter("flash", 1.0)
	Events.hit_spark.emit(global_position, Palette.CYAN)
	if hp <= 0.0:
		alive = false
		remove_from_group("enemies")     # synchronous — safe inside a signal
		call_deferred("_die")

func _die() -> void:
	GameState.add_kill(global_position, rank)
	if game != null:
		if game.has_method("death_fx"):
			game.death_fx(global_position, rank)
		if game.has_method("spawn_xp"):
			game.spawn_xp(global_position, 1 + rank)
	queue_free()
