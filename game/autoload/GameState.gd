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
var overdrive_active: bool = false   # true during the Overdrive spike -> global XP magnet
var alive: bool = true

# --- META-PROGRESSION (persistent talents bought with banked scrap between runs) ---
# Data-driven: id -> {name, stat, per(-level bonus), max(level), cost[per level]}.
# Caps kept modest (guide: meta <= ~+30%) so skill stays king, not pay/grind-to-win.
const META: Dictionary = {
	"vitalite":  {"name": "Vitalité",  "stat": "hp",        "per": 10.0, "max": 5, "cost": [40, 70, 110, 160, 230]},
	"puissance": {"name": "Puissance", "stat": "damage",    "per": 0.06, "max": 5, "cost": [50, 90, 140, 200, 280]},
	"agilite":   {"name": "Agilité",   "stat": "speed",     "per": 0.035, "max": 4, "cost": [45, 80, 130, 190]},
	"cupidite":  {"name": "Cupidité",  "stat": "xp",        "per": 0.08, "max": 4, "cost": [50, 90, 150, 220]},
	"surcharge": {"name": "Surcharge", "stat": "overdrive", "per": 0.10, "max": 3, "cost": [60, 120, 200]},
}
var meta_hp: float = 0.0
var meta_dmg: float = 0.0
var meta_speed: float = 0.0
var meta_xp: float = 0.0
var meta_od: float = 0.0

func reset() -> void:
	run_time = 0.0
	level = 1
	xp = 0
	xp_to_next = 5
	kills = 0
	scrap = 0
	overdrive = 0.0
	overdrive_active = false
	alive = true
	_compute_meta()

func _compute_meta() -> void:
	meta_hp = 0.0; meta_dmg = 0.0; meta_speed = 0.0; meta_xp = 0.0; meta_od = 0.0
	for id in META:
		var lvl: int = SaveManager.meta_level(id)
		if lvl <= 0:
			continue
		var d: Dictionary = META[id]
		var amt: float = float(d["per"]) * lvl
		match String(d["stat"]):
			"hp": meta_hp += amt
			"damage": meta_dmg += amt
			"speed": meta_speed += amt
			"xp": meta_xp += amt
			"overdrive": meta_od += amt

func add_xp(amount: int) -> void:
	amount = int(ceil(amount * (1.0 + meta_xp)))   # Cupidité meta talent
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
	overdrive = clampf(overdrive + a * (1.0 + meta_od), 0.0, 1.0)   # Surcharge meta talent
	Events.overdrive_changed.emit(overdrive)
