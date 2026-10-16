# upgrade_turret_shots_vfx.py
# Generates the visually upgraded TurretShots.gd with AAA-grade procedural VFX for the 9 level themes.
import os

TARGET = r"C:\Users\Administrator\mecha-forge\game\actors\TurretShots.gd"

code = r'''class_name TurretShot
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
		plr.take_damage(amount, from)

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)

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
		_burst("pod", plr.global_position, 0.5, Color(0.4, 0.9, 1.0))
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
	global_position = _ballistic(u, 220.0) # Cloche haute
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
		global_position = _ballistic(u, 310.0) # Lourd et haut
		if randf() < 0.92:
			_trail.append([global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)), 0.0, randf_range(6.0, 12.0)])
		if u >= 1.0:
			phase = 1
			t = 0.0
			_sfx("ts_slag_b", 0.05)
			_shake(4.5)
			if plr != null and plr.global_position.distance_to(tgt) <= 58.0:
				_hurt(dmg * 0.6, tgt)
			_burst("slag", tgt, 1.1, Color(1.0, 0.55, 0.12))
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
			# Flaque de magma qui bulle 5 s
			_after("magma", t2, 92.0, 5.0, dmg * 0.45, 0.0)
			_burst("slag", t2, 1.4, Color(1.0, 0.48, 0.1))
			_sig("volcanic_fx_obus_lave", t2, 1.0, Color(1.0, 0.45, 0.15))
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
	# Suivi lent et inexorable
	if plr != null:
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
			dir = ((plr.global_position if plr != null else tgt) - src).normalized()
			var dist: float = src.distance_to(plr.global_position) if plr != null else 300.0
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
			_burst("flower", global_position, 0.7, Color(0.5, 1.0, 0.6))
			_sig("reacteur_fx_tir_fragmente", global_position, 0.85, Color(0.45, 1.0, 0.55))
			queue_free()

func _step_bolt(delta: float) -> void:
	global_position += vel * delta
	_trail.append([global_position, 0.0, 0.0])
	if plr != null and global_position.distance_to(plr.global_position) <= 20.0 and not _hit_done:
		_hit_done = true
		_hurt(dmg, global_position)
		_burst("flower", global_position, 0.5, Color(0.5, 1.0, 0.6))
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
	global_position = _ballistic(u, 75.0)
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
		_burst("flower", global_position, 0.6, Color(1.0, 0.85, 0.5))
		_sfx("ts_missile_b", 0.1)
		queue_free()
		return
	if (plr != null and global_position.distance_to(plr.global_position) <= 22.0) or t >= life:
		var c: Vector2 = global_position
		_sfx("ts_missile_b", 0.05)
		_shake(3.8)
		if plr != null and plr.global_position.distance_to(c) <= 76.0:
			_hurt(dmg, c)
		_burst("flower", c, 1.25, Color(1.0, 0.72, 0.9))
		_sig("citadelle_fx_missile_plasma", c, 0.85, Color(1.0, 0.45, 0.85))
		queue_free()

# ================================================================== DESSIN PRINCIPAL
func _draw() -> void:
	if delay > 0.0:
		return
	match style:
		"weld_sweep": _draw_weld()
		"solar_needle": _draw_solar()
		"lob_pod": _draw_pod()
		"thorn": _draw_thorn()
		"lob_slag": _draw_slag()
		"flak": _draw_flak()
		"orb_frost": _draw_orb()
		"plasma": _draw_plasma()
		"bolt": _draw_bolt()
		"acid_burst": _draw_acid()
		"missile": _draw_missile()
		"lock": _draw_lock()

func _draw_glow(g: Node2D) -> void:
	if delay > 0.0:
		return
	match style:
		"weld_sweep": _glow_weld(g)
		"solar_needle": _glow_solar(g)
		"lob_slag": _glow_slag(g)
		"flak": _glow_flak(g)
		"orb_frost": _glow_orb(g)
		"plasma": _glow_plasma(g)
		"bolt": _glow_bolt(g)
		"missile": _glow_missile(g)
		"lock": _glow_lock(g)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, n: int = 24) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)

func _dotted(a: Vector2, b: Vector2, col: Color, gap: float = 14.0, r: float = 2.0) -> void:
	var n: int = int(a.distance_to(b) / gap)
	for i in n:
		draw_circle(a.lerp(b, float(i) / maxf(1.0, float(n))), r, col)

# ---------------------------------------------------------------- DESSIN 1 SOUDEUSE
func _draw_weld() -> void:
	var o: Vector2 = to_local(src)
	var max_ang: float = deg_to_rad(46.0)
	if t < 0.7:
		var k: float = clampf(t / 0.7, 0.0, 1.0)
		var a0: Vector2 = o + dir.rotated(-max_ang) * 320.0
		var a1: Vector2 = o + dir.rotated(max_ang) * 320.0
		# Grille industrielle de balayage +-46°
		_dotted(o, a0, Color(0.35, 0.85, 1.0, 0.45 * k), 12.0, 2.2)
		_dotted(o, a1, Color(0.35, 0.85, 1.0, 0.45 * k), 12.0, 2.2)
		draw_arc(o, 320.0, dir.angle() - max_ang, dir.angle() + max_ang, 32, Color(0.35, 0.85, 1.0, 0.3 * k), 2.0)
		# Arc median et encoches
		for step in [-0.5, 0.0, 0.5]:
			var tick_d: Vector2 = dir.rotated(max_ang * step)
			draw_line(o + tick_d * 300.0, o + tick_d * 335.0, Color(0.4, 0.9, 1.0, 0.4 * k), 1.5)
		# Masque de soudeur metallique
		var vy: float = lerpf(-32.0, -14.0, k)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-18, vy - 11), o + Vector2(18, vy - 11), o + Vector2(13, vy + 7), o + Vector2(-13, vy + 7)]), Color(0.08, 0.11, 0.15, 0.95))
		draw_rect(Rect2(o + Vector2(-10, vy - 4), Vector2(20, 6)), Color(0.4, 0.95, 1.0, 0.95))
		# Etincelle pilote au nez du canon
		var pilot_f: float = fmod(t * 22.0, 1.0)
		draw_circle(o, 3.5 + pilot_f * 2.0, Color(0.8, 0.98, 1.0, 0.85))
		return
	if not _d.has("tip"):
		return
	var tip: Vector2 = to_local(_d["tip"])
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 18
	var perp: Vector2 = (tip - o).normalized().orthogonal()
	# Faisceau principal avec fractal jitter
	for i in n + 1:
		var f: float = float(i) / float(n)
		var jit: float = 0.0 if (i == 0 or i == n) else (sin(t * 40.0 + float(i) * 2.5) * 5.5 + randf_range(-3.5, 3.5))
		pts.append(o.lerp(tip, f) + perp * jit)
	# Gaine cyan et coeur blanc incandescant
	draw_polyline(pts, Color(0.4, 0.92, 1.0, 0.75), 6.5, true)
	draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.98), 2.8, true)
	# 5 branches electriques ramifiees
	for i in 5:
		var bi: int = clampi(int(float(n) * (0.2 + float(i) * 0.14)), 2, n - 2)
		var br_root: Vector2 = pts[bi]
		var br_dir: Vector2 = perp * (1.0 if i % 2 == 0 else -1.0) * randf_range(18.0, 32.0) + (tip - o).normalized() * randf_range(10.0, 24.0)
		var br_mid: Vector2 = br_root + br_dir * 0.55 + perp * randf_range(-8.0, 8.0)
		var br_tip: Vector2 = br_root + br_dir
		draw_polyline(PackedVector2Array([br_root, br_mid, br_tip]), Color(0.55, 0.92, 1.0, 0.85), 1.8, true)
		draw_circle(br_tip, 1.6, Color(0.9, 1.0, 1.0, 0.9))
	# Cratere de fusion au point d'impact
	draw_circle(tip, 11.0 + randf() * 3.0, Color(1.0, 0.95, 0.7, 0.85))
	draw_circle(tip, 19.0 + randf() * 4.0, Color(1.0, 0.5, 0.1, 0.4))
	# Etincelles physiques avec traînée effilee
	for sp in _sparks:
		var p_cur: Vector2 = to_local(sp[0] as Vector2)
		var sp_v: Vector2 = sp[1] as Vector2
		var l: float = float(sp[2])
		var max_l: float = float(sp[3])
		var f_sp: float = clampf(l / max_l, 0.0, 1.0)
		var p_prev: Vector2 = p_cur - sp_v * minf(0.026, 0.045 * f_sp)
		draw_line(p_prev, p_cur, Color(1.0, 0.48, 0.1, f_sp * 0.75), 2.2 * f_sp + 0.8)
		draw_circle(p_cur, 1.8 * f_sp + 0.5, Color(1.0, 0.96, 0.85, f_sp))

func _glow_weld(g: Node2D) -> void:
	if t < 0.7 or not _d.has("tip"):
		return
	var o: Vector2 = to_local(src)
	var tip: Vector2 = to_local(_d["tip"])
	g.draw_line(o, tip, Color(0.25, 0.65, 1.0, 0.35), 36.0)
	g.draw_line(o, tip, Color(0.5, 0.92, 1.0, 0.6), 16.0)
	g.draw_circle(tip, 22.0 + randf() * 6.0, Color(0.7, 0.95, 1.0, 0.65))
	g.draw_circle(o, 14.0 + randf() * 4.0, Color(0.7, 0.95, 1.0, 0.65))

# ---------------------------------------------------------------- DESSIN 2 TERRES CALCINEES
func _draw_solar() -> void:
	var o: Vector2 = to_local(src)
	if t < 1.5:
		var u: float = clampf(t / 1.5, 0.0, 1.0)
		var lk: Vector2 = to_local(_d["lock"] if _d.has("lock") else tgt)
		var rr: float = lerpf(320.0, 24.0, u * u)
		# 12 rayons solaires or qui convergent
		for i in 12:
			var a: float = TAU * float(i) / 12.0 + u * 1.1
			var r_len: float = rr + lerpf(180.0, 40.0, u)
			var from: Vector2 = lk + Vector2.RIGHT.rotated(a) * r_len
			draw_line(from, lk, Color(1.0, 0.88, 0.35, 0.15 + 0.65 * u), 1.5 + 2.5 * u)
		# Anneaux solaires concentriques se resserrant
		draw_arc(lk, rr, 0.0, TAU, 48, Color(1.0, 0.92, 0.5, 0.25 + 0.45 * u), 2.2)
		draw_arc(lk, rr * 0.6, 0.0, TAU, 36, Color(1.0, 0.8, 0.3, 0.2 + 0.5 * u), 1.6)
		# Motes d'energie convergentes
		for i in 8:
			var mote_p: float = fmod(u * 3.0 + float(i) * 0.28, 1.0)
			var mote_pos: Vector2 = lk + Vector2.RIGHT.rotated(float(i) * 1.25) * (rr * (1.0 - mote_p))
			draw_circle(mote_pos, 2.2 * (1.0 - mote_p), Color(1.0, 1.0, 0.8, 0.85))
		return
	if _d.has("tip"):
		var tip: Vector2 = to_local(_d["tip"])
		var f: float = clampf(1.0 - (t - 1.5) / 0.45, 0.0, 1.0)
		# Aiguille instantanee : coeur ultra fin et net
		draw_line(o, tip, Color(1.0, 0.92, 0.55, f), 8.0 * f + 1.5)
		draw_line(o, tip, Color(1.0, 1.0, 1.0, f), 3.0 * f + 1.0)

func _glow_solar(g: Node2D) -> void:
	var o: Vector2 = to_local(src)
	if t < 1.5:
		var u: float = clampf(t / 1.5, 0.0, 1.0)
		var lk: Vector2 = to_local(_d["lock"] if _d.has("lock") else tgt)
		# Eclat focal sur la cible et lentille sur le miroir
		g.draw_circle(lk, 14.0 + 38.0 * u, Color(1.0, 0.88, 0.35, 0.2 + 0.6 * u))
		g.draw_circle(o, 12.0 + 32.0 * u, Color(1.0, 0.92, 0.5, 0.2 + 0.5 * u))
		for i in 4:
			var a: float = float(i) * PI * 0.5 + 0.4
			g.draw_line(o - Vector2.RIGHT.rotated(a) * (36.0 * u), o + Vector2.RIGHT.rotated(a) * (36.0 * u), Color(1.0, 0.96, 0.65, 0.7 * u), 2.5)
		return
	if _d.has("tip"):
		var tip: Vector2 = to_local(_d["tip"])
		var f: float = clampf(1.0 - (t - 1.5) / 0.45, 0.0, 1.0)
		g.draw_line(o, tip, Color(1.0, 0.78, 0.2, 0.65 * f), 42.0 * f)
		g.draw_line(o, tip, Color(1.0, 0.95, 0.7, 0.85 * f), 16.0 * f)

# ---------------------------------------------------------------- DESSIN 3 RUINE VERTE
func _draw_pod() -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var gp: Vector2 = to_local(_ground(u))
	var tp: Vector2 = to_local(tgt)
	# Ombre ovale nette et contrastée qui grandit a l'approche
	_ellipse(tp, 16.0 + 34.0 * u, 8.0 + 17.0 * u, Color(0.01, 0.06, 0.01, 0.2 + 0.45 * u))
	_ellipse(gp, 14.0 * (1.0 - u * 0.3), 6.0 * (1.0 - u * 0.3), Color(0.0, 0.0, 0.0, 0.22))
	# Trainee de spores
	for tr in _trail:
		var ag: float = float(tr[1])
		var k_tr: float = 1.0 - ag / 0.7
		draw_circle(to_local(tr[0]), 3.5 * k_tr, Color(0.55, 0.92, 0.25, 0.55 * k_tr))
	# Cosse en cloche qui tourne avec ailerons organiques
	var rot: float = t * 11.0
	_ellipse(Vector2.ZERO, 15.0, 10.0, Color(0.24, 0.55, 0.16), rot)
	_ellipse(Vector2(-3, -2), 8.0, 4.5, Color(0.7, 1.0, 0.35, 0.85), rot)
	# 3 ailes de samara / sycomore
	for i in 3:
		var la: float = rot + float(i) * TAU / 3.0
		var wing: PackedVector2Array = PackedVector2Array([
			Vector2.RIGHT.rotated(la) * 9.0,
			Vector2.RIGHT.rotated(la + 0.32) * 24.0,
			Vector2.RIGHT.rotated(la - 0.18) * 18.0
		])
		draw_colored_polygon(wing, Color(0.32, 0.72, 0.22, 0.92))

func _draw_thorn() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(-7, 4.0), Vector2(-5, 0), Vector2(-7, -4.0)]), Color(0.8, 1.0, 0.45))
	draw_line(Vector2(-6, 0), Vector2(-20, 0), Color(0.45, 0.9, 0.3, 0.65), 2.5)

# ---------------------------------------------------------------- DESSIN 4 FORGE
func _draw_slag() -> void:
	var tp: Vector2 = to_local(tgt)
	if phase == 0:
		var u: float = clampf(t / life, 0.0, 1.0)
		_ellipse(tp, 20.0 + 26.0 * u, 9.0 + 12.0 * u, Color(0.06, 0.03, 0.02, 0.35 + 0.35 * u))
		# Vapeur et fumee chaude au sol
		for i in 4:
			var rise: float = fmod(t * 42.0 + float(i) * 20.0, 70.0)
			draw_circle(tp + Vector2(sin(t * 3.5 + float(i)) * 10.0, -rise), 6.0 + rise * 0.12, Color(0.22, 0.18, 0.16, 0.38 * (1.0 - rise / 70.0)))
	# Trainee de fumee noire et cendre
	for tr in _trail:
		var ag: float = float(tr[1])
		var sz_tr: float = float(tr[2]) if tr.size() > 2 else 7.0
		var k_tr: float = 1.0 - ag / 0.7
		draw_circle(to_local(tr[0]), sz_tr + 6.0 * ag, Color(0.14, 0.11, 0.09, 0.55 * k_tr))
	# Obus de lave lourd : coeur de magma incandescent + plaques d'obsidienne
	draw_circle(Vector2.ZERO, 17.0, Color(0.12, 0.08, 0.06))
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.55, 0.12))
	draw_circle(Vector2(-3, -3), 6.0, Color(1.0, 0.95, 0.65))
	for i in 4:
		var a: float = t * 3.6 + float(i) * 1.57
		draw_line(Vector2.RIGHT.rotated(a) * 4.0, Vector2.RIGHT.rotated(a + 0.35) * 16.0, Color(1.0, 0.8, 0.25), 2.5)

func _glow_slag(g: Node2D) -> void:
	g.draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.42, 0.08, 0.32))
	g.draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.75, 0.2, 0.5))

# ---------------------------------------------------------------- DESSIN 5 CITE DECHUE
func _draw_flak() -> void:
	if phase == 0:
		var tp: Vector2 = to_local(tgt)
		var k: float = clampf(t / life, 0.0, 1.0)
		draw_arc(tp, 122.0, 0.0, TAU, 40, Color(0.95, 0.88, 0.72, 0.25 + 0.5 * k), 2.6)
		draw_circle(tp, 5.0, Color(0.1, 0.1, 0.14, 0.4 * k))
		# Obus traceur avec combustion de phosphore
		draw_line(Vector2.ZERO, -dir * 60.0, Color(1.0, 0.55, 0.18, 0.75), 5.5)
		draw_line(Vector2.ZERO, -dir * 35.0, Color(1.0, 0.95, 0.6, 0.98), 3.0)
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 0.9))
	else:
		var r: float = float(_d.get("r", 0.0))
		var f: float = clampf(1.0 - t / 0.6, 0.0, 1.0)
		# Anneau de 16 eclats de tungstene
		for i in FRAG_N:
			var a: float = TAU * float(i) / float(FRAG_N) + 0.2
			var p: Vector2 = Vector2.RIGHT.rotated(a) * r
			var flechette: Vector2 = Vector2.RIGHT.rotated(a) * 18.0
			draw_line(p, p - flechette, Color(1.0, 0.92, 0.5, f), 3.8)
			draw_circle(p, 2.5, Color(1.0, 1.0, 0.9, f))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.92, 0.75, 0.7 * f), 4.0)

func _glow_flak(g: Node2D) -> void:
	if phase == 0:
		g.draw_line(Vector2.ZERO, -dir * 50.0, Color(1.0, 0.78, 0.25, 0.5), 11.0)
	else:
		var f: float = clampf(1.0 - t / 0.35, 0.0, 1.0)
		g.draw_circle(Vector2.ZERO, 32.0 * f + 8.0, Color(1.0, 0.72, 0.25, 0.6 * f))

# ---------------------------------------------------------------- DESSIN 6 CRYO
func _draw_orb() -> void:
	var o: Vector2 = to_local(src)
	if phase == 0:
		var k: float = clampf(t / 0.9, 0.0, 1.0)
		var e: Vector2 = o + dir * minf(src.distance_to(tgt), 430.0) * k
		# Ligne de givre dentritique
		for i in 16:
			var f_l: float = float(i) / 16.0
			if f_l > k: break
			var p: Vector2 = o.lerp(e, f_l)
			var pr: Vector2 = dir.orthogonal() * (5.0 + 6.0 * sin(float(i) * 1.8))
			draw_line(p - pr, p + pr, Color(0.78, 0.94, 1.0, 0.65), 1.8)
		return
	# Trainee de givre et cristaux
	for tr in _trail:
		var ag: float = float(tr[1])
		var k_tr: float = 1.0 - ag / 0.7
		draw_circle(to_local(tr[0]), 6.0 + 10.0 * ag, Color(0.85, 0.96, 1.0, 0.26 * k_tr))
	# Orbe de glace a cristaux rotatifs
	var rot: float = t * 2.2
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 8:
		pts.append(Vector2.RIGHT.rotated(rot + float(i) * TAU / 8.0) * (18.0 if i % 2 == 0 else 12.0))
	draw_colored_polygon(pts, Color(0.65, 0.88, 1.0, 0.95))
	draw_circle(Vector2.ZERO, 7.5, Color(0.95, 1.0, 1.0))

func _glow_orb(g: Node2D) -> void:
	if phase == 1:
		g.draw_circle(Vector2.ZERO, 34.0, Color(0.5, 0.85, 1.0, 0.32))

# ---------------------------------------------------------------- DESSIN 7 NOYAU INSTABLE
func _draw_plasma() -> void:
	var o: Vector2 = to_local(src)
	if phase == 0:
		var st: int = int(_d.get("stage", 1))
		for k in st:
			var rr: float = 18.0 + float(k) * 12.0 + randf() * 2.5
			draw_arc(o, rr, 0.0, TAU, 32, Color(0.35, 1.0, 0.6, 0.9), 2.2)
		# Arcs electriques corona
		for i in 4:
			var a: float = randf() * TAU
			draw_line(o, o + Vector2.RIGHT.rotated(a) * (20.0 + float(st) * 10.0), Color(0.85, 1.0, 0.9, 0.85), 1.6)
		return
	for tr in _trail:
		var ag: float = float(tr[1])
		draw_circle(to_local(tr[0]), 7.0 * (1.0 - ag / 0.7), Color(0.4, 1.0, 0.6, 0.38))
	if _d.get("tele", false):
		var base: Vector2 = Vector2.ZERO
		for i in 3:
			var dd: Vector2 = dir.rotated(float(i - 1) * 0.4)
			_dotted(base, base + dd * 360.0, Color(0.5, 1.0, 0.6, 0.55), 12.0, 2.0)
	draw_circle(Vector2.ZERO, 13.0 + randf() * 3.0, Color(0.9, 1.0, 0.92))
	for i in 3:
		draw_arc(Vector2.ZERO, 15.0 + float(i) * 5.0, t * 7.0 + float(i), t * 7.0 + float(i) + 1.8, 12, Color(0.4, 1.0, 0.6, 0.85), 2.0)

func _glow_plasma(g: Node2D) -> void:
	var o: Vector2 = to_local(src)
	if phase == 0:
		var st: int = int(_d.get("stage", 1))
		g.draw_circle(o, 14.0 + 14.0 * float(st), Color(0.3, 1.0, 0.55, 0.18 + 0.12 * float(st)))
	else:
		g.draw_circle(Vector2.ZERO, 36.0, Color(0.3, 1.0, 0.55, 0.35))

func _draw_bolt() -> void:
	var n: int = 9
	var pts: PackedVector2Array = PackedVector2Array()
	var back: Vector2 = -vel.normalized() * 52.0
	var perp: Vector2 = vel.normalized().orthogonal()
	for i in n + 1:
		var f: float = float(i) / float(n)
		pts.append(back * f + perp * (0.0 if i == 0 else randf_range(-7.0, 7.0)))
	draw_polyline(pts, Color(0.95, 1.0, 0.95), 3.0, true)

func _glow_bolt(g: Node2D) -> void:
	g.draw_line(Vector2.ZERO, -vel.normalized() * 52.0, Color(0.35, 1.0, 0.55, 0.45), 14.0)

# ---------------------------------------------------------------- DESSIN 8 RUCHE
func _draw_acid() -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var tp: Vector2 = to_local(_ground(u))
	_ellipse(tp, 12.0, 5.5, Color(0.0, 0.0, 0.0, 0.18))
	# Globule qui s'etire de facon organique
	var sp: float = 1.0 + 1.2 * sin(u * PI)
	var rot: float = dir.angle()
	_ellipse(Vector2.ZERO, 13.0 * sp, 8.5 / sp, Color(0.82, 0.95, 0.22, 0.95), rot)
	_ellipse(Vector2(-2, -2), 5.0 * sp, 2.8, Color(1.0, 1.0, 0.75, 0.9), rot)

# ---------------------------------------------------------------- DESSIN 9 CITADELLE
func _draw_lock() -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var rr: float = lerpf(135.0, 36.0, u)
	var col_lock: Color = Color(1.0, 0.82, 0.28, 0.4 + 0.6 * u) if u < 0.85 else Color(1.0, 0.25, 0.25, 0.95)
	# Reticule de verrouillage militaire avec calibres
	for i in 4:
		var a: float = float(i) * PI * 0.5 + u * 1.4
		draw_arc(Vector2.ZERO, rr, a, a + 0.85, 12, col_lock, 3.0)
		draw_line(Vector2.RIGHT.rotated(a + 0.42) * (rr - 9.0), Vector2.RIGHT.rotated(a + 0.42) * (rr + 9.0), col_lock, 2.2)
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.2, 0.2, 0.95 * u))

func _glow_lock(g: Node2D) -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var rr: float = lerpf(135.0, 36.0, u)
	var col_glow: Color = Color(1.0, 0.8, 0.25, 0.35 * u) if u < 0.85 else Color(1.0, 0.3, 0.3, 0.6)
	g.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 32, col_glow, 6.0)

func _draw_missile() -> void:
	var n: int = _trail.size()
	for i in n:
		var ag: float = float(_trail[i][1])
		var k_tr: float = 1.0 - ag / 0.7
		var sz_tr: float = float(_trail[i][2]) if _trail[i].size() > 2 else 4.0
		draw_circle(to_local(_trail[i][0]), sz_tr + 5.0 * k_tr, Color(1.0, 1.0, 1.0, 0.48 * k_tr))
	var d: Vector2 = dir
	var pr: Vector2 = d.orthogonal()
	draw_colored_polygon(PackedVector2Array([d * 14.0, d * 5.0 + pr * 4.5, -d * 10.0 + pr * 4.5, -d * 10.0 - pr * 4.5, d * 5.0 - pr * 4.5]), Color(0.95, 0.96, 1.0))
	draw_colored_polygon(PackedVector2Array([d * 14.0, d * 7.0 + pr * 3.5, d * 7.0 - pr * 3.5]), Color(1.0, 0.78, 0.25))
	draw_colored_polygon(PackedVector2Array([-d * 10.0 + pr * 4.5, -d * 14.0 + pr * 9.0, -d * 5.0 + pr * 4.5]), Color(1.0, 0.78, 0.25))
	draw_colored_polygon(PackedVector2Array([-d * 10.0 - pr * 4.5, -d * 14.0 - pr * 9.0, -d * 5.0 - pr * 4.5]), Color(1.0, 0.78, 0.25))

func _glow_missile(g: Node2D) -> void:
	g.draw_line(-dir * 9.0, -dir * (26.0 + randf() * 7.0), Color(0.5, 0.92, 1.0, 0.85), 7.0)
	g.draw_circle(-dir * 11.0, 8.5, Color(0.65, 0.95, 1.0, 0.55))

# ================================================================== CLASSES AUXILIAIRES
class ShotGlow extends Node2D:
	var owner_shot: TurretShot = null
	func _draw() -> void:
		if owner_shot != null and is_instance_valid(owner_shot):
			owner_shot._draw_glow(self)

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

	func _ready() -> void:
		_seed = randf() * 50.0

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
					plr.take_damage(dps * 0.25, a)
		queue_redraw()

	func _draw() -> void:
		var f: float = clampf((dur - t) / 0.7, 0.0, 1.0)
		var o: Vector2 = Vector2.ZERO
		match kind:
			"magma": # Flaque de magma bouillonnante (5 s)
				draw_circle(o, r, Color(0.12, 0.06, 0.04, 0.8 * f))
				draw_circle(o, r * 0.82, Color(0.92, 0.32, 0.06, 0.65 * f))
				draw_circle(o, r * 0.48, Color(1.0, 0.78, 0.22, 0.65 * f))
				# Bulles de lave visqueuses qui gonflent et eclatent
				for i in 6:
					var ph: float = fmod(t * 1.3 + float(i) * 0.33 + _seed, 1.0)
					var b_pos: Vector2 = Vector2.RIGHT.rotated(float(i) * 1.15 + _seed) * (r * 0.52)
					draw_circle(b_pos, 4.0 + 6.0 * ph, Color(1.0, 0.9, 0.35, (1.0 - ph) * 0.85 * f))
					draw_arc(b_pos, 4.0 + 7.0 * ph, 0.0, TAU, 16, Color(1.0, 0.5, 0.1, (1.0 - ph) * 0.6 * f), 1.5)
			"acid": # Flaque d'acide caustique qui fume
				draw_circle(o, r, Color(0.48, 0.68, 0.12, 0.6 * f))
				draw_circle(o, r * 0.68, Color(0.82, 0.98, 0.25, 0.48 * f))
				for i in 7:
					var ph2: float = fmod(t * 1.2 + float(i) * 0.27 + _seed, 1.0)
					var steam_pos: Vector2 = Vector2.RIGHT.rotated(float(i) * 1.05 + _seed) * r * 0.65 + Vector2(0.0, -ph2 * 28.0)
					draw_circle(steam_pos, 2.5 + 4.5 * ph2, Color(0.92, 1.0, 0.5, (1.0 - ph2) * 0.75 * f))
			"drop":
				draw_circle(o, r, Color(0.82, 0.96, 0.25, 0.65 * f))
			"frost": # Trainee de givre et rime
				draw_circle(o, r, Color(0.78, 0.92, 1.0, 0.35 * f))
				for i in 6:
					var ang: float = float(i) * TAU / 6.0 + _seed
					draw_line(Vector2.RIGHT.rotated(ang) * r * 0.15, Vector2.RIGHT.rotated(ang) * r * 0.95, Color(0.92, 0.98, 1.0, 0.8 * f), 1.8)
			"spores": # Nuage de spores organiques
				for i in 8:
					var ph3: float = fmod(t * 0.5 + float(i) * 0.28, 1.0)
					draw_circle(Vector2.RIGHT.rotated(float(i) * 0.85 + t * 0.35) * r * (0.2 + 0.75 * ph3), 10.0 + 9.0 * ph3, Color(0.58, 0.92, 0.32, 0.2 * f))
				draw_circle(o, r, Color(0.52, 0.88, 0.32, 0.12 * f))
			"glass": # Sillon de verre vitrifie qui brule 3 s
				var la: Vector2 = Vector2.ZERO
				var lb: Vector2 = b - a
				draw_line(la, lb, Color(0.18, 0.72, 0.68, 0.4 * f), r * 1.6)
				draw_line(la, lb, Color(0.6, 0.98, 0.88, 0.65 * f), 7.0)
				draw_line(la, lb, Color(1.0, 0.9, 0.45, 0.6 * f), 2.5)
				for i in 9:
					var ph4: float = fmod(t * 2.2 + float(i) * 0.35, 1.0)
					draw_circle(la.lerp(lb, float(i) / 9.0 + ph4 * 0.08), 2.2, Color(1.0, 1.0, 0.85, (1.0 - ph4) * f))

class TurretBurst extends Node2D:
	var kind: String = ""
	var scl: float = 1.0
	var col: Color = Color.WHITE
	var t: float = 0.0
	var _seed: float = 0.0

	func _ready() -> void:
		_seed = randf() * TAU

	func _process(delta: float) -> void:
		t += delta
		if t >= 0.7:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var u: float = clampf(t / 0.7, 0.0, 1.0)
		var f: float = 1.0 - u
		match kind:
			"slag":
				for i in 10:
					var a: float = _seed + float(i) * TAU / 10.0
					var p: Vector2 = Vector2.RIGHT.rotated(a) * (55.0 * scl * u) + Vector2(0.0, -75.0 * u * (1.0 - u) * 4.0 * 0.5 + 32.0 * u * u)
					draw_circle(p, 5.0 * f + 1.0, Color(1.0, 0.52, 0.12, f))
			"ice":
				draw_arc(Vector2.ZERO, 96.0 * scl * (1.0 - f * f), 0.0, TAU, 48, Color(0.82, 0.96, 1.0, 0.85 * f), 3.5)
				for i in 12:
					var a2: float = _seed + float(i) * TAU / 12.0
					var l: float = 75.0 * scl * (1.0 - f * f)
					draw_line(Vector2.RIGHT.rotated(a2) * l * 0.3, Vector2.RIGHT.rotated(a2) * l, Color(0.92, 0.98, 1.0, f), 3.2)
			"acid":
				for i in 8:
					var a3: float = _seed + float(i) * TAU / 8.0
					var p3: Vector2 = Vector2.RIGHT.rotated(a3) * (50.0 * scl * u)
					draw_circle(p3, 5.5 * f + 1.0, Color(0.85, 0.98, 0.25, f))
			"pod":
				for i in 9:
					var a4: float = _seed + float(i) * TAU / 9.0
					draw_circle(Vector2.RIGHT.rotated(a4) * (44.0 * scl * u), 3.5 * f + 1.0, Color(col.r, col.g, col.b, f))
			"smoke":
				for i in 5:
					var a5: float = _seed + float(i) * 1.5
					draw_circle(Vector2.RIGHT.rotated(a5) * (16.0 * u), 18.0 * scl * (0.5 + u), Color(0.58, 0.58, 0.6, 0.55 * f))
			"flower":
				var rr: float = 78.0 * scl * (1.0 - f * f)
				for i in 8:
					var a6: float = _seed + float(i) * TAU / 8.0
					var tip_b: Vector2 = Vector2.RIGHT.rotated(a6) * rr
					draw_colored_polygon(PackedVector2Array([Vector2.RIGHT.rotated(a6 + 0.28) * rr * 0.3, tip_b, Vector2.RIGHT.rotated(a6 - 0.28) * rr * 0.3]), Color(col.r, col.g, col.b, 0.75 * f))
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(1.0, 0.88, 0.35, f), 3.2)
'''

with open(TARGET, "w", encoding="utf-8") as f:
    f.write(code)

print("Updated TurretShots.gd successfully! Total bytes:", len(code))
