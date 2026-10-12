extends RefCounted
## FxKit — boite a outils VFX PREMIUM (04/10, tour 2 : le patron trouve les effets « encore bas de
## gamme, j'aurais aime plus de serieux et de qualite »).
##
## Diagnostic de l'ancien rendu (Game._debris/_smoke/_ring/_flash_sprite) :
##   * debris = CPUParticles2D SANS texture -> des carres de 2-4 px ; et sans `spread` -> le cone
##     par defaut de 45 deg vers la DROITE : toutes les gerbes partaient du meme cote.
##   * fumee = carres gris opaques, aucune variation.
##   * anneaux/flashs = interpolation LINEAIRE (aucune inertie), anneau gaussien mou.
##   * aucune trace persistante au sol -> l'explosion « n'a pas eu lieu » une fois finie.
##
## Ici chaque effet est COMPOSE en couches, comme un VFX de production :
##   1. coeur blanc anamorphique (pop 0.1 s, ease-out expo)      -> l'instant de l'impact
##   2. halo colore plus lent                                    -> l'energie
##   3. onde de choc a front net (ease-out expo, fondu ease-in)  -> la pression
##   4. etincelles etirees alignees sur la vitesse + gravite     -> la matiere projetee
##   5. matiere secondaire (fumee bruitee / vapeur / eclats / gouttes / braises)
##   6. trace au sol qui s'estompe en ~3 s (brulure, givre, flaque) -> la consequence
## Tout est blanc + teinte (color_ramp) -> une texture sert toutes les couleurs, batch possible.
## Rien en headless. Couts bornes (plafond de decals, pas de Light2D, pas de shader).

const MAX_DECALS: int = 14
static var _decals: Array = []
static var _curve_shrink: Curve = null
static var _curve_grow: Curve = null
static var _curve_pop: Curve = null
static var _ramps: Dictionary = {}

# ---------------------------------------------------------------------------------------------
# utilitaires
# ---------------------------------------------------------------------------------------------
static func ok(g: Node) -> bool:
	return g != null and g.get("_headless") != true and g.get("fx_layer") != null

static func _shrink() -> Curve:
	if _curve_shrink == null:
		_curve_shrink = Curve.new()
		_curve_shrink.add_point(Vector2(0.0, 1.0))
		_curve_shrink.add_point(Vector2(0.7, 0.55))
		_curve_shrink.add_point(Vector2(1.0, 0.0))
	return _curve_shrink

static func _grow() -> Curve:
	if _curve_grow == null:
		_curve_grow = Curve.new()
		_curve_grow.add_point(Vector2(0.0, 0.45))
		_curve_grow.add_point(Vector2(1.0, 1.0))
	return _curve_grow

static func _pop() -> Curve:
	if _curve_pop == null:
		_curve_pop = Curve.new()
		_curve_pop.add_point(Vector2(0.0, 0.2))
		_curve_pop.add_point(Vector2(0.15, 1.0))
		_curve_pop.add_point(Vector2(1.0, 0.0))
	return _curve_pop

static func _key(c: Color) -> String:
	return "%d_%d_%d_%d" % [int(c.r * 40), int(c.g * 40), int(c.b * 40), int(c.a * 20)]

## Rampe « chaud » : blanc sature -> accent -> accent assombri transparent (refroidissement).
static func _hot_ramp(col: Color) -> Gradient:
	var k: String = "hot_" + _key(col)
	if _ramps.has(k):
		return _ramps[k]
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(col.r * 0.6, col.g * 0.35, col.b * 0.35, 0.0))
	g.add_point(0.18, col.lerp(Color.WHITE, 0.45))
	g.add_point(0.55, Color(col.r, col.g, col.b, 0.85))
	_ramps[k] = g
	return g

## Rampe « fumee » : apparition rapide, teinte, extinction lente.
static func _smoke_ramp(tint: Color, alpha: float, hot: bool) -> Gradient:
	var k: String = "smk_" + _key(tint) + ("h" if hot else "") + str(int(alpha * 20))
	if _ramps.has(k):
		return _ramps[k]
	var g: Gradient = Gradient.new()
	g.set_color(0, (Color(1.0, 0.55, 0.2, 0.0) if hot else Color(tint.r, tint.g, tint.b, 0.0)))
	g.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	g.add_point(0.1, (Color(0.95, 0.5, 0.2, alpha * 0.9) if hot else Color(tint.r, tint.g, tint.b, alpha)))
	g.add_point(0.35, Color(tint.r, tint.g, tint.b, alpha))
	_ramps[k] = g
	return g

static func _free_after(g: Node, n: Node, t: float) -> void:
	var tw: Tween = g.create_tween()
	tw.tween_interval(t)
	tw.tween_callback(n.queue_free)

static func _particles(pos: Vector2, n: int, life: float) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = maxi(1, n)
	p.lifetime = life
	p.lifetime_randomness = 0.4
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 180.0                          # gerbe sur 360 deg (l'ancien defaut = 45 deg a droite)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	return p

static func _launch(g: Node, p: CPUParticles2D, layer: Node = null) -> void:
	(layer if layer != null else g.fx_layer).add_child(p)
	p.emitting = true
	_free_after(g, p, p.lifetime + 0.4)

static func conveyor_pulse(g: Node, pos: Vector2, color: Color, dir: Vector2, scale: float) -> void:
	if not ok(g): return
	var sw: Sprite2D = Sprite2D.new()
	sw.texture = Tex.shock_tex()
	sw.material = Tex.add_mat()
	sw.global_position = pos
	sw.rotation = dir.angle()
	sw.modulate = Color(color.r, color.g, color.b, 0.8)
	sw.scale = Vector2.ONE * (scale * 0.5)
	g.get("fx_layer").add_child(sw)
	var tw: Tween = sw.create_tween().set_parallel(true)
	tw.tween_property(sw, "scale", Vector2.ONE * (scale * 1.5), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sw, "position", sw.global_position + dir * 60.0 * scale, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(sw, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	_free_after(g, sw, 0.45)

# ---------------------------------------------------------------------------------------------
# couches
# ---------------------------------------------------------------------------------------------

static func _vfx_mult(g: Node, id: String, cat: String) -> float:
	if g != null and is_instance_valid(g) and g.is_inside_tree():
		var sm: Node = g.get_node_or_null("/root/SaveManager")
		if sm != null and sm.has_method("get_vfx_scale"):
			return sm.get_vfx_scale(id, cat)
	return 1.0

## 1+2 — coeur blanc anamorphique + halo colore. `size` = diametre du halo en px.
static func core(g: Node, pos: Vector2, col: Color, size: float, dur: float = 0.24) -> void:
	if not ok(g):
		return
	size *= _vfx_mult(g, "core", "impacts")
	var f: Sprite2D = Sprite2D.new()
	f.texture = Tex.flare_tex()
	f.material = Tex.add_mat()
	f.position = pos
	f.rotation = randf_range(-0.12, 0.12)
	f.modulate = col.lerp(Color.WHITE, 0.8)
	var fs: float = size * 1.25 / 128.0
	f.scale = Vector2(fs * 0.35, fs * 0.2)
	f.z_index = 2
	g.fx_layer.add_child(f)
	var tw: Tween = g.create_tween().set_parallel(true)
	tw.tween_property(f, "scale", Vector2(fs, fs * 0.8), dur * 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, dur * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(f.queue_free)
	var h: Sprite2D = Sprite2D.new()
	h.texture = Tex.glow(Color.WHITE, 128)
	h.material = Tex.add_mat()
	h.position = pos
	h.modulate = Color(col.r, col.g, col.b, 0.9)
	var hs: float = size * 1.5 / 128.0
	h.scale = Vector2.ONE * hs * 0.3
	h.z_index = 1
	g.fx_layer.add_child(h)
	var tw2: Tween = g.create_tween().set_parallel(true)
	tw2.tween_property(h, "scale", Vector2.ONE * hs, dur * 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(h, "modulate:a", 0.0, dur * 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw2.chain().tween_callback(h.queue_free)

## 3 — onde de choc a front net. r0 -> r1 (rayons px). `delay` pour etager plusieurs ondes.
static func shock(g: Node, pos: Vector2, col: Color, r0: float, r1: float, dur: float,
		delay: float = 0.0, alpha: float = 1.0) -> void:
	if not ok(g):
		return
	var vm: float = _vfx_mult(g, "shock", "shockwaves")
	r0 *= vm
	r1 *= vm
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.shock_tex()
	s.material = Tex.add_mat()
	s.position = pos
	s.scale = Vector2.ONE * (r0 / 128.0)
	s.modulate = Color(col.r, col.g, col.b, 0.0 if delay > 0.0 else alpha)
	g.fx_layer.add_child(s)
	var tw: Tween = g.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_property(s, "modulate:a", alpha, 0.01)
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (r1 / 128.0), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)

## 4 — etincelles etirees, alignees sur leur vitesse, qui refroidissent (blanc -> accent -> noir).
static func sparks(g: Node, pos: Vector2, col: Color, n: int, vmin: float, vmax: float, life: float,
		grav: Vector2 = Vector2(0.0, 320.0), size: float = 1.0) -> void:
	if not ok(g):
		return
	var p: CPUParticles2D = _particles(pos, n, life)
	p.texture = Tex.spark_tex()
	p.material = Tex.add_mat()
	p.particle_flag_align_y = true
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.damping_min = vmin * 0.6
	p.damping_max = vmax * 0.9
	p.gravity = grav
	p.scale_amount_min = 0.26 * size
	p.scale_amount_max = 0.62 * size
	p.scale_amount_curve = _shrink()
	p.color_ramp = _hot_ramp(col)
	p.z_index = 3
	_launch(g, p)

## 5a — fumee / vapeur / poussiere bruitee, rotation lente, gonfle en se dissipant.
static func smoke(g: Node, pos: Vector2, n: int, tint: Color, size: float = 1.0, alpha: float = 0.55,
		hot: bool = false, rise: float = 30.0, spread_v: float = 80.0) -> void:
	if not ok(g):
		return
	var p: CPUParticles2D = _particles(pos, n, 1.25)
	p.explosiveness = 0.8
	p.texture = Tex.puff_tex()
	p.emission_sphere_radius = 16.0 * size
	p.initial_velocity_min = spread_v * 0.3
	p.initial_velocity_max = spread_v
	p.damping_min = spread_v * 0.5
	p.damping_max = spread_v * 0.9
	p.gravity = Vector2(0.0, -rise)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -50.0
	p.angular_velocity_max = 50.0
	p.scale_amount_min = 0.38 * size
	p.scale_amount_max = 0.72 * size
	p.scale_amount_curve = _grow()
	p.color_ramp = _smoke_ramp(tint, alpha, hot)
	p.z_index = -1                            # SOUS le feu / le coeur
	_launch(g, p)

## 5b — braises : points chauds qui montent et s'eteignent lentement (incendie qui couve).
static func embers(g: Node, pos: Vector2, n: int, col: Color, size: float = 1.0) -> void:
	if not ok(g):
		return
	var p: CPUParticles2D = _particles(pos, n, 1.4)
	p.explosiveness = 0.7
	p.texture = Tex.glow(Color.WHITE, 32)
	p.material = Tex.add_mat()
	p.emission_sphere_radius = 26.0 * size
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 130.0 * size
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.gravity = Vector2(0.0, -70.0)
	p.tangential_accel_min = -40.0
	p.tangential_accel_max = 40.0
	p.scale_amount_min = 0.22
	p.scale_amount_max = 0.5
	p.scale_amount_curve = _pop()
	p.color_ramp = _hot_ramp(col)
	p.z_index = 3
	_launch(g, p)

## 5c — eclats solides (glace, metal) : tournoient, retombent (gravite = pseudo-hauteur).
static func shards(g: Node, pos: Vector2, col: Color, n: int, vmax: float, size: float = 1.0,
		additive: bool = false) -> void:
	if not ok(g):
		return
	var p: CPUParticles2D = _particles(pos, n, 0.75)
	p.explosiveness = 1.0
	p.texture = Tex.shard_tex()
	if additive:
		p.material = Tex.add_mat()
	p.initial_velocity_min = vmax * 0.35
	p.initial_velocity_max = vmax
	p.damping_min = vmax * 0.4
	p.damping_max = vmax * 0.8
	p.gravity = Vector2(0.0, 520.0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -620.0
	p.angular_velocity_max = 620.0
	p.scale_amount_min = 0.45 * size
	p.scale_amount_max = 1.0 * size
	p.scale_amount_curve = _shrink()
	var gr: Gradient = Gradient.new()
	gr.set_color(0, col.lerp(Color.WHITE, 0.35))
	gr.set_color(1, Color(col.r, col.g, col.b, 0.0))
	gr.add_point(0.7, col)
	p.color_ramp = gr
	p.z_index = 2
	_launch(g, p)

## 5d — eclairs RAMIFIES qui crepitent (3 re-tirages en 0.2 s) : halo large + filament blanc.
static func lightning(g: Node, pos: Vector2, col: Color, n: int, length: float, dur: float = 0.24) -> void:
	if not ok(g):
		return
	var root: Node2D = Node2D.new()
	root.position = pos
	root.z_index = 3
	g.fx_layer.add_child(root)
	var bolts: Array = []
	for i in n:
		var ang: float = TAU * float(i) / float(n) + randf_range(-0.45, 0.45)
		var l: float = length * randf_range(0.65, 1.1)
		var halo: Line2D = _bolt_line(10.0 * clampf(length / 90.0, 0.7, 1.6), Color(col.r, col.g, col.b, 0.28))
		var fil: Line2D = _bolt_line(2.4, col.lerp(Color.WHITE, 0.75))
		root.add_child(halo)
		root.add_child(fil)
		bolts.append([halo, fil, ang, l])
		if randf() < 0.6:                        # ramification
			var bh: Line2D = _bolt_line(5.0, Color(col.r, col.g, col.b, 0.22))
			var bf: Line2D = _bolt_line(1.4, col.lerp(Color.WHITE, 0.55))
			root.add_child(bh)
			root.add_child(bf)
			bolts.append([bh, bf, ang + randf_range(-0.9, 0.9), l * 0.45, l * randf_range(0.3, 0.55)])
	var rejitter: Callable = func() -> void:
		for b in bolts:
			var start: Vector2 = Vector2.ZERO
			if b.size() > 4:
				start = Vector2.from_angle(float(b[2])) * float(b[4]) * 0.6
			var pts: PackedVector2Array = _bolt_pts(start, float(b[2]), float(b[3]))
			(b[0] as Line2D).points = pts
			(b[1] as Line2D).points = pts
	rejitter.call()
	var tw: Tween = g.create_tween()
	tw.tween_interval(dur * 0.25)
	tw.tween_callback(rejitter)
	tw.tween_interval(dur * 0.25)
	tw.tween_callback(rejitter)
	tw.tween_property(root, "modulate:a", 0.0, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)

static func _bolt_line(w: float, c: Color) -> Line2D:
	var ln: Line2D = Line2D.new()
	ln.width = w
	ln.default_color = c
	ln.material = Tex.add_mat()
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	var wc: Curve = Curve.new()
	wc.add_point(Vector2(0.0, 1.0))
	wc.add_point(Vector2(1.0, 0.15))
	ln.width_curve = wc
	return ln

static func _bolt_pts(start: Vector2, ang: float, length: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var dir: Vector2 = Vector2.from_angle(ang)
	var perp: Vector2 = dir.orthogonal()
	var steps: int = 7
	pts.append(start)
	for s in range(1, steps + 1):
		var t: float = float(s) / float(steps)
		var j: float = randf_range(-1.0, 1.0) * length * 0.13 * (1.0 - t * 0.4)
		pts.append(start + dir * length * t + perp * j)
	return pts

## 5e — tourbillon : arcs de vent effiles qui tournent et s'ouvrent + voile de poussiere.
static func gust(g: Node, pos: Vector2, col: Color, r: float, dur: float = 0.5) -> void:
	if not ok(g):
		return
	var root: Node2D = Node2D.new()
	root.position = pos
	root.scale = Vector2.ONE * 0.45
	root.z_index = 2
	g.fx_layer.add_child(root)
	var wc: Curve = Curve.new()
	wc.add_point(Vector2(0.0, 0.0))
	wc.add_point(Vector2(0.5, 1.0))
	wc.add_point(Vector2(1.0, 0.0))
	for i in 9:
		var ln: Line2D = Line2D.new()
		ln.width = randf_range(4.0, 8.0)
		ln.width_curve = wc
		ln.default_color = Color(col.r, col.g, col.b, randf_range(0.45, 0.85)).lerp(Color.WHITE, 0.35)
		ln.material = Tex.add_mat()
		var a0: float = TAU * float(i) / 9.0 + randf_range(-0.3, 0.3)
		var rr: float = r * randf_range(0.45, 0.95)
		var arc: float = randf_range(0.7, 1.3)
		for k in 10:
			var t: float = float(k) / 9.0
			ln.add_point(Vector2.from_angle(a0 + arc * t) * rr * (0.85 + 0.15 * t))
		root.add_child(ln)
	var tw: Tween = g.create_tween().set_parallel(true)
	tw.tween_property(root, "rotation", 2.2, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector2.ONE * 1.25, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)

## 5f — projections organiques (gouttes visqueuses qui retombent).
static func goo(g: Node, pos: Vector2, col: Color, n: int, size: float = 1.0) -> void:
	if not ok(g):
		return
	var p: CPUParticles2D = _particles(pos, n, 0.7)
	p.explosiveness = 1.0
	p.texture = Tex.puff_tex()
	p.initial_velocity_min = 110.0 * size
	p.initial_velocity_max = 300.0 * size
	p.damping_min = 120.0
	p.damping_max = 220.0
	p.gravity = Vector2(0.0, 600.0)
	p.scale_amount_min = 0.1 * size
	p.scale_amount_max = 0.24 * size
	p.scale_amount_curve = _shrink()
	var gr: Gradient = Gradient.new()
	gr.set_color(0, col.lerp(Color.WHITE, 0.3))
	gr.set_color(1, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.0))
	gr.add_point(0.6, Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, 0.95))
	p.color_ramp = gr
	p.z_index = 2
	_launch(g, p)

## 6 — trace au sol (brulure, givre, flaque) dans la couche des acteurs, SOUS eux. Apparait vite,
## tient, puis s'estompe. Plafond MAX_DECALS (la plus ancienne part la premiere).
static func decal(g: Node, pos: Vector2, radius: float, tint: Color, hold: float = 1.6,
		fade: float = 1.6, additive: bool = false) -> void:
	if not ok(g):
		return
	var layer: Node = g.get("enemy_layer")
	if layer == null:
		layer = g.fx_layer
	_decals = _decals.filter(func(d: Variant) -> bool: return is_instance_valid(d))
	while _decals.size() >= MAX_DECALS:
		var old: Variant = _decals.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.scorch_tex()
	if additive:
		s.material = Tex.add_mat()
	s.position = pos
	s.rotation = randf() * TAU
	s.scale = Vector2.ONE * (radius / 64.0) * randf_range(0.9, 1.1)
	s.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	s.z_index = -3
	layer.add_child(s)
	_decals.append(s)
	var tw: Tween = g.create_tween()
	tw.tween_property(s, "modulate:a", tint.a, 0.08)
	tw.tween_interval(hold)
	tw.tween_property(s, "modulate:a", 0.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)

## Lueur residuelle au sol (metal en fusion, givre luminescent) — additive, courte.
static func afterglow(g: Node, pos: Vector2, col: Color, radius: float, dur: float = 0.9) -> void:
	if not ok(g):
		return
	var layer: Node = g.get("enemy_layer")
	if layer == null:
		layer = g.fx_layer
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.glow(Color.WHITE, 128)
	s.material = Tex.add_mat()
	s.position = pos
	s.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	s.modulate = Color(col.r, col.g, col.b, 0.55)
	s.z_index = -2
	layer.add_child(s)
	var tw: Tween = g.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(s.queue_free)

# ---------------------------------------------------------------------------------------------
# recettes completes par famille de danger du decor (appelees par Game.impact_fx)
# ---------------------------------------------------------------------------------------------

## FEU / SURCHAUFFE / BARIL : boule de feu + onde + gerbe incandescente + braises + fumee noire
## + brulure au sol.
static func recipe_fire(g: Node, pos: Vector2, col: Color, s: float) -> void:
	var fire: Color = Color(1.0, 0.55, 0.18).lerp(col, 0.35)
	core(g, pos, Color(1.0, 0.78, 0.45), 170.0 * s, 0.26)
	g.spawn_vfx("aaa_explosion", pos, randf() * TAU, 0.72 * s, Color.WHITE)
	shock(g, pos, Color(1.0, 0.7, 0.4), 18.0 * s, 175.0 * s, 0.42)
	shock(g, pos, fire, 10.0 * s, 120.0 * s, 0.55, 0.05, 0.6)
	sparks(g, pos, fire, int(26 * s), 240.0, 680.0 * s, 0.6, Vector2(0.0, 420.0), 1.1)
	embers(g, pos, int(16 * s), Color(1.0, 0.5, 0.15), s)
	smoke(g, pos, int(10 * s), Color(0.09, 0.08, 0.08), s * 1.1, 0.62, true, 34.0, 95.0 * s)
	decal(g, pos, 62.0 * s, Color(0.05, 0.04, 0.035, 0.78), 2.0, 1.8)
	afterglow(g, pos, Color(1.0, 0.42, 0.1), 44.0 * s, 1.1)

## CRYO : eclat blanc glace + double onde + eclats de glace tournoyants + vapeur froide
## rampante + plaque de givre au sol.
static func recipe_ice(g: Node, pos: Vector2, col: Color, s: float) -> void:
	var ice: Color = Color(0.6, 0.88, 1.0).lerp(col, 0.4)
	core(g, pos, ice.lerp(Color.WHITE, 0.5), 140.0 * s, 0.24)
	shock(g, pos, Color(0.9, 0.97, 1.0), 12.0 * s, 165.0 * s, 0.4)
	shock(g, pos, ice, 8.0 * s, 115.0 * s, 0.55, 0.07, 0.7)
	shards(g, pos, Color(0.82, 0.95, 1.0), int(18 * s), 420.0 * s, 1.0 * s)
	shards(g, pos, ice, int(6 * s), 260.0 * s, 0.7 * s, true)            # eclats luminescents
	sparks(g, pos, Color(0.8, 0.95, 1.0), int(10 * s), 160.0, 420.0, 0.35, Vector2.ZERO, 0.7)
	smoke(g, pos, int(9 * s), Color(0.78, 0.9, 1.0), s * 1.15, 0.32, false, -6.0, 140.0 * s)
	decal(g, pos, 70.0 * s, Color(0.72, 0.9, 1.0, 0.42), 2.2, 1.8, true)

## VENT / DEPRESSURISATION : tourbillon d'arcs + ondes de pression concentriques + poussiere
## aspiree/soufflee.
static func recipe_wind(g: Node, pos: Vector2, col: Color, s: float) -> void:
	var w: Color = col.lerp(Color(0.85, 0.95, 1.0), 0.4)
	gust(g, pos, w, 150.0 * s, 0.55)
	shock(g, pos, w.lerp(Color.WHITE, 0.4), 10.0 * s, 190.0 * s, 0.38, 0.0, 0.7)
	shock(g, pos, w, 10.0 * s, 150.0 * s, 0.45, 0.09, 0.5)
	shock(g, pos, w, 10.0 * s, 110.0 * s, 0.5, 0.18, 0.35)
	smoke(g, pos, int(10 * s), Color(0.62, 0.6, 0.56), s, 0.3, false, 0.0, 230.0 * s)
	sparks(g, pos, w, int(8 * s), 300.0, 620.0, 0.3, Vector2.ZERO, 0.6)

## BIOMECANIQUE : eclatement organique + projections visqueuses + nuage de spores + flaque.
static func recipe_bio(g: Node, pos: Vector2, col: Color, s: float) -> void:
	core(g, pos, col.lerp(Color.WHITE, 0.25), 120.0 * s, 0.22)
	g.spawn_vfx("dp_blast", pos, randf() * TAU, 0.42 * s, col)
	shock(g, pos, col, 14.0 * s, 120.0 * s, 0.45, 0.0, 0.75)
	goo(g, pos, col, int(16 * s), s)
	smoke(g, pos, int(8 * s), col.darkened(0.45), s, 0.42, false, 12.0, 70.0 * s)
	embers(g, pos, int(8 * s), col, s * 0.8)                              # spores luminescentes
	decal(g, pos, 58.0 * s, Color(col.r * 0.45, col.g * 0.45, col.b * 0.4, 0.7), 2.4, 1.8)
	afterglow(g, pos, col, 36.0 * s, 0.9)

## ENERGIE / CRISTAUX : flash + dome plasma + onde nette blanche puis coloree + eclairs ramifies
## crepitants + etincelles electriques + impact noirci.
static func recipe_energy(g: Node, pos: Vector2, col: Color, s: float) -> void:
	core(g, pos, col.lerp(Color.WHITE, 0.35), 160.0 * s, 0.24)
	g.spawn_vfx("aaa_aoe", pos, 0.0, 0.5 * s, Color.WHITE)
	shock(g, pos, Color.WHITE, 10.0 * s, 150.0 * s, 0.32, 0.0, 0.85)
	shock(g, pos, col, 10.0 * s, 185.0 * s, 0.5, 0.06, 0.8)
	lightning(g, pos, col, clampi(int(5 * s), 3, 9), 110.0 * s, 0.26)
	sparks(g, pos, col, int(16 * s), 260.0, 700.0, 0.32, Vector2.ZERO, 0.8)
	decal(g, pos, 46.0 * s, Color(0.05, 0.05, 0.08, 0.6), 1.4, 1.4)
	afterglow(g, pos, col, 40.0 * s, 0.7)

## INDUSTRIEL / CINETIQUE (caisses, presses, conteneurs...) : flash blanc sec + onde + gerbe
## d'etincelles de meulage + eclats de metal + poussiere + marque au sol.
static func recipe_kinetic(g: Node, pos: Vector2, col: Color, s: float) -> void:
	core(g, pos, Color(1.0, 0.92, 0.75), 130.0 * s, 0.2)
	g.spawn_vfx("aaa_impact", pos, randf() * TAU, 0.62 * s, col)
	shock(g, pos, col.lerp(Color.WHITE, 0.5), 12.0 * s, 130.0 * s, 0.34)
	sparks(g, pos, Color(1.0, 0.68, 0.28), int(24 * s), 260.0, 720.0 * s, 0.5, Vector2(0.0, 520.0), 1.0)
	shards(g, pos, Color(0.42, 0.42, 0.46), int(10 * s), 360.0 * s, 0.9 * s)
	smoke(g, pos, int(8 * s), Color(0.5, 0.46, 0.4), s, 0.38, false, 14.0, 120.0 * s)
	decal(g, pos, 44.0 * s, Color(0.06, 0.05, 0.05, 0.55), 1.4, 1.4)
