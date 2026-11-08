extends Node
## Headless regression harness pour les 4 nouveaux boss de chapitre (plan "5 arenes de boss" :
## cryo/reacteur/ruche/citadelle). Teste BOSS_PHASE_THRESHOLDS/CHAPTER_FINAL_BOSS + les hooks de
## phase 3 sur Enemy, sans Game.tscn ni horloge de boss reelle.
##   godot --headless --path game res://_test_boss_chapitres.tscn
##
## 04/10 : ces 4 boss sont DESACTIVES dans EnemySpawner.DEFS pour la publication itch ("sans
## ennemis", demande du patron) - voir le commentaire dans EnemySpawner.gd. Ce test garde SA PROPRE
## copie des stats (BOSS_DEFS ci-dessous, identique aux lignes commentees) pour continuer a verifier
## le comportement cote Enemy independamment de l'etat active/desactive du roster.
const BOSS_DEFS: Dictionary = {
	"cryoboss":      {"name": "Le Cryarque",   "chassis": "cryoboss",      "hp": 2800.0, "speed": 236.0, "dmg": 30.0, "radius": 78.0, "size": 360.0, "rank": 4, "w": 0, "final": true, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 26.0, "attack_cd": 2.2, "prefer_dist": 360.0, "shield": 380.0},
	"reacteurboss":  {"name": "Le Fulgurant",  "chassis": "reacteurboss",  "hp": 2940.0, "speed": 240.0, "dmg": 31.0, "radius": 78.0, "size": 370.0, "rank": 4, "w": 0, "final": true, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 27.0, "attack_cd": 2.2, "prefer_dist": 360.0, "shield": 400.0},
	"rucheboss":     {"name": "La Matriarche", "chassis": "rucheboss",     "hp": 3080.0, "speed": 244.0, "dmg": 32.0, "radius": 80.0, "size": 385.0, "rank": 4, "w": 0, "final": true, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 28.0, "attack_cd": 2.2, "prefer_dist": 360.0, "shield": 420.0},
	"citadelleboss": {"name": "L'Arcange",     "chassis": "citadelleboss", "hp": 3220.0, "speed": 248.0, "dmg": 34.0, "radius": 82.0, "size": 400.0, "rank": 4, "w": 0, "final": true, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 30.0, "attack_cd": 2.2, "prefer_dist": 360.0, "shield": 440.0},
}

class StubGame extends Node:
	var enemy_layer: Node2D
	var zone_calls: Array = []
	func _init() -> void:
		enemy_layer = Node2D.new(); add_child(enemy_layer)
	func spawn_ground_zone(_pos: Vector2, _radius: float, _delay: float, _dmg: float, _color: Color = Color.WHITE, _fx_kind: String = "decor_hit", _shape: String = "circle", _line_from: Vector2 = Vector2.ZERO, _line_to: Vector2 = Vector2.ZERO) -> void:
		zone_calls.append({"radius": _radius, "dmg": _dmg, "color": _color})
	func spawn_vfx(_kind: String, _pos: Vector2, _rot: float, _scale: float, _color: Color) -> void:
		pass
	func show_banner(_txt: String, _col: Color = Color.WHITE) -> void:
		pass

class DummyPlayer extends Node2D:
	var field_slow: float = 1.0
	var dmg_total: float = 0.0
	var stun_calls: int = 0
	func take_damage(amount: float, _pos: Vector2 = Vector2.ZERO, _tag: String = "") -> void:
		dmg_total += amount
	func stun(_d: float) -> void:
		stun_calls += 1

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _make_boss(kind: String, pos: Vector2, plr_pos: Vector2) -> Dictionary:
	var gs: StubGame = StubGame.new(); add_child(gs)
	var plr: DummyPlayer = DummyPlayer.new(); add_child(plr); plr.global_position = plr_pos
	var e: Enemy = Enemy.new(); add_child(e)
	e.setup(kind, BOSS_DEFS[kind], plr, gs)
	e.global_position = pos
	return {"e": e, "gs": gs, "plr": plr}

func _ready() -> void:
	print("=== TEST 4 NOUVEAUX BOSS DE CHAPITRE (cryo/reacteur/ruche/citadelle) ===")
	GameState.reset()

	var kinds: Array = ["cryoboss", "reacteurboss", "rucheboss", "citadelleboss"]

	# --- 1. BOSS_DEFS (copie locale, cf. commentaire en tete de fichier) bien formees, et
	# BOSS_PHASE_THRESHOLDS (toujours actif dans EnemySpawner, independant de DEFS) pret ---
	for k in kinds:
		_ok(not EnemySpawner.DEFS.has(k), "DEFS NE contient PAS '%s' (desactive pour la pub itch, 04/10)" % k)
		var d: Dictionary = BOSS_DEFS.get(k, {})
		_ok(bool(d.get("final", false)), "%s : final == true" % k)
		_ok(int(d.get("rank", 0)) >= 4, "%s : rank >= 4" % k, "rank=%d" % int(d.get("rank", 0)))
		_ok(int(d.get("w", -1)) == 0, "%s : w == 0 (hors pool aleatoire)" % k)
		_ok(String(d.get("chassis", "")) != "", "%s : chassis defini" % k)
		_ok(bool(d.get("ogive", false)) and bool(d.get("heavy", false)) and String(d.get("behavior","")) == "ranged",
			"%s : ranged+heavy+ogive (necessaire pour _fire_ogive)" % k)
		_ok(EnemySpawner.BOSS_PHASE_THRESHOLDS.get(k, []).size() >= 2,
			"BOSS_PHASE_THRESHOLDS['%s'] a bien 2 seuils (phase 3 atteignable)" % k)

	# --- 2. override chapitre -> kind, testable sans horloge de boss ---
	var sp: EnemySpawner = EnemySpawner.new(); add_child(sp)
	_ok(sp._final_boss_for(1, false) == "belier01", "chapitre 1 -> belier01 (inchange)")
	_ok(sp._final_boss_for(2, false) == "endboss", "chapitre 2 -> endboss (inchange)")
	_ok(sp._final_boss_for(5, false) == "endboss", "chapitre 5 -> endboss (inchange)")
	_ok(sp._final_boss_for(6, false) == "cryoboss", "chapitre 6 -> cryoboss")
	_ok(sp._final_boss_for(7, false) == "reacteurboss", "chapitre 7 -> reacteurboss")
	_ok(sp._final_boss_for(8, false) == "rucheboss", "chapitre 8 -> rucheboss")
	_ok(sp._final_boss_for(9, false) == "citadelleboss", "chapitre 9 -> citadelleboss")
	_ok(sp._final_boss_for(6, true) == "endboss", "SANS FIN desactive l'override meme au chapitre 6")

	var dt: float = 0.1

	# --- 3. CRYOBOSS phase 3 : GroundZone avec stun_duration, qui stun reellement le joueur ---
	var c1: Dictionary = _make_boss("cryoboss", Vector2.ZERO, Vector2(50.0, 0.0))
	var e1: Enemy = c1["e"]; var gs1: StubGame = c1["gs"]; var plr1: DummyPlayer = c1["plr"]
	e1._phase_idx = 2
	e1._apply_boss_phase(2)
	for i in 40: e1._physics_process(dt)   # arme (0.2s) + declenche (CRYO_HAZARD_CD=2.3s) : marge large
	var gz: GroundZone = null
	for ch in gs1.enemy_layer.get_children():
		if ch is GroundZone: gz = ch
	_ok(gz != null, "cryoboss phase 3 : une GroundZone apparait sous enemy_layer")
	_ok(gz != null and gz.stun_duration > 0.0, "cryoboss phase 3 : la GroundZone porte un stun_duration > 0")
	if gz != null:
		for i in 20: gz._process(dt)   # > delay (1.0s) -> explosion
		_ok(plr1.stun_calls > 0, "cryoboss phase 3 : l'explosion applique bien un stun au joueur")

	# --- 4. REACTEURBOSS phase 3 : alterne zone chargee / zone ventee ---
	var c2: Dictionary = _make_boss("reacteurboss", Vector2.ZERO, Vector2(999.0, 0.0))
	var e2: Enemy = c2["e"]; var gs2: StubGame = c2["gs"]
	e2._phase_idx = 2
	e2._apply_boss_phase(2)
	for i in 25: e2._physics_process(dt)   # arme + 1er declenchement (REACTEUR_HAZARD_CD=1.8s)
	_ok(gs2.zone_calls.size() >= 1, "reacteurboss phase 3 : une 1ere GroundZone declenchee")
	for i in 20: e2._physics_process(dt)   # 2e declenchement
	_ok(gs2.zone_calls.size() >= 2, "reacteurboss phase 3 : une 2e GroundZone declenchee")
	if gs2.zone_calls.size() >= 2:
		var d1: float = float(gs2.zone_calls[0]["dmg"]); var d2: float = float(gs2.zone_calls[1]["dmg"])
		_ok((d1 > 0.0) != (d2 > 0.0), "reacteurboss phase 3 : alterne bien chargee/ventee", "d1=%.1f d2=%.1f" % [d1, d2])

	# --- 5. RUCHEBOSS phase 3 : aura continue de field_slow a portee ---
	var c3: Dictionary = _make_boss("rucheboss", Vector2.ZERO, Vector2(100.0, 0.0))
	var e3: Enemy = c3["e"]; var plr3: DummyPlayer = c3["plr"]
	_ok(plr3.field_slow == 1.0, "rucheboss : field_slow intact avant la phase 3")
	e3._phase_idx = 2
	for i in 5: e3._physics_process(dt)
	_ok(plr3.field_slow < 1.0, "rucheboss phase 3 : l'aura reduit field_slow du joueur a portee", "val=%.2f" % plr3.field_slow)

	# --- 6. CITADELLEBOSS phase 3 : pousse puis attire (alternance) ---
	var c4: Dictionary = _make_boss("citadelleboss", Vector2.ZERO, Vector2(200.0, 0.0))
	var e4: Enemy = c4["e"]; var plr4: DummyPlayer = c4["plr"]
	e4._phase_idx = 2
	e4._apply_boss_phase(2)
	for i in 5: e4._physics_process(dt)   # 1ere pulsion (pousse)
	var x_after_1: float = plr4.global_position.x
	_ok(x_after_1 > 200.0, "citadelleboss phase 3 : la 1ere pulsion pousse le joueur plus loin")
	for i in 32: e4._physics_process(dt)   # > CITADELLE_PULSE_CD (3.0s) -> 2e pulsion (attire)
	_ok(plr4.global_position.x < x_after_1, "citadelleboss phase 3 : la 2e pulsion attire (alternance confirmee)")

	# --- 7. chemin pilote par les PV (pas seulement l'appel manuel) atteint bien idx==2 ---
	var c5: Dictionary = _make_boss("cryoboss", Vector2.ZERO, Vector2(9999.0, 0.0))
	var e5: Enemy = c5["e"]
	e5.hp = e5.hp_max * 0.45; e5._check_boss_phase()
	e5.hp = e5.hp_max * 0.15; e5._check_boss_phase()
	_ok(e5._phase_idx == 2, "cryoboss : la chute de PV seule atteint bien la phase 3", "idx=%d" % e5._phase_idx)

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
