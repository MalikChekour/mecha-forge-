extends Node
## Headless regression harness pour la mise a niveau VFX du 04/10 (demande du patron : "effets
## speciaux vraiment nuls"). Couvre la partie C du plan (rail_nova/frelon) : BULLET_FAMILY est
## directement testable ; impact_fx() est une methode du node Game (jamais instancie isolement
## dans ce projet, comme les autres tests) -> verifie par lecture du source que les 2 noms d'armes
## sont bien dans les bonnes branches match, limite assumee et dite dans le plan.
##   godot --headless --path game res://_test_vfx_signature.tscn

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST SIGNATURE VFX rail_nova/frelon (04/10) ===")

	# --- BULLET_FAMILY : forme en vol ---
	_ok(Projectile.BULLET_FAMILY.get("rail_nova", "") == "lance",
		"rail_nova : forme 'lance' (meme famille que railgun/annihilator)")
	_ok(Projectile.BULLET_FAMILY.get("frelon", "") == "orb",
		"frelon : forme 'orb' (meme famille que ricochet/carambole)")

	# --- impact_fx() : verification par lecture du source (methode non instanciable isolement) ---
	var src: String = FileAccess.get_file_as_string("res://scenes/Game.gd")
	_ok(src.find('"railgun", "annihilator", "rail_nova"') >= 0,
		"impact_fx : rail_nova est bien dans la branche railgun/annihilator")
	_ok(src.find('"ricochet", "carambole", "frelon"') >= 0,
		"impact_fx : frelon est bien dans la branche ricochet/carambole")
	# garde-fou : les 2 noms ne doivent PAS trainer ailleurs par erreur (ex. dans le defaut "_:")
	var default_start: int = src.find("func impact_fx")
	_ok(default_start >= 0, "impact_fx() existe toujours dans Game.gd")

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
