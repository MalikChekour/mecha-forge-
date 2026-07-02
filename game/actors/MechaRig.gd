extends Node2D
class_name MechaRig
## Layered, procedurally-animated mecha.
##
## The chassis is assembled from SEPARATELY-RENDERED rigid part sprites
## (leg_left, leg_right, torso, core, head) composited live; each equipped weapon
## is a VISIBLE hardpoint mounted at a shoulder anchor that aims and recoils.
## There are NO baked per-combo walk spritesheets: any chassis x weapon loadout is
## assembled and animated at runtime, which is what makes the mecha customizable.
##
## Animation is fully procedural and matches tools/preview_gif.py 1:1 so the engine
## looks like the offline proof. All offsets are expressed in 384px "frame space"
## (the render resolution) and scaled to the display via this node's `scale`.

# --- shared animation constants (mirror of tools/preview_gif.py) ---
const A_LIFT: float = 0.028     # leg vertical lift on swing (frac of frame)
const A_STRIDE: float = 0.016   # leg fore/aft stride
const A_BOB: float = 0.014      # torso weight-bob
const A_ROCK: float = 0.030     # torso rock (radians)
const A_HEADB: float = 0.010    # head extra bob
const RECOIL: float = 0.055     # weapon kick along -aim
const STEP_FREQ: float = 1.1    # leg cycles/sec at reference speed
const REF_SPEED: float = 220.0

signal fired(hardpoint_index: int, muzzle_world: Vector2, aim: Vector2)

@export var display_height: float = 150.0   # on-screen mecha height in px

var frame_px: float = 384.0
var velocity: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.RIGHT

var _rig: Dictionary = {}
var _layers: Dictionary = {}     # name -> Sprite2D
var _hardpoints: Array = []      # {sprite, mount:Vector2, muzzle:float, recoil:float, id:String}
var _phase: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	_load_rig()
	_build_chassis()
	scale = Vector2.ONE * (display_height / frame_px)

func _load_rig() -> void:
	var path: String = "res://assets/mecha/rig.json"
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_rig = data
	frame_px = float(_rig.get("frame", 384))

func _mk_layer(lname: String, z: int, tint: Color) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.centered = true
	s.z_index = z
	s.name = lname
	s.texture = Tex.get_tex("res://assets/mecha/%s.png" % lname, tint, int(frame_px))
	add_child(s)
	_layers[lname] = s

func _build_chassis() -> void:
	var zo: Dictionary = _rig.get("z_order", {"leg_left": 0, "leg_right": 0, "torso": 2, "core": 3, "head": 3})
	_mk_layer("leg_left", int(zo.get("leg_left", 0)), Palette.STEEL)
	_mk_layer("leg_right", int(zo.get("leg_right", 0)), Palette.STEEL)
	_mk_layer("torso", int(zo.get("torso", 2)), Palette.STEEL)
	_mk_layer("core", int(zo.get("core", 3)), Palette.CYAN)
	_mk_layer("head", int(zo.get("head", 3)), Palette.STEEL)

## Mount a visible weapon hardpoint. side = "left" | "right". Returns its index.
func add_hardpoint(weapon_id: String, side: String) -> int:
	var s: Sprite2D = Sprite2D.new()
	s.centered = true
	s.z_index = 4
	s.texture = Tex.get_tex("res://assets/weapons/%s.png" % weapon_id, Palette.GUNMETAL, int(frame_px))
	add_child(s)
	var shoulders: Dictionary = _rig.get("shoulders", {"left": [-92, -35], "right": [92, -35]})
	var arr: Array = shoulders.get(side, [92, -35])
	var mount: Vector2 = Vector2(arr[0], arr[1])
	var muzzle: float = 100.0
	var wdefs: Dictionary = _rig.get("weapons", {})
	if wdefs.has(weapon_id):
		var wd: Dictionary = wdefs[weapon_id]
		var md: Array = wd.get("muzzle", [100, 0])
		muzzle = float(md[0])
	s.position = mount
	_hardpoints.append({"sprite": s, "mount": mount, "muzzle": muzzle, "recoil": 0.0, "id": weapon_id})
	return _hardpoints.size() - 1

func fire(i: int) -> void:
	if i < 0 or i >= _hardpoints.size():
		return
	var hp: Dictionary = _hardpoints[i]
	hp["recoil"] = 1.0
	var mount: Vector2 = hp["mount"]
	var muzzle_local: Vector2 = mount + aim_dir * float(hp["muzzle"])
	fired.emit(i, to_global(muzzle_local), aim_dir)

func get_layer_count() -> int:
	return _layers.size()

func get_hardpoint_count() -> int:
	return _hardpoints.size()

func _process(delta: float) -> void:
	_time += delta
	var speed: float = velocity.length()
	var moving: bool = speed > 5.0
	if moving:
		var drive: float = clampf(speed / REF_SPEED, 0.35, 1.6)
		_phase += delta * STEP_FREQ * TAU * drive

	_anim_leg("leg_left", 0.0, moving)
	_anim_leg("leg_right", PI, moving)

	var bob: float = 0.0
	var rock: float = 0.0
	var head_dy: float = 0.0
	if moving:
		bob = A_BOB * frame_px * (0.5 - 0.5 * cos(2.0 * _phase))
		rock = A_ROCK * sin(_phase)
		head_dy = -A_HEADB * frame_px * (0.5 - 0.5 * cos(2.0 * _phase))
	else:
		bob = A_BOB * frame_px * 0.35 * (0.5 - 0.5 * cos(_time * TAU * 0.5))

	var torso: Sprite2D = _layers["torso"]
	torso.position = Vector2(0, bob)
	torso.rotation = rock
	var core: Sprite2D = _layers["core"]
	core.position = Vector2(0, bob)
	core.rotation = rock
	core.modulate.a = 0.75 + 0.25 * sin(_time * TAU * 1.5)
	var head: Sprite2D = _layers["head"]
	head.position = Vector2(0, bob + head_dy)

	var a: float = aim_dir.angle()
	for hp in _hardpoints:
		var s: Sprite2D = hp["sprite"]
		s.rotation = a
		var kick: float = float(hp["recoil"]) * RECOIL * frame_px
		s.position = Vector2(hp["mount"]) - aim_dir * kick
		hp["recoil"] = maxf(0.0, float(hp["recoil"]) - delta * 6.0)

func _anim_leg(lname: String, phase_off: float, moving: bool) -> void:
	var s: Sprite2D = _layers[lname]
	if not moving:
		s.position = s.position.lerp(Vector2.ZERO, 0.2)
		return
	var p: float = _phase + phase_off
	var dy: float = -A_LIFT * frame_px * maxf(0.0, sin(p))
	dy += A_STRIDE * frame_px * cos(p) * 0.5
	var dx: float = A_STRIDE * frame_px * sin(p) * 0.35
	s.position = Vector2(dx, dy)
