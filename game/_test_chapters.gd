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
	print("=== TEST INTEGRATION CAMPAGNE (18 chapitres au total) ===")

	_ok(GameScript.CHAPTERS.size() == 18, "CHAPTERS compte bien 18 entrees (9 historiques + 9 nouveaux)",
		"obtenu=%d" % GameScript.CHAPTERS.size())

	var all_new_biomes: Array = ["abyss", "ether", "titans", "orbit", "quantum", "ozone", "prism", "steampunk", "colosseum"]
	for i in GameScript.CHAPTERS.size():
		var ch: Dictionary = GameScript.CHAPTERS[i]
		var b: String = String(ch.get("biome", ""))
		_ok(GameScript.BIOME_MODS.has(b), "CHAPTERS[%d] ('%s') : le biome '%s' existe dans BIOME_MODS" % [i, String(ch.get("name","")), b])
		_ok(int(ch.get("diff", -1)) >= 0 and int(ch.get("diff", -1)) < 4,
			"CHAPTERS[%d] : diff dans la plage valide [0,3]" % i, "diff=%d" % int(ch.get("diff", -1)))
	for b in all_new_biomes:
		var found: bool = false
		for ch in GameScript.CHAPTERS:
			if String(ch.get("biome", "")) == b:
				found = true
		_ok(found, "le nouveau biome '%s' est bien un chapitre jouable" % b)

	# Deblocage en chaine : vérifie la formule et le mode DEBUG_UNLOCK_ALL
	if SaveManager.DEBUG_UNLOCK_ALL:
		_ok(SaveManager.chapter_unlocked(10), "DEBUG_UNLOCK_ALL actif : chapitre 10 accessible directement pour test")
		_ok(SaveManager.chapter_unlocked(18), "DEBUG_UNLOCK_ALL actif : chapitre 18 accessible directement pour test")
	else:
		SaveManager.data["chapters_cleared"] = 0
		_ok(SaveManager.chapter_unlocked(1), "chapitre 1 toujours ouvert au depart")
		_ok(not SaveManager.chapter_unlocked(10), "chapitre 10 (nouveau) verrouille tant que 1-9 pas battus")
		SaveManager.data["chapters_cleared"] = 9
		_ok(SaveManager.chapter_unlocked(10), "chapitre 10 s'ouvre bien apres avoir battu le 9")
		_ok(not SaveManager.chapter_unlocked(11), "chapitre 11 reste verrouille tant que le 10 n'est pas battu")
		SaveManager.data["chapters_cleared"] = 17
		_ok(SaveManager.chapter_unlocked(18), "chapitre 18 (Colisée Virtuel) s'ouvre apres le 17")
		SaveManager.data["chapters_cleared"] = 0   # reset pour ne pas polluer la sauvegarde locale

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)

