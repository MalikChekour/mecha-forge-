extends Node2D
class_name TechMaze
## Labyrinthe Léger Modulaire pour le Niveau 1 (Secteur Tech / L'Usine).
## Entièrement modélisé et rendu sous Blender 5.0 avec Cycles CPU,
## recouvert des textures PBR "papier peint" sci-fi (blindage d'usine, rayures de sécurité,
## conduits plasma cyan et terminaux de contrôle).

var game: Node = null
var walls_container: Node2D = null

# Chemins des textures rendues sous Blender
const PATH_WALL_H_BASE     = "res://assets/decor/tech_maze/wall_horiz_base.png"
const PATH_WALL_H_HAZARD   = "res://assets/decor/tech_maze/wall_horiz_hazard.png"
const PATH_WALL_H_CONDUIT  = "res://assets/decor/tech_maze/wall_horiz_conduit.png"
const PATH_WALL_H_TERMINAL = "res://assets/decor/tech_maze/wall_horiz_terminal.png"

const PATH_WALL_V_BASE     = "res://assets/decor/tech_maze/wall_vert_base.png"
const PATH_WALL_V_HAZARD   = "res://assets/decor/tech_maze/wall_vert_hazard.png"
const PATH_WALL_V_CONDUIT  = "res://assets/decor/tech_maze/wall_vert_conduit.png"

const PATH_CORNER_TL       = "res://assets/decor/tech_maze/corner_tl.png"
const PATH_CORNER_TR       = "res://assets/decor/tech_maze/corner_tr.png"
const PATH_CORNER_BL       = "res://assets/decor/tech_maze/corner_bl.png"
const PATH_CORNER_BR       = "res://assets/decor/tech_maze/corner_br.png"

const PATH_PILLAR_REACTOR  = "res://assets/decor/tech_maze/pillar_reactor_core.png"
const PATH_PILLAR_VENT     = "res://assets/decor/tech_maze/pillar_vent_tower.png"
const PATH_BARRIER_LOW     = "res://assets/decor/tech_maze/barrier_low_tech.png"

var maze_colliders: Array[Node2D] = []

func _ready() -> void:
	walls_container = Node2D.new()
	walls_container.name = "WallsContainer"
	add_child(walls_container)
	build_maze()

func build_maze() -> void:
	for child in walls_container.get_children():
		child.queue_free()
	maze_colliders.clear()

	# 1. ENCEINTE EXTÉRIEURE DU COMPLEXE INDUSTRIEL (±1550 px)
	_build_perimeter(1550.0)

	# 2. SALLE CENTRALE D'ASSEMBLAGE (Spawn joueur à 0, 0 avec arène dégagée)
	_build_central_hub()

	# 3. LES 4 GRANDS AXES / AVENUES DE CIRCULATION (Larges couloirs 320 px)
	_build_avenues()

	# 4. LES 4 ARÈNES LATÉRALES THÉMATIQUES (Salles de combat spécialisées)
	_build_chamber_ne(Vector2(950, -950))  # Réacteurs & Énergie
	_build_chamber_nw(Vector2(-950, -950)) # Ventilation & Refroidissement
	_build_chamber_se(Vector2(950, 950))   # Terminal de Contrôle
	_build_chamber_sw(Vector2(-950, 950))  # Dépôt d'Assemblage & Blindage

	# Enregistrement dans game.cover_list pour que les hordes contournent les murs
	if game != null and "cover_list" in game:
		for col in maze_colliders:
			if is_instance_valid(col):
				game.cover_list.append(col.global_position)

## Construction du mur d'enceinte à ±half
func _build_perimeter(half: float) -> void:
	var step: float = 240.0
	var count: int = int((half * 2.0) / step)

	for i in range(count):
		var x: float = -half + float(i) * step + step * 0.5
		if absf(x) < half - 90.0:
			_place_wall_h(Vector2(x, -half), "hazard" if (i % 3 == 0) else "base")
			_place_wall_h(Vector2(x, half), "hazard" if (i % 3 == 0) else "base")

	for i in range(count):
		var y: float = -half + float(i) * step + step * 0.5
		if absf(y) < half - 90.0:
			_place_wall_v(Vector2(-half, y), "conduit" if (i % 3 == 1) else "base")
			_place_wall_v(Vector2(half, y), "conduit" if (i % 3 == 1) else "base")

	_place_corner(Vector2(-half, -half), "tl")
	_place_corner(Vector2(half, -half), "tr")
	_place_corner(Vector2(-half, half), "bl")
	_place_corner(Vector2(half, half), "br")

## Hub central avec piliers tactiques et 4 larges sorties
func _build_central_hub() -> void:
	# 4 Piliers tactiques (couvert défensif contre tirs de tourelles/ennemis distants)
	_place_pillar(Vector2(-240, -240), "reactor")
	_place_pillar(Vector2(240, -240), "vent")
	_place_pillar(Vector2(-240, 240), "vent")
	_place_pillar(Vector2(240, 240), "reactor")

	# Parois de la salle centrale laissant 4 larges ouvertures de 320 px
	_place_wall_h(Vector2(-270, -380), "conduit")
	_place_wall_v(Vector2(-380, -270), "conduit")

	_place_wall_h(Vector2(270, -380), "terminal")
	_place_wall_v(Vector2(380, -270), "terminal")

	_place_wall_h(Vector2(-270, 380), "hazard")
	_place_wall_v(Vector2(-380, 270), "hazard")

	_place_wall_h(Vector2(270, 380), "base")
	_place_wall_v(Vector2(380, 270), "base")

## Avenues reliant les secteurs (couloirs fluides de 320 px de large)
func _build_avenues() -> void:
	# Avenue Nord (x entre -160 et 160)
	for y in [-620.0, -860.0, -1100.0, -1340.0]:
		_place_wall_v(Vector2(-170, y), "base" if int(absf(y)) % 2 == 0 else "conduit")
		_place_wall_v(Vector2(170, y), "hazard" if int(absf(y)) % 2 == 0 else "base")

	# Avenue Sud (x entre -160 et 160)
	for y in [620.0, 860.0, 1100.0, 1340.0]:
		_place_wall_v(Vector2(-170, y), "hazard" if int(absf(y)) % 2 == 0 else "base")
		_place_wall_v(Vector2(170, y), "conduit" if int(absf(y)) % 2 == 0 else "base")

	# Avenue Ouest (y entre -160 et 160)
	for x in [-620.0, -860.0, -1100.0, -1340.0]:
		_place_wall_h(Vector2(x, -170), "conduit" if int(absf(x)) % 2 == 0 else "base")
		_place_wall_h(Vector2(x, 170), "hazard" if int(absf(x)) % 2 == 0 else "terminal")

	# Avenue Est (y entre -160 et 160)
	for x in [620.0, 860.0, 1100.0, 1340.0]:
		_place_wall_h(Vector2(x, -170), "terminal" if int(absf(x)) % 2 == 0 else "base")
		_place_wall_h(Vector2(x, 170), "base" if int(absf(x)) % 2 == 0 else "hazard")

## Arène Nord-Est : "Réacteur Principal & Énergie"
func _build_chamber_ne(center: Vector2) -> void:
	_place_pillar(center + Vector2(-120, 0), "reactor")
	_place_pillar(center + Vector2(120, 0), "reactor")

	_place_wall_h(center + Vector2(-160, -320), "conduit")
	_place_wall_h(center + Vector2(160, -320), "conduit")
	_place_wall_v(center + Vector2(320, -160), "conduit")
	_place_wall_v(center + Vector2(320, 160), "hazard")
	_place_corner(center + Vector2(320, -320), "tr")

	_place_barrier(center + Vector2(0, 220))

## Arène Nord-Ouest : "Ventilation & Refroidissement"
func _build_chamber_nw(center: Vector2) -> void:
	_place_pillar(center + Vector2(0, -120), "vent")
	_place_pillar(center + Vector2(0, 120), "vent")

	_place_wall_h(center + Vector2(-160, -320), "hazard")
	_place_wall_h(center + Vector2(160, -320), "hazard")
	_place_wall_v(center + Vector2(-320, -160), "hazard")
	_place_wall_v(center + Vector2(-320, 160), "base")
	_place_corner(center + Vector2(-320, -320), "tl")

	_place_barrier(center + Vector2(180, 0))

## Arène Sud-Est : "Poste de Contrôle & Télémesure"
func _build_chamber_se(center: Vector2) -> void:
	_place_pillar(center + Vector2(-120, -100), "vent")
	_place_pillar(center + Vector2(120, 100), "reactor")

	_place_wall_h(center + Vector2(-160, 320), "terminal")
	_place_wall_h(center + Vector2(160, 320), "terminal")
	_place_wall_v(center + Vector2(320, -160), "terminal")
	_place_wall_v(center + Vector2(320, 160), "base")
	_place_corner(center + Vector2(320, 320), "br")

	_place_barrier(center + Vector2(0, -180))

## Arène Sud-Ouest : "Dépôt d'Assemblage & Blindage"
func _build_chamber_sw(center: Vector2) -> void:
	_place_pillar(center + Vector2(-100, 0), "reactor")
	_place_pillar(center + Vector2(100, 0), "vent")

	_place_wall_h(center + Vector2(-160, 320), "hazard")
	_place_wall_h(center + Vector2(160, 320), "hazard")
	_place_wall_v(center + Vector2(-320, -160), "base")
	_place_wall_v(center + Vector2(-320, 160), "hazard")
	_place_corner(center + Vector2(-320, 320), "bl")

	_place_barrier(center + Vector2(0, -180))


# ----------------- HELPERS D'INSTANCIATION PHYSIQUE -----------------

func _place_wall_h(pos: Vector2, kind: String = "base") -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 8   # Layer 8 = Cover / Murs (bloque le joueur et les projectiles)
	body.collision_mask = 0
	body.add_to_group("cover")

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(240.0, 56.0)
	shape.shape = rect
	body.add_child(shape)

	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.position = Vector2(0, 28.0)
	shadow.scale = Vector2(3.8, 0.7)
	shadow.z_index = -2
	body.add_child(shadow)

	var sprite: Sprite2D = Sprite2D.new()
	var path: String = PATH_WALL_H_BASE
	match kind:
		"hazard":   path = PATH_WALL_H_HAZARD
		"conduit":  path = PATH_WALL_H_CONDUIT
		"terminal": path = PATH_WALL_H_TERMINAL
	sprite.texture = Tex.get_tex(path)
	sprite.z_index = clampi(int(pos.y), -4000, 4000)
	body.add_child(sprite)

	walls_container.add_child(body)
	maze_colliders.append(body)

func _place_wall_v(pos: Vector2, kind: String = "base") -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 8
	body.collision_mask = 0
	body.add_to_group("cover")

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(56.0, 240.0)
	shape.shape = rect
	body.add_child(shape)

	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.position = Vector2(0, 110.0)
	shadow.scale = Vector2(1.2, 3.6)
	shadow.z_index = -2
	body.add_child(shadow)

	var sprite: Sprite2D = Sprite2D.new()
	var path: String = PATH_WALL_V_BASE
	match kind:
		"hazard":  path = PATH_WALL_V_HAZARD
		"conduit": path = PATH_WALL_V_CONDUIT
	sprite.texture = Tex.get_tex(path)
	sprite.z_index = clampi(int(pos.y + 110.0), -4000, 4000)
	body.add_child(sprite)

	walls_container.add_child(body)
	maze_colliders.append(body)

func _place_corner(pos: Vector2, quad: String) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 8
	body.collision_mask = 0
	body.add_to_group("cover")

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(80.0, 80.0)
	shape.shape = rect
	body.add_child(shape)

	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.position = Vector2(0, 35.0)
	shadow.scale = Vector2(1.5, 1.2)
	shadow.z_index = -2
	body.add_child(shadow)

	var sprite: Sprite2D = Sprite2D.new()
	var path: String = PATH_CORNER_TL
	match quad:
		"tr": path = PATH_CORNER_TR
		"bl": path = PATH_CORNER_BL
		"br": path = PATH_CORNER_BR
	sprite.texture = Tex.get_tex(path)
	sprite.z_index = clampi(int(pos.y + 35.0), -4000, 4000)
	body.add_child(sprite)

	walls_container.add_child(body)
	maze_colliders.append(body)

func _place_pillar(pos: Vector2, kind: String = "reactor") -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 8
	body.collision_mask = 0
	body.add_to_group("cover")

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 42.0
	shape.shape = circle
	body.add_child(shape)

	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.5)
	shadow.position = Vector2(0, 30.0)
	shadow.scale = Vector2(1.8, 1.3)
	shadow.z_index = -2
	body.add_child(shadow)

	var sprite: Sprite2D = Sprite2D.new()
	var path: String = PATH_PILLAR_VENT if kind == "vent" else PATH_PILLAR_REACTOR
	sprite.texture = Tex.get_tex(path)
	sprite.z_index = clampi(int(pos.y + 30.0), -4000, 4000)
	body.add_child(sprite)

	walls_container.add_child(body)
	maze_colliders.append(body)

func _place_barrier(pos: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 8
	body.collision_mask = 0
	body.add_to_group("cover")

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(140.0, 36.0)
	shape.shape = rect
	body.add_child(shape)

	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.4)
	shadow.position = Vector2(0, 18.0)
	shadow.scale = Vector2(2.4, 0.6)
	shadow.z_index = -2
	body.add_child(shadow)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = Tex.get_tex(PATH_BARRIER_LOW)
	sprite.z_index = clampi(int(pos.y + 18.0), -4000, 4000)
	body.add_child(sprite)

	walls_container.add_child(body)
	maze_colliders.append(body)
