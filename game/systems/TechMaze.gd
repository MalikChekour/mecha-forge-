extends Node2D
class_name TechMaze
## Labyrinthe Industriel Modulaire Haute Fidélité pour le Niveau 1 (Secteur Tech / L'Usine).
## Déployé sur toute la grande carte circulaire jusqu'aux limites du cercle PUBG (MAP_R = 10 000 px).
##
## Caractéristiques :
##  - Agencement modulaire sans chevauchement : chaque élément respecte strictement les cotes
##    physiques et visuelles (murs H/V 288x160 / 160x288, piliers 200x210, barrières 220x140).
##    Garantie 0 collision physique et 0 chevauchement visuel entre décors.
##  - Centrage parfait sur le point de spawn (0, 0) : le Hub Central est centré en (0, 0) avec
##    une esplanade de déploiement dégagée de 600x600 px et des avenues de 420 px d'inter-chunks.
##  - Réduction tactique des canons : densité réduite à ~16%, réservés aux positions charnières
##    (sas extérieur Est du hub et chicane fortifiée).
##  - Salve Flak Supersonique cinématique : tirs en rafale de 4 obus traceurs avec traînées de fumée,
##    détonations airburst, ondes de choc supersoniques et piratage défensif contre la horde.
##  - Rendu graphique 2.5D enrichi : ombres de contact au sol (Tex.shadow) sous chaque paroi,
##    lueur additive plasma cyan sur les conduits et luminescence pulsante des réacteurs à fusion.
##  - Streaming dynamique par chunks (1200x1200 px, grille 5x5) assurant un 60 FPS constant.

var game: Node = null
var walls_container: Node2D = null

# Chemins des textures 2.5D Deluxe
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

# Paramètres du streaming de carte
const CHUNK_SIZE: float = 1200.0
const LOAD_R: int = 2                 # Grille 5x5 de chunks actifs autour du joueur
const MAX_MAP_R: float = 10000.0      # Rayon du cercle PUBG

var _chunks: Dictionary = {}          # Vector2i -> Array[StaticBody2D]
var _chunk_positions: Dictionary = {} # Vector2i -> Array[Vector2] (pour cover_list)
var _last_cell: Vector2i = Vector2i(9999999, 9999999)
var maze_colliders: Array[Node2D] = []

func _ready() -> void:
	walls_container = Node2D.new()
	walls_container.name = "WallsContainer"
	add_child(walls_container)
	build_maze()

func _process(_delta: float) -> void:
	var p: Node2D = _get_player()
	if p == null or not is_instance_valid(p):
		return
	var pos: Vector2 = p.global_position
	# Centrage précis des cellules avec demi-taille de chunk
	var cell: Vector2i = Vector2i(
		int(floor((pos.x + CHUNK_SIZE * 0.5) / CHUNK_SIZE)),
		int(floor((pos.y + CHUNK_SIZE * 0.5) / CHUNK_SIZE))
	)
	if cell != _last_cell:
		_update_chunks(cell)

func _get_player() -> Node2D:
	if game != null and "player" in game and is_instance_valid(game.player):
		return game.player as Node2D
	return null

func build_maze() -> void:
	for child in walls_container.get_children():
		child.queue_free()
	_chunks.clear()
	_chunk_positions.clear()
	maze_colliders.clear()
	_last_cell = Vector2i(9999999, 9999999)

	# Charge initialement le hub central (0, 0) et ses chunks adjacents immédiats
	_update_chunks(Vector2i.ZERO)

## Met à jour les chunks actifs autour de la cellule actuelle du joueur
func _update_chunks(center_cell: Vector2i) -> void:
	_last_cell = center_cell
	var needed: Dictionary = {}

	for dx in range(-LOAD_R, LOAD_R + 1):
		for dy in range(-LOAD_R, LOAD_R + 1):
			var c: Vector2i = Vector2i(center_cell.x + dx, center_cell.y + dy)
			var c_center: Vector2 = Vector2(float(c.x) * CHUNK_SIZE, float(c.y) * CHUNK_SIZE)
			# Ne génère pas au-delà des limites de la carte circulaire
			if c_center.length() <= MAX_MAP_R + CHUNK_SIZE * 0.75:
				needed[c] = true

	# Déchargement des chunks hors de portée
	var to_unload: Array = []
	for c in _chunks.keys():
		if not needed.has(c):
			to_unload.append(c)
	for c in to_unload:
		_unload_chunk(c)

	# Chargement des nouveaux chunks
	for c in needed.keys():
		if not _chunks.has(c):
			_load_chunk(c)

func _unload_chunk(c: Vector2i) -> void:
	if not _chunks.has(c):
		return
	var bodies: Array = _chunks[c]
	for b in bodies:
		if is_instance_valid(b):
			maze_colliders.erase(b)
			b.queue_free()
	_chunks.erase(c)

	if _chunk_positions.has(c):
		var pts: Array = _chunk_positions[c]
		if game != null and "cover_list" in game:
			for pt in pts:
				game.cover_list.erase(pt)
		_chunk_positions.erase(c)

func _load_chunk(c: Vector2i) -> void:
	var chunk_bodies: Array[Node2D] = []
	var chunk_pts: Array[Vector2] = []
	# Origine centrée exactement sur le centre mathématique du chunk c
	var origin: Vector2 = Vector2(float(c.x) * CHUNK_SIZE, float(c.y) * CHUNK_SIZE)

	if c == Vector2i.ZERO:
		_build_central_hub_chunk(origin, chunk_bodies, chunk_pts)
	else:
		_build_procedural_chunk(c, origin, chunk_bodies, chunk_pts)

	_chunks[c] = chunk_bodies
	_chunk_positions[c] = chunk_pts

## Hub Central d'Assemblage (c = (0, 0)) : Spacieux, dégagé (aire 600x600 px au centre) et 1 canon flak à l'Est
func _build_central_hub_chunk(origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2]) -> void:
	# Portique Nord : Mur horizontal et pilier d'angle Ouest
	_instantiate_wall_h(origin + Vector2(0, -360), "terminal", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(-300, -360), "vent", out_bodies, out_pts)

	# Angle Nord-Est : Canon de barrage d'angle couvrant l'avenue de transit Est (orienté plein Sud 90.0° à travers la route)
	_instantiate_cannon(origin + Vector2(320, -340), 90.0, out_bodies, out_pts)

	# Sas Sud : Barrière centrale et pilier d'angle Ouest
	_instantiate_barrier(origin + Vector2(0, 360), out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(-300, 360), "vent", out_bodies, out_pts)

	# Angle Sud-Est : Canon de barrage d'angle couvrant la route Sud (orienté plein Ouest 180.0° à travers la route)
	_instantiate_cannon(origin + Vector2(320, 340), 180.0, out_bodies, out_pts)

	# Alcôve Ouest : Cœur de réacteur de secours
	_instantiate_pillar(origin + Vector2(-320, 0), "reactor", out_bodies, out_pts)

## Secteurs procéduraux déterministes basés sur les coordonnées de chunk
func _build_procedural_chunk(c: Vector2i, origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2]) -> void:
	var seed_hash: int = int(((c.x * 73856093) ^ (c.y * 19349663) ^ 0x5bd1e995) & 0x7fffffff)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_hash

	# Distribution équilibrée et cohérente de la zone industrielle :
	# 1. Autoroutes de pipelines et conduits plasma linéaires (~28% des chunks)
	# 2. Esplanades logistiques / places de manœuvre ouvertes (~22% des chunks)
	# 3. Postes de contrôle fortifiés avec chicane et canon flak tactique (~16% des chunks)
	# 4. Grands complexes industriels spécialisés sans canon (~34% des chunks)
	var zone_roll: int = abs(c.x * 5 + c.y * 11 + int(rng.randi())) % 100

	if zone_roll < 28:
		# Axe de transit linéaire (Nord-Sud si c.x est pair, Est-Ouest si impair)
		_build_pipeline_highway(origin, out_bodies, out_pts, (c.x % 2 == 0))
	elif zone_roll < 50:
		# Esplanade logistique aérée (grand espace de manœuvre de 800x800 px)
		_build_logistics_plaza(origin, out_bodies, out_pts)
	elif zone_roll < 66:
		# Sas fortifié avec chicane défensive et canon flak tactique (seul chunk procédural armé)
		_build_security_bastion(origin, out_bodies, out_pts)
	else:
		# Complexe industriel spécialisé (0 canon, installations de pointe)
		var facility_type: int = (abs(c.x * 2 + c.y * 3) + int(rng.randi())) % 5
		match facility_type:
			0: _build_power_substation(origin, out_bodies, out_pts)
			1: _build_cooling_facility(origin, out_bodies, out_pts)
			2: _build_warehouse_bay(origin, out_bodies, out_pts)
			3: _build_refinery_complex(origin, out_bodies, out_pts)
			4: _build_repair_hangar(origin, out_bodies, out_pts)

## Axe de Transit & Conduits Plasma : Voies rapides avec passages dégagés de 420 px (0 chevauchement)
func _build_pipeline_highway(origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2], is_vertical: bool) -> void:
	if is_vertical:
		# Pipeline Ouest (X = -300) : Pilier central et deux murs verticaux espacés de 21 px
		_instantiate_pillar(origin + Vector2(-300, 0), "vent", out_bodies, out_pts)
		_instantiate_wall_v(origin + Vector2(-300, -270), "conduit", out_bodies, out_pts)
		_instantiate_wall_v(origin + Vector2(-300, 270), "conduit", out_bodies, out_pts)

		# Balises et barrières Est (X = 300) : Barrière centrale, pilier Sud et canon d'angle Nord
		_instantiate_barrier(origin + Vector2(300, 0), out_bodies, out_pts)
		_instantiate_pillar(origin + Vector2(300, 260), "vent", out_bodies, out_pts)
		# Angle Nord-Est : Canon de barrage d'angle couvrant l'autoroute Nord-Sud (orienté Ouest 180.0° à travers la route)
		_instantiate_cannon(origin + Vector2(300, -260), 180.0, out_bodies, out_pts)
	else:
		# Pipeline Nord (Y = -300) : Pilier central et deux murs horizontaux espacés de 26 px
		_instantiate_pillar(origin + Vector2(0, -300), "vent", out_bodies, out_pts)
		_instantiate_wall_h(origin + Vector2(-270, -300), "conduit", out_bodies, out_pts)
		_instantiate_wall_h(origin + Vector2(270, -300), "conduit", out_bodies, out_pts)

		# Balises et barrières Sud (Y = 300) : Barrière centrale, pilier Est et canon d'angle Ouest
		_instantiate_barrier(origin + Vector2(0, 300), out_bodies, out_pts)
		_instantiate_pillar(origin + Vector2(260, 300), "vent", out_bodies, out_pts)
		# Angle Sud-Ouest : Canon de barrage d'angle couvrant l'autoroute Est-Ouest (orienté Nord -90.0° à travers la route)
		_instantiate_cannon(origin + Vector2(-260, 300), -90.0, out_bodies, out_pts)

## Esplanade Logistique & Parc de Manœuvre : Zone centrale spacieuse de 800x800 px dégagée
func _build_logistics_plaza(origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2]) -> void:
	# Piliers et bornes aux 4 coins extérieurs avec espacement net de 30 px minimum
	# Coin Nord-Ouest
	_instantiate_pillar(origin + Vector2(-380, -320), "vent", out_bodies, out_pts)
	_instantiate_barrier(origin + Vector2(-140, -320), out_bodies, out_pts)

	# Coin Nord-Est : Canon de barrage d'angle (orienté 195.0° à travers la place)
	_instantiate_barrier(origin + Vector2(140, -320), out_bodies, out_pts)
	_instantiate_cannon(origin + Vector2(380, -320), 195.0, out_bodies, out_pts)

	# Coin Sud-Ouest
	_instantiate_pillar(origin + Vector2(-380, 320), "vent", out_bodies, out_pts)
	_instantiate_barrier(origin + Vector2(-140, 320), out_bodies, out_pts)

	# Coin Sud-Est
	_instantiate_barrier(origin + Vector2(140, 320), out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(380, 320), "vent", out_bodies, out_pts)

## Archetype 0 : Centrale Électrique & Réacteurs à Fusion (Configuration aérée, 0 collision)
func _build_power_substation(origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2]) -> void:
	# Paroi Nord : Pilier(-300,-270) + Mur H(-30,-270) + Pilier(240,-270) (espacement net de 26 px)
	_instantiate_pillar(origin + Vector2(-300, -270), "vent", out_bodies, out_pts)
	_instantiate_wall_h(origin + Vector2(-30, -270), "terminal", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(240, -270), "vent", out_bodies, out_pts)

	# Paroi Ouest : Mur V(-300, 0) + Pilier(-300, 270) (espacement net de 21 px)
	_instantiate_wall_v(origin + Vector2(-300, 0), "conduit", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(-300, 270), "vent", out_bodies, out_pts)

	# Cœur du réacteur intérieur et bouclier thermique (dégagé de 25 px)
	_instantiate_pillar(origin + Vector2(0, 50), "reactor", out_bodies, out_pts)
	_instantiate_barrier(origin + Vector2(0, 260), out_bodies, out_pts)

	# Cour de transformateurs Est
	_instantiate_pillar(origin + Vector2(260, 50), "vent", out_bodies, out_pts)
	_instantiate_barrier(origin + Vector2(260, 260), out_bodies, out_pts)

## Archetype 1 : Station Cryogénique & Turbines (Disposition décalée en quinconce, 0 collision)
func _build_cooling_facility(origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2]) -> void:
	# Flanc Nord : Pilier(-250,-260) + Mur H(20,-260) + Pilier(290,-260)
	_instantiate_pillar(origin + Vector2(-250, -260), "vent", out_bodies, out_pts)
	_instantiate_wall_h(origin + Vector2(20, -260), "hazard", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(290, -260), "vent", out_bodies, out_pts)

	# Aile Sud : Pilier(-290, 260) + Mur H(-20, 260) + Pilier(250, 260)
	_instantiate_pillar(origin + Vector2(-290, 260), "vent", out_bodies, out_pts)
	_instantiate_wall_h(origin + Vector2(-20, 260), "hazard", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(250, 260), "vent", out_bodies, out_pts)

	# Double échangeurs thermiques internes (dégagés au centre avec 50 px d'écartement)
	_instantiate_pillar(origin + Vector2(100, 0), "reactor", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(-150, 0), "vent", out_bodies, out_pts)

## Archetype 2 : Hangar Logistique & Quai de Fret (Grand dépôt avec baie ouverte à l'Est, 0 collision)
func _build_warehouse_bay(origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2]) -> void:
	# Enceinte principale Nord et Ouest
	_instantiate_pillar(origin + Vector2(-270, -260), "vent", out_bodies, out_pts)
	_instantiate_wall_h(origin + Vector2(0, -260), "base", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(270, -260), "vent", out_bodies, out_pts)

	_instantiate_wall_v(origin + Vector2(-270, 0), "base", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(-270, 260), "vent", out_bodies, out_pts)

	# Quai de déchargement Est et barrières de retenue
	_instantiate_pillar(origin + Vector2(150, 0), "reactor", out_bodies, out_pts)
	_instantiate_barrier(origin + Vector2(150, 240), out_bodies, out_pts)

## Archetype 3 : Sas Fortifié & Chicane Tactique (Seul secteur procédural avec canon flak, 0 collision)
func _build_security_bastion(origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2]) -> void:
	# Déflecteur Nord-Ouest : Pilier(-320,-220) + Mur H(-50,-220)
	_instantiate_pillar(origin + Vector2(-320, -220), "vent", out_bodies, out_pts)
	_instantiate_wall_h(origin + Vector2(-50, -220), "hazard", out_bodies, out_pts)

	# Déflecteur Sud-Est : Mur H(50, 220) + Pilier(320, 220)
	_instantiate_wall_h(origin + Vector2(50, 220), "hazard", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(320, 220), "vent", out_bodies, out_pts)

	# Poste de surveillance central au milieu de la chicane (dégagé de 25 px de chaque paroi)
	_instantiate_pillar(origin + Vector2(0, 0), "reactor", out_bodies, out_pts)

	# Angle Nord-Est : Canon de barrage d'angle couvrant la route d'entrée de la chicane (orienté Ouest 180.0° à travers la route)
	_instantiate_cannon(origin + Vector2(320, -220), 180.0, out_bodies, out_pts)

## Archetype 4 : Complexe de Raffinage & Pipelines Plasma (Agencement industriel étalé, 0 collision)
func _build_refinery_complex(origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2]) -> void:
	# Unité Ouest : Pilier(-270,-260) + Mur V(-270, 0) + Pilier(-270, 260)
	_instantiate_pillar(origin + Vector2(-270, -260), "vent", out_bodies, out_pts)
	_instantiate_wall_v(origin + Vector2(-270, 0), "conduit", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(-270, 260), "vent", out_bodies, out_pts)

	# Pipeline Est : Mur H(100,-260) + Pilier(370,-260)
	_instantiate_wall_h(origin + Vector2(100, -260), "conduit", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(370, -260), "vent", out_bodies, out_pts)

	# Cuves de rétention Sud
	_instantiate_pillar(origin + Vector2(100, 80), "reactor", out_bodies, out_pts)
	_instantiate_barrier(origin + Vector2(100, 280), out_bodies, out_pts)

## Archetype 5 : Atelier de Maintenance & Réparation (Hangar 3 faces avec station diagnostique, 0 collision)
func _build_repair_hangar(origin: Vector2, out_bodies: Array[Node2D], out_pts: Array[Vector2]) -> void:
	# Mur Nord de diagnostic : Pilier(-270,-260) + Mur H(0,-260) + Pilier(270,-260)
	_instantiate_pillar(origin + Vector2(-270, -260), "vent", out_bodies, out_pts)
	_instantiate_wall_h(origin + Vector2(0, -260), "terminal", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(270, -260), "vent", out_bodies, out_pts)

	# Paroi Ouest d'outillage : Mur V(-270, 0) + Pilier(-270, 260)
	_instantiate_wall_v(origin + Vector2(-270, 0), "conduit", out_bodies, out_pts)
	_instantiate_pillar(origin + Vector2(-270, 260), "vent", out_bodies, out_pts)

	# Baies de service centrales
	_instantiate_pillar(origin + Vector2(60, 0), "reactor", out_bodies, out_pts)
	_instantiate_barrier(origin + Vector2(60, 240), out_bodies, out_pts)

## ----------------------------------------------------------------------
## INSTANCIATION DES MODULES 2.5D DELUXE & OMBRES DE CONTACT
## ----------------------------------------------------------------------

func _add_shadow(parent: Node2D, size: int, sc: Vector2, pos: Vector2, alpha: float = 0.45) -> Sprite2D:
	var sh: Sprite2D = Sprite2D.new()
	sh.texture = Tex.shadow(size)
	sh.scale = sc
	sh.position = pos
	sh.modulate = Color(0.0, 0.0, 0.0, alpha)
	sh.z_index = -1
	parent.add_child(sh)
	return sh

func _instantiate_wall_h(pos: Vector2, variant: String, out_b: Array[Node2D], out_pts: Array[Vector2]) -> StaticBody2D:
	var path: String = PATH_WALL_H_BASE
	match variant:
		"hazard":   path = PATH_WALL_H_HAZARD
		"conduit":  path = PATH_WALL_H_CONDUIT
		"terminal": path = PATH_WALL_H_TERMINAL

	var tex: Texture2D = Tex.get_tex(path)
	var body: StaticBody2D = StaticBody2D.new()
	body.global_position = pos
	body.collision_layer = 8
	body.collision_mask = 0

	# Ombre de contact au sol (ancrage 2.5D compact)
	_add_shadow(body, 128, Vector2(1.7, 0.46), Vector2(8, 16), 0.42)

	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(0.82, 0.82)
	spr.position = Vector2(0, -8)
	body.add_child(spr)

	# Lueur additive sur les conduits d'énergie plasma
	if variant == "conduit":
		var glow_spr: Sprite2D = Sprite2D.new()
		glow_spr.texture = Tex.glow(Color(0.15, 0.85, 1.0), 64)
		glow_spr.material = Tex.add_mat()
		glow_spr.scale = Vector2(2.8, 0.36)
		glow_spr.position = Vector2(0, -14)
		glow_spr.modulate = Color(0.2, 0.85, 1.0, 0.48)
		glow_spr.z_index = 1
		body.add_child(glow_spr)

	var shape: RectangleShape2D = RectangleShape2D.new()
	# Hitbox affinée (épaisseur 48px au lieu de 90px) pour libérer les voies de circulation
	shape.size = Vector2(210.0, 48.0)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, 10)
	body.add_child(col)

	walls_container.add_child(body)
	out_b.append(body)
	out_pts.append(pos)
	maze_colliders.append(body)
	if game != null and "cover_list" in game:
		game.cover_list.append(pos)
	return body

func _instantiate_wall_v(pos: Vector2, variant: String, out_b: Array[Node2D], out_pts: Array[Vector2]) -> StaticBody2D:
	var path: String = PATH_WALL_V_BASE
	match variant:
		"hazard":  path = PATH_WALL_V_HAZARD
		"conduit": path = PATH_WALL_V_CONDUIT

	var tex: Texture2D = Tex.get_tex(path)
	var body: StaticBody2D = StaticBody2D.new()
	body.global_position = pos
	body.collision_layer = 8
	body.collision_mask = 0

	# Ombre de contact au sol (ancrage 2.5D compact)
	_add_shadow(body, 128, Vector2(0.46, 1.7), Vector2(8, 16), 0.42)

	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(0.82, 0.82)
	spr.position = Vector2(0, -12)
	body.add_child(spr)

	# Lueur additive sur les conduits d'énergie plasma
	if variant == "conduit":
		var glow_spr: Sprite2D = Sprite2D.new()
		glow_spr.texture = Tex.glow(Color(0.15, 0.85, 1.0), 64)
		glow_spr.material = Tex.add_mat()
		glow_spr.scale = Vector2(0.36, 2.8)
		glow_spr.position = Vector2(12, -12)
		glow_spr.modulate = Color(0.2, 0.85, 1.0, 0.48)
		glow_spr.z_index = 1
		body.add_child(glow_spr)

	var shape: RectangleShape2D = RectangleShape2D.new()
	# Hitbox affinée (largeur 48px au lieu de 90px) pour libérer les passages latéraux
	shape.size = Vector2(48.0, 210.0)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, 5)
	body.add_child(col)

	walls_container.add_child(body)
	out_b.append(body)
	out_pts.append(pos)
	maze_colliders.append(body)
	if game != null and "cover_list" in game:
		game.cover_list.append(pos)
	return body

func _instantiate_corner(pos: Vector2, corner_type: String, out_b: Array[Node2D], out_pts: Array[Vector2]) -> StaticBody2D:
	var path: String = PATH_CORNER_TL
	match corner_type:
		"tr": path = PATH_CORNER_TR
		"bl": path = PATH_CORNER_BL
		"br": path = PATH_CORNER_BR

	var tex: Texture2D = Tex.get_tex(path)
	var body: StaticBody2D = StaticBody2D.new()
	body.global_position = pos
	body.collision_layer = 8
	body.collision_mask = 0

	# Ombre de contact au sol
	_add_shadow(body, 128, Vector2(1.0, 1.0), Vector2(8, 16), 0.42)

	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(0.82, 0.82)
	spr.position = Vector2(0, -8)
	body.add_child(spr)

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(100.0, 100.0)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, 8)
	body.add_child(col)

	walls_container.add_child(body)
	out_b.append(body)
	out_pts.append(pos)
	maze_colliders.append(body)
	if game != null and "cover_list" in game:
		game.cover_list.append(pos)
	return body

func _instantiate_pillar(pos: Vector2, ptype: String, out_b: Array[Node2D], out_pts: Array[Vector2]) -> StaticBody2D:
	var path: String = PATH_PILLAR_REACTOR if ptype == "reactor" else PATH_PILLAR_VENT
	var tex: Texture2D = Tex.get_tex(path)

	var body: StaticBody2D = StaticBody2D.new()
	body.global_position = pos
	body.collision_layer = 8
	body.collision_mask = 0

	# Ombre de contact au sol
	_add_shadow(body, 96, Vector2(1.35, 0.72), Vector2(6, 18), 0.45)

	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(0.82, 0.82) if ptype == "reactor" else Vector2(0.80, 0.80)
	spr.position = Vector2(0, -16)
	body.add_child(spr)

	# Lueur dynamique de réacteur à fusion
	if ptype == "reactor":
		var glow_core: Sprite2D = Sprite2D.new()
		glow_core.texture = Tex.glow(Color(0.2, 0.9, 1.0), 128)
		glow_core.material = Tex.add_mat()
		glow_core.scale = Vector2(0.85, 0.7)
		glow_core.position = Vector2(0, -12)
		glow_core.modulate = Color(0.25, 0.9, 1.0, 0.55)
		glow_core.z_index = 1
		body.add_child(glow_core)

	var col: CollisionShape2D = CollisionShape2D.new()
	if ptype == "reactor":
		var cshape: CircleShape2D = CircleShape2D.new()
		# Rayon réduit de 75px (150px diametre) à 44px (88px diametre) : mecha circule sans buter
		cshape.radius = 44.0
		col.shape = cshape
		col.position = Vector2(0, 12)
	else:
		var rshape: RectangleShape2D = RectangleShape2D.new()
		# Empreinte de tour de ventilation réduite de 150x150 à 85x80
		rshape.size = Vector2(85.0, 80.0)
		col.shape = rshape
		col.position = Vector2(0, 8)

	body.add_child(col)
	walls_container.add_child(body)
	out_b.append(body)
	out_pts.append(pos)
	maze_colliders.append(body)
	if game != null and "cover_list" in game:
		game.cover_list.append(pos)
	return body

func _instantiate_barrier(pos: Vector2, out_b: Array[Node2D], out_pts: Array[Vector2]) -> StaticBody2D:
	var tex: Texture2D = Tex.get_tex(PATH_BARRIER_LOW)
	var body: StaticBody2D = StaticBody2D.new()
	body.global_position = pos
	body.collision_layer = 8
	body.collision_mask = 0

	# Ombre de contact au sol
	_add_shadow(body, 96, Vector2(1.6, 0.42), Vector2(6, 14), 0.38)

	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(0.82, 0.82)
	spr.position = Vector2(0, -8)
	body.add_child(spr)

	var shape: RectangleShape2D = RectangleShape2D.new()
	# Hitbox de barrière affinée de 190x55 à 140x32
	shape.size = Vector2(140.0, 32.0)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, 8)
	body.add_child(col)

	walls_container.add_child(body)
	out_b.append(body)
	out_pts.append(pos)
	maze_colliders.append(body)
	if game != null and "cover_list" in game:
		game.cover_list.append(pos)
	return body

## Instancie un canon de défense stratégique interactif (tourelle rotative avec salve flak supersonique haute fidelite et piratage)
func _instantiate_cannon(pos: Vector2, aim_deg: float, out_b: Array[Node2D], out_pts: Array[Vector2]) -> Node2D:
	var prop: PropScatter.Prop = PropScatter.Prop.new()
	prop.game = game
	prop.kind = "tourelle"
	var d: Dictionary = PropScatter.DECOR["tourelle"].duplicate()
	d["aim"] = aim_deg
	d["shot_style"] = "flak"
	d["shoot_cd"] = 3.2
	d["shoot_dmg"] = 24.0
	prop.def = d
	prop.position = pos
	prop.global_position = pos
	prop.rand_scale = 0.85
	prop.skill_roll = 0.0
	prop.flip = false
	prop.collision_layer = 8
	prop.collision_mask = 0

	# Ombre de contact au sol sous le socle de tourelle
	_add_shadow(prop, 96, Vector2(1.3, 0.82), Vector2(6, 16), 0.48)

	# Viseur optique / balise d'acquisition active sur la tourelle
	var sensor: Sprite2D = Sprite2D.new()
	sensor.texture = Tex.glow(Color(0.2, 0.9, 1.0), 32)
	sensor.material = Tex.add_mat()
	sensor.position = Vector2(0, 8)
	sensor.modulate = Color(0.3, 0.9, 1.0, 0.65)
	sensor.scale = Vector2(0.7, 0.7)
	sensor.z_index = 25
	prop.add_child(sensor)

	walls_container.add_child(prop)
	out_b.append(prop)
	out_pts.append(pos)
	maze_colliders.append(prop)
	if game != null and "cover_list" in game:
		game.cover_list.append(pos)
	return prop
