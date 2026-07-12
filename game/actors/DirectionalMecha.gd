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

const LOOP: Dictionary = {"idle": true, "walk": true, "run": true, "attack": false, "hit": false, "die": false}
const FPS: Dictionary = {"idle": 10.0, "walk": 16.0, "run": 20.0, "attack": 22.0, "hit": 14.0, "die": 12.0}

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

## Grip anchor (local px, relative to mecha center) where a held weapon sits, per facing.
## Derived by projecting the rig's LeftHand/RightHand bones through the exact bake camera
## (two-hand midpoint) so the weapon attaches to the body instead of floating in front.
const _GRIP_ANCHOR: Dictionary = {
	"front": Vector2(-0.8, -22.9),
	"back": Vector2(0.8, -22.8),
	"left": Vector2(0.1, -23.3),
	"right": Vector2(-0.1, -22.4),
}

func grip_anchor() -> Vector2:
	var a: Vector2 = _GRIP_ANCHOR.get(_dir, Vector2(0.0, -23.0))
	return a * (display_height / 190.0)   # anchors were measured at display_height 190

## Chassis that hold their weapons baked into the mesh (cannon in the RIGHT hand, energy
## blade in the LEFT hand). Anchors are projected from each rig (at display 190) so the game
## fires from the cannon hand and places the melee/saber FX on the blade hand, per facing.
const _GUN_ANCHORS: Dictionary = {
	"valiant": {
		"front": Vector2(-14.8, -33.7), "back": Vector2(14.8, -3.4),
		"left": Vector2(24.5, -27.7), "right": Vector2(-24.5, -9.4)},
	"pilot": {
		"front": Vector2(-14.9, -25.7), "back": Vector2(14.9, -10.9),
		"left": Vector2(12.1, -27.5), "right": Vector2(-12.1, -9.1)},
	"mecha_joueur": {
		"front": Vector2(-15.0, -26.0), "back": Vector2(15.0, -11.0),
		"left": Vector2(12.0, -28.0), "right": Vector2(-12.0, -9.0)},
}
const _BLADE_ANCHORS: Dictionary = {
	"valiant": {
		"front": Vector2(8.0, -8.0), "back": Vector2(-8.0, -30.6),
		"left": Vector2(-18.3, -14.4), "right": Vector2(18.3, -24.2)},
	"pilot": {
		"front": Vector2(21.0, -22.9), "back": Vector2(-21.0, -19.2),
		"left": Vector2(2.9, -8.2), "right": Vector2(-2.9, -34.0)},
	"mecha_joueur": {
		"front": Vector2(20.0, -22.0), "back": Vector2(-20.0, -19.0),
		"left": Vector2(3.0, -8.0), "right": Vector2(-3.0, -34.0)},
}

func has_baked_weapon() -> bool:
	return _GUN_ANCHORS.has(chassis)

func gun_anchor() -> Vector2:
	var d: Dictionary = _GUN_ANCHORS.get(chassis, {})
	var a: Vector2 = d.get(_dir, Vector2(-15.0, -25.0))
	return a * (display_height / 190.0)

func blade_anchor() -> Vector2:
	var d: Dictionary = _BLADE_ANCHORS.get(chassis, {})
	var a: Vector2 = d.get(_dir, Vector2(15.0, -20.0))
	return a * (display_height / 190.0)

func facing() -> String:
	return _dir

## Tint the sprite (e.g. energized/overdrive glow) without swapping the chassis.
func set_tint(c: Color) -> void:
	if _spr != null:
		_spr.modulate = c

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

## Swap the whole chassis (e.g. base 'vanguard' <-> transformed 'vanguard2').
## Clears the texture cache so the new chassis' sheets load on the next frame.
func set_chassis(c: String) -> void:
	chassis = c
	_cache.clear()
	_apply()

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
