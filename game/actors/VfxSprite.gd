extends Sprite2D
class_name VfxSprite
## One-shot animated VFX sprite driven by a horizontal spritesheet (baked on black -> ADDITIVE).
## Pooled by Game (spawn_vfx/reclaim_vfx): no queue_free in the hot loop. Position, rotation,
## scale and colour are set per spawn so one neutral sheet serves many contexts.

var _fps: float = 26.0
var _frames: int = 1
var _t: float = 0.0
var _frame: int = 0
var _playing: bool = false
var game: Node

func _ready() -> void:
	centered = true
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # black background adds nothing -> pure glow
	material = m
	visible = false
	set_process(false)

## sheet cell is 160px; `scl` scales that (e.g. 1.25 -> ~200px on screen). rot in radians.
## `stretch` permet d'ETIRER une planche sur un axe : c'est ce qui transforme une
## planche d'energie en RAYON de la longueur voulue, au lieu d'un trait dessine.
func play(tex: Texture2D, frames: int, fps: float, pos: Vector2, rot: float, scl: float, col: Color,
		stretch: Vector2 = Vector2.ONE) -> void:
	texture = tex
	hframes = frames
	vframes = 1
	_frames = frames
	frame = 0
	_frame = 0
	_t = 0.0
	_fps = fps
	global_position = pos
	rotation = rot
	scale = Vector2(scl, scl) * stretch
	modulate = col
	visible = true
	_playing = true
	set_process(true)

func _process(delta: float) -> void:
	if not _playing:
		return
	_t += delta
	var step: float = 1.0 / _fps
	while _t >= step:
		_t -= step
		_frame += 1
		if _frame >= _frames:
			_finish()
			return
	frame = _frame

func reset() -> void:
	_playing = false
	visible = false
	set_process(false)
	global_position = Vector2(1.0e7, 1.0e7)

func _finish() -> void:
	if game != null and game.has_method("reclaim_vfx"):
		game.reclaim_vfx(self)
	else:
		reset()
		queue_free()
