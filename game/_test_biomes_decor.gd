extends Node
## Chaque biome se peuple et se borde sans erreur (listes vides comprises), et n'emploie que ses
## decors propres (14/10 : plus aucun decor partage d'un niveau a l'autre).
##   godot --headless --path game res://_test_biomes_decor.tscn

class StubGame extends Node:
	var enemy_layer: Node2D
	var arena: Rect2 = Rect2(-6000, -6000, 12000, 12000)
	var cover_list: Array = []
	func _init() -> void:
		enemy_layer = Node2D.new()
		add_child(enemy_layer)
	func spawn_ground_zone(_p, _r, _d, _dmg, _c = Color.WHITE, _k = "decor_hit") -> void: pass
	func spawn_vfx(_k, _p, _r = 0.0, _s = 1.0, _c = Color.WHITE) -> void: pass
	func impact_fx(_p, _c, _k, _d = Vector2.ZERO, _s = 1.0) -> void: pass

var _fail: int = 0
func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST DECOR PAR BIOME ===")
	GameState.reset()
	for b in PropScatter.BIOME_DECOR:
		var g: StubGame = StubGame.new()
		add_child(g)
		var ps: PropScatter = PropScatter.new()
		ps.game = g; ps.biome = b; ps.arena_half = 5000.0
		add_child(ps)
		ps.populate()
		ps.build_border(5000.0)
		var kinds: Dictionary = {}
		var n: int = 0
		for c in ps._chunks:
			for p in ps._chunks[c]:
				if is_instance_valid(p):
					kinds[(p as PropScatter.Prop).kind] = true
					n += 1
		var own: Array = PropScatter.BIOME_DECOR[b].duplicate()
		for k in PropScatter.COMPANION.values():
			own.append(k[0])
		var hors: Array = []
		for k in kinds:
			if not own.has(k):
				hors.append(k)
		var vide: bool = PropScatter.BIOME_DECOR[b].is_empty()
		_ok(hors.is_empty() and (n == 0 if vide else n > 0), "%s : %d decors, uniquement les siens" % [b, n], "hors=%s" % str(hors))
		ps.queue_free()
		g.queue_free()
		await get_tree().process_frame
	print("=== %s (%d echec(s)) ===" % ["OK" if _fail == 0 else "ECHEC", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
