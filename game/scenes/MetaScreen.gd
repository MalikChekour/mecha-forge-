extends CanvasLayer
class_name MetaScreen
## End-of-run screen: optional revive (watch-ad stub), then the persistent talent shop
## (spend banked scrap) and a Replay button. This is the between-runs retention loop.

var game: Node
var died: bool = false
var _revive_ok: bool = false

func setup(g: Node, d: bool, revive_available: bool) -> void:
	game = g
	died = d
	_revive_ok = revive_available
	layer = 40
	if died and revive_available:
		_build_revive()
	else:
		_build_shop()

func _clear() -> void:
	for c in get_children():
		c.queue_free()

func _scaffold(min_w: float = 540.0) -> VBoxContainer:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.07, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v: VBoxContainer = VBoxContainer.new()
	v.custom_minimum_size = Vector2(min_w, 0)
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)
	return v

func _title(v: VBoxContainer, text: String, color: Color, size: int = 40) -> void:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	v.add_child(l)

func _big_button(v: VBoxContainer, text: String, cb: Callable, color: Color = Color(0.2, 0.55, 0.95)) -> void:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(cb)
	v.add_child(b)

# --- revive prompt (death only, once per run) ---
func _build_revive() -> void:
	_clear()
	var v: VBoxContainer = _scaffold()
	_title(v, "MECHA DÉTRUIT", Color(1.0, 0.5, 0.4))
	_title(v, "Une seconde chance ?", Color(0.85, 0.9, 1.0), 22)
	_big_button(v, "REVIVRE  (pub)", _on_revive, Color(0.2, 0.7, 0.4))
	_big_button(v, "Abandonner", _on_abandon, Color(0.4, 0.4, 0.5))

func _on_revive() -> void:
	if game != null and game.has_method("revive_player"):
		game.revive_player()
	queue_free()

func _on_abandon() -> void:
	_build_shop()

# --- talent shop + replay ---
func _build_shop() -> void:
	if game != null and game.has_method("ensure_banked"):
		game.ensure_banked()   # bank the run's scrap so it's spendable here
	_clear()
	var v: VBoxContainer = _scaffold(560.0)
	if died:
		_title(v, "MECHA DÉTRUIT", Color(1.0, 0.5, 0.4))
	else:
		_title(v, "VICTOIRE !", Color(1.0, 0.9, 0.45))
	_title(v, "Niveau %d · %d kills · %ds" % [GameState.level, GameState.kills, int(GameState.run_time)], Color(0.8, 0.85, 0.95), 20)
	_title(v, "%d  ferraille" % int(SaveManager.data.get("meta_scrap", 0)), Color(0.6, 0.9, 1.0), 26)

	for id: String in GameState.META:
		var d: Dictionary = GameState.META[id]
		var lvl: int = SaveManager.meta_level(id)
		var maxl: int = int(d["max"])
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_l: Label = Label.new()
		name_l.text = "%s   [%d/%d]" % [String(d["name"]), lvl, maxl]
		name_l.custom_minimum_size = Vector2(340, 0)
		name_l.add_theme_font_size_override("font_size", 20)
		row.add_child(name_l)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(160, 44)
		if lvl >= maxl:
			b.text = "MAX"
			b.disabled = true
		else:
			var cost: int = int(d["cost"][lvl])
			b.text = "%d" % cost
			b.disabled = int(SaveManager.data.get("meta_scrap", 0)) < cost
			b.pressed.connect(_buy.bind(id, cost))
		row.add_child(b)
		v.add_child(row)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	v.add_child(spacer)
	_big_button(v, "REJOUER", _replay, Color(0.2, 0.6, 0.95))

func _buy(id: String, cost: int) -> void:
	if SaveManager.buy_meta(id, cost):
		_build_shop()   # refresh levels + scrap + button states

func _replay() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
