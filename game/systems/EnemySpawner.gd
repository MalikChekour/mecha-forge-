extends Node
class_name EnemySpawner
## Ring-spawns Meshy enemies around the player, ramping rate over the run.
## Data-driven; the 'motion' field maps to the baked animation sheet
## (enemies/<kind>_<motion>.png).

var game: Node
var player: Node2D
var _t: float = 0.0
var _spawn_t: float = 0.0

const DEFS: Dictionary = {
	# behavior: rush (melee) | ranged (kite + shoot) | dasher (wind-up + dash)
	"crawler": {"hp": 18.0, "speed": 96.0, "dmg": 7.0, "radius": 22.0, "size": 92.0, "motion": "scuttle", "rank": 0, "w": 4,
		"behavior": "rush"},
	"drone":   {"hp": 12.0, "speed": 134.0, "dmg": 3.0, "radius": 18.0, "size": 78.0, "motion": "hover", "rank": 0, "w": 3,
		"behavior": "ranged", "attack_dmg": 5.0, "attack_cd": 1.7, "prefer_dist": 300.0},
	"rusher":  {"hp": 16.0, "speed": 170.0, "dmg": 6.0, "radius": 18.0, "size": 80.0, "motion": "spin", "rank": 0, "w": 3,
		"behavior": "dasher", "attack_dmg": 18.0},
	"spitter": {"hp": 26.0, "speed": 80.0, "dmg": 3.0, "radius": 22.0, "size": 104.0, "motion": "idle", "rank": 0, "w": 2,
		"behavior": "ranged", "attack_dmg": 8.0, "attack_cd": 2.0, "prefer_dist": 360.0},
	"brute":   {"hp": 64.0, "speed": 70.0, "dmg": 14.0, "radius": 30.0, "size": 124.0, "motion": "walk", "rank": 1, "w": 1,
		"behavior": "rush"},
}

func _process(delta: float) -> void:
	if not GameState.alive:
		return
	_t += delta
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		var rate: float = clampf(0.85 - _t * 0.005, 0.22, 0.85)
		_spawn_t = rate
		_spawn()

func _weighted_pick() -> String:
	var total: int = 0
	for k in DEFS:
		total += int(DEFS[k]["w"])
	var r: int = randi() % maxi(1, total)
	for k in DEFS:
		r -= int(DEFS[k]["w"])
		if r < 0:
			return k
	return "crawler"

func _spawn() -> void:
	if player == null or not is_instance_valid(player):
		return
	if get_tree().get_nodes_in_group("enemies").size() > 170:
		return
	var kind: String = _weighted_pick()
	var e: Enemy = Enemy.new()
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 640.0
	game.enemy_layer.add_child(e)
	e.setup(kind, DEFS[kind], player, game)
