class_name TurretShot
extends Node2D
## TIRS DE TOURELLE (15/10, patron : « les tirs ne doivent jamais etre les memes d'un niveau a un autre »).
## Avant : sept tourelles posaient le MEME cercle de danger + la meme ogive qui tombe, seule la couleur
## changeait. Maintenant chaque niveau a sa grammaire complete : trajectoire, signal avant le tir,
## corps du projectile, trace, impact et sequelle, son.
##
##   niveau 1  weld_sweep    rayon d'arc de soudure qui BALAIE (hitscan continu, etincelles)
##   niveau 2  solar_needle  cone de lumiere qui converge, puis aiguille instantanee + sillon de verre
##   niveau 3  lob_pod       cosse EN CLOCHE (ombre ovale) qui eclate en epines + spores
##   niveau 4  lob_slag      obus de lave lourd et haut, REBONDIT, laisse une flaque de magma
##   niveau 5  flak          salve de 4 obus traces qui eclatent EN L'AIR en anneau d'eclats
##   niveau 6  orb_frost     orbe LENT a suivi mou, ligne de givre, interceptable, nova de glace
##   niveau 7  plasma        charge en 3 paliers, boule instable qui se SCINDE en 3 eclairs
##   niveau 8  acid_burst    la poche gonfle, 3 globules a arc bas qui s'etirent + flaques d'acide
##   niveau 9  missile_swarm reticule de verrouillage, 5 missiles verticaux puis a tete chercheuse
##
## Rien ici n'utilise GroundZone : pas de cercle rouge, pas d'ogive commune. Tout est dessine par le
## code (aucune image requise) ; les images FX de la bible ne servent qu'a l'IMPACT.

var style: String = ""
var game: Node = null
var plr: Node2D = null
var kind: String = ""             # kind du decor (recettes d'impact de Game.impact_fx)
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
var _trail: Array = []            # [position monde, age]
var _trail_t: float = 0.0
var _glow: Node2D = null
var _hit_done: bool = false
var _tick: float = 0.0
var _sparks: Array = []           # [pos, vel, vie]
var _seed: float = 0.0
var _d: Dictionary = {}           # donnees propres a chaque style

const FRAG_N: int = 14

## Grammaire de chaque tir : [trajectoire, signal avant le tir]. Le test _test_turret_shots refuse que deux
## niveaux partagent la MEME trajectoire ou le MEME signal (patron : « ne jamais se ressembler »).
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
## Point d'entree unique : appele par PropScatter.Prop a chaque tir de tourelle.
static func fire(shot_style: String, prop: Node2D, g: Node, p: Node2D, damage: float, k: String) -> void:
	if g == null or p == null or not is_instance_valid(p) or not ("fx_layer" in g) or g.fx_layer == null:
		return
	if prop.has_method("head_snap"):
		prop.head_snap(p.global_position)   # le canon est deja dans l axe quand le tir part
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
				var off: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 85.0)
				var sh5: TurretShot = _mk("flak", g, p, damage * 0.45, k, s, to_p + lead + off, prop)
				sh5.delay = float(i) * 0.13
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
		return prop.muzzle_world()   # canon pivotant : le tir part du bout du canon, tourne vers la cible
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

## « La poche gonfle » (ruche) : l'organe grossit et vibre avant de cracher.
static func _swell(prop: Node2D) -> void:
	if not ("_sprite" in prop) or prop._sprite == null:
		return
	var sp: Sprite2D = prop._sprite
	var base: Vector2 = sp.scale
	var tw: Tween = prop.create_tween()
	tw.tween_property(sp, "scale", base * 1.16, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "scale", base * 0.93, 0.07)
	tw.tween_property(sp, "scale", base, 0.18).set_trans(Tween.TRANS_ELASTIC)

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
		sp[1] = (sp[1] as Vector2) + Vector2(0.0, 520.0) * delta
		sp[0] = (sp[0] as Vector2) + (sp[1] as Vector2) * delta
		if float(sp[2]) <= 0.0:
			_sparks.remove_at(i)

## Le canon pivote pour rester ALIGNE avec le tir (patron : si le projectile poursuit, le canon pivote).
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

## Un tir du joueur est-il sur ce projectile ? (orbe de givre, missiles : on peut les abattre)
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

# ---------------------------------------------------------------- 1 SOUDEUSE
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
	var ang: float = lerpf(-0.8, 0.8, u)
	var d: Vector2 = dir.rotated(ang)
	_aim_prop(d, 0.25)   # le bras de soudure suit l arc qui balaie
	global_position = src
	var tip: Vector2 = src + d * 440.0
	_d["tip"] = tip
	_d["d"] = d
	for i in 3:
		_sparks.append([tip, Vector2(randf_range(-170.0, 170.0), randf_range(-330.0, -60.0)), randf_range(0.25, 0.55)])
	_tick -= delta
	if _tick <= 0.0 and plr != null and _seg_dist(plr.global_position, src, tip) < 22.0:
		_tick = 0.35
		_hurt(dmg * 0.5, src)
		_burst("pod", plr.global_position, 0.5, Color(0.4, 0.9, 1.0))
	if t >= tell + 2.4:
		queue_free()

# --------------------------------------------------------------- 2 MIROIR SOLAIRE
func _step_solar(delta: float) -> void:
	var charge: float = 1.5
	src = _cur_muzzle()
	global_position = src
	_aim_prop(((_d["lock"] if _d.has("lock") else tgt) - src).normalized(), 0.25)
	if t < charge:
		if t < delta * 1.5:
			_sfx("ts_solar_a", 0.03)
		if t < charge * 0.78 and plr != null:
			_d["lock"] = plr.global_position
		if not _d.has("lock"):
			_d["lock"] = tgt
		return
	if not _hit_done:
		_hit_done = true
		var lk: Vector2 = _d["lock"]
		var dd: Vector2 = (lk - src).normalized()
		var tip: Vector2 = src + dd * 540.0
		_d["tip"] = tip
		_sfx("ts_solar_b", 0.02)
		_shake(5.0)
		if plr != null and _seg_dist(plr.global_position, src, tip) < 20.0:
			_hurt(dmg, src)
		_after("glass", src, 22.0, 3.2, dmg * 0.25, 0.0, tip)
		_sig("desert_fx_rayon_solaire", lk, 1.0, Color(1.0, 0.85, 0.3))
	if t >= charge + 0.45:
		queue_free()

# ------------------------------------------------------------------ 3 COSSE (JUNGLE)
func _step_pod(delta: float) -> void:
	if t < delta * 1.5:
		_sfx("ts_pod_a", 0.06)
	var u: float = clampf(t / life, 0.0, 1.0)
	global_position = _ballistic(u, 170.0)
	if int(t * 28.0) != int((t - delta) * 28.0):
		_trail.append([global_position, 0.0])
	if u >= 1.0:
		_hit_done = true
		_sfx("ts_pod_b", 0.05)
		_shake(3.0)
		if plr != null and plr.global_position.distance_to(tgt) <= 62.0:
			_hurt(dmg * 0.8, tgt)
		for i in 6:
			var th: TurretShot = _mk("thorn", game, plr, dmg * 0.18, kind, tgt, tgt, prop_ref)
			th.vel = Vector2.RIGHT.rotated(float(i) * TAU / 6.0 + randf() * 0.3) * 330.0
			th.life = 0.4
		_after("spores", tgt, 72.0, 3.0, 0.0, 0.7)
		_burst("pod", tgt, 1.0, Color(0.55, 0.9, 0.3))
		_sig("jungle_fx_cosse_epines", tgt, 0.8, Color(0.4, 0.9, 0.25))
		queue_free()

func _step_thorn(delta: float) -> void:
	global_position += vel * delta
	rotation = vel.angle()
	if plr != null and global_position.distance_to(plr.global_position) <= 16.0 and not _hit_done:
		_hit_done = true
		_hurt(dmg, global_position)
		queue_free()
	elif t >= life:
		queue_free()

# ------------------------------------------------------------------ 4 OBUS DE LAVE (FORGE)
func _step_slag(delta: float) -> void:
	if t < delta * 1.5:
		_sfx("ts_slag_a", 0.04)
	var total1: float = life
	var hop: float = 0.55
	if phase == 0:
		var u: float = clampf(t / total1, 0.0, 1.0)
		global_position = _ballistic(u, 300.0)
		if randf() < 0.9:
			_trail.append([global_position + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)), 0.0])
		if u >= 1.0:
			phase = 1
			t = 0.0
			_sfx("ts_slag_b", 0.05)
			_shake(4.0)
			if plr != null and plr.global_position.distance_to(tgt) <= 55.0:
				_hurt(dmg * 0.6, tgt)
			_burst("slag", tgt, 1.0, Color(1.0, 0.5, 0.1))
			var d2: Vector2 = _d["dir2"]
			_d["tgt2"] = tgt + d2 * 120.0
	else:
		var u2: float = clampf(t / hop, 0.0, 1.0)
		var t2: Vector2 = _d["tgt2"]
		global_position = tgt.lerp(t2, u2) + Vector2(0.0, -70.0 * 4.0 * u2 * (1.0 - u2))
		_trail.append([global_position, 0.0])
		if u2 >= 1.0:
			_sfx("ts_slag_b", 0.03)
			_shake(3.0)
			if plr != null and plr.global_position.distance_to(t2) <= 60.0:
				_hurt(dmg * 0.5, t2)
			_after("magma", t2, 88.0, 5.0, dmg * 0.45, 0.0)
			_burst("slag", t2, 1.3, Color(1.0, 0.45, 0.1))
			_sig("volcanic_fx_obus_lave", t2, 1.0, Color(1.0, 0.45, 0.15))
			queue_free()

# ------------------------------------------------------------------ 5 DCA (CITE)
func _step_flak(delta: float) -> void:
	if t < delta * 1.5:
		_sfx("ts_flak_a", 0.06)
	if phase == 0:
		var u: float = clampf(t / life, 0.0, 1.0)
		global_position = src.lerp(tgt, u)
		dir = (tgt - src).normalized()
		if u >= 1.0:
			phase = 1
			t = 0.0
			_sfx("ts_flak_b", 0.05)
			_shake(2.5)
			_burst("smoke", tgt, 1.0, Color(0.6, 0.6, 0.62))
			_sig("swamp_fx_obus_fusee", tgt, 0.7, Color(1.0, 0.55, 0.2))
			global_position = tgt
	else:
		global_position = tgt
		var r: float = 118.0 * (1.0 - pow(1.0 - clampf(t / 0.5, 0.0, 1.0), 2.0))
		_d["r"] = r
		if not _hit_done and plr != null:
			var dp: float = plr.global_position.distance_to(tgt)
			if absf(dp - r) <= 18.0 and t < 0.5:
				_hit_done = true
				_hurt(dmg, tgt)
		if t >= 0.6:
			queue_free()

# ------------------------------------------------------------------ 6 ORBE DE GIVRE (CRYO)
func _step_orb(delta: float) -> void:
	var tell: float = 0.9
	if phase == 0:
		src = _cur_muzzle()
		_aim_prop(dir, 0.3)
	else:
		if t < 0.6:
			_aim_prop((global_position - src).normalized(), 0.15)
	global_position = src if phase == 0 else global_position
	if phase == 0:
		if t < delta * 1.5:
			_sfx("ts_frost_a", 0.04)
		if t >= tell:
			phase = 1
			global_position = src
			vel = dir * 70.0
			_d["trav"] = 0.0
		return
	if plr != null:
		var want: Vector2 = (plr.global_position - global_position).normalized() * 112.0
		vel = vel.move_toward(want, 150.0 * delta)
	var step: Vector2 = vel * delta
	global_position += step
	_d["trav"] = float(_d["trav"]) + step.length()
	if float(_d["trav"]) >= 38.0:
		_d["trav"] = 0.0
		_after("frost", global_position, 24.0, 2.2, 0.0, 0.78)
	_trail.append([global_position, 0.0])
	if _intercepted(global_position, 22.0):
		_burst("ice", global_position, 0.7, Color(0.7, 0.9, 1.0))
		_sfx("ts_frost_b", 0.12)
		queue_free()
		return
	if (plr != null and global_position.distance_to(plr.global_position) <= 22.0) or t >= life:
		_nova()

func _nova() -> void:
	var c: Vector2 = global_position
	_sfx("ts_frost_b", 0.04)
	_shake(3.5)
	if plr != null and plr.global_position.distance_to(c) <= 88.0:
		_hurt(dmg, c)
	_after("frost", c, 82.0, 4.0, 0.0, 0.55)
	_burst("ice", c, 1.2, Color(0.7, 0.92, 1.0))
	_sig("cryo_fx_orbe_givre", c, 0.9, Color(0.65, 0.88, 1.0))
	queue_free()

# ------------------------------------------------------------------ 7 PLASMA (REACTEUR)
func _step_plasma(delta: float) -> void:
	var charge: float = 1.35
	if phase == 0:
		src = _cur_muzzle()
		global_position = src
		if t < delta * 1.5:
			_sfx("ts_plasma_a", 0.03)
		_d["stage"] = clampi(int(t / (charge / 3.0)) + 1, 1, 3)
		if prop_ref != null and is_instance_valid(prop_ref) and "_sprite" in prop_ref and prop_ref._sprite != null:
			var k: float = float(_d["stage"]) * 1.2
			prop_ref._sprite.position = Vector2(randf_range(-k, k), randf_range(-k, k))
		if t >= charge:
			if prop_ref != null and is_instance_valid(prop_ref) and "_sprite" in prop_ref and prop_ref._sprite != null:
				prop_ref._sprite.position = Vector2.ZERO
			phase = 1
			t = 0.0
			dir = ((plr.global_position if plr != null else tgt) - src).normalized()
			var dist: float = src.distance_to(plr.global_position) if plr != null else 300.0
			_d["ls"] = clampf(dist * 0.55, 150.0, 330.0)
			_d["ttot"] = float(_d["ls"]) / 300.0
		return
	if phase == 1:
		var u: float = clampf(t / float(_d["ttot"]), 0.0, 1.0)
		global_position = src + dir * float(_d["ls"]) * u
		_trail.append([global_position, 0.0])
		_d["tele"] = float(_d["ttot"]) - t < 0.32
		if u >= 1.0:
			_sfx("ts_plasma_b", 0.04)
			_shake(3.0)
			for i in 3:
				var b: TurretShot = _mk("bolt", game, plr, dmg * 0.55, kind, global_position, tgt, prop_ref)
				b.vel = dir.rotated(float(i - 1) * 0.38) * 560.0
				b.life = 0.65
			_burst("flower", global_position, 0.6, Color(0.5, 1.0, 0.6))
			_sig("reacteur_fx_tir_fragmente", global_position, 0.8, Color(0.45, 1.0, 0.55))
			queue_free()

func _step_bolt(delta: float) -> void:
	global_position += vel * delta
	_trail.append([global_position, 0.0])
	if plr != null and global_position.distance_to(plr.global_position) <= 18.0 and not _hit_done:
		_hit_done = true
		_hurt(dmg, global_position)
		_burst("flower", global_position, 0.45, Color(0.5, 1.0, 0.6))
		queue_free()
	elif t >= life:
		queue_free()

# ------------------------------------------------------------------ 8 ACIDE (RUCHE)
func _step_acid(delta: float) -> void:
	if t < delta * 1.5:
		_sfx("ts_acid_a", 0.08)
	var u: float = clampf(t / life, 0.0, 1.0)
	var prev: Vector2 = global_position
	global_position = _ballistic(u, 70.0)
	dir = (global_position - prev).normalized() if prev != global_position else dir
	if int(t * 20.0) != int((t - delta) * 20.0):
		_after("drop", _ground(u), 8.0, 1.2, dmg * 0.08, 0.0)
	if u >= 1.0:
		_sfx("ts_acid_b", 0.06)
		_shake(2.0)
		if plr != null and plr.global_position.distance_to(tgt) <= 40.0:
			_hurt(dmg * 0.6, tgt)
		_after("acid", tgt, 54.0, 4.0, dmg * 0.25, 0.0)
		_burst("acid", tgt, 1.0, Color(0.85, 0.95, 0.25))
		_sig("ruche_fx_globule_acide", tgt, 0.7, Color(0.85, 0.95, 0.25))
		queue_free()

# ------------------------------------------------------------------ 9 MISSILES (CITADELLE)
func _step_lock(_delta: float) -> void:
	global_position = plr.global_position if plr != null else tgt
	if t >= life:
		queue_free()

func _step_missile(delta: float) -> void:
	if phase == 0:
		if t < delta * 1.5:
			_sfx("ts_missile_a", 0.07)
			global_position = src + Vector2(float(_d.get("spread", 0.0)), 0.0)
			vel = Vector2(0.0, -230.0)
		global_position += vel * delta
		_trail.append([global_position, 0.0])
		dir = Vector2.UP
		if t >= 0.42:
			phase = 1
			t = 0.0
		return
	if plr != null:
		var want: Vector2 = (plr.global_position - global_position).normalized()
		var cur: float = dir.angle()
		var diff: float = wrapf(want.angle() - cur, -PI, PI)
		dir = Vector2.RIGHT.rotated(cur + clampf(diff, -2.4 * delta, 2.4 * delta))
	vel = dir * 255.0
	global_position += vel * delta
	_trail.append([global_position, 0.0])
	if _intercepted(global_position, 16.0):
		_burst("flower", global_position, 0.5, Color(1.0, 0.85, 0.5))
		_sfx("ts_missile_b", 0.1)
		queue_free()
		return
	if (plr != null and global_position.distance_to(plr.global_position) <= 20.0) or t >= life:
		var c: Vector2 = global_position
		_sfx("ts_missile_b", 0.05)
		_shake(3.5)
		if plr != null and plr.global_position.distance_to(c) <= 72.0:
			_hurt(dmg, c)
		_burst("flower", c, 1.2, Color(1.0, 0.7, 0.9))
		_sig("citadelle_fx_missile_plasma", c, 0.8, Color(1.0, 0.45, 0.85))
		queue_free()

# ================================================================== DESSIN
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

func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, n: int = 18) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)

func _dotted(a: Vector2, b: Vector2, col: Color, gap: float = 14.0, r: float = 2.0) -> void:
	var n: int = int(a.distance_to(b) / gap)
	for i in n:
		draw_circle(a.lerp(b, float(i) / maxf(1.0, float(n))), r, col)

# --- soudeuse : masque + pointilles, arc ramifie
func _draw_weld() -> void:
	var o: Vector2 = to_local(src)
	if t < 0.7:
		var k: float = clampf(t / 0.7, 0.0, 1.0)
		var a0: Vector2 = o + dir.rotated(-0.8) * 300.0
		var a1: Vector2 = o + dir.rotated(0.8) * 300.0
		_dotted(o, a0, Color(0.35, 0.85, 1.0, 0.45 * k))
		_dotted(o, a1, Color(0.35, 0.85, 1.0, 0.45 * k))
		draw_arc(o, 300.0, dir.angle() - 0.8, dir.angle() + 0.8, 24, Color(0.35, 0.85, 1.0, 0.25 * k), 1.5)
		# masque de soudeur qui s'abaisse
		var vy: float = lerpf(-30.0, -12.0, k)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-16, vy - 10), o + Vector2(16, vy - 10), o + Vector2(12, vy + 6), o + Vector2(-12, vy + 6)]), Color(0.08, 0.1, 0.14, 0.9))
		draw_rect(Rect2(o + Vector2(-9, vy - 3), Vector2(18, 5)), Color(0.4, 0.9, 1.0, 0.9))
		return
	if not _d.has("tip"):
		return
	var tip: Vector2 = to_local(_d["tip"])
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 14
	var perp: Vector2 = (tip - o).normalized().orthogonal()
	for i in n + 1:
		var f: float = float(i) / float(n)
		var jit: float = 0.0 if (i == 0 or i == n) else randf_range(-8.0, 8.0)
		pts.append(o.lerp(tip, f) + perp * jit)
	draw_polyline(pts, Color(0.9, 1.0, 1.0, 0.95), 3.0, true)
	# branches
	for i in 3:
		var bi: int = randi_range(2, n - 2)
		draw_line(pts[bi], pts[bi] + perp * randf_range(-22.0, 22.0) + (tip - o).normalized() * randf_range(8.0, 20.0), Color(0.5, 0.9, 1.0, 0.8), 1.5)
	for sp in _sparks:
		var l: float = float(sp[2])
		draw_circle(to_local(sp[0]), 2.2, Color(1.0, 0.7, 0.25, clampf(l * 3.0, 0.0, 1.0)))

func _glow_weld(g: Node2D) -> void:
	if t < 0.7 or not _d.has("tip"):
		return
	var o: Vector2 = to_local(src)
	var tip: Vector2 = to_local(_d["tip"])
	g.draw_line(o, tip, Color(0.3, 0.8, 1.0, 0.25), 20.0)
	g.draw_line(o, tip, Color(0.6, 0.95, 1.0, 0.4), 9.0)
	g.draw_circle(tip, 14.0 + randf() * 5.0, Color(0.8, 1.0, 1.0, 0.55))

# --- miroir solaire : rayons convergents, aiguille instantanee
func _draw_solar() -> void:
	var o: Vector2 = to_local(src)
	if t < 1.5:
		var u: float = clampf(t / 1.5, 0.0, 1.0)
		var lk: Vector2 = to_local(_d["lock"] if _d.has("lock") else tgt)
		var rr: float = lerpf(300.0, 26.0, u * u)
		for i in 7:
			var a: float = TAU * float(i) / 7.0 + u * 0.8
			var from: Vector2 = lk + Vector2.RIGHT.rotated(a) * rr
			draw_line(from, lk, Color(1.0, 0.85, 0.35, 0.12 + 0.5 * u), 1.0 + 2.0 * u)
		draw_arc(lk, rr, 0.0, TAU, 40, Color(1.0, 0.9, 0.5, 0.2 + 0.3 * u), 1.5)
		return
	if _d.has("tip"):
		var tip: Vector2 = to_local(_d["tip"])
		var f: float = clampf(1.0 - (t - 1.5) / 0.45, 0.0, 1.0)
		draw_line(o, tip, Color(1.0, 1.0, 0.95, f), 5.0 * f + 1.0)

func _glow_solar(g: Node2D) -> void:
	var o: Vector2 = to_local(src)
	if t < 1.5:
		var u: float = clampf(t / 1.5, 0.0, 1.0)
		# eclat de lentille sur le miroir
		g.draw_circle(o, 10.0 + 26.0 * u, Color(1.0, 0.9, 0.5, 0.15 + 0.4 * u))
		for i in 4:
			var a: float = float(i) * PI * 0.5 + 0.4
			g.draw_line(o - Vector2.RIGHT.rotated(a) * (30.0 * u), o + Vector2.RIGHT.rotated(a) * (30.0 * u), Color(1.0, 0.95, 0.6, 0.6 * u), 2.0)
		return
	if _d.has("tip"):
		var tip: Vector2 = to_local(_d["tip"])
		var f: float = clampf(1.0 - (t - 1.5) / 0.45, 0.0, 1.0)
		g.draw_line(o, tip, Color(1.0, 0.8, 0.3, 0.55 * f), 26.0 * f)
		g.draw_line(o, tip, Color(1.0, 0.95, 0.7, 0.8 * f), 11.0 * f)

# --- cosse : ombre ovale + cosse qui tourne
func _draw_pod() -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var gp: Vector2 = to_local(_ground(u))
	var tp: Vector2 = to_local(tgt)
	_ellipse(tp, 14.0 + 30.0 * u, 7.0 + 15.0 * u, Color(0.02, 0.08, 0.02, 0.22 + 0.3 * u))
	_ellipse(gp, 12.0, 5.0, Color(0.0, 0.0, 0.0, 0.18))
	for tr in _trail:
		var ag: float = float(tr[1])
		draw_circle(to_local(tr[0]), 3.0 * (1.0 - ag / 0.7), Color(0.45, 0.8, 0.2, 0.5 * (1.0 - ag / 0.7)))
	var rot: float = t * 9.0
	_ellipse(Vector2.ZERO, 13.0, 9.0, Color(0.22, 0.5, 0.15), rot)
	_ellipse(Vector2(-3, -3), 6.0, 3.5, Color(0.6, 0.9, 0.35, 0.8), rot)
	for i in 2:
		var la: float = rot + PI * float(i)
		draw_colored_polygon(PackedVector2Array([Vector2.RIGHT.rotated(la) * 10.0, Vector2.RIGHT.rotated(la + 0.35) * 22.0, Vector2.RIGHT.rotated(la - 0.35) * 22.0]), Color(0.3, 0.65, 0.2, 0.9))

func _draw_thorn() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(14, 0), Vector2(-6, 3.5), Vector2(-6, -3.5)]), Color(0.75, 0.95, 0.5))
	draw_line(Vector2(-6, 0), Vector2(-16, 0), Color(0.4, 0.8, 0.25, 0.5), 2.0)

# --- obus de lave
func _draw_slag() -> void:
	var tp: Vector2 = to_local(tgt)
	if phase == 0:
		var u: float = clampf(t / life, 0.0, 1.0)
		_ellipse(tp, 18.0 + 22.0 * u, 8.0 + 10.0 * u, Color(0.05, 0.03, 0.02, 0.3 + 0.3 * u))
		for i in 3:
			var rise: float = fmod(t * 40.0 + float(i) * 22.0, 66.0)
			draw_circle(tp + Vector2(sin(t * 3.0 + float(i)) * 8.0, -rise), 5.0 + rise * 0.1, Color(0.2, 0.18, 0.17, 0.35 * (1.0 - rise / 66.0)))
	for tr in _trail:
		var ag: float = float(tr[1])
		var k: float = 1.0 - ag / 0.7
		draw_circle(to_local(tr[0]), 5.0 + 7.0 * ag, Color(0.12, 0.1, 0.1, 0.5 * k))
	draw_circle(Vector2.ZERO, 15.0, Color(0.12, 0.08, 0.06))
	for i in 4:
		var a: float = t * 3.0 + float(i) * 1.6
		draw_line(Vector2.RIGHT.rotated(a) * 3.0, Vector2.RIGHT.rotated(a + 0.4) * 14.0, Color(1.0, 0.5, 0.1), 2.2)

func _glow_slag(g: Node2D) -> void:
	g.draw_circle(Vector2.ZERO, 26.0, Color(1.0, 0.4, 0.08, 0.28))
	g.draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.7, 0.2, 0.45))

# --- DCA : obus trace + ombres + anneau d'eclats en l'air
func _draw_flak() -> void:
	if phase == 0:
		var tp: Vector2 = to_local(tgt)
		var k: float = clampf(t / life, 0.0, 1.0)
		draw_arc(tp, 118.0, 0.0, TAU, 36, Color(0.9, 0.85, 0.7, 0.2 + 0.45 * k), 2.5)
		draw_circle(tp, 4.0, Color(0.1, 0.1, 0.12, 0.3 * k))
		draw_line(Vector2.ZERO, -dir * 52.0, Color(1.0, 0.85, 0.35, 0.95), 4.0)
	else:
		var r: float = float(_d.get("r", 0.0))
		var f: float = clampf(1.0 - t / 0.6, 0.0, 1.0)
		for i in FRAG_N:
			var a: float = TAU * float(i) / float(FRAG_N) + 0.2
			var p: Vector2 = Vector2.RIGHT.rotated(a) * r
			draw_line(p, p - Vector2.RIGHT.rotated(a) * 16.0, Color(1.0, 0.9, 0.45, f), 4.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.9, 0.7, 0.6 * f), 4.0)

func _glow_flak(g: Node2D) -> void:
	if phase == 0:
		g.draw_line(Vector2.ZERO, -dir * 44.0, Color(1.0, 0.8, 0.3, 0.4), 9.0)
	else:
		var f: float = clampf(1.0 - t / 0.35, 0.0, 1.0)
		g.draw_circle(Vector2.ZERO, 26.0 * f + 8.0, Color(1.0, 0.7, 0.25, 0.55 * f))

# --- orbe de givre
func _draw_orb() -> void:
	var o: Vector2 = to_local(src)
	if phase == 0:
		var k: float = clampf(t / 0.9, 0.0, 1.0)
		var e: Vector2 = o + dir * minf(src.distance_to(tgt), 420.0) * k
		for i in 12:
			var f: float = float(i) / 12.0
			if f > k:
				break
			var p: Vector2 = o.lerp(e, f)
			var pr: Vector2 = dir.orthogonal() * (4.0 + 4.0 * sin(float(i) * 1.7))
			draw_line(p - pr, p + pr, Color(0.75, 0.93, 1.0, 0.55), 1.5)
		return
	for tr in _trail:
		var ag: float = float(tr[1])
		draw_circle(to_local(tr[0]), 5.0 + 9.0 * ag, Color(0.85, 0.95, 1.0, 0.22 * (1.0 - ag / 0.7)))
	var rot: float = t * 2.0
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 6:
		pts.append(Vector2.RIGHT.rotated(rot + float(i) * TAU / 6.0) * (16.0 if i % 2 == 0 else 11.0))
	draw_colored_polygon(pts, Color(0.6, 0.85, 1.0, 0.92))
	draw_circle(Vector2.ZERO, 6.0, Color(0.95, 1.0, 1.0))

func _glow_orb(g: Node2D) -> void:
	if phase == 1:
		g.draw_circle(Vector2.ZERO, 30.0, Color(0.5, 0.8, 1.0, 0.25))

# --- plasma instable
func _draw_plasma() -> void:
	var o: Vector2 = to_local(src)
	if phase == 0:
		var st: int = int(_d.get("stage", 1))
		for k in st:
			var rr: float = 18.0 + float(k) * 11.0 + randf() * 2.0
			draw_arc(o, rr, 0.0, TAU, 28, Color(0.4, 1.0, 0.55, 0.85), 2.0)
		return
	for tr in _trail:
		var ag: float = float(tr[1])
		draw_circle(to_local(tr[0]), 6.0 * (1.0 - ag / 0.7), Color(0.4, 1.0, 0.55, 0.35))
	if _d.get("tele", false):
		var base: Vector2 = Vector2.ZERO
		for i in 3:
			var dd: Vector2 = dir.rotated(float(i - 1) * 0.38)
			_dotted(base, base + dd * 340.0, Color(0.5, 1.0, 0.6, 0.5), 12.0, 1.8)
	draw_circle(Vector2.ZERO, 11.0 + randf() * 3.0, Color(0.85, 1.0, 0.9))
	for i in 3:
		draw_arc(Vector2.ZERO, 14.0 + float(i) * 5.0, t * 6.0 + float(i), t * 6.0 + float(i) + 1.6, 10, Color(0.4, 1.0, 0.55, 0.8), 1.8)

func _glow_plasma(g: Node2D) -> void:
	var o: Vector2 = to_local(src)
	if phase == 0:
		var st: int = int(_d.get("stage", 1))
		g.draw_circle(o, 12.0 + 12.0 * float(st), Color(0.3, 1.0, 0.5, 0.15 + 0.1 * float(st)))
	else:
		g.draw_circle(Vector2.ZERO, 32.0, Color(0.3, 1.0, 0.5, 0.3))

func _draw_bolt() -> void:
	var n: int = 7
	var pts: PackedVector2Array = PackedVector2Array()
	var back: Vector2 = -vel.normalized() * 46.0
	var perp: Vector2 = vel.normalized().orthogonal()
	for i in n + 1:
		var f: float = float(i) / float(n)
		pts.append(back * f + perp * (0.0 if i == 0 else randf_range(-6.0, 6.0)))
	draw_polyline(pts, Color(0.9, 1.0, 0.92), 2.6, true)

func _glow_bolt(g: Node2D) -> void:
	g.draw_line(Vector2.ZERO, -vel.normalized() * 46.0, Color(0.3, 1.0, 0.5, 0.4), 12.0)

# --- acide : globule qui s'etire
func _draw_acid() -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var tp: Vector2 = to_local(_ground(u))
	_ellipse(tp, 11.0, 5.0, Color(0.0, 0.0, 0.0, 0.16))
	var sp: float = 1.0 + 0.9 * sin(u * PI)
	var rot: float = dir.angle()
	_ellipse(Vector2.ZERO, 11.0 * sp, 8.0 / sp, Color(0.78, 0.9, 0.2, 0.92), rot)
	_ellipse(Vector2(-2, -2), 4.0 * sp, 2.5, Color(1.0, 1.0, 0.7, 0.85), rot)

# --- missile
func _draw_lock() -> void:
	pass

func _glow_lock(g: Node2D) -> void:
	var u: float = clampf(t / life, 0.0, 1.0)
	var rr: float = lerpf(130.0, 38.0, u)
	var col: Color = Color(1.0, 0.8, 0.3, 0.35 + 0.6 * u)
	for i in 4:
		var a: float = float(i) * PI * 0.5 + u * 1.2
		g.draw_arc(Vector2.ZERO, rr, a, a + 0.9, 10, col, 3.0)
		g.draw_line(Vector2.RIGHT.rotated(a + 0.45) * (rr - 8.0), Vector2.RIGHT.rotated(a + 0.45) * (rr + 8.0), col, 2.0)
	g.draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.3, 0.3, 0.9 * u))

func _draw_missile() -> void:
	var n: int = _trail.size()
	for i in n:
		var ag: float = float(_trail[i][1])
		var k: float = 1.0 - ag / 0.7
		draw_circle(to_local(_trail[i][0]), 2.5 + 4.0 * k, Color(1.0, 1.0, 1.0, 0.45 * k))
	var d: Vector2 = dir
	var pr: Vector2 = d.orthogonal()
	draw_colored_polygon(PackedVector2Array([d * 12.0, d * 4.0 + pr * 4.0, -d * 9.0 + pr * 4.0, -d * 9.0 - pr * 4.0, d * 4.0 - pr * 4.0]), Color(0.95, 0.96, 1.0))
	draw_colored_polygon(PackedVector2Array([d * 12.0, d * 6.0 + pr * 3.0, d * 6.0 - pr * 3.0]), Color(1.0, 0.8, 0.3))
	draw_colored_polygon(PackedVector2Array([-d * 9.0 + pr * 4.0, -d * 13.0 + pr * 8.0, -d * 4.0 + pr * 4.0]), Color(1.0, 0.8, 0.3))
	draw_colored_polygon(PackedVector2Array([-d * 9.0 - pr * 4.0, -d * 13.0 - pr * 8.0, -d * 4.0 - pr * 4.0]), Color(1.0, 0.8, 0.3))

func _glow_missile(g: Node2D) -> void:
	g.draw_line(-dir * 8.0, -dir * (22.0 + randf() * 6.0), Color(0.5, 0.9, 1.0, 0.8), 6.0)
	g.draw_circle(-dir * 10.0, 7.0, Color(0.6, 0.95, 1.0, 0.5))


## Calque additif des tirs (halo, eclairs) : un Node2D enfant au materiau additif.
class ShotGlow extends Node2D:
	var owner_shot: TurretShot = null
	func _draw() -> void:
		if owner_shot != null and is_instance_valid(owner_shot):
			owner_shot._draw_glow(self)


## Sequelle persistante au sol : magma, acide, givre, spores, sillon de verre.
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
			"magma":
				draw_circle(o, r, Color(0.1, 0.05, 0.03, 0.75 * f))
				draw_circle(o, r * 0.8, Color(0.9, 0.3, 0.05, 0.55 * f))
				draw_circle(o, r * 0.45, Color(1.0, 0.75, 0.2, 0.55 * f))
				for i in 5:
					var ph: float = fmod(t * 1.4 + float(i) * 0.37 + _seed, 1.0)
					draw_circle(Vector2.RIGHT.rotated(float(i) * 1.3 + _seed) * r * 0.5, 3.0 + 5.0 * ph, Color(1.0, 0.85, 0.3, (1.0 - ph) * 0.8 * f))
			"acid":
				draw_circle(o, r, Color(0.5, 0.65, 0.1, 0.55 * f))
				draw_circle(o, r * 0.65, Color(0.8, 0.95, 0.25, 0.4 * f))
				for i in 6:
					var ph: float = fmod(t * 1.1 + float(i) * 0.29 + _seed, 1.0)
					draw_circle(Vector2.RIGHT.rotated(float(i) * 1.1 + _seed) * r * 0.6 + Vector2(0.0, -ph * 24.0), 2.0 + 3.0 * ph, Color(0.9, 1.0, 0.5, (1.0 - ph) * 0.7 * f))
			"drop":
				draw_circle(o, r, Color(0.8, 0.95, 0.25, 0.6 * f))
			"frost":
				draw_circle(o, r, Color(0.75, 0.9, 1.0, 0.32 * f))
				for i in 6:
					var ang: float = float(i) * TAU / 6.0 + _seed
					draw_line(Vector2.RIGHT.rotated(ang) * r * 0.15, Vector2.RIGHT.rotated(ang) * r * 0.95, Color(0.9, 0.97, 1.0, 0.75 * f), 1.5)
			"spores":
				for i in 7:
					var ph: float = fmod(t * 0.5 + float(i) * 0.31, 1.0)
					draw_circle(Vector2.RIGHT.rotated(float(i) * 0.9 + t * 0.4) * r * (0.2 + 0.7 * ph), 9.0 + 8.0 * ph, Color(0.55, 0.9, 0.3, 0.18 * f))
				draw_circle(o, r, Color(0.5, 0.85, 0.3, 0.1 * f))
			"glass":
				var la: Vector2 = Vector2.ZERO
				var lb: Vector2 = b - a
				draw_line(la, lb, Color(0.2, 0.7, 0.65, 0.35 * f), r * 1.5)
				draw_line(la, lb, Color(0.55, 0.95, 0.85, 0.55 * f), 6.0)
				draw_line(la, lb, Color(1.0, 0.85, 0.4, 0.5 * f), 2.0)
				for i in 8:
					var ph: float = fmod(t * 2.0 + float(i) * 0.37, 1.0)
					draw_circle(la.lerp(lb, float(i) / 8.0 + ph * 0.1), 1.8, Color(1.0, 1.0, 0.8, (1.0 - ph) * f))


## Effet d'impact purement visuel, dessine par le code (forme propre a chaque niveau).
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
			"slag":      # gouttes de lave qui retombent
				for i in 9:
					var a: float = _seed + float(i) * TAU / 9.0
					var p: Vector2 = Vector2.RIGHT.rotated(a) * (50.0 * scl * u) + Vector2(0.0, -70.0 * u * (1.0 - u) * 4.0 * 0.5 + 30.0 * u * u)
					draw_circle(p, 4.5 * f + 1.0, Color(1.0, 0.5, 0.1, f))
			"ice":       # cristaux radiaux + anneau
				draw_arc(Vector2.ZERO, 90.0 * scl * (1.0 - f * f), 0.0, TAU, 40, Color(0.8, 0.95, 1.0, 0.8 * f), 3.0)
				for i in 10:
					var a2: float = _seed + float(i) * TAU / 10.0
					var l: float = 70.0 * scl * (1.0 - f * f)
					draw_line(Vector2.RIGHT.rotated(a2) * l * 0.35, Vector2.RIGHT.rotated(a2) * l, Color(0.9, 0.98, 1.0, f), 3.0)
			"acid":      # gouttelettes qui giclent
				for i in 7:
					var a3: float = _seed + float(i) * TAU / 7.0
					var p3: Vector2 = Vector2.RIGHT.rotated(a3) * (46.0 * scl * u)
					draw_circle(p3, 5.0 * f + 1.0, Color(0.85, 0.95, 0.25, f))
			"pod":       # etincelles / feuilles
				for i in 8:
					var a4: float = _seed + float(i) * TAU / 8.0
					draw_circle(Vector2.RIGHT.rotated(a4) * (40.0 * scl * u), 3.0 * f + 1.0, Color(col.r, col.g, col.b, f))
			"smoke":     # bouffee grise de la DCA
				for i in 4:
					var a5: float = _seed + float(i) * 1.6
					draw_circle(Vector2.RIGHT.rotated(a5) * (14.0 * u), 16.0 * scl * (0.5 + u), Color(0.55, 0.55, 0.57, 0.5 * f))
			"flower":    # fleur de plasma / missile
				var rr: float = 74.0 * scl * (1.0 - f * f)
				for i in 8:
					var a6: float = _seed + float(i) * TAU / 8.0
					var tip: Vector2 = Vector2.RIGHT.rotated(a6) * rr
					draw_colored_polygon(PackedVector2Array([Vector2.RIGHT.rotated(a6 + 0.28) * rr * 0.3, tip, Vector2.RIGHT.rotated(a6 - 0.28) * rr * 0.3]), Color(col.r, col.g, col.b, 0.7 * f))
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 36, Color(1.0, 0.85, 0.35, f), 3.0)
