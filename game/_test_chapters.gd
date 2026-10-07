extends Node
## Verifie l'integration campagne des 4 biomes "15 maps" (03/10, demande du patron) : CHAPTERS
## passe de 5 a 9 entrees, le deblocage en chaine (SaveManager) doit rester generique (pas de "5"
## en dur), et chaque chapitre doit pointer un biome qui existe vraiment.
##   godot --headless --path game res://_test_chapters.tscn

const GameScript = preload("res://scenes/Game.gd")

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST INTEGRATION CAMPAGNE (4 nouveaux chapitres) ===")

	_ok(GameScript.CHAPTERS.size() == 9, "CHAPTERS compte bien 9 entrees (5 historiques + 4 nouvelles)",
		"obtenu=%d" % GameScript.CHAPTERS.size())

	var new_biomes: Array = ["cryo", "reacteur", "ruche", "citadelle"]
	for i in GameScript.CHAPTERS.size():
		var ch: Dictionary = GameScript.CHAPTERS[i]
		var b: String = String(ch.get("biome", ""))
		_ok(GameScript.BIOME_MODS.has(b), "CHAPTERS[%d] ('%s') : le biome '%s' existe dans BIOME_MODS" % [i, String(ch.get("name","")), b])
		_ok(int(ch.get("diff", -1)) >= 0 and int(ch.get("diff", -1)) < 4,
			"CHAPTERS[%d] : diff dans la plage valide [0,3]" % i, "diff=%d" % int(ch.get("diff", -1)))
	for b in new_biomes:
		var found: bool = false
		for ch in GameScript.CHAPTERS:
			if String(ch.get("biome", "")) == b:
				found = true
		_ok(found, "le biome '%s' (plan 15 maps) est bien un chapitre jouable" % b)

	# Deblocage en chaine : doit rester un simple compteur, fonctionnel au-dela de 5 (pas de "5" en
	# dur dans SaveManager - verifie fonctionnellement plutot qu'en lisant le fichier).
	SaveManager.data["chapters_cleared"] = 0
	_ok(SaveManager.chapter_unlocked(1), "chapitre 1 toujours ouvert au depart")
	_ok(not SaveManager.chapter_unlocked(6), "chapitre 6 (nouveau) verrouille tant que 1-5 pas battus")
	SaveManager.data["chapters_cleared"] = 5
	_ok(SaveManager.chapter_unlocked(6), "chapitre 6 s'ouvre bien apres avoir battu le 5")
	_ok(not SaveManager.chapter_unlocked(7), "chapitre 7 reste verrouille tant que le 6 n'est pas battu")
	SaveManager.data["chapters_cleared"] = 8
	_ok(SaveManager.chapter_unlocked(9), "chapitre 9 (dernier, Forge Finale) s'ouvre apres le 8")
	SaveManager.data["chapters_cleared"] = 0   # reset pour ne pas polluer la sauvegarde locale

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
