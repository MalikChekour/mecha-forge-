extends Node
## CAPTURES GRANDE CARTE (05/11 v12.19) : debut (aucun cercle, minicarte), balise de POI, milieu (cercle visible), fin.
##   godot --path game res://_shot_bigmap.tscn -- --no-protocols --autoplay
const GameScene = preload("res://scenes/Main.tscn")
var g: Node
var _t: float = 0.0
var _step: int = 0
var _mark: float = 0.0
func _ready() -> void:
	GameState.difficulty = 1
	g = GameScene.instantiate()
	add_child(g)
	GameState.difficulty = 1
	g._chapter = 1
	g._apply_chapter_biome("tech")
	DisplayServer.window_set_size(Vector2i(1280, 720))
func _shot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../qa_bigmap")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name))
	print("SHOT ", dir.path_join(name), " t=", GameState.run_time)
func _process(delta: float) -> void:
	if g == null or g.player == null or g.arena_wall == null:
		return
	_t += delta
	var aw = g.arena_wall
	match _step:
		0:
			if _t > 9.0:
				_shot("1_debut_sans_cercle.png")
				for q in aw.pois:
					if q["type"] == "cache" and int(q["state"]) == 0:
						g.player.global_position = (q["pos"] as Vector2) + Vector2(0, 420)
						break
				_mark = _t
				_step = 1
		1:
			if _t > _mark + 1.2:
				_shot("2_poi_cache.png")
				GameState.run_time = 300.0
				_mark = _t
				_step = 2
		2:
			if _t > _mark + 0.3:
				var d: Vector2 = (g.player.global_position - aw.center)
				d = d.normalized() if d.length() > 1.0 else Vector2.RIGHT
				g.player.global_position = aw.center + d * (aw.radius - 170.0)
				_mark = _t
				_step = 3
		3:
			if _t > _mark + 1.2:
				_shot("3_milieu_cercle.png")
				GameState.run_time = 855.0
				_mark = _t
				_step = 4
		4:
			if _t > _mark + 0.3:
				g.player.global_position = aw.center + Vector2(0, aw.radius * 0.4)
				_mark = _t
				_step = 5
		5:
			if _t > _mark + 1.2:
				_shot("4_fin_petit_cercle.png")
				get_tree().quit(0)
