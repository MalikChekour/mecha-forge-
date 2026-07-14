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
var difficulty_bonus: float = 0.0   # permanent step-up per cleared zone (set by Game.next_map)
# Scripted HORDES: a massive coordinated wave that crashes in at timed moments. First at
# ~1 min, then on an interval; each wave grows with run time and stays mobile-safe (capped).
var _wave_t: float = 38.0
const WAVE_INTERVAL: float = 50.0
const ENEMY_CAP: int = 220   # weak swarm dies fast -> allow a denser horde on screen

const DEFS: Dictionary = {
	# behavior: rush (melee, charges) | ranged (holds distance + shoots) | dasher (wind-up + dash)
	# SURVIVOR.IO-STYLE tiers: a WEAK SWARM that dies in 1-2 hits and comes in numbers, a few
	# INTERMEDIATE foes (tankier, rarer) that DROP A BONUS on death, and the tanky bosses.
	# --- SWARM FODDER (rank 0: from the start, weak, high spawn weight -> come as a horde) ---
	"brute":   {"hp": 14.0, "speed": 104.0, "dmg": 6.0, "radius": 30.0, "size": 124.0, "motion": "walk", "rank": 0, "w": 6,
		"behavior": "rush"},                                              # basic brawler — the bulk of the swarm
	"shielded": {"hp": 20.0, "speed": 92.0, "dmg": 6.0, "radius": 32.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 4,
		"behavior": "rush"},                                              # slightly sturdier swarmling (shield removed -> dies fast)
	"drone":   {"hp": 9.0, "speed": 152.0, "dmg": 3.0, "radius": 18.0, "size": 78.0, "motion": "hover", "rank": 0, "w": 5,
		"behavior": "ranged", "attack_dmg": 4.0, "attack_cd": 1.9, "prefer_dist": 280.0},   # fast weak flyer harasser
	# --- INTERMEDIATES (rank 1: appear a bit into the run, tankier, RARE, drop a bonus on death) ---
	"crusher": {"hp": 70.0, "speed": 64.0, "dmg": 16.0, "radius": 36.0, "size": 156.0, "motion": "walk", "rank": 1, "w": 1,
		"behavior": "rush", "drops_bonus": true},                         # heavy bruiser -> drops a bonus
	"elite":   {"hp": 82.0, "speed": 80.0, "dmg": 18.0, "radius": 34.0, "size": 146.0, "motion": "walk", "rank": 1, "w": 1,
		"behavior": "rush", "drops_bonus": true},                         # bladed elite -> drops a bonus
	"warden":  {"hp": 74.0, "speed": 88.0, "dmg": 14.0, "radius": 30.0, "size": 140.0, "motion": "walk", "rank": 1, "w": 1,
		"behavior": "ranged", "attack_dmg": 10.0, "attack_cd": 1.7, "prefer_dist": 330.0, "drops_bonus": true},  # ranged elite -> drops a bonus
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
		# swarm cadence: already dense at the start, ramps to a heavy horde (weak foes -> OK)
		var rate: float = clampf(0.82 - _t * 0.0016, 0.15, 0.82)
		_spawn_t = rate / maxf(0.2, spawn_mult * float(GameState.diff().get("spawn", 1.0)))
		_spawn()
	if _bosses_fired < BOSS_SCHEDULE.size() and GameState.run_time >= float(BOSS_SCHEDULE[_bosses_fired]["t"]):
		if not _boss_alive():   # never let two bosses coexist -> avoids double next_map in one frame
			_spawn_boss(String(BOSS_SCHEDULE[_bosses_fired]["kind"]))
			_bosses_fired += 1
	_wave_t -= delta
	if _wave_t <= 0.0:
		_wave_t = WAVE_INTERVAL
		_spawn_wave()

## Hold off spawning for `s` seconds (used by the run-start teleport intro).
func delay_spawns(s: float) -> void:
	_spawn_t = maxf(_spawn_t, s)

func _spawn_boss(kind: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	var e: Enemy = Enemy.new()
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 760.0
	game.enemy_layer.add_child(e)
	e.setup(kind, DEFS[kind], player, game)
	_scale_enemy(e)   # bosses scale with run time + cleared-zone bonus + difficulty, like the trash
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("shockwave", e.global_position, 0.0, 3.0, Color(1.0, 0.5, 0.4))   # menacing arrival ring
	if game != null and game.has_method("show_banner"):
		game.show_banner("!  MENACE MAJEURE  !", Color(1.0, 0.4, 0.3))
	Audio.sfx("boss")
	Audio.music("boss")

func _boss_alive() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).alive and int((e as Enemy).rank) >= 3:
			return true
	return false

func _rank_unlocked(rank: int, t: float) -> bool:
	# gate tougher foes by run time so the opening is gentle and it builds up
	if rank <= 0:
		return true
	if rank == 1:
		return t >= 40.0    # intermediates (crusher/elite/warden) trickle in after 40s -> opening is pure weak swarm
	return t >= 240.0       # (reserved) higher tiers

func _weighted_pick(fodder_only: bool = false) -> String:
	var t: float = GameState.run_time
	var picks: Array = []
	var total: int = 0
	for k in DEFS:
		var w: int = int(DEFS[k]["w"])
		if w <= 0:
			continue                       # bosses (spawned on schedule, not here)
		if fodder_only and int(DEFS[k]["rank"]) > 0:
			continue                       # massive waves = the weak swarm only (no tanky intermediates)
		if not _rank_unlocked(int(DEFS[k]["rank"]), t):
			continue
		picks.append([k, w]); total += w
	if picks.is_empty():
		return "drone"
	var r: int = randi() % maxi(1, total)
	for pw in picks:
		r -= int(pw[1])
		if r < 0:
			return String(pw[0])
	return String(picks[0][0])

func _spawn() -> void:
	if player == null or not is_instance_valid(player):
		return
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return
	var kind: String = _weighted_pick()
	var e: Enemy = Enemy.new()
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 640.0
	game.enemy_layer.add_child(e)
	e.setup(kind, DEFS[kind], player, game)
	_scale_enemy(e)

# Scale a fresh enemy, per stat (not uniformly):
#   HP     = run-time crescendo + per-zone bonus + difficulty (full stack)
#   damage = per-zone bonus + difficulty (contact AND ranged bolts)
#   speed  = biome modifier + difficulty only (intentionally NOT time/zone — enemy speed must
#            not creep upward over a run; cf. Game.next_map where difficulty_bonus feeds HP/dmg)
func _scale_enemy(e: Enemy) -> void:
	var d: Dictionary = GameState.diff()
	e.speed *= speed_mult * float(d.get("speed", 1.0))
	var hp_scale: float = (1.0 + GameState.run_time * 0.0011) * (1.0 + difficulty_bonus) * float(d.get("hp", 1.0))
	e.hp *= hp_scale
	e.hp_max = e.hp
	if e.shield_max > 0.0:               # shields scale with HP too, else late-game shields are trivial
		e.shield_max *= hp_scale
		e.shield = e.shield_max
	var dmg_scale: float = (1.0 + difficulty_bonus * 0.5) * float(d.get("dmg", 1.0))
	e.contact_dmg *= dmg_scale
	e.attack_dmg *= dmg_scale             # ranged bolts scale too (else late-game shooters are harmless)

# Scripted horde: a big ring of foes crashes in at once. Leans on one archetype for a
# coherent "swarm" read, mixes in a few others, and stays under the enemy cap for mobile.
func _spawn_wave() -> void:
	if player == null or not is_instance_valid(player):
		return
	var existing: int = get_tree().get_nodes_in_group("enemies").size()
	var want: int = 24 + int(GameState.run_time / 40.0) * 6 + int(difficulty_bonus * 24.0)
	var count: int = clampi(want, 0, maxi(0, ENEMY_CAP - existing))
	if count <= 0:
		return
	var lead: String = _weighted_pick(true)   # waves are pure weak swarm (fodder only)
	var base_ang: float = randf() * TAU
	for i in count:
		var ang: float = base_ang + float(i) / float(count) * TAU + randf_range(-0.06, 0.06)
		var dist: float = 720.0 + randf_range(-40.0, 130.0)
		var kind: String = lead if randf() < 0.82 else _weighted_pick(true)
		var e: Enemy = Enemy.new()
		e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * dist
		game.enemy_layer.add_child(e)
		e.setup(kind, DEFS[kind], player, game)
		_scale_enemy(e)
	if game != null and game.has_method("show_banner"):
		game.show_banner(">>>  VAGUE MASSIVE  <<<", Color(1.0, 0.55, 0.3))
	Audio.sfx("boss", 0.1)
