extends CanvasLayer
class_name HUD
## In-run HUD: HP/XP/Overdrive bars, run timer, level/kills/scrap, the touch-stick ring, the
## DAMAGE feedback (red vignette + low-HP pulse) and the level-up DRAFT-of-3 overlay (pauses
## the tree, real buttons — also drivable by the headless bot via pick()).
##
## 🚨 TOUT est ANCRE et mis a l'echelle par Palette.fs()/_k().
## L'ancienne version ecrivait des positions ABSOLUES dans un espace fige 1280x720
## (barre du haut (0,0)-(1280,52), SURCHARGE en (1080,588), panneau de draft en (340,175)).
## Mesure par les testeurs : en 21:9 il manquait 400 px de barre et la carte d'amelioration
## etait decalee de 200 px ; en PORTRAIT (480x854 — atteignable, l'orientation du projet
## est 6 = capteur) tout se recroquevillait en haut a gauche, texte a ~7 px.
## Toute nouvelle position doit passer par des ancres, jamais par des pixels bruts.

signal card_picked(index: int)
signal reroll_requested()
signal banish_requested(index: int)

var _banish_mode: bool = false
var _draft_cards: Array = []
var _draft_rerolls: int = 0
var _draft_banishes: int = 0

var player: Player
var _root: Control
var _topbar: ColorRect
var _hp_fill: ColorRect
var _hp_ghost: ColorRect
var _hp_bg: ColorRect
var _xp_fill: ColorRect
var _xp_bg: ColorRect
var _od_fill: ColorRect
var _od_bg: ColorRect
var _od_lbl: Label
var _hp_lbl: Label      # libelle "VIE" a droite de la barre (rapport Manus 26/09, P1)
var _xp_lbl: Label      # libelle "XP"
var _bar_od_lbl: Label  # libelle "SURCHARGE" — nom distinct de _od_lbl ("SURCHARGE PRETE")
var _dock: Control
var _skill_btns: Array = []
var _od_btn: Button       # tactile trigger for Overdrive (mobile) — pulses when ready
var _menu_btn: Button     # opens the in-run settings panel
var _timer_lbl: Label
var _stat_lbl: Label
var _chip: Label
var _draft_root: Control
var _card_btns: Array[Button] = []
var _hurt: TextureRect    # red vignette — damage feedback + low-HP pulse
var _stick: Control       # virtual move-stick ring (touch)
var _aim_stick: Control   # virtual aim-stick ring (touch, right half of screen)
var _bar_w: float = 360.0
var _last_hp: float = -1.0
var _hurt_flash: float = 0.0
var _hp_overlay: Control   # 05/10, refonte UI hologramme : cadre + segments par-dessus la barre de vie
var _hud_glass: Panel      # 05/10 : "verre depoli" derriere horloge + stats

# Boss Health Bar HUD (alerte visuelle et barre de vie de boss pour mobiles)
var _boss_panel: Panel
var _boss_title: Label
var _boss_hp_bg: ColorRect
var _boss_hp_ghost: ColorRect
var _boss_hp_fill: ColorRect
var _active_boss: Enemy = null
var _last_boss_hp: float = -1.0
var _boss_radar: Control

## Cadre holographique + decoupe en segments par-dessus la barre de vie (demande du patron, 05/10 :
## "barre segmentee style tech/armure" au lieu d'un simple rectangle plein). Dessine PAR-DESSUS
## _hp_bg/_hp_fill sans jamais toucher leur logique de remplissage (_update_hp() reste inchange,
## continue de redimensionner _hp_fill.size.x) - un calque visuel en plus, rien d'autre. Meme astuce
## de "faux glow" (polyligne repetee a alpha decroissante) que HudTabFrame dans MetaScreen.gd, mais
## copiee ici plutot qu'importee : ce fichier a deja sa propre recette holographique independante
## (_render_draft() plus bas), meme convention qu'avant.
class HpSegments extends Control:
	const ACCENT: Color = Color(0.15, 0.85, 1.0)
	var segments: int = 8
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w <= 0.0 or h <= 0.0:
			return
		var pts: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h), Vector2(0, 0)])
		draw_polyline(pts, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.18), 6.0)
		draw_polyline(pts, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45), 3.0)
		draw_polyline(pts, Color(ACCENT.r, ACCENT.g, ACCENT.b, 1.0), 1.4)
		for i in range(1, segments):
			var x: float = w * float(i) / float(segments)
			draw_line(Vector2(x, 1.0), Vector2(x, h - 1.0), Color(0.0, 0.0, 0.0, 0.55), 2.0)
		var cl: float = minf(7.0, minf(w, h) * 0.35)
		draw_line(Vector2(0, cl), Vector2(0, 0), Color(1, 1, 1, 0.9), 2.0)
		draw_line(Vector2(0, 0), Vector2(cl, 0), Color(1, 1, 1, 0.9), 2.0)
		draw_line(Vector2(w - cl, h), Vector2(w, h), Color(1, 1, 1, 0.9), 2.0)
		draw_line(Vector2(w, h), Vector2(w, h - cl), Color(1, 1, 1, 0.9), 2.0)

## Safe Area pour encoches d'appareils mobiles (notches, barres de gestes) — compatible Godot 4.
func _safe_insets() -> Dictionary:
	var insets: Dictionary = {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if DisplayServer.has_method("get_display_safe_area"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var win: Vector2i = DisplayServer.window_get_size()
		if win.x > 0 and win.y > 0 and (safe.position != Vector2i.ZERO or safe.size != win):
			var vp: Vector2 = _vp()
			var sx: float = vp.x / float(win.x)
			var sy: float = vp.y / float(win.y)
			insets["left"] = maxf(0.0, float(safe.position.x) * sx)
			insets["top"] = maxf(0.0, float(safe.position.y) * sy)
			insets["right"] = maxf(0.0, float(win.x - safe.end.x) * sx)
			insets["bottom"] = maxf(0.0, float(win.y - safe.end.y) * sy)
	return insets

## Echelle d'interface commune (meme formule que Palette.fs / MetaScreen._ui_k).
func _k() -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return clampf(minf(vp.x, vp.y) / 720.0, 0.62, 1.75)

func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size

func setup(p: Player) -> void:
	player = p
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")   # la cinematique s'en sert pour masquer le HUD pendant qu'elle joue
	_build()
	Events.run_time_changed.connect(_on_time)
	Events.player_damaged.connect(_on_damaged)
	Events.xp_gained.connect(func(_a: int) -> void: _update_xp())
	Events.level_up.connect(func(_l: int) -> void: _update_xp())
	Events.overdrive_changed.connect(_on_overdrive)
	# B6 : le HUD restait affiche PAR-DESSUS l'ecran de fin de partie.
	Events.player_died.connect(_on_died)
	get_viewport().size_changed.connect(_relayout)
	_update_hp()
	_update_xp()

func _on_died() -> void:
	# l'ecran de resultats prend la main : plus rien du HUD ne doit rester dessus
	visible = false
	if _draft_root != null:
		_draft_root.visible = false
	if _boss_panel != null:
		_boss_panel.visible = false
	if _boss_radar != null:
		_boss_radar.visible = false

func _on_overdrive(v: float) -> void:
	if _od_fill != null and _od_bg != null:
		_od_fill.size.x = _od_bg.size.x * clampf(v, 0.0, 1.0)
	var ready: bool = v >= 1.0 and (player == null or not player.transformed)
	if _od_lbl != null:
		_od_lbl.visible = ready
	if _od_btn != null:
		_od_btn.visible = ready

func _process(delta: float) -> void:
	# pulse the Overdrive button so the player notices it's ready to tap
	if _od_btn != null and _od_btn.visible:
		var p: float = 0.78 + 0.22 * sin(Time.get_ticks_msec() / 140.0)
		_od_btn.modulate = Color(1, 1, 1, p)
	_update_hurt(delta)
	_update_boss_bar(delta)
	if _stick != null:
		_stick.queue_redraw()
	if _aim_stick != null:
		_aim_stick.queue_redraw()
	if _boss_radar != null:
		_boss_radar.queue_redraw()

## RETOUR DE DEGATS. Constat des testeurs : « sur une douzaine de captures ou la vie tombe de
## 100 % a 8 %, aucune image ne me dit que j'encaisse ». L'onde de blessure existante est CYAN,
## exactement la couleur de nos propres tirs. Ici : un vignettage ROUGE, franc au moment du coup,
## puis une pulsation permanente sous 30 % de vie.
func _update_hurt(delta: float) -> void:
	if _hurt == null:
		return
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.6)
	var low: float = 0.0
	if player != null and is_instance_valid(player) and player.max_hp > 0.0 and GameState.alive:
		var f: float = clampf(player.hp / player.max_hp, 0.0, 1.0)
		if f < 0.30:
			# plus la vie est basse, plus la pulsation est forte et rapide
			var sev: float = 1.0 - f / 0.30
			var spd: float = 3.2 + 3.4 * sev
			low = (0.16 + 0.30 * sev) * (0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * spd))
	_hurt.modulate.a = clampf(maxf(_hurt_flash, low), 0.0, 1.0)

func _on_damaged(hp: float, _mx: float) -> void:
	# player_damaged sert aussi au soin et a la regeneration : on ne flashe que si la vie BAISSE.
	if _last_hp >= 0.0 and hp < _last_hp - 0.01:
		_hurt_flash = 0.85
	_last_hp = hp
	_update_hp()

func _on_skill_pressed(id: String) -> void:
	if player != null and is_instance_valid(player) and player.has_method("use_skill"):
		player.use_skill(id)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_J: _on_skill_pressed("shield")
			KEY_K: _on_skill_pressed("special")
			KEY_L: _on_skill_pressed("jet")

func _on_od_pressed() -> void:
	if player != null and player.has_method("activate_overdrive"):
		player.activate_overdrive()

func _on_menu_pressed() -> void:
	if player != null and "game" in player and player.game != null and player.game.has_method("show_settings"):
		player.game.show_settings()

## Meme recette holographique que _render_draft() plus bas (cyan neon, coins arrondis, halo) -
## centralisee ici (05/10) pour que le cadre horloge/stats reste visuellement identique au reste.
func _holo_style(bg_a: float = 0.85, corner: float = 10.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.12, bg_a)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.15, 0.85, 1.0, 0.8)
	sb.corner_radius_top_left = corner; sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner; sb.corner_radius_bottom_right = corner
	sb.shadow_color = Color(0.15, 0.85, 1.0, 0.3)
	sb.shadow_size = 10
	return sb

func _rect(parent: Node, col: Color) -> ColorRect:
	var c: ColorRect = ColorRect.new()
	c.color = col
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

## Petit libelle nomme une barre du bandeau (VIE/XP/SURCHARGE) — position calculee en _relayout.
func _bar_label(txt: String, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

## Vignette radiale rouge, sans shader : un GradientTexture2D en remplissage radial,
## transparent au centre et opaque sur les bords.
func _make_vignette() -> TextureRect:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([
		Color(0.9, 0.05, 0.05, 0.0),
		Color(0.85, 0.04, 0.04, 0.20),
		Color(0.75, 0.02, 0.02, 0.95)])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 192
	gt.height = 192
	var tr: TextureRect = TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	return tr

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- bandeau du haut (ancre TOP_WIDE : suit TOUTE la largeur, quel que soit le format) ---
	_topbar = _rect(_root, Color(0, 0, 0, 0.38))
	_topbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hp_bg = _rect(_root, Color(0.22, 0.05, 0.05, 0.9))
	_hp_ghost = _rect(_root, Color(1.0, 1.0, 1.0, 0.85))
	_hp_fill = _rect(_root, Color(0.92, 0.26, 0.2, 1))
	_hp_overlay = HpSegments.new()
	_hp_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hp_overlay)
	_xp_bg = _rect(_root, Color(0.05, 0.12, 0.2, 0.9))
	_xp_fill = _rect(_root, Color(0.15, 0.85, 1, 1))
	_od_bg = _rect(_root, Color(0.22, 0.14, 0.03, 0.9))
	_od_fill = _rect(_root, Color(1.0, 0.72, 0.16, 1))

	# 🚨 Rapport de test Manus (26/09, P1) : « le joueur doit deduire qu'une barre correspond a
	# la vie, une autre a l'XP et une autre probablement a une energie » — les 3 barres du
	# bandeau n'etaient jamais nommees. Un mot court a droite de chacune, pas une refonte.
	_hp_lbl = _bar_label("VIE", Color(1.0, 0.55, 0.5))
	_xp_lbl = _bar_label("XP", Color(0.55, 0.9, 1.0))
	_bar_od_lbl = _bar_label("SURCHARGE", Color(1.0, 0.82, 0.4))

	_od_lbl = Label.new()
	_od_lbl.add_theme_color_override("font_color", Color(1, 0.78, 0.25))
	_od_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_od_lbl.add_theme_constant_override("outline_size", 4)
	_od_lbl.text = "SURCHARGE PRETE"
	_od_lbl.visible = false
	_od_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_od_lbl)

	# 05/10, refonte UI hologramme : conteneur "verre depoli" derriere horloge+stats, cree AVANT
	# les 2 labels pour etre plus bas dans l'ordre des enfants (= dessine derriere, jamais dessus).
	_hud_glass = Panel.new()
	_hud_glass.add_theme_stylebox_override("panel", _holo_style(0.5, 8.0))
	_hud_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud_glass)

	_timer_lbl = Label.new()
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	_timer_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_timer_lbl.add_theme_constant_override("outline_size", 5)
	_timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_timer_lbl)

	_stat_lbl = Label.new()
	_stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_lbl.add_theme_color_override("font_color", Color(0.72, 0.83, 0.98))
	_stat_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_stat_lbl.add_theme_constant_override("outline_size", 4)
	_stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stat_lbl)

	# PROTOCOLES du run — rappel permanent sous le bandeau.
	# 🚨 le glyphe ◈ (U+25C8) est ABSENT de Rajdhani ET d'Orbitron : il s'affichait en carre
	#    vide avec son code hexa. Verifie a fontTools : seul « • » (U+2022) existe partout.
	if Protocols.active.size() > 0:
		var pcol: Color = Color(Protocols.active[0].get("color", Color(0.9, 0.6, 0.3)))
		_chip = Label.new()
		_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chip.add_theme_color_override("font_color", Color(pcol.r, pcol.g, pcol.b, 0.9))
		_chip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_chip.add_theme_constant_override("outline_size", 4)
		_chip.text = "• " + Protocols.label()
		_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_chip)
		# The big one-shot ANNOUNCE is fired by Game._begin_run (sequenced after the sector title,
		# once the biome-intro card is gone) — not here, so it can't play hidden under the intro.

	# --- BANDEAU DE VIE BOSS (alerte holographique pour les menaces rank >= 3) ---
	_boss_panel = Panel.new()
	var bsb: StyleBoxFlat = StyleBoxFlat.new()
	bsb.bg_color = Color(0.10, 0.02, 0.04, 0.88)
	bsb.border_width_left = 2; bsb.border_width_right = 2
	bsb.border_width_top = 2; bsb.border_width_bottom = 2
	bsb.border_color = Color(1.0, 0.28, 0.22, 0.95)
	bsb.corner_radius_top_left = 8; bsb.corner_radius_top_right = 8
	bsb.corner_radius_bottom_left = 8; bsb.corner_radius_bottom_right = 8
	bsb.shadow_color = Color(1.0, 0.15, 0.15, 0.4)
	bsb.shadow_size = 10
	_boss_panel.add_theme_stylebox_override("panel", bsb)
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	_root.add_child(_boss_panel)

	_boss_title = Label.new()
	_boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_boss_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_boss_title.add_theme_constant_override("outline_size", 4)
	_boss_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_child(_boss_title)

	_boss_hp_bg = ColorRect.new()
	_boss_hp_bg.color = Color(0.18, 0.04, 0.04, 0.9)
	_boss_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_child(_boss_hp_bg)

	_boss_hp_ghost = ColorRect.new()
	_boss_hp_ghost.color = Color(1.0, 0.9, 0.7, 0.85)
	_boss_hp_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_child(_boss_hp_ghost)

	_boss_hp_fill = ColorRect.new()
	_boss_hp_fill.color = Color(0.95, 0.22, 0.16, 1.0)
	_boss_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_child(_boss_hp_fill)

	# --- vignette de degats (sous les boutons, au-dessus du jeu) ---
	_hurt = _make_vignette()
	_root.add_child(_hurt)

	# --- anneau du stick tactile : le testeur signalait qu'AUCUN stick n'etait dessine ---
	var sr: StickRing = StickRing.new()
	sr.hud = self
	_stick = sr
	_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stick)

	# --- anneau du stick de visee (patron, 25/09) : meme logique, cote droit de l'ecran ---
	var ar: AimStickRing = AimStickRing.new()
	ar.hud = self
	_aim_stick = ar
	_aim_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aim_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_aim_stick)

	# --- RADAR DE MENACE HORS-ECRAN (Offscreen Boss Radar pour confort mobile) ---
	var br: OffscreenBossRadar = OffscreenBossRadar.new()
	br.hud = self
	_boss_radar = br
	_boss_radar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_radar)

	# --- SURCHARGE : gros bouton ancre EN BAS A DROITE ---
	# Deux testeurs sur quatre l'ont dit illisible alors que c'est la SEULE action manuelle
	# du jeu. Il a maintenant un fond ambre plein + bordure, et il est ancre (avant : x=1080
	# en dur, soit 416 px du bord droit en 21:9).
	_od_btn = Button.new()
	_od_btn.text = "SURCHARGE"
	_od_btn.add_theme_color_override("font_color", Color(0.12, 0.06, 0.0))
	_od_btn.add_theme_color_override("font_color_hover", Color(0.12, 0.06, 0.0))
	_od_btn.add_theme_color_override("font_color_pressed", Color(0.12, 0.06, 0.0))
	for st: String in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.74, 0.18) if st != "pressed" else Color(1.0, 0.88, 0.45)
		sb.border_color = Color(1.0, 0.95, 0.72)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(6)
		_od_btn.add_theme_stylebox_override(st, sb)
	_od_btn.visible = false
	_od_btn.pressed.connect(_on_od_pressed)
	_root.add_child(_od_btn)

	# --- ONGLET DE COMPETENCES : cadre + 3 boutons (BOUCLIER / SPECIAL / JET PACK), ancre en bas a droite ---
	_dock = SkillDockFrame.new()
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dock)
	for sd: Array in [["shield", "BOUCLIER", "J", Color(0.4, 0.9, 1.0)], ["special", "SPECIAL", "K", Color(1.0, 0.7, 0.25)], ["jet", "JET PACK", "L", Color(1.0, 0.6, 0.2)]]:
		var sbtn: SkillButton = SkillButton.new()
		sbtn.skill_id = String(sd[0])
		sbtn.title = String(sd[1])
		sbtn.key_hint = String(sd[2])
		sbtn.col = sd[3]
		sbtn.player = player
		sbtn.activated.connect(_on_skill_pressed)
		_dock.add_child(sbtn)
		_skill_btns.append(sbtn)

	# OPTIONS button (top-right) — opens the in-run settings panel (music/sfx/auto-aim/orientation)
	_menu_btn = Button.new()
	_menu_btn.text = "OPTIONS"
	_menu_btn.pressed.connect(_on_menu_pressed)
	_root.add_child(_menu_btn)

	_draft_root = Control.new()
	_draft_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft_root.visible = false
	add_child(_draft_root)

	_relayout()

## Toute la geometrie vit ICI et se recalcule sur size_changed : portrait, 4:3, 16:9, 21:9.
func _relayout() -> void:
	if _root == null or not is_inside_tree():
		return
	var vp: Vector2 = _vp()
	var k: float = _k()
	var insets: Dictionary = _safe_insets()
	var pad: float = 14.0 * k
	var pad_left: float = pad + float(insets["left"])
	var pad_right: float = pad + float(insets["right"])
	var pad_top: float = pad * 0.8 + float(insets["top"])
	var pad_bottom: float = pad * 1.2 + float(insets["bottom"])
	var portrait: bool = vp.y > vp.x

	# largeur de barre PROPORTIONNELLE avec prise en compte de la safe area
	_bar_w = clampf((vp.x - pad_left - pad_right) * (0.56 if portrait else 0.30), 150.0, 460.0)
	var hp_h: float = maxf(12.0, 15.0 * k)
	var xp_h: float = maxf(6.0, 7.0 * k)
	var od_h: float = maxf(5.0, 6.0 * k)
	var gap: float = 4.0 * k
	var top: float = pad_top
	var bar_total: float = hp_h + xp_h + od_h + gap * 2.0
	var band_h: float = top + bar_total + pad * 0.7

	_topbar.offset_bottom = band_h
	_hp_bg.position = Vector2(pad_left, top)
	_hp_bg.size = Vector2(_bar_w, hp_h)
	_hp_ghost.position = _hp_bg.position
	_hp_ghost.size.y = hp_h
	_hp_fill.position = _hp_bg.position
	_hp_fill.size = Vector2(_bar_w, hp_h)
	_hp_overlay.position = _hp_bg.position
	_hp_overlay.size = _hp_bg.size
	_hp_overlay.queue_redraw()
	_xp_bg.position = Vector2(pad_left, top + hp_h + gap)
	_xp_bg.size = Vector2(_bar_w, xp_h)
	_xp_fill.position = _xp_bg.position
	_xp_fill.size = Vector2(0, xp_h)
	_od_bg.position = Vector2(pad_left, top + hp_h + xp_h + gap * 2.0)
	_od_bg.size = Vector2(_bar_w, od_h)
	_od_fill.position = _od_bg.position
	_od_fill.size = Vector2(0, od_h)

	# libelles a droite de chaque barre
	var lbl_x: float = pad_left + _bar_w + 8.0 * k
	var lbl_fs: float = maxf(10.0, 11.0 * k)
	var lbl_w: float = maxf(40.0, vp.x - lbl_x - pad_right)
	for pair in [[_hp_lbl, _hp_bg], [_xp_lbl, _xp_bg], [_bar_od_lbl, _od_bg]]:
		var lbl: Label = pair[0]
		var bg: ColorRect = pair[1]
		lbl.add_theme_font_size_override("font_size", lbl_fs)
		lbl.position = Vector2(lbl_x, bg.position.y - (lbl_fs - bg.size.y) * 0.5)
		lbl.size = Vector2(lbl_w, maxf(bg.size.y, lbl_fs))

	# OPTIONS : ancre en haut a DROITE, cible tactile >= 48 dp
	var mb: Vector2 = Vector2(maxf(118.0, 134.0 * k), maxf(48.0, 44.0 * k))
	_menu_btn.add_theme_font_size_override("font_size", Palette.fs(15))
	_menu_btn.size = mb
	_menu_btn.position = Vector2(vp.x - mb.x - pad_right, top)

	# horloge + stats : centrees sur la largeur reelle
	_timer_lbl.add_theme_font_size_override("font_size", Palette.fs(24))
	_stat_lbl.add_theme_font_size_override("font_size", Palette.fs(14))
	var mid_x: float = _bar_w + pad_left + pad
	var mid_w: float = maxf(80.0, vp.x - mid_x - mb.x - pad_right - pad)

	_od_lbl.add_theme_font_size_override("font_size", Palette.fs(14))
	_chip_fs()
	var cur: float = band_h + 3.0 * k
	if portrait or mid_w < 150.0 * k:
		_timer_lbl.position = Vector2(0, cur)
		_timer_lbl.size = Vector2(vp.x, 0)
		cur += float(Palette.fs(24)) * 1.22
		_stat_lbl.position = Vector2(0, cur)
		_stat_lbl.size = Vector2(vp.x, 0)
		cur += float(Palette.fs(14)) * 1.35
	else:
		_timer_lbl.position = Vector2(mid_x, top - 2.0 * k)
		_timer_lbl.size = Vector2(mid_w, 0)
		_stat_lbl.position = Vector2(mid_x, top + float(Palette.fs(24)) * 1.15)
		_stat_lbl.size = Vector2(mid_w, 0)
	var glass_pad: float = 6.0 * k
	var th: float = float(Palette.fs(24)) * 1.22
	var sh: float = float(Palette.fs(14)) * 1.35
	var glass_w: float = (vp.x * 0.6) if portrait else mid_w
	var glass_x: float = ((vp.x - glass_w) * 0.5) if portrait else mid_x
	_hud_glass.position = Vector2(glass_x - glass_pad, _timer_lbl.position.y - glass_pad * 0.5)
	_hud_glass.size = Vector2(glass_w + glass_pad * 2.0, th + sh + glass_pad)

	_od_lbl.position = Vector2(pad_left, cur)
	cur += float(Palette.fs(14)) * 1.35
	if _chip != null:
		_chip.position = Vector2(0, cur)
		_chip.size = Vector2(vp.x, 0)
		cur += float(Palette.fs(13)) * 1.35
	if portrait:
		_topbar.offset_bottom = maxf(band_h, cur)

	# --- BANDEAU DE VIE DU BOSS (alerte menaces majeures) ---
	if _boss_panel != null:
		var bp_w: float = clampf((vp.x - pad_left - pad_right) * (0.86 if portrait else 0.46), 260.0, 520.0)
		var bp_h: float = maxf(40.0, 44.0 * k)
		var bp_x: float = (vp.x - bp_w) * 0.5
		var bp_y: float = (cur + 8.0 * k) if portrait else (band_h + 8.0 * k)
		_boss_panel.size = Vector2(bp_w, bp_h)
		_boss_panel.position = Vector2(bp_x, bp_y)
		var bh_pad: float = 8.0 * k
		var b_bar_w: float = bp_w - bh_pad * 2.0
		var b_bar_h: float = maxf(10.0, 12.0 * k)
		_boss_title.position = Vector2(bh_pad, 2.0 * k)
		_boss_title.size = Vector2(b_bar_w, maxf(16.0, 18.0 * k))
		_boss_title.add_theme_font_size_override("font_size", Palette.fs(13))
		var b_bar_y: float = bp_h - b_bar_h - bh_pad * 0.7
		_boss_hp_bg.position = Vector2(bh_pad, b_bar_y)
		_boss_hp_bg.size = Vector2(b_bar_w, b_bar_h)
		_boss_hp_ghost.position = _boss_hp_bg.position
		_boss_hp_ghost.size.y = b_bar_h
		_boss_hp_fill.position = _boss_hp_bg.position
		_boss_hp_fill.size.y = b_bar_h

	# SURCHARGE : ancre en bas a droite, cible tactile >= 48 dp
	var ob: Vector2 = Vector2(clampf(vp.x * 0.22, 150.0, 230.0), maxf(64.0, 78.0 * k))
	_od_btn.add_theme_font_size_override("font_size", Palette.fs(19))
	_od_btn.size = ob
	# dock de competences : bas droite avec marge safe area
	var bs: float = clampf(88.0 * k, 64.0, 110.0)
	var dgap: float = 10.0 * k
	var dock_w: float = bs * 3.0 + dgap * 4.0 + 8.0
	var dock_h: float = bs + 28.0 + 26.0 * k
	if _dock != null:
		_dock.size = Vector2(dock_w, dock_h)
		_dock.position = Vector2(vp.x - dock_w - pad_right, vp.y - dock_h - pad_bottom)
		for i in _skill_btns.size():
			var sb2: Control = _skill_btns[i]
			sb2.size = Vector2(bs, bs)
			sb2.position = Vector2(dgap + 4.0 + float(i) * (bs + dgap), 28.0)
	_od_btn.position = Vector2(vp.x - ob.x - pad_right, vp.y - dock_h - ob.y - pad_bottom - pad * 0.8)

	if _draft_root != null and _draft_root.visible:
		_render_draft()

func _update_boss_bar(_delta: float) -> void:
	if _boss_panel == null:
		return
	var boss: Enemy = null
	if _active_boss != null and is_instance_valid(_active_boss) and _active_boss.alive and _active_boss.rank >= 3:
		boss = _active_boss
	else:
		_active_boss = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and (e as Enemy).alive and (e as Enemy).rank >= 3:
				boss = e as Enemy
				_active_boss = boss
				_last_boss_hp = boss.hp
				break
	
	if boss != null and is_instance_valid(boss) and boss.alive and GameState.alive:
		if not _boss_panel.visible:
			_boss_panel.visible = true
			if _boss_hp_bg != null and _boss_hp_fill != null and _boss_hp_ghost != null:
				_boss_hp_fill.size.x = _boss_hp_bg.size.x
				_boss_hp_ghost.size.x = _boss_hp_bg.size.x
		var bname: String = String(boss.name_label) if "name_label" in boss and boss.name_label != "" else boss.kind.to_upper()
		_boss_title.text = "★ MENACE MAJEURE : %s ★" % bname
		if _boss_hp_bg != null and _boss_hp_fill != null and _boss_hp_ghost != null:
			var frac: float = clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0)
			var target_w: float = _boss_hp_bg.size.x * frac
			var cur_fill: float = _boss_hp_fill.size.x
			_boss_hp_fill.size.x = target_w
			if target_w < cur_fill - 1.0:
				_boss_hp_ghost.size.x = maxf(_boss_hp_ghost.size.x, cur_fill)
				var t: Tween = _boss_hp_ghost.create_tween()
				t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				t.tween_property(_boss_hp_ghost, "size:x", target_w, 0.35).set_delay(0.12).set_trans(Tween.TRANS_SINE)
			elif target_w > cur_fill:
				_boss_hp_ghost.size.x = target_w
	else:
		if _boss_panel.visible:
			_boss_panel.visible = false
			_active_boss = null

func _chip_fs() -> void:
	if _chip != null:
		_chip.add_theme_font_size_override("font_size", Palette.fs(13))

func _update_hp() -> void:
	if player != null and _hp_fill != null and _hp_ghost != null:
		var target_w: float = _bar_w * clampf(player.hp / maxf(1.0, player.max_hp), 0.0, 1.0)
		var current_fill: float = _hp_fill.size.x
		_hp_fill.size.x = target_w
		
		# Ghost bar (damage feedback)
		if target_w < current_fill:
			_hp_ghost.size.x = maxf(_hp_ghost.size.x, current_fill)
			var t: Tween = _hp_ghost.create_tween()
			t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			t.tween_property(_hp_ghost, "size:x", target_w, 0.4).set_delay(0.15).set_trans(Tween.TRANS_SINE)
		elif target_w > current_fill:
			_hp_ghost.size.x = target_w

func _update_xp() -> void:
	if _xp_fill != null:
		_xp_fill.size.x = _bar_w * clampf(float(GameState.xp) / maxf(1.0, float(GameState.xp_to_next)), 0.0, 1.0)

func _on_time(t: float) -> void:
	_timer_lbl.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]
	_stat_lbl.text = "Niv %d   ·   %d kills   ·   %d ferraille" % [GameState.level, GameState.kills, GameState.scrap]

func show_draft(cards: Array, rerolls: int = 0, banishes: int = 0) -> void:
	_draft_cards = cards
	_draft_rerolls = rerolls
	_draft_banishes = banishes
	_banish_mode = false
	_render_draft()

## Panneau de draft CENTRE et ancre (avant : (340,175) taille 600x410 en dur -> decale de
## 200 px en 21:9, et completement hors cadre en portrait).
func _render_draft() -> void:
	for ch in _draft_root.get_children():
		ch.queue_free()
	_card_btns.clear()
	var cards: Array = _draft_cards
	var vp: Vector2 = _vp()
	var k: float = _k()
	var pw: float = clampf(vp.x * 0.86, 280.0, 640.0)
	var row_h: float = maxf(64.0, 72.0 * k)
	var row_gap: float = 12.0 * k
	var mar: float = 20.0 * k

	# 1. Full-screen blur overlay
	var bg_blur: ColorRect = ColorRect.new()
	bg_blur.material = ShaderMaterial.new()
	bg_blur.material.shader = load("res://shaders/ui_blur.gdshader")
	bg_blur.color = Color.WHITE
	bg_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_blur.mouse_filter = Control.MOUSE_FILTER_STOP
	_draft_root.add_child(bg_blur)

	# 2. Holographic panel for the draft
	var panel: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.12, 0.85)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.15, 0.85, 1.0, 0.8) # Neon cyan border
	sb.corner_radius_top_left = 12; sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12; sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0.15, 0.85, 1.0, 0.3)
	sb.shadow_size = 15
	panel.add_theme_stylebox_override("panel", sb)
	_draft_root.add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(row_gap))
	_draft_root.add_child(vb)

	var title: Label = Label.new()
	title.text = "CHOISIS UNE CARTE A BANNIR" if _banish_mode else "AMÉLIORATION — Niveau %d" % GameState.level
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", Palette.fs(20))
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if _banish_mode else Color(0.15, 0.85, 1))
	vb.add_child(title)

	for i in cards.size():
		var b: Button = Button.new()
		var is_evo: bool = bool(cards[i].get("evo", false))
		var is_hybrid: bool = bool(cards[i].get("hybrid", false))
		var card_txt: String = ("BANNIR : " if _banish_mode else "") + String(cards[i].get("name", "?"))
		if cards[i].has("desc_evo"):
			card_txt += "\n" + String(cards[i]["desc_evo"])
		b.text = card_txt
		b.custom_minimum_size = Vector2(0, row_h)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", Palette.fs(16 if cards[i].has("desc_evo") else 17))
		
		# Holographic card styling
		var btn_sb: StyleBoxFlat = StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.02, 0.05, 0.1, 0.7)
		btn_sb.border_width_left = 1; btn_sb.border_width_right = 1
		btn_sb.border_width_top = 1; btn_sb.border_width_bottom = 1
		btn_sb.border_color = Color(0.2, 0.6, 0.8, 0.4)
		btn_sb.corner_radius_top_left = 6; btn_sb.corner_radius_bottom_right = 6
		btn_sb.corner_radius_top_right = 6; btn_sb.corner_radius_bottom_left = 6
		
		var btn_sb_hover: StyleBoxFlat = btn_sb.duplicate()
		btn_sb_hover.bg_color = Color(0.1, 0.25, 0.4, 0.8)
		btn_sb_hover.border_color = Color(0.15, 0.85, 1.0, 1.0)
		btn_sb_hover.shadow_color = Color(0.15, 0.85, 1.0, 0.5)
		btn_sb_hover.shadow_size = 8

		if is_evo and not _banish_mode:
			b.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))   # gold evolution
			btn_sb.border_color = Color(1.0, 0.82, 0.2, 0.85)
			btn_sb.border_width_left = 2; btn_sb.border_width_right = 2
			btn_sb.border_width_top = 2; btn_sb.border_width_bottom = 2
			btn_sb.shadow_color = Color(1.0, 0.75, 0.1, 0.35)
			btn_sb.shadow_size = 10
			btn_sb.bg_color = Color(0.12, 0.09, 0.03, 0.85)
			btn_sb_hover.bg_color = Color(0.22, 0.16, 0.05, 0.95)
			btn_sb_hover.border_color = Color(1.0, 0.92, 0.4, 1.0)
		elif is_hybrid and not _banish_mode:
			b.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))   # violet fusion hybride
			btn_sb.border_color = Color(0.75, 0.45, 1.0, 0.85)
			btn_sb.border_width_left = 2; btn_sb.border_width_right = 2
			btn_sb.border_width_top = 2; btn_sb.border_width_bottom = 2
			btn_sb.shadow_color = Color(0.75, 0.45, 1.0, 0.35)
			btn_sb.shadow_size = 10
			btn_sb.bg_color = Color(0.09, 0.04, 0.14, 0.85)
			btn_sb_hover.bg_color = Color(0.18, 0.08, 0.26, 0.95)
			btn_sb_hover.border_color = Color(0.85, 0.65, 1.0, 1.0)
		b.add_theme_stylebox_override("normal", btn_sb)
		b.add_theme_stylebox_override("hover", btn_sb_hover)
		b.add_theme_stylebox_override("pressed", btn_sb_hover)
		var idx: int = i
		if _banish_mode:
			b.disabled = is_evo or is_hybrid   # evolutions/fusions can't be banished
			b.pressed.connect(func() -> void: banish_requested.emit(idx))
		else:
			b.pressed.connect(func() -> void: _pick(idx))
		vb.add_child(b)
		_card_btns.append(b)

	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(row_gap))
	vb.add_child(hb)
	var rb: Button = Button.new()
	rb.text = "Relancer  (%d)" % _draft_rerolls
	rb.custom_minimum_size = Vector2(0, maxf(48.0, 44.0 * k))
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.add_theme_font_size_override("font_size", Palette.fs(15))
	rb.disabled = _draft_rerolls <= 0 or _banish_mode
	rb.pressed.connect(func() -> void: reroll_requested.emit())
	hb.add_child(rb)
	var bb: Button = Button.new()
	bb.text = "Annuler" if _banish_mode else "Bannir  (%d)" % _draft_banishes
	bb.custom_minimum_size = Vector2(0, maxf(48.0, 44.0 * k))
	bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bb.add_theme_font_size_override("font_size", Palette.fs(15))
	bb.disabled = _draft_banishes <= 0 and not _banish_mode
	bb.pressed.connect(func() -> void:
		_banish_mode = not _banish_mode
		_render_draft())
	hb.add_child(bb)

	# Hauteur CALCULEE, pas mesuree.
	# 🚨 get_combined_minimum_size() donnait une hauteur enorme (panneau occupant presque tout
	# l'ecran, verifie en capture portrait et 21:9) : les boutons ont autowrap_mode actif et
	# sont mesures a une largeur encore nulle, donc le texte « s'enroule » sur des dizaines de
	# lignes imaginaires. On additionne donc les hauteurs qu'on connait deja.
	var title_h: float = float(Palette.fs(20)) * 1.4
	var foot_h: float = maxf(48.0, 44.0 * k)
	var content_h: float = title_h + float(cards.size()) * row_h + foot_h \
		+ row_gap * float(cards.size() + 1)
	vb.size = Vector2(pw - mar * 2.0, 0)
	var ph: float = minf(vp.y * 0.92, content_h + mar * 2.0)
	var ox: float = (vp.x - pw) * 0.5
	var oy: float = (vp.y - ph) * 0.5
	panel.position = Vector2(ox, oy)
	panel.size = Vector2(pw, ph)
	vb.position = Vector2(ox + mar, oy + mar)
	vb.size = Vector2(pw - mar * 2.0, ph - mar * 2.0)
	_draft_root.visible = true

	# --- MOTION DESIGN ---
	Palette.fade_in(bg_blur)
	Palette.pop_in(panel)
	Palette.stagger_reveal(vb, 0.04, 0.08)

func pick(i: int) -> void:      # headless bot entry point
	if _draft_root.visible:
		_pick(i)

func _pick(i: int) -> void:
	_draft_root.visible = false
	card_picked.emit(i)

func show_lucky_chest(rewards: Array, count: int, scrap_bonus: int) -> void:
	for ch in _draft_root.get_children():
		ch.queue_free()
	_card_btns.clear()
	var vp: Vector2 = _vp()
	var k: float = _k()
	var pw: float = clampf(vp.x * 0.88, 300.0, 680.0)
	var row_h: float = maxf(60.0, 66.0 * k)
	var row_gap: float = 10.0 * k
	var mar: float = 20.0 * k

	# 1. Full-screen blur overlay
	var bg_blur: ColorRect = ColorRect.new()
	bg_blur.material = ShaderMaterial.new()
	bg_blur.material.shader = load("res://shaders/ui_blur.gdshader")
	bg_blur.color = Color.WHITE
	bg_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_blur.mouse_filter = Control.MOUSE_FILTER_STOP
	_draft_root.add_child(bg_blur)

	# 2. Golden Cybernetic Panel
	var panel: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.02, 0.92)
	sb.border_width_left = 3; sb.border_width_right = 3
	sb.border_width_top = 3; sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.82, 0.2, 0.95) # Radiant Gold border
	sb.corner_radius_top_left = 14; sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14; sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(1.0, 0.75, 0.1, 0.45)
	sb.shadow_size = 22
	panel.add_theme_stylebox_override("panel", sb)
	_draft_root.add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(row_gap))
	_draft_root.add_child(vb)

	var title: Label = Label.new()
	if count >= 5:
		title.text = "★ ★ ★ MEGA JACKPOT x5 ! ★ ★ ★"
		title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	elif count >= 3:
		title.text = "★ ★ SUPER COFFRE x3 ! ★ ★"
		title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	else:
		title.text = "★ COFFRE DE GUERRE ★"
		title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", Palette.fs(22))
	vb.add_child(title)

	var sub: Label = Label.new()
	sub.text = "Butin de Boss récupéré   ·   +%d Ferraille !" % scrap_bonus
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", Palette.fs(15))
	sub.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	vb.add_child(sub)

	for i in rewards.size():
		var r: Dictionary = rewards[i]
		var is_evo: bool = bool(r.get("evo", false))
		var card_p: Panel = Panel.new()
		var card_sb: StyleBoxFlat = StyleBoxFlat.new()
		card_sb.bg_color = Color(0.18, 0.13, 0.03, 0.8) if is_evo else Color(0.04, 0.08, 0.14, 0.8)
		card_sb.border_width_left = 2; card_sb.border_width_right = 2
		card_sb.border_width_top = 2; card_sb.border_width_bottom = 2
		card_sb.border_color = Color(1.0, 0.84, 0.2, 0.9) if is_evo else Color(0.2, 0.6, 0.85, 0.6)
		card_sb.corner_radius_top_left = 6; card_sb.corner_radius_bottom_right = 6
		card_sb.corner_radius_top_right = 6; card_sb.corner_radius_bottom_left = 6
		card_p.add_theme_stylebox_override("panel", card_sb)
		card_p.custom_minimum_size = Vector2(0, row_h)

		var lbl: Label = Label.new()
		lbl.text = ("★ ÉVOLUTION ULTIME : " if is_evo else "AMÉLIORATION : ") + String(r.get("name", "?"))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", Palette.fs(16))
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if is_evo else Color(0.85, 0.95, 1.0))
		card_p.add_child(lbl)
		vb.add_child(card_p)

	var claim_btn: Button = Button.new()
	claim_btn.text = "RÉCUPÉRER LE BUTIN"
	claim_btn.custom_minimum_size = Vector2(0, maxf(50.0, 48.0 * k))
	claim_btn.add_theme_font_size_override("font_size", Palette.fs(18))
	var btn_sb: StyleBoxFlat = StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.25, 0.18, 0.04, 0.9)
	btn_sb.border_color = Color(1.0, 0.85, 0.3, 1.0)
	btn_sb.border_width_left = 2; btn_sb.border_width_right = 2
	btn_sb.border_width_top = 2; btn_sb.border_width_bottom = 2
	btn_sb.corner_radius_top_left = 8; btn_sb.corner_radius_bottom_right = 8
	btn_sb.corner_radius_top_right = 8; btn_sb.corner_radius_bottom_left = 8
	btn_sb.shadow_color = Color(1.0, 0.8, 0.2, 0.5)
	btn_sb.shadow_size = 12
	claim_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_sb_h: StyleBoxFlat = btn_sb.duplicate()
	btn_sb_h.bg_color = Color(0.4, 0.28, 0.06, 0.95)
	btn_sb_h.border_color = Color(1.0, 0.95, 0.5, 1.0)
	claim_btn.add_theme_stylebox_override("hover", btn_sb_h)
	claim_btn.add_theme_stylebox_override("pressed", btn_sb_h)
	claim_btn.pressed.connect(func() -> void:
		_draft_root.visible = false
		if player != null and "game" in player and player.game != null and player.game.has_method("claim_lucky_chest"):
			player.game.claim_lucky_chest(rewards, scrap_bonus))
	vb.add_child(claim_btn)

	var title_h: float = float(Palette.fs(22)) * 1.5 + float(Palette.fs(15)) * 1.3
	var foot_h: float = maxf(50.0, 48.0 * k)
	var content_h: float = title_h + float(rewards.size()) * row_h + foot_h + row_gap * float(rewards.size() + 2)
	vb.size = Vector2(pw - mar * 2.0, 0)
	var ph: float = minf(vp.y * 0.94, content_h + mar * 2.0)
	var ox: float = (vp.x - pw) * 0.5
	var oy: float = (vp.y - ph) * 0.5
	panel.position = Vector2(ox, oy)
	panel.size = Vector2(pw, ph)
	vb.position = Vector2(ox + mar, oy + mar)
	vb.size = Vector2(pw - mar * 2.0, ph - mar * 2.0)
	_draft_root.visible = true

	Palette.fade_in(bg_blur)
	Palette.pop_in(panel)
	Palette.stagger_reveal(vb, 0.05, 0.1)


## Anneau du stick tactile. Le testeur « nouveau joueur » notait qu'aucun stick n'etait
## dessine : au doigt, rien ne confirme que le glissement est pris en compte.
## ======================= ONGLET DE COMPETENCES (17/10, patron : « un onglet bien evident, stylise, en bas a droite ») =======================
## Trois boutons hexagonaux (BOUCLIER / SPECIAL / JET PACK) dans un cadre holographique ; chacun affiche son icone, sa touche (J K L),
## un balayage de recharge et un halo qui pulse quand il est PRET. La SURCHARGE reste le gros bouton ambre juste au-dessus.
class SkillButton extends Control:
	var skill_id: String = ""
	var title: String = ""
	var key_hint: String = ""
	var col: Color = Color(0.4, 0.9, 1.0)
	var player: Player = null
	signal activated(id: String)
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			activated.emit(skill_id)
			accept_event()
	func _hex(c: Vector2, r: float) -> PackedVector2Array:
		var pts: PackedVector2Array = PackedVector2Array()
		for i in 6:
			var a: float = TAU * float(i) / 6.0 - PI / 2.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.46
		var ratio: float = player.skill_ratio(skill_id) if player != null and is_instance_valid(player) else 1.0
		var active: bool = ratio < 0.0
		var ready: bool = ratio >= 0.999
		var t: float = Time.get_ticks_msec() / 1000.0
		var hex: PackedVector2Array = _hex(c, r)
		if ready or active:
			var pulse: float = 0.5 + 0.5 * sin(t * (4.0 if ready else 12.0))
			for i in 4:
				draw_colored_polygon(_hex(c, r + 3.0 + float(i) * 3.5), Color(col.r, col.g, col.b, (0.10 + 0.10 * pulse) * (1.0 - float(i) / 4.0)))
		draw_colored_polygon(hex, Color(0.03, 0.07, 0.11, 0.92))
		if not ready and not active:
			var pie: PackedVector2Array = PackedVector2Array([c])
			var n: int = 40
			var sweep: float = TAU * (1.0 - ratio)
			for i in n + 1:
				var a2: float = -PI / 2.0 + sweep * float(i) / float(n)
				pie.append(c + Vector2(cos(a2), sin(a2)) * r * 0.98)
			draw_colored_polygon(pie, Color(0.0, 0.0, 0.0, 0.55))
		var line_col: Color = col if (ready or active) else Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 0.9)
		var hex_closed: PackedVector2Array = hex.duplicate()
		hex_closed.append(hex[0])
		draw_polyline(hex_closed, line_col, 3.0, true)
		var ic: Color = Color.WHITE if (ready or active) else Color(0.7, 0.75, 0.8, 0.8)
		var u: float = r * 0.42
		match skill_id:
			"shield":
				var sh: PackedVector2Array = PackedVector2Array([c + Vector2(-u, -u * 0.8), c + Vector2(u, -u * 0.8), c + Vector2(u, u * 0.1), c + Vector2(0, u * 1.1), c + Vector2(-u, u * 0.1)])
				draw_colored_polygon(sh, Color(col.r, col.g, col.b, 0.35))
				var shc: PackedVector2Array = sh.duplicate()
				shc.append(sh[0])
				draw_polyline(shc, ic, 2.5, true)
				draw_line(c + Vector2(0, -u * 0.6), c + Vector2(0, u * 0.6), ic, 2.0)
			"special":
				for i in 8:
					var a3: float = TAU * float(i) / 8.0
					var l: float = u * (1.25 if i % 2 == 0 else 0.7)
					draw_line(c + Vector2(cos(a3), sin(a3)) * u * 0.25, c + Vector2(cos(a3), sin(a3)) * l, ic, 3.0 if i % 2 == 0 else 2.0, true)
				draw_circle(c, u * 0.3, ic)
			"jet":
				for k2 in 2:
					var y0: float = -u * 0.7 + float(k2) * u * 0.7
					draw_polyline(PackedVector2Array([c + Vector2(-u * 0.8, y0 + u * 0.5), c + Vector2(0, y0 - u * 0.1), c + Vector2(u * 0.8, y0 + u * 0.5)]), ic, 3.0, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.3, u * 0.9), c + Vector2(0, u * 1.5 + 3.0 * sin(t * 25.0)), c + Vector2(u * 0.3, u * 0.9)]), Color(1.0, 0.6, 0.15, 0.9))
		var font: Font = ThemeDB.fallback_font
		var fs: int = int(maxf(10.0, r * 0.30))
		var tw: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, Vector2(c.x - tw.x * 0.5, size.y + fs * 1.1), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, 0.95))
		var kr: float = r * 0.30
		draw_circle(c + Vector2(r * 0.72, -r * 0.72), kr, Color(0.0, 0.0, 0.0, 0.8))
		draw_arc(c + Vector2(r * 0.72, -r * 0.72), kr, 0.0, TAU, 20, line_col, 2.0, true)
		var kw: Vector2 = font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_CENTER, -1, int(kr * 1.2))
		draw_string(font, c + Vector2(r * 0.72 - kw.x * 0.5, -r * 0.72 + kr * 0.42), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(kr * 1.2), Color.WHITE)
		if not ready and not active and player != null and is_instance_valid(player):
			var rem: float = float(player.skill_cd[skill_id])
			var txt: String = "%d" % int(ceil(rem))
			var rw: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, int(r * 0.55))
			draw_string(font, c + Vector2(-rw.x * 0.5, r * 0.20), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.55), Color(1, 1, 1, 0.92))

## Cadre du dock : plaque holographique a coins coupes, titre COMPETENCES, liseres lumineux.
class SkillDockFrame extends Control:
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var cut: float = 14.0
		var pts: PackedVector2Array = PackedVector2Array([Vector2(cut, 0), Vector2(w, 0), Vector2(w, h - cut), Vector2(w - cut, h), Vector2(0, h), Vector2(0, cut)])
		draw_colored_polygon(pts, Color(0.02, 0.06, 0.10, 0.80))
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		for i in 3:
			draw_polyline(closed, Color(0.15, 0.85, 1.0, 0.10 + 0.05 * float(2 - i)), 9.0 - 3.0 * float(i), true)
		draw_polyline(closed, Color(0.35, 0.92, 1.0, 0.95), 2.0, true)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(cut + 6.0, 15.0), "COMPETENCES", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.92, 1.0, 0.95))
		draw_line(Vector2(cut + 6.0, 20.0), Vector2(w - 10.0, 20.0), Color(0.35, 0.92, 1.0, 0.45), 1.0)

class StickRing extends Control:
	var hud: HUD
	func _draw() -> void:
		if hud == null or hud.player == null or not is_instance_valid(hud.player):
			return
		var p: Player = hud.player
		if p._stick_id == -1:
			return
		var o: Vector2 = p._stick_origin
		var v: Vector2 = p._stick_vec
		var r: float = Player.STICK_R
		draw_circle(o, r, Color(0.5, 0.8, 1.0, 0.10))
		draw_arc(o, r, 0.0, TAU, 48, Color(0.55, 0.85, 1.0, 0.55), 3.0, true)
		draw_circle(o + v * r, r * 0.36, Color(0.65, 0.9, 1.0, 0.40))
		draw_arc(o + v * r, r * 0.36, 0.0, TAU, 32, Color(0.8, 0.95, 1.0, 0.85), 3.0, true)

## Anneau du stick de visee manuelle (patron, 25/09 : "orienter la visee manuellement en
## ajoutant un deuxieme joystick, meme si la visee est automatique"). Meme geometrie que
## StickRing mais teinte chaude (orange), pour le distinguer du stick de deplacement (bleu) au
## premier coup d'oeil ; s'illumine encore plus fort pendant que le override manuel est actif
## (Player._aim_stick_active) pour confirmer que le doigt prend bien le pas sur l'auto-visee.
class AimStickRing extends Control:
	var hud: HUD
	func _draw() -> void:
		if hud == null or hud.player == null or not is_instance_valid(hud.player):
			return
		var p: Player = hud.player
		if p._aim_stick_id == -1:
			return
		var o: Vector2 = p._aim_stick_origin
		var v: Vector2 = p._aim_stick_vec
		var r: float = 80.0
		var a: float = 0.85 if p._aim_stick_active else 0.45   # brighter once past the deadzone
		draw_circle(o, r, Color(1.0, 0.55, 0.3, 0.10 * a))
		draw_arc(o, r, 0.0, TAU, 48, Color(1.0, 0.65, 0.35, 0.6 * a), 3.0, true)
		draw_circle(o + v * r, r * 0.36, Color(1.0, 0.7, 0.4, 0.40 * a))
		draw_arc(o + v * r, r * 0.36, 0.0, TAU, 32, Color(1.0, 0.8, 0.5, 0.9 * a), 3.0, true)

## Radar de menace hors-écran (Offscreen Boss Indicator).
## Alerte le joueur de l'arrivée d'un Boss/Élite majeur (rank >= 3) situé hors du champ visuel :
## flèche holographique néon orientée sur le bord d'écran, étiquette de distance en mètres,
## pulsation dynamique et prise en compte stricte des Safe Area mobiles.
class OffscreenBossRadar extends Control:
	var hud: HUD
	func _draw() -> void:
		if hud == null or hud.player == null or not is_instance_valid(hud.player) or not GameState.alive:
			return
		var boss: Enemy = hud._active_boss
		if boss == null or not is_instance_valid(boss) or not boss.alive or boss.rank < 3:
			return

		var vp: Vector2 = hud._vp()
		if vp.x <= 0.0 or vp.y <= 0.0:
			return

		var cam_xform: Transform2D = hud.player.get_viewport().get_canvas_transform()
		var screen_pos: Vector2 = cam_xform * boss.global_position

		var insets: Dictionary = hud._safe_insets()
		var pad_l: float = 38.0 + float(insets["left"])
		var pad_r: float = vp.x - 38.0 - float(insets["right"])
		var pad_t: float = 88.0 + float(insets["top"])
		var pad_b: float = vp.y - 48.0 - float(insets["bottom"])

		# Si le boss est visible à l'intérieur des marges, pas d'indicateur
		if screen_pos.x >= pad_l and screen_pos.x <= pad_r and screen_pos.y >= pad_t and screen_pos.y <= pad_b:
			return

		var center: Vector2 = vp * 0.5
		var dir: Vector2 = (screen_pos - center).normalized()
		if dir.length_squared() < 0.001:
			return

		var t_x: float = 1e9
		if dir.x > 0.0001:
			t_x = (pad_r - center.x) / dir.x
		elif dir.x < -0.0001:
			t_x = (pad_l - center.x) / dir.x

		var t_y: float = 1e9
		if dir.y > 0.0001:
			t_y = (pad_b - center.y) / dir.y
		elif dir.y < -0.0001:
			t_y = (pad_t - center.y) / dir.y

		var t_edge: float = minf(t_x, t_y)
		var edge_pt: Vector2 = center + dir * t_edge

		var world_dist: float = (boss.global_position - hud.player.global_position).length()
		var dist_m: int = int(round(world_dist / 40.0))

		var pulse: float = 0.80 + 0.20 * sin(Time.get_ticks_msec() / 130.0)
		var col_main: Color = Color(1.0, 0.24, 0.18, 0.95 * pulse)
		var col_gold: Color = Color(1.0, 0.88, 0.42, pulse)

		# Chevron directionnel
		var tip: Vector2 = edge_pt
		var base_pt: Vector2 = edge_pt - dir * 20.0
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var p1: Vector2 = base_pt + perp * 11.0
		var p2: Vector2 = base_pt - perp * 11.0
		var inner: Vector2 = base_pt + dir * 5.0
		var arrow_pts: PackedVector2Array = PackedVector2Array([tip, p1, inner, p2])
		draw_colored_polygon(arrow_pts, col_main)
		var closed: PackedVector2Array = PackedVector2Array([tip, p1, inner, p2, tip])
		draw_polyline(closed, col_gold, 2.0, true)

		# Badge distance
		var badge_center: Vector2 = edge_pt - dir * 42.0
		var dist_str: String = "%dm" % dist_m
		var font: Font = ThemeDB.fallback_font
		var fs: int = 12
		var s_sz: Vector2 = font.get_string_size(dist_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var rw: float = s_sz.x + 12.0
		var rh: float = maxf(18.0, s_sz.y + 4.0)
		var rect: Rect2 = Rect2(badge_center - Vector2(rw * 0.5, rh * 0.5), Vector2(rw, rh))
		draw_rect(rect, Color(0.08, 0.02, 0.03, 0.88), true)
		draw_rect(rect, col_gold, false, 1.5)
		draw_string(font, badge_center + Vector2(-s_sz.x * 0.5, fs * 0.36), dist_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

