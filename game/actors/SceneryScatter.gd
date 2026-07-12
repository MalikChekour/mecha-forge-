extends Node2D
class_name SceneryScatter
## Scatters large 3D-rendered LANDSCAPE formations (Blender/Cycles bakes) as background
## scenery. Uses grey rock / bright crystal / bare-wood forms that CONTRAST every biome floor
## (no camouflage). Non-colliding, drawn behind actors, with a soft ground shadow.

var biome_name: String = "tech"   # kept for compat; scenery is biome-agnostic (contrasting)

const KINDS: Array[String] = ["mesa", "crystal_cluster", "rock_cluster", "deadtree"]

func populate(count: int = 10) -> void:
	for i in count:
		var pos: Vector2 = Vector2(randf_range(-2200.0, 2200.0), randf_range(-2200.0, 2200.0))
		if pos.length() < 560.0:   # keep the spawn area clear
			continue
		_place(KINDS[randi() % KINDS.size()], pos)

func _place(kind: String, pos: Vector2) -> void:
	var v: int = 1 + (randi() % 2)
	var path: String = "res://assets/decor/d_%s_%d.png" % [kind, v]
	var tex: Texture2D = Tex.get_tex(path, Palette.STEEL_DK, 256)
	var th: float = maxf(1.0, float(tex.get_height()))
	var target: float = randf_range(300.0, 460.0)
	var sc: float = target / th
	var span: float = th * sc

	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.42)
	shadow.position = pos + Vector2(0.0, span * 0.30)
	shadow.scale = Vector2(span / 64.0 * 0.95, span / 64.0 * 0.4)
	shadow.z_index = -4
	add_child(shadow)

	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * sc
	s.flip_h = randf() < 0.5
	s.position = pos
	s.z_index = -3   # background scenery: behind actors/props, above the floor
	s.modulate = Palette.biome_tint(biome_name)   # painted into the biome
	add_child(s)

	if kind == "crystal_cluster":
		var glow := PointLight2D.new()
		glow.texture = Tex.glow(Palette.CYAN, 128)
		glow.color = Palette.CYAN
		glow.energy = 0.7
		glow.texture_scale = span / 128.0 * 2.4
		glow.position = pos
		add_child(glow)
