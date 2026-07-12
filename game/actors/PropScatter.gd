extends Node2D
class_name PropScatter

var game: Node
var biome: String = "tech"            # set by Game -> decor is painted to harmonise

const _BONUS_RATE: float = 0.25       # fraction of destructible props holding a bonus cache

func populate(count: int = 34) -> void:
	# large cover props (collidable, destructible), painted into the biome (harmonised).
	var kinds: Array[String] = ["boulder", "rock_cluster", "container", "pillar", "pylon", "debris"]
	for i in count:
		var pos: Vector2 = Vector2(randf_range(-2050.0, 2050.0), randf_range(-2050.0, 2050.0))
		if pos.length() < 280.0:
			continue
		_place(kinds[randi() % kinds.size()], pos, false, randf() < _BONUS_RATE)
	# ambient detail scatter (small, NO collision) for a richer ground
	var detail: Array[String] = ["boulder", "crystal", "debris"]
	for i in count * 3:
		var dp: Vector2 = Vector2(randf_range(-2100.0, 2100.0), randf_range(-2100.0, 2100.0))
		if dp.length() < 220.0:
			continue
		_place(detail[randi() % detail.size()], dp, true)

func _place(kind: String, pos: Vector2, ambient: bool = false, bonus: bool = false) -> void:
	var prop: Prop = Prop.new()
	prop.game = game
	prop.kind = kind
	prop.position = pos
	prop.ambient = ambient
	prop.tint = Palette.biome_tint(biome)
	prop.has_bonus = bonus
	add_child(prop)

class Prop extends StaticBody2D:
	var game: Node
	var kind: String
	var ambient: bool = false
	var hp: float
	var sprite: Sprite2D
	var shadow: Sprite2D
	var tint: Color = Color.WHITE     # biome tint (painted decor)
	var has_bonus: bool = false       # destroys into a bonus cache

	func _ready() -> void:
		match kind:
			"boulder":
				hp = 120.0
			"rock_cluster":
				hp = 160.0
			"container":
				hp = 40.0
			"pillar":
				hp = 200.0
			"pylon":
				hp = 90.0
			"debris":
				hp = 25.0
			"crystal":
				hp = 40.0
			_:
				hp = 60.0

		var variant: int = 1 + (randi() % 2)
		var tex: Texture2D = Tex.get_tex("res://assets/decor/d_%s_%d.png" % [kind, variant], Palette.STEEL_DK, 128)
		var th: float = maxf(1.0, float(tex.get_height()))
		var base_h: float = 58.0 if ambient else 150.0
		var sc: float = randf_range(0.7, 1.3) * (base_h / th)
		var span: float = th * sc

		shadow = Sprite2D.new()
		shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
		shadow.modulate = Color(0, 0, 0, 0.4 if ambient else 0.5)
		shadow.position = Vector2(0.0, span * 0.30)
		shadow.scale = Vector2(span / 64.0 * 1.15, span / 64.0 * 0.45)
		shadow.z_index = -2
		add_child(shadow)

		sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.scale = Vector2.ONE * sc
		sprite.flip_h = randf() < 0.5
		sprite.modulate = tint            # painted into the biome
		add_child(sprite)

		# crystals softly glow -> adds 3D depth/ambiance to the ground
		if kind == "crystal" or kind == "crystal_cluster":
			var glow := PointLight2D.new()
			glow.texture = Tex.glow(Palette.CYAN, 128)
			glow.color = Palette.CYAN
			glow.energy = 0.5 if ambient else 0.9
			glow.texture_scale = span / 128.0 * (2.2 if ambient else 3.0)
			add_child(glow)

		# bonus caches read as special: a warm gold glow so the player knows to break them
		if has_bonus and not ambient:
			var bl := PointLight2D.new()
			bl.texture = Tex.glow(Palette.BONUS, 128)
			bl.color = Palette.BONUS
			bl.energy = 1.1
			bl.texture_scale = span / 128.0 * 2.6
			add_child(bl)

		if ambient:
			z_index = -1   # small ground details: behind actors, no collision
			return

		var shape: Shape2D
		if kind == "container":
			shape = RectangleShape2D.new()
			(shape as RectangleShape2D).size = Vector2(span * 0.8, span * 0.8)
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
				if has_bonus and game.has_method("spawn_bonus"):
					game.spawn_bonus(global_position)     # the reward for breaking a cache
				elif game.has_method("spawn_scrap"):
					game.spawn_scrap(global_position, 2 + randi() % 3)
			call_deferred("queue_free")
		else:
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
			tween.tween_property(sprite, "modulate", tint, 0.15)
