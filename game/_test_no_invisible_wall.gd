extends Node
## MUR INVISIBLE (05/10) : en map infinie (Game.BOUNDED = false), le joueur etait bloque a
## +-2810 par un clamp applique sans condition dans _apply_biome_floor(). Verifie qu'apres
## chargement d'un biome, rien ne borne le joueur ni la camera.
##   godot --headless --path game res://_test_no_invisible_wall.tscn

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST PAS DE MUR INVISIBLE (map infinie) ===")
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	for i in 5:
		await get_tree().physics_frame
	_ok(game.BOUNDED == false, "map en mode infini (BOUNDED = false)")
	for biome in ["tech", "cryo", "citadelle"]:
		game._apply_biome_floor(biome)
		var p: Node2D = game.player
		_ok(p.arena.size.x > 100000.0, "%s : joueur non borne" % biome, "arena=%s" % str(p.arena))
		_ok(game.cam.limit_right > 100000, "%s : camera non bornee" % biome, "limit_right=%d" % game.cam.limit_right)
		for target in [Vector2(6000, 0), Vector2(-6000, 0), Vector2(0, 6000), Vector2(0, -6000), Vector2(9000, 9000)]:
			p.global_position = target
			for i in 3:
				await get_tree().physics_frame
			# tolere un petit deplacement (collision decor / IA du bot), pas un rappel a 2810
			_ok(p.global_position.distance_to(target) < 600.0, "%s : le mecha reste a %s" % [biome, str(target)],
				"obtenu=%s" % str(p.global_position))
	print("=== %s ===" % ("PASS" if _fail == 0 else "%d echec(s)" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)
