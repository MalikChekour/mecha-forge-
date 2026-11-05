extends Node
## CAPTURES VAGUES (05/11 v12.20) : debut (fantassins seuls), montee pre-boss (bandeau SIGNAL HOSTILE DETECTE), fin (melange blinde).
##   godot --path game res://_shot_waves.tscn -- --no-protocols --autoplay
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
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../qa_waves")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name))
	var kinds: Dictionary = {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).alive:
			kinds[(e as Enemy).kind] = int(kinds.get((e as Enemy).kind, 0)) + 1
	print("SHOT ", dir.path_join(name), " t=", GameState.run_time, " ennemis=", kinds)
func _process(delta: float) -> void:
	if g == null or g.player == null:
		return
	_t += delta
	g.player.hp = g.player.max_hp   # capture : le bot ne doit pas mourir pendant les sauts de temps
	match _step:
		0:
			if _t > 28.0:
				_shot("1_debut_fantassins_seuls.png")
				GameState.run_time = 196.0
				_mark = _t
				_step = 1
		1:
			if GameState.run_time >= 211.0:
				_shot("2_signal_hostile_pre_boss.png")
				_mark = _t
				_step = 2
		2:
			if _t > _mark + 6.0:
				_shot("2b_montee_pre_boss.png")
				GameState.run_time = 700.0
				_mark = _t
				_step = 3
		3:
			if _t > _mark + 14.0:
				_shot("3_fin_melange_blinde.png")
				get_tree().quit(0)
