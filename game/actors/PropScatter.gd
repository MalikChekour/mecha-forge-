extends Node2D
class_name PropScatter

var game: Node

func populate(count: int = 34) -> void:
	var kinds: Array[String] = ["crate", "barrier", "wreck"]
	for i in count:
		var pos: Vector2 = Vector2(randf_range(-2050.0, 2050.0), randf_range(-2050.0, 2050.0))
		if pos.length() < 280.0:
			continue
		_place(kinds[randi() % kinds.size()], pos)

func _place(kind: String, pos: Vector2) -> void:
	var prop: Prop = Prop.new()
	prop.game = game
	prop.kind = kind
	prop.position = pos
	add_child(prop)

class Prop extends StaticBody2D:
	var game: Node
	var kind: String
	var hp: float
	var sprite: Sprite2D
	var shadow: Sprite2D

	func _ready() -> void:
		match kind:
			"crate":
				hp = 30.0
			"barrier":
				hp = 50.0
			"wreck":
				hp = 500.0
			_:
				hp = 30.0

		var tex: Texture2D = Tex.get_tex("res://assets/decor/%s.png" % kind, Palette.STEEL_DK, 128)
		var th: float = maxf(1.0, float(tex.get_height()))
		var sc: float = randf_range(0.75, 1.25) * (140.0 / th)
		var span: float = th * sc

		shadow = Sprite2D.new()
		shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.position = Vector2(0.0, span * 0.30)
		shadow.scale = Vector2(span / 64.0 * 1.15, span / 64.0 * 0.45)
		add_child(shadow)

		sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.scale = Vector2.ONE * sc
		sprite.flip_h = randf() < 0.5
		sprite.modulate = Color(1, 1, 1).lerp(Palette.STEEL, 0.12)
		add_child(sprite)

		var shape: Shape2D
		if kind == "crate":
			shape = RectangleShape2D.new()
			(shape as RectangleShape2D).size = Vector2(span, span)
		else:
			shape = CircleShape2D.new()
			(shape as CircleShape2D).radius = span * 0.5

		var collision := CollisionShape2D.new()
		collision.shape = shape
		add_child(collision)

		add_to_group("cover")
		collision_layer = 8
		collision_mask = 0

	func take_damage(amount: float) -> void:
		hp -= amount
		if hp <= 0:
			if game != null:
				if game.has_method("death_fx"):
					game.death_fx(global_position, 0)
				if game.has_method("spawn_scrap"):
					game.spawn_scrap(global_position, 2 + randi() % 3)
			call_deferred("queue_free")
		else:
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
			tween.tween_property(sprite, "modulate", Color(1, 1, 1).lerp(Palette.STEEL, 0.12), 0.15)
