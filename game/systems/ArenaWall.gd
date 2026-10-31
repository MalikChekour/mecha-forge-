class_name ArenaWall
extends Node2D
## CHAMP DE CONFINEMENT (31/10, anti-fuite plan B, patron : « le mecha du joueur peut fuir indefiniment »).
##
## La carte reste INFINIE (Game.BOUNDED = false : decor en flux, pas de bord de monde). Le mur est donc un CERCLE D'ENERGIE
## MOBILE centre sur la zone de combat : son centre suit le joueur, mais au plus a DRIFT px/s (plus lent que tous les ennemis,
## ~170-250 px/s) et seulement quand il sort du coeur (DRIFT_DEAD x rayon). Consequence : on peut se repositionner librement
## dans un disque de ~1640 px (plus grand que l'ecran), mais une fuite en ligne droite finit contre le mur, qui brule
## (part des PV max par impulsion) et repousse ; le long du mur on n'avance plus qu'a DRIFT px/s -> la horde rattrape.
## ENCERCLEMENTS (5:00 et 11:30, memes fenetres que EnemySpawner.SOFT_WALLS) : le champ se recentre sur le joueur et se
## RESSERRE a R_SHRINK (visible a l'ecran meme sur mobile), reste fige pendant la fenetre, puis se relache.
## L'ennemi traverse le champ (il est de leur cote) ; seul le joueur est retenu.

const R_BASE: float = 820.0
const R_SHRINK: float = 560.0
const DRIFT: float = 125.0
const DRIFT_DEAD: float = 0.35
const SHRINKS: Array = [Vector2(300.0, 345.0), Vector2(690.0, 735.0)]   # [debut, fin] en s de partie
const SHRINK_IN: float = 5.0
const SHRINK_OUT: float = 5.0
const TICK: float = 0.5
const DMG_FRAC: Array[float] = [0.03, 0.05, 0.06, 0.07]                # part des PV max par impulsion (Facile..Veteran)
const BOUNCE: float = 70.0                                              # recul vers l'interieur a chaque impulsion
const COL_IDLE: Color = Color(0.3, 0.85, 1.0)
const COL_SHRINK: Color = Color(1.0, 0.38, 0.25)

var game: Node
var player: Node2D
var center: Vector2 = Vector2.ZERO
var radius: float = R_BASE
var shrink: float = 0.0
var active: bool = true
var _started: bool = false
var _tick_t: float = 0.0
var _near: float = 0.0
var _banner: Dictionary = {}
# mesures de banc
var touch_s: float = 0.0
var hits: int = 0
var dmg_total: float = 0.0

func setup(g: Node, p: Node2D) -> void:
	game = g
	player = p
	z_index = 3
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m

func _shrink_amount(t: float) -> float:
	for w in SHRINKS:
		var a: float = (w as Vector2).x
		var b: float = (w as Vector2).y
		if t >= a and t < b + SHRINK_OUT:
			if t < a + SHRINK_IN:
				return clampf((t - a) / SHRINK_IN, 0.0, 1.0)
			if t < b:
				return 1.0
			return clampf(1.0 - (t - b) / SHRINK_OUT, 0.0, 1.0)
	return 0.0

func _physics_process(delta: float) -> void:
	if not active or player == null or not is_instance_valid(player):
		visible = false
		return
	var t: float = GameState.run_time
	visible = t > 0.05 and GameState.alive
	var pp: Vector2 = player.global_position
	if not _started or pp.distance_to(center) > radius * 1.6:   # debut de partie / teleportation (changement de zone)
		_started = true
		center = pp
	shrink = _shrink_amount(t)
	radius = lerpf(R_BASE, R_SHRINK, shrink)
	_announce(t)
	var off: Vector2 = pp - center
	var d: float = off.length()
	var in_window: bool = false
	for w in SHRINKS:
		if t >= (w as Vector2).x and t < (w as Vector2).x + SHRINK_IN:
			in_window = true
	if in_window:
		center = center.move_toward(pp, 240.0 * delta)          # le piege se referme AUTOUR du joueur
	elif shrink <= 0.0:
		var dead: float = radius * DRIFT_DEAD
		if d > dead:
			center += off / d * minf(DRIFT * delta, d - dead)
	off = pp - center
	d = off.length()
	var limit: float = radius - 24.0
	_near = clampf((d - radius * 0.6) / (radius * 0.4), 0.0, 1.0)
	if GameState.alive and d > limit and d > 0.01:
		var n: Vector2 = off / d
		player.global_position = center + n * limit
		if "velocity" in player:
			var v: Vector2 = player.velocity
			var outward: float = v.dot(n)
			if outward > 0.0:
				player.velocity = v - n * outward
		touch_s += delta
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = TICK
			var mx: float = float(player.max_hp) if "max_hp" in player else 100.0
			var dmg: float = mx * DMG_FRAC[clampi(int(GameState.difficulty), 0, 3)]
			var hp0: float = float(player.hp) if "hp" in player else 0.0
			if player.has_method("take_damage"):
				player.take_damage(dmg, center + n * (radius + 30.0), "mur:energie")
			if "hp" in player:
				dmg_total += maxf(0.0, hp0 - float(player.hp))
			hits += 1
			player.global_position = center + n * (limit - BOUNCE)
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("aaa_shockwave", center + n * radius, 0.0, 0.5, COL_SHRINK if shrink > 0.0 else COL_IDLE)
	else:
		_tick_t = 0.0      # premier contact = impulsion immediate (c'est un mur, pas une suggestion)
	global_position = center
	queue_redraw()

func _announce(t: float) -> void:
	if game == null or not game.has_method("show_banner"):
		return
	for w in SHRINKS:
		var a: float = (w as Vector2).x
		var b: float = (w as Vector2).y
		if t >= a and t < a + 1.0 and not _banner.has(a):
			_banner[a] = true
			game.show_banner("!  CHAMP DE CONFINEMENT  !", COL_SHRINK)
		if t >= b and t < b + 1.0 and not _banner.has(b):
			_banner[b] = true
			game.show_banner("LE CHAMP SE RELACHE", COL_IDLE)

## Lisibilite : anneau net + halo large + segments d'energie qui tournent ; s'intensifie quand le joueur approche et vire au
## rouge pendant un encerclement. ~4 draw_arc par image (pas de shader, pas de texture) : sans cout sur mobile/web.
func _draw() -> void:
	var tm: float = float(Time.get_ticks_msec()) * 0.001
	var col: Color = COL_IDLE.lerp(COL_SHRINK, shrink)
	var pulse: float = 0.5 + 0.5 * sin(tm * 4.0)
	var k: float = 0.35 + 0.65 * maxf(_near, shrink)
	draw_arc(Vector2.ZERO, radius + 22.0, 0.0, TAU, 160, Color(col.r, col.g, col.b, 0.10 + 0.14 * k), 48.0)
	draw_arc(Vector2.ZERO, radius - 8.0, 0.0, TAU, 160, Color(col.r, col.g, col.b, 0.22 + 0.2 * k), 16.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 160, Color(minf(1.0, col.r + 0.4), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.3), 0.55 + 0.35 * pulse * k), 5.0)
	var segs: int = 28
	for i in segs:
		var a: float = float(i) * TAU / float(segs) + tm * (0.18 + 0.5 * shrink)
		draw_arc(Vector2.ZERO, radius + 6.0, a, a + 0.07, 5, Color(1.0, 1.0, 1.0, 0.35 + 0.5 * k), 9.0)
