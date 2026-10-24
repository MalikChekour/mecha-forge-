extends Node

func _ready() -> void:
	print("=== TEST GEAR MERGE 3-IN-1 ===")
	# Backup current parts
	var backup_parts = SaveManager.data.get("parts", []).duplicate(true)
	var backup_eq = SaveManager.data.get("equipped", {}).duplicate(true)
	
	# Setup test inventory: 3 common blindage pieces, 1 equipped
	SaveManager.data["parts"] = [
		{"uid": 101, "slot": "blindage", "rarity": "commun", "level": 1},
		{"uid": 102, "slot": "blindage", "rarity": "commun", "level": 2},
		{"uid": 103, "slot": "blindage", "rarity": "commun", "level": 1},
	]
	SaveManager.data["equipped"] = {"blindage": 102}
	
	assert(SaveManager.gear_can_merge("blindage", "commun"), "Doit pouvoir fusionner 3x commun")
	assert(not SaveManager.gear_can_merge("blindage", "rare"), "Ne doit pas pouvoir fusionner rare")
	print("  PASS  gear_can_merge detecte l'eligibilite 3-en-1")
	
	var merged = SaveManager.gear_merge("blindage", "commun")
	assert(not merged.is_empty(), "La fusion doit reussir")
	assert(merged["rarity"] == "rare", "La rarete resultante doit etre 'rare'")
	assert(merged["level"] == 2, "Le niveau max (2) doit etre conserve")
	assert(SaveManager.data["parts"].size() == 1, "Il ne doit rester qu'1 seule piece dans l'inventaire")
	assert(int(SaveManager.data["equipped"]["blindage"]) == int(merged["uid"]), "La nouvelle piece doit rester equipee")
	print("  PASS  gear_merge combine 3x commun -> 1x rare et conserve l'equipement")

	# Test auto_merge_all
	SaveManager.data["parts"] = [
		{"uid": 201, "slot": "arme", "rarity": "commun", "level": 1},
		{"uid": 202, "slot": "arme", "rarity": "commun", "level": 1},
		{"uid": 203, "slot": "arme", "rarity": "commun", "level": 1},
		{"uid": 204, "slot": "arme", "rarity": "rare", "level": 1},
		{"uid": 205, "slot": "arme", "rarity": "rare", "level": 1},
	]
	# After merging 3x commun into 1x rare, we now have 3x rare -> can cascade into epique!
	var cascades = SaveManager.gear_auto_merge_all()
	assert(cascades == 2, "Doit faire 2 fusions en cascade (3 commun -> 1 rare, puis 3 rare -> 1 epique)")
	assert(SaveManager.data["parts"][0]["rarity"] == "epique", "La piece resultante doit etre epique")
	print("  PASS  gear_auto_merge_all effectue les fusions en cascade")

	# Restore backup
	SaveManager.data["parts"] = backup_parts
	SaveManager.data["equipped"] = backup_eq
	SaveManager.save_data()
	
	print("=== GEAR MERGE SMOKE PASS (0 echec(s)) ===")
	get_tree().quit(0)
