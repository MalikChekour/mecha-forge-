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

func _find_label(n: Node, txt: String) -> Label:
	if n is Label and (n as Label).text == txt:
		return n
	for c in n.get_children():
		var r: Label = _find_label(c, txt)
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
	for sz in [Vector2i(1036, 558), Vector2i(1280, 720), Vector2i(800, 360), Vector2i(390, 844), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1080, 2340), Vector2i(2560, 1440)]:
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
		# CENTRAGE (14/10, patron : « le menu des niveaux n'est pas centre ») : marges gauche/droite
		# du bloc visible (zone de defilement + RETOUR) egales, et centre vertical du contenu proche
		# de celui de l'ecran.
		if sc != null and back != null:
			var sr2: Rect2 = sc.get_global_rect()
			var ml: float = sr2.position.x - vp.position.x
			var mr: float = vp.end.x - sr2.end.x
			_ok(absf(ml - mr) <= 2.0, "%s : liste centree horizontalement" % str(sz), "marge_g=%.1f marge_d=%.1f" % [ml, mr])
			var bl: float = back.get_global_rect().position.x - vp.position.x
			var br: float = vp.end.x - back.get_global_rect().end.x
			_ok(absf(bl - br) <= 2.0, "%s : RETOUR centre horizontalement" % str(sz), "g=%.1f d=%.1f" % [bl, br])
			var top_m: float = sr2.position.y - vp.position.y
			var bot_m: float = vp.end.y - back.get_global_rect().end.y
			print("      %s vertical : haut(liste)=%.0f bas(retour)=%.0f  vp=%s sc=%s back=%s" % [str(sz), top_m, bot_m, str(vp), str(sr2), str(back.get_global_rect())])
			# Si tout tient sans defilement, le BLOC (titre -> RETOUR) doit etre centre verticalement.
			var title_l: Label = _find_label(cl, "CHOISIS UN CHAPITRE")
			var content_h2: float = sc.get_child(0).size.y
			if title_l != null and content_h2 <= sc.size.y + 1.0:
				var tm: float = title_l.get_global_rect().position.y - vp.position.y
				var bm: float = vp.end.y - back.get_global_rect().end.y
				_ok(absf(tm - bm) <= 6.0, "%s : bloc centre verticalement (tout tient)" % str(sz), "haut=%.1f bas=%.1f" % [tm, bm])
		if sc != null:
			var sr: Rect2 = sc.get_global_rect()
			_ok(vp.encloses(sr), "%s : zone de defilement dans l'ecran" % str(sz), "scroll=%s contenu_h=%.0f" % [str(sr), sc.get_child(0).size.y])
		cl.free()
		get_tree().paused = false
	print("=== %s ===" % ("PASS" if _fail == 0 else "%d echec(s)" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)
