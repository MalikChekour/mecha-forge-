extends Node
## Test de validation du Plan d'Amélioration (Piliers 1 & 2 : Bestiaire tripartite & Décors interactifs)

class StubGame extends Node:
	var enemy_layer: Node2D = Node2D.new()
	var projectile_layer: Node2D = Node2D.new()
	var cover_list: Array = []
	var spawner: EnemySpawner = null
	var drops: Array = []
	var vfx_spawned: Array = []
	func _ready() -> void:
		add_child(enemy_layer)
		add_child(projectile_layer)
	func spawn_enemy_bolt(_pos, _dir, _dmg, _col = Color.WHITE, _scl = 1.0, _spd = 300.0, _homing = false, _ht = 0.0, _tag: String = "") -> void: pass
	func spawn_vfx(kind: String, pos: Vector2, _rot = 0.0, _scl = 1.0, _col = Color.WHITE) -> void:
		vfx_spawned.append([kind, pos])
	func spawn_heal(pos: Vector2) -> void:
		drops.append(["heal", pos])
	func spawn_scrap(pos: Vector2, count: int = 1) -> void:
		drops.append(["scrap", pos, count])
	func spawn_xp(pos: Vector2, count: int = 1) -> void:
		drops.append(["xp", pos, count])
	func death_fx(_pos, _rank, _final) -> void: pass
	func impact_fx(_pos, _col, _kind, _dir, _scl) -> void: pass
	func show_banner(_t: String, _c = Color.WHITE) -> void: pass

class FakePlayer extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var base_speed: float = 300.0
	var chassis_family: String = "vortex"
	var hp: float = 100.0
	var max_hp: float = 100.0
	func take_damage(_dmg: float, _src = Vector2.ZERO, _tag: String = "") -> void: pass

var _fail: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + msg)
	if not ok:
		_fail += 1

func _ready() -> void:
	print("=== VALIDATION PLAN AMELIORATION MECHA-FORGE ===")
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

	# 1. TEST PILIER 1 : Diversification du Bestiaire (18 biomes x 4 rôles)
	print("\n--- TEST 1 : BESTIAIRE TRIPARTITE PAR BIOME ---")
	var biomes: Array = ["tech", "desert", "jungle", "volcanic", "swamp", "cryo", "reacteur", "ruche", "citadelle",
		"abyss", "ether", "titans", "orbit", "quantum", "ozone", "prism", "steampunk", "colosseum"]
	
	for b in biomes:
		var pool: Array = EnemySpawner.BIOME_POOL.get(b, [])
		_check(pool.size() >= 4, "%-10s : 4 archétypes dans le pool (%s)" % [b, str(pool)])
		var base_k: String = String(pool[0])
		var swarm_k: String = String(pool[1])
		var shield_k: String = String(pool[2])
		var sniper_k: String = String(pool[3])
		var elite_k: String = String(pool[4]) if pool.size() >= 5 else ""

		_check(EnemySpawner.DEFS.has(swarm_k), "%s : DEFS contient %s" % [b, swarm_k])
		_check(EnemySpawner.DEFS.has(shield_k), "%s : DEFS contient %s" % [b, shield_k])
		_check(EnemySpawner.DEFS.has(sniper_k), "%s : DEFS contient %s" % [b, sniper_k])
		_check(EnemySpawner.DEFS.has(elite_k), "%s : DEFS contient %s" % [b, elite_k])

		sp.current_biome = b
		var d_swarm: Dictionary = sp._def_for(swarm_k)
		var d_shield: Dictionary = sp._def_for(shield_k)
		var d_sniper: Dictionary = sp._def_for(sniper_k)
		var d_elite: Dictionary = sp._def_for(elite_k)

		_check(String(d_swarm.get("behavior", "")) == "rush", "%s : swarm a behavior=rush (vitesse %.0f)" % [b, float(d_swarm.get("speed", 0.0))])
		_check(bool(d_shield.get("garde", false)) and float(d_shield.get("shield", 0.0)) > 0.0, "%s : shield a garde=true et shield=%.0f" % [b, float(d_shield.get("shield", 0.0))])
		_check(String(d_sniper.get("tir_style", "")) == "sniper", "%s : sniper a tir_style=sniper (portée %.0f)" % [b, float(d_sniper.get("prefer_dist", 0.0))])
		_check(bool(d_elite.get("contact_sword", false)) and String(d_elite.get("special_vfx", "")) != "", "%s : elite a contact_sword=true et special_vfx=%s" % [b, String(d_elite.get("special_vfx", ""))])

	# 2. TEST ESCOUADE COMBINEE (Armes combinées : Chef + Shield + Sniper + Swarmers)
	print("\n--- TEST 2 : COMPOSITION TACTIQUE DE L'ESCOUADE ---")
	sp.current_biome = "tech"
	sp._squads.clear()
	sp._spawn_squad()
	_check(sp._squads.size() == 1, "escouade créée dans le biome tech")
	if not sp._squads.is_empty():
		var sq: Squad = sp._squads[0]
		var members: Array = sq.live()
		_check(members.size() >= 4, "escouade compte %d membres" % members.size())
		var has_shield: bool = false
		var has_sniper: bool = false
		var has_swarm: bool = false
		for m in members:
			var en: Enemy = m as Enemy
			if en.garde and en.shield_max > 0.0:
				has_shield = true
			if en.tir_style == "sniper":
				has_sniper = true
			if en.behavior == "rush":
				has_swarm = true
		_check(has_shield, "présence d'un Tank Blindé avec bouclier dans l'escouade")
		_check(has_sniper, "présence d'une Sentinelle Laser Sniper dans l'escouade")
		_check(has_swarm, "présence de Drones d'Assaut Rapides dans l'escouade")

	# 3. TEST PILIER 2 : Décors Interactifs (Cuves IEM, Générateurs de Scrap, Barricades)
	print("\n--- TEST 3 : DECORS INTERACTIFS & EFFETS TACTIQUES ---")
	_check(PropScatter.DECOR.has("cuve_promethee"), "DECOR contient cuve_promethee")
	_check(PropScatter.DECOR.has("generateur_scrap"), "DECOR contient generateur_scrap")
	_check(PropScatter.DECOR.has("barricade_blindee"), "DECOR contient barricade_blindee")

	# Test Stun sur Enemy
	var dummy_enemy: Enemy = Enemy.new()
	g.enemy_layer.add_child(dummy_enemy)
	dummy_enemy.setup("mech01", sp._def_for("mech01"), pl, g)
	_check(dummy_enemy.stun_t == 0.0, "ennemi initialement non étourdi")
	dummy_enemy.apply_stun(2.5)
	_check(dummy_enemy.stun_t == 2.5, "apply_stun(2.5) fixe stun_t à 2.5s")
	dummy_enemy.velocity = Vector2(200, 200)
	dummy_enemy._physics_process(0.5)
	_check(dummy_enemy.stun_t == 2.0, "stun_t décroît correctement (2.0s restantes)")
	_check(dummy_enemy.velocity.length() < 10.0, "vitesse de l'ennemi stoppée pendant le stun")

	# Test Explosion Cuve de Prométhée (Baril IEM)
	var scatter: PropScatter = PropScatter.new()
	scatter.game = g
	scatter.biome = "tech"
	add_child(scatter)
	
	var emp_def: Dictionary = PropScatter.DECOR["cuve_promethee"]
	var p_emp = scatter._place("cuve_promethee", Vector2(100, 100), 1.0, 0.0, false)
	_check(p_emp._emp_barrel, "Prop cuve_promethee a _emp_barrel=true")
	_check(p_emp._emp_stun == 2.5, "Prop cuve_promethee stun = 2.5s")
	
	# Placer un ennemi à proximité de la cuve avec assez de PV pour survivre à l'explosion
	dummy_enemy.global_position = Vector2(140, 100)
	dummy_enemy.hp = 200.0
	dummy_enemy.hp_max = 200.0
	dummy_enemy.alive = true
	dummy_enemy.stun_t = 0.0
	var hp_before: float = dummy_enemy.hp
	p_emp.take_damage(999.0)   # Détruire la cuve IEM
	_check(dummy_enemy.hp < hp_before, "l'explosion IEM a infligé des dégâts à l'ennemi")
	_check(dummy_enemy.stun_t >= 2.4, "l'ennemi a été étourdi par l'onde IEM")

	# Test Générateur de Scrap (style Arbre de Brotato)
	g.drops.clear()
	var p_scrap = scatter._place("generateur_scrap", Vector2(300, 300), 1.0, 0.0, false)
	_check(p_scrap._scrap_generator, "Prop generateur_scrap a _scrap_generator=true")
	p_scrap.take_damage(999.0)
	var got_heal: bool = false
	var got_scrap: bool = false
	for d in g.drops:
		if d[0] == "heal": got_heal = true
		if d[0] == "scrap": got_scrap = true
	_check(got_heal, "générateur de scrap a lâché un kit de nanites (soin garanti)")
	_check(got_scrap, "générateur de scrap a lâché du scrap")

	print("\n=== BILAN : %d ÉCHEC(S) ===" % _fail)
	if _fail == 0:
		print(">>> TOUS LES TESTS DU PLAN D'AMELIORATION SONT VERTS (SUCCES) <<<")
	get_tree().quit(1 if _fail > 0 else 0)
