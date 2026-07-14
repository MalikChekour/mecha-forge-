extends Node
## Minimal persistence (meta scrap + settings) to user://. Expanded in Phase 2
## (meta tree, chassis, unlocks).

const PATH: String = "user://mecha_forge_save.json"

var data: Dictionary = {
	"meta_scrap": 0,
	"meta": {},                       # talent id -> purchased level
	"settings": {"shake": true, "damage_numbers": true},
	"difficulty": 1,                  # last chosen difficulty index
	"best_scores": {},                # difficulty index (as str) -> best score (local leaderboard)
	"owned_mechs": ["mecha_joueur"],  # unlocked chassis (base always owned)
	"equipped_mech": "mecha_joueur",
	# --- forward-compatible keys for the upcoming equipment economy / retention (Vague 1) ---
	# load_data() merges per-key, so old saves absorb these without breaking.
	"parts": [],                      # [{uid, def_id, rarity, plus, enchant, locked}]
	"equipped": {},                   # slot -> part uid
	"crystals": 0,                    # premium hard currency (gacha)
	"cores": 0,                       # forge currency (from salvage)
	"last_played": 0,                 # unix ts for daily reward / offline gains
	"first_run": true,                # RESERVED (Vague 1): future FTUE gate — NOT yet read (Game._ready always shows the modal)
}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if FileAccess.file_exists(PATH):
		var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for k in d:
					data[k] = d[k]

func save_data() -> void:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))

func bank_scrap(amount: int) -> void:
	data["meta_scrap"] = int(data.get("meta_scrap", 0)) + amount
	save_data()

func meta_level(id: String) -> int:
	var m: Dictionary = data.get("meta", {})
	return int(m.get(id, 0))

func get_difficulty() -> int:
	return int(data.get("difficulty", 1))

func set_difficulty(idx: int) -> void:
	data["difficulty"] = clampi(idx, 0, GameState.DIFFICULTY.size() - 1)
	save_data()

# Record a run's score for its difficulty; returns true if it's a new personal best.
func record_score(difficulty: int, score: int) -> bool:
	var bs: Dictionary = data.get("best_scores", {})
	var key: String = str(difficulty)
	var prev: int = int(bs.get(key, 0))
	if score > prev:
		bs[key] = score
		data["best_scores"] = bs
		save_data()
		return true
	return false

func best_score(difficulty: int) -> int:
	return int(data.get("best_scores", {}).get(str(difficulty), 0))

# --- mech garage ---
func owns_mech(id: String) -> bool:
	if id == "mecha_joueur":
		return true
	return (data.get("owned_mechs", []) as Array).has(id)

func equipped_mech() -> String:
	return String(data.get("equipped_mech", "mecha_joueur"))

func equip_mech(id: String) -> void:
	if owns_mech(id):
		data["equipped_mech"] = id
		save_data()

# Buy `id` for `cost` scrap and auto-equip. Returns true on success.
func buy_mech(id: String, cost: int) -> bool:
	if owns_mech(id) or int(data.get("meta_scrap", 0)) < cost:
		return false
	data["meta_scrap"] = int(data["meta_scrap"]) - cost
	var owned: Array = data.get("owned_mechs", [])
	owned.append(id)
	data["owned_mechs"] = owned
	data["equipped_mech"] = id
	save_data()
	return true

# Try to buy the next level of talent `id` for `cost` scrap. Returns true on success.
func buy_meta(id: String, cost: int) -> bool:
	var d: Dictionary = GameState.META.get(id, {})
	if d.is_empty():
		return false
	var m: Dictionary = data.get("meta", {})
	if int(m.get(id, 0)) >= int(d.get("max", 0)):
		return false   # already maxed: enforce the cap at the data layer, not just the UI
	if int(data.get("meta_scrap", 0)) < cost:
		return false
	data["meta_scrap"] = int(data["meta_scrap"]) - cost
	m[id] = int(m.get(id, 0)) + 1
	data["meta"] = m
	save_data()
	return true
