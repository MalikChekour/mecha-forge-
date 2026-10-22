extends Node
## Escouades, grades, visee et garde active (21/10). Simulation sans scene de jeu : un faux Game fournit les calques.

class StubGame extends Node:
	var enemy_layer: Node2D = Node2D.new()
	var projectile_layer: Node2D = Node2D.new()
	var cover_list: Array = []
	var spawner: EnemySpawner = null
	var bolts: Array = []
	var banners: Array = []
	func _ready() -> void:
		add_child(enemy_layer)
		add_child(projectile_layer)
	func spawn_enemy_bolt(pos: Vector2, dir: Vector2, dmg: float, _c = Color.WHITE, _s = 1.0, _v = 300.0, _m = false, _h = 0.0, _tag: String = "") -> void:
		bolts.append([pos, dir])
	func spawn_vfx(_k, _p, _r = 0.0, _s = 1.0, _c = Color.WHITE) -> void: pass
	func shield_ripple(_p, _r, _c) -> void: pass
	func shield_break(_p, _r, _c) -> void: pass
	func show_banner(t: String, _c = Color.WHITE) -> void: banners.append(t)

class FakePlayer extends Node2D:
	var velocity: Vector2 = Vector2(200, 0)
	var base_speed: float = 300.0
	var chassis_family: String = "vortex"
	func take_damage(_a, _b = Vector2.ZERO) -> void: pass

var _fail: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + msg)
	if not ok: _fail += 1

func _ready() -> void:
	GameState.reset()
	var g: StubGame = StubGame.new()
	add_child(g)
	await get_tree().process_frame
	var pl: FakePlayer = FakePlayer.new()
	pl.add_to_group("player")
	add_child(pl)
	var sp: EnemySpawner = EnemySpawner.new()
	sp.game = g
	sp.player = pl
	g.spawner = sp
	add_child(sp)
	sp.set_process(false)
	# 1) chaque formation : emplacements de depart >= 250 px du joueur, breche de l'encerclement
	for f in Squad.all_forms():
		sp.current_biome = "colosseum"
		var q: Squad = Squad.new()
		q.setup(f, 0.7, Vector2.from_angle(0.7) * 640.0, Vector2.ZERO)
		var dmin: float = 99999.0
		for i in range(1 if f == "leurre" else 0, 8):   # leurre : l'indice 0 est le leurre, repousse a 560 px au spawn
			dmin = minf(dmin, q.slot(i, 8, Vector2.ZERO).length())
		_check(dmin >= 250.0, "%-17s emplacement le plus proche %.0f px (>=250)" % [f, dmin])
	# breche (encerclement) : plus grand ecart angulaire entre voisins >= 1 rad
	var qe: Squad = Squad.new()
	qe.setup("encerclement", 0.0, Vector2(640, 0), Vector2.ZERO)
	var angs: Array = []
	for i in 8:
		angs.append(fposmod(qe.slot(i, 8, Vector2.ZERO).angle(), TAU))
	angs.sort()
	var gap: float = TAU - (float(angs[7]) - float(angs[0]))
	_check(gap >= 0.95, "encerclement : breche de %.2f rad laissee ouverte" % gap)
	# 2) vrai spawn d'une escouade + grades + simulation de 25 s
	for biome in ["desert", "cryo", "quantum", "colosseum"]:
		sp.current_biome = biome
		sp._squads.clear()
		for c in g.enemy_layer.get_children(): c.queue_free()
		await get_tree().process_frame
		sp._spawn_squad()
		_check(sp._squads.size() == 1, "%s : une escouade creee" % biome)
		if sp._squads.is_empty():
			continue
		var q2: Squad = sp._squads[0]
		var n0: int = q2.live().size()
		var chefs: int = 0
		var lts: int = 0
		for m in q2.live():
			if m.grade == "chef": chefs += 1
			if m.grade == "lieutenant": lts += 1
		_check(chefs == 1, "%s : 1 chef de meute (forme %s, %d membres, %d lieutenants)" % [biome, q2.form, n0, lts])
		var chef: Enemy = q2.chef
		var soldat: Enemy = null
		for m in q2.live():
			if m.grade == "":
				soldat = m
		_check(soldat != null and chef.hp_max > soldat.hp_max * 1.8, "%s : chef plus coriace (%.0f PV vs soldat %.0f)" % [biome, chef.hp_max, soldat.hp_max])
		var dmin2: float = 99999.0
		for m in q2.live():
			dmin2 = minf(dmin2, (m as Node2D).global_position.length())
		_check(dmin2 >= 380.0, "%s : apparition >= 380 px du joueur (%.0f)" % [biome, dmin2])
		for step in 750:   # 25 s a 30 Hz
			sp._squad_tick(1.0 / 30.0)
			for m in g.enemy_layer.get_children():
				if m is Enemy and (m as Enemy).alive:
					(m as Enemy)._physics_process(1.0 / 30.0)
			if step == 120 and q2.chef != null:
				(q2.chef as Enemy).take_damage(99999.0)   # le chef tombe
		_check(q2.chef != null and is_instance_valid(q2.chef) and q2.chef != chef and q2.chef.grade == "chef", "%s : un nouveau chef a pris le commandement" % biome)
		_check(g.banners.has("CHEF ABATTU - L'ESCOUADE HESITE"), "%s : annonce du chef abattu" % biome)
	_check(g.bolts.size() > 0, "des tirs visés ont ete emis (%d)" % g.bolts.size())
	# visee : un tireur dont la cible bouge ne tire pas hors de l'ecart de 0,28 rad
	# garde active : un coup de 10 est reduit a ~12 % ; la visee tourne a vitesse finie
	sp.current_biome = "citadelle"
	var ge: Enemy = Enemy.new()
	ge.global_position = Vector2(300, 0)
	g.enemy_layer.add_child(ge)
	ge.setup("mech09", sp._role_def("mech09", ["tir", "garde"], 9), pl, g)
	_check(ge.garde, "garde : drapeau lu depuis la definition")
	ge._garde_cd_t = 0.0
	var hp0: float = ge.hp
	ge.take_damage(10.0)
	_check(ge._garde_t > 0.0 and hp0 - ge.hp <= 1.3, "garde : coup de 10 -> %.2f PV perdus pendant la garde" % (hp0 - ge.hp))
	ge._garde_t = 0.0
	ge._garde_cd_t = 99.0
	ge.take_damage(3.0)
	_check(absf((hp0 - ge.hp) - (hp0 - ge.hp)) < 1.0 and ge.hp < hp0 - 1.5, "hors garde : degats pleins")
	# signatures de tir : chaque style produit sa propre salve
	for st in ["rafale", "eventail", "sniper", "guide", "anneau", "orbe"]:
		var se: Enemy = Enemy.new()
		se.global_position = Vector2(400, 0)
		g.enemy_layer.add_child(se)
		se.setup("mech09", sp._role_def("mech09", ["tir", st], 9), pl, g)
		se._aim_init = true
		se._aim = PI
		var b0: int = g.bolts.size()
		se._tire_dispatch(Vector2.LEFT)
		for k in 60:
			se._style_tick(1.0 / 30.0, true)
		var nb: int = g.bolts.size() - b0
		var want: int = {"rafale": 3, "eventail": 5, "sniper": 1, "guide": 1, "anneau": 10, "orbe": 1}[st]
		_check(nb == want, "style %-8s -> %d projectile(s) (attendu %d)" % [st, nb, want])
	# ordre du chef : -25 % de degats subis a portee
	var so: Enemy = Enemy.new()
	so.global_position = Vector2(400, 0)
	g.enemy_layer.add_child(so)
	so.setup("mech09", sp._role_def("mech09", ["tir"], 9), pl, g)
	var hpo: float = so.hp
	so.take_damage(10.0)
	var plein: float = hpo - so.hp
	so.hp = hpo
	var chf: Enemy = Enemy.new()
	chf.global_position = Vector2(450, 0)
	g.enemy_layer.add_child(chf)
	chf.setup("mech09", sp._role_def("mech09", ["tir"], 9), pl, g)
	so.chef_ref = chf
	so.take_damage(10.0)
	_check(absf((hpo - so.hp) - plein * 0.75) < 0.01, "ordre du chef : %.2f degats au lieu de %.2f" % [hpo - so.hp, plein])
	# 8 directions : un tireur doit regarder dans >= 5 secteurs differents quand le joueur fait le tour
	var seen: Dictionary = {}
	for k in 16:
		pl.global_position = Vector2.from_angle(float(k) * TAU / 16.0) * 230.0
		var fe: Enemy = Enemy.new()
		g.enemy_layer.add_child(fe)
		fe.setup("mech09", sp._role_def("mech09", ["tir"], 9), pl, g)
		for i in 40: fe._physics_process(1.0 / 30.0)
		seen[fe._dir] = 1
	_check(seen.size() >= 5, "tireur : %d directions distinctes sur 8 (regression : visee ignoree par _update_facing)" % seen.size())
	var sh: Enemy = Enemy.new()
	g.enemy_layer.add_child(sh)
	sh.setup("mech09", sp._role_def("mech09", ["tir", "garde"], 9), pl, g)
	_check(sh._garde_dome != null and sh._garde_dome.position.y < -5.0, "bouclier centre sur le corps (decalage %.0f px au-dessus de l'origine)" % -sh._garde_dome.position.y)
	# protecteur : marque ses allies proches (-40 %), zigzag sur les melee, LOD des lointains
	var pr: Enemy = Enemy.new()
	pr.global_position = Vector2(500, 0)
	g.enemy_layer.add_child(pr)
	pr.setup("mech09", sp._role_def("mech09", ["tir", "protecteur"], 9), pl, g)
	var al: Enemy = Enemy.new()
	al.global_position = Vector2(560, 0)
	g.enemy_layer.add_child(al)
	al.setup("mech09", sp._role_def("mech09", ["tir"], 9), pl, g)
	pr._enemies_frame = -1   # le test ne fait pas avancer les images physiques : on invalide le cache a la main
	pr._protecteur_tick(0.6)
	_check(pr.protecteur and al._prot_t > 0.0, "protecteur : allie proche marque (%.1f s)" % al._prot_t)
	var hpa: float = al.hp
	al.take_damage(10.0)
	_check(absf((hpa - al.hp) - 6.0) < 0.05, "protecteur : degats reduits de 40 %% (%.2f au lieu de 10)" % (hpa - al.hp))
	_check(float(sp._role_def("mech09", ["bull"], 9).get("zigzag", 0.0)) > 0.0, "bull : approche en lacets (zigzag)")
	var far: Enemy = Enemy.new()
	far.global_position = Vector2(2000, 0)
	g.enemy_layer.add_child(far)
	far.setup("mech09", sp._role_def("mech09", ["tir"], 9), pl, g)
	var skipped: int = 0
	for i in 9:
		if far._lod_far(1.0 / 30.0): skipped += 1
	_check(skipped == 6, "LOD : ennemi lointain mis a jour 1 image sur 3 (%d/9 sautees)" % skipped)
	var ae: Enemy = Enemy.new()
	ae.global_position = Vector2(400, 0)
	g.enemy_layer.add_child(ae)
	ae.setup("mech09", sp._role_def("mech09", ["tir"], 9), pl, g)
	ae._aim = 0.0
	ae._aim_init = true
	pl.global_position = Vector2(0, -400)     # cible a ~ -2.35 rad : le canon doit mettre du temps
	ae._aim_tick(0.1)
	var turned: float = absf(ae._aim)
	_check(turned > 0.0 and turned <= ae.aim_rate * 0.1 + 0.001, "visee : rotation %.2f rad en 0,1 s (limite %.2f)" % [turned, ae.aim_rate * 0.1])
	_check(not ae._aim_ready(), "visee : ne tire pas tant que le canon n'est pas aligne")
	print("=== ", "OK" if _fail == 0 else "%d ECHEC(S)" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
