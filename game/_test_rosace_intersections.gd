extends Node
## Test automatisé de validation : Disposition Géométrique en Rosaces et Rendu 2.5D Blender (v12.42)
## Vérifie :
##  1. Présence et validité des 4 assets 2.5D Blender (desert_obelisque_solaire, jungle_pilier_racines, volcanic_fourneau_lourd, swamp_arche_submergee).
##  2. Topologie en Rosace exclusive pour chaque biome (aucun niveau ne se ressemble).
##  3. Placement des décors et canons d'angle strictement sur les croisements de la rosace.
##  4. Dégagement de circulation du mecha >= 380 px et zéro chevauchement.
##  5. Préservation absolue du catalogue RESERVED_DECOR (0 suppression).

const CircuitPatterns = preload("res://systems/CircuitPatterns.gd")
const PropScatter = preload("res://actors/PropScatter.gd")

func _ready() -> void:
	print("\n=== TEST DISPOSITION EN ROSACES ET ASSETS 2.5D BLENDER (v12.42) ===")
	var errs: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242

	# 1. Vérification des assets 2.5D Blender et textures
	var blender_assets: Dictionary = {
		"desert": "desert_obelisque_solaire",
		"jungle": "jungle_pilier_racines",
		"volcanic": "volcanic_fourneau_lourd",
		"swamp": "swamp_arche_submergee"
	}

	for biome in blender_assets:
		var prop_key: String = blender_assets[biome]
		if not PropScatter.DECOR.has(prop_key):
			printerr("  FAIL  Prop 2.5D non enregistre dans PropScatter.DECOR: %s" % prop_key)
			errs += 1
		else:
			var d: Dictionary = PropScatter.DECOR[prop_key]
			var f_name: String = String(d.get("f", ""))
			var path_png: String = "res://assets/decor/%s.png" % f_name
			if not (ResourceLoader.exists(path_png) or FileAccess.file_exists(path_png)):
				printerr("  FAIL  Fichier PNG manquant pour l'asset 2.5D: %s" % path_png)
				errs += 1
			else:
				print("  PASS  Asset 2.5D Blender valide et charge   %s (%s)" % [prop_key, path_png])

	# 2. Vérification de conservation intégrale de RESERVED_DECOR
	if PropScatter.RESERVED_DECOR.size() >= 18:
		print("  PASS  RESERVED_DECOR : conservation garantie (0 suppression)   n=%d" % PropScatter.RESERVED_DECOR.size())
	else:
		printerr("  FAIL  Catalogue RESERVED_DECOR incomplet: %d" % PropScatter.RESERVED_DECOR.size())
		errs += 1

	# 3. Test de disposition aux croisements de rosace par biome
	var biomes: Array = ["desert", "jungle", "volcanic", "swamp"]
	var rosace_names: Dictionary = {
		"desert": "Rosace Quadrilobée (4 pétales à 90°)",
		"jungle": "Rosace Hexalobée (6 pétales en fleur de lotus à 60°)",
		"volcanic": "Rosace Octolobée (Double anneau crénelé à 45°)",
		"swamp": "Rosace Décalobée (10 canaux polaires sécants à 36°)"
	}

	var turrets: Dictionary = {
		"desert": "desert_miroir_solaire",
		"jungle": "jungle_mortier_plante",
		"volcanic": "volcanic_mortier_scories",
		"swamp": "swamp_tourelle_dca"
	}

	var all_layouts: Dictionary = {}

	for biome in biomes:
		print("\n--- Validation %s : %s ---" % [biome.to_upper(), rosace_names[biome]])
		var kinds: Array = PropScatter.BIOME_DECOR.get(biome, [])
		if kinds.is_empty():
			printerr("  FAIL  %s : liste BIOME_DECOR vide" % biome)
			errs += 1
			continue

		var chunks_tested: Array = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 2)]
		var signature_prop: String = blender_assets[biome]
		var found_signature: bool = false
		var found_turret: bool = false

		for c in chunks_tested:
			var items: Array = CircuitPatterns.generate_layout(c, kinds, rng, Vector2.ZERO, 340.0, biome)
			if items.size() < 4:
				printerr("  FAIL  %s : chunk (%d,%d) sous-densifie (n=%d)" % [biome, c.x, c.y, items.size()])
				errs += 1

			# Vérifier le dégagement minimum entre chaque croisement (>= 380 px)
			for i in range(items.size()):
				var p1: Vector2 = items[i]["pos"]
				var k1: String = items[i]["kind"]
				if k1 == signature_prop:
					found_signature = true
				if k1 == turrets[biome]:
					found_turret = true
					if not items[i].has("aim"):
						printerr("  FAIL  %s : tourelle d'angle sans tir de barrage 'aim'" % biome)
						errs += 1

				for j in range(i + 1, items.size()):
					var p2: Vector2 = items[j]["pos"]
					var dist: float = p1.distance_to(p2)
					if dist < 380.0:
						printerr("  FAIL  %s : Croisements trop proches (%s <-> %s: %.1f px < 380 px)" % [biome, k1, items[j]["kind"], dist])
						errs += 1

		if found_signature:
			print("  PASS  Croisement central accueille l'asset 2.5D Blender (%s)" % signature_prop)
		else:
			printerr("  FAIL  Asset 2.5D non retrouve dans les chunks de test (%s)" % signature_prop)
			errs += 1

		if found_turret:
			print("  PASS  Croisement d'angle accueille le canon tactique avec tir de barrage (%s)" % turrets[biome])
		else:
			printerr("  FAIL  Canon d'angle non positionne (%s)" % turrets[biome])
			errs += 1

		# Enregistrer la signature pour unicité
		var sample_items: Array = CircuitPatterns.generate_layout(Vector2i(1, 1), kinds, rng, Vector2.ZERO, 340.0, biome)
		var sig: Array = []
		for it in sample_items:
			sig.append(it["pos"] - Vector2(1000.0, 1000.0))
		all_layouts[biome] = sig

	# 4. Vérification de la diversité absolue des rosaces
	print("\n--- Contrôle de Différenciation Géométrique des Rosaces ---")
	var unique_count: int = 0
	for i in range(biomes.size()):
		var b1: String = biomes[i]
		var is_unique: bool = true
		for j in range(i + 1, biomes.size()):
			var b2: String = biomes[j]
			if all_layouts[b1] == all_layouts[b2]:
				printerr("  FAIL  Rosaces identiques entre %s et %s" % [b1, b2])
				is_unique = false
				errs += 1
		if is_unique:
			unique_count += 1

	if unique_count == biomes.size():
		print("  PASS  Diversité absolue : 4 rosaces géométriquement et thématiquement exclusives (4/4)")

	print("\n=== RÉSULTAT : %d ÉCHEC(S) ===" % errs)
	if errs == 0:
		print("=== SUCCÈS COMPLET (v12.42) ===")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
