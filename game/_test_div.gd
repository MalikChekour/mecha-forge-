extends Node
## DIVERSITE ENNEMIS (29/10) : banc headless.
##  1) grille des paliers (18 chapitres x 4 difficultes) == plan
##  2) chaque type de chaque biome, a chaque palier 1..6 et chaque difficulte : spawn + 4 s simulees, sans erreur
##  3) les roles presents suivent le palier (_weighted_pick + escouades)
##  4) les 18 pouvoirs d'elite + competences de role se declenchent (stats EnemyDiv)
##  5) telegraphes : duree x difficulte (min 0,4 s)
##  6) vague lourde : 220 ennemis tous roles au palier 6 Veteran, cout par image + pool des telegraphes

class StubGame extends Node:
	var enemy_layer: Node2D = Node2D.new()
	var projectile_layer: Node2D = Node2D.new()
	var cover_list: Array = []
	var spawner: EnemySpawner = null
	var bolts: int = 0
	var zones: int = 0
	func _ready() -> void:
		add_child(enemy_layer)
		add_child(projectile_layer)
	func spawn_enemy_bolt(_pos: Vector2, _dir: Vector2, _dmg: float, _c = Color.WHITE, _s = 1.0, _v = 300.0, _m = false, _h = 0.0, _tag: String = "") -> void:
		bolts += 1
	func spawn_ground_zone(_p, _r, _d, _dmg, _c = Color.WHITE, _fx = "", _sh = "circle", _a = Vector2.ZERO, _b = Vector2.ZERO) -> void:
		zones += 1
	func spawn_vfx(_k, _p, _r = 0.0, _s = 1.0, _c = Color.WHITE, _st = Vector2.ONE) -> void: pass
	func shield_ripple(_p, _r, _c) -> void: pass
	func shield_break(_p, _r, _c) -> void: pass
	func show_banner(_t: String, _c = Color.WHITE) -> void: pass
	func impact_fx(_p, _c, _k, _d = Vector2.ZERO, _s = 1.0) -> void: pass
	func _streak(_p, _d, _c, _l, _w, _t) -> void: pass

class FakePlayer extends Node2D:
	var velocity: Vector2 = Vector2(120, 40)
	var base_speed: float = 336.0
	var chassis_family: String = "vortex"
	var hp: float = 100.0
	var max_hp: float = 100.0
	var field_slow: float = 1.0
	var dmg_taken: float = 0.0
	var hits: int = 0
	var stuns: int = 0
	func take_damage(a: float, _b = Vector2.ZERO, _c: String = "") -> void:
		dmg_taken += a
		hits += 1
	func stun(_d: float) -> void:
		stuns += 1

var _fail: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + msg)
	if not ok:
		_fail += 1

const GRID: Array = [[1, 1, 2, 3], [1, 2, 3, 4], [2, 3, 4, 5], [3, 4, 5, 6], [4, 5, 6, 6], [5, 6, 6, 6]]

var g: StubGame
var pl: FakePlayer
var sp: EnemySpawner

func _sim(frames: int) -> void:
	var dt: float = 1.0 / 60.0
	for f in frames:
		pl.global_position = Vector2(sin(float(f) * 0.03) * 120.0, cos(float(f) * 0.02) * 80.0)
		pl.field_slow = minf(1.0, pl.field_slow + dt * 2.5)
		for c in g.enemy_layer.get_children():
			if c is Enemy and is_instance_valid(c):
				(c as Enemy)._physics_process(dt)
			elif c is Telegraph and (c as Telegraph)._active:
				(c as Telegraph)._physics_process(dt)
		for c in g.projectile_layer.get_children():
			pass

func _clear() -> void:
	for c in g.enemy_layer.get_children():
		if c is Enemy:
			c.queue_free()
		elif c is Telegraph:
			(c as Telegraph)._release()
	await get_tree().process_frame
	await get_tree().physics_frame   # le cache d'ennemis partage (1 / image physique) ne doit plus voir les liberes
	await get_tree().physics_frame

func _ready() -> void:
	GameState.reset()
	GameState.alive = true
	g = StubGame.new()
	add_child(g)
	await get_tree().process_frame
	pl = FakePlayer.new()
	pl.add_to_group("player")
	add_child(pl)
	sp = EnemySpawner.new()
	sp.game = g
	sp.player = pl
	g.spawner = sp
	add_child(sp)
	sp.set_process(false)
	sp._ensure_phase2()

	# 1) grille
	var grid_ok: bool = true
	for ch in range(1, 19):
		for d in 4:
			var want: int = int(GRID[(ch - 1) / 3][d])
			if EnemyDiv.tier_for(ch, d) != want:
				grid_ok = false
				print("    grille ch%d diff%d = %d (attendu %d)" % [ch, d, EnemyDiv.tier_for(ch, d), want])
	_check(grid_ok, "grille paliers 18 chapitres x 4 difficultes conforme au plan")

	# 5) telegraphes
	var tele_ok: bool = true
	var mults: Array = [1.5, 1.0, 0.85, 0.7]
	for d in 4:
		EnemyDiv.diff_override = d
		for base in [0.3, 0.5, 0.8, 1.2]:
			var want2: float = maxf(0.4, base * float(mults[d]))
			if absf(EnemyDiv.tele(base) - want2) > 0.001:
				tele_ok = false
	EnemyDiv.diff_override = 0
	_check(tele_ok and is_equal_approx(EnemyDiv.tele(1.0), 1.5), "telegraphes : Facile x1,5 .. Veteran x0,7, min 0,4 s")
	EnemyDiv.diff_override = 3
	_check(is_equal_approx(EnemyDiv.tele(0.5), 0.4) and is_equal_approx(EnemyDiv.tele(1.0), 0.7), "Veteran : 0,5 s -> 0,4 s (plancher), 1 s -> 0,7 s")

	# 2) chaque type x chaque palier x chaque difficulte
	var spawned: int = 0
	var bad: Array = []
	var roles_seen: Dictionary = {}
	var tiers_seen: Dictionary = {}
	var roles_by_tier: Dictionary = {}
	for d in 4:
		EnemyDiv.diff_override = d
		GameState.difficulty = d
		for ch in range(1, 19):
			var biome: String = EnemyDiv.BIOMES[ch - 1]
			sp.current_biome = biome
			var t: int = sp._sync_div()
			GameState.run_time = 200.0
			var kinds: Array = (EnemySpawner.BIOME_POOL[biome] as Array).duplicate()
			kinds.append_array(sp.PHASE2_EXTRA.get(biome, []))
			for k in kinds:
				var e: Enemy = sp.spawn_kind_at(String(k), Vector2.from_angle(randf() * TAU) * randf_range(150.0, 420.0))
				if e == null or e.role == "" or e.dtier != t:
					bad.append("%s ch%d d%d" % [k, ch, d])
					continue
				spawned += 1
				roles_seen[e.role] = true
				tiers_seen[t] = true
				if not roles_by_tier.has(t):
					roles_by_tier[t] = {}
				roles_by_tier[t][e.role] = true
				# 30/10 : SEUL l'art rigge (planches cuites d'un rig Meshy enNN_*) apparait ; aucune recoloration shader
				if not e.chassis.begins_with("en") or e._proc:
					bad.append("art non rigge %s ch%d = %s" % [k, ch, e.chassis])
				if e._mat != null and e._mat.shader != null and e._mat.get_shader_parameter("hue_shift") != null:
					bad.append("recoloration %s" % k)
				for c in e.get_children():
					if c.get_script() != null and String(c.get_script().resource_path).ends_with("EnemyOverlay.gd"):
						bad.append("surcouche %s" % k)
				var vf: float = e._vis_frac(e._spr.texture)
				var vis: float = e._spr.scale.x * vf * float(e._spr.texture.get_height())
				if absf(vis - 124.0 * Protocols.enemy_scale) > 1.0:
					bad.append("taille %s = %.1f px" % [k, vis])
			# intermediaire / mk2 / random elite
			var mi: Enemy = sp._spawn_tier("inter")
			if mi != null:
				spawned += 1
				if mi.tier_tag != "inter" or not mi.dv.has("power") or mi.dtier != mini(6, t + 1):
					bad.append("inter ch%d d%d" % [ch, d])
			var mk: Enemy = sp.spawn_kind_at(String(EnemySpawner.BIOME_POOL[biome][0]), Vector2(300, 0))
			if mk != null:
				EnemyDiv.make_elite(mk)
				if not mk.dv.has("power"):
					bad.append("elite tiree ch%d" % ch)
			_sim(240)
			await _clear()
	EnemyDiv.diff_override = -1
	_check(bad.is_empty(), "%d spawns (18 biomes x 4 difficultes x tous les types + inter + elites) : role, palier, art, taille 124 px OK %s" % [spawned, str(bad.slice(0, 8))])
	_check(roles_seen.size() == 5 and not roles_seen.has("kamikaze") and not roles_seen.has("artilleur") and not roles_seen.has("invocateur") and not roles_seen.has("reparateur"), "5 roles rigges seulement (fantassin/essaim/bouclier/sniper/elite) : %s" % str(roles_seen.keys()))
	_check(tiers_seen.size() == 6, "les 6 paliers ont ete joues : %s" % str(tiers_seen.keys()))

	# 2b) balises / epaves : les universels non rigges (brute/drone/quadshell) sont redirig?s vers l'ennemi rigge du chapitre
	var redir_bad: Array = []
	for ch in [1, 5, 12, 18]:
		sp.current_biome = EnemyDiv.BIOMES[ch - 1]
		for uk in ["brute", "drone", "quadshell"]:
			var ue: Enemy = sp.spawn_kind_at(uk, Vector2(200, 0))
			if ue == null or not ue.chassis.begins_with("en") or ue._proc:
				redir_bad.append("%s ch%d -> %s" % [uk, ch, "null" if ue == null else ue.chassis])
	await _clear()
	_check(redir_bad.is_empty(), "balises/epaves : universels non rigges rediriges vers un ennemi rigge %s" % str(redir_bad))

	# 3) roles presents selon le palier (tirage reel)
	var gate_ok: bool = true
	var full_t3: bool = true
	for d in 4:
		EnemyDiv.diff_override = d
		for ch in [1, 4, 7, 10, 13, 16]:
			sp.current_biome = EnemyDiv.BIOMES[ch - 1]
			var t2: int = sp._sync_div()
			GameState.run_time = 400.0
			var seen: Dictionary = {}
			for i in 600:
				var k2: String = sp._weighted_pick()
				var r2: String = EnemyDiv.role_of(k2, sp._raw(k2))
				seen[r2] = true
				if not EnemyDiv.role_allowed(r2, t2):
					gate_ok = false
			if seen.has("kamikaze") or seen.has("artilleur") or seen.has("invocateur") or seen.has("reparateur") or seen.has(""):
				full_t3 = false
				print("    ch%d d%d palier %d : %s" % [ch, d, t2, str(seen.keys())])
			if false:
				full_t3 = false
				print("    ch%d d%d palier %d : %s" % [ch, d, t2, str(seen.keys())])
			if t2 == 1 and (seen.has("kamikaze") or seen.has("artilleur") or seen.has("invocateur") or seen.has("reparateur")):
				gate_ok = false
	EnemyDiv.diff_override = 3
	sp.current_biome = "tech"
	_check(sp._sync_div() == 3, "Veteran chapitre 1 = palier 3")
	EnemyDiv.diff_override = -1
	_check(gate_ok, "palier 1 : pas d'artilleur/kamikaze/invocateur/reparateur ; jamais de role au-dessus du palier")
	_check(full_t3, "tirage reel : jamais de role non rigge (kamikaze/artilleur/invocateur/reparateur), jamais d'ennemi universel")
	# escouade palier 6 : artilleur + reparateur presents
	EnemyDiv.diff_override = 3
	sp.current_biome = "colosseum"
	GameState.run_time = 400.0
	sp._squads.clear()
	sp._spawn_squad(true)
	var sq_roles: Dictionary = {}
	for e2 in g.enemy_layer.get_children():
		if e2 is Enemy:
			sq_roles[(e2 as Enemy).role] = true
	_check(sq_roles.has("elite") and not sq_roles.has("artilleur") and not sq_roles.has("reparateur"), "escouade palier 6 (roles rigges) : %s" % str(sq_roles.keys()))
	sp._squads.clear()
	await _clear()

	# 4) pouvoirs : un elite de chaque biome, palier 6, 20 s
	EnemyDiv.diff_override = 3
	for ch in range(1, 19):
		sp.current_biome = EnemyDiv.BIOMES[ch - 1]
		sp._sync_div()
		var el: Enemy = sp.spawn_kind_at("mech%02d_elite" % ch, Vector2(260, 0))
		if el != null:
			el.hp_max *= 50.0
			el.hp = el.hp_max
	_sim(1200)
	await _clear()
	var missing: Array = []
	for p in EnemyDiv.POWERS:
		if int(EnemyDiv.stats.get("power:" + p, 0)) == 0:
			missing.append(p)
	_check(missing.is_empty(), "18 pouvoirs de biome declenches (manquants : %s)" % str(missing))
	# scenario rapproche : chaque role au palier 6, a 150-230 px, PV entames, 12 s
	EnemyDiv.diff_override = 3
	sp.current_biome = "colosseum"
	sp._sync_div()
	Enemy.fire_rate = 60.0
	var near: Array = (EnemySpawner.BIOME_POOL["colosseum"] as Array).duplicate()
	near.append_array(sp.PHASE2_EXTRA["colosseum"])
	for rep in 2:
		for k4 in near:
			var en4: Enemy = sp.spawn_kind_at(String(k4), Vector2.from_angle(randf() * TAU) * randf_range(150.0, 230.0))
			if en4 != null:
				en4.hp_max *= 20.0
				en4.hp = en4.hp_max * 0.5
				if en4.role == "sniper":
					en4.prefer_dist = 120.0
	# ici le MOTEUR fait tourner les ennemis (vraies images physiques : le budget de tir global se recharge)
	for f in 720:
		pl.global_position = Vector2(sin(float(f) * 0.03) * 120.0, cos(float(f) * 0.02) * 80.0)
		await get_tree().physics_frame
	await _clear()
	Enemy.fire_rate = 6.0
	var want_sk: Array = ["fantassin:grenade", "fantassin:rafale", "essaim:bond", "bouclier:provocation", "bouclier:charge", "sniper:rail", "sniper:repli",
		"elite:assaut"]
	var miss2: Array = []
	for k3 in want_sk:
		if int(EnemyDiv.stats.get(k3, 0)) == 0:
			miss2.append(k3)
	_check(miss2.is_empty(), "competences de role declenchees (manquantes : %s)" % str(miss2))
	_check(Telegraph.fired_total > 100 and pl.hits > 0, "telegraphes resolus : %d, coups encaisses par le joueur : %d, etourdissements : %d" % [Telegraph.fired_total, pl.hits, pl.stuns])

	# 6) vague lourde
	EnemyDiv.diff_override = 3
	sp.current_biome = "colosseum"
	sp._sync_div()
	GameState.run_time = 600.0
	var pool18: Array = (EnemySpawner.BIOME_POOL["colosseum"] as Array).duplicate()
	pool18.append_array(sp.PHASE2_EXTRA["colosseum"])
	for i in EnemySpawner.ENEMY_CAP:
		sp.spawn_kind_at(String(pool18[i % pool18.size()]), Vector2.from_angle(randf() * TAU) * randf_range(120.0, 540.0))
	var n_en: int = 0
	for c in g.enemy_layer.get_children():
		if c is Enemy:
			n_en += 1
	# reference : meme vague, competences coupees (cout d'origine d'Enemy._physics_process)
	EnemyDiv.enabled = false
	var ref_total: float = 0.0
	for f in 300:
		var t1: int = Time.get_ticks_usec()
		_sim(1)
		ref_total += float(Time.get_ticks_usec() - t1)
		if f % 60 == 0:
			await get_tree().process_frame
	EnemyDiv.enabled = true
	var ref_ms: float = ref_total / 300.0 / 1000.0
	print("  reference SANS competences : %.2f ms/image" % ref_ms)
	var created0: int = Telegraph.created_total
	var worst: float = 0.0
	var total: float = 0.0
	var peak_live: int = 0
	for f in 600:
		var t0: int = Time.get_ticks_usec()
		_sim(1)
		var us: float = float(Time.get_ticks_usec() - t0)
		total += us
		worst = maxf(worst, us)
		peak_live = maxi(peak_live, Telegraph.live)
		if f % 60 == 0:
			await get_tree().process_frame
	print("  vague lourde : %d ennemis, %.2f ms/image en moyenne (logique ennemis + telegraphes), pire %.2f ms" % [n_en, total / 600.0 / 1000.0, worst / 1000.0])
	print("  pool telegraphes : %d crees au total (%d pendant la vague), %d reutilisations, pic en vol %d / %d" % [Telegraph.created_total, Telegraph.created_total - created0, Telegraph.reused_total, peak_live, Telegraph.LIVE_CAP])
	_check(peak_live <= Telegraph.LIVE_CAP and Telegraph.reused_total > Telegraph.created_total, "telegraphes pooles et plafonnes")
	var div_ms: float = total / 600.0 / 1000.0
	_check(div_ms < ref_ms * 1.25 + 0.5, "surcout des competences a 220 ennemis : %.2f ms -> %.2f ms (+%.0f %%, banc stub, binaire editeur)" % [ref_ms, div_ms, (div_ms / maxf(0.001, ref_ms) - 1.0) * 100.0])
	print("  stats : ", EnemyDiv.stats)
	print("DIV RESULT: %s (%d echec(s))" % ["OK" if _fail == 0 else "ECHEC", _fail])
	get_tree().quit(1 if _fail > 0 else 0)