extends Node
## Minimal persistence (meta scrap + settings) to user://. Expanded in Phase 2
## (meta tree, chassis, unlocks).

const PATH: String = "user://mecha_forge_save.json"

var data: Dictionary = {
	"meta_scrap": 0,
	"meta": {},                       # talent id -> purchased level
	"equipped_chassis": "vanguard",
	"settings": {"shake": true, "damage_numbers": true},
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

# Try to buy the next level of talent `id` for `cost` scrap. Returns true on success.
func buy_meta(id: String, cost: int) -> bool:
	if int(data.get("meta_scrap", 0)) < cost:
		return false
	data["meta_scrap"] = int(data["meta_scrap"]) - cost
	var m: Dictionary = data.get("meta", {})
	m[id] = int(m.get(id, 0)) + 1
	data["meta"] = m
	save_data()
	return true
