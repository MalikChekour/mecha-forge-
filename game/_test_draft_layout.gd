extends Node
## Menu d'AMELIORATION (draft de niveau) : panneau centre et tout son contenu DEDANS, a plusieurs
## tailles d'ecran (14/10, patron : « le menu des niveaux n'est pas centre »).
##   godot --headless --path game res://_test_draft_layout.tscn

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r: Node = _find(c, cls)
		if r != null:
			return r
	return null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== TEST LAYOUT MENU D'AMELIORATION ===")
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	for i in 5:
		await get_tree().process_frame
	var cards: Array = [
		{"name": "Autocanon  Niv 2  +cadence de tir", "evo": false},
		{"name": "Blindage renforce", "evo": false},
		{"name": "EVOLUTION : Railgun surcharge", "evo": true},
	]
	for sz in [Vector2i(1280, 720), Vector2i(1036, 558), Vector2i(800, 360), Vector2i(390, 844), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1080, 2340)]:
		get_window().size = sz
		for i in 3:
			await get_tree().process_frame
		var hud: Node = game.hud
		hud.show_draft(cards, 2, 2)
		for i in 4:
			await get_tree().process_frame
		var vp: Rect2 = game.get_viewport().get_visible_rect()
		var panel: Control = _find(hud._draft_root, "Panel") as Control
		if panel == null:
			_ok(false, "%s : panneau present" % str(sz))
			continue
		var pr: Rect2 = panel.get_global_rect()
		var ml: float = pr.position.x - vp.position.x
		var mr: float = vp.end.x - pr.end.x
		var mt: float = pr.position.y - vp.position.y
		var mb: float = vp.end.y - pr.end.y
		_ok(absf(ml - mr) <= 2.0, "%s : panneau centre horizontalement" % str(sz), "g=%.1f d=%.1f" % [ml, mr])
		_ok(absf(mt - mb) <= 2.0, "%s : panneau centre verticalement" % str(sz), "h=%.1f b=%.1f" % [mt, mb])
		# contenu : chaque bouton du draft entierement dans le panneau
		var out: int = 0
		for b in hud._card_btns:
			if not pr.encloses((b as Control).get_global_rect()):
				out += 1
		_ok(out == 0, "%s : les cartes sont dans le panneau" % str(sz), "hors=%d panneau=%s" % [out, str(pr)])
		hud._draft_root.visible = false
	print("=== %s ===" % ("PASS" if _fail == 0 else "%d echec(s)" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)
