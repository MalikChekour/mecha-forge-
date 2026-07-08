extends Node2D
class_name DirectionalMecha
## Directional, animated mecha rendered from baked 4-direction Meshy spritesheets:
##   res://assets/mecha/<chassis>_<anim>_<dir>.png   (8 frames horizontal each)
## dir in {front, back, left, right}. Falls back to the single-direction sheet
## (<chassis>_<anim>.png) then to a placeholder, so missing art never crashes.
##
## Used for the player (and can back animated enemies too). Replaces the procedural
## primitive rig now that we have real textured, rigged, 4-dir Meshy sprites.

signal anim_finished(anim: String)

@export var chassis: String = "vanguard"
@export var display_height: float = 150.0
@export var frame_count: int = 8

const LOOP: Dictionary = {"idle": true, "walk": true, "attack": false, "hit": false, "die": false}
const FPS: Dictionary = {"idle": 6.0, "walk": 12.0, "attack": 16.0, "hit": 12.0, "die": 10.0}

var _spr: Sprite2D
var _cache: Dictionary = {}          # "anim_dir" -> Texture2D
var _anim: String = "idle"
var _dir: String = "front"
var _t: float = 0.0
var _frame: int = 0
var _oneshot: bool = false

func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.centered = true
	_spr.hframes = frame_count
	add_child(_spr)
	_apply()

func _tex(anim: String, dir: String) -> Texture2D:
	var key: String = "%s_%s" % [anim, dir]
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	var candidates: Array[String] = [
		"res://assets/mecha/%s_%s_%s.png" % [chassis, anim, dir],
		"res://assets/mecha/%s_%s.png" % [chassis, anim],
		"res://assets/mecha/%s.png" % chassis,
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			var r: Variant = load(p)
			if r is Texture2D:
				t = r
				break
	if t == null:
		t = Tex.get_tex("res://assets/mecha/%s.png" % chassis, Palette.STEEL, 256)
	_cache[key] = t
	return t

func _apply() -> void:
	var tex: Texture2D = _tex(_anim, _dir)
	_spr.texture = tex
	_spr.hframes = frame_count
	_spr.frame = clampi(_frame, 0, frame_count - 1)
	var fh: float = float(tex.get_height())
	if fh > 0.0:
		_spr.scale = Vector2.ONE * (display_height / fh)

## Pick facing from a movement/aim vector. +y (down, toward camera) = front.
func set_facing_from(v: Vector2) -> void:
	if v.length() < 0.05:
		return
	var d: String
	if absf(v.x) > absf(v.y):
		d = "right" if v.x > 0.0 else "left"
	else:
		d = "front" if v.y > 0.0 else "back"
	if d != _dir:
		_dir = d
		_apply()

func play(anim: String) -> void:
	if anim == _anim and bool(LOOP.get(anim, false)):
		return
	_anim = anim
	_frame = 0
	_t = 0.0
	_oneshot = not bool(LOOP.get(anim, true))
	_apply()

func current_anim() -> String:
	return _anim

func _process(delta: float) -> void:
	_t += delta
	var step: float = 1.0 / float(FPS.get(_anim, 10.0))
	while _t >= step:
		_t -= step
		_frame += 1
		if _frame >= frame_count:
			if _oneshot:
				_frame = frame_count - 1
				_oneshot = false
				anim_finished.emit(_anim)
				if _anim != "die":
					play("idle")
				return
			_frame = 0
	_spr.frame = _frame
