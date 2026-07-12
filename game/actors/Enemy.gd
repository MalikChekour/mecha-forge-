extends Area2D
class_name Enemy

var game: Node
var player: Node2D
var kind: String = "crawler"
var hp: float = 20.0
var hp_max: float = 20.0
var speed: float = 90.0
var contact_dmg: float = 8.0
var rank: int = 0
var alive: bool = true
var is_final: bool = false       # the endboss: its death = run victory
var _hp_bg: Line2D
var _hp_fill: Line2D
var _hp_bar_w: float = 0.0
var _hp_bar_y: float = 0.0

var behavior: String = "rush"
var attack_dmg: float = 0.0
var attack_cd: float = 1.0
var prefer_dist: float = 340.0

var _spr: Sprite2D
var _mat: ShaderMaterial
var _frames: int = 1
var _fps: float = 14.0
var _t: float = 0.0
var _flash: float = 0.0
var _contact_cd: float = 0.0

# Energy shield (protection): absorbs damage before HP, ripples on hit, shatters when
# broken, then slowly regenerates. Only enemies with def "shield" > 0 carry one.
var shield_max: float = 0.0
var shield: float = 0.0
var _shield_spr: Sprite2D = null
var _shield_regen_t: float = 0.0
var _shield_flash: float = 0.0
var _body_radius: float = 24.0
var _bolt_color: Color = Color(1.0, 0.55, 0.25)   # per-enemy ranged-bolt colour

# Movement internals
var velocity: Vector2 = Vector2.ZERO
var _speed_mult: float = 1.0
var _wander_phase: float = 0.0

# Attack internals
var _atk_cd: float = 0.0
var _phase: int = 0
var _phase_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0

# Animation state
var _anims: Dictionary = {}          # anim -> Texture2D (single) OR {front,back,left,right}
var _cur_anim: String = ""
var _one_shot: bool = false
var _anim_done: bool = false
var _base_loop: String = ""
var _idle_anim: String = ""
var _dying: bool = false
var _die_timer: float = 0.0
var _dir: String = "front"           # facing, chosen from movement like the player mecha
var _directional: bool = false       # true once any anim has 4-view sheets
const _DIRS: Array[String] = ["front", "back", "left", "right"]

# Tuning constants
const _ACCEL: float = 700.0
const _SEP_RADIUS: float = 50.0
const _SEP_FORCE: float = 200.0
const _WANDER_STR: float = 9.0

# Dasher phases
const _PH_DASH_WIND: int = 0
const _PH_DASH_ACTIVE: int = 1
const _PH_DASH_COOLDOWN: int = 2


func setup(k: String, def: Dictionary, plr: Node2D, g: Node) -> void:
	kind = k
	player = plr
	game = g
	hp = float(def.get("hp", 20.0))
	hp_max = hp
	speed = float(def.get("speed", 90.0))
	contact_dmg = float(def.get("dmg", 8.0))
	rank = int(def.get("rank", 0))
	is_final = bool(def.get("final", false))
	
	behavior = String(def.get("behavior", "rush"))
	attack_dmg = float(def.get("attack_dmg", 0.0))
	attack_cd = float(def.get("attack_cd", 1.0))
	prefer_dist = float(def.get("prefer_dist", 340.0))
	shield_max = float(def.get("shield", 0.0))
	shield = shield_max
	_body_radius = float(def.get("radius", 24.0))
	_bolt_color = _kind_bolt_color(k)

	_speed_mult = randf_range(0.85, 1.15)
	_wander_phase = randf() * TAU
	velocity = Vector2.ZERO
	
	_atk_cd = attack_cd
	_strafe_dir = 1.0 if randf() > 0.5 else -1.0
	
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
	
	# Auto-discover animation sheets: directional 4-view (<kind>_<anim>_<dir>.png)
	# if present, else the single front-only sheet (<kind>_<anim>.png).
	var names_to_check: Array[String] = ["idle", "walk", "attack", "hit", "die"]
	if motion != "":
		names_to_check.append(motion)
	for anim_name: String in names_to_check:
		if _anims.has(anim_name):
			continue
		var a: Variant = _load_anim(anim_name)
		if a != null:
			_anims[anim_name] = a
			if a is Dictionary:
				_directional = true

	if _anims.is_empty():
		# Fallback to default single sprite
		var tex: Texture2D = Tex.get_tex("res://assets/enemies/%s.png" % kind, Palette.STEEL_DK, 160)
		_anims["idle"] = tex
		
	# Determine loop anims
	if _anims.has("walk"):
		_base_loop = "walk"
	elif _anims.has(motion):
		_base_loop = motion
	else:
		_base_loop = _anims.keys()[0]
		
	if _anims.has("idle"):
		_idle_anim = "idle"
	else:
		_idle_anim = _base_loop
		
	play(_base_loop, false)
	
	var fh: float = float(_spr.texture.get_height())
	if fh > 0.0:
		_spr.scale = Vector2.ONE * (float(def.get("size", 92.0)) / fh)

	# ground shadow: anchors the enemy to the floor so it doesn't look like it floats on glass
	var gsize: float = float(def.get("size", 92.0))
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.position = Vector2(0.0, gsize * 0.34)
	shadow.scale = Vector2(gsize / 64.0 * 0.9, gsize / 64.0 * 0.38)
	shadow.z_index = -1
	add_child(shadow)

	_mat = ShaderMaterial.new()
	if ResourceLoader.exists("res://shaders/hit_flash.gdshader"):
		_mat.shader = load("res://shaders/hit_flash.gdshader")
		_spr.material = _mat
	add_child(_spr)

	# energy shield bubble (a cyan barrier ring) drawn in front of the body
	if shield_max > 0.0:
		_shield_spr = Sprite2D.new()
		_shield_spr.texture = Tex.ring(Palette.CYAN, 128)
		var add_mat: CanvasItemMaterial = CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shield_spr.material = add_mat
		var diam: float = _body_radius * 3.2
		_shield_spr.scale = Vector2.ONE * (diam / 128.0)
		_shield_spr.modulate = Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.4)
		_shield_spr.z_index = 3
		add_child(_shield_spr)

	# bosses (rank >= 3) get a floating health bar so the player sees the fight's progress
	if rank >= 3:
		_hp_bar_w = float(def.get("size", 92.0)) * 1.1
		_hp_bar_y = -float(def.get("size", 92.0)) * 0.62
		_hp_bg = Line2D.new()
		_hp_bg.width = 9.0
		_hp_bg.default_color = Color(0.0, 0.0, 0.0, 0.65)
		_hp_bg.points = PackedVector2Array([Vector2(-_hp_bar_w * 0.5, _hp_bar_y), Vector2(_hp_bar_w * 0.5, _hp_bar_y)])
		_hp_bg.z_index = 5
		add_child(_hp_bg)
		_hp_fill = Line2D.new()
		_hp_fill.width = 6.0
		_hp_fill.default_color = Color(1.0, 0.28, 0.22)
		_hp_fill.points = _hp_bg.points
		_hp_fill.z_index = 6
		add_child(_hp_fill)


func _kind_bolt_color(k: String) -> Color:
	# Readability rule: WARM = enemy/danger (cold hues are reserved for the player).
	match k:
		"spitter": return Color(1.0, 0.35, 0.7)    # magenta plasma
		"drone": return Color(1.0, 0.6, 0.2)       # orange
		"warden": return Color(1.0, 0.28, 0.22)    # red
		"raider": return Color(1.0, 0.72, 0.25)    # amber
		_: return Color(1.0, 0.5, 0.2)             # orange


func _load_anim(anim_name: String) -> Variant:
	# 4-view directional sheets take priority; fall back to a single front sheet.
	var dirs: Dictionary = {}
	for d: String in _DIRS:
		var p: String = "res://assets/enemies/%s_%s_%s.png" % [kind, anim_name, d]
		if ResourceLoader.exists(p):
			var r: Variant = load(p)
			if r is Texture2D:
				dirs[d] = r
	if dirs.size() == _DIRS.size():
		return dirs
	var sp: String = "res://assets/enemies/%s_%s.png" % [kind, anim_name]
	if ResourceLoader.exists(sp):
		var r2: Variant = load(sp)
		if r2 is Texture2D:
			return r2
	return null


func _current_tex() -> Texture2D:
	var a: Variant = _anims.get(_cur_anim)
	if a is Dictionary:
		return a.get(_dir, a.get("front"))
	return a


func play(name: String, one_shot: bool = false) -> void:
	if not _anims.has(name) or _cur_anim == name:
		return
	_cur_anim = name
	_spr.texture = _current_tex()
	_spr.hframes = 8
	_frames = 8
	_t = 0.0
	_one_shot = one_shot
	_anim_done = false


func _physics_process(delta: float) -> void:
	if not alive:
		if _dying:
			_die_timer -= delta
			_advance_one_shot(delta)
			if _anim_done or _die_timer <= 0.0:
				queue_free()
		return
		
	var desired_vel: Vector2 = Vector2.ZERO
	var player_valid: bool = player != null and is_instance_valid(player) and GameState.alive
	
	_atk_cd -= delta
	if _atk_cd < 0.0:
		_atk_cd = 0.0
		
	_contact_cd -= delta
	if _contact_cd < 0.0:
		_contact_cd = 0.0
		
	if player_valid:
		var to_player: Vector2 = player.global_position - global_position
		var dist_sq: float = to_player.length_squared()
		var dist: float = sqrt(dist_sq)
		
		if dist > 1.0:
			var dir: Vector2 = to_player / dist
			
			if behavior == "ranged":
				var dist_margin: float = 40.0
				if dist > prefer_dist + dist_margin:
					desired_vel = dir * speed * _speed_mult
				elif dist < prefer_dist - dist_margin:
					desired_vel = -dir * speed * _speed_mult
				else:
					_strafe_timer -= delta
					if _strafe_timer <= 0.0:
						_strafe_dir *= -1.0
						_strafe_timer = randf_range(1.0, 2.5)
					var perp: Vector2 = Vector2(-dir.y, dir.x)
					desired_vel = perp * _strafe_dir * speed * _speed_mult * 0.75
					
			elif behavior == "dasher":
				_phase_timer -= delta
				if _phase == _PH_DASH_WIND:
					desired_vel = dir * speed * 0.1
					_flash = 0.5
					if _mat != null and _mat.shader != null:
						_mat.set_shader_parameter("flash", 0.5)
					if _phase_timer <= 0.0:
						_phase = _PH_DASH_ACTIVE
						_phase_timer = 0.45
						_dash_dir = dir
						_flash = 0.0
						if _mat != null and _mat.shader != null:
							_mat.set_shader_parameter("flash", 0.0)
						play("attack", true)
				elif _phase == _PH_DASH_ACTIVE:
					desired_vel = _dash_dir * speed * 2.6
					if dist < 44.0 and _contact_cd <= 0.0:
						_contact_cd = 0.5
						if player.has_method("take_damage"):
							player.take_damage(contact_dmg)
							
					if _phase_timer <= 0.0:
						_phase = _PH_DASH_COOLDOWN
						_phase_timer = 1.2
				elif _phase == _PH_DASH_COOLDOWN:
					desired_vel = dir * speed * 0.3
					if _phase_timer <= 0.0:
						_phase = _PH_DASH_WIND
						_phase_timer = 0.5
						
			else:
				desired_vel = dir * speed * _speed_mult
				var time_sec: float = Time.get_ticks_msec() / 1000.0
				var perp_rush: Vector2 = Vector2(-dir.y, dir.x)
				desired_vel += perp_rush * sin(time_sec * 1.3 + _wander_phase) * _WANDER_STR
				
				if dist < 44.0 and _contact_cd <= 0.0:
					_contact_cd = 0.5
					if player.has_method("take_damage"):
						player.take_damage(contact_dmg)
						play("attack", true)

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
				
				if d2 > 0.0 and d2 < sep_rad_sq:
					var push: Vector2 = to_other.normalized()
					var weight: float = 1.0 - (d2 / sep_rad_sq)
					separation += push * weight
			
			if separation != Vector2.ZERO:
				desired_vel += separation * _SEP_FORCE

			if behavior == "ranged" and _atk_cd <= 0.0 and dist < prefer_dist + 100.0:
				_atk_cd = attack_cd
				if game != null and game.has_method("spawn_enemy_bolt"):
					game.spawn_enemy_bolt(global_position, dir, attack_dmg, _bolt_color)
					play("attack", true)
					
	else:
		desired_vel = Vector2.ZERO

	velocity = velocity.move_toward(desired_vel, _ACCEL * delta)
	global_position += velocity * delta
	
	if _directional:
		# Ranged foes face their target (they shoot at the player while strafing);
		# melee foes face where they move (which is toward the player anyway).
		var face_vec: Vector2 = velocity
		if behavior == "ranged" and player != null and is_instance_valid(player):
			face_vec = player.global_position - global_position
		_update_facing(face_vec)
	elif abs(velocity.x) > 2.0:
		_spr.flip_h = velocity.x < 0.0

	if _one_shot:
		_advance_one_shot(delta)
	else:
		# Movement-driven selection
		var current_speed: float = velocity.length()
		var max_speed: float = speed * _speed_mult
		if max_speed > 0.0 and current_speed > (max_speed * 0.12):
			play(_base_loop, false)
		else:
			play(_idle_anim, false)
			
		if _frames > 1:
			var speed_factor: float = (current_speed / max_speed) if max_speed > 0 else 0.0
			speed_factor = maxf(0.65, minf(1.4, speed_factor))
			_t += delta * _fps * speed_factor
			_spr.frame = int(_t) % _frames

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		if _mat != null and _mat.shader != null:
			_mat.set_shader_parameter("flash", _flash)

	_update_shield(delta)
	if _hp_fill != null:
		var frac: float = clampf(hp / maxf(1.0, hp_max), 0.0, 1.0)
		_hp_fill.points = PackedVector2Array([
			Vector2(-_hp_bar_w * 0.5, _hp_bar_y),
			Vector2(-_hp_bar_w * 0.5 + _hp_bar_w * frac, _hp_bar_y)])


func _update_shield(delta: float) -> void:
	if shield_max <= 0.0:
		return
	# regenerate after a lull without taking damage
	if _shield_regen_t > 0.0:
		_shield_regen_t -= delta
	elif shield < shield_max:
		shield = minf(shield_max, shield + shield_max * 0.22 * delta)
	if _shield_flash > 0.0:
		_shield_flash = maxf(0.0, _shield_flash - delta * 4.0)
	if _shield_spr != null:
		var on: bool = shield > 0.5
		_shield_spr.visible = on
		if on:
			var a: float = 0.30 + 0.10 * sin(_t * 4.0) + _shield_flash * 0.6
			a *= clampf(shield / maxf(1.0, shield_max), 0.35, 1.0)   # dimmer as it weakens
			_shield_spr.modulate = Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, a)


func _update_facing(v: Vector2) -> void:
	# Same mapping as the player mecha: +x right, -x left, +y (toward camera) front, -y back.
	if v.length() < 8.0:
		return
	var nd: String
	if absf(v.x) > absf(v.y):
		nd = "right" if v.x > 0.0 else "left"
	else:
		nd = "front" if v.y > 0.0 else "back"
	if nd == _dir:
		return
	_dir = nd
	if _anims.get(_cur_anim) is Dictionary:
		var f: int = _spr.frame
		_spr.texture = _current_tex()
		_spr.hframes = 8
		_spr.frame = f


func _advance_one_shot(delta: float) -> void:
	if _anim_done:
		return
	_t += delta * 12.0
	var frame_idx: int = int(_t)
	if frame_idx >= _frames:
		_anim_done = true
		_spr.frame = _frames - 1
		if _cur_anim == "attack" or _cur_anim == "hit":
			play(_base_loop, false)
	else:
		_spr.frame = frame_idx


func take_damage(amount: float) -> void:
	if not alive:
		return
	# the energy shield soaks damage first; only the overflow reaches HP
	if shield > 0.0:
		var absorbed: float = minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		_shield_flash = 1.0
		_shield_regen_t = 3.0
		if game != null and game.has_method("shield_ripple"):
			game.shield_ripple(global_position, _body_radius * 1.5, Palette.CYAN)
		if shield <= 0.0:
			shield = 0.0
			if game != null and game.has_method("shield_break"):
				game.shield_break(global_position, _body_radius * 1.7, Palette.CYAN)
		if amount <= 0.0:
			return
	hp -= amount
	_flash = 1.0
	if _mat != null and _mat.shader != null:
		_mat.set_shader_parameter("flash", 1.0)
	Events.hit_spark.emit(global_position, Palette.CYAN)
	if hp <= 0.0:
		alive = false
		remove_from_group("enemies")
		call_deferred("_die")
	else:
		play("hit", true)


func _die() -> void:
	if _dying:
		return
	_dying = true
	alive = false
	remove_from_group("enemies")
	set_deferred("monitorable", false)
	if _hp_bg != null:
		_hp_bg.visible = false
	if _hp_fill != null:
		_hp_fill.visible = false
	GameState.add_kill(global_position, rank)
	if game != null:
		if game.has_method("death_fx"):
			game.death_fx(global_position, rank)
		if game.has_method("spawn_xp"):
			game.spawn_xp(global_position, 1 + rank)
	if is_final:
		Events.run_won.emit()   # the endboss is down -> victory
	if _anims.has("die"):
		play("die", true)
		_die_timer = 0.7
	else:
		queue_free()
