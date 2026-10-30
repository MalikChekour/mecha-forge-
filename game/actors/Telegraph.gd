class_name Telegraph
extends Node2D
## TELEGRAPHES D'ATTAQUE (29/10, plan diversite ennemis, etape 2) : ligne / cercle / anneau / arc.
## Duree passee par EnemyDiv.tele() : Facile x1,5, Normal x1, Difficile x0,85, Veteran x0,7, jamais sous 0,4 s.
## POOL : un telegraphe n'est jamais libere, il est cache puis reutilise. Plafond LIVE_CAP en vol
## (au-dela, la competence est simplement sautee : jamais de pic de noeuds pendant une vague massive).
## Effets (params) : stun, slow + slow_t, knock (repousse), pull (attire, pendant linger), linger + dps
## (zone persistante), follow (suit un noeud), on_fire (Callable(tg, hit) appele au declenchement), tag.

const LIVE_CAP: int = 48
static var _pool: Array = []
static var live: int = 0
static var created_total: int = 0
static var reused_total: int = 0
static var fired_total: int = 0

var shape: String = "circle"
var radius: float = 80.0
var inner: float = 0.0
var length: float = 300.0
var width: float = 24.0
var dir: Vector2 = Vector2.RIGHT
var half_angle: float = 0.6
var dur: float = 0.8
var dmg: float = 0.0
var col: Color = Color(1.0, 0.3, 0.2)
var fx: Dictionary = {}
var game: Node = null
var player: Node2D = null
var follow: Node2D = null
var on_fire: Callable = Callable()
var _t: float = 0.0
var _phase: int = 0          # 0 telegraphe, 1 zone persistante, 2 malus sur le joueur (ralenti)
var _left: float = 0.0
var _tick: float = 0.0
var _active: bool = false
var _drawn_f: int = 0

static func make(g: Node, plr: Node2D, shp: String, pos: Vector2, duration: float, damage: float, color: Color, params: Dictionary = {}) -> Telegraph:
	if g == null or not is_instance_valid(g) or not ("enemy_layer" in g) or g.enemy_layer == null:
		return null
	if Telegraph.live >= LIVE_CAP:
		return null
	var t: Telegraph = null
	while t == null and not Telegraph._pool.is_empty():
		var c: Variant = Telegraph._pool.pop_back()
		if is_instance_valid(c) and (c as Node).get_parent() == g.enemy_layer and not (c as Telegraph)._active:
			t = c as Telegraph
			Telegraph.reused_total += 1
	if t == null:
		t = Telegraph.new()
		t.z_index = -2
		g.enemy_layer.add_child(t)
		Telegraph.created_total += 1
	t._arm(g, plr, shp, pos, duration, damage, color, params)
	return t

func _arm(g: Node, plr: Node2D, shp: String, pos: Vector2, duration: float, damage: float, color: Color, params: Dictionary) -> void:
	game = g
	player = plr
	shape = shp
	global_position = pos
	dur = maxf(0.05, duration)
	dmg = damage
	col = color
	fx = params
	radius = float(params.get("radius", 80.0))
	inner = float(params.get("inner", 0.0))
	length = float(params.get("length", 300.0))
	width = float(params.get("width", 24.0))
	dir = (params.get("dir", Vector2.RIGHT) as Vector2).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	half_angle = float(params.get("half", 0.6))
	var fv: Variant = params.get("follow", null)
	follow = fv as Node2D if (fv is Node2D and is_instance_valid(fv)) else null
	var cb: Variant = params.get("on_fire", null)
	on_fire = cb if cb is Callable else Callable()
	_t = 0.0
	_phase = 0
	_left = 0.0
	_tick = 0.0
	_active = true
	visible = true
	Telegraph.live += 1
	set_physics_process(true)
	queue_redraw()

func _exit_tree() -> void:
	if _active:
		_active = false
		Telegraph.live = maxi(0, Telegraph.live - 1)

func _release() -> void:
	if not _active:
		return
	_active = false
	visible = false
	follow = null
	on_fire = Callable()
	fx = {}
	set_physics_process(false)
	Telegraph.live = maxi(0, Telegraph.live - 1)
	Telegraph._pool.push_back(self)

func _physics_process(delta: float) -> void:
	if not _active:
		set_physics_process(false)
		return
	if follow != null:
		if is_instance_valid(follow) and follow.is_inside_tree():
			global_position = follow.global_position
		else:
			follow = null
	_t += delta
	match _phase:
		0:
			if _t >= dur:
				_fire()
			elif Engine.get_physics_frames() % 2 == 0:
				queue_redraw()
		1:
			_left -= delta
			_tick -= delta
			var inside: bool = _player_inside()
			if inside and player != null and is_instance_valid(player):
				var pull: float = float(fx.get("pull", 0.0))
				if pull > 0.0:
					var to_c: Vector2 = global_position - player.global_position
					if to_c.length() > 8.0:
						player.global_position += to_c.normalized() * pull * delta
				var sl: float = float(fx.get("slow", 0.0))
				if sl > 0.0 and "field_slow" in player:
					player.field_slow = minf(player.field_slow, sl)
			if _tick <= 0.0:
				_tick = 0.33
				if inside and player != null and is_instance_valid(player) and player.has_method("take_damage"):
					var dps: float = float(fx.get("dps", 0.0))
					if dps > 0.0:
						player.take_damage(dps * 0.33, global_position, "tele:" + String(fx.get("tag", "zone")))
			if Engine.get_physics_frames() % 4 == 0:
				queue_redraw()
			if _left <= 0.0:
				_release()
		2:
			_left -= delta
			if player != null and is_instance_valid(player) and "field_slow" in player:
				player.field_slow = minf(player.field_slow, float(fx.get("slow", 0.6)))
			if _left <= 0.0:
				_release()

func _player_inside() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var p: Vector2 = player.global_position - global_position
	match shape:
		"circle":
			return p.length() <= radius + 10.0
		"ring":
			var l: float = p.length()
			return l >= inner - 6.0 and l <= radius + 10.0
		"line":
			var tt: float = p.dot(dir)
			return tt >= -10.0 and tt <= length + 10.0 and absf(p.cross(dir)) <= width * 0.5 + 14.0
		"arc":
			return p.length() <= radius + 10.0 and absf(angle_difference(dir.angle(), p.angle())) <= half_angle
	return false

func _center() -> Vector2:
	match shape:
		"line":
			return global_position + dir * length * 0.5
		"arc":
			return global_position + dir * radius * 0.5
	return global_position

func _fire() -> void:
	Telegraph.fired_total += 1
	var hit: bool = _player_inside()
	var valid_p: bool = player != null and is_instance_valid(player)
	var src: Variant = fx.get("src", null)
	var src_ok: bool = src == null or (is_instance_valid(src) and not (src is Enemy and not (src as Enemy).alive))
	if on_fire.is_valid() and src_ok:   # ennemi mort avant le declenchement -> pas de rappel
		on_fire.call(self, hit)
	if hit and valid_p:
		if dmg > 0.0 and player.has_method("take_damage"):
			player.take_damage(dmg, global_position, "tele:" + String(fx.get("tag", shape)))
		var st: float = float(fx.get("stun", 0.0))
		if st > 0.0 and player.has_method("stun"):
			player.stun(st)
		var kn: float = float(fx.get("knock", 0.0))
		if kn > 0.0:
			var away: Vector2 = player.global_position - (global_position if shape != "line" else global_position + dir * clampf((player.global_position - global_position).dot(dir), 0.0, length))
			if away.length() < 1.0:
				away = dir
			player.global_position += away.normalized() * kn
	if game != null and is_instance_valid(game) and game.has_method("spawn_vfx"):
		var s: float = (radius if shape != "line" else width * 2.0) / 95.0
		game.spawn_vfx("aaa_shockwave", _center(), dir.angle(), clampf(s, 0.3, 3.2), col)
	var lin: float = float(fx.get("linger", 0.0))
	if lin > 0.0:
		_phase = 1
		_left = lin
		_tick = 0.0
		queue_redraw()
	elif hit and valid_p and float(fx.get("slow", 0.0)) > 0.0:
		_phase = 2
		_left = float(fx.get("slow_t", 1.5))
		visible = false
	else:
		_release()

func _draw() -> void:
	if not _active:
		return
	var prog: float = clampf(_t / dur, 0.0, 1.0) if _phase == 0 else 1.0
	var a_fill: float = 0.14
	var a_prog: float = 0.30
	if _phase == 1:
		a_fill = 0.22 + 0.10 * sin(_t * 9.0)
		a_prog = 0.0
	var c_fill: Color = Color(col, a_fill)
	var c_prog: Color = Color(col, a_prog)
	var c_edge: Color = Color(col, 0.9)
	if prog < 0.04:
		a_prog = 0.0
	match shape:
		"circle":
			draw_circle(Vector2.ZERO, radius, c_fill)
			if a_prog > 0.0:
				draw_circle(Vector2.ZERO, radius * prog, c_prog)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, c_edge, 3.0)
		"ring":
			var w: float = maxf(4.0, radius - inner)
			var mid: float = (radius + inner) * 0.5
			draw_arc(Vector2.ZERO, mid, 0.0, TAU, 48, c_fill, w)
			if a_prog > 0.0:
				draw_arc(Vector2.ZERO, inner + w * prog * 0.5, 0.0, TAU, 48, c_prog, w * prog)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, c_edge, 3.0)
			draw_arc(Vector2.ZERO, maxf(2.0, inner), 0.0, TAU, 40, Color(col, 0.6), 2.0)
		"line":
			var pr: Vector2 = dir.orthogonal() * width * 0.5
			var end: Vector2 = dir * length
			draw_colored_polygon(PackedVector2Array([pr, end + pr, end - pr, -pr]), c_fill)
			if a_prog > 0.0:
				var pe: Vector2 = dir * length * prog
				draw_colored_polygon(PackedVector2Array([pr, pe + pr, pe - pr, -pr]), c_prog)
			draw_polyline(PackedVector2Array([pr, end + pr, end - pr, -pr, pr]), c_edge, 2.5)
		"arc":
			var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
			var pts2: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
			var n: int = 18
			for i in n + 1:
				var v: Vector2 = dir.rotated(-half_angle + 2.0 * half_angle * float(i) / float(n))
				pts.append(v * radius)
				pts2.append(v * radius * maxf(0.05, prog))
			draw_colored_polygon(pts, c_fill)
			if a_prog > 0.0:
				draw_colored_polygon(pts2, c_prog)
			pts.append(Vector2.ZERO)
			draw_polyline(pts, c_edge, 2.5)