class_name PlasmaPool
extends Node2D
## BRASIER : mare d'energie au sol (arme active originale, role "Molotov" mais identite maison).
## Persiste `life` secondes et inflige des degats aux ennemis dedans par tick. Pulse + s'estompe.

var radius: float = 90.0
var dmg: float = 6.0
var life: float = 3.2
var color: Color = Color(0.4, 0.9, 1.0)
var crit_chance: float = 0.0
var crit_mult: float = 2.0

var _t: float = 0.0
var _tick: float = 0.0
var _fill: Sprite2D
var _ring: Sprite2D
var _life0: float = 1.0

func _ready() -> void:
	z_index = -2                              # au SOL, sous les ennemis
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_life0 = life
	var d: float = radius * 2.0 / 128.0
	_fill = Sprite2D.new(); _fill.texture = Tex.glow(color, 128); _fill.material = Tex.add_mat()
	_fill.scale = Vector2.ONE * d; _fill.modulate = Color(color.r, color.g, color.b, 0.22)
	add_child(_fill)
	_ring = Sprite2D.new(); _ring.texture = Tex.ring(color, 128); _ring.material = Tex.add_mat()
	_ring.scale = Vector2.ONE * d; _ring.modulate = Color(color.r, color.g, color.b, 0.5)
	add_child(_ring)

func _process(delta: float) -> void:
	if GameState != null and not GameState.alive:
		return
	_t += delta
	life -= delta
	var fade: float = clampf(life / 0.5, 0.0, 1.0)          # s'estompe en fin de vie
	var pulse: float = 0.5 + 0.5 * sin(_t * 7.0)
	_fill.modulate.a = (0.14 + 0.12 * pulse) * fade
	_ring.modulate.a = (0.35 + 0.25 * pulse) * fade
	_ring.rotation += delta * 0.8
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.3
		var r2: float = radius * radius
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and (e as Enemy).alive and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
				var isc: bool = randf() < crit_chance
				var dm: float = dmg * (crit_mult if isc else 1.0)
				(e as Enemy).take_damage(dm)
				if isc:
					Events.damage_dealt.emit((e as Node2D).global_position, int(dm), true)
	if life <= 0.0:
		queue_free()
