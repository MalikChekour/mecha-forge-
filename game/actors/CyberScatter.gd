extends Node2D
class_name CyberScatter

var game: Node
var biome: String = "tech"
var arena_half: float = 0.0

var _chunks: Dictionary = {}
var _last_cell: Vector2i = Vector2i(999999, 999999)
var _player: Node2D = null

const CHUNK: float = 600.0
const LOAD_R: int = 2
const COVER_R: int = 1

func _player_pos() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		return _player.global_position
	return Vector2.ZERO

func current_map_phase() -> int:
	return clampi(int(round(clampf(GameState.run_time / 300.0, 0.0, 2.0))), 0, 2)


func populate(_count: int = 28) -> void:
	if arena_half > 0.0:
		var cr: int = int(ceil(arena_half / CHUNK))
		for cy in range(-cr, cr + 1):
			for cx in range(-cr, cr + 1):
				_load_chunk(Vector2i(cx, cy))
		_refresh_cover(_cell_of(_player_pos()))

func build_border(half: float) -> void:
	# Indestructible digital walls
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var step: float = 150.0
	var count: int = int(half * 2.0 / step)
	for i in range(count):
		var t = -half + i * step
		_spawn_wall(Vector2(t, -half))
		_spawn_wall(Vector2(t, half))
		_spawn_wall(Vector2(-half, t))
		_spawn_wall(Vector2(half, t))

func _spawn_wall(pos: Vector2) -> void:
	var node = CyberNode.new()
	node.global_position = pos
	node.sz = 100.0
	node.col = Color(1.0, 0.0, 0.4, 0.9)
	node.sides = 4
	node.hp = 999999.0
	node.rot_speed = 0.0
	add_child(node)

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK)), int(floor(p.y / CHUNK)))

func _process(_delta: float) -> void:
	var cell: Vector2i = _cell_of(_player_pos())
	if cell != _last_cell:
		_last_cell = cell
		if arena_half > 0.0:
			_refresh_cover(cell)

func _refresh_cover(cell: Vector2i) -> void:
	if game == null or not ("cover_list" in game):
		return
	game.cover_list.clear()
	for dy in range(-COVER_R, COVER_R + 1):
		for dx in range(-COVER_R, COVER_R + 1):
			var props: Variant = _chunks.get(cell + Vector2i(dx, dy))
			if props == null:
				continue
			for p in props:
				if is_instance_valid(p):
					game.cover_list.append(p)

func _load_chunk(c: Vector2i) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % ["cyber", c.x, c.y])
	var origin: Vector2 = Vector2(float(c.x) * CHUNK, float(c.y) * CHUNK)
	
	var props: Array = []
	var count: int = rng.randi_range(1, 4)
	for i in range(count):
		var pos: Vector2 = origin + Vector2(rng.randf_range(50.0, CHUNK-50.0), rng.randf_range(50.0, CHUNK-50.0))
		if pos.distance_to(_player_pos()) < 400.0:
			continue
		
		var node = CyberNode.new()
		node.global_position = pos
		node.sz = rng.randf_range(40.0, 100.0)
		node.col = Color(rng.randf_range(0.0, 0.4), rng.randf_range(0.6, 1.0), rng.randf_range(0.8, 1.0), 0.8)
		node.sides = rng.randi_range(3, 6)
		add_child(node)
		props.append(node)
		
	_chunks[c] = props

class CyberNode extends Area2D:
	var sz: float = 60.0
	var col: Color = Color(0.0, 1.0, 0.8, 0.8)
	var sides: int = 4
	var block_r: float = 0.0
	var hp: float = 300.0
	var rot_speed: float = 0.0
	
	func _init() -> void:
		collision_layer = 8
		block_r = sz * 0.9
		rot_speed = randf_range(-1.5, 1.5)
		
		var shape: CollisionShape2D = CollisionShape2D.new()
		var circ: CircleShape2D = CircleShape2D.new()
		circ.radius = block_r
		shape.shape = circ
		add_child(shape)
		
	func _process(_delta: float) -> void:
		queue_redraw()
		
	func _draw() -> void:
		var pts: PackedVector2Array = []
		var t = Time.get_ticks_msec() * 0.001
		var base_rot = t * rot_speed
		for i in range(sides):
			var a = base_rot + i * TAU / sides
			pts.append(Vector2(cos(a), sin(a)) * sz)
		
		var c = col
		c.a = 0.3 + 0.2 * sin(t * 3.0)
		draw_colored_polygon(pts, c)
		
		pts.append(pts[0])
		draw_polyline(pts, col, 4.0, true)

	func take_damage(amt: float) -> void:
		hp -= amt
		if hp <= 0.0:
			queue_free()
