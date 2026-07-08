extends CharacterBody2D
class_name Player
## Top-down player: a DirectionalMecha (Meshy 4-dir sprites) driven by keyboard/
## touch stick, auto-firing bolts at the nearest enemy. Weapons currently fire
## from the mecha body (Phase 1); swappable overlay hardpoints come in Phase 2.

var game: Node
var mecha: DirectionalMecha
var base_speed: float = 320.0
var hp: float = 100.0
var max_hp: float = 100.0
var damage: float = 12.0
var fire_interval: float = 0.45
var arena: Rect2 = Rect2(-2200, -2200, 4400, 4400)

var bolt_pierce: int = 0
var bot_active: bool = false
var bot_move: Vector2 = Vector2.ZERO

var _iframe: float = 0.0
var _fire_t: float = 0.0
var _stick_id: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_vec: Vector2 = Vector2.ZERO
var _aim: Vector2 = Vector2.DOWN

func get_layer_ok() -> bool:
	return mecha != null

func _ready() -> void:
	mecha = DirectionalMecha.new()
	mecha.chassis = String(SaveManager.data.get("equipped_chassis", "vanguard"))
	mecha.display_height = 156.0
	add_child(mecha)
	var cs: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new(); c.radius = 26.0
	cs.shape = c
	add_child(cs)
	collision_layer = 1
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if not GameState.alive:
		return
	_iframe = maxf(0.0, _iframe - delta)
	var mv: Vector2 = _move_input()
	velocity = mv * base_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, arena.position.x, arena.end.x)
	global_position.y = clampf(global_position.y, arena.position.y, arena.end.y)

	if mv.length() > 0.1:
		_aim = mv
		mecha.set_facing_from(mv)
		if mecha.current_anim() == "idle":
			mecha.play("walk")
	elif mecha.current_anim() == "walk":
		mecha.play("idle")

	_fire_t -= delta
	if _fire_t <= 0.0:
		var target: Node2D = _nearest_enemy()
		if target != null:
			_fire_t = fire_interval
			var dir: Vector2 = (target.global_position - global_position).normalized()
			_aim = dir
			mecha.set_facing_from(dir)
			if game != null and game.has_method("spawn_bolt"):
				game.spawn_bolt(global_position + dir * 40.0, dir, damage)

func _move_input() -> Vector2:
	if bot_active:
		return bot_move
	var kb: Vector2 = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if kb == Vector2.ZERO:
		if Input.is_key_pressed(KEY_A): kb.x -= 1.0
		if Input.is_key_pressed(KEY_D): kb.x += 1.0
		if Input.is_key_pressed(KEY_W): kb.y -= 1.0
		if Input.is_key_pressed(KEY_S): kb.y += 1.0
	if kb.length() > 0.1:
		return kb.normalized()
	if _stick_id != -1:
		return _stick_vec
	return Vector2.ZERO

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and e.position.x < get_viewport_rect().size.x * 0.55:
			_stick_id = e.index
			_stick_origin = e.position
			_stick_vec = Vector2.ZERO
		elif not e.pressed and e.index == _stick_id:
			_stick_id = -1
			_stick_vec = Vector2.ZERO
	elif e is InputEventScreenDrag and e.index == _stick_id:
		_stick_vec = (e.position - _stick_origin).limit_length(80.0) / 80.0

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var bd: float = 1.0e12
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D:
			var d: float = global_position.distance_squared_to((e as Node2D).global_position)
			if d < bd:
				bd = d
				best = e
	return best

func take_damage(amount: float) -> void:
	if _iframe > 0.0 or not GameState.alive:
		return
	hp -= amount
	_iframe = 0.55
	Events.player_damaged.emit(hp, max_hp)
	Events.screen_shake.emit(6.0)
	if hp <= 0.0:
		hp = 0.0
		GameState.alive = false
		mecha.play("die")
		Events.player_died.emit()
