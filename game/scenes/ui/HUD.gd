extends CanvasLayer
class_name HUD
## In-run HUD: HP/XP bars, run timer, level/kills/scrap, a touch-stick ring, and the
## level-up DRAFT-of-3 overlay (pauses the tree, real buttons — also drivable by the
## headless bot via pick()).

signal card_picked(index: int)

var player: Player
var _hp_fill: ColorRect
var _xp_fill: ColorRect
var _timer_lbl: Label
var _stat_lbl: Label
var _draft_root: Control
var _card_btns: Array[Button] = []
const BAR_W: float = 360.0

func setup(p: Player) -> void:
	player = p
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Events.run_time_changed.connect(_on_time)
	Events.player_damaged.connect(func(_hp: float, _mx: float) -> void: _update_hp())
	Events.xp_gained.connect(func(_a: int) -> void: _update_xp())
	Events.level_up.connect(func(_l: int) -> void: _update_xp())
	_update_hp()
	_update_xp()

func _rect(parent: Node, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var c: ColorRect = ColorRect.new()
	c.color = col
	c.position = pos
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_rect(root, Vector2(0, 0), Vector2(1280, 52), Color(0, 0, 0, 0.32))
	_rect(root, Vector2(16, 12), Vector2(BAR_W, 15), Color(0.22, 0.05, 0.05, 0.9))
	_hp_fill = _rect(root, Vector2(16, 12), Vector2(BAR_W, 15), Color(0.92, 0.26, 0.2, 1))
	_rect(root, Vector2(16, 31), Vector2(BAR_W, 8), Color(0.05, 0.12, 0.2, 0.9))
	_xp_fill = _rect(root, Vector2(16, 31), Vector2(0, 8), Color(0.15, 0.85, 1, 1))

	_timer_lbl = Label.new()
	_timer_lbl.position = Vector2(596, 10)
	_timer_lbl.add_theme_font_size_override("font_size", 26)
	_timer_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1))
	root.add_child(_timer_lbl)

	_stat_lbl = Label.new()
	_stat_lbl.position = Vector2(410, 15)
	_stat_lbl.add_theme_color_override("font_color", Color(0.6, 0.72, 0.9))
	root.add_child(_stat_lbl)

	_draft_root = Control.new()
	_draft_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft_root.visible = false
	add_child(_draft_root)

func _update_hp() -> void:
	if player != null and _hp_fill != null:
		_hp_fill.size.x = BAR_W * clampf(player.hp / maxf(1.0, player.max_hp), 0.0, 1.0)

func _update_xp() -> void:
	if _xp_fill != null:
		_xp_fill.size.x = BAR_W * clampf(float(GameState.xp) / maxf(1.0, float(GameState.xp_to_next)), 0.0, 1.0)

func _on_time(t: float) -> void:
	_timer_lbl.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]
	_stat_lbl.text = "Lv %d   Kills %d   Scrap %d" % [GameState.level, GameState.kills, GameState.scrap]

func show_draft(cards: Array) -> void:
	for ch in _draft_root.get_children():
		ch.queue_free()
	_card_btns.clear()
	var panel: ColorRect = _rect(_draft_root, Vector2(340, 190), Vector2(600, 340), Color(0.06, 0.08, 0.14, 0.96))
	var title: Label = Label.new()
	title.text = "AMÉLIORATION — Niveau %d" % GameState.level
	title.position = Vector2(360, 205)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.15, 0.85, 1))
	_draft_root.add_child(title)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	for i in cards.size():
		var b: Button = Button.new()
		b.text = String(cards[i].get("name", "?"))
		b.position = Vector2(365, 255 + i * 82)
		b.size = Vector2(550, 68)
		b.add_theme_font_size_override("font_size", 20)
		var idx: int = i
		b.pressed.connect(func() -> void: _pick(idx))
		_draft_root.add_child(b)
		_card_btns.append(b)
	_draft_root.visible = true

func pick(i: int) -> void:      # headless bot entry point
	if _draft_root.visible:
		_pick(i)

func _pick(i: int) -> void:
	_draft_root.visible = false
	card_picked.emit(i)
