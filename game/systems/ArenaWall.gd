class_name ArenaWall
extends Node2D
## ZONE DE BATAILLE facon PUBG (05/11, patron : « applique les principes de PUBG, comme PUBG tout simplement »).
## Remplace le champ de confinement MOBILE de la v12.17 (qui suivait le joueur et le repoussait).
##
##  - Le cercle sur est FIXE sur la carte (il ne suit PAS le joueur). Au depart, il est place au hasard autour du point
##    d'apparition (le joueur est dedans, mais pas forcement au centre).
##  - Chaque phase : ANNONCE (le prochain cercle, tire au hasard A L'INTERIEUR du cercle actuel, apparait en blanc),
##    ATTENTE (compte a rebours au HUD), puis RETRECISSEMENT progressif du cercle actuel (bleu) vers le blanc.
##  - Hors zone : degats continus (part des PV max par seconde), SANS recul, qui augmentent a chaque phase ; voile rouge
##    + « HORS ZONE » + fleche vers la zone. L'armure ne reduit pas ces degats (comme le gaz bleu de PUBG).
##  - Les ennemis ne subissent pas la zone (ils sont « du cote de la zone ») et apparaissent en partie du cote de la zone
##    sure (EnemySpawner) : la horde converge vers l'endroit ou le joueur DOIT aller -> fuir ne sert plus a rien.
##  - Cercle final 380 px de rayon (760 px de diametre) : il remplit encore la hauteur d'un ecran 720 en paysage et presque
##    la largeur en portrait mobile ; 240 (essai du 02/11) laissait un disque plus petit que les telegraphes du boss final.
## Les champs touch_s / hits / dmg_total sont gardes pour le banc (_bal_ch1.gd) : temps hors zone, ticks, degats de zone.

const R0: float = 1500.0
## [annonce, debut retrecissement, fin retrecissement, rayon cible, degats hors zone en % PV max / s pendant cette phase]
const PHASES: Array = [
	[40.0, 90.0, 140.0, 1150.0, 0.010],     # 1 : apprend la regle
	[160.0, 210.0, 270.0, 900.0, 0.015],    # 2 : apres le mini-boss de 3:00
	[340.0, 390.0, 450.0, 700.0, 0.025],    # 3 : apres le boss 1 (5:00) -> le combat de boss reste stable
	[510.0, 540.0, 590.0, 560.0, 0.035],    # 4 : se ferme AVANT le boss 2 (10:00)
	[650.0, 690.0, 750.0, 460.0, 0.050],    # 5 : encerclement 11:30
	[780.0, 820.0, 880.0, 380.0, 0.070],    # 6 : cercle final pour le boss de 15:00
]
const DIFF_MULT: Array[float] = [0.6, 1.0, 1.2, 1.4]   # Facile / Normal / Difficile / Veteran
const TICK: float = 1.0
const COL_ZONE: Color = Color(0.3, 0.6, 1.0)
const COL_NEXT: Color = Color(1.0, 1.0, 1.0)
const COL_OUT: Color = Color(1.0, 0.25, 0.2)

var game: Node
var player: Node2D
var center: Vector2 = Vector2.ZERO        # cercle ACTUEL (bleu)
var radius: float = R0
var next_center: Vector2 = Vector2.ZERO   # prochain cercle (blanc), valable si next_shown
var next_radius: float = R0
var next_shown: bool = false
var phase: int = 0                        # nombre de retrecissements commences
var shrink: float = 0.0                   # 0..1 dans le retrecissement en cours (compat)
var outside: bool = false
var active: bool = true
var _started: bool = false
var _from_c: Vector2 = Vector2.ZERO
var _from_r: float = R0
var _tick_t: float = TICK
var _banner: Dictionary = {}
var _ui: CanvasLayer
var _hud: Control
# mesures de banc
var touch_s: float = 0.0
var hits: int = 0
var dmg_total: float = 0.0

func setup(g: Node, p: Node2D) -> void:
	game = g
	player = p
	z_index = 3
	_ui = CanvasLayer.new()
	_ui.layer = 6
	add_child(_ui)
	_hud = ZoneHud.new()
	_hud.zone = self
	_ui.add_child(_hud)

## Cercle vers lequel il faut aller : le prochain s'il est annonce, sinon l'actuel.
func target_center() -> Vector2:
	return next_center if next_shown else center

func target_radius() -> float:
	return next_radius if next_shown else radius

func cur_dps_frac() -> float:
	var i: int = clampi(phase - 1, 0, PHASES.size() - 1)
	var base: float = float(PHASES[i][4]) * (0.6 if phase == 0 else 1.0)
	return base * DIFF_MULT[clampi(int(GameState.difficulty), 0, 3)]

func _pick_inside(c: Vector2, r: float, r_new: float) -> Vector2:
	var a: float = randf() * TAU
	var d: float = sqrt(randf()) * maxf(0.0, r - r_new)
	return c + Vector2.from_angle(a) * d

func _reset_at(pp: Vector2) -> void:
	_started = true
	phase = 0
	radius = R0
	center = pp + Vector2.from_angle(randf() * TAU) * randf_range(0.0, R0 * 0.35)
	next_shown = false
	_from_c = center
	_from_r = radius

func _physics_process(delta: float) -> void:
	if not active or player == null or not is_instance_valid(player):
		visible = false
		if _ui != null:
			_ui.visible = false
		return
	var t: float = GameState.run_time
	var pp: Vector2 = player.global_position
	if not _started or (t < 1.0 and pp.distance_to(center) > R0) or pp.distance_to(center) > radius * 2.5 + 1200.0:
		_reset_at(pp)   # debut de partie / teleportation (changement de secteur)
	visible = t > 0.05 and GameState.alive
	_ui.visible = visible and (game == null or game.hud == null or game.hud.visible)
	# --- echeancier des phases ---
	shrink = 0.0
	for i in PHASES.size():
		var ph: Array = PHASES[i]
		var a: float = float(ph[0])
		var s0: float = float(ph[1])
		var s1: float = float(ph[2])
		if t >= a and i >= phase and not next_shown:
			next_radius = float(ph[3])
			next_center = _pick_inside(center, radius, next_radius)
			next_shown = true
			_say("a%d" % i, "ZONE %d/%d : NOUVELLE ZONE SURE" % [i + 1, PHASES.size()], COL_NEXT)
		if t >= s0 and phase == i and next_shown:
			phase = i + 1
			_from_c = center
			_from_r = radius
			_say("s%d" % i, "!  LA ZONE SE RESSERRE  !", COL_OUT)
		if phase == i + 1 and next_shown:
			var k: float = clampf((t - s0) / maxf(0.01, s1 - s0), 0.0, 1.0)
			shrink = k
			center = _from_c.lerp(next_center, k)
			radius = lerpf(_from_r, next_radius, k)
			if k >= 1.0:
				next_shown = false
	# --- degats hors zone : continus, sans recul ---
	var d: float = pp.distance_to(center)
	outside = GameState.alive and d > radius
	if outside:
		touch_s += delta
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = TICK
			_zone_damage()
	else:
		_tick_t = minf(_tick_t + delta, TICK)
	global_position = Vector2.ZERO
	queue_redraw()
	_hud.queue_redraw()

func _zone_damage() -> void:
	if not player.has_method("take_damage"):
		return
	var mx: float = float(player.max_hp) if "max_hp" in player else 100.0
	var dmg: float = mx * cur_dps_frac() * TICK
	var arm: float = clampf(float(player.armor), 0.0, 0.75) if "armor" in player else 0.0
	dmg /= maxf(0.25, 1.0 - arm)               # le gaz ignore l'armure
	var hp0: float = float(player.hp) if "hp" in player else 0.0
	var ifr: float = float(player._iframe) if "_iframe" in player else 0.0
	if "_iframe" in player:
		player._iframe = 0.0                    # la zone ne s'arrete pas aux i-frames...
	player.take_damage(dmg, center, "zone:pubg")
	if "_iframe" in player and GameState.alive:
		player._iframe = ifr                    # ...et n'en accorde pas (sinon elle protegerait des ennemis)
	if "hp" in player:
		dmg_total += maxf(0.0, hp0 - float(player.hp))
	hits += 1

func _say(key: String, text: String, col: Color) -> void:
	if _banner.has(key) or game == null or not game.has_method("show_banner"):
		return
	_banner[key] = true
	game.show_banner(text, col)

## Monde : cercle actuel bleu (mur d'energie + voile exterieur), prochain cercle en blanc fin.
func _draw() -> void:
	var tm: float = float(Time.get_ticks_msec()) * 0.001
	var pulse: float = 0.5 + 0.5 * sin(tm * 3.0)
	var n: int = 192
	# voile bleu cote exterieur (« le gaz »)
	draw_arc(center, radius + 150.0, 0.0, TAU, n, Color(COL_ZONE.r, COL_ZONE.g, COL_ZONE.b, 0.16), 300.0)
	draw_arc(center, radius + 18.0, 0.0, TAU, n, Color(COL_ZONE.r, COL_ZONE.g, COL_ZONE.b, 0.30 + 0.15 * shrink), 36.0)
	draw_arc(center, radius, 0.0, TAU, n, Color(0.6, 0.85, 1.0, 0.7 + 0.25 * pulse), 6.0)
	var segs: int = 36
	for i in segs:
		var a: float = float(i) * TAU / float(segs) + tm * 0.12
		draw_arc(center, radius + 8.0, a, a + 0.05, 4, Color(1, 1, 1, 0.45), 8.0)
	if next_shown:
		draw_arc(next_center, next_radius, 0.0, TAU, n, Color(1, 1, 1, 0.85), 4.0)
		var dash: int = 48
		for i in dash:
			var a2: float = float(i) * TAU / float(dash)
			draw_arc(next_center, next_radius + 10.0, a2, a2 + 0.04, 3, Color(1, 1, 1, 0.5), 3.0)

## HUD de zone : minicarte (haut droite), phase + compte a rebours, fleche + distance, voile rouge « HORS ZONE ».
class ZoneHud extends Control:
	var zone: ArenaWall
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _fmt(s: float) -> String:
		var x: int = int(ceil(maxf(s, 0.0)))
		return "%d:%02d" % [x / 60, x % 60]
	func _status() -> String:
		var t: float = GameState.run_time
		var n: int = ArenaWall.PHASES.size()
		for i in ArenaWall.PHASES.size():
			var ph: Array = ArenaWall.PHASES[i]
			if t < float(ph[1]):
				if t < float(ph[0]):
					return "ZONE %d/%d  -  STABLE  %s" % [i, n, _fmt(float(ph[1]) - t)]
				return "ZONE %d/%d  -  RESSERREMENT DANS %s" % [i + 1, n, _fmt(float(ph[1]) - t)]
			if t < float(ph[2]):
				return "ZONE %d/%d  -  LA ZONE SE RESSERRE  %s" % [i + 1, n, _fmt(float(ph[2]) - t)]
		return "ZONE FINALE"
	func _draw() -> void:
		if zone == null or zone.player == null or not is_instance_valid(zone.player):
			return
		var vp: Vector2 = get_viewport_rect().size
		var k: float = minf(vp.x, vp.y) / 720.0
		var font: Font = ThemeDB.fallback_font
		var pp: Vector2 = zone.player.global_position
		var tc: Vector2 = zone.target_center()
		var tr: float = zone.target_radius()
		var tm: float = float(Time.get_ticks_msec()) * 0.001
		# voile rouge hors zone (bords de l'ecran)
		if zone.outside:
			var a: float = 0.22 + 0.12 * sin(tm * 6.0)
			var w: float = 70.0 * k
			draw_rect(Rect2(0, 0, vp.x, w), Color(1, 0.1, 0.05, a))
			draw_rect(Rect2(0, vp.y - w, vp.x, w), Color(1, 0.1, 0.05, a))
			draw_rect(Rect2(0, 0, w, vp.y), Color(1, 0.1, 0.05, a))
			draw_rect(Rect2(vp.x - w, 0, w, vp.y), Color(1, 0.1, 0.05, a))
			draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 0.1, 0.05, 0.10))
			var fs: int = int(34.0 * k)
			var txt: String = "HORS ZONE  -%d PV/s" % int(round(float(zone.player.max_hp) * zone.cur_dps_frac()))
			var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(font, Vector2((vp.x - tw) * 0.5, vp.y * 0.30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(6.0 * k), Color(0, 0, 0, 0.9))
			draw_string(font, Vector2((vp.x - tw) * 0.5, vp.y * 0.30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.35, 0.3))
		# ligne d'etat sous la barre du haut
		var st: String = _status()
		var fs2: int = int(19.0 * k)
		var sw: float = font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var sy: float = 112.0 * k
		var scol: Color = Color(1, 0.55, 0.45) if zone.shrink > 0.0 and zone.shrink < 1.0 else Color(0.8, 0.92, 1.0)
		draw_string_outline(font, Vector2((vp.x - sw) * 0.5, sy), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, int(5.0 * k), Color(0, 0, 0, 0.85))
		draw_string(font, Vector2((vp.x - sw) * 0.5, sy), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, scol)
		# fleche + distance quand on est hors du cercle a atteindre
		var dz: float = pp.distance_to(tc) - tr
		if dz > 0.0:
			var dir: Vector2 = (tc - pp).normalized()
			var c0: Vector2 = vp * 0.5 + Vector2(0.0, 40.0 * k)
			var tip: Vector2 = c0 + dir * 150.0 * k
			var side: Vector2 = dir.orthogonal() * 16.0 * k
			var col: Color = Color(1, 0.35, 0.3, 0.95) if zone.outside else Color(1, 1, 1, 0.9)
			draw_colored_polygon(PackedVector2Array([tip + dir * 26.0 * k, tip + side, tip - side]), col)
			var dt: String = "%d m" % int(dz / 10.0)
			draw_string_outline(font, tip - dir * 24.0 * k + Vector2(-20.0 * k, 6.0 * k), dt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17.0 * k), int(4.0 * k), Color(0, 0, 0, 0.9))
			draw_string(font, tip - dir * 24.0 * k + Vector2(-20.0 * k, 6.0 * k), dt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17.0 * k), col)
		# minicarte (haut droite, sous OPTIONS), centree sur le joueur, 1 px = 36 px monde
		var mr: float = 58.0 * k
		var mc: Vector2 = Vector2(vp.x - mr - 16.0 * k, 72.0 * k + mr)
		var sc: float = mr / 2100.0
		draw_circle(mc, mr, Color(0.02, 0.05, 0.1, 0.72))
		var cc: Vector2 = mc + (zone.center - pp) * sc
		draw_arc(cc, zone.radius * sc, 0.0, TAU, 64, Color(0.35, 0.65, 1.0, 0.95), 2.0 * k)
		if zone.next_shown:
			draw_arc(mc + (zone.next_center - pp) * sc, zone.next_radius * sc, 0.0, TAU, 64, Color(1, 1, 1, 0.95), 1.5 * k)
		draw_circle(mc, 3.5 * k, Color(1.0, 0.8, 0.2))
		draw_arc(mc, mr, 0.0, TAU, 64, Color(0.6, 0.85, 1.0, 0.8), 2.0 * k)
