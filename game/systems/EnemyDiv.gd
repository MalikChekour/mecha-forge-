class_name EnemyDiv
extends RefCounted
## DIVERSITE DES ENNEMIS (29/10, plan valide par le patron : etapes 1 a 4, ZERO credit Meshy).
##
## 9 ROLES a taille egale (124 px) : fantassin, essaim, bouclier, sniper, artilleur, kamikaze, invocateur, reparateur, elite.
## 6 PALIERS. Palier = bloc de 3 chapitres + decalage de difficulte (Facile -1, Normal 0, Difficile +1, Veteran +2), borne 1..6 :
##            Facile  Normal  Difficile  Veteran
##   Ch1-3      1       1        2          3
##   Ch4-6      1       2        3          4
##   Ch7-9      2       3        4          5
##   Ch10-12    3       4        5          6
##   Ch13-15    4       5        6          6
##   Ch16-18    5       6        6          6
## Mk2 et Intermediaire jouent avec un palier d'avance (l'intermediaire porte aussi un pouvoir d'elite).
## Les ROLES presents suivent le palier : P1 fantassin/essaim/bouclier/sniper/elite, P2 + artilleur/kamikaze,
## P3 + invocateur/reparateur (en Veteran, les 9 roles sont la des le chapitre 1).
## TELEGRAPHES : duree de base x1,5 (Facile) / x1 / x0,85 / x0,7 (Veteran), jamais sous 0,4 s.
## Les multiplicateurs PV/degats de difficulte (GameState.DIFFICULTY) ne sont PAS touches.
##
## COMPETENCES (cumulatives : un palier garde tout ce qu'avaient les precedents)
##   fantassin  P1 tir | P2 grenade (cercle) | P3 rafale en eventail | P4 esquive | P5 3 grenades | P6 rage < 35 % PV
##   essaim     P1 ruee en lacets | P2 bond (ligne) | P3 meute (+vitesse a 3+ allies) | P4 etincelle a la mort | P5 bond plus frequent | P6 double bond
##   bouclier   P1 bouclier+garde | P2 onde de provocation (anneau, repousse) | P3 charge-bouclier (ligne) | P4 bouclier +30 % | P5 provocation etourdit, plus frequente | P6 dernier rempart (bouclier brise -> onde etourdissante)
##   sniper     P1 tir charge (laser) | P2 repli (saut en arriere) | P3 rail (ligne lourde) | P4 rail ralentit | P5 trois rails en eventail | P6 rail plus frequent
##   artilleur  P2 mortier (cercle) | P3 2 obus | P4 tir anticipe | P5 barrage en ligne (1 salve / 3) | P6 saturation en anneau (1 / 4)
##   kamikaze   P2 meche (anneau) | P3 sprint final | P4 laisse un brasier | P5 reaction en chaine | P6 sous-munitions
##   invocateur P3 3 drones / 8 s | P4 toutes les 6,5 s | P5 portails autour du joueur | P6 se teleporte s'il est approche
##   reparateur P3 rayon de soin | P4 soigne 2 cibles | P5 surbouclier sur un allie | P6 impulsion de soin de zone + fuite
##   elite      P1 epee + pouvoir de biome (10 s) | P2 9 s | P3 assaut (ligne) | P4 7 s | P5 rage a 50 % PV | P6 5 s + 2 escortes
## Les 18 POUVOIRS DE BIOME ont un vrai effet de jeu (voir _power).

const DIFF_OFF: Array[int] = [-1, 0, 1, 2]
const TELE_MULT: Array[float] = [1.5, 1.0, 0.85, 0.7]
const ROLES: Array[String] = ["fantassin", "essaim", "bouclier", "sniper", "artilleur", "kamikaze", "invocateur", "reparateur", "elite"]
const ROLE_MIN_TIER: Dictionary = {"fantassin": 1, "essaim": 1, "bouclier": 1, "sniper": 1, "elite": 1, "kamikaze": 2, "artilleur": 2, "invocateur": 3, "reparateur": 3}
const ROLE_COL: Dictionary = {
	"fantassin": Color(0.86, 0.9, 0.98), "essaim": Color(0.85, 1.0, 0.2), "bouclier": Color(0.3, 0.85, 1.0),
	"sniper": Color(1.0, 0.22, 0.22), "artilleur": Color(1.0, 0.55, 0.12), "kamikaze": Color(1.0, 0.2, 0.75),
	"invocateur": Color(0.68, 0.42, 1.0), "reparateur": Color(0.3, 1.0, 0.45), "elite": Color(1.0, 0.78, 0.25)}
const ROLE_NAME: Dictionary = {"fantassin": "Fantassin", "essaim": "Essaim", "bouclier": "Bouclier", "sniper": "Sniper", "artilleur": "Artilleur",
	"kamikaze": "Kamikaze", "invocateur": "Invocateur", "reparateur": "Reparateur", "elite": "Elite"}
const BIOMES: Array[String] = ["tech", "desert", "jungle", "volcanic", "swamp", "cryo", "reacteur", "ruche", "citadelle", "abyss", "ether", "titans", "orbit", "quantum", "ozone", "prism", "steampunk", "colosseum"]
## teinte dominante (tours de roue chromatique) des planches sources Ch1-3, et teinte cible de chaque biome
const SRC_BASE: Array[String] = ["en01_tech", "en02_desert", "en03_jungle"]
const SRC_HUE: Array[float] = [0.57, 0.08, 0.30]
const BIOME_HUE: Array[float] = [0.57, 0.08, 0.30, 0.02, 0.22, 0.53, 0.33, 0.11, 0.13, 0.50, 0.78, 0.07, 0.62, 0.15, 0.86, 0.93, 0.09, 0.0]
const ROLE_SUFFIX: Dictionary = {"essaim": "_swarm", "bouclier": "_shield", "sniper": "_sniper"}
const POWERS: Array[String] = ["iem_slash", "fire_trail", "tungsten_slam", "magma_wave", "acid_corrosion", "cryo_freeze", "radiation_aura", "amber_cleave", "gold_blast",
	"hydro_vortex", "uv_rapier", "titan_cleave", "zero_g_dash", "phase_warp", "arc_lightning", "prismatic_burst", "steam_burst", "arena_execution"]
const POWER_CD: Array[float] = [10.0, 9.0, 8.0, 7.0, 6.0, 5.0]

static var cur_chapter: int = 1
static var diff_override: int = -1
static var stats: Dictionary = {}
static var enabled: bool = true      # banc : coupe les competences pour mesurer le cout de reference

# ---------------------------------------------------------------- paliers / telegraphes
static func difficulty() -> int:
	return diff_override if diff_override >= 0 else clampi(int(GameState.difficulty), 0, 3)

static func tier_for(ch: int, d: int) -> int:
	return clampi(int(ceil(float(clampi(ch, 1, 18)) / 3.0)) + DIFF_OFF[clampi(d, 0, 3)], 1, 6)

static func tier() -> int:
	return tier_for(cur_chapter, difficulty())

static func tele(base: float) -> float:
	return maxf(0.4, base * TELE_MULT[difficulty()])

static func count(k: String) -> void:
	stats[k] = int(stats.get(k, 0)) + 1

# ---------------------------------------------------------------- roles
static func role_of(kind: String, def: Dictionary) -> String:
	if def.has("role"):
		return String(def["role"])
	if kind.ends_with("_swarm"): return "essaim"
	if kind.ends_with("_shield"): return "bouclier"
	if kind.ends_with("_sniper"): return "sniper"
	if kind.ends_with("_elite"): return "elite"
	if kind.ends_with("_kami"): return "kamikaze"
	if kind.ends_with("_summoner"): return "invocateur"
	if kind.ends_with("_artillery"): return "artilleur"
	if kind.ends_with("_repair"): return "reparateur"
	if kind.begins_with("mech") and (kind.length() == 6 or kind.ends_with("_mk2") or kind.ends_with("_inter")):
		return "fantassin"
	return ""

static func role_allowed(role: String, t: int) -> bool:
	return t >= int(ROLE_MIN_TIER.get(role, 1))

static func kind_allowed(kind: String, def: Dictionary, t: int) -> bool:
	var r: String = role_of(kind, def)
	return r == "" or role_allowed(r, t)

static func chapter_of_chassis(ch: String) -> int:
	if ch.length() >= 4 and ch.begins_with("en") and ch.substr(2, 2).is_valid_int():
		return int(ch.substr(2, 2))
	return 0

## Art sans credit : planche existante + recoloration shader (teinte) pour les roles Ch4-18.
static func art_for(chassis: String, role: String) -> Dictionary:
	var out: Dictionary = {"chassis": chassis, "hue": 0.0, "sat": 1.0, "proc": false}
	var n: int = chapter_of_chassis(chassis)
	match role:
		"essaim", "bouclier", "sniper":
			if n > 3 and n <= 18 and chassis == "en%02d_%s" % [n, BIOMES[n - 1]]:
				var src: int = (n - 1) % 3
				out["chassis"] = SRC_BASE[src] + String(ROLE_SUFFIX[role])
				out["hue"] = BIOME_HUE[n - 1] - SRC_HUE[src]
				out["sat"] = 1.15
		"invocateur":
			var s2: int = (maxi(n, cur_chapter)) % 3          # bloc VOISIN : silhouette differente du bouclier du chapitre
			out["chassis"] = SRC_BASE[s2] + "_shield"
			out["hue"] = 0.76 - SRC_HUE[s2]                    # violet
			out["sat"] = 1.25
		"kamikaze":
			out["chassis"] = "u_rodeur"
			out["proc"] = true
		"artilleur":
			out["chassis"] = "u_belier"
			out["proc"] = true
		"reparateur":
			out["chassis"] = "brute"
	return out

## Appele par Enemy.setup AVANT le chargement des planches (peut changer de chassis).
static func pre_setup(e, def: Dictionary) -> void:
	e.role = role_of(e.kind, def)
	e.tier_tag = String(def.get("tier_tag", ""))
	if e.tier_tag == "" and (e.kind.ends_with("_mk2") or e.kind.ends_with("_inter")):
		e.tier_tag = e.kind.get_slice("_", e.kind.get_slice_count("_") - 1)
	var t: int = tier()
	if e.tier_tag == "mk2" or e.tier_tag == "inter":
		t = mini(6, t + 1)
	e.dtier = t
	# 30/10 (patron : retirer les ajouts visuels) : plus de substitution/recoloration de planche, chaque ennemi garde SON art cuit.

## Appele a la FIN de Enemy.setup : recoloration, teinte de role, reglages de palier, surcouches.
static func post_setup(e, def: Dictionary) -> void:
	if e.role == "" or e.rank >= 2:
		return
	var t: int = e.dtier
	e.dv["name"] = String(def.get("name", ROLE_NAME.get(e.role, "")))
	e.dv["cd1"] = randf_range(1.5, 3.5)
	e.dv["cd2"] = randf_range(2.5, 5.0)
	e.dv["cd3"] = randf_range(3.0, 6.0)
	match e.role:
		"fantassin":
			if t >= 4:
				e.esquive = true
		"bouclier":
			if t >= 4 and e.shield_max > 0.0:
				e.shield_max *= 1.3
				e.shield = e.shield_max
		"artilleur":
			e.attack_cd = 999.0       # pas de tir direct : il ne fait QUE du mortier telegraphie
			e._atk_cd = 999.0
	var elite: bool = e.role == "elite" or e.contact_sword or e.tier_tag == "inter"
	if elite:
		_set_power(e, String(def.get("special_vfx", "")))

static func _set_power(e, p: String) -> void:
	if p == "" or not POWERS.has(p):
		var n: int = chapter_of_chassis(e.chassis)
		if n <= 0:
			n = cur_chapter
		p = POWERS[clampi(n, 1, 18) - 1]
	e.dv["power"] = p
	e.dv["pcd"] = randf_range(2.5, 4.5)

## Elite tiree au sort (_maybe_elite) ou scriptee (_spawn_elite) : cape + epee + nom + pouvoir.
static func make_elite(e) -> void:
	if e == null or not is_instance_valid(e):
		return
	e.dv["elite"] = true
	if not e.dv.has("power"):
		_set_power(e, String(e.special_vfx))

# ---------------------------------------------------------------- outils
static func _ad(e) -> float:
	return e.attack_dmg if e.attack_dmg > 0.0 else e.contact_dmg

static func _mk(e, shp: String, pos: Vector2, base_dur: float, dmg: float, col: Color, p: Dictionary) -> Telegraph:
	if p.has("on_fire"):
		p["src"] = e      # rappel annule si l'ennemi meurt avant le declenchement
	return Telegraph.make(e.game, e.player, shp, pos, tele(base_dur), dmg, col, p)

static func _dash(e, d: Vector2, spd: float, dur: float) -> void:
	e._dv_dash_t = dur
	e._dv_dash_v = d.normalized() * spd

static func _blink(e, to: Vector2) -> void:
	var sp: Variant = e.game.get("spawner") if e.game != null else null
	if sp != null and float(sp.arena_half) > 0.0:
		to.x = clampf(to.x, sp.arena.position.x, sp.arena.end.x)
		to.y = clampf(to.y, sp.arena.position.y, sp.arena.end.y)
	if e.game != null and e.game.has_method("spawn_vfx"):
		e.game.spawn_vfx("aaa_shockwave", e.global_position, 0.0, 0.6, Color(0.7, 0.5, 1.0))
		e.game.spawn_vfx("aaa_shockwave", to, 0.0, 0.6, Color(0.7, 0.5, 1.0))
	e.global_position = to
	e.velocity = Vector2.ZERO

static func _dash_cb(e, d: Vector2, spd: float, dur: float) -> Callable:
	return func(_tg, _hit) -> void:
		if is_instance_valid(e) and e.alive:
			_dash(e, d, spd, dur)

static func _cd(e, k: String, delta: float) -> float:
	var v: float = float(e.dv.get(k, 0.0)) - delta
	e.dv[k] = v
	return v

# ---------------------------------------------------------------- MINI-BOSS / BOSS (v12.15, patron : « le 1er niveau est trop facile »)
## Banc Ch1 v12.14 : les rangs >= 2 n'avaient AUCUNE competence (tick() les ignorait) -> mini-boss 7-11 PV de degats
## infliges sur toute la partie, boss 1 : 3,8. Kit telegraphie (lisible, appris), plus court a Difficile/Veteran (tele()).
const BOSS_KIT_CD: Dictionary = {"mini": 4.6, "boss1": 4.2, "boss2": 3.8, "boss": 3.4}
const BOSS_RAIN_N: Dictionary = {"boss1": 4, "boss2": 5, "boss": 6}

static func _boss_tick(e, delta: float, dist: float, dir: Vector2) -> void:
	var tag: String = String(e.tier_tag)
	if not BOSS_KIT_CD.has(tag):
		return
	if not e.dv.has("bcd"):
		e.dv["bcd"] = 2.5
		e.dv["bn"] = 0
	var enr: bool = e.hp < e.hp_max * 0.5
	if enr and not e.dv.has("benr"):
		e.dv["benr"] = true
		e._speed_mult *= 1.15
		if e.game.has_method("spawn_vfx"):
			e.game.spawn_vfx("aaa_shockwave", e.global_position, 0.0, 1.4, Color(1.0, 0.3, 0.15))
		count("boss:rage")
	if _cd(e, "bcd", delta) > 0.0 or dist > 760.0:
		return
	var n: int = int(e.dv["bn"])
	e.dv["bn"] = n + 1
	e.dv["bcd"] = float(BOSS_KIT_CD[tag]) * (0.7 if enr else 1.0)
	var ad: float = maxf(_ad(e), e.contact_dmg * 0.8)
	var ppos: Vector2 = e.player.global_position
	var pv: Vector2 = (e.player.velocity as Vector2) if "velocity" in e.player else Vector2.ZERO
	if tag == "mini":
		var cm: Color = Color(1.0, 0.35, 0.9)
		if n % 2 == 0:
			for i in 3:
				var pp: Vector2 = ppos + pv * 0.35 * float(i) + Vector2.from_angle(randf() * TAU) * 40.0 * float(i)
				_mk(e, "circle", pp, 1.0 + 0.15 * float(i), ad * 2.4, cm, {"radius": 85.0, "tag": "salve_mini"})
			count("mini:salve")
		else:
			var L: float = dist + 140.0
			_mk(e, "line", e.global_position, 0.85, ad * 3.0, cm, {"dir": dir, "length": L, "width": 70.0, "knock": 160.0, "tag": "charge_mini", "on_fire": _dash_cb(e, dir, L / 0.3, 0.3)})
			count("mini:charge")
		return
	var cb: Color = Color(1.0, 0.3, 0.25)
	match n % 3:
		0:
			_mk(e, "ring", e.global_position, 1.0, ad * 2.6, cb, {"inner": 90.0, "radius": 300.0, "follow": e, "tag": "onde_boss"})
			if enr or tag == "boss":
				_mk(e, "ring", e.global_position, 1.5, ad * 2.2, cb, {"inner": 300.0, "radius": 470.0, "follow": e, "tag": "onde_boss"})
			count("boss:onde")
		1:
			var k: int = int(BOSS_RAIN_N.get(tag, 4))
			for i in k:
				var pp2: Vector2 = ppos + pv * 0.3 * float(i) + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 90.0)
				_mk(e, "circle", pp2, 0.9 + 0.18 * float(i), ad * 2.2, cb, {"radius": 90.0, "tag": "pluie_boss"})
			count("boss:pluie")
		_:
			var L2: float = dist + 180.0
			var fx: Dictionary = {"dir": dir, "length": L2, "width": 90.0, "knock": 200.0, "tag": "charge_boss", "on_fire": _dash_cb(e, dir, L2 / 0.32, 0.32)}
			_mk(e, "line", e.global_position, 0.9, ad * 3.4, cb, fx)
			if tag == "boss" and e.game.has_method("spawn_enemy_bolt") and Enemy._fire_ok(3.0, e.rank):
				for i in 12:
					e.game.spawn_enemy_bolt(e.global_position, Vector2.from_angle(TAU * float(i) / 12.0), ad * 0.7, cb, 1.0, 260.0, false, 0.0, "boss:couronne")
			count("boss:charge")
# ---------------------------------------------------------------- boucle (appelee par Enemy._physics_process)
static func tick(e, delta: float, dist: float, dir: Vector2) -> void:
	if enabled and e.rank >= 2 and e.game != null and e.player != null:
		_boss_tick(e, delta, dist, dir)   # v12.15 : kit mini-boss / boss
		return
	if not enabled or e.role == "" or e.rank >= 2 or e.game == null:
		return
	var t: int = e.dtier
	var c1: float = _cd(e, "cd1", delta)
	var c2: float = _cd(e, "cd2", delta)
	var c3: float = _cd(e, "cd3", delta)
	var ppos: Vector2 = e.player.global_position
	var ad: float = _ad(e)
	var col: Color = ROLE_COL.get(e.role, Color.WHITE)
	match e.role:
		"fantassin":
			if t >= 2 and c1 <= 0.0 and dist < 520.0:
				e.dv["cd1"] = 7.0 if t < 5 else 6.0
				if t >= 5:
					var a0: float = randf() * TAU
					for i in 3:
						_mk(e, "circle", ppos + Vector2.from_angle(a0 + TAU * float(i) / 3.0) * 70.0, 1.0, ad * 0.8, Color(1.0, 0.5, 0.2), {"radius": 60.0, "tag": "grenade"})
				else:
					_mk(e, "circle", ppos, 1.0, ad * 1.2, Color(1.0, 0.5, 0.2), {"radius": 70.0, "tag": "grenade"})
				count("fantassin:grenade")
			if t >= 3 and c2 <= 0.0 and dist < 480.0 and Enemy._fire_ok(2.0, e.rank) and e.game.has_method("spawn_enemy_bolt"):
				e.dv["cd2"] = 6.0
				for i in 3:
					e.game.spawn_enemy_bolt(e.global_position + dir * 20.0, dir.rotated(-0.18 + 0.18 * float(i)), ad * 0.6, Color(1.0, 0.6, 0.25), 0.85, 360.0, false, 0.0, "div:rafale")
				count("fantassin:rafale")
			if t >= 6 and not e.dv.has("rage") and e.hp < e.hp_max * 0.35:
				e.dv["rage"] = true
				e._speed_mult *= 1.25
				e.attack_cd *= 0.7
				if e.game.has_method("spawn_vfx"):
					e.game.spawn_vfx("aaa_shockwave", e.global_position, 0.0, 0.8, Color(1.0, 0.3, 0.2))
				count("fantassin:rage")
		"essaim":
			if t >= 2 and c1 <= 0.0 and dist > 110.0 and dist < 290.0:
				e.dv["cd1"] = 4.0 if t < 5 else 2.8
				_bond(e, dir, dist, ad, col)
				if t >= 6:
					e.dv["bond2"] = tele(0.5) + 0.45
			if t >= 6 and e.dv.has("bond2"):
				if _cd(e, "bond2", delta) <= 0.0:
					e.dv.erase("bond2")
					_bond(e, dir, dist, ad, col)
			if t >= 3 and c3 <= 0.0:
				e.dv["cd3"] = 0.5
				var pack: bool = e._allies >= 3
				if pack != bool(e.dv.get("pack", false)):
					e.dv["pack"] = pack
					e._speed_mult *= 1.15 if pack else 1.0 / 1.15
		"bouclier":
			if t >= 2 and c1 <= 0.0 and dist < 200.0:
				e.dv["cd1"] = 9.0 if t < 5 else 6.0
				var fx: Dictionary = {"inner": 55.0, "radius": 190.0, "knock": 140.0, "follow": e, "tag": "provocation"}
				if t >= 5:
					fx["stun"] = 0.4
				_mk(e, "ring", e.global_position, 0.8, ad * 0.8, col, fx)
				count("bouclier:provocation")
			if t >= 3 and c2 <= 0.0 and dist > 160.0 and dist < 360.0:
				e.dv["cd2"] = 8.0
				var L: float = dist + 40.0
				_mk(e, "line", e.global_position, 0.7, ad * 1.3, col, {"dir": dir, "length": L, "width": 60.0, "knock": 160.0, "tag": "charge_bouclier", "on_fire": _dash_cb(e, dir, L / 0.3, 0.3)})
				count("bouclier:charge")
			if t >= 6 and e.shield_max > 0.0:
				if e.shield <= 0.5 and not bool(e.dv.get("broke", false)):
					e.dv["broke"] = true
					_mk(e, "circle", e.global_position, 0.6, ad, col, {"radius": 220.0, "stun": 0.6, "follow": e, "tag": "dernier_rempart"})
					count("bouclier:rempart")
				elif e.shield > e.shield_max * 0.5:
					e.dv["broke"] = false
		"sniper":
			if t >= 2 and c3 <= 0.0 and dist < 240.0:
				e.dv["cd3"] = 5.0
				_blink(e, e.global_position - dir * 200.0)
				count("sniper:repli")
			if t >= 3 and c1 <= 0.0 and dist < 760.0:
				e.dv["cd1"] = 8.0 if t < 6 else 5.0
				var n: int = 3 if t >= 5 else 1
				for i in n:
					var d2: Vector2 = dir.rotated((float(i) - float(n - 1) * 0.5) * 0.22)
					var fx2: Dictionary = {"dir": d2, "length": 780.0, "width": 22.0, "tag": "rail"}
					if t >= 4:
						fx2["slow"] = 0.55
						fx2["slow_t"] = 1.5
					_mk(e, "line", e.global_position, 0.9, ad * 1.1, Color(1.0, 0.2, 0.2), fx2)
				count("sniper:rail")
		"kamikaze":
			if t >= 3 and not e.dv.has("sprint") and dist < 320.0:
				e.dv["sprint"] = true
				e._speed_mult *= 1.4
				count("kamikaze:sprint")
		"invocateur":
			if t >= 4 and e._summon_cd > 6.5:
				e._summon_cd = 6.5
			if t >= 5 and c1 <= 0.0 and dist < 600.0:
				e.dv["cd1"] = 11.0
				var a1: float = randf() * TAU
				for i in 3:
					var pp: Vector2 = ppos + Vector2.from_angle(a1 + TAU * float(i) / 3.0) * 240.0
					_mk(e, "circle", pp, 1.0, 0.0, col, {"radius": 45.0, "tag": "portail", "on_fire": _portal_cb(e)})
				count("invocateur:portail")
			if t >= 6 and c2 <= 0.0 and dist < 200.0:
				e.dv["cd2"] = 5.0
				_blink(e, e.global_position - dir * 260.0)
				count("invocateur:fuite")
		"artilleur":
			if c1 <= 0.0 and dist < 720.0:
				e.dv["cd1"] = 4.5 if t < 6 else 3.5
				var vol: int = int(e.dv.get("vol", 0)) + 1
				e.dv["vol"] = vol
				var tgt: Vector2 = ppos
				if t >= 4 and "velocity" in e.player:
					tgt += (e.player.velocity as Vector2) * tele(1.2) * 0.6
				_mk(e, "circle", tgt, 1.2, ad * 1.6, col, {"radius": 85.0, "tag": "mortier"})
				if t >= 3:
					_mk(e, "circle", ppos + Vector2.from_angle(randf() * TAU) * 110.0, 1.35, ad * 1.2, col, {"radius": 70.0, "tag": "mortier"})
				if t >= 5 and vol % 3 == 0:
					for i in 4:
						_mk(e, "circle", e.global_position + dir * (140.0 + 110.0 * float(i)), 1.0 + 0.15 * float(i), ad, col, {"radius": 60.0, "tag": "barrage"})
				if t >= 6 and vol % 4 == 0:
					_mk(e, "ring", ppos, 1.4, ad * 1.4, col, {"inner": 90.0, "radius": 210.0, "tag": "saturation"})
				if e.game.has_method("spawn_vfx"):
					e.game.spawn_vfx("fire_blast", e.global_position - Vector2(0, 30), -PI / 2.0, 0.5, col)
				e.play("attack", true)
				count("artilleur:mortier")
		"reparateur":
			if t >= 4 and c1 <= 0.0:
				e.dv["cd1"] = 1.4
				var best = null
				var bm: float = 0.0
				for o in e._shared_enemies():
					if o == e or not (o is Enemy) or not o.alive or e.global_position.distance_squared_to(o.global_position) > 260.0 * 260.0:
						continue
					var miss: float = (o.hp_max - o.hp) * randf_range(0.6, 1.0)
					if miss > bm:
						bm = miss
						best = o
				if best != null:
					best.hp = minf(best.hp_max, best.hp + best.hp_max * 0.05)
					count("reparateur:soin2")
			if t >= 5 and c2 <= 0.0:
				e.dv["cd2"] = 7.0
				var ally = null
				var bd: float = 260.0 * 260.0
				for o in e._shared_enemies():
					if o == e or not (o is Enemy) or not o.alive:
						continue
					var d2s: float = e.global_position.distance_squared_to(o.global_position)
					if d2s < bd:
						bd = d2s
						ally = o
				if ally != null:
					ally._prot_t = 3.0
					if ally.shield_max > 0.0:
						ally.shield = ally.shield_max
					if e.game.has_method("shield_ripple"):
						e.game.shield_ripple(ally.global_position, 60.0, col)
					count("reparateur:surbouclier")
			if t >= 6 and c3 <= 0.0:
				e.dv["cd3"] = 9.0
				for o in e._shared_enemies():
					if o is Enemy and o.alive and e.global_position.distance_squared_to(o.global_position) < 220.0 * 220.0:
						o.hp = minf(o.hp_max, o.hp + o.hp_max * 0.08)
				if e.game.has_method("spawn_vfx"):
					e.game.spawn_vfx("shockwave", e.global_position, 0.0, 220.0 / 95.0, col)
				if dist < 180.0:
					_blink(e, e.global_position - dir * 240.0)
				count("reparateur:impulsion")
	# ---- ELITE (role elite, elite tiree au sort, intermediaire) ----
	if e.dv.has("power"):
		var enr: bool = bool(e.dv.get("enraged", false))
		if _cd(e, "pcd", delta) <= 0.0 and dist < 560.0:
			e.dv["pcd"] = POWER_CD[t - 1] * (0.7 if enr else 1.0)
			_power(e, String(e.dv["power"]), dir, dist, ppos, ad)
		var is_el: bool = e.role == "elite" or bool(e.dv.get("elite", false))
		if is_el:
			if t >= 3 and _cd(e, "acd", delta) <= 0.0 and dist > 180.0 and dist < 420.0:
				e.dv["acd"] = 7.0
				var L2: float = dist + 50.0
				_mk(e, "line", e.global_position, 0.6, ad * 1.2, Color(1.0, 0.75, 0.25), {"dir": dir, "length": L2, "width": 50.0, "tag": "assaut", "on_fire": _dash_cb(e, dir, L2 / 0.3, 0.3)})
				count("elite:assaut")
			if t >= 5 and not enr and e.hp < e.hp_max * 0.5:
				e.dv["enraged"] = true
				e._speed_mult *= 1.2
				if e.game.has_method("spawn_vfx"):
					e.game.spawn_vfx("aaa_shockwave", e.global_position, 0.0, 1.0, Color(1.0, 0.3, 0.15))
				count("elite:rage")
			if t >= 6 and not e.dv.has("escort") and e.hp < e.hp_max * 0.6:
				e.dv["escort"] = true
				var sp: Variant = e.game.get("spawner")
				if sp != null:
					var pool: Array = EnemySpawner.BIOME_POOL.get(sp.current_biome, [])
					if pool.size() >= 2:
						for i in 2:
							sp.spawn_kind_at(String(pool[1]), e.global_position + Vector2.from_angle(TAU * float(i) / 2.0 + 0.7) * 90.0)
				count("elite:escorte")
	if e.dv.has("trail"):
		if _cd(e, "trail", delta) <= 0.0:
			e.dv.erase("trail")
		elif _cd(e, "trail_t", delta) <= 0.0:
			e.dv["trail_t"] = 0.35
			_mk(e, "circle", e.global_position, 0.4, 0.0, Color(1.0, 0.45, 0.1), {"radius": 55.0, "linger": 2.5, "dps": ad * 0.6, "tag": "fire_trail"})

static func _bond(e, dir: Vector2, dist: float, ad: float, col: Color) -> void:
	var L: float = dist + 70.0
	_mk(e, "line", e.global_position, 0.5, ad, col, {"dir": dir, "length": L, "width": 34.0, "tag": "bond", "on_fire": _dash_cb(e, dir, L / 0.22, 0.22)})
	count("essaim:bond")

static func _portal_cb(e) -> Callable:
	return func(tg, _hit) -> void:
		if not is_instance_valid(e) or not e.alive or e.summon_kind == "":
			return
		if e._living_drones() >= 6 or e.get_tree().get_nodes_in_group("enemies").size() >= EnemySpawner.ENEMY_CAP:
			return
		var sp: Variant = e.game.get("spawner")
		if sp != null and sp.has_method("spawn_kind_at"):
			var d: Variant = sp.spawn_kind_at(e.summon_kind, (tg as Node2D).global_position)
			if d is Enemy:
				(d as Enemy).set_meta("summoner_owner", e.get_instance_id())

# ---------------------------------------------------------------- 18 pouvoirs de biome (vrais effets)
static func _power(e, p: String, dir: Vector2, dist: float, ppos: Vector2, ad: float) -> void:
	count("power:" + p)
	var pv: Vector2 = (e.player.velocity as Vector2) if "velocity" in e.player else Vector2.ZERO
	match p:
		"iem_slash":       # Ch1 tech : arc IEM -> etourdit
			_mk(e, "arc", e.global_position, 0.8, ad, Color(0.35, 0.9, 1.0), {"dir": dir, "radius": 210.0, "half": 0.75, "stun": 0.6, "tag": p})
		"fire_trail":      # Ch2 desert : ruee qui laisse une trainee de feu persistante
			e.dv["trail"] = 2.4
			e.dv["trail_t"] = 0.0
			_mk(e, "line", e.global_position, 0.6, ad * 0.8, Color(1.0, 0.45, 0.1), {"dir": dir, "length": dist + 120.0, "width": 44.0, "tag": p, "on_fire": _dash_cb(e, dir, (dist + 120.0) / 0.5, 0.5)})
		"tungsten_slam":   # Ch3 jungle : bond + impact au sol, repousse
			_mk(e, "circle", ppos, 1.0, ad * 1.8, Color(0.75, 1.0, 0.4), {"radius": 110.0, "knock": 150.0, "tag": p, "on_fire": _slam_cb(e)})
		"magma_wave":      # Ch4 volcanique : deux anneaux de lave concentriques
			_mk(e, "ring", e.global_position, 0.8, ad * 1.2, Color(1.0, 0.35, 0.1), {"inner": 60.0, "radius": 170.0, "follow": e, "tag": p})
			_mk(e, "ring", e.global_position, 1.25, ad * 1.2, Color(1.0, 0.35, 0.1), {"inner": 170.0, "radius": 290.0, "follow": e, "tag": p})
		"acid_corrosion":  # Ch5 marais : flaque d'acide persistante, ralentit
			_mk(e, "circle", ppos, 0.9, ad * 0.6, Color(0.6, 1.0, 0.2), {"radius": 120.0, "linger": 3.5, "dps": ad * 0.5, "slow": 0.6, "tag": p})
		"cryo_freeze":     # Ch6 cryo : gel -> immobilise 1 s
			_mk(e, "circle", ppos, 1.1, ad * 0.8, Color(0.55, 0.9, 1.0), {"radius": 100.0, "stun": 1.0, "tag": p})
		"radiation_aura":  # Ch7 reacteur : aura irradiee qui suit l'elite
			_mk(e, "circle", e.global_position, 0.8, ad * 0.4, Color(0.7, 1.0, 0.2), {"radius": 200.0, "linger": 4.0, "dps": ad * 0.6, "follow": e, "tag": p})
		"amber_cleave":    # Ch8 ruche : fauche d'ambre, englue
			_mk(e, "arc", e.global_position, 0.8, ad * 1.3, Color(1.0, 0.7, 0.15), {"dir": dir, "radius": 230.0, "half": 1.05, "slow": 0.5, "slow_t": 2.0, "tag": p})
		"gold_blast":      # Ch9 citadelle : rayon d'or longue portee
			_mk(e, "line", e.global_position, 1.0, ad * 2.0, Color(1.0, 0.85, 0.3), {"dir": dir, "length": 820.0, "width": 46.0, "tag": p})
		"hydro_vortex":    # Ch10 abysses : vortex qui aspire
			_mk(e, "circle", ppos, 0.8, ad * 0.4, Color(0.2, 0.7, 1.0), {"radius": 170.0, "linger": 2.5, "dps": ad * 0.4, "pull": 140.0, "tag": p})
		"uv_rapier":       # Ch11 ether : teleportation derriere le joueur + estoc
			var behind: Vector2 = ppos + dir * 150.0
			_blink(e, behind)
			_mk(e, "arc", behind, 0.6, ad * 1.4, Color(0.8, 0.45, 1.0), {"dir": -dir, "radius": 175.0, "half": 0.6, "tag": p})
		"titan_cleave":    # Ch12 titans : fauche a 180 deg, repousse fort
			_mk(e, "arc", e.global_position, 1.1, ad * 2.0, Color(1.0, 0.6, 0.3), {"dir": dir, "radius": 260.0, "half": 1.57, "knock": 180.0, "tag": p})
		"zero_g_dash":     # Ch13 orbite : ruee en apesanteur a travers le joueur
			var L: float = dist + 160.0
			_mk(e, "line", e.global_position, 0.7, ad * 1.5, Color(0.6, 0.85, 1.0), {"dir": dir, "length": L, "width": 56.0, "tag": p, "on_fire": _dash_cb(e, dir, L / 0.3, 0.3)})
		"phase_warp":      # Ch14 quantique : saut de phase + couronne de projectiles
			var to: Vector2 = ppos + Vector2.from_angle(randf() * TAU) * 260.0
			_blink(e, to)
			_mk(e, "circle", to, 0.6, ad * 0.6, Color(1.0, 0.95, 0.4), {"radius": 70.0, "tag": p, "on_fire": _warp_cb(e, ad)})
		"arc_lightning":   # Ch15 ozone : 3 frappes de foudre successives qui anticipent
			for i in 3:
				_mk(e, "circle", ppos + pv * 0.4 * float(i), 0.7 + 0.3 * float(i), ad * 0.9, Color(1.0, 1.0, 0.45), {"radius": 70.0, "stun": 0.25, "tag": p})
		"prismatic_burst": # Ch16 prisme : 6 rayons en etoile
			for i in 6:
				_mk(e, "line", e.global_position, 0.9, ad, Color.from_hsv(float(i) / 6.0, 0.6, 1.0), {"dir": dir.rotated(TAU * float(i) / 6.0), "length": 520.0, "width": 26.0, "tag": p})
		"steam_burst":     # Ch17 steampunk : jet de vapeur, repousse + ralentit
			_mk(e, "circle", e.global_position, 0.8, ad * 0.8, Color(0.9, 0.9, 0.85), {"radius": 210.0, "knock": 220.0, "slow": 0.55, "slow_t": 2.0, "follow": e, "tag": p})
		"arena_execution": # Ch18 colisee : anneau d'arene ; execute (degats x2) un joueur sous 40 % PV
			_mk(e, "ring", ppos, 1.2, ad * 1.2, Color(1.0, 0.25, 0.2), {"inner": 110.0, "radius": 300.0, "tag": p, "on_fire": _exec_cb(e, ad)})

static func _slam_cb(e) -> Callable:
	return func(tg, _h) -> void:
		if is_instance_valid(e) and e.alive:
			_blink(e, (tg as Node2D).global_position)

static func _warp_cb(e, ad: float) -> Callable:
	return func(tg, _h) -> void:
		if is_instance_valid(e) and e.alive and e.game.has_method("spawn_enemy_bolt"):
			for i in 8:
				e.game.spawn_enemy_bolt((tg as Node2D).global_position, Vector2.from_angle(TAU * float(i) / 8.0), ad * 0.5, Color(1.0, 0.95, 0.4), 1.0, 240.0, false, 0.0, "div:phase")

static func _exec_cb(e, ad: float) -> Callable:
	return func(_tg, hit) -> void:
		if hit and is_instance_valid(e) and e.player != null and is_instance_valid(e.player) and "hp" in e.player and "max_hp" in e.player:
			if float(e.player.hp) < float(e.player.max_hp) * 0.4:
				e.player.take_damage(ad * 1.2, e.global_position, "tele:execution")
				count("power:execution_bonus")

# ---------------------------------------------------------------- a la mort
static func on_death(e) -> void:
	if not enabled or e.role == "" or e.rank >= 2 or e.game == null or e.player == null or not is_instance_valid(e.player):
		return
	var t: int = e.dtier
	var pos: Vector2 = e.global_position
	if pos.distance_squared_to(e.player.global_position) > 700.0 * 700.0:
		return
	match e.role:
		"essaim":
			if t >= 4:
				_mk(e, "circle", pos, 0.6, e.contact_dmg * 0.8, ROLE_COL["essaim"], {"radius": 60.0, "tag": "etincelle"})
				count("essaim:etincelle")
		"kamikaze":
			var ad: float = _ad(e)
			if t >= 4:
				_mk(e, "circle", pos, 0.4, 0.0, Color(1.0, 0.4, 0.1), {"radius": 80.0, "linger": 2.0, "dps": ad * 0.5, "tag": "brasier"})
				count("kamikaze:brasier")
			if t >= 5:
				for o in e._shared_enemies():
					if o != e and o is Enemy and o.alive and o.role == "kamikaze" and not o._kamikaze_arming and pos.distance_squared_to(o.global_position) < 200.0 * 200.0:
						o._kamikaze_arming = true
						o._kamikaze_fuse = 0.3
						count("kamikaze:chaine")
			if t >= 6:
				var a0: float = randf() * TAU
				for i in 3:
					_mk(e, "circle", pos + Vector2.from_angle(a0 + TAU * float(i) / 3.0) * 120.0, 0.8, ad * 0.6, Color(1.0, 0.4, 0.1), {"radius": 55.0, "tag": "sous_munition"})
				count("kamikaze:sous_munitions")