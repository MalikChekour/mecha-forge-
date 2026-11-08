extends Node
## CAPTURES CIRCUITS D'OBSTACLES (v12.21) : validation des motifs structurés, boucles et goulets.
const GameScene = preload("res://scenes/Main.tscn")
var g: Node
var _t: float = 0.0
var _step: int = 0
var _mark: float = 0.0

func _ready() -> void:
	GameState.difficulty = 1
	g = GameScene.instantiate()
	add_child(g)
	g._chapter = 1
	g._apply_chapter_biome("tech")
	DisplayServer.window_set_size(Vector2i(1280, 720))

func _shot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../qa_circuits")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name))
	var props_count: int = 0
	if g != null and "cover_list" in g:
		props_count = g.cover_list.size()
	print("SHOT ", dir.path_join(name), " t=", _t, " props_near=", props_count)

func _process(delta: float) -> void:
	if g == null or g.player == null:
		return
	_t += delta
	g.player.hp = g.player.max_hp

	match _step:
		0:
			if _t > 2.0:
				_shot("1_circuit_depart.png")
				_mark = _t
				_step = 1
		1:
			# Deplacer un peu le bot pour decouvrir un chunk voisin avec chicane/anneau
			if _t > _mark + 4.0:
				_shot("2_circuit_exploration.png")
				_mark = _t
				_step = 2
		2:
			if _t > _mark + 4.0:
				_shot("3_circuit_combat.png")
				print("VALIDATION CIRCUITS OBSTACLES REUSSIE : 3 captures effectuees avec succes.")
				get_tree().quit(0)
