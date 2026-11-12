extends Node
## Test de validation : ZERO collision physique ET ZERO chevauchement visuel entre décors dans TechMaze

const TechMaze = preload("res://systems/TechMaze.gd")

class DummyGame extends Node2D:
	var cover_list: Array = []

func _ready() -> void:
	print("=== VERIFICATION ABSOLUE DE NON-COLLISION PHYSIQUE ET VISUELLE ===")
	var dummy_game = DummyGame.new()
	var maze: TechMaze = TechMaze.new()
	maze.game = dummy_game
	add_child(maze)

	var colliders = maze.maze_colliders
	print("Total colliders a verifier : ", colliders.size())

	var physics_overlaps: int = 0
	var visual_overlaps: int = 0

	for i in range(colliders.size()):
		var c1 = colliders[i]
		var r1 = _get_collider_rect(c1)
		var v1 = _get_visual_rect(c1)

		for j in range(i + 1, colliders.size()):
			var c2 = colliders[j]
			var r2 = _get_collider_rect(c2)
			var v2 = _get_visual_rect(c2)

			# 1. Test physique (tolérance de 2px)
			if r1.grow(-2.0).intersects(r2.grow(-2.0)):
				physics_overlaps += 1
				printerr("  [COLLISION PHYSIQUE #%d] entre %s (%s) et %s (%s)" % [
					physics_overlaps, c1.name, str(c1.global_position), c2.name, str(c2.global_position)
				])

			# 2. Test visuel des sprites de décor principaux (tolérance de 2px)
			if v1.grow(-2.0).intersects(v2.grow(-2.0)):
				visual_overlaps += 1
				printerr("  [CHEVAUCHEMENT VISUEL #%d] entre:\n    A: %s (pos=%s, visual_box=%s)\n    B: %s (pos=%s, visual_box=%s)" % [
					visual_overlaps, c1.name, str(c1.global_position), str(v1),
					c2.name, str(c2.global_position), str(v2)
				])

	print("Bilan :")
	print("  - Collisions physiques : ", physics_overlaps)
	print("  - Chevauchements visuels : ", visual_overlaps)

	if physics_overlaps == 0 and visual_overlaps == 0:
		print("  [SUCCES TOTAL] ZERO collision physique et ZERO chevauchement visuel !")
		get_tree().quit(0)
	else:
		printerr("  [ECHEC] Des collisions ou chevauchements subsistent !")
		get_tree().quit(1)

func _get_collider_rect(node: Node2D) -> Rect2:
	var pos = node.global_position
	for child in node.get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			var offset = child.position
			if shape is RectangleShape2D:
				var sz = shape.size
				return Rect2(pos + offset - sz * 0.5, sz)
			elif shape is CircleShape2D:
				var r = shape.radius
				return Rect2(pos + offset - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
	return Rect2(pos - Vector2(50, 50), Vector2(100, 100))

func _get_visual_rect(node: Node2D) -> Rect2:
	var pos = node.global_position
	for child in node.get_children():
		if child is Sprite2D and child.texture != null:
			# On ne teste que les sprites principaux de décor (pas les ombres z_index=-1 ni les glows additifs)
			if child.z_index >= 0 and child.material == null:
				var sz = child.texture.get_size() * child.scale.abs()
				var offset = child.position
				return Rect2(pos + offset - sz * 0.5, sz)
	return _get_collider_rect(node)
