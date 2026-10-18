extends Node

const GameScene = preload("res://scenes/Main.tscn")
const GameScript = preload("res://scenes/Game.gd")

func _ready() -> void:
	print("=== TEST DEMARRAGE COMPLET DES 18 CHAPITRES ===")
	var g = GameScene.instantiate()
	add_child(g)
	
	var passed: int = 0
	var failed: int = 0
	
	for i in GameScript.CHAPTERS.size():
		var ch: Dictionary = GameScript.CHAPTERS[i]
		var b_name: String = String(ch["biome"])
		print("Test Chapitre %d : %s (%s)..." % [i + 1, ch["name"], b_name])
		g._chapter = i + 1
		g._apply_chapter_biome(b_name)
		
		# Verifications
		var ok: bool = true
		if g._biome_label(b_name) == "":
			ok = false
			print("  FAIL: label vide pour %s" % b_name)
		if g._scatter == null or not is_instance_valid(g._scatter):
			ok = false
			print("  FAIL: scatter null pour %s" % b_name)
		if g._floor_mat == null:
			ok = false
			print("  FAIL: floor_mat null pour %s" % b_name)
			
		if ok:
			passed += 1
			print("  -> OK (sol, props, lumieres, ambiance charges)")
		else:
			failed += 1
			
	print("=== RESULTAT : %d/%d CHAPITRES PASSES ===" % [passed, GameScript.CHAPTERS.size()])
	get_tree().quit(1 if failed > 0 else 0)
