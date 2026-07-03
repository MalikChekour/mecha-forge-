extends Node2D
## Rig sandbox + headless smoke harness — CUSTOMIZATION DEMO.
## Two chassis, two loadouts, one part-layer system:
##   VANGUARD (blue, crest head)  : rotary autocannon + missile pod
##   TITAN    (olive heavy, bunker): railgun + plasmacaster (slower, heavier gait)
## Desktop/web: auto-demo (arrows drive the vanguard). Headless (--autoplay):
## asserts real invariants per rig and exits 0/1 accordingly.

const EXPECT_LAYERS: int = 7
const EXPECT_HARDPOINTS: int = 2

var rigs: Array[MechaRig] = []
var _fires: Dictionary = {}      # rig index -> count
var _t: float = 0.0
var _frames: int = 0
var _headless: bool = false

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--autoplay")
	var sz: Vector2 = get_viewport_rect().size
	_spawn("vanguard", Vector2(sz.x * 0.32, sz.y * 0.55), [["autocannon", "right"], ["missilepod", "left"]])
	_spawn("titan", Vector2(sz.x * 0.68, sz.y * 0.55), [["railgun", "right"], ["plasmacaster", "left"]])
	for i in rigs.size():
		print("[boot] rig=%s layers=%d hardpoints=%d" % [rigs[i].chassis, rigs[i].get_layer_count(), rigs[i].get_hardpoint_count()])

func _spawn(chassis_id: String, pos: Vector2, loadout: Array) -> void:
	var rig: MechaRig = MechaRig.new()
	rig.chassis = chassis_id
	rig.display_height = 250.0
	rig.position = pos
	add_child(rig)
	for w in loadout:
		rig.add_hardpoint(String(w[0]), String(w[1]))
	var idx: int = rigs.size()
	_fires[idx] = 0
	rig.fired.connect(func(_i: int, muzzle: Vector2, _aim: Vector2) -> void:
		_fires[idx] = int(_fires[idx]) + 1
		if not (is_finite(muzzle.x) and is_finite(muzzle.y)):
			push_error("non-finite muzzle position on rig %d" % idx))
	rigs.append(rig)

func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	# vanguard: player-drivable, else auto-demo
	var mv: Vector2 = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	var v: MechaRig = rigs[0]
	if mv.length() > 0.1:
		v.velocity = mv.normalized() * 200.0
		v.aim_dir = mv
	else:
		var a1: float = _t * 0.8
		v.velocity = Vector2(cos(a1), sin(a1)) * 190.0
		v.aim_dir = Vector2(cos(_t * 1.4), sin(_t * 1.4))
	# titan: always auto, slower drift (heavy class)
	var t2: MechaRig = rigs[1]
	var a2: float = _t * 0.5 + PI
	t2.velocity = Vector2(cos(a2), sin(a2)) * 150.0
	t2.aim_dir = Vector2(cos(_t * 0.9 + 1.0), sin(_t * 0.9 + 1.0))
	# staggered fire across all four hardpoints
	if _frames % 40 == 0:
		v.fire(0)
	if _frames % 55 == 0:
		v.fire(1)
	if _frames % 70 == 5:
		t2.fire(0)
	if _frames % 62 == 20:
		t2.fire(1)
	queue_redraw()
	if _headless:
		if _frames % 60 == 0:
			print("[rig] f=%d fires=%s" % [_frames, str(_fires)])
		if _frames >= 300:
			_finish()

func _finish() -> void:
	var ok: bool = true
	var why: Array[String] = []
	for i in rigs.size():
		var r: MechaRig = rigs[i]
		if r.get_layer_count() != EXPECT_LAYERS:
			ok = false; why.append("%s layers=%d" % [r.chassis, r.get_layer_count()])
		if r.get_hardpoint_count() != EXPECT_HARDPOINTS:
			ok = false; why.append("%s hardpoints=%d" % [r.chassis, r.get_hardpoint_count()])
		if int(_fires[i]) <= 0:
			ok = false; why.append("%s never fired" % r.chassis)
		if r.frame_px <= 0.0:
			ok = false; why.append("%s bad frame_px" % r.chassis)
	if ok:
		print("[rig] SMOKE PASS — 2 chassis x (%d layers, %d hardpoints), fires=%s" % [
			EXPECT_LAYERS, EXPECT_HARDPOINTS, str(_fires)])
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
	# labels under each mecha
	var f: Font = ThemeDB.fallback_font
	for r in rigs:
		var label: String = r.chassis.to_upper()
		var tw: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
		draw_string(f, r.position + Vector2(-tw / 2.0, 170), label,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.6, 0.75, 0.9, 0.8))
	var title: String = "MECHA-FORGE — layered rig demo: 2 chassis, 4 visible hardpoints, procedural gait"
	draw_string(f, Vector2(24, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.75, 0.85, 1.0, 0.9))
	draw_string(f, Vector2(24, 66), "Arrows drive the VANGUARD. Everything is assembled at runtime — no baked spritesheets.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.55, 0.62, 0.8, 0.8))
