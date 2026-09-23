extends Node2D
class_name GroundZone
## Zone d'impact TELEGRAPHIEE au sol (facon Survivor.io) : un cercle rouge apparait, pulse/grossit
## pendant `delay` secondes (le joueur a le temps d'en sortir), puis EXPLOSE = degats AoE si le
## joueur est dedans. Se detruit apres l'explosion.

var radius: float = 100.0
var delay: float = 0.95
var damage: float = 20.0
var color: Color = Color(1.0, 0.45, 0.12)
var game: Node = null
var player: Node2D = null

const MISSILE_TEX: Texture2D = preload("res://assets/weapons/missile_boss.png")   # bombe/ogive Gemini

var _t: float = 0.0
var _exploded: bool = false
var _ring: Sprite2D
var _fill: Sprite2D
# OGIVE qui TOMBE sur la zone (materialise le tir boss + trainee de fumee en particules)
var _missile: Sprite2D
var _smoke_ps: CPUParticles2D
var _off: Vector2 = Vector2.ZERO
var _mscale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE   # se fige avec le draft (le parent Game tourne en ALWAYS)
	z_index = -2                                 # au SOL, sous les ennemis
	var d: float = radius * 2.0 / 128.0
	_fill = Sprite2D.new()
	_fill.texture = Tex.glow(color, 128)
	_fill.scale = Vector2.ONE * d
	_fill.modulate = Color(color.r, color.g, color.b, 0.10)
	add_child(_fill)
	_ring = Sprite2D.new()
	_ring.texture = Tex.ring(color, 128)
	_ring.scale = Vector2.ONE * d
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ring.material = m
	_ring.modulate = Color(color.r, color.g, color.b, 0.7)
	add_child(_ring)
	# --- OGIVE entrante : part d'en haut (leger biais) et fond sur la zone ---
	if radius < 100.0:
		return   # petites zones (barrage/anneau) : pas de missile+particules -> evite le pic de latence
	var a: float = deg_to_rad(-96.0 + randf_range(-22.0, 22.0))   # arrive du haut
	_off = Vector2(cos(a), sin(a)) * (radius * 2.2 + 300.0)
	_mscale = clampf(radius / 95.0, 0.7, 1.35) * 0.42
	_missile = Sprite2D.new(); _missile.texture = MISSILE_TEX; _missile.top_level = true; _missile.z_index = 41
	_missile.rotation = (-_off).angle()          # pointe dans le sens de chute (vers la zone)
	add_child(_missile)
	# trainee de FUMEE en particules, emise vers l'arriere (le haut, d'ou vient l'ogive)
	_smoke_ps = CPUParticles2D.new()
	_smoke_ps.texture = Tex.glow(Color(1, 1, 1), 48)
	_smoke_ps.local_coords = false; _smoke_ps.z_index = 40
	_smoke_ps.amount = 14; _smoke_ps.lifetime = 0.5; _smoke_ps.lifetime_randomness = 0.35
	_smoke_ps.direction = Vector2(-1, 0); _smoke_ps.spread = 12.0    # -X local = arriere du missile
	_smoke_ps.initial_velocity_min = 10.0; _smoke_ps.initial_velocity_max = 40.0
	_smoke_ps.damping_min = 18.0; _smoke_ps.damping_max = 38.0; _smoke_ps.gravity = Vector2.ZERO
	_smoke_ps.scale_amount_min = 0.22 * _mscale / 0.42; _smoke_ps.scale_amount_max = 0.4 * _mscale / 0.42
	var cur: Curve = Curve.new(); cur.add_point(Vector2(0.0, 0.4)); cur.add_point(Vector2(1.0, 1.5))
	_smoke_ps.scale_amount_curve = cur
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.9, 0.9, 0.94, 0.55)); ramp.set_color(1, Color(0.52, 0.52, 0.58, 0.0))
	_smoke_ps.color_ramp = ramp
	_missile.add_child(_smoke_ps)                # suit le missile + herite de sa rotation

func _process(delta: float) -> void:
	if GameState != null and not GameState.alive:
		return
	_t += delta
	var p: float = clampf(_t / delay, 0.0, 1.0)
	# telegraph : le liseré pulse de plus en plus vite + le disque se remplit vers l'explosion
	var pulse: float = 0.5 + 0.5 * sin(_t * (10.0 + 22.0 * p))
	if _ring != null:
		_ring.modulate.a = 0.45 + 0.35 * p + 0.2 * pulse
		_ring.scale = Vector2.ONE * (radius * 2.0 / 128.0) * (0.92 + 0.08 * p)
	if _fill != null:
		_fill.modulate.a = 0.08 + 0.26 * p
	# OGIVE : descend de _off vers le centre (accelere = chute) + grossit + trainee
	if _missile != null and _missile.visible:
		var pm: float = pow(p, 1.75)
		_missile.global_position = global_position + _off * (1.0 - pm)
		_missile.scale = Vector2.ONE * _mscale * (0.55 + 0.45 * pm)
	if not _exploded and _t >= delay:
		_explode()

func _explode() -> void:
	_exploded = true
	if _missile != null:
		_missile.visible = false   # l'ogive a touche -> place a l'explosion
	if _smoke_ps != null:
		_smoke_ps.emitting = false
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("aaa_explosion", global_position, 0.0, radius / 95.0, color)
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		if (player as Node2D).global_position.distance_to(global_position) <= radius:
			player.take_damage(damage)
	if Events != null:
		Events.screen_shake.emit(3.2)
	queue_free()
