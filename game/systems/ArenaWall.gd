class_name ArenaWall
extends Node2D
## GRANDE CARTE + ZONE facon PUBG (05/11 v12.19, patron : « regarde comme la carte de PUBG est grande [...] il faut que le
## joueur puisse se balader, on ne doit meme pas voir le cercle au debut »).
##
##  - CARTE BORNEE de MAP_R = 10 000 px de rayon (disque de 20 000 px, ~16 ecrans de large / ~28 de haut a 1280x720).
##    A la vitesse de base du mecha (320 px/s) la traverser prend ~62 s en ligne droite, ~75-90 s en combattant.
##    Le decor reste STREAME par PropScatter (tranches de 1000 px, 5x5 autour du joueur) : rien n'est instancie d'avance.
##    Bord dur = le bord de la carte = le tout premier cercle (R0 = MAP_R).
##  - PHASE 0 (0:00-2:00) : aucun cercle visible, aucun degat, aucun compte a rebours ; la minicarte montre la carte, les
##    points d'interet et le joueur. On explore.
##  - 8 phases ensuite : ANNONCE (prochain cercle blanc tire au hasard A L'INTERIEUR de l'actuel), attente, RETRECISSEMENT
##    progressif du cercle bleu vers le blanc. Hors zone : degats continus en % des PV max / s, sans recul, croissants.
##  - Cercle final 420 px (840 px de diametre : il remplit encore un ecran 720 et presque la largeur en portrait).
##  - POINTS D'INTERET (POI) disperses (graine par partie) : caches de ravitaillement, depots d'armes, ateliers, camps
##    d'elite. Les ennemis ne subissent pas la zone.
## touch_s / hits / dmg_total : mesures de banc (temps hors zone, ticks, degats de zone).

const MAP_R: float = 10000.0
const R0: float = MAP_R
## [annonce, debut retrecissement, fin retrecissement, rayon cible, degats hors zone en % PV max / s]
const PHASES: Array = [
	[120.0, 180.0, 240.0, 6500.0, 0.005],   # 1 : 2:00 premiere annonce, on a explore 2 min
	[270.0, 330.0, 390.0, 4200.0, 0.008],   # 2 : boss 1 a 5:00 pendant l'attente
	[420.0, 465.0, 525.0, 2700.0, 0.012],   # 3 : apres le mini-boss de 8:00
	[540.0, 580.0, 630.0, 1700.0, 0.020],   # 4 : se ferme juste apres le boss 2 (10:00)
	[645.0, 680.0, 720.0, 1100.0, 0.030],   # 5 : mini-boss 12:00 dans un cercle deja serre
	[735.0, 765.0, 805.0, 750.0, 0.045],    # 6
	[815.0, 840.0, 870.0, 520.0, 0.060],    # 7
	[875.0, 885.0, 915.0, 420.0, 0.080],    # 8 : cercle final pour le boss de 15:00
]
const DIFF_MULT: Array[float] = [0.6, 1.0, 1.2, 1.4]   # Facile / Normal / Difficile / Veteran
const TICK: float = 1.0
const COL_ZONE: Color = Color(0.3, 0.6, 1.0)
const COL_NEXT: Color = Color(1.0, 1.0, 1.0)
const COL_OUT: Color = Color(1.0, 0.25, 0.2)
const COL_EDGE: Color = Color(1.0, 0.55, 0.2)
## Points d'interet : nombre par type ; rayon de declenchement.
const POI_COUNTS: Dictionary = {"cache": 7, "arsenal": 4, "camp": 5, "atelier": 3}
const POI_LABEL: Dictionary = {"cache": "CACHE", "arsenal": "DEPOT D'ARMES", "camp": "CAMP D'ELITE", "atelier": "ATELIER"}
const POI_COL: Dictionary = {"cache": Color(1.0, 0.85, 0.3), "arsenal": Color(0.4, 1.0, 0.6), "camp": Color(1.0, 0.35, 0.3), "atelier": Color(0.45, 0.85, 1.0)}
const POI_OPEN_R: float = 230.0
const CAMP_TRIGGER_R: float = 760.0
const POI_MIN_GAP: float = 2600.0
const CAMP_WAKE_T: float = 180.0   # banc bm1 : un camp d'elite reveille des 1:30 + snipers = mort a 3:34 en Normal -> camps endormis avant 3:00

var game: Node
var player: Node2D
var map_center: Vector2 = Vector2.ZERO
var center: Vector2 = Vector2.ZERO        # cercle ACTUEL (bleu)
var radius: float = R0
var next_center: Vector2 = Vector2.ZERO
var next_radius: float = R0
var next_shown: bool = false
var phase: int = 0                        # nombre de retrecissements TERMINES
var _shrinking: int = -1
var shrink: float = 0.0
var outside: bool = false
var active: bool = true
var _started: bool = false
var _from_c: Vector2 = Vector2.ZERO
var _from_r: float = R0
var _tick_t: float = TICK
var _banner: Dictionary = {}
var _ui: CanvasLayer
var _hud: Control
var pois: Array = []                      # [{type, pos, state: 0 ferme / 1 camp actif / 2 fait, guards: []}]
var _poi_scan: float = 0.0
# mesures de banc
var touch_s: float = 0.0
var hits: int = 0
var dmg_total: float = 0.0
var poi_done: int = 0
var edge_s: float = 0.0

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

func target_center() -> Vector2:
	return next_center if next_shown else center

func target_radius() -> float:
	return next_radius if next_shown else radius

## La zone est toujours active et visible des le debut de la partie.
func zone_live() -> bool:
	return active

func cur_dps_frac() -> float:
	var z: int = phase + (1 if _shrinking >= 0 else 0)
	var i: int = clampi(z - 1, 0, PHASES.size() - 1)
	var base: float = float(PHASES[i][4]) * (0.6 if z == 0 else 1.0)
	return base * DIFF_MULT[clampi(int(GameState.difficulty), 0, 3)]

func clamp_to_map(pos: Vector2, margin: float = 60.0) -> Vector2:
	var off: Vector2 = pos - map_center
	var lim: float = MAP_R - margin
	if off.length() > lim:
		return map_center + off.normalized() * lim
	return pos

func _pick_inside(c: Vector2, r: float, r_new: float) -> Vector2:
	var a: float = randf() * TAU
	var d: float = sqrt(randf()) * maxf(0.0, r - r_new)
	return c + Vector2.from_angle(a) * d

func _reset_at(pp: Vector2) -> void:
	_started = true
	phase = 0
	_shrinking = -1
	map_center = pp
	radius = R0
	center = map_center
	next_shown = false
	_from_c = center
	_from_r = radius
	_gen_pois()

func _gen_pois() -> void:
	pois.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var order: Array = []
	for ty in POI_COUNTS.keys():
		for i in int(POI_COUNTS[ty]):
			order.append(String(ty))
	for ty in order:
		for _try in 60:
			var pos: Vector2 = map_center + Vector2.from_angle(rng.randf() * TAU) * MAP_R * sqrt(rng.randf_range(0.02, 0.8))
			if pos.distance_to(map_center) < 1400.0:
				continue
			var ok: bool = true
			for q in pois:
				if (q["pos"] as Vector2).distance_to(pos) < POI_MIN_GAP:
					ok = false
					break
			if ok:
				pois.append({"type": ty, "pos": pos, "state": 0, "guards": []})
				break

## Cible d'exploration du bot de banc : POI non visite le plus proche DANS le cercle a atteindre, sinon le centre.
func bot_goal(pp: Vector2) -> Vector2:
	var tc: Vector2 = target_center()
	var tr: float = target_radius()
	var best: Vector2 = tc
	var bd: float = 1.0e12
	for q in pois:
		if int(q["state"]) == 2:
			continue
		var p: Vector2 = q["pos"]
		if p.distance_to(tc) > tr * 0.9:
			continue
		var d: float = pp.distance_squared_to(p)
		if d < bd:
			bd = d
			best = p
	return best

func _physics_process(delta: float) -> void:
	if not active or player == null or not is_instance_valid(player):
		visible = false
		if _ui != null:
			_ui.visible = false
		return
	var t: float = GameState.run_time
	var pp: Vector2 = player.global_position
	if not _started or (t < 1.0 and pp.distance_to(map_center) > 400.0 and phase == 0):
		_reset_at(pp)   # debut de partie : la carte est centree sur le point d'apparition
	visible = t > 0.05 and GameState.alive
	_ui.visible = visible and (game == null or game.hud == null or game.hud.visible)
	# --- bord dur de la carte ---
	var mo: Vector2 = pp - map_center
	var ml: float = MAP_R - 40.0
	if mo.length() > ml:
		var n: Vector2 = mo.normalized()
		player.global_position = map_center + n * ml
		pp = player.global_position
		if "velocity" in player:
			var v: Vector2 = player.velocity
			var outward: float = v.dot(n)
			if outward > 0.0:
				player.velocity = v - n * outward
		edge_s += delta
	# --- echeancier des phases (machine a etats stricte) ---
	shrink = 0.0
	for _guard in PHASES.size() + 1:
		if phase >= PHASES.size():
			break
		var ph: Array = PHASES[phase]
		var s0: float = float(ph[1])
		var s1: float = float(ph[2])
		if _shrinking < 0:
			if t >= float(ph[0]) and not next_shown:
				next_radius = float(ph[3])
				next_center = clamp_to_map(_pick_inside(center, radius, next_radius), next_radius)
				next_shown = true
				_say("a%d" % phase, "ZONE %d/%d : NOUVELLE ZONE SURE" % [phase + 1, PHASES.size()], COL_NEXT)
			if t >= s0 and next_shown:
				_shrinking = phase
				_from_c = center
				_from_r = radius
				_say("s%d" % phase, "!  LA ZONE SE RESSERRE  !", COL_OUT)
		if _shrinking == phase:
			var k: float = clampf((t - s0) / maxf(0.01, s1 - s0), 0.0, 1.0)
			shrink = k
			center = _from_c.lerp(next_center, k)
			radius = lerpf(_from_r, next_radius, k)
			if k >= 1.0:
				next_shown = false
				_shrinking = -1
				phase += 1
				continue
		break
	# --- degats hors zone ---
	var d: float = pp.distance_to(center)
	outside = GameState.alive and zone_live() and d > radius
	if outside:
		touch_s += delta
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = TICK
			_zone_damage()
	else:
		_tick_t = minf(_tick_t + delta, TICK)
	# --- points d'interet ---
	_poi_scan -= delta
	if _poi_scan <= 0.0:
		_poi_scan = 0.2
		_poi_tick(pp)
	global_position = Vector2.ZERO
	queue_redraw()
	_hud.queue_redraw()

func _poi_tick(pp: Vector2) -> void:
	if game == null or not GameState.alive:
		return
	for q in pois:
		var st: int = int(q["state"])
		if st == 2:
			continue
		var p: Vector2 = q["pos"]
		var d: float = pp.distance_to(p)
		var ty: String = q["type"]
		if ty == "camp":
			if st == 0 and d < CAMP_TRIGGER_R and GameState.run_time >= CAMP_WAKE_T:
				q["state"] = 1
				q["guards"] = _spawn_camp(p)
				if game.has_method("show_banner"):
					game.show_banner("CAMP D'ELITE : NETTOIE-LE", POI_COL["camp"])
			elif st == 1:
				var alive_n: int = 0
				for e in q["guards"]:
					if is_instance_valid(e) and (e as Enemy).alive:
						alive_n += 1
				if alive_n == 0:
					q["state"] = 2
					poi_done += 1
					_loot(p, "camp")
					if game.has_method("show_banner"):
						game.show_banner("CAMP NETTOYE : BUTIN", POI_COL["camp"])
		elif d < POI_OPEN_R:
			q["state"] = 2
			poi_done += 1
			_loot(p, ty)

func _loot(p: Vector2, ty: String) -> void:
	if game.has_method("spawn_vfx"):
		game.spawn_vfx("aaa_shockwave", p, 0.0, 0.8, POI_COL.get(ty, Color.WHITE))
	match ty:
		"cache":
			game.spawn_bonus(p)
			game.spawn_scrap(p + Vector2(40, 0), 10)
			for i in 5:
				game.spawn_xp(p + Vector2.from_angle(float(i) * TAU / 5.0) * 70.0, 4)
			if randf() < 0.35:
				game.spawn_skill(p + Vector2(-40, 0))
		"arsenal":
			game.spawn_weapon_loan(p)
			game.spawn_scrap(p + Vector2(50, 0), 8)
		"atelier":
			game.spawn_od(p)
			game.spawn_heal(p + Vector2(50, 0))
			game.spawn_scrap(p + Vector2(-50, 0), 6)
		"camp":
			game.spawn_weapon_loan(p)
			game.spawn_skill(p + Vector2(60, 0))
			game.spawn_scrap(p + Vector2(-60, 0), 15)
			for i in 6:
				game.spawn_xp(p + Vector2.from_angle(float(i) * TAU / 6.0) * 90.0, 6)

## Camp d'elite : 1 elite du biome (PV x1,8) + 4 gardes ordinaires, poses autour du POI (pas devant le joueur).
func _spawn_camp(p: Vector2) -> Array:
	var out: Array = []
	var sp = game.get("spawner")
	if sp == null:
		return out
	var pool: Array = EnemySpawner.BIOME_POOL.get(sp.current_biome, EnemySpawner.BIOME_POOL["tech"])
	var elite_k: String = ""
	for k in pool:
		if EnemySpawner.DEFS.has(k) and int(EnemySpawner.DEFS[k].get("rank", 0)) >= 1:
			elite_k = String(k)
	if elite_k != "":
		var e: Enemy = sp.spawn_kind_at(elite_k, p)
		if e != null:
			e.hp_max *= 1.8
			e.hp = e.hp_max
			EnemyDiv.make_elite(e)
			out.append(e)
	for i in 4:
		var k2: String = String(pool[i % mini(2, pool.size())])
		var g: Enemy = sp.spawn_kind_at(k2, p + Vector2.from_angle(float(i) * TAU / 4.0 + 0.4) * 170.0)
		if g != null:
			out.append(g)
	return out

func _zone_damage() -> void:
	if not player.has_method("take_damage"):
		return
	var mx: float = float(player.max_hp) if "max_hp" in player else 100.0
	var dmg: float = mx * cur_dps_frac() * TICK
	var arm: float = clampf(float(player.armor), 0.0, 0.75) if "armor" in player else 0.0
	dmg /= maxf(0.25, 1.0 - arm)
	var hp0: float = float(player.hp) if "hp" in player else 0.0
	var ifr: float = float(player._iframe) if "_iframe" in player else 0.0
	if "_iframe" in player:
		player._iframe = 0.0
	player.take_damage(dmg, center, "zone:pubg")
	if "_iframe" in player and GameState.alive:
		player._iframe = ifr
	if "hp" in player:
		dmg_total += maxf(0.0, hp0 - float(player.hp))
	hits += 1

func _say(key: String, text: String, col: Color) -> void:
	if _banner.has(key) or game == null or not game.has_method("show_banner"):
		return
	_banner[key] = true
	print("[zone] t=%.0f %s phase=%d r=%.0f -> %.0f" % [GameState.run_time, key, phase, radius, next_radius])
	game.show_banner(text, col)

func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var pp: Vector2 = player.global_position
	var tm: float = float(Time.get_ticks_msec()) * 0.001
	var pulse: float = 0.5 + 0.5 * sin(tm * 3.0)
	var view: float = 1500.0
	# bord de carte : seulement quand on s'en approche
	if pp.distance_to(map_center) > MAP_R - view:
		draw_arc(map_center, MAP_R + 60.0, 0.0, TAU, 720, Color(COL_EDGE.r, COL_EDGE.g, COL_EDGE.b, 0.35), 120.0)
		draw_arc(map_center, MAP_R, 0.0, TAU, 720, Color(1.0, 0.75, 0.4, 0.8), 6.0)
	# points d'interet proches : balise au sol
	var font: Font = ThemeDB.fallback_font
	for q in pois:
		var p: Vector2 = q["pos"]
		if p.distance_to(pp) > view or int(q["state"]) == 2:
			continue
		var col: Color = POI_COL.get(q["type"], Color.WHITE)
		draw_circle(p, 150.0, Color(col.r, col.g, col.b, 0.08 + 0.05 * pulse))
		draw_arc(p, 150.0, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.7), 4.0)
		draw_arc(p, 60.0 + 30.0 * pulse, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.9), 3.0)
		var lb: String = String(POI_LABEL.get(q["type"], ""))
		var w: float = font.get_string_size(lb, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string_outline(font, p + Vector2(-w * 0.5, -170.0), lb, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(0, 0, 0, 0.85))
		draw_string(font, p + Vector2(-w * 0.5, -170.0), lb, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
	if not zone_live():
		return
	# zone : on ne dessine que si le bord est a portee de vue (rayon jusqu'a 10 000 px)
	var n: int = clampi(int(radius / 12.0), 96, 900)
	if absf(pp.distance_to(center) - radius) < view + 300.0:
		draw_arc(center, radius + 150.0, 0.0, TAU, n, Color(COL_ZONE.r, COL_ZONE.g, COL_ZONE.b, 0.16), 300.0)
		draw_arc(center, radius + 18.0, 0.0, TAU, n, Color(COL_ZONE.r, COL_ZONE.g, COL_ZONE.b, 0.30 + 0.15 * shrink), 36.0)
		draw_arc(center, radius, 0.0, TAU, n, Color(0.6, 0.85, 1.0, 0.7 + 0.25 * pulse), 6.0)
	if next_shown and absf(pp.distance_to(next_center) - next_radius) < view + 300.0:
		var n2: int = clampi(int(next_radius / 12.0), 96, 900)
		draw_arc(next_center, next_radius, 0.0, TAU, n2, Color(1, 1, 1, 0.95), 7.0)

## HUD : minicarte (haut droite), etat de zone (seulement apres la 1re annonce), fleche + distance, voile « HORS ZONE ».
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
		if t < float(ArenaWall.PHASES[0][0]):
			return "ZONE 1/%d  -  ATTENTE %s" % [n, _fmt(float(ArenaWall.PHASES[0][0]) - t)]
		for i in ArenaWall.PHASES.size():
			var ph: Array = ArenaWall.PHASES[i]
			if t < float(ph[1]):
				if t < float(ph[0]):
					return "ZONE %d/%d  -  STABLE" % [i, n]
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
		var tm: float = float(Time.get_ticks_msec()) * 0.001
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
		# minicarte : carte entiere tant que la zone est grande, puis vue rapprochee centree sur le joueur
		var mr: float = 64.0 * k
		var mc: Vector2 = Vector2(vp.x - mr - 16.0 * k, 72.0 * k + mr)
		var whole: bool = zone.radius > 3000.0
		var origin: Vector2 = zone.map_center if whole else pp
		var rng_w: float = ArenaWall.MAP_R * 1.04 if whole else maxf(zone.radius * 1.5, 1600.0)
		var sc: float = mr / rng_w
		draw_circle(mc, mr, Color(0.02, 0.05, 0.1, 0.75))
		draw_arc(mc + (zone.map_center - origin) * sc, ArenaWall.MAP_R * sc, 0.0, TAU, 64, Color(1.0, 0.7, 0.35, 0.6), 1.5 * k)
		for q in zone.pois:
			var qp: Vector2 = mc + ((q["pos"] as Vector2) - origin) * sc
			if qp.distance_to(mc) > mr:
				continue
			var col: Color = ArenaWall.POI_COL.get(q["type"], Color.WHITE)
			if int(q["state"]) == 2:
				col = Color(0.5, 0.5, 0.5, 0.6)
			draw_rect(Rect2(qp - Vector2(2.5, 2.5) * k, Vector2(5, 5) * k), col)
		if zone.zone_live():
			draw_arc(mc + (zone.center - origin) * sc, zone.radius * sc, 0.0, TAU, 64, Color(0.35, 0.65, 1.0, 0.95), 2.0 * k)
			if zone.next_shown:
				draw_arc(mc + (zone.next_center - origin) * sc, zone.next_radius * sc, 0.0, TAU, 64, Color(1, 1, 1, 0.95), 1.5 * k)
		draw_circle(mc + (pp - origin) * sc, 3.5 * k, Color(1.0, 0.85, 0.2))
		draw_arc(mc, mr, 0.0, TAU, 64, Color(0.6, 0.85, 1.0, 0.8), 2.0 * k)
		# etat de zone (rien pendant la phase 0)
		var st: String = _status()
		if st != "":
			var fs2: int = int(19.0 * k)
			var sw: float = font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			var sx: float = vp.x - sw - 16.0 * k
			var sy: float = 72.0 * k + 2.0 * mr + 26.0 * k
			var scol: Color = Color(1, 0.55, 0.45) if zone.shrink > 0.0 and zone.shrink < 1.0 else Color(0.8, 0.92, 1.0)
			draw_string_outline(font, Vector2(sx, sy), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, int(5.0 * k), Color(0, 0, 0, 0.85))
			draw_string(font, Vector2(sx, sy), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, scol)
		# fleche vers la zone a atteindre
		if zone.zone_live():
			var tc: Vector2 = zone.target_center()
			var tr: float = zone.target_radius()
			var dz: float = pp.distance_to(tc) - tr
			if dz > 0.0:
				var dir: Vector2 = (tc - pp).normalized()
				var c0: Vector2 = vp * 0.5 + Vector2(0.0, 40.0 * k)
				var tip: Vector2 = c0 + dir * 150.0 * k
				var side: Vector2 = dir.orthogonal() * 16.0 * k
				var col2: Color = Color(1, 0.35, 0.3, 0.95) if zone.outside else Color(1, 1, 1, 0.9)
				draw_colored_polygon(PackedVector2Array([tip + dir * 26.0 * k, tip + side, tip - side]), col2)
				var dt: String = "%d m" % int(dz / 10.0)
				var lp: Vector2 = tip - dir * 24.0 * k + Vector2(-20.0 * k, 6.0 * k)
				draw_string_outline(font, lp, dt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17.0 * k), int(4.0 * k), Color(0, 0, 0, 0.9))
				draw_string(font, lp, dt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17.0 * k), col2)
