extends Node2D
## Vitrine VFX (04/10 tour 2) : declenche les 6 recettes FxKit + 2 telegraphes GroundZone en
## grille, sur un sol sombre, pour juger le rendu hors partie. Non utilise par le jeu.
##   godot --path game res://_vfx_showcase.tscn --write-movie out.png --fixed-fps 30 --quit-after 90

const FxKit = preload("res://scenes/FxKit.gd")

var fx_layer: Node2D
var enemy_layer: Node2D
var _headless: bool = false
var _vfx_pool: Array = []
var _t: float = 0.0
var _fired: int = 0

const VFX_DEF: Dictionary = {
	"aaa_impact":    {"frames": 28, "fps": 72},
	"aaa_explosion": {"frames": 30, "fps": 58},
	"aaa_aoe":       {"frames": 28, "fps": 54},
	"dp_blast":      {"frames": 24, "fps": 30},
}

func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.16, 0.17, 0.19)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	# damier discret pour juger traces au sol / fumee sur un fond texture
	for y in 9:
		for x in 16:
			if (x + y) % 2 == 0:
				var c: ColorRect = ColorRect.new()
				c.color = Color(0.2, 0.21, 0.23)
				c.position = Vector2(x * 80, y * 80)
				c.size = Vector2(80, 80)
				add_child(c)
	enemy_layer = Node2D.new()
	add_child(enemy_layer)
	fx_layer = Node2D.new()
	fx_layer.z_index = 40
	add_child(fx_layer)
	Tex.spark_tex(); Tex.puff_tex(); Tex.shard_tex(); Tex.shock_tex(); Tex.flare_tex()
	Tex.disc_tex(); Tex.hazard_ring_tex(); Tex.scorch_tex()

func spawn_vfx(id: String, pos: Vector2, rot: float = 0.0, scl: float = 1.0, col: Color = Color.WHITE,
		stretch: Vector2 = Vector2.ONE) -> void:
	var d: Dictionary = VFX_DEF.get(id, {})
	var p: String = "res://assets/vfx/%s.png" % id
	if d.is_empty() or not ResourceLoader.exists(p):
		return
	var v: VfxSprite = VfxSprite.new()
	fx_layer.add_child(v)
	v.play(load(p), int(d["frames"]), float(d["fps"]), pos, rot, scl, col, stretch)

func reclaim_vfx(v: VfxSprite) -> void:
	v.queue_free()

func _process(delta: float) -> void:
	_t += delta
	if _fired == 0 and _t > 0.05:
		_fired = 1
		var gz: GroundZone = GroundZone.new()
		gz.radius = 110.0; gz.delay = 3.0; gz.damage = 0.0; gz.color = Color(1.0, 0.35, 0.1)
		gz.fx_kind = "surchauffe_sol"
		add_child(gz)
		gz.global_position = Vector2(1100, 560)
		var gl: GroundZone = GroundZone.new()
		gl.shape = "line"; gl.radius = 28.0; gl.delay = 3.0; gl.damage = 0.0
		gl.color = Color(1.0, 0.6, 0.15); gl.line_from = Vector2(-150, 0); gl.line_to = Vector2(150, 0)
		add_child(gl)
		gl.global_position = Vector2(1100, 330)
	if _fired == 1 and _t > 0.5:
		_fired = 2
		FxKit.recipe_fire(self, Vector2(200, 200), Color(1.0, 0.5, 0.15), 1.2)
		FxKit.recipe_ice(self, Vector2(520, 200), Color(0.6, 0.85, 1.0), 1.1)
		FxKit.recipe_energy(self, Vector2(840, 200), Color(0.55, 0.75, 1.0), 1.2)
		FxKit.recipe_bio(self, Vector2(200, 520), Color(0.55, 1.0, 0.35), 1.1)
		FxKit.recipe_wind(self, Vector2(520, 520), Color(0.7, 0.9, 1.0), 1.2)
		FxKit.recipe_kinetic(self, Vector2(840, 520), Color(1.0, 0.85, 0.3), 1.1)
