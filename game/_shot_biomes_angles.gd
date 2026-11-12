extends Node
## Capture visuelle des topologies exclusives et des canons d'angle pour les 4 biomes de l'Étape 1.

const GameScene = preload("res://scenes/Main.tscn")
const PropScatter = preload("res://actors/PropScatter.gd")

var g: Node
var _t: float = 0.0
var _step: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.skip_hub = true
	GameState.difficulty = 1
	SaveManager.data["seen_intro"] = true
	var seen: Dictionary = {}
	for k in PropScatter.DECOR:
		seen[k] = true
	SaveManager.data["seen_props"] = seen

	g = GameScene.instantiate()
	g._bot = true
	g._cut_seen["in_earth"] = true
	g._cut_seen["in_desert"] = true
	g._cut_seen["in_jungle"] = true
	g._cut_seen["in_volcanic"] = true
	g._cut_seen["in_swamp"] = true
	g._cut_seen["in_tech"] = true
	g._chapter = 2
	add_child(g)
	if g.player != null:
		g.player.bot_active = true
	DisplayServer.window_set_size(Vector2i(1280, 720))

	# Éliminer tout panneau ou cutscene résiduel
	for child in g.get_children():
		if child.name.contains("Cutscene") or child.name.contains("Pancarte") or child is CanvasLayer:
			child.queue_free()

	_load_step(0)

func _load_step(st: int) -> void:
	_t = 0.0
	match st:
		0:
			# NIVEAU 2 : DÉSERT TOXIQUE (canyons diagonaux, arches de verre fondu, miroir solaire d'angle)
			g._chapter = 2
			g._apply_chapter_biome("desert")
			if g.player != null:
				g.player.global_position = Vector2(720.0, 340.0)
		1:
			# NIVEAU 3 : RUINES VÉGÉTALES (clairières circulaires, colonnes de racines, plante-mortier d'angle)
			g._chapter = 3
			g._apply_chapter_biome("jungle")
			if g.player != null:
				g.player.global_position = Vector2(720.0, 720.0)
		2:
			# NIVEAU 4 : FORGE ET CONSTRUCTION (halles industrielles, ponts roulants, mortier de scories d'angle)
			g._chapter = 4
			g._apply_chapter_biome("volcanic")
			if g.player != null:
				g.player.global_position = Vector2(280.0, 740.0)
		3:
			# NIVEAU 5 : CITÉ ENGLOUTIE (damier urbain inondé, gratte-ciel, barricades, tourelle DCA d'angle)
			g._chapter = 5
			g._apply_chapter_biome("swamp")
			if g.player != null:
				g.player.global_position = Vector2(720.0, 320.0)

	# Nettoyage de toute pancarte
	if "_pancarte_panel" in g and g._pancarte_panel != null:
		g._pancarte_panel.visible = false

func _shot(name: String) -> void:
	# Purge de tout élément d'interface qui masquerait le décor
	for child in g.get_children():
		if child.name.contains("Cutscene"):
			child.queue_free()
	if "_pancarte_panel" in g and g._pancarte_panel != null:
		g._pancarte_panel.visible = false
	var img: Image = get_viewport().get_texture().get_image()
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../qa_biomes_angles")
	DirAccess.make_dir_recursive_absolute(dir)
	var full_p: String = dir.path_join(name)
	img.save_png(full_p)
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
			if _t > 2.2:
				_shot("01_desert_canyon_miroir_angle.png")
				_step = 1
				_load_step(1)
		1:
			if _t > 2.2:
				_shot("02_jungle_clairiere_mortier_angle.png")
				_step = 2
				_load_step(2)
		2:
			if _t > 2.2:
				_shot("03_volcanic_fonderie_scories_angle.png")
				_step = 3
				_load_step(3)
		3:
			if _t > 2.2:
				_shot("04_swamp_carrefour_flak_dca_angle.png")
				print("[CAPTURE FINIE] Captures des 4 biomes et canons d'angles effectuees avec succes.")
				get_tree().quit(0)
