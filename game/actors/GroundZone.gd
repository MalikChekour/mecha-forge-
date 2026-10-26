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
# BRAS PRESSEUR (decor tech) : forme "line" en plus du cercle par defaut. line_from/line_to sont
# des offsets LOCAUX (relatifs a global_position, fixe par l'appelant APRES new()) ; radius sert
# alors de demi-largeur de la ligne plutot que de rayon de cercle. Le telegraphe reste le meme
# cercle/anneau cosmetique quelle que soit la forme -> aucune nouvelle texture requise.
var shape: String = "circle"
var line_from: Vector2 = Vector2.ZERO
var line_to: Vector2 = Vector2.ZERO
var stun_duration: float = 0.0
var fx_kind: String = "decor_hit"

const MISSILE_TEX: Texture2D = preload("res://assets/weapons/missile_boss.png")   # bombe/ogive Gemini

var _t: float = 0.0
var _exploded: bool = false
var _ring: Sprite2D
var _fill: Sprite2D
# 04/10, signale par le patron : shape="line" ne changeait QUE le calcul de collision dans
# _explode(), jamais le rendu (le _ring restait un cercle quelle que soit la forme - simplification
# volontaire a l'epoque, documentee plus haut, mais ca rend le "laser rotatif" illisible : le
# joueur voit un point clignoter au centre, jamais la ligne balayee). _beam rend la vraie forme
# en plus du _ring existant (inchange, garde pour les zones circulaires classiques).
var _beam: Sprite2D
# OGIVE qui TOMBE sur la zone (materialise le tir boss + trainee de fumee en particules)
var _missile: Sprite2D
var _smoke_ps: CPUParticles2D
var _off: Vector2 = Vector2.ZERO
var _mscale: float = 1.0
# 04/10 tour 2 (« encore bas de gamme ») : telegraphe PREMIUM. Avant = un halo + un anneau qui
# clignote. Maintenant 4 couches lisibles et « serieuses » :
#   _base   : assombrit le sol de la zone (le danger se lit meme sur un sol clair)
#   _fill   : disque qui se REMPLIT du centre vers le bord = compte a rebours visuel exact
#   _ring   : bord net (onde a front tranchant), pulse de plus en plus vite
#   _hazard : couronne segmentee « instrument de visee » qui tourne et accelere
# + flash blanc dans les 12 derniers % avant l'impact. Forme "line" : vraie bande + 2 bords nets.
var _base: Sprite2D
var _hazard: Sprite2D
var _edge_a: Line2D
var _edge_b: Line2D
var _band: Line2D
## Phase 2 : les cercles chauds viennent du pool. Les bandes ("line") restent des noeuds frais.
var _pooled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE   # se fige avec le draft (le parent Game tourne en ALWAYS)
	z_index = -2                                 # au SOL, sous les ennemis
	var m: CanvasItemMaterial = Tex.add_mat()
	if shape == "line":
		_build_line_telegraph(m)
	else:
		var d: float = radius * 2.0 / 128.0
		_base = Sprite2D.new()
		_base.texture = Tex.disc_tex()
		_base.scale = Vector2.ONE * d
		_base.modulate = Color(color.r * 0.12, color.g * 0.08, color.b * 0.08, 0.0)
		add_child(_base)
		_fill = Sprite2D.new()
		_fill.texture = Tex.disc_tex()
		_fill.material = m
		_fill.scale = Vector2.ONE * d * 0.05
		_fill.modulate = Color(color.r, color.g, color.b, 0.16)
		add_child(_fill)
		_hazard = Sprite2D.new()
		_hazard.texture = Tex.hazard_ring_tex()
		_hazard.material = m
		_hazard.scale = Vector2.ONE * (radius * 2.0 / 256.0)
		_hazard.rotation = randf() * TAU
		_hazard.modulate = Color(color.r, color.g, color.b, 0.0)
		add_child(_hazard)
		_ring = Sprite2D.new()
		_ring.texture = Tex.shock_tex()
		_ring.material = m
		_ring.scale = Vector2.ONE * (radius * 2.0 / 256.0)
		_ring.modulate = Color(color.r, color.g, color.b, 0.0)
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

## Rearme une zone circulaire deja construite (pool). La forme "line" n'est pas recyclee :
## son visuel est bake dans _ready, le reset ne le reconstruit pas.
func arm(pos: Vector2, r: float, dly: float, dmg: float, col: Color, fx: String, g: Node, plr: Node2D) -> void:
	shape = "circle"
	radius = r
	delay = maxf(0.05, dly)
	damage = dmg
	color = col
	fx_kind = fx
	game = g
	player = plr
	_t = 0.0
	_exploded = false
	visible = true
	set_process(true)
	global_position = pos
	if _missile != null:
		var show_m: bool = radius >= 100.0
		_missile.visible = show_m
		if show_m:
			var a: float = deg_to_rad(-96.0 + randf_range(-22.0, 22.0))
			_off = Vector2(cos(a), sin(a)) * (radius * 2.2 + 300.0)
			_mscale = clampf(radius / 95.0, 0.7, 1.35) * 0.42
			_missile.rotation = (-_off).angle()
		if _smoke_ps != null:
			_smoke_ps.emitting = show_m
			if show_m:
				_smoke_ps.restart()

## Remise en reserve. N'appelle pas queue_free.
func reset() -> void:
	_t = 0.0
	_exploded = false
	visible = false
	set_process(false)
	global_position = Vector2(1.0e7, 1.0e7)
	if _missile != null:
		_missile.visible = false
	if _smoke_ps != null:
		_smoke_ps.emitting = false

func _release_self() -> void:
	if _pooled and game != null and game.has_method("reclaim_ground_zone"):
		game.reclaim_ground_zone(self)
	else:
		queue_free()

## Forme "line" (bras presseur, laser rotatif) : bande sombre + bande d'energie qui s'epaissit
## + deux bords nets paralleles + halo doux. Plus de cercle parasite au centre.
func _build_line_telegraph(m: CanvasItemMaterial) -> void:
	var length: float = maxf(line_from.distance_to(line_to), 1.0)
	var dir: Vector2 = (line_to - line_from) / length
	var perp: Vector2 = dir.orthogonal()
	var shade: Line2D = Line2D.new()
	shade.width = radius * 2.0
	shade.default_color = Color(0, 0, 0, 0.28)
	shade.add_point(line_from)
	shade.add_point(line_to)
	add_child(shade)
	_beam = Sprite2D.new()
	_beam.texture = Tex.glow(Color.WHITE, 128)
	_beam.scale = Vector2(length / 128.0 * 1.15, radius * 2.0 / 128.0)
	_beam.rotation = dir.angle()
	_beam.position = (line_from + line_to) * 0.5
	_beam.material = m
	_beam.modulate = Color(color.r, color.g, color.b, 0.0)
	add_child(_beam)
	_band = Line2D.new()
	_band.width = 2.0
	_band.material = m
	_band.default_color = Color(color.r, color.g, color.b, 0.3)
	_band.add_point(line_from)
	_band.add_point(line_to)
	add_child(_band)
	_edge_a = Line2D.new()
	_edge_b = Line2D.new()
	for e in [_edge_a, _edge_b]:
		var ln: Line2D = e
		ln.width = 3.0
		ln.material = m
		ln.default_color = Color(color.r, color.g, color.b, 0.0).lerp(Color(1, 1, 1, 0.0), 0.3)
		add_child(ln)
	_edge_a.add_point(line_from + perp * radius)
	_edge_a.add_point(line_to + perp * radius)
	_edge_b.add_point(line_from - perp * radius)
	_edge_b.add_point(line_to - perp * radius)

func _process(delta: float) -> void:
	if GameState != null and not GameState.alive:
		return
	_t += delta
	var p: float = clampf(_t / delay, 0.0, 1.0)
	# telegraph : le bord pulse de plus en plus vite, le disque se remplit du centre vers le bord,
	# la couronne tactique tourne en accelerant, flash blanc juste avant l'impact.
	var pulse: float = 0.5 + 0.5 * sin(_t * (10.0 + 26.0 * p))
	var fin: float = clampf((p - 0.88) / 0.12, 0.0, 1.0)      # 0 -> 1 sur les 12 derniers %
	var intro: float = clampf(_t / 0.12, 0.0, 1.0)            # apparition franche (pas de pop)
	var ease_p: float = 1.0 - pow(1.0 - p, 2.2)
	if _base != null:
		_base.modulate.a = 0.42 * intro
	if _fill != null:
		_fill.scale = Vector2.ONE * (radius * 2.0 / 128.0) * maxf(0.05, ease_p)
		var fc: Color = color.lerp(Color.WHITE, 0.55 * fin)
		_fill.modulate = Color(fc.r, fc.g, fc.b, (0.14 + 0.22 * p + 0.35 * fin) * intro)
	if _ring != null:
		var rc: Color = color.lerp(Color.WHITE, 0.25 + 0.6 * fin)
		_ring.modulate = Color(rc.r, rc.g, rc.b, (0.55 + 0.3 * p + 0.15 * pulse) * intro)
		_ring.scale = Vector2.ONE * (radius * 2.0 / 256.0) * (1.0 + 0.04 * (1.0 - intro))
	if _hazard != null:
		_hazard.rotation += delta * (0.6 + 3.4 * p * p)
		_hazard.modulate.a = (0.35 + 0.35 * p) * intro * (1.0 - 0.6 * fin)
		_hazard.scale = Vector2.ONE * (radius * 2.0 / 256.0) * (1.06 - 0.06 * ease_p)
	if _beam != null:
		var bc: Color = color.lerp(Color.WHITE, 0.5 * fin)
		_beam.modulate = Color(bc.r, bc.g, bc.b, (0.18 + 0.3 * p + 0.15 * pulse + 0.3 * fin) * intro)
		var length: float = maxf(line_from.distance_to(line_to), 1.0)
		_beam.scale = Vector2(length / 128.0 * 1.15, (radius * 2.0 / 128.0) * (0.92 + 0.08 * p))
	if _band != null:
		_band.width = maxf(2.0, radius * 2.0 * ease_p)
		_band.default_color = Color(color.r, color.g, color.b, (0.16 + 0.2 * p + 0.4 * fin) * intro).lerp(
			Color(1, 1, 1, (0.16 + 0.2 * p + 0.4 * fin) * intro), 0.5 * fin)
	if _edge_a != null:
		var ec: Color = color.lerp(Color.WHITE, 0.3 + 0.6 * fin)
		var ea: float = (0.6 + 0.25 * p + 0.15 * pulse) * intro
		_edge_a.default_color = Color(ec.r, ec.g, ec.b, ea)
		_edge_b.default_color = Color(ec.r, ec.g, ec.b, ea)
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
	# 04/10, VFX "vraiment nuls" signale par le patron : un seul sprite plat ici servait TOUS les
	# dangers routes par GroundZone (bras_presseur, jet_de_cryo, pic_de_glace, grille_ventilation,
	# zone_chargement, surchauffe_sol, tentacule_emergence, pulse_energie, cristal_instable,
	# emetteur_laser_rotatif...). impact_fx (meme composite que le combat : flash+anneau+debris+
	# halo) n'a aucun filtre de kind -> "decor_hit" retombe sur son defaut complet, gratuitement.
	if game != null and game.has_method("impact_fx"):
		game.impact_fx(global_position, color, fx_kind, Vector2.ZERO, radius / 95.0)
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		var ppos: Vector2 = (player as Node2D).global_position
		var hit: bool = false
		match shape:
			"line":
				var a: Vector2 = global_position + line_from
				var b: Vector2 = global_position + line_to
				var ab: Vector2 = b - a
				var t: float = clampf((ppos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				hit = ppos.distance_to(a + ab * t) <= radius
			_:
				hit = ppos.distance_to(global_position) <= radius
		if hit:
			player.take_damage(damage, global_position, "zone:" + (fx_kind if fx_kind != "" else "sol"))
			if stun_duration > 0.0 and player.has_method("stun"):
				player.stun(stun_duration)
	
	# Damage enemies as well
	if is_inside_tree():
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.has_method("take_damage"):
				var epos: Vector2 = (e as Node2D).global_position
				var hit: bool = false
				match shape:
					"line":
						var a: Vector2 = global_position + line_from
						var b: Vector2 = global_position + line_to
						var ab: Vector2 = b - a
						var t: float = clampf((epos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
						hit = epos.distance_to(a + ab * t) <= radius
					_:
						hit = epos.distance_to(global_position) <= radius
				if hit:
					e.take_damage(damage)

	if Events != null:
		Events.screen_shake.emit(3.2)
	_release_self()
