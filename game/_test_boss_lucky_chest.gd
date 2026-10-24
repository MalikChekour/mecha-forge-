extends Node

func _ready() -> void:
	print("=== TEST BOSS LUCKY CHEST ===")
	var game_script = load("res://scenes/Game.gd")
	var g: Node2D = Node2D.new()
	g.set_script(game_script)
	
	# Verify spawn_boss_chest exists
	assert(g.has_method("spawn_boss_chest"), "spawn_boss_chest doit exister")
	assert(g.has_method("open_lucky_chest"), "open_lucky_chest doit exister")
	assert(g.has_method("claim_lucky_chest"), "claim_lucky_chest doit exister")
	print("  PASS  Methodes de coffre de boss detectees")
	
	# Test claiming a reward
	var initial_scrap: int = GameState.scrap
	var test_reward = [{"id": "dmg", "name": "+25% Degats"}]
	g.claim_lucky_chest(test_reward, 150)
	assert(GameState.scrap == initial_scrap + 150, "La ferraille bonus doit etre creditee")
	assert(g._passives.get("dmg", 0) >= 1, "Le bonus du coffre doit etre applique")
	print("  PASS  claim_lucky_chest applique les bonus et credite la ferraille")

	g.free()
	print("=== BOSS CHEST SMOKE PASS (0 echec(s)) ===")
	get_tree().quit(0)
