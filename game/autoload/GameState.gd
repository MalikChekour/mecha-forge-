extends Node
## Live run state (reset each run). Progression math lives here so HUD/Player read
## one source of truth.

var run_time: float = 0.0
var level: int = 1
var xp: int = 0
var xp_to_next: int = 5
var kills: int = 0
var scrap: int = 0
var overdrive: float = 0.0    # 0..1 — fills with kills, unlocks the transformation
var alive: bool = true

func reset() -> void:
	run_time = 0.0
	level = 1
	xp = 0
	xp_to_next = 5
	kills = 0
	scrap = 0
	overdrive = 0.0
	alive = true

func add_xp(amount: int) -> void:
	xp += amount
	Events.xp_gained.emit(amount)
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(xp_to_next * 1.35)) + 2
		Events.level_up.emit(level)

func add_scrap(amount: int) -> void:
	scrap += amount
	Events.scrap_collected.emit(amount)

func add_kill(pos: Vector2, rank: int) -> void:
	kills += 1
	add_overdrive(0.055 + rank * 0.03)
	Events.enemy_killed.emit(pos, rank)

func add_overdrive(a: float) -> void:
	overdrive = clampf(overdrive + a, 0.0, 1.0)
	Events.overdrive_changed.emit(overdrive)
