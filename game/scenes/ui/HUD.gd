extends CanvasLayer
class_name HUD
## In-run HUD: HP/XP bars, run timer, level/kills/scrap, a touch-stick ring, and the
## level-up DRAFT-of-3 overlay (pauses the tree, real buttons — also drivable by the
## headless bot via pick()).

signal card_picked(index: int)
signal reroll_requested()
signal banish_requested(index: int)

var _banish_mode: bool = false
var _draft_cards: Array = []
var _draft_rerolls: int = 0
var _draft_banishes: int = 0

var player: Player
var _hp_fill: ColorRect
var _xp_fill: ColorRect
var _od_fill: ColorRect
var _od_lbl: Label
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
	Events.overdrive_changed.connect(_on_overdrive)
	_update_hp()
	_update_xp()

func _on_overdrive(v: float) -> void:
	if _od_fill != null:
		_od_fill.size.x = BAR_W * clampf(v, 0.0, 1.0)
	if _od_lbl != null:
		_od_lbl.visible = v >= 1.0

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
	_rect(root, Vector2(16, 31), Vector2(BAR_W, 7), Color(0.05, 0.12, 0.2, 0.9))
	_xp_fill = _rect(root, Vector2(16, 31), Vector2(0, 7), Color(0.15, 0.85, 1, 1))
	_rect(root, Vector2(16, 41), Vector2(BAR_W, 6), Color(0.22, 0.14, 0.03, 0.9))
	_od_fill = _rect(root, Vector2(16, 41), Vector2(0, 6), Color(1.0, 0.72, 0.16, 1))
	_od_lbl = Label.new()
	_od_lbl.position = Vector2(16, 52)
	_od_lbl.add_theme_font_size_override("font_size", 17)
	_od_lbl.add_theme_color_override("font_color", Color(1, 0.75, 0.2))
	_od_lbl.text = "⚡ OVERDRIVE — ESPACE"
	_od_lbl.visible = false
	root.add_child(_od_lbl)

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

func show_draft(cards: Array, rerolls: int = 0, banishes: int = 0) -> void:
	_draft_cards = cards
	_draft_rerolls = rerolls
	_draft_banishes = banishes
	_banish_mode = false
	_render_draft()

func _render_draft() -> void:
	for ch in _draft_root.get_children():
		ch.queue_free()
	_card_btns.clear()
	var cards: Array = _draft_cards
	var panel: ColorRect = _rect(_draft_root, Vector2(340, 175), Vector2(600, 410), Color(0.06, 0.08, 0.14, 0.96))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var title: Label = Label.new()
	title.text = "CHOISIS UNE CARTE A BANNIR" if _banish_mode else "AMÉLIORATION — Niveau %d" % GameState.level
	title.position = Vector2(360, 195)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if _banish_mode else Color(0.15, 0.85, 1))
	_draft_root.add_child(title)
	for i in cards.size():
		var b: Button = Button.new()
		var is_evo: bool = bool(cards[i].get("evo", false))
		b.text = ("BANNIR : " if _banish_mode else "") + String(cards[i].get("name", "?"))
		b.position = Vector2(365, 238 + i * 76)
		b.size = Vector2(550, 62)
		b.add_theme_font_size_override("font_size", 20)
		if is_evo and not _banish_mode:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))   # gold evolution
		var idx: int = i
		if _banish_mode:
			b.disabled = is_evo   # evolutions can't be banished
			b.pressed.connect(func() -> void: banish_requested.emit(idx))
		else:
			b.pressed.connect(func() -> void: _pick(idx))
		_draft_root.add_child(b)
		_card_btns.append(b)
	var by: float = 238 + cards.size() * 76 + 8
	var rb: Button = Button.new()
	rb.text = "Relancer  (%d)" % _draft_rerolls
	rb.position = Vector2(365, by); rb.size = Vector2(268, 42)
	rb.add_theme_font_size_override("font_size", 18)
	rb.disabled = _draft_rerolls <= 0 or _banish_mode
	rb.pressed.connect(func() -> void: reroll_requested.emit())
	_draft_root.add_child(rb)
	var bb: Button = Button.new()
	bb.text = "Annuler" if _banish_mode else "Bannir  (%d)" % _draft_banishes
	bb.position = Vector2(647, by); bb.size = Vector2(268, 42)
	bb.add_theme_font_size_override("font_size", 18)
	bb.disabled = _draft_banishes <= 0 and not _banish_mode
	bb.pressed.connect(func() -> void:
		_banish_mode = not _banish_mode
		_render_draft())
	_draft_root.add_child(bb)
	_draft_root.visible = true

func pick(i: int) -> void:      # headless bot entry point
	if _draft_root.visible:
		_pick(i)

func _pick(i: int) -> void:
	_draft_root.visible = false
	card_picked.emit(i)
