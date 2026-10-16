extends Node
## Headless regression harness pour les 3 biomes restants de la refonte "15 maps" : Noyau
## Instable (reacteur), Biomecanique (ruche), Forge Finale (citadelle). Un seul fichier pour les
## 3 (mecaniques plus courtes individuellement que Zone Cryo) - meme moule que
## _test_decor_tech.gd/_test_decor_cryo.gd. Les mecaniques qui REUTILISENT un idiome deja
## teste a l'identique (porte_securite_orbitale/segment_mur_modulaire = _cycle, deja couvert par
## _test_decor_tech.gd) ne sont pas re-testees ici pour rester concis.
##   godot --headless --path game res://_test_decor_phase2.tscn

class StubGame extends Node:
	var enemy_layer: Node2D
	var arena: Rect2 = Rect2(-5000, -5000, 10000, 10000)
	var awaken_calls: int = 0
	var vfx_positions: Array = []
	func _init() -> void:
		enemy_layer = Node2D.new()
		add_child(enemy_layer)
	func spawn_ground_zone(_pos: Vector2, _radius: float, _delay: float, _dmg: float, _color: Color = Color.WHITE, _fx_kind: String = "decor_hit") -> void:
		pass
	func spawn_vfx(_kind: String, _pos: Vector2, _rot: float, _scale: float, _color: Color) -> void:
		vfx_positions.append(_pos)
	func awaken_enemy(_pos: Vector2, _kind: String) -> void:
		awaken_calls += 1
	# 04/10, mise a niveau VFX (demande du patron) : les coups uniques du decor passent maintenant
	# par impact_fx (meme composite complet que le combat) au lieu de spawn_vfx seul.
	var impact_calls: int = 0
	func impact_fx(_pos: Vector2, _color: Color, _kind: String, _dir: Vector2 = Vector2.ZERO, _scale: float = 1.0) -> void:
		impact_calls += 1

class DummyPlayer extends Node2D:
	var field_slow: float = 1.0
	var dmg_total: float = 0.0
	func take_damage(amount: float, _pos: Vector2 = Vector2.ZERO) -> void:
		dmg_total += amount

## Game.gd n'a pas de class_name -> acces aux const via le script preload, comme _test_decor_cryo.gd.
const GameScript = preload("res://scenes/Game.gd")

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _mk_prop(game_stub: StubGame, kind: String, pos: Vector2) -> PropScatter.Prop:
	var p: PropScatter.Prop = PropScatter.Prop.new()
	p.game = game_stub; p.kind = kind; p.def = PropScatter.DECOR[kind]
	p.position = pos; p.rand_scale = 1.0; p.skill_roll = 0.0; p.flip = false
	add_child(p)
	return p

func _ready() -> void:
	PropScatter.Prop._enemy_cache_on = false
	print("=== TEST DECOR INTERACTIF (NOYAU INSTABLE / BIOMECANIQUE / FORGE FINALE) ===")
	GameState.reset()

	# --- 0. les 3 biomes sont enregistres partout ou il faut ---
	for b in ["reacteur", "ruche", "citadelle"]:
		_ok(GameScript.BIOMES.has(b), "BIOMES contient '%s'" % b)
		_ok(GameScript.BIOME_MODS.has(b), "BIOME_MODS contient '%s'" % b)
		_ok(GameScript.CUT_LINES.has(b), "CUT_LINES contient '%s'" % b)
		_ok(EnemySpawner.BIOME_TINT.has(b), "EnemySpawner.BIOME_TINT contient '%s'" % b)
	var all_kinds: Dictionary = {
		"reacteur": ["bassin_toxique", "vanne_drainage", "poche_de_vent", "console_vent", "grille_ventilation", "zone_alternante", "cristal_instable", "pulse_energie"],
		"ruche": ["cocon", "residu_biomecanique", "sol_collant", "tentacule_emergence", "nuage_spores", "plante_lumineuse"],
		"citadelle": ["porte_securite_orbitale", "zone_depressurisation", "zone_push_pull", "emetteur_laser_rotatif", "pilier_energie", "segment_mur_modulaire"],
	}
	for biome in all_kinds:
		var biome_kinds: Array = PropScatter.BIOME_DECOR[biome]
		for k in all_kinds[biome]:
			_ok(biome_kinds.has(k), "BIOME_DECOR['%s'] contient '%s'" % [biome, k])
			_ok(PropScatter.DECOR.has(k), "DECOR['%s'] existe" % k)

	# 03/10 : BIOME_BORDER ne doit plus retomber sur le defaut rocher/arbre pour ces 3 biomes
	# (trou signale par le patron) - et chaque kind de bordure doit resoudre une vraie texture.
	for b in ["reacteur", "ruche", "citadelle"]:
		_ok(PropScatter.BIOME_BORDER.has(b), "BIOME_BORDER contient '%s' (plus de defaut rocher/arbre)" % b)
		for k in PropScatter.BIOME_BORDER.get(b, []):
			var d: Dictionary = PropScatter.DECOR.get(String(k), {})
			_ok(d.has("f"), "BIOME_BORDER['%s'] : kind '%s' resout une texture DECOR valide" % [b, k])

	var game_stub: StubGame = StubGame.new()
	add_child(game_stub)
	var plr: DummyPlayer = DummyPlayer.new()
	add_child(plr)
	plr.add_to_group("player")
	plr.global_position = Vector2(0.0, 0.0)
	var dt: float = 0.1

	# --- NOYAU INSTABLE ---
	# bassin_toxique : degats continus, suspendu par vanne_drainage
	var bassin: PropScatter.Prop = _mk_prop(game_stub, "bassin_toxique", Vector2(0.0, 0.0))
	_ok(bassin._toxic_ring != null, "bassin_toxique : a bien un anneau visuel (04/10, etait un GAP total avant - seul des 4 a infliger des degats sans jamais prevenir)")
	_ok(bassin._toxic_ring.get_child_count() > 0, "bassin_toxique : l'anneau a bien un coeur (04/10, mise a niveau halo+coeur)")
	for i in 10: bassin._process(dt)
	_ok(plr.dmg_total > 0.0, "bassin_toxique : inflige des degats continus", "total=%.1f" % plr.dmg_total)
	var vanne: PropScatter.Prop = _mk_prop(game_stub, "vanne_drainage", Vector2(0.0, 0.0))
	vanne._on_drain_filled()
	_ok(bassin._toxic_suppressed_t > 0.0, "vanne_drainage : a bien suspendu le bassin voisin")
	var dmg_avant: float = plr.dmg_total
	for i in 10: bassin._process(dt)
	_ok(plr.dmg_total == dmg_avant, "bassin_toxique : ne degate plus pendant la suspension")

	# poche_de_vent + console_vent : pousse, puis la console inverse la direction
	var vent: PropScatter.Prop = _mk_prop(game_stub, "poche_de_vent", Vector2(0.0, 0.0))
	var dir_avant: Vector2 = vent._wind_dir
	var x_avant_vent: float = 0.0
	for i in 10: vent._process(dt)
	_ok(plr.global_position.x != x_avant_vent, "poche_de_vent : a pousse le joueur")
	var console_v: PropScatter.Prop = _mk_prop(game_stub, "console_vent", Vector2(0.0, 0.0))
	game_stub.vfx_positions.clear()
	console_v._on_wind_console_filled()
	_ok(vent._wind_dir == -dir_avant, "console_vent : a inverse la direction de la poche voisine")
	var vfx_at_vent: bool = false
	for p in game_stub.vfx_positions:
		if (p as Vector2).distance_to(vent.global_position) < 1.0:
			vfx_at_vent = true
	_ok(vfx_at_vent, "poche_de_vent : le VFX de confirmation joue bien A LA POCHE affectee (04/10, WEAK avant - ne jouait qu'a la console)")

	# grille_ventilation : ne plante pas sur l'intervalle (GroundZone construite directement)
	var grille: PropScatter.Prop = _mk_prop(game_stub, "grille_ventilation", Vector2(500.0, 0.0))
	for i in 150: grille._process(dt)
	_ok(true, "grille_ventilation : tourne sur l'intervalle sans erreur (150 ticks)")

	# zone_alternante : degats uniquement pendant la phase "presente" (cycle_on)
	var alt: PropScatter.Prop = _mk_prop(game_stub, "zone_alternante", Vector2(0.0, 0.0))
	_ok(alt._cycle_present, "zone_alternante : commence en phase danger (cycle_on)")
	var dmg_avant_alt: float = plr.dmg_total
	for i in 10: alt._process(dt)
	_ok(plr.dmg_total > dmg_avant_alt, "zone_alternante : inflige des degats en phase danger")
	for i in 60: alt._process(dt)   # > cycle_on (5s) -> passe en phase sure
	_ok(not alt._cycle_present, "zone_alternante : passe bien en phase sure apres cycle_on")
	_ok(alt._alt_warn_ring.modulate.a == 0.0, "zone_alternante : pas d'alerte juste apres le basculement (encore loin de la fin de la phase sure)")
	alt._cycle_t = 0.5   # force dans la derniere seconde de la phase sure (fenetre d'alerte = 1.0s)
	alt._process(dt)
	_ok(not alt._cycle_present, "zone_alternante : toujours en phase sure juste avant le basculement")
	_ok(alt._alt_warn_ring.modulate.a > 0.0, "zone_alternante : l'alerte rampe bien dans la derniere seconde avant le danger (04/10, WEAK avant - pop instantane)")

	# cristal_instable : armement au contact puis explosion differee (auto-destruction)
	var crystal: PropScatter.Prop = _mk_prop(game_stub, "cristal_instable", Vector2(0.0, 0.0))
	crystal._on_crystal_armed()
	_ok(crystal._crystal_armed, "cristal_instable : arme au contact")
	for i in 40: crystal._process(dt)   # > 3.0s -> doit se liberer (queue_free differe)
	await get_tree().process_frame
	_ok(not is_instance_valid(crystal) or crystal.is_queued_for_deletion(),
		"cristal_instable : se detruit apres son delai d'explosion")

	# pulse_energie : tourne sans erreur
	var pulse: PropScatter.Prop = _mk_prop(game_stub, "pulse_energie", Vector2(1000.0, 0.0))
	for i in 110: pulse._process(dt)
	_ok(true, "pulse_energie : tourne sur l'intervalle sans erreur (110 ticks)")

	# --- BIOMECANIQUE ---
	# cocon : destruction -> reveil d'ennemi (meme hook que capsule_cryogenique)
	for i in 30:
		var cocon: PropScatter.Prop = _mk_prop(game_stub, "cocon", Vector2(2000.0 + i * 10.0, 0.0))
		cocon.take_damage(9999.0)
	_ok(game_stub.awaken_calls > 0, "cocon : au moins un reveil d'ennemi sur 30 destructions",
		"obtenu=%d" % game_stub.awaken_calls)

	# sol_collant : ralentit via field_slow (reutilisation directe, pas de nouveau canal)
	plr.field_slow = 1.0
	var sticky: PropScatter.Prop = _mk_prop(game_stub, "sol_collant", Vector2(0.0, 0.0))
	_ok(sticky._sticky_ring != null, "sol_collant : a bien un anneau visuel (04/10, etait un GAP total avant)")
	sticky._process(dt)
	_ok(plr.field_slow < 1.0, "sol_collant : a bien reduit field_slow", "val=%.2f" % plr.field_slow)

	# residu_biomecanique : ralentit le joueur ET attire un ennemi proche vers son centre (distinct
	# de sol_collant - verifie suite au signalement du patron sur la fusion a tort des 2 mecaniques)
	plr.field_slow = 1.0
	plr.global_position = Vector2(0.0, 0.0)
	var residu: PropScatter.Prop = _mk_prop(game_stub, "residu_biomecanique", Vector2(2500.0, 0.0))
	_ok(residu._bio_residue_ring != null, "residu_biomecanique : a bien un anneau visuel (04/10, etait un GAP total avant)")
	plr.global_position = Vector2(2500.0, 0.0)
	residu._process(dt)
	_ok(plr.field_slow < 1.0, "residu_biomecanique : a bien reduit field_slow", "val=%.2f" % plr.field_slow)
	var enemy_dummy2: Node2D = Node2D.new()
	add_child(enemy_dummy2)
	enemy_dummy2.add_to_group("enemies")
	enemy_dummy2.global_position = Vector2(2600.0, 0.0)
	var ex0b: float = enemy_dummy2.global_position.x
	for i in 10: residu._process(dt)
	_ok(enemy_dummy2.global_position.x < ex0b, "residu_biomecanique : a bien attire l'ennemi proche vers son centre")
	plr.global_position = Vector2(0.0, 0.0)   # remet le joueur en place pour les blocs suivants

	# nuage_spores : derive + degats continus + suppression par plante_lumineuse
	var spore: PropScatter.Prop = _mk_prop(game_stub, "nuage_spores", Vector2(0.0, 0.0))
	var x0_spore: float = spore.global_position.x
	var dmg_avant_spore: float = plr.dmg_total
	for i in 15: spore._process(dt)
	_ok(spore.global_position.x != x0_spore, "nuage_spores : sa position a bouge")
	_ok(plr.dmg_total > dmg_avant_spore, "nuage_spores : inflige des degats continus")
	var plante: PropScatter.Prop = _mk_prop(game_stub, "plante_lumineuse", Vector2(0.0, 0.0))
	plante.global_position = spore.global_position
	plante._on_light_plant_filled()
	_ok(spore._spore_suppressed_t > 0.0, "plante_lumineuse : a bien suspendu le nuage voisin")

	# --- FORGE FINALE ---
	# zone_depressurisation : aspire vers son centre (pas de crash sur l'intervalle)
	var depress: PropScatter.Prop = _mk_prop(game_stub, "zone_depressurisation", Vector2(300.0, 300.0))
	for i in 190: depress._process(dt)
	_ok(true, "zone_depressurisation : tourne sur l'intervalle sans erreur (190 ticks)")
	# 04/10, WEAK signale par le patron : l'aspiration et son VFX arrivaient dans la MEME frame,
	# aucune alarme avant. Force le minuteur a 0.5s (< la fenetre d'alerte de 0.7s) et verifie que
	# l'anneau d'alarme rampe AVANT le declenchement (qui n'arrive que 5 ticks plus tard).
	depress._depress_t = 0.5
	depress._process(dt)
	_ok(depress._depress_warn.modulate.a > 0.0, "zone_depressurisation : l'alarme rampe avant l'aspiration")

	# zone_push_pull : la direction du nudge s'inverse bien avec _grav_phase_on (minuteur dedie,
	# 04/10 - l'ancien partage de _cycle masquait sprite+collider pendant la phase "attire")
	var grav: PropScatter.Prop = _mk_prop(game_stub, "zone_push_pull", Vector2(0.0, 0.0))
	plr.global_position = Vector2(50.0, 0.0)
	grav._grav_phase_on = true    # phase "push" (eloigne du centre)
	var x_push_avant: float = plr.global_position.x
	grav._process(dt)
	_ok(plr.global_position.x > x_push_avant, "zone_push_pull : pousse le joueur loin du centre en phase push")
	_ok(grav._sprite == null or grav._sprite.visible, "zone_push_pull : sprite toujours visible en phase push")
	grav._grav_phase_on = false   # phase "pull" (attire vers le centre)
	var x_pull_avant: float = plr.global_position.x
	grav._process(dt)
	_ok(plr.global_position.x < x_pull_avant, "zone_push_pull : attire le joueur vers le centre en phase pull")
	_ok(grav._sprite == null or grav._sprite.visible, "zone_push_pull : sprite toujours visible en phase pull (bug corrige)")
	_ok(grav._cycle_col == null or not grav._cycle_col.disabled, "zone_push_pull : collider toujours actif en phase pull")

	# emetteur_laser_rotatif : l'angle avance a chaque activation
	var laser: PropScatter.Prop = _mk_prop(game_stub, "emetteur_laser_rotatif", Vector2(0.0, 0.0))
	var angle0: float = laser._rot_laser_angle
	for i in 70: laser._process(dt)   # > intervalle max 6s
	_ok(laser._rot_laser_angle != angle0, "emetteur_laser_rotatif : l'angle a bien avance apres un tir")

	# pilier_energie : destruction -> repousse les ennemis proches
	var enemy_dummy: Node2D = Node2D.new()
	add_child(enemy_dummy)
	enemy_dummy.add_to_group("enemies")
	enemy_dummy.global_position = Vector2(100.0, 0.0)
	var pillar: PropScatter.Prop = _mk_prop(game_stub, "pilier_energie", Vector2(0.0, 0.0))
	var ex0: float = enemy_dummy.global_position.x
	var impact_avant: int = game_stub.impact_calls
	pillar.take_damage(9999.0)
	_ok(enemy_dummy.global_position.x > ex0, "pilier_energie : a bien repousse un ennemi proche a la destruction")
	_ok(game_stub.impact_calls > impact_avant, "pilier_energie : la destruction appelle bien impact_fx (04/10, composite riche)")

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
