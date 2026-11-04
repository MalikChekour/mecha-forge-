extends Node
## CAPTURE ZONE PUBG (05/11) : partie bot Ch1 Normal RENDUE (lancer SANS --headless).
##   godot --path game res://_shot_pubg.tscn -- --no-protocols --autoplay
const GameScene = preload("res://scenes/Main.tscn")
var g: Node
var _t: float = 0.0
var _step: int = 0
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
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../qa_pubg")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name))
	print("SHOT ", dir.path_join(name))
func _process(delta: float) -> void:
	if g == null or g.player == null or g.arena_wall == null:
		return
	_t += delta
	var aw = g.arena_wall
	match _step:
		0:
			if _t > 12.0:
				GameState.run_time = 520.0   # phase 4 annoncee : cercle actuel 700, prochain 560 en blanc
				_step = 1
		1:
			if _t > 12.5:
				var dir: Vector2 = (aw.next_center - aw.center).normalized() if aw.next_center != aw.center else Vector2.RIGHT
				g.player.global_position = aw.center - dir * (aw.radius - 330.0)
				_step = 2
		2:
			if _t > 15.0:
				_shot("zone_pubg_dedans.png")
				var dir2: Vector2 = (g.player.global_position - aw.center).normalized()
				g.player.global_position = aw.center + dir2 * (aw.radius + 480.0)
				_step = 3
		3:
			if _t > 15.6:
				_shot("zone_pubg_hors_zone.png")
				get_tree().quit(0)
