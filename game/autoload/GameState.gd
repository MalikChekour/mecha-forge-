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
var score: int = 0            # run score (kills weighted by rank x difficulty) -> leaderboard/grade

# --- DIFFICULTY (chosen at run start) : scales foes + rewards + score weight ---
const DIFFICULTY: Array = [
	{"name": "FACILE",   "hp": 0.72, "dmg": 0.68, "speed": 0.92, "spawn": 0.85, "reward": 0.8, "score": 0.7},
	{"name": "NORMAL",   "hp": 1.00, "dmg": 1.00, "speed": 1.00, "spawn": 1.00, "reward": 1.0, "score": 1.0},
	{"name": "DIFFICILE","hp": 1.40, "dmg": 1.28, "speed": 1.06, "spawn": 1.20, "reward": 1.3, "score": 1.6},
	{"name": "VETERAN",  "hp": 1.85, "dmg": 1.62, "speed": 1.12, "spawn": 1.45, "reward": 1.7, "score": 2.4},
]
var difficulty: int = 1       # index into DIFFICULTY (default NORMAL)

func diff() -> Dictionary:
	return DIFFICULTY[clampi(difficulty, 0, DIFFICULTY.size() - 1)]

# Rank grade from final score (shown next to the player on results/leaderboard).
func grade() -> String:
	if score >= 60000: return "S+"
	elif score >= 38000: return "S"
	elif score >= 22000: return "A"
	elif score >= 12000: return "B"
	elif score >= 6000: return "C"
	elif score >= 2500: return "D"
	return "E"

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

# --- MECHS (alternate chassis bought with scrap "credits"; each plays DIFFERENTLY) ---
# Reuses the already-baked 4-dir sheets in assets/mecha/. hp = flat +max HP, dmg/speed =
# multipliers, crit = flat +chance, weapons = distinct starter loadout.
const MECHS: Array = [
	{"id": "mecha_joueur", "name": "AEGIS",    "cost": 0,   "weapons": ["autocannon"],          "hp": 0.0,  "dmg": 1.0,  "speed": 1.0,  "crit": 0.0,  "desc": "Polyvalent - autocanon rapide"},
	{"id": "vanguard",     "name": "VANGUARD", "cost": 120, "weapons": ["missilepod"],          "hp": -10.0,"dmg": 1.0,  "speed": 1.07, "crit": 0.0,  "desc": "Agile - missiles chercheurs"},
	{"id": "valiant",      "name": "VALIANT",  "cost": 220, "weapons": ["plasma"],              "hp": 10.0, "dmg": 1.0,  "speed": 1.0,  "crit": 0.05, "desc": "Zone - canon plasma"},
	{"id": "titan",        "name": "TITAN",    "cost": 320, "weapons": ["railgun"],             "hp": 50.0, "dmg": 1.12, "speed": 0.9,  "crit": 0.0,  "desc": "Lourd - railgun percant"},
	{"id": "vanguard2",    "name": "NEMESIS",  "cost": 500, "weapons": ["autocannon","plasma"], "hp": 15.0, "dmg": 1.15, "speed": 1.06, "crit": 0.08, "desc": "PREMIUM - double arme + crit"},
]

static func mech_def(id: String) -> Dictionary:
	for m in MECHS:
		if String(m["id"]) == id:
			return m
	return MECHS[0]

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
	score = 0
	difficulty = SaveManager.get_difficulty()   # default from last choice; run-start menu can override
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
	amount = int(round(amount * float(diff().get("reward", 1.0))))   # difficulty reward bonus (UI promise)
	scrap += amount
	Events.scrap_collected.emit(amount)

func add_kill(pos: Vector2, rank: int) -> void:
	kills += 1
	score += int(round((10 + rank * 40) * float(diff().get("score", 1.0))))   # rank & difficulty weighted
	add_overdrive(0.055 + rank * 0.03)
	Events.enemy_killed.emit(pos, rank)

func add_overdrive(a: float) -> void:
	overdrive = clampf(overdrive + a * (1.0 + meta_od), 0.0, 1.0)   # Surcharge meta talent
	Events.overdrive_changed.emit(overdrive)
