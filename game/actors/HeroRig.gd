extends Node2D
class_name HeroRig
## 2D cut-out rig of the Gemini-painted hero: separate part sprites (head/torso/arms/legs)
## rotated around their joints for a living walk + 360° weapon aim. Drop-in for the player's
## `mecha` visual (implements play/current_anim/set_facing_from/set_tint like DirectionalMecha).

@export var chassis: String = "hero"     # compat (unused)
@export var display_height: float = 210.0

const RIG_SPAN_Y: float = 1005.0
const CENTER_Y: float = 481.0            # shift the feet-anchored export so the rig is centred on origin
const RIG: Dictionary = {
	"leg_r": {"joint": Vector2(68.0, 32.0),  "pos": Vector2(57.0, -568.0),  "z": 0},
	"leg_l": {"joint": Vector2(164.0, 32.0), "pos": Vector2(-49.0, -568.0), "z": 1},
	"torso": {"joint": Vector2(170.0, 150.0),"pos": Vector2(-1.0, -750.0),  "z": 2},
	"arm_r": {"joint": Vector2(36.0, 76.0),  "pos": Vector2(137.0, -820.0), "z": 3},
	"arm_l": {"joint": Vector2(189.0, 75.0), "pos": Vector2(-133.0, -820.0),"z": 4},
	"head":  {"joint": Vector2(80.0, 178.0), "pos": Vector2(4.0, -805.0),   "z": 5},
}

var _parts: Dictionary = {}
var _base: Dictionary = {}               # name -> centred base position
var _anim: String = "idle"
var _anim_t: float = 0.0                  # time in the current anim (for one-shot auto-return)
var _aim: Vector2 = Vector2.RIGHT
var _t: float = 0.0
var _stride: float = 0.0
var _shadow: Sprite2D

func _ready() -> void:
	scale = Vector2.ONE * (display_height / RIG_SPAN_Y)
	_shadow = Sprite2D.new()
	_shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	_shadow.modulate = Color(0, 0, 0, 0.5)
	_shadow.position = Vector2(0.0, CENTER_Y + 8.0)
	_shadow.scale = Vector2(5.2, 1.5)
	_shadow.z_index = -3
	add_child(_shadow)
	for name in RIG:
		var d: Dictionary = RIG[name]
		var s: Sprite2D = Sprite2D.new()
		s.texture = load("res://assets/hero/%s.png" % name)
		s.centered = false
		s.offset = -(d["joint"] as Vector2)          # joint at node origin -> rotate around the joint
		var p: Vector2 = (d["pos"] as Vector2) + Vector2(0.0, CENTER_Y)
		s.position = p
		s.z_index = int(d["z"])
		add_child(s)
		_parts[name] = s
		_base[name] = p

# --- DirectionalMecha-compatible interface ---
func play(a: String) -> void:
	_anim = a
	_anim_t = 0.0
func current_anim() -> String: return _anim
func set_facing_from(v: Vector2) -> void:
	if v.length() > 0.05: _aim = v.normalized()
func facing() -> String: return "right" if _aim.x >= 0.0 else "left"
func set_tint(c: Color) -> void:
	for s in _parts.values(): (s as Sprite2D).modulate = c
func set_chassis(_c: String) -> void: pass

func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	if (_anim == "attack" or _anim == "hit") and _anim_t > 0.35:
		_anim = "idle"    # one-shot auto-return (Player relies on this, like DirectionalMecha)
	var base_scale: float = display_height / RIG_SPAN_Y

	if _anim == "die":
		rotation = move_toward(rotation, 1.25, delta * 4.5)   # topple over
		scale.x = base_scale
		return
	rotation = move_toward(rotation, 0.0, delta * 6.0)

	var moving: bool = _anim == "walk" or _anim == "run"
	var attack: bool = _anim == "attack"
	if moving: _stride += delta * (9.0 if _anim == "run" else 6.5)
	var ph: float = _stride
	var sway: float = sin(ph)
	var bob: float = (sin(ph * 2.0) * 7.0) if moving else (sin(_t * 2.2) * 2.5)

	for name in _parts:                       # whole-body bob + reset
		var s: Sprite2D = _parts[name]
		s.position = _base[name] + Vector2(0.0, bob)
		s.rotation = 0.0

	if moving:
		_parts["leg_l"].rotation = deg_to_rad(sway * 6.0)
		_parts["leg_l"].position.y += -maxf(0.0, sway) * 9.0
		_parts["leg_r"].rotation = deg_to_rad(-sway * 6.0)
		_parts["leg_r"].position.y += -maxf(0.0, -sway) * 9.0
		_parts["arm_l"].rotation = deg_to_rad(sin(ph + PI) * 10.0)
		_parts["head"].rotation = deg_to_rad(sway * 2.0)
	else:
		_parts["arm_l"].rotation = deg_to_rad(sin(_t * 2.2 + 1.0) * 2.5)

	# weapon arm aims (raise with aim.y) + recoil kick on attack + a little walk sway
	var raise: float = clampf(-_aim.y, -1.0, 1.0) * 0.5
	var recoil: float = -0.35 if (attack and fmod(_t, 0.16) < 0.08) else 0.0
	_parts["arm_r"].rotation = raise + recoil + (deg_to_rad(sin(ph) * 6.0) if moving else 0.0)

	scale.x = base_scale * (1.0 if _aim.x >= 0.0 else -1.0)   # mirror to face left/right
