extends Node2D
## Rig sandbox + headless smoke harness.
## Drives a MechaRig through walk / aim / fire so the whole layered-animation
## system is exercised. Desktop: interactive sandbox (arrows move; auto-demo
## otherwise). Headless (--autoplay): asserts real invariants and exits with a
## meaningful code — review fix: no hardcoded "0 errors", no unconditional quit(0).

const EXPECT_LAYERS: int = 7      # thigh x2 + shin x2 + torso + core + head
const EXPECT_HARDPOINTS: int = 2

var rig: MechaRig
var _t: float = 0.0
var _frames: int = 0
var _fires: int = 0
var _headless: bool = false

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--autoplay")
	rig = MechaRig.new()
	rig.display_height = 240.0
	rig.position = get_viewport_rect().size * 0.5
	add_child(rig)
	rig.add_hardpoint("autocannon", "right")
	rig.add_hardpoint("missilepod", "left")
	rig.fired.connect(_on_fired)
	print("[boot] headless=%s layers=%d hardpoints=%d" % [_headless, rig.get_layer_count(), rig.get_hardpoint_count()])

func _on_fired(_i: int, muzzle: Vector2, _aim: Vector2) -> void:
	_fires += 1
	# muzzle must be a finite world position (guards the tip math)
	if not (is_finite(muzzle.x) and is_finite(muzzle.y)):
		push_error("fired with non-finite muzzle position")

func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	var mv: Vector2 = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	if mv.length() > 0.1:
		rig.velocity = mv.normalized() * 200.0
		rig.aim_dir = mv
	else:
		var ang: float = _t * 0.8
		rig.velocity = Vector2(cos(ang), sin(ang)) * 190.0
		rig.aim_dir = Vector2(cos(_t * 1.6), sin(_t * 1.6))
	if _frames % 40 == 0:
		rig.fire(0)
	if _frames % 55 == 0:
		rig.fire(1)
	queue_redraw()
	if _headless:
		if _frames % 60 == 0:
			print("[rig] f=%d t=%.1f aim=%d deg layers=%d hp=%d fires=%d" % [
				_frames, _t, int(rad_to_deg(rig.aim_dir.angle())),
				rig.get_layer_count(), rig.get_hardpoint_count(), _fires])
		if _frames >= 240:
			_finish()

func _finish() -> void:
	var ok: bool = true
	var why: Array[String] = []
	if rig.get_layer_count() != EXPECT_LAYERS:
		ok = false; why.append("layers=%d expected %d" % [rig.get_layer_count(), EXPECT_LAYERS])
	if rig.get_hardpoint_count() != EXPECT_HARDPOINTS:
		ok = false; why.append("hardpoints=%d expected %d" % [rig.get_hardpoint_count(), EXPECT_HARDPOINTS])
	if _fires <= 0:
		ok = false; why.append("no fire events")
	if rig.frame_px <= 0.0:
		ok = false; why.append("bad frame_px")
	if ok:
		print("[rig] SMOKE PASS — layers=%d hardpoints=%d fires=%d" % [
			rig.get_layer_count(), rig.get_hardpoint_count(), _fires])
		get_tree().quit(0)
	else:
		print("[rig] SMOKE FAIL — " + ", ".join(why))
		get_tree().quit(1)

func _draw() -> void:
	if _headless:
		return
	var sz: Vector2 = get_viewport_rect().size
	var col: Color = Color(0.13, 0.13, 0.2, 0.5)
	var step: int = 64
	var x: int = 0
	while x < int(sz.x):
		draw_line(Vector2(x, 0), Vector2(x, sz.y), col, 1.0)
		x += step
	var y: int = 0
	while y < int(sz.y):
		draw_line(Vector2(0, y), Vector2(sz.x, y), col, 1.0)
		y += step
