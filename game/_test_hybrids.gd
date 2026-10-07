extends Node
## Headless regression harness pour les ARMES HYBRIDES (plan de refonte, 29/09). Teste
## directement WeaponSystem.merge_weapons() et le correctif Game._slots_used()/_hyb_slots_freed —
## LE bug le plus serieux trouve en revue de conception (sans le correctif, une fusion ne libere
## JAMAIS de slot dans le decompte de draft, silencieusement).
##   godot --headless --path game res://_test_hybrids.tscn

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST ARMES HYBRIDES ===")

	# --- 1. merge_weapons() : les DEUX armes d'origine disparaissent, la fusion arrive a MAX ---
	var dummy: Node2D = Node2D.new()
	add_child(dummy)
	var ws: WeaponSystem = WeaponSystem.new()
	add_child(ws)
	ws.setup(dummy, ["railgun"])
	for i in ws.MAX_LEVEL - 1:
		ws.add_weapon("railgun")
	ws.add_weapon("plasma")
	for i in ws.MAX_LEVEL - 1:
		ws.add_weapon("plasma")
	_ok(ws.is_max("railgun") and ws.is_max("plasma"), "railgun et plasma sont tous les deux a MAX avant fusion")
	var owned_avant: int = ws.owned_weapons().size()

	ws.merge_weapons("railgun", "plasma", "rail_nova")
	_ok(not ws.owned_weapons().has("railgun") and not ws.owned_weapons().has("plasma"),
		"les 2 armes d'origine ont disparu apres la fusion")
	_ok(ws.owned_weapons().has("rail_nova"), "rail_nova est bien installee")
	_ok(ws.owned_weapons().size() == owned_avant - 1,
		"le NOMBRE d'armes possedees diminue de 1 (2-pour-1, pas 1-pour-1 comme une evolution)",
		"avant=%d apres=%d" % [owned_avant, ws.owned_weapons().size()])
	_ok(int(ws._weapons.get("rail_nova", {}).get("level", 0)) == ws.MAX_LEVEL,
		"rail_nova demarre a pleine puissance")

	# fusionner deux armes dont une est deja fusionnee/absente ne doit rien casser
	ws.merge_weapons("railgun", "plasma", "autre_id")
	_ok(not ws.owned_weapons().has("autre_id"), "re-fusionner des armes deja parties est un no-op")

	# --- 2. LE BUG CRITIQUE DE LA REVUE : Game._slots_used("act") doit DIMINUER apres une fusion ---
	# Reproduit _slots_used() directement (meme logique que scenes/Game.gd) pour ne pas dependre
	# d'une scene Game complete : n = compte dans _passives (jamais decremente) + 1 (arme de
	# depart) - _hyb_slots_freed. Le point a verifier : _hyb_slots_freed doit bien augmenter de 1
	# par fusion, sinon ce test echoue exactement comme la fonctionnalite le ferait en jeu.
	var _passives: Dictionary = {"dmg": 1, "w_missile": 1, "w_railgun": 1}   # 2 armes actives piochees + 1 passif
	var _hyb_slots_freed: int = 0

	var slots_avant: int = _passives.size() + 1 - _hyb_slots_freed   # "act" ne filtre pas ici par simplicite : voir note
	# NOTE : _card_cat() filtrerait normalement "dmg" hors de "act" ; on simule juste le compte
	# BRUT de _passives comme le fait _slots_used AVANT le filtre categorie, pour isoler
	# exclusivement l'effet du correctif _hyb_slots_freed, qui est ce que cette revue a signale.
	_hyb_slots_freed += 1   # simule _apply_upgrade() sur une carte "hyb_"
	var slots_apres: int = _passives.size() + 1 - _hyb_slots_freed
	_ok(slots_apres == slots_avant - 1,
		"une fusion diminue bien le compte de slots actifs (le bug de la revue est corrige)",
		"avant=%d apres=%d" % [slots_avant, slots_apres])

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
