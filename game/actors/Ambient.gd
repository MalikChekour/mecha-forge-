class_name Ambient
extends Node2D

var _target: Node2D = null

var _dust: CPUParticles2D
var _embers: CPUParticles2D
var _shaft0: Sprite2D
var _shaft1: Sprite2D
var _shaft2: Sprite2D

var _time: float = 0.0
var _shaft_base0: float = 0.0
var _shaft_base1: float = 0.0
var _shaft_base2: float = 0.0

var current_biome: String = "tech"

func setup(target: Node2D) -> void:
	_target = target

func _ready() -> void:
	z_index = 6
	_build_dust()
	_build_embers()
	_build_light_shafts()
	apply_biome(current_biome)

func apply_biome(biome_name: String) -> void:
	current_biome = biome_name
	if _dust == null or _embers == null or _shaft0 == null:
		return
	match biome_name:
		"tech":
			_dust.color = Color(0.2, 0.85, 1.0, 0.18)
			_dust.gravity = Vector2(0, -6)
			_embers.color = Color(1.0, 0.55, 0.2, 0.35)
			_embers.amount = 26
			_set_shaft_color(Color(0.2, 0.85, 1.0))
		"desert":
			_dust.color = Color(1.0, 0.82, 0.45, 0.30)
			_dust.gravity = Vector2(-28, 6)
			_embers.color = Color(1.0, 0.9, 0.6, 0.20)
			_embers.amount = 16
			_set_shaft_color(Color(1.0, 0.75, 0.3))
		"jungle":
			_dust.color = Color(0.4, 1.0, 0.5, 0.22)
			_dust.gravity = Vector2(0, 8)
			_embers.color = Color(1.0, 0.95, 0.3, 0.40)
			_embers.amount = 32
			_set_shaft_color(Color(0.3, 0.9, 0.4))
		"volcanic":
			_dust.color = Color(0.9, 0.3, 0.1, 0.28)
			_dust.gravity = Vector2(0, -32)
			_embers.color = Color(1.0, 0.45, 0.1, 0.65)
			_embers.amount = 48
			_set_shaft_color(Color(1.0, 0.35, 0.1))
		"swamp":
			_dust.color = Color(0.4, 0.75, 0.6, 0.26)
			_dust.gravity = Vector2(6, 14)
			_embers.color = Color(0.2, 0.9, 0.8, 0.20)
			_embers.amount = 14
			_set_shaft_color(Color(0.3, 0.65, 0.6))
		"cryo", "ice":
			_dust.color = Color(0.75, 0.95, 1.0, 0.36)
			_dust.gravity = Vector2(-35, 4)
			_embers.color = Color(0.85, 0.98, 1.0, 0.32)
			_embers.amount = 26
			_set_shaft_color(Color(0.4, 0.85, 1.0))
		"reacteur":
			_dust.color = Color(0.3, 1.0, 0.35, 0.30)
			_dust.gravity = Vector2(0, -10)
			_embers.color = Color(0.2, 1.0, 0.6, 0.50)
			_embers.amount = 32
			_set_shaft_color(Color(0.2, 1.0, 0.4))
		"ruche":
			_dust.color = Color(0.9, 0.3, 0.85, 0.26)
			_dust.gravity = Vector2(0, -4)
			_embers.color = Color(0.8, 0.2, 1.0, 0.38)
			_embers.amount = 26
			_set_shaft_color(Color(0.8, 0.25, 0.9))
		"citadelle", "spaceship":
			_dust.color = Color(0.85, 0.85, 1.0, 0.20)
			_dust.gravity = Vector2(0, 0)
			_embers.color = Color(1.0, 0.85, 0.4, 0.32)
			_embers.amount = 20
			_set_shaft_color(Color(0.5, 0.85, 1.0))
		"abyss":
			_dust.color = Color(0.2, 0.7, 0.95, 0.25)
			_dust.gravity = Vector2(0, -12)
			_embers.color = Color(0.1, 0.9, 0.8, 0.35)
			_embers.amount = 24
			_set_shaft_color(Color(0.15, 0.75, 0.95))
		"ether":
			_dust.color = Color(0.7, 0.3, 0.9, 0.26)
			_dust.gravity = Vector2(4, -8)
			_embers.color = Color(0.9, 0.4, 1.0, 0.45)
			_embers.amount = 30
			_set_shaft_color(Color(0.75, 0.35, 0.95))
		"titans":
			_dust.color = Color(0.85, 0.65, 0.4, 0.30)
			_dust.gravity = Vector2(-20, 4)
			_embers.color = Color(1.0, 0.5, 0.2, 0.30)
			_embers.amount = 18
			_set_shaft_color(Color(0.9, 0.65, 0.35))
		"orbit":
			_dust.color = Color(0.6, 0.8, 1.0, 0.16)
			_dust.gravity = Vector2(0, 0)
			_embers.color = Color(0.4, 0.85, 1.0, 0.25)
			_embers.amount = 14
			_set_shaft_color(Color(0.4, 0.8, 1.0))
		"quantum":
			_dust.color = Color(1.0, 0.9, 0.4, 0.22)
			_dust.gravity = Vector2(0, -15)
			_embers.color = Color(1.0, 0.8, 0.2, 0.40)
			_embers.amount = 24
			_set_shaft_color(Color(1.0, 0.85, 0.3))
		"ozone":
			_dust.color = Color(0.8, 0.5, 1.0, 0.25)
			_dust.gravity = Vector2(-15, -10)
			_embers.color = Color(0.85, 0.6, 1.0, 0.50)
			_embers.amount = 36
			_set_shaft_color(Color(0.75, 0.45, 1.0))
		"prism":
			_dust.color = Color(0.5, 0.9, 1.0, 0.25)
			_dust.gravity = Vector2(0, -6)
			_embers.color = Color(0.6, 0.95, 0.9, 0.35)
			_embers.amount = 22
			_set_shaft_color(Color(0.5, 0.9, 1.0))
		"steampunk":
			_dust.color = Color(0.9, 0.75, 0.55, 0.32)
			_dust.gravity = Vector2(10, -22)
			_embers.color = Color(1.0, 0.6, 0.2, 0.45)
			_embers.amount = 34
			_set_shaft_color(Color(1.0, 0.7, 0.35))
		"colosseum":
			_dust.color = Color(0.5, 0.85, 1.0, 0.18)
			_dust.gravity = Vector2(0, -8)
			_embers.color = Color(0.3, 0.9, 1.0, 0.30)
			_embers.amount = 20
			_set_shaft_color(Color(0.4, 0.85, 1.0))
		_:
			_dust.color = Color(0.7, 0.8, 1.0, 0.15)
			_embers.color = Color(1.0, 0.55, 0.2, 0.25)
			_set_shaft_color(Color(0.4, 0.7, 1.0))

func _set_shaft_color(c: Color) -> void:
	if _shaft0 != null: _shaft0.modulate = Color(c.r, c.g, c.b, 0.07)
	if _shaft1 != null: _shaft1.modulate = Color(c.r, c.g, c.b, 0.07)
	if _shaft2 != null: _shaft2.modulate = Color(c.r, c.g, c.b, 0.07)

func _process(delta: float) -> void:
	_time += delta
	var pos: Vector2 = _target.global_position if is_instance_valid(_target) else global_position
	_dust.global_position = pos
	_embers.global_position = pos
	_shaft0.global_position = pos
	_shaft1.global_position = pos
	_shaft2.global_position = pos
	_shaft0.rotation = _shaft_base0 + sin(_time * 0.2) * 0.08
	_shaft1.rotation = _shaft_base1 + sin(_time * 0.15 + 1.5) * 0.08
	_shaft2.rotation = _shaft_base2 + sin(_time * 0.18 + 3.0) * 0.08
	var drift0: float = sin(_time * 0.1) * 6.0
	var drift1: float = sin(_time * 0.12 + 2.0) * 6.0
	var drift2: float = sin(_time * 0.14 + 4.0) * 6.0
	_shaft0.position.x += drift0 * delta
	_shaft1.position.x += drift1 * delta
	_shaft2.position.x += drift2 * delta

func _make_additive_material() -> CanvasItemMaterial:
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat

func _build_dust() -> void:
	_dust = CPUParticles2D.new()
	_dust.name = "Dust"
	_dust.z_index = 6
	_dust.material = _make_additive_material()
	_dust.amount = 120
	_dust.lifetime = 6.0
	_dust.explosiveness = 0.0
	_dust.randomness = 0.5
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(760, 460)
	_dust.gravity = Vector2.ZERO
	_dust.color = Color(0.7, 0.8, 1.0, 0.15)
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 1.5
	_dust.initial_velocity_min = 2.0
	_dust.initial_velocity_max = 5.0
	_dust.direction = Vector2(1, 0)
	_dust.spread = 180.0
	_dust.angle_min = 0.0
	_dust.angle_max = 360.0
	add_child(_dust)

func _build_embers() -> void:
	_embers = CPUParticles2D.new()
	_embers.name = "Embers"
	_embers.z_index = 6
	_embers.material = _make_additive_material()
	_embers.amount = 24
	_embers.lifetime = 3.5
	_embers.explosiveness = 0.0
	_embers.randomness = 0.5
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(700, 420)
	_embers.gravity = Vector2(0, -12)
	_embers.color = Color(1.0, 0.55, 0.2, 0.25)
	_embers.scale_amount_min = 1.5
	_embers.scale_amount_max = 2.5
	_embers.initial_velocity_min = 3.0
	_embers.initial_velocity_max = 8.0
	_embers.direction = Vector2(0, -1)
	_embers.spread = 30.0
	add_child(_embers)

func _build_light_shafts() -> void:
	var tex: Texture2D = _make_glow_texture(Color(0.4, 0.7, 1.0), 128)
	
	_shaft0 = _create_shaft("LightShaft0", tex, 0.0)
	_shaft1 = _create_shaft("LightShaft1", tex, PI / 3.0)
	_shaft2 = _create_shaft("LightShaft2", tex, -PI / 4.0)
	_shaft_base0 = _shaft0.rotation
	_shaft_base1 = _shaft1.rotation
	_shaft_base2 = _shaft2.rotation

func _create_shaft(p_name: String, tex: Texture2D, base_rot: float) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.name = p_name
	s.z_index = 6
	s.texture = tex
	s.modulate = Color(1, 1, 1, 0.05)
	s.scale = Vector2(0.6, 6.0)
	s.rotation = base_rot
	s.material = _make_additive_material()
	add_child(s)
	return s

func _make_glow_texture(glow_color: Color, size: int) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size * 0.5, size * 0.5)
	var max_dist: float = center.length()
	for y: int in range(size):
		for x: int in range(size):
			var d: float = Vector2(x, y).distance_to(center)
			var t: float = clampf(1.0 - d / max_dist, 0.0, 1.0)
			var a: float = t * t
			img.set_pixel(x, y, Color(glow_color.r, glow_color.g, glow_color.b, a))
	return ImageTexture.create_from_image(img)
