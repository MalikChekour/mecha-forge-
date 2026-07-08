extends Node2D
class_name PropScatter
## Scatters the baked decor sprites (crate/barrier/wreck) across the arena with
## soft blob shadows, flip + scale + tint variety. Static; drawn under the actors.

func populate(count: int = 34) -> void:
	var kinds: Array[String] = ["crate", "barrier", "wreck"]
	for i in count:
		var pos: Vector2 = Vector2(randf_range(-2050.0, 2050.0), randf_range(-2050.0, 2050.0))
		if pos.length() < 280.0:
			continue
		_place(kinds[randi() % kinds.size()], pos)

func _place(kind: String, pos: Vector2) -> void:
	var tex: Texture2D = Tex.get_tex("res://assets/decor/%s.png" % kind, Palette.STEEL_DK, 128)
	var th: float = maxf(1.0, float(tex.get_height()))
	var sc: float = randf_range(0.75, 1.25) * (140.0 / th)
	var span: float = th * sc

	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.5)
	shadow.position = pos + Vector2(0.0, span * 0.30)
	shadow.scale = Vector2(span / 64.0 * 1.15, span / 64.0 * 0.45)
	add_child(shadow)

	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2.ONE * sc
	s.flip_h = randf() < 0.5
	s.modulate = Color(1, 1, 1).lerp(Palette.STEEL, 0.12)
	add_child(s)
