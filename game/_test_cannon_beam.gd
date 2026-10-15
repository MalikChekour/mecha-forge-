extends Node

class StubGame extends Node:
	var vfx_calls: int = 0
	var impact_calls: int = 0
	func spawn_vfx(_kind: String, _pos: Vector2, _rot: float, _scale: float, _color: Color) -> void:
		vfx_calls += 1
	func impact_fx(_pos: Vector2, _color: Color, _kind: String, _dir: Vector2 = Vector2.ZERO, _scale: float = 1.0) -> void:
		impact_calls += 1
	func show_hint(_text: String, _color: Color, _dur: float) -> void:
		pass

class DummyPlayer extends CharacterBody2D:
	var hp: float = 100.0
	var hit_count: int = 0
	var field_slow: float = 1.0
	func _init() -> void:
		add_to_group("player")
	func take_damage(amount: float, _from_pos: Vector2 = Vector2.ZERO) -> void:
		hp -= amount
		hit_count += 1

class DummyEnemy extends CharacterBody2D:
	var hp: float = 200.0
	var hit_count: int = 0
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(amount: float) -> void:
		hp -= amount
		hit_count += 1

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST CANON A RAYON AUTOMATIQUE (TOURELLE) ===")
	GameState.reset()
	var game_stub: StubGame = StubGame.new()
	add_child(game_stub)

	var plr: DummyPlayer = DummyPlayer.new()
	add_child(plr)
	plr.global_position = Vector2(0.0, 0.0)

	var tourelle: PropScatter.Prop = PropScatter.Prop.new()
	tourelle.game = game_stub
	tourelle.kind = "tourelle"
	tourelle.def = PropScatter.DECOR["tourelle"]
	tourelle.position = Vector2(300.0, 300.0)
	tourelle.rand_scale = 1.0
	tourelle.skill_roll = 0.0
	tourelle.flip = false
	add_child(tourelle)

	# 1. Verification initialisation
	_ok(tourelle._cannon_beam, "Tourelle a bien le mode _cannon_beam active")
	_ok(tourelle._cannon_beam_glow != null, "Ligne de glow du rayon instanciee")
	_ok(tourelle._cannon_beam_line != null, "Ligne de corps du rayon instanciee")
	_ok(tourelle._cannon_beam_core != null, "Ligne de coeur du rayon instanciee")
	_ok(tourelle._cannon_beam_flash != null, "Muzzle flash du canon instancie")
	_ok(not tourelle._cannon_beam_line.visible, "Rayon invisible au depart (etat idle)")

	# 2. Cycle automatique vers le telegraph (charge)
	tourelle._cannon_beam_t = 0.05
	tourelle._process(0.06)
	_ok(tourelle._cannon_beam_state == 1, "Passe en etat telegraph / charge")
	_ok(tourelle._cannon_beam_line.visible, "Ligne de visee/telegraph visible pendant la charge")
	_ok(tourelle._cannon_beam_core.visible, "Ligne de coeur visible pendant la charge")

	# 3. Positionnement d'un ennemi et du joueur sur l'axe du rayon
	# 15/10 : la tourelle a canon pivotant tire depuis le bout de son canon, dans l'axe de l'image
	var muzzle_pt: Vector2 = tourelle.muzzle_world() if tourelle.has_head() else tourelle.global_position + tourelle._muzzle
	var ray_axis: Vector2 = tourelle.head_dir() if tourelle.has_head() else tourelle._cannon
	plr.global_position = muzzle_pt + ray_axis * 200.0

	var enemy: DummyEnemy = DummyEnemy.new()
	add_child(enemy)
	enemy.global_position = muzzle_pt + ray_axis * 400.0

	# 4. Cycle vers le tir du rayon (discharge)
	tourelle._cannon_beam_t = 0.01
	tourelle._process(0.02)
	_ok(tourelle._cannon_beam_state == 2, "Passe en etat tir de rayon actif")
	_ok(plr.hit_count > 0, "Le joueur sur la ligne du rayon prend des degats", "hp=%.1f" % plr.hp)
	_ok(enemy.hit_count > 0, "L'ennemi dans la ligne du rayon prend des degats (degats collateraux)", "hp=%.1f" % enemy.hp)
	_ok(tourelle._cannon_beam_flash.visible, "Muzzle flash actif pendant le tir")

	# 5. Pas de multi-hit par frame (anti-shredding injuste)
	var plr_hp_before: float = plr.hp
	tourelle._process(0.05)
	_ok(plr.hp == plr_hp_before, "Hit tracking protege le joueur d'un tick par frame", "hp=%.1f" % plr.hp)

	# 6. Cycle de retour a idle
	tourelle._cannon_beam_t = 0.01
	tourelle._process(0.02)
	_ok(tourelle._cannon_beam_state == 0, "Retourne a l'etat idle")
	_ok(not tourelle._cannon_beam_line.visible, "Rayon redevenu invisible")
	_ok(not tourelle._cannon_beam_flash.visible, "Flash redevenu invisible")

	# 7. Piratage de la tourelle : bascule en mode allie cyan
	var hp_full: float = tourelle.hp
	tourelle.take_damage(hp_full * 0.7)
	_ok(tourelle._hacked, "Tourelle correctement pirate sous le seuil de PV")

	# En mode pirate, le joueur est immunise et l'ennemi subit des degats supercharges
	plr.hit_count = 0
	enemy.hit_count = 0
	var enemy_hp_before: float = enemy.hp
	tourelle._cannon_beam_t = 0.01
	tourelle._process(0.02) # -> telegraph
	tourelle._cannon_beam_t = 0.01
	tourelle._process(0.02) # -> fire
	_ok(plr.hit_count == 0, "Joueur immunise contre la tourelle pirate")
	_ok(enemy.hit_count > 0, "Tourelle pirate inflige des degats a l'ennemi")
	_ok(enemy.hp < enemy_hp_before, "Ennemi a subi de lourds degats du rayon allie")

	# 8. Destruction et nettoyage : _clear_beam
	tourelle.take_damage(1000.0)
	_ok(not tourelle._cannon_beam_line.visible, "Ligne masquee apres destruction")
	_ok(not tourelle._cannon_beam_flash.visible, "Flash masque apres destruction")

	# 9. Verification globale : Tous les canons (g27) fonctionnent, tapis ralentisseur recentre
	var fake_cannon_prop: PropScatter.Prop = PropScatter.Prop.new()
	fake_cannon_prop.game = game_stub; fake_cannon_prop.kind = "tourelle_test"
	fake_cannon_prop.def = {"f": "g27", "hp": 100.0, "sz": 150.0}
	fake_cannon_prop.position = Vector2(0.0, 0.0); fake_cannon_prop.rand_scale = 1.0; fake_cannon_prop.flip = false
	add_child(fake_cannon_prop)
	_ok(fake_cannon_prop._cannon_beam, "Tout decor utilisant l'art g27 a bien le rayon de canon active")

	# Tapis ralentisseur recentre : block 0.0, anneau visuel, et ralentissement de vitesse (field_slow)
	var tapis: PropScatter.Prop = PropScatter.Prop.new()
	tapis.game = game_stub; tapis.kind = "convoyeur_sol"; tapis.def = PropScatter.DECOR["convoyeur_sol"]
	tapis.position = Vector2(50.0, 50.0); tapis.rand_scale = 1.0; tapis.skill_roll = 0.0; tapis.flip = false
	add_child(tapis)
	_ok(float(tapis.def.get("block", 1.0)) == 0.0, "Tapis ralentisseur : block == 0.0 (infranchissable supprime, 100% marchable)")
	_ok(tapis._conveyor_ring != null, "Tapis ralentisseur : anneau visuel lumineux centre instancie")
	plr.global_position = Vector2(50.0, 50.0)
	plr.set("field_slow", 1.0)
	tapis._process(0.05)
	_ok(float(plr.get("field_slow")) < 0.6, "Tapis ralentisseur : applique bien le ralentissement (field_slow <= 0.52)",
		"field_slow=%.2f" % float(plr.get("field_slow")))

	# Verification convoyeur : n'utilise plus g27 (canon) mais bien son art dedie
	_ok(String(PropScatter.DECOR["convoyeur"].get("f", "")) != "g27", "convoyeur n'utilise plus l'art g27 du canon")

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
