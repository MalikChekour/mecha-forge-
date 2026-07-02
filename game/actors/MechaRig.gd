extends Node2D
class_name MechaRig
## Layered, procedurally-animated mecha — runtime twin of tools/preview_gif.py.
##
## The chassis is assembled from SEPARATELY-RENDERED rigid part layers
## (thigh_l/r + shin_l/r + torso + core + head) composited live; each equipped
## weapon is a VISIBLE hardpoint mounted at a shoulder anchor that aims and
## recoils. No baked per-combo spritesheets: any chassis x weapon loadout is
## assembled and animated at runtime.
##
## The animation model and its constants come from assets/mecha/rig.json (single
## source of truth, written by tools/build_mecha.py):
## - two-segment FK legs in ANTIPHASE (visible knee bend, foot plant + squash)
## - torso weight: bob dips on footfalls, lateral shift to the planted foot,
##   rock about the pelvis; head follows with a lag; core pulses
## - hardpoints INHERIT the torso motion (review fix: no floating weapons),
##   kick along -aim on fire, with a torso counter-rock impulse
## All offsets are in "frame space" (the 384px render), scaled via node `scale`.

signal fired(hardpoint_index: int, muzzle_world: Vector2, aim: Vector2)

@export var display_height: float = 150.0   # on-screen mecha height in px

var frame_px: float = 384.0
var velocity: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.RIGHT:
	set(v):
		# review fix: normalize on assign; zero-aim falls back to +X
		aim_dir = v.normalized() if v.length_squared() > 0.0001 else Vector2.RIGHT

const REF_SPEED: float = 220.0
const CHASSIS: Array[String] = ["thigh_left", "thigh_right", "shin_left", "shin_right", "torso", "core", "head"]

var _rig: Dictionary = {}
var _anim: Dictionary = {}
var _layers: Dictionary = {}      # name -> Sprite2D
var _hardpoints: Array = []       # {sprite, mount, muzzle, recoil, side, id}
var _anchor: Dictionary = {}      # "hips"/"knees"/"feet"/"shoulders" -> {left/right: Vector2}
var _rock_pivot: Vector2 = Vector2.ZERO
var _phase: float = 0.0
var _time: float = 0.0
var _walk_w: float = 0.0          # walk weight 0..1 — review fix: no idle<->walk pop
var _rock_imp: float = 0.0        # fire counter-rock impulse
var _shadow_squash: float = 0.0

func _ready() -> void:
	_load_rig()
	_build_chassis()
	scale = Vector2.ONE * (display_height / frame_px)

func _a(key: String, def: float) -> float:
	var v: Variant = _anim.get(key)
	return float(v) if (v is float or v is int) else def

func _load_rig() -> void:
	var path: String = "res://assets/mecha/rig.json"
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_rig = data
	frame_px = float(_rig.get("frame", 384))
	var an: Variant = _rig.get("anim", {})
	_anim = an if an is Dictionary else {}
	for grp in ["hips", "knees", "feet", "shoulders"]:
		var g: Variant = _rig.get(grp, {})
		var out: Dictionary = {}
		for side in ["left", "right"]:
			var arr: Variant = g.get(side) if g is Dictionary else null
			if arr is Array and arr.size() >= 2:
				out[side] = Vector2(float(arr[0]), float(arr[1]))
			else:
				out[side] = Vector2(38.0 if side == "right" else -38.0, 5.0)
		_anchor[grp] = out
	_rock_pivot = Vector2(0.0, (_anchor["hips"]["left"] as Vector2).y)

func _mk_layer(lname: String, z: int, tint: Color) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.centered = true
	s.z_index = z
	s.name = lname
	s.texture = Tex.get_tex("res://assets/mecha/%s.png" % lname, tint, int(frame_px))
	add_child(s)
	_layers[lname] = s

func _build_chassis() -> void:
	var zo_v: Variant = _rig.get("z_order", {})
	var zo: Dictionary = zo_v if zo_v is Dictionary else {}
	var defaults: Dictionary = {"thigh_left": 0, "thigh_right": 0, "shin_left": 1, "shin_right": 1,
		"torso": 3, "core": 4, "head": 5}
	for lname in CHASSIS:
		var tint: Color = Palette.CYAN if lname == "core" else Palette.STEEL
		_mk_layer(lname, int(zo.get(lname, defaults.get(lname, 0))), tint)

## Mount a visible weapon hardpoint. side = "left" | "right". Returns its index.
func add_hardpoint(weapon_id: String, side: String) -> int:
	var s: Sprite2D = Sprite2D.new()
	s.centered = true
	s.z_index = 6
	s.texture = Tex.get_tex("res://assets/weapons/%s.png" % weapon_id, Palette.GUNMETAL, int(frame_px))
	add_child(s)
	var mount: Vector2 = (_anchor["shoulders"] as Dictionary).get(side, Vector2(86, -55))
	var muzzle: float = 100.0
	var wdefs: Variant = _rig.get("weapons", {})
	if wdefs is Dictionary and wdefs.has(weapon_id) and wdefs[weapon_id] is Dictionary:
		var md: Variant = (wdefs[weapon_id] as Dictionary).get("muzzle")
		if md is Array and md.size() >= 1:
			muzzle = float(md[0])
	s.position = mount
	_hardpoints.append({"sprite": s, "mount": mount, "muzzle": muzzle, "recoil": 0.0,
		"side": side, "id": weapon_id})
	return _hardpoints.size() - 1

## Shared barrel-tip math (review fix: fire() and the visual use the SAME helper,
## including the transformed mount and current recoil).
func _hardpoint_tip(hp: Dictionary, mount_now: Vector2) -> Vector2:
	var kick: float = float(hp["recoil"]) * _a("recoil", 0.06) * frame_px
	return mount_now - aim_dir * kick + aim_dir * float(hp["muzzle"])

func fire(i: int) -> void:
	if i < 0 or i >= _hardpoints.size():
		return
	var hp: Dictionary = _hardpoints[i]
	hp["recoil"] = 1.0
	_rock_imp += _a("recoil_rock", 0.05) * (0.6 if String(hp["side"]) == "left" else -0.6)
	var tip: Vector2 = _hardpoint_tip(hp, _mount_now(hp))
	fired.emit(i, to_global(tip), aim_dir)

func get_layer_count() -> int:
	return _layers.size()

func get_hardpoint_count() -> int:
	return _hardpoints.size()

# ---- animation ----

func _current_rock() -> float:
	return _a("rock", 0.045) * sin(_phase) * _walk_w + _rock_imp

func _current_bob() -> float:
	var dip: float = pow(0.5 + 0.5 * cos(2.0 * _phase), 1.5)
	var idle: float = _a("bob", 0.02) * frame_px * 0.3 * (0.5 - 0.5 * cos(_time * TAU * 0.5))
	return _a("bob", 0.02) * frame_px * dip * _walk_w + idle * (1.0 - _walk_w)

func _current_lat() -> float:
	return _a("lat", 0.01) * frame_px * sin(_phase) * _walk_w

func _mount_now(hp: Dictionary) -> Vector2:
	var rock: float = _current_rock()
	var m: Vector2 = hp["mount"]
	return (m - _rock_pivot).rotated(rock) + _rock_pivot + Vector2(_current_lat(), _current_bob())

func _process(delta: float) -> void:
	_time += delta
	var speed: float = velocity.length()
	var moving: bool = speed > 5.0
	_walk_w = clampf(_walk_w + (6.0 * delta if moving else -6.0 * delta), 0.0, 1.0)
	if moving:
		var drive: float = clampf(speed / REF_SPEED, 0.35, 1.6)
		_phase += delta * _a("step_freq", 1.0) * TAU * drive
	_rock_imp = lerpf(_rock_imp, 0.0, minf(1.0, delta * 8.0))

	var bob: float = _current_bob()
	var lat: float = _current_lat()
	var rock: float = _current_rock()
	var head_dy: float = _a("head_bob", 0.008) * frame_px * (0.5 + 0.5 * cos(2.0 * _phase - 0.6)) * _walk_w
	_shadow_squash = bob

	_leg_pose("left")
	_leg_pose("right")

	_place(_layers["torso"], rock, _rock_pivot, Vector2(lat, bob))
	var core: Sprite2D = _layers["core"]
	_place(core, rock, _rock_pivot, Vector2(lat, bob))
	core.modulate.a = 0.88 + 0.12 * sin(TAU * _a("core_pulse_hz", 1.2) * _time)
	_place(_layers["head"], rock * 0.5, _rock_pivot, Vector2(lat, bob + head_dy))

	for hp in _hardpoints:
		var s: Sprite2D = hp["sprite"]
		var mount_now: Vector2 = _mount_now(hp)
		var kick: float = float(hp["recoil"]) * _a("recoil", 0.06) * frame_px
		s.rotation = aim_dir.angle()
		s.position = mount_now - aim_dir * kick
		hp["recoil"] = maxf(0.0, float(hp["recoil"]) - delta * 6.0)

	queue_redraw()

## Place a full-frame layer rotated by `a` about `pivot` (frame coords rel center)
## then translated — same convention as preview_gif.py comp().
func _place(s: Sprite2D, a: float, pivot: Vector2, translate: Vector2) -> void:
	s.rotation = a
	s.position = pivot - pivot.rotated(a) + translate

## Two-segment FK leg, antiphase on the right — mirror of preview_gif.leg_pose().
func _leg_pose(side: String) -> void:
	var sg: float = -1.0 if side == "left" else 1.0
	var p: float = _phase + (PI if side == "right" else 0.0)
	var swing: float = maxf(0.0, sin(p)) * _walk_w
	var stance: float = maxf(0.0, -sin(p)) * _walk_w
	var hip: Vector2 = _anchor["hips"][side]
	var knee: Vector2 = _anchor["knees"][side]
	var foot: Vector2 = _anchor["feet"][side]

	var th: float = sg * _a("thigh_rot", 0.10) * swing
	var dx: float = _a("stride", 0.014) * frame_px * sin(p) * 0.35 * _walk_w
	var dyt: float = -_a("lift_thigh", 0.02) * frame_px * swing
	_place(_layers["thigh_%s" % side], th, hip, Vector2(dx, dyt))

	# knee position after the thigh transform
	var knee_now: Vector2 = knee.rotated(th) + (hip - hip.rotated(th)) + Vector2(dx, dyt)
	# shin: extra knee bend + extra lift during swing; squash on plant (foot-anchored)
	var ps: float = th + sg * _a("shin_rot", 0.22) * swing
	var extra: float = -_a("lift_shin", 0.024) * frame_px * swing
	var sq: float = 1.0 - _a("squash", 0.055) * pow(stance, 3.0)
	var shin: Sprite2D = _layers["shin_%s" % side]
	var tr: Vector2 = knee_now - knee.rotated(ps) + Vector2(0.0, extra)
	# PIL-equivalent squash: pre-rotation content offset + top-left anchor shift
	var cy: float = frame_px / 2.0
	var dy_sq: float = (cy + foot.y) * (1.0 - sq)
	shin.rotation = ps
	shin.scale = Vector2(1.0, sq)
	shin.position = tr + Vector2(0.0, dy_sq) + Vector2(0.0, cy * (sq - 1.0)).rotated(ps)

func _draw() -> void:
	# soft ground shadow under the feet (squashes with the bob) — grounds the mecha
	var fy: float = (_anchor["feet"]["left"] as Vector2).y + 8.0
	var w: float = 150.0 - _shadow_squash * 2.5
	draw_set_transform(Vector2(0, fy), 0.0, Vector2(w / 150.0, 0.22))
	draw_circle(Vector2.ZERO, 75.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
