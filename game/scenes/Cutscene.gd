extends CanvasLayer
class_name Cutscene
## Survivor.io-style in-engine cutscene: a sequence of full-screen key-art panels with a slow
## Ken-Burns push, a caption (title + line), fade transitions, tap-to-advance and a PASSER (skip)
## button. Used for the opening story AND for the per-map intro/outro beats.
##
## play([{tex, title, text, ken}], on_done): pauses the tree while it runs and restores the PREVIOUS
## pause state on finish, so it works both from the (already-paused) menu and mid-run (resumes play).
## No-ops instantly in headless/bot so the smoke soak never stalls on a panel.
##
## 🚨 DEFAUT BLOQUANT CORRIGE (testeur « nouveau joueur ») : la cinematique n'avancait QUE sur
## un clic/tap. Un joueur qui ne touche pas l'ecran restait bloque A VIE sur le premier panneau
## — captures identiques a l'octet de 16 s a 60 s. Il y a desormais (a) une AVANCE AUTOMATIQUE
## chronometree sur la longueur du texte, (b) une barre de progression visible, (c) un indice
## « Touchez pour continuer » qui pulse. Le tap reste prioritaire : il coupe court a l'attente.

signal finished

const DWELL_MIN: float = 4.2      # secondes minimum sur un panneau
const DWELL_PER_CHAR: float = 0.055
const DWELL_MAX: float = 11.0

var _panels: Array = []
var _idx: int = -1
var _busy: bool = false
var _was_paused: bool = false
var _kb: Tween = null
var _dwell: float = 0.0           # duree prevue du panneau courant
var _elapsed: float = 0.0         # temps passe dessus
var _hud_hidden: Node = null      # HUD masque pendant la cinematique (restaure a la fin)

var _bg: ColorRect
var _tex: TextureRect
var _cap: PanelContainer
var _title_l: Label
var _text_l: Label
var _hint_l: Label
var _catch: Control
var _fade: ColorRect
var _prog_bg: ColorRect
var _prog: ColorRect
var _skip: Button

## panels: Array of Dictionaries {tex: Texture2D, title: String, text: String, ken: String}
## ken ∈ {"in","out","left","right","up"} (default "in").
func play(panels: Array) -> void:
	_panels = panels.filter(func(p): return p.get("tex") != null)   # drop missing art gracefully
	if _panels.is_empty() or _is_bot():
		# nothing to show (or automated run) -> finish next frame so callers can await safely
		call_deferred("_bail")
		return
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS   # animate + take input while the tree is paused
	_was_paused = get_tree().paused
	get_tree().paused = true
	# Le HUD de partie (barres + OPTIONS + SURCHARGE) restait AU-DESSUS de la cinematique : en
	# plus de la rendre illisible, son bouton OPTIONS chevauchait PASSER sur 130x22 px, si bien
	# qu'un tap sur PASSER renvoyait au menu (mesure du testeur ergonomie).
	var h: Node = get_tree().get_first_node_in_group("hud")
	if h != null and "visible" in h and h.visible:
		h.visible = false
		_hud_hidden = h
	_build()
	get_viewport().size_changed.connect(_relayout)
	_advance()

func _is_bot() -> bool:
	return DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--autoplay")

func _bail() -> void:
	finished.emit()
	queue_free()

func _k() -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return clampf(minf(vp.x, vp.y) / 720.0, 0.62, 1.75)

func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_tex = TextureRect.new()
	_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# CONTAIN (letterbox), NOT cover: always show the WHOLE composed frame, with black bars when the
	# window aspect != the art's 16:9 (portrait phone, or a desktop window wider than 16:9). COVERED
	# was cropping the panels to a narrow slice off-16:9 — that was the "mal calibré".
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)

	# caption band, bottom
	_cap = PanelContainer.new()
	_cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cap.offset_left = 0.0
	_cap.offset_right = 0.0
	_cap.offset_bottom = 0.0
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.72)
	_cap.add_theme_stylebox_override("panel", sb)
	add_child(_cap)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_cap.add_child(vb)
	_title_l = Label.new()
	_title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_l.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	_title_l.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_l.add_theme_constant_override("outline_size", 6)
	vb.add_child(_title_l)
	_text_l = Label.new()
	_text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_l.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))
	_text_l.add_theme_color_override("font_outline_color", Color.BLACK)
	_text_l.add_theme_constant_override("outline_size", 4)
	vb.add_child(_text_l)
	# indice d'interaction : sans lui, rien ne disait au joueur que l'ecran repond au doigt
	_hint_l = Label.new()
	_hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_l.text = "Touchez pour continuer  ›"
	_hint_l.add_theme_color_override("font_color", Color(0.62, 0.78, 0.9))
	_hint_l.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_l.add_theme_constant_override("outline_size", 4)
	vb.add_child(_hint_l)

	# barre de progression du panneau : on VOIT que ca avance tout seul
	_prog_bg = ColorRect.new()
	_prog_bg.color = Color(1, 1, 1, 0.10)
	_prog_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prog_bg)
	_prog = ColorRect.new()
	_prog.color = Color(0.45, 0.85, 1.0, 0.75)
	_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prog)

	# tap-anywhere catcher (advances)
	_catch = Control.new()
	_catch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catch.mouse_filter = Control.MOUSE_FILTER_STOP
	_catch.gui_input.connect(_on_catch)
	add_child(_catch)

	# PASSER (skip all) — above the catcher so it gets its own taps
	_skip = Button.new()
	_skip.text = "PASSER  ›"
	_skip.modulate = Color(1, 1, 1, 0.8)
	_skip.pressed.connect(_finish)
	add_child(_skip)

	# transition veil (topmost, never eats input)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_relayout()

## Toutes les tailles passent par Palette.fs() et la hauteur du bandeau suit l'ecran :
## -190 px en dur mangeaient la moitie d'un ecran portrait.
func _relayout() -> void:
	if _cap == null or not is_inside_tree():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: float = _k()
	_title_l.add_theme_font_size_override("font_size", Palette.fs(26))
	_text_l.add_theme_font_size_override("font_size", Palette.fs(17))
	_hint_l.add_theme_font_size_override("font_size", Palette.fs(13))
	var sb: StyleBoxFlat = _cap.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.content_margin_left = 26.0 * k
		sb.content_margin_right = 26.0 * k
		sb.content_margin_top = 16.0 * k
		sb.content_margin_bottom = 20.0 * k
	# le bandeau ne depasse jamais 34 % de la hauteur (portrait compris)
	_cap.offset_top = -minf(vp.y * 0.34, maxf(150.0, 190.0 * k))

	var ph: float = maxf(3.0, 4.0 * k)
	_prog_bg.position = Vector2(0, vp.y - ph)
	_prog_bg.size = Vector2(vp.x, ph)
	_prog.position = Vector2(0, vp.y - ph)
	_prog.size = Vector2(0, ph)

	# PASSER : cible >= 48 dp, ancree en haut a droite avec une marge qui suit l'echelle
	var w: float = maxf(132.0, 150.0 * k)
	var h: float = maxf(48.0, 46.0 * k)
	_skip.add_theme_font_size_override("font_size", Palette.fs(15))
	_skip.size = Vector2(w, h)
	_skip.position = Vector2(vp.x - w - 18.0 * k, 18.0 * k)

func _process(delta: float) -> void:
	if _busy or _panels.is_empty() or _idx < 0:
		return
	_elapsed += delta
	if _prog != null and _prog_bg != null and _dwell > 0.0:
		_prog.size.x = _prog_bg.size.x * clampf(_elapsed / _dwell, 0.0, 1.0)
	if _hint_l != null:
		# plancher a 0,40 : a 0,10 (ancienne borne basse) l'indice devenait illisible au creux
		# de la pulsation — verifie sur capture au format 1280x720.
		_hint_l.modulate.a = 0.62 + 0.22 * sin(Time.get_ticks_msec() / 420.0)
	if _elapsed >= _dwell:
		_advance()

func _on_catch(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_advance()

## Clavier : Espace / Entree / Echap avancent aussi. Le testeur avait note qu'aucune
## touche ne faisait quoi que ce soit, ce qui rendait le blocage total au clavier.
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var kc: int = (e as InputEventKey).keycode
		if kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_KP_ENTER:
			_advance()
			get_viewport().set_input_as_handled()
		elif kc == KEY_ESCAPE:
			_finish()
			get_viewport().set_input_as_handled()

func _advance() -> void:
	if _busy:
		return
	if _idx >= _panels.size() - 1:
		_finish()
		return
	_busy = true
	var t: Tween = create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.22)
	t.tween_callback(_show_next)
	t.tween_property(_fade, "color:a", 0.0, 0.34)
	t.tween_callback(func() -> void: _busy = false)

func _show_next() -> void:
	_idx += 1
	var p: Dictionary = _panels[_idx]
	_tex.texture = p.get("tex")
	_title_l.text = String(p.get("title", ""))
	_text_l.text = String(p.get("text", ""))
	_cap.visible = _title_l.text != "" or _text_l.text != ""
	# temps de lecture proportionnel a la longueur du texte, borne des deux cotes
	var n: int = _title_l.text.length() + _text_l.text.length()
	_dwell = clampf(DWELL_MIN + float(n) * DWELL_PER_CHAR, DWELL_MIN, DWELL_MAX)
	_elapsed = 0.0
	if _prog != null:
		_prog.size.x = 0.0
	_start_kenburns(String(p.get("ken", "in")))

func _start_kenburns(mode: String) -> void:
	if _kb != null and _kb.is_valid():
		_kb.kill()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_tex.pivot_offset = vp * 0.5   # zoom from centre = the letterboxed image zooms symmetrically
	# ZOOM-ONLY Ken-Burns: panning a letterboxed panel would reveal the black bars unevenly, so we
	# only push/pull gently from the centre. "out" pulls back, everything else pushes in.
	var s0: float = 1.0
	var s1: float = 1.09
	if mode == "out":
		s0 = 1.09
		s1 = 1.0
	_tex.scale = Vector2(s0, s0)
	_tex.position = Vector2.ZERO
	_kb = create_tween()
	# la poussee dure exactement le temps d'affichage : plus de zoom fige en fin de panneau
	_kb.tween_property(_tex, "scale", Vector2(s1, s1), maxf(1.0, _dwell))

func _finish() -> void:
	if not is_inside_tree():
		return
	if _hud_hidden != null and is_instance_valid(_hud_hidden) and "visible" in _hud_hidden:
		_hud_hidden.visible = true
	get_tree().paused = _was_paused
	finished.emit()
	queue_free()
