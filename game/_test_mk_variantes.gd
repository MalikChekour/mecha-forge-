extends Node
## Versions MK (16/10, essai) : definies, jouables (cout 0 = possedees), famille mecanique = chassis de base, ancres de tir reprises,
## planches idle/walk/attack presentes dans les 8 directions.
##   godot --headless --path game res://_test_mk_variantes.tscn
var _fail: int = 0
func _ok(c: bool, label: String, detail: String = "") -> void:
	if c:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST VERSIONS MK ===")
	GameState.reset()
	var dirs: Array = ["front", "back", "left", "right", "front_right", "front_left", "back_right", "back_left"]
	for base in ["vortex", "bluestrike"]:
		var b: Dictionary = GameState.mech_def(base)
		var prev_hp: float = float(b["hp"])
		for n in [2, 3, 4]:
			var id: String = "%smk%d" % [base, n]
			var d: Dictionary = GameState.mech_def(id)
			_ok(String(d["id"]) == id, "%s : defini au catalogue" % id)
			_ok(GameState.chassis_family(id) == base, "%s : famille = %s" % [id, base])
			_ok(float(d["hp"]) > prev_hp, "%s : PV > palier precedent" % id, "%s > %s" % [d["hp"], prev_hp])
			prev_hp = float(d["hp"])
			_ok(String(d["signature"]) == String(b["signature"]) and (d["arsenal"] as Array).size() == 5, "%s : meme signature/arsenal que %s" % [id, base])
			_ok(SaveManager.owns_mech(id), "%s : possede d'office (cout 0)" % id)
			var dm: DirectionalMecha = DirectionalMecha.new()
			dm.chassis = id
			add_child(dm)
			_ok(dm.has_baked_weapon() == (base == "vortex" or DirectionalMecha.new().chassis != "" and dm.has_baked_weapon()), "%s : ancres d'arme reprises de %s" % [id, base])
			var miss: Array = []
			for an in ["idle", "walk", "attack"]:
				for dd in dirs:
					if not ResourceLoader.exists("res://assets/mecha/%s_%s_%s.png" % [id, an, dd]):
						miss.append("%s_%s" % [an, dd])
			_ok(miss.is_empty(), "%s : planches idle/walk/attack x 8 directions" % id, "manquantes : %s" % str(miss))
			dm.queue_free()
	print("=== %s (%d echec(s)) ===" % ["OK" if _fail == 0 else "ECHEC", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
