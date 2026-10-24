extends Node

func _ready() -> void:
	print("=== TEST COMBAT REPORT ===")
	GameState.reset()
	
	# Add damage and kills
	GameState.add_damage("autocannon", 12500.0)
	GameState.add_damage("vulcan", 48200.0)
	GameState.add_damage("plasma", 8400.0)
	GameState.add_kill(Vector2.ZERO, 1, "autocannon")
	GameState.add_kill(Vector2.ZERO, 2, "vulcan")
	
	assert(GameState.total_damage == 69100.0, "Total damage doit valoir 69100")
	assert(GameState.damage_by_weapon["vulcan"] == 48200.0, "Vulcan damage doit valoir 48200")
	print("  PASS  GameState add_damage comptabilise exactement les degats")

	var ms: MetaScreen = MetaScreen.new()
	assert(ms._format_number(48200.0) == "48.2K", "Format 48.2K")
	assert(ms._format_number(1250000.0) == "1.25M", "Format 1.25M")
	assert(ms._format_weapon_name("vulcan") == "Vulcan Barrage", "Nom Vulcan Barrage")
	print("  PASS  Formatage des nombres et noms d'armes valide")

	var v: VBoxContainer = VBoxContainer.new()
	ms._build_combat_report(v)
	assert(v.get_child_count() > 0, "Le rapport de combat doit generer des conteneurs d'affichage")
	print("  PASS  _build_combat_report genere le panneau de DPS/Degats")

	ms.free()
	v.free()
	print("=== COMBAT REPORT SMOKE PASS (0 echec(s)) ===")
	get_tree().quit(0)
