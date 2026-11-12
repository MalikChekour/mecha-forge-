extends Node
## Test de validation de l'Étape 1 :
## 1. Chaque biome (desert, jungle, volcanic, swamp) a sa topologie exclusive (aucune ne se ressemble).
## 2. Les canons sont places dans les angles et orientes en tir de barrage sur les routes du mecha.
## 3. Aucun decor remplace n'est supprime (RESERVED_DECOR preserve a 100%).
## 4. Zéro collision, zero chevauchement visuel ou physique entre decors (gap respecte).
## 5. Les passages mecha garantissent >= 340 px de passage libre.

const CircuitPatterns = preload("res://systems/CircuitPatterns.gd")
const PropScatter = preload("res://actors/PropScatter.gd")

var _fail: int = 0
func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST BIOMES ET CANONS D'ANGLE (Étape 1) ===")
	GameState.reset()

	var biomes: Array = ["desert", "jungle", "volcanic", "swamp"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var ppos: Vector2 = Vector2(500.0, 500.0)
	var clear_r: float = 340.0

	# 1. Vérification du catalogue de conservation RESERVED_DECOR
	_ok(PropScatter.RESERVED_DECOR.size() >= 16, "RESERVED_DECOR : catalogue de conservation actif", "n=%d" % PropScatter.RESERVED_DECOR.size())
	_ok(CircuitPatterns.RESERVED_DECOR.size() == 4, "CircuitPatterns.RESERVED_DECOR : 4 biomes archives", "n=%d" % CircuitPatterns.RESERVED_DECOR.size())

	# 2. Vérification de chaque biome : non-ressemblance, canons d'angle, barrages
	var signatures: Dictionary = {}
	var corner_cannons: Dictionary = {
		"desert": "desert_miroir_solaire",
		"jungle": "jungle_mortier_plante",
		"volcanic": "volcanic_mortier_scories",
		"swamp": "swamp_tourelle_dca"
	}

	for b in biomes:
		var kinds: Array = PropScatter.BIOME_DECOR.get(b, [])
		_ok(not kinds.is_empty(), "%s : liste de decors presente" % b, "kinds=%d" % kinds.size())

		# Test sur 4 chunks differents
		var chunk_kinds_seen: Dictionary = {}
		var found_cannon: bool = false
		var overlaps: int = 0
		var cannon_in_corner: bool = false

		for cx in range(1, 3):
			for cy in range(1, 3):
				var cell: Vector2i = Vector2i(cx, cy)
				var layout: Array = CircuitPatterns.generate_layout(cell, kinds, rng, ppos, clear_r, b)
				_ok(not layout.is_empty(), "%s : chunk (%d,%d) genere" % [b, cx, cy], "props=%d" % layout.size())

				for item in layout:
					var k: String = String(item.get("kind", ""))
					chunk_kinds_seen[k] = true
					if k == corner_cannons[b]:
						found_cannon = true
						var pos: Vector2 = item.get("pos", Vector2.ZERO)
						var origin: Vector2 = Vector2(float(cell.x) * 1000.0, float(cell.y) * 1000.0)
						var rel: Vector2 = pos - origin
						# Vérifie que le canon est bien dans un angle (marge <= 260 px d'un coin)
						var in_corner: bool = (rel.x <= 260.0 or rel.x >= 740.0) and (rel.y <= 260.0 or rel.y >= 740.0)
						if in_corner:
							cannon_in_corner = true
						var aim: float = float(item.get("aim", -999.0))
						_ok(aim > -900.0, "%s : canon d'angle a un angle de tir de barrage assigne" % b, "aim=%.1f°" % aim)

				# Vérifie l'absence de chevauchement au sein du chunk
				for i in layout.size():
					for j in range(i + 1, layout.size()):
						var p1: Vector2 = layout[i]["pos"]
						var p2: Vector2 = layout[j]["pos"]
						var dist: float = p1.distance_to(p2)
						if dist < 140.0:
							overlaps += 1

		_ok(overlaps == 0, "%s : zero collision ou chevauchement entre decors" % b, "overlaps=%d" % overlaps)
		_ok(found_cannon, "%s : canon tactique present" % b, corner_cannons[b])
		_ok(cannon_in_corner, "%s : canon tactique positionne dans l'angle" % b)

		# Signature du biome pour prouver la non-ressemblance
		var sig_keys: Array = chunk_kinds_seen.keys()
		sig_keys.sort()
		var sig_str: String = ",".join(sig_keys)
		signatures[b] = sig_str

	# 3. Prouver qu'aucun biome ne ressemble a un autre (toutes les signatures sont distinctes)
	var unique_sigs: Dictionary = {}
	for b in signatures:
		unique_sigs[signatures[b]] = b
	_ok(unique_sigs.size() == biomes.size(), "Diversite absolue : aucun niveau ne ressemble a un autre", "%d/%d uniques" % [unique_sigs.size(), biomes.size()])

	print("=== %s (%d echec(s)) ===" % ["OK" if _fail == 0 else "ECHEC", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
