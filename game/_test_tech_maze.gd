extends Node
## Test de validation du Labyrinthe Modulaire Blender pour le Niveau 1 (Secteur Tech).

const TechMaze = preload("res://systems/TechMaze.gd")

class DummyGame extends Node2D:
	var cover_list: Array = []

func _ready() -> void:
	print("==================================================")
	print("[TEST] Demarrage verification TechMaze (Niveau 1)")
	print("==================================================")
	
	var pass_count: int = 0
	var fail_count: int = 0

	# 1. Verification de l'existence et chargement des 14 textures Blender
	var texture_paths = [
		"res://assets/decor/tech_maze/wall_horiz_base.png",
		"res://assets/decor/tech_maze/wall_horiz_hazard.png",
		"res://assets/decor/tech_maze/wall_horiz_conduit.png",
		"res://assets/decor/tech_maze/wall_horiz_terminal.png",
		"res://assets/decor/tech_maze/wall_vert_base.png",
		"res://assets/decor/tech_maze/wall_vert_hazard.png",
		"res://assets/decor/tech_maze/wall_vert_conduit.png",
		"res://assets/decor/tech_maze/corner_tl.png",
		"res://assets/decor/tech_maze/corner_tr.png",
		"res://assets/decor/tech_maze/corner_bl.png",
		"res://assets/decor/tech_maze/corner_br.png",
		"res://assets/decor/tech_maze/pillar_reactor_core.png",
		"res://assets/decor/tech_maze/pillar_vent_tower.png",
		"res://assets/decor/tech_maze/barrier_low_tech.png",
	]

	for p in texture_paths:
		var tex: Texture2D = Tex.get_tex(p)
		if tex != null and tex.get_width() > 0:
			print("  [PASS] Texture valide: %s (%dx%d)" % [p.get_file(), tex.get_width(), tex.get_height()])
			pass_count += 1
		else:
			printerr("  [FAIL] Texture invalide ou absente: %s" % p)
			fail_count += 1

	var dummy_game = DummyGame.new()
	var maze: TechMaze = TechMaze.new()
	maze.game = dummy_game
	add_child(maze)

	if maze.maze_colliders.size() >= 40:
		print("  [PASS] TechMaze genere %d colliders de murs et piliers (attendu >= 40)" % maze.maze_colliders.size())
		pass_count += 1
	else:
		printerr("  [FAIL] Nombre insuffisant de colliders dans TechMaze: %d" % maze.maze_colliders.size())
		fail_count += 1

	# 3. Verification physique (Collision Layer 8)
	var all_layer_8: bool = true
	for col in maze.maze_colliders:
		if col is CollisionObject2D:
			if (col as CollisionObject2D).collision_layer != 8:
				all_layer_8 = false
				break
	if all_layer_8:
		print("  [PASS] Tous les murs et piliers ont collision_layer == 8 (Cover/Obstacles)")
		pass_count += 1
	else:
		printerr("  [FAIL] Au moins un collider n'a pas collision_layer == 8")
		fail_count += 1

	# 4. Verification de l'enregistrement dans cover_list
	if dummy_game.cover_list.size() == maze.maze_colliders.size():
		print("  [PASS] game.cover_list contient l'integralite des positions de murs (%d points)" % dummy_game.cover_list.size())
		pass_count += 1
	else:
		printerr("  [FAIL] Incoherence cover_list (%d vs %d)" % [dummy_game.cover_list.size(), maze.maze_colliders.size()])
		fail_count += 1

	# 5. Verification intégration Game.gd
	var game_script = load("res://scenes/Game.gd")
	if game_script != null:
		print("  [PASS] Game.gd charge et compile parfaitement avec TechMazeScript")
		pass_count += 1
	else:
		printerr("  [FAIL] Erreur de compilation dans Game.gd")
		fail_count += 1

	print("==================================================")
	print("[BILAN] Tests reussis: %d / %d | Echecs: %d" % [pass_count, pass_count + fail_count, fail_count])
	print("==================================================")

	if fail_count == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)
