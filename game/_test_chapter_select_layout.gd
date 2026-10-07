extends Node
## Ecran SELECTION DE CHAPITRE (05/10) : le patron restait BLOQUE (RETOUR hors ecran avec 9
## chapitres sur un navigateur 1036x558). Verifie, a plusieurs tailles d'ecran, que RETOUR est
## entierement visible et que la liste des chapitres tient dans un ScrollContainer.
##   godot --headless --path game res://_test_chapter_select_layout.tscn

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _find_button(n: Node, txt: String) -> Button:
	if n is Button and (n as Button).text == txt:
		return n
	for c in n.get_children():
		var r: Button = _find_button(c, txt)
		if r != null:
			return r
	return null

func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for c in n.get_children():
		var r: ScrollContainer = _find_scroll(c)
		if r != null:
			return r
	return null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== TEST LAYOUT SELECTION DE CHAPITRE ===")
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	for i in 5:
		await get_tree().process_frame
	for sz in [Vector2i(1036, 558), Vector2i(1280, 720), Vector2i(800, 360), Vector2i(390, 844)]:
		get_window().size = sz
		for i in 3:
			await get_tree().process_frame
		var before: int = game.get_child_count()
		game._show_chapter_select()
		for i in 4:
			await get_tree().process_frame
		var cl: Node = game.get_child(game.get_child_count() - 1)
		var vp: Rect2 = game.get_viewport().get_visible_rect()
		var back: Button = _find_button(cl, "RETOUR")
		var sc: ScrollContainer = _find_scroll(cl)
		_ok(back != null, "%s : bouton RETOUR present" % str(sz))
		_ok(sc != null, "%s : ScrollContainer present" % str(sz))
		if back != null:
			var r: Rect2 = back.get_global_rect()
			_ok(vp.encloses(r), "%s : RETOUR entierement visible" % str(sz), "vp=%s retour=%s" % [str(vp), str(r)])
			_ok(not back.is_ancestor_of(sc) and not sc.is_ancestor_of(back), "%s : RETOUR hors du defilement" % str(sz))
		if sc != null:
			var sr: Rect2 = sc.get_global_rect()
			_ok(vp.encloses(sr), "%s : zone de defilement dans l'ecran" % str(sz), "scroll=%s contenu_h=%.0f" % [str(sr), sc.get_child(0).size.y])
		cl.free()
		get_tree().paused = false
	print("=== %s ===" % ("PASS" if _fail == 0 else "%d echec(s)" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)
