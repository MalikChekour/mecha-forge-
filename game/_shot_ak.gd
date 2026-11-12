extends Node
## CAPTURE ANTI-FUITE (31/10) : partie bot Ch1 Normal RENDUE (lancer SANS --headless), puis captures PNG du champ de
## confinement (normal, puis resserre a 5:00) avec des chasseurs en approche.
##   godot --path game res://_shot_ak.tscn -- --no-protocols --autoplay
const GameScene = preload("res://scenes/Main.tscn")
const GameScript = preload("res://scenes/Game.gd")
var g: Node
var _t: float = 0.0
var _step: int = 0
var out_dir: String = "res://../qa_antikite/"
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
	var p: String = ProjectSettings.globalize_path("res://").path_join("../qa_antikite/" + name)
	img.save_png(p)
	print("SHOT ", p)
func _process(delta: float) -> void:
	if g == null or g.player == null:
		return
	_t += delta
	var sp = g.spawner
	var aw = g.arena_wall
	match _step:
		0:
			if _t > 14.0:
				# pousse le mecha pres du bord pour montrer le mur, + 3 chasseurs devant
				g.player.global_position = aw.center + Vector2(aw.radius - 150.0, -60.0)
				for i in 3:
					sp.spawn_chasseur(g.player.global_position + Vector2.from_angle(-0.6 + 0.6 * float(i)) * 420.0)
				_step = 1
		1:
			if _t > 16.5:
				_shot("ak_mur_chasseurs.png")
				GameState.run_time = 301.0   # saute a l'encerclement de 5:00 -> le champ se resserre
				_step = 2
		2:
			if _t > 22.5:
				for i in 3:
					sp.spawn_chasseur(g.player.global_position + Vector2.from_angle(PI + 0.5 * float(i)) * 380.0)
				_step = 3
		3:
			if _t > 24.0:
				_shot("ak_mur_resserre.png")
				_step = 4
		4:
			if _t > 25.5:
				_shot("ak_mur_resserre2.png")
				get_tree().quit(0)
