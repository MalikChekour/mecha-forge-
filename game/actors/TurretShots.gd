class_name TurretShot
extends Node2D
## TIRS DE TOURELLE HAUTE QUALITE VISUELLE (15/10 - REVISION MAJEURE)
## Chaque niveau possede sa grammaire propre, ses effets visuels haut de gamme, ses particules
## physiques et ses sequelles spectaculaires :
##
##   niveau 1  weld_sweep    arc de soudure ramifie qui balaie +-46°, etincelles qui rebondissent
##   niveau 2  solar_needle  rayons d'or qui convergent, puis aiguille instantanee et sillon de verre (3 s)
##   niveau 3  lob_pod       cosse qui tourne en cloche, ombre ovale, eclate en 6 epines et spores
##   niveau 4  lob_slag      obus de lave lourd qui rebondit une fois, puis flaque de magma qui bulle (5 s)
##   niveau 5  flak          salve de 4 obus traceurs qui eclatent en l'air en anneau d'eclats
##   niveau 6  orb_frost     orbe lent qui vous suit, ligne de givre, trainee de glace, nova
##   niveau 7  plasma        charge en 3 paliers (le canon vibre), boule qui se scinde en 3 eclairs
##   niveau 8  acid_burst    la poche gonfle, 3 globules qui s'etirent, flaques d'acide qui fument
##   niveau 9  missile_swarm reticule de verrouillage qui se resserre, 5 missiles verticaux puis a tete chercheuse

var style: String = ""
var game: Node = null
var plr: Node2D = null
var kind: String = ""
var dmg: float = 20.0
var src: Vector2 = Vector2.ZERO
var tgt: Vector2 = Vector2.ZERO
var t: float = 0.0
var life: float = 1.0
var delay: float = 0.0
var vel: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var phase: int = 0
var prop_ref: Node2D = null
var _trail: Array = []            # [pos, age, extra]
var _glow: Node2D = null
var _hit_done: bool = false
var _tick: float = 0.0
var _sparks: Array = []           # [pos, vel, life, max_life, floor_y, bounce_count]
var _seed: float = 0.0
var _d: Dictionary = {}

const FRAG_N: int = 16
## portee du tir droit (canons a tube fixes) selon le style
const STRAIGHT_RANGE: Dictionary = {"weld_sweep": 450.0, "lob_pod": 430.0, "lob_slag": 400.0, "flak": 470.0,
	"orb_frost": 450.0, "plasma": 440.0, "acid_burst": 340.0}

const GRAMMAR: Dictionary = {
	"weld_sweep":    ["balayage_continu", "masque_et_pointilles"],
	"solar_needle":  ["aiguille_instantanee", "cone_convergent"],
	"lob_pod":       ["cloche_legere", "ombre_ovale"],
	"lob_slag":      ["cloche_lourde_rebond", "ombre_et_fumee"],
	"flak":          ["salve_droite_eclatement_aerien", "anneaux_d_ombre"],
	"orb_frost":     ["orbe_lent_a_suivi_mou", "ligne_de_givre"],
	"plasma":        ["boule_qui_se_scinde", "charge_3_paliers_et_3_lignes"],
	"acid_burst":    ["arc_bas_etire", "poche_qui_gonfle"],
	"missile_swarm": ["verticale_puis_chercheur", "reticule_de_verrouillage"],
}

# ======================================================================= API
static func fire(shot_style: String, prop: Node2D, g: Node, p: Node2D, damage: float, k: String) -> void:
	if g == null or p == null or not is_instance_valid(p) or not ("fx_layer" in g) or g.fx_layer == null:
		return
	if prop.has_method("head_snap"):
		prop.head_snap(p.global_position)
	var s: Vector2 = _muzzle_of(prop)
	var to_p: Vector2 = p.global_position
	var lead: Vector2 = Vector2.ZERO
	if "velocity" in p:
		lead = (p.velocity as Vector2) * 0.35
	var fixed_dir: Vector2 = Vector2.ZERO
	# canon a tube fixe : le tir part DROIT dans l axe du tube, sans viser le mecha
	if prop.has_method("barrel_fixed") and prop.barrel_fixed():
		var bd: Vector2 = prop.head_dir()
		lead = Vector2.ZERO
		fixed_dir = bd
		to_p = s + bd * float(STRAIGHT_RANGE.get(shot_style, 400.0))
	match shot_style:
		"weld_sweep":
			var sh: TurretShot = _mk("weld_sweep", g, p, damage, k, s, to_p, prop)
			sh.life = 0.7 + 2.4
			sh.dir = (to_p - s).normalized()
		"solar_needle":
			var sh2: TurretShot = _mk("solar_needle", g, p, damage, k, s, to_p, prop)
			sh2.life = 1.5 + 0.45
		"lob_pod":
			var sh3: TurretShot = _mk("lob_pod", g, p, damage, k, s, to_p + lead, prop)
			sh3.life = clampf(s.distance_to(sh3.tgt) / 300.0, 0.9, 1.7)
		"lob_slag":
			var sh4: TurretShot = _mk("lob_slag", g, p, damage, k, s, to_p + lead * 0.6, prop)
			sh4.life = clampf(s.distance_to(sh4.tgt) / 190.0, 1.5, 2.4)
			sh4._d["dir2"] = (sh4.tgt - s).normalized()
		"flak":
			for i in 4:
				var off: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(25.0, 75.0)
				if fixed_dir != Vector2.ZERO:
					off = fixed_dir * randf_range(-70.0, 70.0)   # tube fixe : les obus restent DANS l axe, seule la profondeur varie
				var sh5: TurretShot = _mk("flak", g, p, damage * 0.45, k, s, to_p + lead + off, prop)
				sh5.delay = float(i) * 0.12
				sh5.life = clampf(s.distance_to(sh5.tgt) / 560.0, 0.45, 1.0)
		"orb_frost":
			var sh6: TurretShot = _mk("orb_frost", g, p, damage, k, s, to_p, prop)
			sh6.life = 0.9 + 6.0
			sh6.dir = (to_p - s).normalized()
			sh6.vel = Vector2.ZERO
		"plasma":
			var sh7: TurretShot = _mk("plasma", g, p, damage, k, s, to_p, prop)
			sh7.life = 1.35 + 2.4
			sh7.dir = (to_p - s).normalized()
		"acid_burst":
			_swell(prop)
			for i in 3:
				var off2: Vector2 = Vector2(randf_range(-34.0, 34.0), randf_range(-34.0, 34.0))
				if fixed_dir != Vector2.ZERO:
					off2 = fixed_dir * randf_range(-40.0, 40.0)
				var sh8: TurretShot = _mk("acid_burst", g, p, damage, k, s, to_p + lead * 0.5 + off2, prop)
				sh8.delay = 0.55 + float(i) * 0.16
				sh8.life = clampf(s.distance_to(sh8.tgt) / 400.0, 0.5, 1.1)
		"missile_swarm":
			var rt: TurretShot = _mk("lock", g, p, damage, k, s, to_p, prop)
			rt.life = 1.05
			for i in 5:
				var sh9: TurretShot = _mk("missile", g, p, damage * 0.4, k, s, to_p, prop)
				sh9.delay = 1.0 + float(i) * 0.11
				sh9.life = 0.4 + 3.2
				sh9._d["spread"] = float(i - 2) * 16.0

static func _muzzle_of(prop: Node2D) -> Vector2:
	if prop.has_method("has_head") and prop.has_head():
		return prop.muzzle_world()
	var h: float = 100.0
	if "_sprite" in prop and prop._sprite != null and prop._sprite.texture != null:
		h = float(prop._sprite.texture.get_height()) * absf(prop._sprite.scale.y)
	return prop.global_position + Vector2(0.0, -h * 0.28)

static func _mk(st: String, g: Node, p: Node2D, damage: float, k: String, s: Vector2, target: Vector2, prop: Node2D) -> TurretShot:
	var sh: TurretShot = TurretShot.new()
	sh.style = st
	sh.game = g
	sh.plr = p
	sh.dmg = damage
	sh.kind = k
	sh.src = s
	sh.tgt = target
	sh.prop_ref = prop
	sh.top_level = true
	sh.z_index = 30
	sh.global_position = s
	sh._seed = randf() * 100.0
	sh._d["straight"] = prop != null and prop.has_method("barrel_fixed") and prop.barrel_fixed()
	g.fx_layer.add_child(sh)
	sh._glow = ShotGlow.new()
	sh._glow.owner_shot = sh
	sh._glow.material = Tex.add_mat()
	sh.add_child(sh._glow)
	return sh

## « La poche gonfle » (ruche) : l'organe grossit organiquement, vibre puis crache
static func _swell(prop: Node2D) -> void:
	if not ("_sprite" in prop) or prop._sprite == null:
		return
	var sp: Sprite2D = prop._sprite
	var base: Vector2 = sp.scale
	var tw: Tween = prop.create_tween()
	tw.tween_property(sp, "scale", base * 1.25, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "scale", base * 0.88, 0.08)
	tw.tween_property(sp, "scale", base, 0.22).set_trans(Tween.TRANS_ELASTIC)

# ==================================================================== BOUCLE
func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		queue_free()
		return
	if delay > 0.0:
		delay -= delta
		visible = false
		return
	visible = true
	t += delta
	_step_trail(delta)
	match style:
		"weld_sweep": _step_weld(delta)
		"solar_needle": _step_solar(delta)
		"lob_pod": _step_pod(delta)
		"thorn": _step_thorn(delta)
		"lob_slag": _step_slag(delta)
		"flak": _step_flak(delta)
		"orb_frost": _step_orb(delta)
		"plasma": _step_plasma(delta)
		"bolt": _step_bolt(delta)
		"acid_burst": _step_acid(delta)
		"missile": _step_missile(delta)
		"lock": _step_lock(delta)
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()

func _step_trail(delta: float) -> void:
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i][1] += delta
		if float(_trail[i][1]) > 0.7:
			_trail.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		var sp: Array = _sparks[i]
		sp[2] = float(sp[2]) - delta
		var p: Vector2 = sp[0] as Vector2
		var v: Vector2 = sp[1] as Vector2
		v.y += 750.0 * delta # Gravite
		p += v * delta
		var floor_y: float = float(sp[4])
		var b_cnt: int = int(sp[5])
		# Rebond sur le sol
		if p.y >= floor_y and v.y > 0.0 and b_cnt < 3:
			p.y = floor_y
			v.y = -v.y * randf_range(0.55, 0.72)
			v.x = v.x * 0.82 + randf_range(-40.0, 40.0)
			sp[5] = b_cnt + 1
		sp[0] = p
		sp[1] = v
		if float(sp[2]) <= 0.0:
			_sparks.remove_at(i)

func _aim_prop(d: Vector2, hold: float = 0.2) -> void:
	if prop_ref != null and is_instance_valid(prop_ref) and prop_ref.has_method("head_override"):
		prop_ref.head_override(d, hold)

func _cur_muzzle() -> Vector2:
	if prop_ref != null and is_instance_valid(prop_ref) and prop_ref.has_method("has_head") and prop_ref.has_head():
		return prop_ref.muzzle_world()
	return src

func _hurt(amount: float, from: Vector2) -> void:
	if plr != null and is_instance_valid(plr) and plr.has_method("take_damage"):
		if GameState.run_time < 90.0:
			amount *= clampf(GameState.run_time / 90.0, 0.35, 1.0)
		plr.take_damage(amount, from, "decor:turret")

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)

## canon a tube fixe : la cloche est aplatie pour que l obus reste VISIBLEMENT dans l axe du tube
func _arc_h(h: float) -> float:
	return h * (0.28 if bool(_d.get("straight", false)) else 1.0)

func _ground(u: float) -> Vector2:
	return src.lerp(tgt, u)

func _ballistic(u: float, h: float) -> Vector2:
	return src.lerp(tgt, u) + Vector2(0.0, -h * 4.0 * u * (1.0 - u))

func _intercepted(p: Vector2, r: float) -> bool:
	if not ("projectile_layer" in game) or game.projectile_layer == null:
		return false
	for c in game.projectile_layer.get_children():
		if c is Projectile and (c as Projectile).alive and (c as Node2D).global_position.distance_to(p) <= r:
			if game.has_method("reclaim_proj"):
				game.reclaim_proj(c)
			return true
	return false

func _sfx(n: String, pitch: float = 0.06) -> void:
	Audio.sfx(n, pitch)

func _shake(v: float) -> void:
	Events.screen_shake.emit(v)

func _after(k: String, a: Vector2, r: float, dur: float, dps: float, slow: float, b: Vector2 = Vector2.ZERO) -> void:
	var af: TurretAfter = TurretAfter.new()
	af.kind = k
	af.a = a
	af.b = b
	af.r = r
	af.dur = dur
	af.dps = dps
	af.slow = slow
	af.plr = plr
	af.top_level = true
	af.z_index = -1
	af.global_position = a
	game.fx_layer.add_child(af)

func _burst(k: String, pos: Vector2, scl: float = 1.0, col: Color = Color.WHITE) -> void:
	var b: TurretBurst = TurretBurst.new()
	b.kind = k
	b.scl = scl
	b.col = col
	b.top_level = true
	b.z_index = 31
	b.global_position = pos
	game.fx_layer.add_child(b)

func _sig(name: String, pos: Vector2, scl: float, col: Color) -> void:
	if game.has_method("spawn_signature_vfx"):
		game.spawn_signature_vfx(name, pos, 0.0, scl, 0.4, col)

# ---------------------------------------------------------------- 1 SOUDEUSE (USINE)
# Arc de soudure ramifie qui balaie +-46°, etincelles qui rebondissent
func _step_weld(delta: float) -> void:
	var tell: float = 0.7
	src = _cur_muzzle()
	if t < tell:
		_aim_prop(dir, 0.25)
		if t < delta * 1.5:
			_sfx("ts_weld_a", 0.04)
		global_position = src
		return
	var u: float = clampf((t - tell) / 2.4, 0.0, 1.0)
	var max_ang: float = deg_to_rad(46.0) # +-46° exactement
	var ang: float = lerpf(-max_ang, max_ang, u)
	var d: Vector2 = dir.rotated(ang)
	_aim_prop(d, 0.25)
	global_position = src
	var tip: Vector2 = src + d * 450.0
	_d["tip"] = tip
	_d["d"] = d
	# Etincelles physiques avec rebond
	for i in 4:
		var sp_v: Vector2 = d.rotated(randf_range(-0.6, 0.6)) * randf_range(160.0, 360.0) + Vector2(0.0, randf_range(-380.0, -120.0))
		var floor_y: float = tip.y + randf_range(-6.0, 8.0)
		_sparks.append([tip, sp_v, randf_range(0.35, 0.75), 0.75, floor_y, 0])
	_tick -= delta
	if _tick <= 0.0 and plr != null and _seg_dist(plr.global_position, src, tip) < 24.0:
		_tick = 0.35
		_hurt(dmg * 0.5, src)
		_burst("plasma", plr.global_position, 0.5, Color(0.45, 0.95, 1.0))
	if t >= tell + 2.4:
		queue_free()

# --------------------------------------------------------------- 2 TERRES CALCINEES (SOLAR)
# Rayons d'or qui convergent, puis aiguille instantanee et sillon de verre qui brule 3 s
func _step_solar(delta: float) -> void:
	var charge: float = 1.5
	src = _cur_muzzle()
	global_position = src
	_aim_prop(((_d["lock"] if _d.has("lock") else tgt) - src).normalized(), 0.25)
	if t < charge:
		if t < delta * 1.5:
			_sfx("ts_solar_a", 0.03)
		if t < charge * 0.82 and plr != null:
			_d["lock"] = plr.global_position
		if not _d.has("lock"):
			_d["lock"] = tgt
		return
	if not _hit_done:
		_hit_done = true
		var lk: Vector2 = _d["lock"]
		var dd: Vector2 = (lk - src).normalized()
		var tip: Vector2 = src + dd * 560.0
		_d["tip"] = tip
		_sfx("ts_solar_b", 0.02)
		_shake(5.5)
		if plr != null and _seg_dist(plr.global_position, src, tip) < 22.0:
			_hurt(dmg, src)
		# Sillon de verre vitrifie qui brule pendant 3.0 s
		_after("glass", src, 24.0, 3.2, dmg * 0.28, 0.0, tip)
		_sig("desert_fx_rayon_solaire", lk, 1.1, Color(1.0, 0.88, 0.35))
	if t >= charge + 0.45:
		queue_free()

# ------------------------------------------------------------------ 3 RUINE VERTE (POD)
# Cosse qui tourne en cloche, ombre ovale, eclate en 6 epines et en spores
func _step_pod(delta: float) -> void:
	if t < delta * 1.5:
		_sfx("ts_pod_a", 0.06)
	var u: float = clampf(t / life, 0.0, 1.0)
	global_position = _ballistic(u, _arc_h(220.0)) # Cloche haute
	if int(t * 30.0) != int((t - delta) * 30.0):
		_trail.append([global_position, 0.0, randf() * TAU])
	if u >= 1.0:
		_hit_done = true
		_sfx("ts_pod_b", 0.05)
		_shake(3.5)
		if plr != null and plr.global_position.distance_to(tgt) <= 65.0:
			_hurt(dmg * 0.8, tgt)
		# Eclate en 6 epines radiales
		for i in 6:
			var th: TurretShot = _mk("thorn", game, plr, dmg * 0.18, kind, tgt, tgt, prop_ref)
			th.vel = Vector2.RIGHT.rotated(float(i) * TAU / 6.0 + 0.1) * 340.0
			th.life = 0.42
		# Spores toxiques
		_after("spores", tgt, 76.0, 3.0, 0.0, 0.72)
		_burst("pod", tgt, 1.1, Color(0.55, 0.95, 0.3))
		_sig("jungle_fx_cosse_epines", tgt, 0.85, Color(0.4, 0.95, 0.25))
		queue_free()

func _step_thorn(delta: float) -> void:
	global_position += vel * delta
	rotation = vel.angle()
	_trail.append([global_position, 0.0, 0.0])
	if plr != null and global_position.distance_to(plr.global_position) <= 18.0 and not _hit_done:
		_hit_done = true
		_hurt(dmg, global_position)
		_burst("pod", global_position, 0.45, Color(0.6, 0.95, 0.3))
		queue_free()
	elif t >= life:
		queue_free()

# ------------------------------------------------------------------ 4 FORGE (SLAG)
# Obus de lave lourd qui rebondit une fois, puis flaque de magma qui bulle 5 s
func _step_slag(delta: float) -> void:
	if t < delta * 1.5:
		_sfx("ts_slag_a", 0.04)
	var total1: float = life
	var hop: float = 0.6
	if phase == 0:
		var u: float = clampf(t / total1, 0.0, 1.0)
		global_position = _ballistic(u, _arc_h(310.0)) # Lourd et haut
		if randf() < 0.92:
			_trail.append([global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)), 0.0, randf_range(6.0, 12.0)])
		if u >= 1.0:
			phase = 1
			t = 0.0
			_sfx("ts_slag_b", 0.05)
			_shake(4.5)
			if plr != null and plr.global_position.distance_to(tgt) <= 58.0:
				_hurt(dmg * 0.6, tgt)
			_burst("slag", tgt, 1.1, Color(0.3, 0.85, 1.0))
			var d2: Vector2 = _d["dir2"]
			_d["tgt2"] = tgt + d2 * 130.0
	else:
		var u2: float = clampf(t / hop, 0.0, 1.0)
		var t2: Vector2 = _d["tgt2"]
		global_position = tgt.lerp(t2, u2) + Vector2(0.0, -80.0 * 4.0 * u2 * (1.0 - u2)) # Rebond
		_trail.append([global_position, 0.0, randf_range(5.0, 9.0)])
		if u2 >= 1.0:
			_sfx("ts_slag_b", 0.03)
			_shake(3.8)
			if plr != null and plr.global_position.distance_to(t2) <= 64.0:
				_hurt(dmg * 0.5, t2)
			# Zone d'impact cinétique & étincelles de soudure (zero magma)
			_after("kinetic", t2, 92.0, 4.0, dmg * 0.45, 0.0)
			_burst("slag", t2, 1.4, Color(0.3, 0.85, 1.0))
			_sig("volcanic_fx_obus_lave", t2, 1.0, Color(0.25, 0.8, 1.0))
			queue_free()

# ------------------------------------------------------------------ 5 CITE DECHUE (FLAK)
# Salve de 4 obus traceurs qui éclatent en l'air en anneau d'éclats
func _step_flak(delta: float) -> void:
	if t < delta * 1.5:
		_sfx("ts_flak_a", 0.06)
	if phase == 0:
		var u: float = clampf(t / life, 0.0, 1.0)
		global_position = src.lerp(tgt, u)
		dir = (tgt - src).normalized()
		_trail.append([global_position, 0.0, 0.0])
		if u >= 1.0:
			phase = 1
			t = 0.0
			_sfx("ts_flak_b", 0.05)
			_shake(3.0)
			_burst("smoke", tgt, 1.2, Color(0.65, 0.65, 0.68))
			_sig("swamp_fx_obus_fusee", tgt, 0.75, Color(1.0, 0.58, 0.22))
			global_position = tgt
	else:
		global_position = tgt
		# Anneau d'eclats supersonique
		var r: float = 122.0 * (1.0 - pow(1.0 - clampf(t / 0.52, 0.0, 1.0), 2.2))
		_d["r"] = r
		if not _hit_done and plr != null:
			var dp: float = plr.global_position.distance_to(tgt)
			if absf(dp - r) <= 20.0 and t < 0.5:
				_hit_done = true
				_hurt(dmg, tgt)
		if t >= 0.6:
			queue_free()

# ------------------------------------------------------------------ 6 CRYO (ORB)
# Orbe lent qui vous suit, ligne de givre, trainee de glace, nova
func _step_orb(delta: float) -> void:
	var tell: float = 0.9
	if phase == 0:
		src = _cur_muzzle()
		_aim_prop(dir, 0.3)
	else:
		if t < 0.8:
			_aim_prop((global_position - src).normalized(), 0.15)
	global_position = src if phase == 0 else global_position
	if phase == 0:
		if t < delta * 1.5:
			_sfx("ts_frost_a", 0.04)
		if t >= tell:
			phase = 1
			global_position = src
			vel = dir * 75.0
			_d["trav"] = 0.0
		return
	# Suivi lent et inexorable (sauf canon a tube fixe : l orbe file droit)
	if plr != null and not bool(_d.get("straight", false)):
		var want: Vector2 = (plr.global_position - global_position).normalized() * 115.0
		vel = vel.move_toward(want, 160.0 * delta)
	var step: Vector2 = vel * delta
	global_position += step
	_d["trav"] = float(_d.get("trav", 0.0)) + step.length()
	# Trainee de givre au sol
	if float(_d["trav"]) >= 34.0:
		_d["trav"] = 0.0
		_after("frost", global_position, 26.0, 2.5, 0.0, 0.76)
	_trail.append([global_position, 0.0, randf() * TAU])
	if _intercepted(global_position, 24.0):
		_burst("ice", global_position, 0.8, Color(0.7, 0.92, 1.0))
		_sfx("ts_frost_b", 0.12)
		queue_free()
		return
	if (plr != null and global_position.distance_to(plr.global_position) <= 24.0) or t >= life:
		_nova()

func _nova() -> void:
	var c: Vector2 = global_position
	_sfx("ts_frost_b", 0.04)
	_shake(4.0)
	if plr != null and plr.global_position.distance_to(c) <= 92.0:
		_hurt(dmg, c)
	_after("frost", c, 86.0, 4.0, 0.0, 0.52)
	_burst("ice", c, 1.35, Color(0.75, 0.95, 1.0))
	_sig("cryo_fx_orbe_givre", c, 0.95, Color(0.7, 0.9, 1.0))
	queue_free()

# ------------------------------------------------------------------ 7 NOYAU INSTABLE (PLASMA)
# Charge en 3 paliers (le canon vibre), boule qui se scinde en 3 eclairs
func _step_plasma(delta: float) -> void:
	var charge: float = 1.35
	if phase == 0:
		src = _cur_muzzle()
		global_position = src
		if t < delta * 1.5:
			_sfx("ts_plasma_a", 0.03)
		var st: int = clampi(int(t / (charge / 3.0)) + 1, 1, 3)
		_d["stage"] = st
		# Le canon vibre de plus en plus fort selon le palier
		if prop_ref != null and is_instance_valid(prop_ref) and "_sprite" in prop_ref and prop_ref._sprite != null:
			var amp: float = float(st) * 2.2
			prop_ref._sprite.position = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		if t >= charge:
			if prop_ref != null and is_instance_valid(prop_ref) and "_sprite" in prop_ref and prop_ref._sprite != null:
				prop_ref._sprite.position = Vector2.ZERO
			phase = 1
			t = 0.0
			if not bool(_d.get("straight", false)):
				dir = ((plr.global_position if plr != null else tgt) - src).normalized()
			var dist: float = src.distance_to(plr.global_position) if (plr != null and not bool(_d.get("straight", false))) else 300.0
			_d["ls"] = clampf(dist * 0.55, 150.0, 330.0)
			_d["ttot"] = float(_d["ls"]) / 320.0
		return
	if phase == 1:
		var u: float = clampf(t / float(_d["ttot"]), 0.0, 1.0)
		global_position = src + dir * float(_d["ls"]) * u
		_trail.append([global_position, 0.0, 0.0])
		_d["tele"] = float(_d["ttot"]) - t < 0.32
		if u >= 1.0:
			_sfx("ts_plasma_b", 0.04)
			_shake(3.2)
			# Se scinde en 3 eclairs
			for i in 3:
				var b: TurretShot = _mk("bolt", game, plr, dmg * 0.55, kind, global_position, tgt, prop_ref)
				b.vel = dir.rotated(float(i - 1) * 0.4) * 580.0
				b.life = 0.68
			_burst("plasma", global_position, 0.8, Color(0.5, 1.0, 0.6))
			_sig("reacteur_fx_tir_fragmente", global_position, 0.85, Color(0.45, 1.0, 0.55))
			queue_free()

func _step_bolt(delta: float) -> void:
	global_position += vel * delta
	_trail.append([global_position, 0.0, 0.0])
	if plr != null and global_position.distance_to(plr.global_position) <= 20.0 and not _hit_done:
		_hit_done = true
		_hurt(dmg, global_position)
		_burst("plasma", global_position, 0.5, Color(0.5, 1.0, 0.6))
		queue_free()
	elif t >= life:
		queue_free()

# ------------------------------------------------------------------ 8 RUCHE (ACIDE)
# La poche gonfle, 3 globules qui s'etirent, flaques d'acide qui fument
func _step_acid(delta: float) -> void:
	if t < delta * 1.5:
		_sfx("ts_acid_a", 0.08)
	var u: float = clampf(t / life, 0.0, 1.0)
	var prev: Vector2 = global_position
	global_position = _ballistic(u, _arc_h(75.0))
	dir = (global_position - prev).normalized() if prev != global_position else dir
	if int(t * 22.0) != int((t - delta) * 22.0):
		_after("drop", _ground(u), 9.0, 1.4, dmg * 0.08, 0.0)
	if u >= 1.0:
		_sfx("ts_acid_b", 0.06)
		_shake(2.5)
		if plr != null and plr.global_position.distance_to(tgt) <= 44.0:
			_hurt(dmg * 0.6, tgt)
		# Flaque d'acide caustique qui fume
		_after("acid", tgt, 58.0, 4.0, dmg * 0.28, 0.0)
		_burst("acid", tgt, 1.15, Color(0.85, 0.98, 0.25))
		_sig("ruche_fx_globule_acide", tgt, 0.75, Color(0.85, 0.98, 0.25))
		queue_free()

# ------------------------------------------------------------------ 9 CITADELLE (MISSILES)
# Reticule de verrouillage qui se resserre, 5 missiles verticaux puis a tete chercheuse
func _step_lock(_delta: float) -> void:
	global_position = plr.global_position if plr != null else tgt
	if t >= life:
		queue_free()

func _step_missile(delta: float) -> void:
	if phase == 0:
		if t < delta * 1.5:
			_sfx("ts_missile_a", 0.07)
			global_position = src + Vector2(float(_d.get("spread", 0.0)), 0.0)
			vel = Vector2(0.0, -250.0)
		global_position += vel * delta
		_trail.append([global_position, 0.0, randf_range(2.0, 5.0)])
		dir = Vector2.UP
		if t >= 0.42:
			phase = 1
			t = 0.0
		return
	# Phase 1 : navigation proportionnelle chercheuse
	if plr != null:
		var want: Vector2 = (plr.global_position - global_position).normalized()
		var cur: float = dir.angle()
		var diff: float = wrapf(want.angle() - cur, -PI, PI)
		dir = Vector2.RIGHT.rotated(cur + clampf(diff, -2.8 * delta, 2.8 * delta))
	vel = dir * 265.0
	global_position += vel * delta
	_trail.append([global_position, 0.0, randf_range(3.0, 7.0)])
	if _intercepted(global_position, 18.0):
		_burst("missile", global_position, 0.6, Color(1.0, 0.85, 0.5))
		_sfx("ts_missile_b", 0.1)
		queue_free()
		return
	if (plr != null and global_position.distance_to(plr.global_position) <= 22.0) or t >= life:
		var c: Vector2 = global_position
		_sfx("ts_missile_b", 0.05)
		_shake(3.8)
		if plr != null and plr.global_position.distance_to(c) <= 76.0:
			_hurt(dmg, c)
		_burst("missile", c, 1.0, Color(1.0, 0.72, 0.9))
		_sig("citadelle_fx_missile_plasma", c, 0.85, Color(1.0, 0.45, 0.85))
		queue_free()

# ================================================================== BIBLIOTHEQUE DE TEXTURES
# 15/10 (patron : « la qualite etait trop basique ») : plus aucun cercle/trait dessine a la main pour les
# effets. Tout passe par des textures RENDUES (tools/gen_turret_vfx.py : lumiere HDR, bloom, bruit fractal)
# dessinees en additif dans le noeud `_glow` ; seuls les ombres au sol et les fumees sont en melange normal.
static func _T(n: String) -> Texture2D:
	return Tex.get_tex("res://assets/vfx/ts/%s.png" % n)

## Sprite centre en `pos`, de taille `size`, tourne de `rot`.
static func _spr(g: CanvasItem, n: String, pos: Vector2, size: Vector2, rot: float = 0.0, col: Color = Color.WHITE) -> void:
	var tex: Texture2D = _T(n)
	if tex == null:
		return
	g.draw_set_transform(pos, rot, Vector2.ONE)
	g.draw_texture_rect(tex, Rect2(-size * 0.5, size), false, col)
	g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Image entiere etiree de `a` (queue) vers `b` (tete), epaisseur `w` (streak, spark).
static func _line(g: CanvasItem, n: String, a: Vector2, b: Vector2, w: float, col: Color = Color.WHITE) -> void:
	var tex: Texture2D = _T(n)
	var l: float = a.distance_to(b)
	if tex == null or l < 1.0:
		return
	g.draw_set_transform(a, (b - a).angle(), Vector2.ONE)
	g.draw_texture_rect(tex, Rect2(0.0, -w * 0.5, l, w), false, col)
	g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Bande de faisceau : 4 variantes empilees dans la texture, `v` choisit laquelle (scintillement).
static func _strip(g: CanvasItem, n: String, a: Vector2, b: Vector2, w: float, v: int, col: Color = Color.WHITE) -> void:
	var tex: Texture2D = _T(n)
	var l: float = a.distance_to(b)
	if tex == null or l < 1.0:
		return
	g.draw_set_transform(a, (b - a).angle(), Vector2.ONE)
	g.draw_texture_rect_region(tex, Rect2(0.0, -w * 0.5, l, w), Rect2(0.0, float(posmod(v, 4)) * 64.0, 256.0, 64.0), col)
	g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Image `frame` (0-15) d'une planche d'impact 4x4.
static func _frame(g: CanvasItem, n: String, frame: int, pos: Vector2, size: Vector2, col: Color = Color.WHITE) -> void:
	var tex: Texture2D = _T(n)
	if tex == null:
		return
	var fr: int = clampi(frame, 0, 15)
	g.draw_texture_rect_region(tex, Rect2(pos - size * 0.5, size), Rect2(float(fr % 4) * 192.0, float(int(fr / 4)) * 192.0, 192.0, 192.0), col)

# ================================================================== DESSIN PRINCIPAL
# Melange NORMAL : ombres au sol, fumees, reperes de telegraphie. Tout le reste est additif (voir _draw_glow).
func _draw() -> void:
	if delay > 0.0:
		return
	match style:
		"weld_sweep": _draw_weld()
		"lob_pod": _draw_pod()
		"lob_slag": _draw_slag()
		"flak": _draw_flak()
		"acid_burst": _draw_acid()
		"missile": _draw_missile()
		"lock": _draw_lock()

func _draw_glow(g: Node2D) -> void:
	if delay > 0.0:
		return
	match style:
		"weld_sweep": _glow_weld(g)
		"solar_needle": _glow_solar(g)
		"lob_pod": _glow_pod(g)
		"thorn": _glow_thorn(g)
		"lob_slag": _glow_slag(g)
		"flak": _glow_flak(g)
		"orb_frost": _glow_orb(g)
		"plasma": _glow_plasma(g)
		"bolt": _glow_bolt(g)
		"acid_burst": _glow_acid(g)
		"missile": _glow_missile(g)
		"lock": _glow_lock(g)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, n: int = 24) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)

## Ombre portee douce (disque noir aux bords fondus) : remplace les ellipses plates.
func _shadow(c: Vector2, rx: float, ry: float, a: float) -> void:
	var tex: Texture2D = Tex.shadow(96)
	draw_texture_rect(tex, Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, Color(1, 1, 1, a))

## Bouffees de fumee (melange normal) le long de la trainee.
func _smoke_trail(col: Color, size0: float, grow: float, alpha: float) -> void:
	var tex: Texture2D = _T("ts_smoke")
	if tex == null:
		return
	for tr in _trail:
		var ag: float = float(tr[1])
		var k: float = clampf(1.0 - ag / 0.7, 0.0, 1.0)
		var sz: float = size0 + grow * ag
		var rot: float = float(tr[2]) if tr.size() > 2 else 0.0
		draw_set_transform(to_local(tr[0] as Vector2), rot, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color(col.r, col.g, col.b, alpha * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Lueurs le long de la trainee (additif).
func _glow_trail(g: CanvasItem, n: String, col: Color, size0: float, alpha: float) -> void:
	for tr in _trail:
		var ag: float = float(tr[1])
		var k: float = clampf(1.0 - ag / 0.7, 0.0, 1.0)
		_spr(g, n, to_local(tr[0] as Vector2), Vector2.ONE * size0 * (0.35 + 0.65 * k), 0.0, Color(col.r, col.g, col.b, alpha * k * k))

# ---------------------------------------------------------------- DESSIN 1 SOUDEUSE
func _draw_weld() -> void:
	if t >= 0.7:
		return
	var o: Vector2 = to_local(src)
	var max_ang: float = deg_to_rad(46.0)
	var k: float = clampf(t / 0.7, 0.0, 1.0)
	var a0: Vector2 = o + dir.rotated(-max_ang) * 320.0
	var a1: Vector2 = o + dir.rotated(max_ang) * 320.0
	# secteur de balayage +-46° (gabarit lisible, fondu avec grille de calibres)
	var sector: PackedVector2Array = PackedVector2Array([o])
	for i in 17:
		sector.append(o + dir.rotated(lerpf(-max_ang, max_ang, float(i) / 16.0)) * 320.0)
	draw_colored_polygon(sector, Color(0.25, 0.75, 1.0, 0.08 * k))
	for i in [4, 8, 12]:
		var g_ang: float = lerpf(-max_ang, max_ang, float(i) / 16.0)
		draw_line(o, o + dir.rotated(g_ang) * 320.0, Color(0.35, 0.85, 1.0, 0.2 * k), 1.0)
	draw_line(o, a0, Color(0.45, 0.95, 1.0, 0.55 * k), 1.8, true)
	draw_line(o, a1, Color(0.45, 0.95, 1.0, 0.55 * k), 1.8, true)
	draw_arc(o, 320.0, dir.angle() - max_ang, dir.angle() + max_ang, 32, Color(0.45, 0.95, 1.0, 0.5 * k), 2.2, true)

func _glow_weld(g: Node2D) -> void:
	var o: Vector2 = to_local(src)
	if t < 0.7:
		var k: float = clampf(t / 0.7, 0.0, 1.0)
		var pulse: float = 0.6 + 0.4 * sin(t * 40.0)
		_spr(g, "ts_flare", o, Vector2.ONE * (65.0 + 95.0 * k), t * 2.0, Color(0.6, 0.95, 1.0, (0.35 + 0.5 * k) * pulse))
		return
	if not _d.has("tip"):
		return
	var tip: Vector2 = to_local(_d["tip"])
	var perp: Vector2 = (tip - o).normalized().orthogonal()
	var n: int = 14
	var pts: PackedVector2Array = PackedVector2Array()
	for i in n + 1:
		var f: float = float(i) / float(n)
		var jit: float = 0.0 if (i == 0 or i == n) else (sin(t * 38.0 + float(i) * 2.5) * 6.0 + randf_range(-4.0, 4.0))
		pts.append(o.lerp(tip, f) + perp * jit)
	var v: int = int(t * 28.0)
	for i in n:
		_strip(g, "ts_beam_weld", pts[i], pts[i + 1], 56.0, v + i)
		g.draw_line(pts[i], pts[i + 1], Color(1.0, 1.0, 1.0, 0.95), 2.4)
	# ramifications qui jaillissent du tronc
	for i in 5:
		var bi: int = clampi(int(float(n) * (0.2 + float(i) * 0.15)), 2, n - 2)
		var root: Vector2 = pts[bi]
		var bd: Vector2 = perp * (1.0 if i % 2 == 0 else -1.0) * randf_range(28.0, 52.0) + (tip - o).normalized() * randf_range(12.0, 36.0)
		var mid: Vector2 = root + bd * 0.55 + perp * randf_range(-9.0, 9.0)
		var end_pt: Vector2 = root + bd
		_strip(g, "ts_beam_weld", root, mid, 26.0, v + i * 3, Color(1, 1, 1, 0.85))
		_strip(g, "ts_beam_weld", mid, end_pt, 18.0, v + i * 5, Color(1, 1, 1, 0.7))
		g.draw_line(root, mid, Color(1.0, 1.0, 1.0, 0.8), 1.5)
		g.draw_line(mid, end_pt, Color(0.7, 0.95, 1.0, 0.65), 1.2)
	# ecrasement de lumiere : bouche + point d'impact
	_spr(g, "ts_flare", o, Vector2.ONE * (110.0 + randf() * 16.0), t * 3.0, Color(0.75, 0.98, 1.0, 0.95))
	_spr(g, "ts_flare", tip, Vector2.ONE * (165.0 + randf() * 26.0), t * -2.0, Color(1.0, 0.92, 0.75, 0.95))
	_spr(g, "ts_flare", tip, Vector2.ONE * 52.0, t * 5.0, Color.WHITE)
	_spr(g, "ts_ring", tip, Vector2.ONE * (64.0 + 28.0 * fmod(t * 3.0, 1.0)), 0.0, Color(1.0, 0.7, 0.3, 0.5))
	# etincelles : traits effiles orientes selon leur vitesse avec pointe incandescente
	for sp in _sparks:
		var pc: Vector2 = to_local(sp[0] as Vector2)
		var sv: Vector2 = sp[1] as Vector2
		var fs: float = clampf(float(sp[2]) / float(sp[3]), 0.0, 1.0)
		_line(g, "ts_spark", pc - sv.normalized() * (12.0 + 30.0 * fs), pc, 4.5 + 9.0 * fs, Color(1.0, 0.82, 0.45, fs))
		_spr(g, "ts_flare", pc, Vector2.ONE * (10.0 + 14.0 * fs), 0.0, Color(1.0, 0.95, 0.8, fs))

# ---------------------------------------------------------------- DESSIN 2 TERRES CALCINEES
func _glow_solar(g: Node2D) -> void:
	var o: Vector2 = to_local(src)
	if t < 1.5:
		var u: float = clampf(t / 1.5, 0.0, 1.0)
		var lk: Vector2 = to_local(_d["lock"] if _d.has("lock") else tgt)
		var rr: float = lerpf(320.0, 24.0, u * u)
		# 16 rayons d'or qui convergent sur la cible avec acceleration angulaire
		for i in 16:
			var a: float = TAU * float(i) / 16.0 + u * 1.6
			var r_len: float = rr + lerpf(180.0, 40.0, u)
			var from: Vector2 = lk + Vector2.RIGHT.rotated(a) * r_len
			_strip(g, "ts_beam_solar", from, lk, 6.0 + 24.0 * u, i, Color(1, 1, 1, 0.12 + 0.6 * u))
		# iris : doubles anneaux qui se resserrent
		_spr(g, "ts_ring", lk, Vector2.ONE * rr * 2.0, u * 2.0, Color(1.0, 0.85, 0.4, 0.3 + 0.6 * u))
		_spr(g, "ts_ring", lk, Vector2.ONE * rr * 1.25, -u * 2.8, Color(1.0, 0.7, 0.25, 0.25 + 0.55 * u))
		_spr(g, "ts_flare", lk, Vector2.ONE * (55.0 + 210.0 * u), u * 2.5, Color(1.0, 0.92, 0.55, 0.35 + 0.75 * u))
		# lentille du miroir qui se charge
		_spr(g, "ts_flare", o, Vector2.ONE * (65.0 + 160.0 * u), -u * 3.5, Color(1.0, 0.95, 0.65, 0.4 + 0.65 * u))
		return
	if _d.has("tip"):
		var tip: Vector2 = to_local(_d["tip"])
		var f: float = clampf(1.0 - (t - 1.5) / 0.45, 0.0, 1.0)
		var b_angle: float = (tip - o).angle()
		# Faisceau solaire orbital triple couche avec filament blanc pur
		_strip(g, "ts_beam_solar", o, tip, 88.0 * f + 12.0, int(t * 40.0), Color(1, 1, 1, f))
		_strip(g, "ts_beam_solar", o, tip, 28.0 * f + 5.0, int(t * 40.0) + 2, Color(1, 1, 1, f))
		g.draw_line(o, tip, Color(1.0, 1.0, 1.0, f * 0.98), 3.4)
		_spr(g, "ts_flare", tip, Vector2(380.0 * f + 50.0, 110.0 * f + 20.0), b_angle, Color(1.0, 0.92, 0.6, f))
		_spr(g, "ts_flare", o, Vector2(220.0 * f + 30.0, 75.0 * f + 15.0), b_angle, Color(1.0, 0.95, 0.75, f))
		_spr(g, "ts_ring", tip, Vector2.ONE * (380.0 * (1.0 - f) + 45.0), 0.0, Color(1.0, 0.82, 0.35, 0.85 * f))

# ---------------------------------------------------------------- DESSIN 3 RUINE VERTE
func _draw_pod() -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var gp: Vector2 = to_local(_ground(u))
	var tp: Vector2 = to_local(tgt)
	_shadow(tp, 24.0 + 44.0 * u, 12.0 + 22.0 * u, 0.28 + 0.52 * u)
	_shadow(gp, 17.0 * (1.0 - u * 0.3), 8.5 * (1.0 - u * 0.3), 0.42)

func _glow_pod(g: Node2D) -> void:
	_glow_trail(g, "ts_flare", Color(0.65, 1.0, 0.35), 50.0, 0.65)
	_spr(g, "ts_pod_head", Vector2.ZERO, Vector2.ONE * 96.0, t * 12.0, Color.WHITE)

func _glow_thorn(g: Node2D) -> void:
	_line(g, "ts_streak", Vector2(-50, 0), Vector2(12, 0), 16.0, Color(0.75, 1.0, 0.45, 0.95))
	_spr(g, "ts_flare", Vector2(8, 0), Vector2.ONE * 38.0, 0.0, Color(0.9, 1.0, 0.65, 0.95))

# ---------------------------------------------------------------- DESSIN 4 FORGE
func _draw_slag() -> void:
	var tp: Vector2 = to_local(tgt)
	if phase == 0:
		var u: float = clampf(t / life, 0.0, 1.0)
		_shadow(tp, 32.0 + 42.0 * u, 15.0 + 21.0 * u, 0.32 + 0.48 * u)
	else:
		_shadow(to_local(global_position + Vector2(0.0, 40.0)), 24.0, 11.0, 0.38)
	_smoke_trail(Color(0.25, 0.35, 0.45), 24.0, 48.0, 0.45)

func _glow_slag(g: Node2D) -> void:
	_glow_trail(g, "ts_flare", Color(0.25, 0.85, 1.0), 44.0, 0.75)
	var pulse: float = 1.0 + 0.07 * sin(t * 32.0)
	_spr(g, "ts_slag_head", Vector2.ZERO, Vector2.ONE * 96.0 * pulse, t * 3.5, Color(0.35, 0.9, 1.0))

# ---------------------------------------------------------------- DESSIN 5 CITE DECHUE
func _draw_flak() -> void:
	if phase == 0:
		var tp: Vector2 = to_local(tgt)
		var k: float = clampf(t / life, 0.0, 1.0)
		_shadow(tp, 20.0 + 12.0 * k, 10.0 + 6.0 * k, 0.28 + 0.32 * k)
	_smoke_trail(Color(0.5, 0.48, 0.46), 15.0, 38.0, 0.38)

func _glow_flak(g: Node2D) -> void:
	if phase == 0:
		var tp: Vector2 = to_local(tgt)
		var k: float = clampf(t / life, 0.0, 1.0)
		_spr(g, "ts_ring", tp, Vector2.ONE * 244.0, 0.0, Color(1.0, 0.8, 0.45, 0.18 + 0.4 * k))
		_spr(g, "ts_flak_head", Vector2.ZERO, Vector2(180, 180), dir.angle(), Color.WHITE)
		_spr(g, "ts_flare", Vector2.ZERO, Vector2.ONE * 45.0, dir.angle(), Color(1.0, 0.9, 0.7, 0.9))
	else:
		var r: float = float(_d.get("r", 0.0))
		var f: float = clampf(1.0 - t / 0.6, 0.0, 1.0)
		_spr(g, "ts_ring", Vector2.ZERO, Vector2.ONE * (r * 2.0 + 26.0), 0.0, Color(1.0, 0.85, 0.55, 0.88 * f))
		for i in FRAG_N:
			var a: float = TAU * float(i) / float(FRAG_N) + 0.2
			var d_v: Vector2 = Vector2.RIGHT.rotated(a)
			_line(g, "ts_spark", d_v * maxf(0.0, r - 34.0), d_v * r, 10.0, Color(1.0, 0.88, 0.55, f))
			_spr(g, "ts_flare", d_v * r, Vector2.ONE * 24.0, 0.0, Color(1.0, 0.96, 0.82, f))
		_spr(g, "ts_flare", Vector2.ZERO, Vector2.ONE * (70.0 + 70.0 * f), 0.0, Color(1.0, 0.82, 0.48, 0.75 * f))

# ---------------------------------------------------------------- DESSIN 6 CRYO
func _glow_orb(g: Node2D) -> void:
	var o: Vector2 = to_local(src)
	if phase == 0:
		var k: float = clampf(t / 0.9, 0.0, 1.0)
		var e: Vector2 = o + dir * minf(src.distance_to(tgt), 430.0) * k
		_line(g, "ts_streak", o, e, 32.0, Color(0.7, 0.95, 1.0, 0.6))
		for i in 12:
			var f_l: float = float(i) / 12.0
			if f_l > k:
				break
			var p: Vector2 = o.lerp(e, f_l)
			var pr: Vector2 = dir.orthogonal() * (15.0 + 11.0 * sin(float(i) * 1.8))
			_line(g, "ts_spark", p - pr, p + pr, 9.0, Color(0.88, 0.98, 1.0, 0.75))
		_spr(g, "ts_flare", o, Vector2.ONE * (55.0 + 75.0 * k), t * 2.0, Color(0.7, 0.95, 1.0, 0.45 + 0.55 * k))
		return
	_glow_trail(g, "ts_flare", Color(0.7, 0.95, 1.0), 54.0, 0.5)
	_spr(g, "ts_ring", Vector2.ZERO, Vector2.ONE * 100.0, t * 1.4, Color(0.7, 0.92, 1.0, 0.45))
	_spr(g, "ts_frost_head", Vector2.ZERO, Vector2.ONE * 118.0, t * 2.4, Color.WHITE)

# ---------------------------------------------------------------- DESSIN 7 NOYAU INSTABLE
func _glow_plasma(g: Node2D) -> void:
	var o: Vector2 = to_local(src)
	if phase == 0:
		var st: int = int(_d.get("stage", 1))
		var sz: float = 44.0 + 36.0 * float(st)
		_spr(g, "ts_plasma_head", o, Vector2.ONE * (sz + randf() * 6.0), t * 4.0, Color(1, 1, 1, 0.6 + 0.15 * float(st)))
		for k in st:
			_spr(g, "ts_ring", o, Vector2.ONE * (64.0 + float(k) * 42.0 + randf() * 5.0), t * (3.0 + float(k)) * (1.0 if k % 2 == 0 else -1.0), Color(0.5, 1.0, 0.7, 0.65))
		for i in 2 + st * 2:
			var a: float = randf() * TAU
			var arc_len: float = 40.0 + 26.0 * float(st)
			var arc_end: Vector2 = o + Vector2.RIGHT.rotated(a) * arc_len
			_strip(g, "ts_beam_plasma", o, arc_end, 15.0, i + int(t * 30.0), Color(1, 1, 1, 0.9))
			g.draw_line(o, arc_end, Color(1.0, 1.0, 1.0, 0.85), 1.6)
		return
	_glow_trail(g, "ts_flare", Color(0.45, 1.0, 0.65), 58.0, 0.6)
	if _d.get("tele", false):
		for i in 3:
			var dd: Vector2 = dir.rotated(float(i - 1) * 0.4)
			_strip(g, "ts_beam_plasma", Vector2.ZERO, dd * 360.0, 12.0, i, Color(1, 1, 1, 0.4))
			g.draw_line(Vector2.ZERO, dd * 360.0, Color(0.6, 1.0, 0.8, 0.5), 1.4)
	_spr(g, "ts_plasma_head", Vector2.ZERO, Vector2.ONE * (124.0 + randf() * 8.0), t * 5.0, Color.WHITE)

func _glow_bolt(g: Node2D) -> void:
	var a: float = vel.angle() - rotation
	_spr(g, "ts_bolt_head", Vector2.ZERO, Vector2(156, 156), a, Color.WHITE)
	_glow_trail(g, "ts_flare", Color(0.45, 1.0, 0.65), 32.0, 0.45)

# ---------------------------------------------------------------- DESSIN 8 RUCHE
func _draw_acid() -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	_shadow(to_local(_ground(u)), 15.0, 7.5, 0.34)

func _glow_acid(g: Node2D) -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var sp: float = 1.0 + 1.2 * sin(u * PI)
	g.draw_set_transform(Vector2.ZERO, dir.angle(), Vector2(sp, 1.0 / sqrt(sp)))
	var tex: Texture2D = _T("ts_acid_head")
	if tex != null:
		g.draw_texture_rect(tex, Rect2(-48.0, -48.0, 96.0, 96.0), false, Color.WHITE)
	g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- DESSIN 9 CITADELLE
func _draw_lock() -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var rr: float = lerpf(135.0, 36.0, u)
	var hot: bool = u >= 0.85
	var col_lock: Color = Color(1.0, 0.82, 0.28, 0.45 + 0.55 * u) if not hot else (Color(1.0, 0.2, 0.2, 0.95) if int(t * 18.0) % 2 == 0 else Color(1.0, 0.8, 0.2, 0.95))
	for i in 4:
		var a: float = float(i) * PI * 0.5 + u * 1.5
		draw_arc(Vector2.ZERO, rr, a, a + 0.85, 12, col_lock, 3.0, true)
		draw_line(Vector2.RIGHT.rotated(a + 0.42) * (rr - 10.0), Vector2.RIGHT.rotated(a + 0.42) * (rr + 10.0), col_lock, 2.4, true)
	draw_line(Vector2(-12, 0), Vector2(12, 0), col_lock, 1.8)
	draw_line(Vector2(0, -12), Vector2(0, 12), col_lock, 1.8)

func _glow_lock(g: Node2D) -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var rr: float = lerpf(135.0, 36.0, u)
	var hot: bool = u >= 0.85
	var col_glow: Color = Color(1.0, 0.3, 0.3, 0.75) if hot else Color(1.0, 0.8, 0.3, 0.28 + 0.42 * u)
	_spr(g, "ts_ring", Vector2.ZERO, Vector2.ONE * rr * 2.2, u * 1.4, col_glow)
	_spr(g, "ts_flare", Vector2.ZERO, Vector2.ONE * (32.0 + 44.0 * u), 0.0, Color(1.0, 0.3, 0.25, 0.95 * u))

func _draw_missile() -> void:
	_smoke_trail(Color(0.92, 0.93, 0.96), 15.0, 42.0, 0.52)

func _glow_missile(g: Node2D) -> void:
	_glow_trail(g, "ts_flare", Color(0.6, 0.9, 1.0), 36.0, 0.55)
	_spr(g, "ts_missile_head", Vector2.ZERO, Vector2(156, 156), dir.angle(), Color(1, 1, 1, 1))

# ================================================================== CLASSES AUXILIAIRES
class ShotGlow extends Node2D:
	var owner_shot: TurretShot = null
	func _draw() -> void:
		if owner_shot != null and is_instance_valid(owner_shot):
			owner_shot._draw_glow(self)

## Residu au sol : decor en melange normal (croute, flaque) + emissif additif par-dessus.
class TurretAfter extends Node2D:
	var kind: String = ""
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2.ZERO
	var r: float = 50.0
	var dur: float = 3.0
	var dps: float = 0.0
	var slow: float = 0.0
	var plr: Node2D = null
	var t: float = 0.0
	var _tick: float = 0.0
	var _seed: float = 0.0
	var _emit: AfterGlow = null

	func _ready() -> void:
		_seed = randf() * 50.0
		_emit = AfterGlow.new()
		_emit.owner_after = self
		_emit.material = Tex.add_mat()
		add_child(_emit)

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		if plr != null and is_instance_valid(plr):
			var inside: bool = false
			if kind == "glass":
				inside = Geometry2D.get_closest_point_to_segment(plr.global_position, a, b).distance_to(plr.global_position) <= r
			else:
				inside = plr.global_position.distance_to(a) <= r
			if inside:
				if slow > 0.0 and "field_slow" in plr:
					plr.field_slow = minf(float(plr.field_slow), 1.0 - slow if slow > 0.4 else slow)
				_tick -= delta
				if dps > 0.0 and _tick <= 0.0 and plr.has_method("take_damage"):
					_tick = 0.25
					plr.take_damage(dps * 0.25, a, "decor:laser_rotatif")
		queue_redraw()
		if _emit != null:
			_emit.queue_redraw()

	func _fade() -> float:
		return clampf((dur - t) / 0.8, 0.0, 1.0) * clampf(t / 0.12, 0.0, 1.0)

	func _decal(n: String, scale_k: float, alpha: float) -> void:
		var tex: Texture2D = TurretShot._T(n)
		if tex == null:
			return
		var sz: float = r * 2.0 * scale_k
		draw_set_transform(Vector2.ZERO, _seed, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw() -> void:
		var f: float = _fade()
		match kind:
			"magma", "kinetic":
				_decal("ts_frost_decal", 1.1, 0.65 * f)
				_steam(Color(0.35, 0.55, 0.75), f * 0.35, 6, 24.0)
			"acid":
				_decal("ts_acid_decal", 1.2, 0.9 * f)
				_steam(Color(0.78, 0.95, 0.4), f * 0.5, 7, 34.0)
			"drop":
				_decal("ts_acid_decal", 1.7, 0.85 * f)
			"frost":
				_decal("ts_frost_decal", 1.25, 0.9 * f)
			"spores":
				_decal("ts_spores_decal", 1.3, 1.0 * f)
				_steam(Color(0.55, 0.9, 0.3), f * 0.4, 8, 20.0)
			"glass":
				var tex: Texture2D = TurretShot._T("ts_glass_decal")
				var lb: Vector2 = b - a
				if tex != null and lb.length() > 1.0:
					draw_set_transform(Vector2.ZERO, lb.angle(), Vector2.ONE)
					draw_texture_rect(tex, Rect2(0.0, -r * 1.7, lb.length(), r * 3.4), false, Color(1, 1, 1, 0.95 * f))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## fumees / vapeurs qui montent de la flaque (melange normal, douces)
	func _steam(col: Color, alpha: float, n: int, rise: float) -> void:
		var tex: Texture2D = TurretShot._T("ts_smoke")
		if tex == null:
			return
		for i in n:
			var ph: float = fmod(t * 0.55 + float(i) / float(n) + _seed * 0.1, 1.0)
			var pos: Vector2 = Vector2.RIGHT.rotated(float(i) * 2.4 + _seed) * r * 0.55 * (0.4 + fmod(float(i) * 0.37, 0.6)) + Vector2(0.0, -ph * rise)
			var sz: float = 26.0 + 40.0 * ph
			draw_texture_rect(tex, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(col.r, col.g, col.b, alpha * sin(ph * PI)))

	func draw_emit(g: CanvasItem) -> void:
		var f: float = _fade()
		var pulse: float = 0.8 + 0.2 * sin(t * 5.0 + _seed)
		match kind:
			"magma", "kinetic":
				var sz: float = r * 2.2
				TurretShot._spr(g, "ts_ring", Vector2.ZERO, Vector2.ONE * sz, 0.0, Color(0.2, 0.85, 1.0, 0.4 * f * pulse))
				for i in 6:
					var ph: float = fmod(t * 1.4 + float(i) * 0.33 + _seed, 1.0)
					var pos: Vector2 = Vector2.RIGHT.rotated(float(i) * 1.15 + _seed) * (r * 0.5)
					TurretShot._spr(g, "ts_flare", pos + Vector2(0, -ph * 14.0), Vector2.ONE * (8.0 + 20.0 * ph), 0.0, Color(0.3, 0.85, 1.0, (1.0 - ph) * 0.8 * f))
					if ph > 0.65:
						var spark_alpha: float = (1.0 - ph) / 0.35 * f
						TurretShot._spr(g, "ts_spark", pos + Vector2(0, -ph * 14.0), Vector2.ONE * 10.0, float(i) * 1.2, Color(1.0, 0.9, 0.5, spark_alpha))
			"acid":
				var sz2: float = r * 2.4
				g.draw_set_transform(Vector2.ZERO, _seed, Vector2.ONE)
				g.draw_texture_rect(TurretShot._T("ts_acid_glow"), Rect2(-sz2 * 0.5, -sz2 * 0.5, sz2, sz2), false, Color(1, 1, 1, f * pulse))
				g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				for i in 6:
					var ph2: float = fmod(t * 1.3 + float(i) * 0.31 + _seed, 1.0)
					var p2: Vector2 = Vector2.RIGHT.rotated(float(i) * 1.5 + _seed) * (r * 0.45)
					TurretShot._spr(g, "ts_flare", p2 + Vector2(0, -ph2 * 22.0), Vector2.ONE * (8.0 + 18.0 * ph2), 0.0, Color(0.8, 1.0, 0.4, (1.0 - ph2) * 0.75 * f))
			"drop":
				var sz3: float = r * 3.4
				g.draw_texture_rect(TurretShot._T("ts_acid_glow"), Rect2(-sz3 * 0.5, -sz3 * 0.5, sz3, sz3), false, Color(1, 1, 1, 0.85 * f))
			"frost":
				var sz4: float = r * 2.5
				g.draw_set_transform(Vector2.ZERO, _seed, Vector2.ONE)
				g.draw_texture_rect(TurretShot._T("ts_frost_glow"), Rect2(-sz4 * 0.5, -sz4 * 0.5, sz4, sz4), false, Color(1, 1, 1, f * (0.6 + 0.4 * pulse)))
				g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				for i in 5:
					var ph_f: float = fmod(t * 2.0 + float(i) * 0.4 + _seed, 1.0)
					var p_f: Vector2 = Vector2.RIGHT.rotated(float(i) * 1.3 + _seed) * (r * 0.6 * ph_f)
					TurretShot._spr(g, "ts_flare", p_f, Vector2.ONE * (8.0 + 10.0 * sin(ph_f * PI)), 0.0, Color(0.8, 0.95, 1.0, sin(ph_f * PI) * 0.7 * f))
			"spores":
				var sz5: float = r * 2.6
				g.draw_texture_rect(TurretShot._T("ts_spores_glow"), Rect2(-sz5 * 0.5, -sz5 * 0.5, sz5, sz5), false, Color(1, 1, 1, f * pulse))
				for i in 8:
					var ph3: float = fmod(t * 0.4 + float(i) * 0.19, 1.0)
					var p3: Vector2 = Vector2.RIGHT.rotated(float(i) * 0.9 + t * 0.3) * r * (0.2 + 0.7 * ph3)
					TurretShot._spr(g, "ts_flare", p3, Vector2.ONE * 14.0, 0.0, Color(0.7, 1.0, 0.45, sin(ph3 * PI) * 0.6 * f))
			"glass":
				var lb: Vector2 = b - a
				if lb.length() > 1.0:
					g.draw_set_transform(Vector2.ZERO, lb.angle(), Vector2.ONE)
					var heat: float = clampf(t / 1.4, 0.0, 1.0)   # le verre est dore et fondu au debut, il refroidit en turquoise
					var gc: Color = Color(1.0, 0.72, 0.32).lerp(Color.WHITE, heat)
					g.draw_texture_rect(TurretShot._T("ts_glass_glow"), Rect2(0.0, -r * 1.7, lb.length(), r * 3.4), false, Color(gc.r, gc.g, gc.b, f * (0.75 + 0.25 * sin(t * 9.0))))
					g.draw_line(Vector2.ZERO, Vector2(lb.length(), 0.0), Color(1.0, 0.9, 0.6, (1.0 - heat * 0.7) * f), 2.5)
					g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					for i in 7:
						var ph4: float = fmod(t * 1.6 + float(i) * 0.37, 1.0)
						var p4: Vector2 = Vector2.ZERO.lerp(lb, fmod(float(i) * 0.139 + ph4 * 0.05, 1.0))
						TurretShot._spr(g, "ts_flare", p4 + Vector2(0, -ph4 * 14.0), Vector2.ONE * 20.0, 0.0, Color(1.0, 0.9, 0.55, (1.0 - ph4) * 0.75 * f))

	class AfterGlow extends Node2D:
		var owner_after: TurretAfter = null
		func _draw() -> void:
			if owner_after != null and is_instance_valid(owner_after):
				owner_after.draw_emit(self)

## Impact : planche animee de 16 images (additif) + flash d'impact initial + onde de choc + etincelles d'eclatement.
class TurretBurst extends Node2D:
	var kind: String = ""
	var scl: float = 1.0
	var col: Color = Color.WHITE
	var t: float = 0.0
	var _seed: float = 0.0
	var _sparks: Array = []
	const DUR: float = 0.8
	const SHEET: Dictionary = {"slag": ["ts_slag_impact", 250.0], "ice": ["ts_ice_impact", 270.0], "acid": ["ts_acid_impact", 210.0],
		"pod": ["ts_pod_impact", 200.0], "smoke": ["ts_smoke_impact", 230.0], "plasma": ["ts_plasma_impact", 240.0],
		"missile": ["ts_missile_impact", 260.0]}

	func _ready() -> void:
		_seed = randf() * TAU
		material = Tex.add_mat()
		var n_sp: int = 10
		for i in n_sp:
			var ang: float = _seed + float(i) * TAU / float(n_sp) + randf_range(-0.2, 0.2)
			var spd: float = randf_range(180.0, 390.0) * scl
			_sparks.append([Vector2.ZERO, Vector2.RIGHT.rotated(ang) * spd, randf_range(0.35, 0.65)])

	func _process(delta: float) -> void:
		t += delta
		if t >= DUR:
			queue_free()
			return
		for sp in _sparks:
			sp[0] = (sp[0] as Vector2) + (sp[1] as Vector2) * delta
			sp[1] = (sp[1] as Vector2) * (1.0 - 2.8 * delta)
		queue_redraw()

	func _draw() -> void:
		var u: float = clampf(t / DUR, 0.0, 0.999)
		if not SHEET.has(kind):
			return
		var info: Array = SHEET[kind]
		var sz: float = float(info[1]) * scl

		# Couche 1 : flash d'impact aveuglant (u < 0.22)
		if u < 0.22:
			var fk: float = 1.0 - u / 0.22
			TurretShot._spr(self, "ts_flare", Vector2.ZERO, Vector2.ONE * sz * (1.3 + 0.7 * fk), _seed, Color(1, 1, 1, fk * 0.95))

		# Couche 2 : onde de choc supersonique en expansion (u < 0.48)
		if u < 0.48:
			var rk: float = u / 0.48
			var ring_sz: float = sz * (0.35 + 1.25 * (1.0 - pow(1.0 - rk, 2.2)))
			var ring_a: float = (1.0 - rk) * 0.85
			TurretShot._spr(self, "ts_ring", Vector2.ZERO, Vector2.ONE * ring_sz, _seed * 0.5, Color(col.r, col.g, col.b, ring_a))

		# Couche 3 : planche 16 frames animee
		var tint: Color = col.lerp(Color.WHITE, 0.4)
		draw_set_transform(Vector2.ZERO, _seed, Vector2.ONE)
		TurretShot._frame(self, String(info[0]), int(u * 16.0), Vector2.ZERO, Vector2(sz, sz), tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Couche 4 : etincelles / debris supersoniques projetes radialement
		for sp in _sparks:
			var p: Vector2 = sp[0] as Vector2
			var v: Vector2 = sp[1] as Vector2
			var max_l: float = float(sp[2])
			var lk: float = clampf((max_l - t) / max_l, 0.0, 1.0)
			if lk > 0.0:
				TurretShot._line(self, "ts_spark", p - v.normalized() * (12.0 * lk + 4.0), p, 4.5 * lk, Color(col.r, col.g, col.b, lk))
				TurretShot._spr(self, "ts_flare", p, Vector2.ONE * (8.0 * lk), 0.0, Color.WHITE)
