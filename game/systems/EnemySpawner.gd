extends Node
class_name EnemySpawner
## Ring-spawns Meshy enemies around the player, ramping rate over the run.
## Data-driven; the 'motion' field maps to the baked animation sheet
## (enemies/<kind>_<motion>.png).

var game: Node
var player: Node2D
var _t: float = 0.0
var _spawn_t: float = 0.0
var speed_mult: float = 1.0   # biome modifier on enemy movement speed
var spawn_mult: float = 1.0   # biome modifier on spawn density

const DEFS: Dictionary = {
	# behavior: rush (melee, charges) | ranged (holds distance + shoots) | dasher (wind-up + dash)
	# Archetypes are coherent with the sprite: melee foes are armed (blade/fists/shield),
	# ranged foes carry a gun/cannon and keep their distance instead of charging blindly.
	# --- MELEE (armed chargers) ---
	"crawler": {"hp": 18.0, "speed": 96.0, "dmg": 7.0, "radius": 22.0, "size": 92.0, "motion": "walk", "rank": 0, "w": 4,
		"behavior": "rush"},                                              # spider — bites
	"rusher":  {"hp": 16.0, "speed": 170.0, "dmg": 6.0, "radius": 18.0, "size": 80.0, "motion": "spin", "rank": 0, "w": 3,
		"behavior": "dasher", "attack_dmg": 18.0},                        # spinning ram
	"brute":   {"hp": 64.0, "speed": 70.0, "dmg": 14.0, "radius": 30.0, "size": 124.0, "motion": "walk", "rank": 1, "w": 1,
		"behavior": "rush"},                                              # brawler — fists
	"crusher": {"hp": 130.0, "speed": 58.0, "dmg": 22.0, "radius": 36.0, "size": 156.0, "motion": "walk", "rank": 2, "w": 1,
		"behavior": "rush"},                                              # heavy — energy sword (baked)
	"elite":   {"hp": 150.0, "speed": 74.0, "dmg": 20.0, "radius": 34.0, "size": 146.0, "motion": "walk", "rank": 2, "w": 1,
		"behavior": "rush"},                                              # bladed
	"shielded": {"hp": 110.0, "speed": 62.0, "dmg": 12.0, "radius": 32.0, "size": 136.0, "motion": "walk", "rank": 1, "w": 2,
		"behavior": "rush", "shield": 90.0},                              # shield tank (energy barrier)
	# --- RANGED (hold distance + shoot; carry a gun/cannon) ---
	"drone":   {"hp": 12.0, "speed": 134.0, "dmg": 3.0, "radius": 18.0, "size": 78.0, "motion": "hover", "rank": 0, "w": 3,
		"behavior": "ranged", "attack_dmg": 5.0, "attack_cd": 1.7, "prefer_dist": 300.0},
	"spitter": {"hp": 26.0, "speed": 80.0, "dmg": 3.0, "radius": 22.0, "size": 104.0, "motion": "walk", "rank": 0, "w": 2,
		"behavior": "ranged", "attack_dmg": 8.0, "attack_cd": 2.0, "prefer_dist": 360.0},   # plasma cannon
	"raider":  {"hp": 34.0, "speed": 132.0, "dmg": 9.0, "radius": 22.0, "size": 104.0, "motion": "walk", "rank": 1, "w": 3,
		"behavior": "ranged", "attack_dmg": 8.0, "attack_cd": 1.3, "prefer_dist": 300.0},   # gun skirmisher (baked)
	# the former player mech, now a ranged elite foe (holds a cannon)
	"warden":  {"hp": 90.0, "speed": 88.0, "dmg": 16.0, "radius": 30.0, "size": 140.0, "motion": "walk", "rank": 2, "w": 1,
		"behavior": "ranged", "attack_dmg": 11.0, "attack_cd": 1.6, "prefer_dist": 340.0, "shield": 50.0},
	# --- BOSSES (w:0 -> never in the weighted pick; spawned on the timed schedule) ---
	"midboss": {"hp": 850.0, "speed": 66.0, "dmg": 24.0, "radius": 58.0, "size": 300.0, "motion": "quad_walk",
		"rank": 3, "w": 0, "behavior": "rush", "shield": 200.0},
	"endboss": {"hp": 2800.0, "speed": 54.0, "dmg": 32.0, "radius": 78.0, "size": 380.0, "motion": "boss_idle",
		"rank": 4, "w": 0, "behavior": "rush", "shield": 400.0, "final": true},
}

# Timed run structure: bosses at 5 min (build filter), 10 min, 15 min (final -> victory).
const BOSS_SCHEDULE: Array = [
	{"t": 300.0, "kind": "midboss"},
	{"t": 600.0, "kind": "midboss"},
	{"t": 900.0, "kind": "endboss"},
]
var _bosses_fired: int = 0

func _process(delta: float) -> void:
	if not GameState.alive:
		return
	_t += delta
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		var rate: float = clampf(0.85 - _t * 0.005, 0.22, 0.85)
		_spawn_t = rate / maxf(0.2, spawn_mult)
		_spawn()
	if _bosses_fired < BOSS_SCHEDULE.size() and GameState.run_time >= float(BOSS_SCHEDULE[_bosses_fired]["t"]):
		_spawn_boss(String(BOSS_SCHEDULE[_bosses_fired]["kind"]))
		_bosses_fired += 1

func _spawn_boss(kind: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	var e: Enemy = Enemy.new()
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 760.0
	game.enemy_layer.add_child(e)
	e.setup(kind, DEFS[kind], player, game)
	e.speed *= speed_mult
	if game != null and game.has_method("show_banner"):
		game.show_banner("!  MENACE MAJEURE  !", Color(1.0, 0.4, 0.3))
	Audio.sfx("boss")
	Audio.music("boss")

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
	e.speed *= speed_mult
