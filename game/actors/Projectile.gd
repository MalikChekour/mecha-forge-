extends Area2D
class_name Projectile

const LockChevron = preload("res://actors/LockChevron.gd")   # voir la note dans Player.gd

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var pierce: int = 0
var homing: bool = false
var aoe: float = 0.0
var fx_scale: float = 1.0     # weapon-level visual growth (bolt size + impact burst)
var bolt_color: Color = Color(0.75, 0.96, 1.0)
var life: float = 2.0
var alive: bool = true
var game: Node = null
var impact_kind: String = ""       # weapon family -> signature impact FX
var crit_chance: float = 0.0
var crit_mult: float = 2.0
# --- capacites ajoutees pour les nouveaux archetypes -------------------------
var bounces: int = 0            # RICOCHET : rebonds restants vers un autre ennemi
var boomerang: bool = false     # DISQUE  : part, ralentit, puis revient au mecha
var _last_hit: Node = null      # pour ne pas rebondir sur l'ennemi qu'on vient de toucher
var _boom_t: float = 0.0        # temps restant avant de faire demi-tour
var _boom_back: bool = false

## Plan de differenciation des chassis (26/09) : identite du tireur, pour VORTEX (chaine
## d'alignement, ci-dessous) et BRUISER (transmise a Enemy.take_damage). Vide = sans effet.
var chassis_id: String = ""
var _align_hits: int = 0        # combien d'ennemis CE projectile a deja touche (perce)
var _align_granted: bool = false   # une seule pile accordee par projectile, au 2e ennemi touche
var _relaunched: bool = false    # CERCLIER : une seule relance du Disque a son premier retour

var _spr: Sprite2D
var _light: Sprite2D          # additive halo, not a dynamic light (see _ready)
var _trail: Line2D
var _lock_mark: LockChevron   # missile-only : chevron sur la cible reellement poursuivie
var _built: bool = false
var _turn_rate: float = 3.0
var _orb_pulse: bool = false       # plasma orbs breathe
var _base_scale: Vector2 = Vector2.ONE
var _pulse_t: float = 0.0

# --- ANIMATED HDR BULLETS -------------------------------------------------------------
# Each weapon family gets a rendered sprite sheet (bloom+ACES) instead of a stretched
# procedural glow blob. Sheets are horizontal: BULLET_FRAMES cells of BULLET_CELL px,
# art pointing +X (the node rotates to the velocity, so the art lines up with travel).
const BULLET_CELL: int = 128
const BULLET_FRAMES: int = 12
const BULLET_FPS: float = 18.0
const BULLET_FAMILY: Dictionary = {
	"autocannon": "tracer", "vulcan": "tracer", "drone": "tracer",
	"missilepod": "warhead", "hydra": "warhead",
	"railgun": "lance", "annihilator": "lance",
	"plasma": "orb", "singularity": "orb",
	"disperseur": "tracer", "deflagrateur": "tracer",   # eclats rapides
	"ricochet": "orb", "carambole": "orb",              # bille qui tourne en rebondissant
	"disque": "lance", "guillotine": "lance",           # lame allongee
	# 04/10, signale par le patron (VFX "vraiment nuls") : rail_nova/frelon retombaient sur le
	# defaut "tracer" (silencieux, jamais signale) - meme famille que l'arme dont elles reprennent
	# le mecanisme (rail_nova perce comme railgun, frelon rebondit comme ricochet).
	"rail_nova": "lance", "frelon": "orb",
}
# family -> {scale on screen, native_hue (skip the accent tint), spin rad/s}
const BULLET_STYLE: Dictionary = {
	# 🚨 TESTEUR SENSATIONS : « l'autocanon de depart est un losange jaune d'environ 20 px avec
	# presque pas de trainee » — et c'est l'arme des 30-60 PREMIERES secondes, celles qui
	# decident si le joueur reste. Le faisceau et les missiles prouvent qu'on sait faire ;
	# l'arme de depart doit jouer dans la meme cour. Taille +45 %.
	"tracer":  {"scale": 0.61, "native": false, "spin": 0.0},
	"warhead": {"scale": 0.40, "native": true,  "spin": 0.0},
	"lance":   {"scale": 0.52, "native": false, "spin": 0.0},
	"orb":     {"scale": 0.36, "native": false, "spin": 2.2},
}
static var _sheets: Dictionary = {}   # family -> Texture2D | null (null = fall back to the glow)
var _anim: bool = false
var _anim_t: float = 0.0
var _spin: float = 0.0

# --- PER-FAMILY TRAILS ----------------------------------------------------------------
# The trail is the biggest thing a bullet puts on screen — at ~45px the sprite detail is
# mostly lost and the streak is what the eye actually reads. So each family gets its own
# streak physics, not just a different width:
#   pts    = trail persistence (how many past positions are kept = how long it lingers)
#   width  = base thickness
#   head   = width multiplier AT the bullet (>1 flares at the head, <1 pinches it)
#   tail   = width multiplier at the far end (warhead's exhaust EXPANDS as it falls behind)
#   wobble = perpendicular sine amplitude (px) — plasma wake undulates
#   wfreq  = wobble frequency
#   warm   = tail colour bias toward embers instead of the accent (fire trails cool to red)
const TRAIL_STYLE: Dictionary = {
	# kinetic: snappy, mais une VRAIE trainee — a 6 points et 8 px de large elle etait
	# invisible en mouvement, d'ou le « presque pas de trainee » du rapport de test.
	"tracer":  {"pts": 14, "width": 15.0, "head": 1.30, "tail": 0.30, "wobble": 0.0, "wfreq": 0.0, "warm": 0.35},
	# rocket: long plume that EXPANDS behind the nozzle and cools to embers
	"warhead": {"pts": 20, "width": 15.0, "head": 0.45, "tail": 1.25, "wobble": 0.0, "wfreq": 0.0, "warm": 1.0},
	# hypersonic: a very long, razor-thin ionisation contrail that hangs in the air
	"lance":   {"pts": 26, "width": 4.5,  "head": 1.0, "tail": 0.5,  "wobble": 0.0, "wfreq": 0.0, "warm": 0.0},
	# plasma: a wide undulating wake — the energy doesn't fly straight, it churns
	"orb":     {"pts": 11, "width": 15.0, "head": 1.0, "tail": 0.3,  "wobble": 6.5, "wfreq": 19.0, "warm": 0.0},
}
var _trail_max: int = 9
var _wobble: float = 0.0
var _wfreq: float = 0.0
var _trail_t: float = 0.0

## Brightness of the additive halo. Replaces PointLight2D.energy: alpha carries the punch and a
## little scale sells the size difference between a pip and a lance.
func _halo(e: float) -> void:
	_light.modulate = Color(bolt_color.r, bolt_color.g, bolt_color.b, clampf(e * 0.34, 0.0, 1.0))
	_light.scale = Vector2.ONE * (0.40 + e * 0.13)

static func _bullet_sheet(fam: String) -> Texture2D:
	if not _sheets.has(fam):
		var p: String = "res://assets/bullets/%s.png" % fam
		_sheets[fam] = load(p) if ResourceLoader.exists(p) else null
	return _sheets[fam]

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
	fx_scale = float(params.get("fx_scale", 1.0))   # grows the bolt + its impact with weapon level
	bolt_color = Color(params.get("color", Color(0.75, 0.96, 1.0)))
	impact_kind = String(params.get("impact", ""))
	crit_chance = float(params.get("crit_chance", 0.0))
	crit_mult = float(params.get("crit_mult", 2.0))
	alive = true
	life = float(params.get("life", 2.0))          # portee courte = duree de vie courte
	bounces = int(params.get("bounces", 0))
	boomerang = bool(params.get("boomerang", false))
	chassis_id = String(params.get("chassis", ""))
	_align_hits = 0          # 🚨 objet PIOCHE DANS UN POOL (_proj_pool) : reinitialiser ici,
	_align_granted = false   # sinon un ancien tir Vortex "contaminerait" le suivant.
	_relaunched = false
	_last_hit = null
	_boom_t = life * 0.45                          # demi-tour a mi-course
	_boom_back = false
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
		var add: CanvasItemMaterial = Tex.add_mat()   # shared instance -> bullets can batch together
		_spr = Sprite2D.new()
		_spr.texture = Tex.glow(Color(0.75, 0.96, 1.0), 44)
		_spr.material = add
		_spr.scale = Vector2(1.0, 0.42)
		add_child(_spr)
		# Additive halo instead of a dynamic light: with evolved weapons and haste the player
		# fires 40-85 shots/second, so this was dozens of concurrent Light2D — each one breaking
		# batching and costing a per-frame light×item test in gl_compatibility.
		_light = Sprite2D.new()
		_light.texture = Tex.glow(Palette.CYAN, 128)
		_light.material = Tex.add_mat()
		_light.modulate = Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.42)
		_light.scale = Vector2.ONE * 0.5
		_light.z_index = -1
		add_child(_light)
		_trail = Line2D.new()
		_trail.top_level = true
		_trail.width = 11.0
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0.3, 0.85, 1.0, 0.0))
		g.set_color(1, Color(0.8, 0.97, 1.0, 0.7))
		_trail.gradient = g
		_trail.material = Tex.add_mat()
		add_child(_trail)
		_lock_mark = LockChevron.new()
		_lock_mark.top_level = true
		_lock_mark.z_index = 5
		_lock_mark.visible = false
		add_child(_lock_mark)
		area_entered.connect(_on_hit)
		body_entered.connect(_on_body)
	
	# Prefer the rendered HDR sheet for this weapon family; fall back to the procedural glow
	# if the sheet isn't present, so a missing asset can never break the shot.
	var fam: String = String(BULLET_FAMILY.get(impact_kind, "tracer"))
	var sheet: Texture2D = _bullet_sheet(fam)
	# the bolt itself grows a little with weapon level (gentler than the impact, so it stays readable)
	var bscale: float = 1.0 + (fx_scale - 1.0) * 0.55
	_anim = sheet != null
	if _anim:
		var st: Dictionary = BULLET_STYLE[fam]
		_spr.texture = sheet
		_spr.region_enabled = true
		_spr.region_rect = Rect2(0, 0, BULLET_CELL, BULLET_CELL)
		_spr.scale = Vector2.ONE * float(st["scale"]) * bscale
		# luminance sheets take the weapon's accent; the missile keeps its own fire colour
		_spr.modulate = Color.WHITE if bool(st["native"]) else Color(bolt_color.r * 1.6,
			bolt_color.g * 1.6, bolt_color.b * 1.6)
		_spin = float(st["spin"])
		_spr.rotation = 0.0
		# desync the loop per bullet — otherwise a burst pulses in lockstep and reads as fake
		_anim_t = randf() * (float(BULLET_FRAMES) / BULLET_FPS)
	else:
		_spr.region_enabled = false
		_spr.texture = Tex.glow(bolt_color, 44)
		# Agent-9 rule: ONE vivid bloomed ACCENT per weapon — so the bolt keeps its HUE (no white-out).
		# Multiplying (not adding an offset) brightens/blooms it while the colour stays saturated.
		_spr.modulate = Color(bolt_color.r * 2.0, bolt_color.g * 2.0, bolt_color.b * 2.0)
		_spr.scale = Vector2(1.35, 0.40) * bscale   # stretched along travel = reads as speed, not a dot
	_light.texture = Tex.glow(bolt_color, 128)
	_halo(bscale)
	# --- trail shaped per weapon family (see TRAIL_STYLE) ---
	var ts: Dictionary = TRAIL_STYLE.get(fam, TRAIL_STYLE["tracer"])
	_trail_max = int(ts["pts"])
	_wobble = float(ts["wobble"])
	_wfreq = float(ts["wfreq"])
	_trail_t = 0.0
	var g2: Gradient = Gradient.new()
	# point 0 = oldest (far behind), point 1 = at the bullet
	var warm: float = float(ts["warm"])
	# a fire trail cools to embers as it falls behind; an energy trail just fades out
	var tail_col: Color = Color(1.0, 0.22, 0.05).lerp(bolt_color, 1.0 - warm)
	g2.set_color(0, Color(tail_col.r, tail_col.g, tail_col.b, 0.0))
	g2.set_color(1, Color(minf(1.0, bolt_color.r * 1.3), minf(1.0, bolt_color.g * 1.3),
		minf(1.0, bolt_color.b * 1.3), 0.85))
	_trail.gradient = g2
	var wc: Curve = Curve.new()
	wc.add_point(Vector2(0.0, float(ts["tail"])))
	wc.add_point(Vector2(1.0, float(ts["head"])))
	_trail.width_curve = wc
	_trail.width = float(ts["width"])
	_trail.clear_points()

	# PER-WEAPON light + fallback shape. The bullet's SHAPE now comes from the rendered art and
	# its streak from TRAIL_STYLE, so the stretch below only applies on the fallback path
	# (where the bolt is still a plain glow blob).
	_orb_pulse = false
	match impact_kind:
		"railgun", "annihilator":            # piercing LANCE: long, thin, blazing
			if not _anim:
				_spr.scale = Vector2(3.4, 0.22)
			_halo(1.35)
		"plasma", "singularity":             # energy ORB: round + pulsing
			if not _anim:
				_spr.scale = Vector2(1.15, 1.05)
				_orb_pulse = true            # the sheet already boils — don't double up on it
			_halo(1.25)
		"missilepod", "hydra":               # WARHEAD: stubby + hot wide trail
			if not _anim:
				_spr.scale = Vector2(0.95, 0.72)
			_halo(1.0)
		"drone":                             # tiny bright pip
			if not _anim:
				_spr.scale = Vector2(0.8, 0.55)
			else:
				_spr.scale = Vector2.ONE * 0.26   # same tracer art, drone-sized
			_trail.width = 6.0                    # drone pips get a slimmer streak than the autocannon
			_trail_max = 5
			_halo(0.8)
		_:                                    # KINETIC tracer (autocannon/vulcan): short & fast
			if not _anim:
				_spr.scale = Vector2(1.4, 0.4)
			_halo(0.95)
	_base_scale = _spr.scale
	_pulse_t = 0.0

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _anim and _spr != null:                      # step the rendered bullet sheet
		_anim_t += delta
		var f: int = int(_anim_t * BULLET_FPS) % BULLET_FRAMES
		_spr.region_rect = Rect2(f * BULLET_CELL, 0, BULLET_CELL, BULLET_CELL)
		if _spin != 0.0:
			_spr.rotation += _spin * delta          # the orb tumbles as it flies
	elif _orb_pulse and _spr != null:               # fallback: plasma orb breathes as it flies
		_pulse_t += delta
		var s: float = 1.0 + 0.16 * sin(_pulse_t * 16.0)
		_spr.scale = _base_scale * s
	if boomerang:
		var home: Node2D = _player_node()
		if not _boom_back:
			_boom_t -= delta
			velocity = velocity.lerp(Vector2.ZERO, delta * 1.6)   # il s'essouffle
			if _boom_t <= 0.0:
				_boom_back = true
				_last_hit = null                                   # il peut retoucher au retour
		elif home != null:
			var back: Vector2 = (home.global_position - global_position)
			if back.length() < 46.0:
				# CERCLIER (27/09, rapport "exploiter le retour du Disque") : au premier retour,
				# repart UNE fois vers l'ennemi le plus proche, degats reduits. boomerang=false ->
				# la branche ci-dessus ne joue plus, il vole tout droit jusqu'a l'impact ou l'expiration.
				if chassis_id == "cerclier" and not _relaunched:
					var nxt: Node2D = _find_nearest_enemy()
					if nxt != null:
						_relaunched = true
						boomerang = false
						damage *= 0.5
						velocity = (nxt.global_position - global_position).normalized() * 620.0
						rotation = velocity.angle()
						life = maxf(life, 1.0)
						return
				_recycle()
				return
			velocity = velocity.lerp(back.normalized() * 780.0, delta * 5.0)
	if homing:
		var tgt: Node2D = _find_homing_target()
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
			_lock_mark.visible = true
			_lock_mark.global_position = tgt.global_position + Vector2(0.0, -46.0)
		else:
			_lock_mark.visible = false
	global_position += velocity * delta
	# plasma churns rather than flying clean: offset the logged point perpendicular to travel
	var tp: Vector2 = global_position
	if _wobble > 0.0:
		_trail_t += delta
		tp += velocity.normalized().orthogonal() * (sin(_trail_t * _wfreq) * _wobble)
	_trail.add_point(tp)
	while _trail.get_point_count() > _trail_max:
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

## HOMING (missilepod/hydra) uniquement — PAS le rebond du ricochet (_find_nearest_enemy ci-dessus,
## omnidirectionnel par design : "on repart vers l'ennemi le plus proche AUTRE que celui touche").
## 🚨 patron 25/09 : "le tir doit aller dans la direction de la visee meme s'il y a rien" — sans
## filtre directionnel, un missile tire vers du vide accrochait le PLUS PROCHE ennemi du plan
## entier (meme dans le dos du joueur), ignorant totalement la visee manuelle des qu'un seul
## ennemi existait quelque part. Cone de 55 deg autour de la vitesse courante : hors cone -> pas
## de cible, le missile vole droit dans l'axe vise au lieu de detourner vers n'importe quoi.
const HOMING_CONE_COS: float = 0.57   # cos(55°)
func _find_homing_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = 99999999.0
	var fwd: Vector2 = velocity.normalized() if velocity.length() > 1.0 else Vector2.RIGHT
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and is_instance_valid(e):
			var to: Vector2 = (e as Node2D).global_position - global_position
			if to.length_squared() < 1.0:
				continue
			if fwd.dot(to.normalized()) < HOMING_CONE_COS:
				continue   # hors du couloir de tir -> ignore, meme si c'est le plus proche
			var d: float = to.length_squared()
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
			var is_crit: bool = randf() < crit_chance
			var dmg: float = damage * (crit_mult if is_crit else 1.0)
			(area as Enemy).take_damage(dmg, chassis_id, impact_kind)
			Events.damage_dealt.emit(global_position, int(dmg), is_crit)
			if is_crit:
				Audio.sfx("crit", 0.1)
			# VORTEX "aligner" (prototype B) : un tir perforant qui touche son 2e ennemi donne
			# UNE pile (pas une par ennemi supplementaire — un Disque a 20 de perce ne doit pas
			# remplir la chaine d'un seul lancer). cf. Player.vortex_align_stack.
			if chassis_id == "vortex" and pierce > 0:
				_align_hits += 1
				if _align_hits >= 2 and not _align_granted:
					_align_granted = true
					if game != null and "player" in game and game.player != null \
							and game.player.has_method("vortex_align_stack"):
						game.player.vortex_align_stack()
		if game != null and game.has_method("impact_fx"):
			# AoE weapons: match the burst to the ACTUAL (level-grown) blast radius, so a wide
			# splash reads wide. Others use the weapon's fx_scale directly.
			var isc: float = fx_scale
			if aoe > 0.0:
				isc = maxf(fx_scale, aoe / 74.0)
			game.impact_fx(global_position, bolt_color, impact_kind, velocity.normalized(), isc)
		else:
			Events.hit_spark.emit(global_position, bolt_color)
		if pierce > 0:
			pierce -= 1
		elif bounces > 0:
			# RICOCHET : on repart vers l'ennemi le plus proche AUTRE que celui touche.
			_last_hit = area
			var nxt: Node2D = _find_nearest_enemy()
			if nxt == null:
				_recycle()
			else:
				bounces -= 1
				var sp: float = velocity.length()
				velocity = (nxt.global_position - global_position).normalized() * sp
				rotation = velocity.angle()
				life = maxf(life, 0.8)
		elif not boomerang:
			_recycle()

## Le mecha, pour le retour du disque (le projectile ne le connait pas autrement).
func _player_node() -> Node2D:
	if game != null and "player" in game:
		var p: Variant = game.player
		if p is Node2D and is_instance_valid(p):
			return p as Node2D
	return null

func _do_splash() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var aoe_sq: float = aoe * aoe
	for e in enemies:
		if e is Enemy and is_instance_valid(e) and (e as Enemy).alive:
			var d: float = global_position.distance_squared_to((e as Node2D).global_position)
			if d <= aoe_sq:
				var is_crit: bool = randf() < crit_chance   # AoE hits crit like single-target ones
				var dmg: float = damage * (crit_mult if is_crit else 1.0)
				(e as Enemy).take_damage(dmg, chassis_id, impact_kind)
				Events.damage_dealt.emit((e as Node2D).global_position, int(dmg), is_crit)
				if is_crit:
					Audio.sfx("crit", 0.1)

func _on_body(body: Node) -> void:
	if not alive:
		return
	if body.is_in_group("cover") and body.has_method("take_damage"):
		body.take_damage(damage)
		Events.hit_spark.emit(global_position, Palette.ACCENT)
		_recycle()

func _recycle() -> void:
	alive = false
	if _lock_mark != null:
		_lock_mark.visible = false
	if game != null and game.has_method("reclaim_proj"):
		game.reclaim_proj(self)
	else:
		queue_free()

## Alias pool Phase 2 : release() cherche reset() avant deactivate().
func reset() -> void:
	deactivate()

# Park far off-screen + stop processing (monitoring stays on -> no signal-time toggle,
# and nothing overlaps way out there). Reused via setup().
func deactivate() -> void:
	set_physics_process(false)
	visible = false
	global_position = Vector2(1.0e7, 1.0e7)
	if _trail != null:
		_trail.clear_points()
	if _lock_mark != null:
		_lock_mark.visible = false
