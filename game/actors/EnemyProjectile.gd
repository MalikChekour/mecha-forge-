class_name EnemyProjectile
extends Area2D
## Balle ennemie POOLEE. DEUX modes :
##  - MISSILE (tirs LOURDS : gunner + boss) : sprite d'OGIVE 3D generee + FLAMME d'echappement +
##    TRAINEE de FUMEE EN PARTICULES (CPUParticles2D, web-safe) = vraie trainee, plus de ruban plat.
##  - NEON (petits drones) : glow additif leger, inchange.
## Noeuds crees UNE fois (_build), reconfigures a chaque setup, recyclee au lieu de queue_free.

const MISSILE_TEX: Texture2D = preload("res://assets/weapons/missile_gunner.png")   # missile Gemini (mecha)

# LATENCE : quand beaucoup de missiles sont a l'ecran, on PLAFONNE le nombre de trainees-particules
# actives (cher sur web). Les missiles en exces gardent flamme + trail court (visuel OK, cout ~0).
static var _smoke_active: int = 0
const SMOKE_CAP: int = 8
# Plafond DUR de missiles simultanes a l'ecran (anti-saturation + latence) : au-dela, le gunner
# ne tire pas ce round (cf. Enemy._fire_heavy). Compteur remis a 0 par Game._ready.
static var _active_missiles: int = 0
const MISSILE_CAP: int = 10
var _counted_missile: bool = false

var _dir: Vector2 = Vector2.ZERO
var _dmg: float = 0.0
var _speed: float = 300.0
var _life: float = 3.0
var tint: Color = Color(1.0, 0.55, 0.25)
var size: float = 1.0
var game: Node = null
var missile: bool = false
## GUIDAGE (palier 3 « TRAQUEUR » de l'arme ennemie). En radians/seconde, 0 = tir droit.
## 🚨 Volontairement FAIBLE et LIMITE DANS LE TEMPS (HOMING_T) : un projectile qui suit
## indefiniment est increvable au doigt sur telephone. Il corrige sa course au debut, puis
## part tout droit — donc esquivable si on bouge, punitif si on reste plante.
var homing: float = 0.0
const HOMING_T: float = 1.05
var _homing: float = 0.0

var _built: bool = false
var _body: Sprite2D
var _hot: Sprite2D
var _halo: Sprite2D
var _trail: Line2D                           # neon (drone) OU exhaust chaud court (missile)
var _missile_spr: Sprite2D
var _flame: Sprite2D
var _smoke_ps: CPUParticles2D                # trainee de fumee en particules (missile)
var _trail_points: Array[Vector2] = []
var _t: float = 0.0
var _has_smoke: bool = false                 # ce missile occupe-t-il un slot de particules ?
var _trail_grad: Gradient                    # degrade de la trainee (tete brillante -> queue transparente)

func _build() -> void:
	collision_layer = 0
	collision_mask = 1 | 8
	monitorable = false
	body_entered.connect(_on_body_entered)
	# --- NEON (drones) ---
	_body = Sprite2D.new(); _body.texture = Tex.glow(Color(1, 1, 1), 64); _body.material = Tex.add_mat(); add_child(_body)
	_hot = Sprite2D.new(); _hot.texture = Tex.glow(Color(1, 1, 1), 40); _hot.material = Tex.add_mat(); _hot.z_index = 1; add_child(_hot)
	_halo = Sprite2D.new(); _halo.texture = Tex.glow(Color(1, 1, 1), 128); _halo.material = Tex.add_mat(); _halo.z_index = -1; add_child(_halo)
	# --- MISSILE : fumee en particules (fond) ---
	_smoke_ps = CPUParticles2D.new()
	_smoke_ps.texture = Tex.glow(Color(1, 1, 1), 48)
	_smoke_ps.local_coords = false            # les bouffees restent dans le monde -> vraie trainee
	_smoke_ps.emitting = false
	_smoke_ps.amount = 14                      # allege (latence quand bcp de missiles a l'ecran)
	_smoke_ps.lifetime = 0.42
	_smoke_ps.lifetime_randomness = 0.35
	_smoke_ps.direction = Vector2(-1, 0)      # emises vers l'ARRIERE du missile
	_smoke_ps.spread = 13.0
	_smoke_ps.initial_velocity_min = 10.0
	_smoke_ps.initial_velocity_max = 42.0
	_smoke_ps.damping_min = 20.0
	_smoke_ps.damping_max = 40.0
	_smoke_ps.gravity = Vector2.ZERO
	var cur: Curve = Curve.new(); cur.add_point(Vector2(0.0, 0.35)); cur.add_point(Vector2(1.0, 1.45))
	_smoke_ps.scale_amount_curve = cur
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.92, 0.92, 0.95, 0.5)); ramp.set_color(1, Color(0.55, 0.55, 0.62, 0.0))
	_smoke_ps.color_ramp = ramp
	_smoke_ps.z_index = -2
	add_child(_smoke_ps)
	# --- flamme d'echappement + sprite ogive ---
	_flame = Sprite2D.new(); _flame.texture = Tex.glow(Color(1, 0.72, 0.3), 64); _flame.material = Tex.add_mat(); _flame.z_index = 2; add_child(_flame)
	_missile_spr = Sprite2D.new(); _missile_spr.texture = MISSILE_TEX; _missile_spr.z_index = 3; add_child(_missile_spr)
	# --- collision + exhaust chaud court ---
	var cs: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new(); c.radius = 8.0; cs.shape = c
	add_child(cs)
	_trail = Line2D.new(); _trail.top_level = true; _trail.material = Tex.add_mat()
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND; _trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_grad = Gradient.new(); _trail.gradient = _trail_grad     # comete : degrade au lieu d'un trait plat
	var wc: Curve = Curve.new(); wc.add_point(Vector2(0.0, 1.0)); wc.add_point(Vector2(1.0, 0.12))
	_trail.width_curve = wc                                         # large a la tete -> fine a la queue
	add_child(_trail)
	_built = true

func setup(pos: Vector2, dir: Vector2, dmg: float, speed: float = 300.0) -> void:
	if not _built:
		_build()
	global_position = pos
	_dir = dir.normalized()
	_dmg = dmg
	_speed = speed
	_life = 3.0
	_t = 0.0
	_homing = homing
	homing = 0.0                                # non colle : le prochain recyclage repart droit
	rotation = _dir.angle()
	_trail_points.clear()
	_trail.points = PackedVector2Array()
	if _has_smoke:                              # libere le slot de particules d'un usage precedent
		_smoke_active -= 1; _has_smoke = false
	if _counted_missile:                        # libere le compteur missile d'un usage precedent
		_active_missiles -= 1; _counted_missile = false
	if missile:
		_active_missiles += 1; _counted_missile = true
		_body.visible = false; _hot.visible = false; _halo.visible = false
		_missile_spr.visible = true; _flame.visible = true
		var ms: float = 0.30 * size
		_missile_spr.scale = Vector2(ms, ms)
		var mlen: float = float(MISSILE_TEX.get_width()) * ms
		var tail: Vector2 = Vector2(-mlen * 0.44, 0.0)        # nozzle = arriere (local -X)
		_flame.position = tail
		# TRAINEE particules SEULEMENT si un slot est libre (sinon flamme+trail suffisent)
		if _smoke_active < SMOKE_CAP:
			_has_smoke = true; _smoke_active += 1
			_smoke_ps.position = tail
			_smoke_ps.scale_amount_min = 0.20 * size
			_smoke_ps.scale_amount_max = 0.34 * size
			_smoke_ps.emitting = true
			_smoke_ps.restart()
		else:
			_smoke_ps.emitting = false
		_trail.width = 7.0 * size
		_trail_grad.set_color(0, Color(1.0, 0.6, 0.2, 0.75))       # exhaust chaud court
		_trail_grad.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	else:
		# BOLT PLASMA (drones/ennemis) : coeur blanc-chaud + halo colore + trainee COMETE (fini le trait plat)
		_body.visible = true; _hot.visible = true; _halo.visible = true
		_missile_spr.visible = false; _flame.visible = false
		_smoke_ps.emitting = false
		_body.scale = Vector2(1.4, 1.15) * size; _body.modulate = Color(tint.r, tint.g, tint.b, 0.95)
		_hot.scale = Vector2(0.85, 0.75) * size; _hot.modulate = Color(1, 1, 1, 0.9)   # coeur blanc incandescent
		_halo.scale = Vector2.ONE * 1.2 * size; _halo.modulate = Color(tint.r, tint.g, tint.b, 0.5)
		_trail.width = 16.0 * size
		_trail_grad.set_color(0, Color(minf(tint.r * 1.5, 1.0), minf(tint.g * 1.5, 1.0), minf(tint.b * 1.5, 1.0), 0.95))
		_trail_grad.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	visible = true
	monitoring = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_t += delta
	if _homing > 0.0 and _t < HOMING_T and game != null and is_instance_valid(game.player):
		var vers: Vector2 = (game.player.global_position - global_position)
		if vers.length_squared() > 1.0:
			# on tourne d'un angle BORNE par image : la courbe se voit, elle ne colle pas.
			var ecart: float = angle_difference(_dir.angle(), vers.angle())
			var pas: float = _homing * delta
			_dir = _dir.rotated(clampf(ecart, -pas, pas))
			rotation = _dir.angle()
	global_position += _dir * _speed * delta
	_trail_points.push_front(global_position)
	var cap: int = 6 if missile else 14
	if _trail_points.size() > cap:
		_trail_points.pop_back()
	_trail.points = PackedVector2Array(_trail_points)
	if missile:
		# FLAMME d'echappement qui vacille (effet special)
		var f: float = 0.72 + 0.32 * sin(_t * 46.0)
		_flame.scale = Vector2(1.6, 1.0) * size * f
		_flame.modulate = Color(1.0, 0.64, 0.24, 0.78 + 0.18 * sin(_t * 61.0))
	else:
		# BOLT plasma vivant : coeur qui pulse (au lieu d'un trait fige)
		var pb: float = 1.0 + 0.14 * sin(_t * 34.0)
		_body.scale = Vector2(1.4, 1.15) * size * pb
		_hot.modulate.a = 0.7 + 0.3 * absf(sin(_t * 44.0))
	_life -= delta
	if _life <= 0.0:
		if missile:
			_impact()          # un missile en fin de course EXPLOSE (ne disparait pas)
		_recycle()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		_impact()
		body.take_damage(_dmg)
		_recycle.call_deferred()
	elif body.is_in_group("cover"):
		_impact()
		_recycle.call_deferred()

## Impact : missile = explosion (feu) ; neon = petit muzzle. Reutilise les VFX POOLES du jeu.
func _impact() -> void:
	if game == null:
		return
	if missile and game.has_method("spawn_vfx"):
		# VRAIE explosion visible (boule de feu + eclair + fumee + secousse) au lieu de disparaitre
		game.spawn_vfx("aaa_explosion", global_position, 0.0, 0.9 * size, Color(1.0, 0.6, 0.2))
		game.spawn_vfx("aaa_muzzle", global_position, 0.0, 0.7 * size, Color(1.0, 0.8, 0.35))
		if Events != null:
			Events.screen_shake.emit(1.6 * size)
	elif game.has_method("spawn_vfx"):
		game.spawn_vfx("aaa_muzzle", global_position, 0.0, 0.4 * size, tint)

func _recycle() -> void:
	visible = false
	monitoring = false
	set_physics_process(false)
	_trail_points.clear()
	if _trail != null:
		_trail.points = PackedVector2Array()
	if _has_smoke:                              # rend le slot de particules
		_smoke_active -= 1; _has_smoke = false
	if _counted_missile:                        # rend le compteur missile
		_active_missiles -= 1; _counted_missile = false
	if _smoke_ps != null:
		_smoke_ps.emitting = false
	if game != null and game.has_method("recycle_enemy_bolt"):
		game.recycle_enemy_bolt(self)
	else:
		queue_free()
