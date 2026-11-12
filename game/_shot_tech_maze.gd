extends Node
## Capture visuelle des installations industrielles réorganisées du Niveau 1.

const GameScene = preload("res://scenes/Main.tscn")
var g: Node
var _t: float = 0.0
var _step: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.skip_hub = true
	GameState.difficulty = 1
	g = GameScene.instantiate()
	g._bot = true
	g._chapter = 1
	add_child(g)
	if g.player != null:
		g.player.bot_active = true
	g._apply_chapter_biome("tech")
	DisplayServer.window_set_size(Vector2i(1280, 720))

func _shot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../qa_tech_maze")
	DirAccess.make_dir_recursive_absolute(dir)
	var full_p: String = dir.path_join(name)
	img.save_png(full_p)
	# Sauvegarde également dans le dossier des artefacts
	var art_dir: String = "C:/Users/Administrator/.gemini/antigravity-ide/brain/57e87bbd-6285-4159-a061-1b83a072c5b4"
	var art_p: String = art_dir.path_join(name)
	img.save_png(art_p)
	print("[SHOT] Enregistre: ", full_p, " et ", art_p)

func _process(delta: float) -> void:
	if g == null or g.player == null:
		return
	_t += delta

	match _step:
		0:
			# Approche de l'avenue Est du Hub Central (angle Nord-Est (320, -340) couvrant la route vers le Sud 90°)
			g.player.global_position = Vector2(280, -160)
			if _t > 2.5:
				_shot("01_hub_central_organise.png")
				_step = 1
				_t = 0.0
		1:
			# Approche de la route Sud du Hub Central (angle Sud-Est (320, 340) couvrant la route vers l'Ouest 180°)
			g.player.global_position = Vector2(180, 320)
			if _t > 2.5:
				_shot("02_complexe_industriel_est.png")
				_step = 2
				_t = 0.0
		2:
			# Autoroute Pipeline Secteur Est (chunk (1, 0), angle Nord-Est (1500, -260) couvrant l'autoroute vers l'Ouest 180°)
			g.player.global_position = Vector2(1420, -140)
			if _t > 2.5:
				_shot("03_hangar_logistique_sud.png")
				print("[CAPTURE FINIE] Toutes les captures de barrage d'angles sont effectuees avec succes.")
				get_tree().quit(0)
