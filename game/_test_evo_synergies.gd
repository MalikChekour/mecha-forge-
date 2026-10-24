extends Node

func _ready() -> void:
	print("=== TEST EVO SYNERGIES ===")
	var game_script = load("res://scenes/Game.gd")
	var g: Node2D = Node2D.new()
	g.set_script(game_script)
	
	# Verify EVO_RULES has all 9 weapons
	assert(g.EVO_RULES.size() == 9, "Doit avoir 9 regles d'evolution")
	print("  PASS  9 regles d'evolution presentes")
	
	# Check canonical synergies
	assert(g.EVO_RULES["autocannon"]["passive"] == "he_fuel", "Autocannon synergise avec he_fuel")
	assert(g.EVO_RULES["missilepod"]["passive"] == "ammo", "Missilepod synergise avec ammo")
	assert(g.EVO_RULES["railgun"]["passive"] == "haste", "Railgun synergise avec haste")
	assert(g.EVO_RULES["plasma"]["passive"] == "dmg", "Plasma synergise avec dmg")
	assert(g.EVO_RULES["sabre"]["passive"] == "armor", "Sabre synergise avec armor")
	assert(g.EVO_RULES["disperseur"]["passive"] == "crit", "Disperseur synergise avec crit")
	assert(g.EVO_RULES["ricochet"]["passive"] == "magnet", "Ricochet synergise avec magnet")
	assert(g.EVO_RULES["disque"]["passive"] == "spd", "Disque synergise avec spd")
	assert(g.EVO_RULES["faisceau"]["passive"] == "goldgain", "Faisceau synergise avec goldgain")
	print("  PASS  Synergies canoniques 1-a-1 conformes a l'etat de l'art")
	
	# Test condition helper without passive
	g._passives.clear()
	assert(not g._evo_cond_met("autocannon", g.EVO_RULES["autocannon"]), "Non eligible sans le passif")
	
	# Test condition helper with passive
	g._passives["he_fuel"] = 1
	assert(g._evo_cond_met("autocannon", g.EVO_RULES["autocannon"]), "Eligible des que le passif est possede")
	print("  PASS  Eligibilite declenchee des obtention du passif en partie")

	g.free()
	print("=== EVO SMOKE PASS (0 echec(s)) ===")
	get_tree().quit(0)
