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

const LOOP: Dictionary = {"idle": true, "walk": true, "run": true, "attack": true, "hit": false, "die": false, "melee": false}
const FPS: Dictionary = {"idle": 10.0, "walk": 16.0, "run": 20.0, "attack": 18.0, "hit": 14.0, "die": 12.0, "melee": 24.0}

var _spr: Sprite2D
var _shadow: Sprite2D                 # ground contact shadow so the mech doesn't look airborne
var _cache: Dictionary = {}          # "anim_dir" -> Texture2D
var _anim: String = "idle"
var _dir: String = "front"
var _t: float = 0.0
var _frame: int = 0
var _oneshot: bool = false

# Procedural life for STATIC baked models (frame_count==1, e.g. TRELLIS mechs with no rig):
# a breathing bob, a walk bounce, and a fire recoil kick opposite the facing — so the mech
# reads as alive and as "bracing when it shoots" without any skeletal animation.
var _static: bool = false
var _bob_t: float = 0.0
var _recoil_t: float = 0.0
const _DIRVEC: Dictionary = {"front": Vector2(0, 1), "back": Vector2(0, -1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
# AIM LEAN: the sprite is baked in 4 cardinal yaws, but the shot follows the exact 360° aim. To keep
# the cannon pointing where it actually fires (instead of "leaning" off to a cardinal), the whole mech
# is rotated a little toward the exact aim, clamped so the body never tips over. The gun/head anchors
# rotate by the same amount so the muzzle flash + eye-laser stay glued to the (now rotated) hardpoints.
var _lean: float = 0.0
var _lean_target: float = 0.0
const LEAN_MAX: float = 0.40

func set_lean_target(_rad: float) -> void:
	_lean_target = 0.0
	_lean = 0.0
	if _spr != null:
		_spr.rotation = 0.0

func _ready() -> void:
	# No ground shadow on the player mech: it walks, and the contact shadow on 3/4 walker art read
	# as pasted/floating however it was placed (patron). Flyers keep theirs (see Enemy.gd).
	_spr = Sprite2D.new()
	_spr.centered = true
	_spr.hframes = frame_count
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel-art sheets (no blur upscaling)
	add_child(_spr)
	_static = frame_count <= 1        # a single-frame chassis -> drive it procedurally
	_apply()

func _tex(anim: String, dir: String) -> Texture2D:
	var key: String = "%s_%s" % [anim, dir]
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	var candidates: Array[String] = [
		"res://assets/mecha/%s_%s_%s.png" % [chassis, anim, dir],
		"res://assets/mecha/%s_%s.png" % [chassis, anim],
		"res://assets/mecha/%s_walk_%s.png" % [chassis, dir],   # anim fallback: any chassis missing
		"res://assets/mecha/%s_idle_%s.png" % [chassis, dir],   # 'run'/'hit' still renders cleanly
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
	if _spr == null:
		return
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
	"darkstar": {
		"front": Vector2(-15.0, -26.0), "back": Vector2(15.0, -11.0),
		"left": Vector2(12.0, -28.0), "right": Vector2(-12.0, -9.0)},
	"bluestrike": {
		"front": Vector2(-15.0, -26.0), "back": Vector2(15.0, -11.0),
		"left": Vector2(12.0, -28.0), "right": Vector2(-12.0, -9.0)},
	"valiant": {
		"front": Vector2(-14.8, -33.7), "back": Vector2(14.8, -3.4),
		"left": Vector2(24.5, -27.7), "right": Vector2(-24.5, -9.4)},
	"pilot": {
		"front": Vector2(-14.9, -25.7), "back": Vector2(14.9, -10.9),
		"left": Vector2(12.1, -27.5), "right": Vector2(-12.1, -9.1)},
	"mecha_joueur": {
		"front": Vector2(-15.0, -26.0), "back": Vector2(15.0, -11.0),
		"left": Vector2(12.0, -28.0), "right": Vector2(-12.0, -9.0)},
	# VORTEX carries an ARM-CANNON baked into every attack frame. These anchors are the
	# measured barrel-TIP pixel per facing (tools/_muzzle_measure.py, gun rendered alone in
	# the exact bake framing), so the muzzle flash + laser leave the very end of the barrel.
	"vortex": {
		"front": Vector2(-11.7, 6.7), "back": Vector2(8.9, -81.6),
		"left": Vector2(-67.5, -43.9), "right": Vector2(66.8, -31.9)},
	"titan": {
		"front": Vector2(-16.0, -14.0), "back": Vector2(16.0, -12.0),
		"left": Vector2(14.0, -22.0), "right": Vector2(-14.0, -12.0)},
	"bruiser": {
		"front": Vector2(-16.0, -12.0), "back": Vector2(16.0, -10.0),
		"left": Vector2(14.0, -20.0), "right": Vector2(-14.0, -10.0)},
	"vanquisher": {
		"front": Vector2(-18.0, -16.0), "back": Vector2(18.0, -12.0),
		"left": Vector2(16.0, -22.0), "right": Vector2(-16.0, -12.0)},
	"pylone": {
		"front": Vector2(-16.0, -14.0), "back": Vector2(16.0, -12.0),
		"left": Vector2(14.0, -22.0), "right": Vector2(-14.0, -12.0)},
	"cerclier": {
		"front": Vector2(-18.0, -16.0), "back": Vector2(18.0, -12.0),
		"left": Vector2(16.0, -22.0), "right": Vector2(-16.0, -12.0)},
}
# Head/eye pixel per facing (measured from the sprite's head mass, tools/head_check2). The red
# targeting laser is emitted from here — a head-mounted sight, Terminator style.
const _HEAD_ANCHORS: Dictionary = {
	"vortex": {
		"front": Vector2(-0.7, -42.3), "back": Vector2(2.3, -43.8),
		"left": Vector2(-15.9, -48.2), "right": Vector2(2.2, -43.8)},
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

# True when gun_anchor() already points at the barrel TIP (not the hand), so the muzzle
# needs no extra forward offset. VORTEX's arm-cannon anchors are measured tips.
func gun_at_tip() -> bool:
	return chassis in ["vortex", "titan", "bruiser", "vanquisher", "pylone", "cerclier"]

func gun_anchor() -> Vector2:
	var d: Dictionary = _GUN_ANCHORS.get(chassis, {})
	var a: Vector2 = d.get(_dir, Vector2(-15.0, -25.0))
	return a * (display_height / 190.0)

func has_head_anchor() -> bool:
	return _HEAD_ANCHORS.has(chassis)

func head_anchor() -> Vector2:
	var d: Dictionary = _HEAD_ANCHORS.get(chassis, {})
	var a: Vector2 = d.get(_dir, Vector2(0.0, -44.0))
	return a * (display_height / 190.0)

func blade_anchor() -> Vector2:
	var d: Dictionary = _BLADE_ANCHORS.get(chassis, {})
	var a: Vector2 = d.get(_dir, Vector2(15.0, -20.0))
	return a * (display_height / 190.0)

func facing() -> String:
	return _dir

func facing_vec() -> Vector2:
	return _DIRVEC.get(_dir, Vector2.RIGHT)

## Tint the sprite (e.g. energized/overdrive glow) without swapping the chassis.
func set_tint(c: Color) -> void:
	if _spr != null:
		_spr.modulate = c

## Pick facing from a movement/aim vector. +y (down, toward camera) = front.
## HYSTERESIS: near a 45-degree diagonal the two axes are almost equal, so a raw |x|>|y|
## test flip-flops between (e.g.) front and right every frame -> visible spinning. We only
## switch facing when one axis clearly dominates (>18%); otherwise we keep the current one.
func set_facing_from(v: Vector2) -> void:
	if v.length() < 0.05:
		return
	var ax: float = absf(v.x)
	var ay: float = absf(v.y)
	if maxf(ax, ay) < 1.05 * minf(ax, ay):
		return   # only hold within ~3 deg of a pure 45 diagonal (avoid jitter); else pick the axis
	var d: String
	if ax > ay:
		d = "right" if v.x > 0.0 else "left"
	else:
		d = "front" if v.y > 0.0 else "back"
	if d != _dir:
		_dir = d
		_apply()

func play(anim: String) -> void:
	if anim == "attack":
		_recoil_t = 1.0            # every shot kicks the mech back a touch (static + rigged alike)
	if anim == _anim and bool(LOOP.get(anim, false)):
		return
	_anim = anim
	_frame = 0
	_t = 0.0
	_oneshot = not bool(LOOP.get(anim, true))
	_apply()

func current_anim() -> String:
	return _anim

## Kick the mech back a touch on each shot, without changing the animation state.
func recoil() -> void:
	_recoil_t = 1.0

## Static baked model: no frames to step, so we animate the sprite's OFFSET instead.
## - idle: slow breathing bob
## - walk/run: faster bob + a vertical bounce (it plods)
## - firing: a recoil kick opposite the facing (set by play("attack"))
## - die: sink + fade
func _process_static(delta: float) -> void:
	if _anim == "die":
		_recoil_t = 0.0
		_spr.position.y = lerp(_spr.position.y, 14.0, minf(1.0, delta * 4.0))
		_spr.modulate.a = maxf(0.0, _spr.modulate.a - delta * 0.9)
		return
	var moving: bool = _anim == "walk" or _anim == "run"
	_bob_t += delta * (9.5 if moving else 3.2)
	var bob: float = sin(_bob_t) * (2.0 if not moving else 3.0)
	var bounce: float = absf(sin(_bob_t)) * 4.5 if moving else 0.0
	_recoil_t = maxf(0.0, _recoil_t - delta * 5.5)
	var kick: Vector2 = (_DIRVEC.get(_dir, Vector2.ZERO) as Vector2) * (-_recoil_t * 13.0)
	_spr.position = Vector2(kick.x, -bob - bounce + kick.y)
	_lean = 0.0
	_spr.rotation = 0.0

## Swap the whole chassis (e.g. base 'vanguard' <-> transformed 'vanguard2').
## Clears the texture cache so the new chassis' sheets load on the next frame.
func set_chassis(c: String) -> void:
	chassis = c
	_cache.clear()
	_apply()

func _process(delta: float) -> void:
	if _static:
		_process_static(delta)
		return
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
	# PER-SHOT RECOIL on the ANIMATED mech (previously only static chassis kicked). recoil() /
	# play("attack") set _recoil_t on every shot, so the body visibly KICKS BACK opposite its facing
	# with each volley -> the firing reads as SYNCED to the mech instead of muzzle flashes from nowhere.
	_recoil_t = maxf(0.0, _recoil_t - delta * 8.0)
	var kick: Vector2 = (_DIRVEC.get(_dir, Vector2.ZERO) as Vector2) * (-_recoil_t * 8.0)
	_spr.position = kick
	_lean = 0.0
	_spr.rotation = 0.0
