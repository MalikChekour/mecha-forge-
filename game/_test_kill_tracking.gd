extends Node
## Headless regression harness for le TRACAGE DES KILLS PAR ARME + les conditions d'evolution
## reconditionnees (plan de refonte, 29/09). Teste directement Enemy.take_damage()/_die() et
## GameState.add_kill()/kills_by_weapon — sans passer par un vrai combat.
##   godot --headless --path game res://_test_kill_tracking.tscn

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

# 30/09 : le roster (EnemySpawner.DEFS) a ete vide sur demande du patron. Ce test verifie un
# MECANISME (attribution des kills par arme), pas un ennemi precis -> definition autonome, pour
# ne pas dependre d'un contenu qui peut disparaitre. "u_rodeur" est un chassis reel (art toujours
# sur disque), independant de DEFS.
const _STUB_DEF: Dictionary = {"name": "Stub", "chassis": "u_rodeur", "hp": 9999.0, "speed": 100.0, "dmg": 1.0, "radius": 20.0, "size": 100.0, "motion": "walk", "rank": 0, "w": 1, "behavior": "rush"}

func _make_enemy(kind: String) -> Enemy:
	var e: Enemy = Enemy.new()
	add_child(e)
	var plr: Node2D = Node2D.new()
	add_child(plr)
	e.setup(kind, _STUB_DEF, plr, null)
	return e

func _ready() -> void:
	print("=== TEST KILL-TRACKING PAR ARME ===")
	GameState.reset()
	_ok(GameState.kills_by_weapon.is_empty(), "kills_by_weapon vide apres reset()")

	# --- 1. un kill avec une arme trackee credite CETTE arme ---
	var e1: Enemy = _make_enemy("brute")
	e1.take_damage(9999.0, "", "railgun")
	await get_tree().process_frame   # _die() est en call_deferred
	_ok(int(GameState.kills_by_weapon.get("railgun", 0)) == 1,
		"1 kill credite a railgun", "obtenu=%d" % int(GameState.kills_by_weapon.get("railgun", 0)))
	_ok(GameState.kills == 1, "kills total = 1")

	# --- 2. un kill SANS arme (source non trackee : aura/drone/lame/orbe) ne credite AUCUNE arme ---
	var kills_avant: int = GameState.kills
	var e2: Enemy = _make_enemy("brute")
	e2.take_damage(9999.0, "")   # weapon_id absent, comme un coup d'aura
	await get_tree().process_frame
	_ok(GameState.kills == kills_avant + 1, "kills total augmente quand meme")
	_ok(int(GameState.kills_by_weapon.get("railgun", 0)) == 1,
		"kills_by_weapon['railgun'] inchange (le 2e kill n'est attribue a personne)")
	var total_apres: int = 0
	for k in GameState.kills_by_weapon:
		total_apres += int(GameState.kills_by_weapon[k])
	_ok(total_apres == 1, "aucune nouvelle arme creditee par le kill sans weapon_id")

	# --- 3. le dernier coup TRACKE l'emporte meme si un coup non-tracke suit sans achever ---
	var e3: Enemy = _make_enemy("brute")
	e3.take_damage(1.0, "", "faisceau")     # touche, ne tue pas
	e3.take_damage(9999.0, "")               # achevee par une source non trackee (garde faisceau)
	await get_tree().process_frame
	_ok(int(GameState.kills_by_weapon.get("faisceau", 0)) == 1,
		"le coup de grace non-tracke garde l'attribution du dernier coup d'arme recu")

	# --- 4. condition d'evolution type "kills" ---
	GameState.kills_by_weapon["missilepod"] = 24
	_ok(not _evo_cond_kills("missilepod", 25), "24 kills < seuil 25 -> pas eligible")
	GameState.kills_by_weapon["missilepod"] = 25
	_ok(_evo_cond_kills("missilepod", 25), "25 kills >= seuil 25 -> eligible")

	# --- 5. condition d'evolution type "meta" (en memoire uniquement, jamais SaveManager.save_data()) ---
	var meta_avant: Dictionary = SaveManager.data.get("meta", {}).duplicate(true)
	SaveManager.data["meta"] = {"puissance": 2}
	_ok(SaveManager.meta_level("puissance") == 2, "meta_level lit la valeur en memoire (2)")
	SaveManager.data["meta"] = {"puissance": 3}
	_ok(SaveManager.meta_level("puissance") >= 3, "meta_level lit la valeur en memoire (3) -> eligible")
	SaveManager.data["meta"] = meta_avant   # restaure, jamais persiste sur disque

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)

## Reproduit exactement la logique de Game._evo_cond_met() pour le type "kills", sans dependre
## d'une instance Game/Player/WeaponSystem complete.
func _evo_cond_kills(base: String, count: int) -> bool:
	return int(GameState.kills_by_weapon.get(base, 0)) >= count
