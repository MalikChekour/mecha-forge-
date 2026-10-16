extends CanvasLayer
class_name MetaScreen
## End-of-run screen: optional revive (watch-ad stub), then the persistent talent shop
## (spend banked scrap) and a Replay button. This is the between-runs retention loop.

## Game.gd n'a pas de class_name -> acces a CHAPTERS via le script preload (meme pattern que les
## tests _test_decor_cryo.gd/_test_decor_phase2.gd).
const GameScript = preload("res://scenes/Game.gd")

var game: Node
var died: bool = false
var _revive_ok: bool = false
var _new_record: bool = false
var _home: bool = false     # true = launch HUB (JOUER + meta), not the end-of-run screen
var _doubled: bool = false  # rewarded-ad scrap doubling claimed for this run (once only)
var _revive_screen: bool = false   # the "MECHA DETRUIT / une seconde chance" prompt is up

## 🚨 BUG-02 (rapport QA 28/09) : sur un sous-ecran long (ARSENAL avec beaucoup d'armes +
## competences), le bouton RETOUR en bas de la ScrollContainer existe et le defilement
## fonctionne, mais la molette y avance a peine de quelques pixels par cran dans l'export
## HTML5 — reproduit : ~15 grands scrolls pour l'atteindre. Un joueur qui ne pense pas a
## tirer la barre de defilement se retrouve donc bloque, sans le moindre retour possible
## (et Echap ne faisait RIEN). On cable ici un raccourci fiable, independant du scroll.
func _unhandled_input(event: InputEvent) -> void:
	if _revive_screen:
		return   # cet ecran n'a pas de "retour" — Echap n'y ferait rien de sense
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

func setup(g: Node, d: bool, revive_available: bool) -> void:
	game = g
	died = d
	_revive_ok = revive_available
	# 🚨 B6 : le HUD de partie restait affiche PAR-DESSUS l'ecran de fin. Le HUD se masque
	# deja sur player_died, mais la VICTOIRE passe par _on_run_won, qui n'emet pas ce signal :
	# le defaut revenait donc par l'autre porte. On masque ici, c'est-a-dire a CHAQUE ecran de
	# resultats, quelle qu'en soit la cause. (Game.revive_player() le remontre.)
	var h: Node = get_tree().get_first_node_in_group("hud")
	if h != null and "visible" in h:
		h.visible = false
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS   # buttons must work while the tree is paused
	_new_record = SaveManager.record_score(GameState.difficulty, GameState.score)
	if died and revive_available:
		_build_revive()
	else:
		_build_shop()

## Home hub shown at launch: same meta systems as the end-of-run screen, but headed by the
## title + currencies and launched via a JOUER button instead of REJOUER.
func setup_home(g: Node) -> void:
	game = g
	_home = true
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS   # hub buttons work while the tree is paused
	get_tree().paused = true
	_build_home()

## Sub-screens return HERE when launched from the hub, or to the results screen otherwise.
func _back() -> void:
	if _home:
		_build_home()
	else:
		_build_shop()

## PREMIUM landscape home (1280x720 design space): full-bleed hero art + cinematic darkening,
## logo top-left, currency chips top-right, a big glowing PLAY and a row of framed buttons.
# --- MENU D'ACCUEIL : style EPURE, ANCRE et RESPONSIVE -------------------------
# Deux exigences : marcher en PAYSAGE **et** en PORTRAIT, et que la taille des
# onglets suive. Donc rien n'est fige : un facteur d'echelle `k` est calcule sur
# le PLUS PETIT cote de l'ecran (comme sur mobile), le titre s'auto-ajuste a la
# largeur disponible, et les sections forment une LISTE VERTICALE sous JOUER,
# centree et large. Le menu se reconstruit a chaque changement de taille ou
# d'orientation de la fenetre.

## Cadre d'onglet "HUD" : coins coupes en diagonale, filet fin, marques d'angle.
## Entierement DESSINE (aucune texture) -> net a n'importe quelle taille, et il suit
## le facteur d'echelle responsive comme le reste du menu.
class HudTabFrame extends Control:
	var accent: Color = Color(0.4, 0.8, 1.0)
	var cut: float = 9.0
	var line_w: float = 2.0
	var hovered: bool = false
	var held: bool = false

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w <= 2.0 or h <= 2.0:
			return
		var c: float = minf(cut, minf(w, h) * 0.4)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(c, 0.0), Vector2(w, 0.0), Vector2(w, h - c),
			Vector2(w - c, h), Vector2(0.0, h), Vector2(0.0, c)])
		
		# Holographic fill
		var fill: Color = Color(0.01, 0.08, 0.12, 0.85)
		if hovered:
			fill = Color(0.05, 0.25, 0.4, 0.95)
		if held:
			fill = Color(0.1, 0.35, 0.5, 1.0)
		draw_colored_polygon(pts, fill)
		
		# Scanlines inside
		var sc_color: Color = Color(accent.r, accent.g, accent.b, 0.15)
		for y in range(4, int(h), 4):
			draw_line(Vector2(2, y), Vector2(w-2, y), sc_color, 1.0)

		# Glowing borders
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(pts[0])
		var border_color: Color = Color(accent.r, accent.g, accent.b, 1.0)
		draw_polyline(outline, border_color, line_w, true)
		# Outer glow
		draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.4), line_w * 3.0, true)
		draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.15), line_w * 6.0, true)

		# Corner marks
		var t: float = maxf(4.0, c * 0.75)
		var m: float = maxf(3.0, c * 0.45)
		var lw: float = maxf(2.0, line_w)
		var mc: Color = Color(1.0, 1.0, 1.0, 0.9) # Bright white corners
		draw_line(Vector2(m, m + t), Vector2(m, m), mc, lw, true)
		draw_line(Vector2(m, m), Vector2(m + t, m), mc, lw, true)
		draw_line(Vector2(w - m, h - m - t), Vector2(w - m, h - m), mc, lw, true)
		draw_line(Vector2(w - m, h - m), Vector2(w - m - t, h - m), mc, lw, true)

const HOME_BASE: float = 720.0                             # cote de reference
const F_TITLE: String = "res://assets/fonts/Orbitron-Variable.ttf"

var _screen_home: bool = false        # l'accueil est-il a l'ecran ? (pour le relayout)
var _animate_home: bool = true        # rejouer les animations d'entree ? (non lors d'un resize)
var _relayout_queued: bool = false

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

## Reconstruit l'accueil quand la fenetre change de taille OU bascule portrait/paysage.
func _queue_relayout() -> void:
	if not _screen_home or _relayout_queued:
		return
	_relayout_queued = true
	call_deferred("_do_relayout")

func _do_relayout() -> void:
	_relayout_queued = false
	if _screen_home and is_inside_tree():
		_animate_home = false      # un redimensionnement ne doit PAS rejouer l'intro
		_build_home()
		_animate_home = true

## Orbitron est une police VARIABLE : la graisse se choisit via FontVariation.
func _orbitron(weight: int) -> FontVariation:
	var fv: FontVariation = FontVariation.new()
	fv.base_font = load(F_TITLE)
	fv.variation_opentype = {&"wght": weight}
	return fv


## Apparition d'un element : opacite + leger depassement d'echelle, avec un retard
## (c'est ce retard croissant qui fait la CASCADE). Les elements etant dans des
## conteneurs, on anime l'echelle et l'alpha — jamais la position, que le conteneur
## reecrirait a chaque mise en page.
func _intro_pop(c: Control, delay: float, from_scale: float) -> void:
	await get_tree().process_frame        # la taille n'est connue qu'apres la mise en page
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(from_scale, from_scale)
	var t: Tween = c.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # les menus mettent l'arbre en pause
	t.set_parallel(true)
	t.tween_property(c, "modulate:a", 1.0, 0.24).set_delay(delay)
	t.tween_property(c, "scale", Vector2.ONE, 0.34).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 05/10, refonte UI hologramme : glissement laissant venir le PANNEAU ENTIER depuis le
## cote, EN PLUS du pop ci-dessus (jamais a la place). Ici on anime bien position.x, mais
## sans le risque decrit plus haut : le delta est applique APRES la mise en page (le
## process_frame a deja laisse le conteneur poser sa position finale dans target_x), donc
## si un redimensionnement survient pendant l'anim, le conteneur re-ecrit juste la position
## FINALE correcte par-dessus -- au pire l'anim est coupee court, jamais corrompue.
func _intro_slide(c: Control, delay: float, from_dx: float) -> void:
	await get_tree().process_frame
	if not is_instance_valid(c):
		return
	var target_x: float = c.position.x
	c.position.x = target_x + from_dx
	var t: Tween = c.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_interval(delay)
	t.tween_property(c, "position:x", target_x, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Punch elastique : le bouton s'ecrase puis depasse legerement avant de se caler.
func _punch(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var t: Tween = c.create_tween()
	# les menus mettent l'arbre en PAUSE (Game.gd) : sans ceci le tween ne tourne jamais.
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(c, "scale", Vector2(0.93, 0.93), 0.05)
	t.tween_property(c, "scale", Vector2(1.055, 1.055), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.07)

## Onde de choc : reservee a JOUER, la seule action qui merite d'etre soulignee.
func _shock(at: Control) -> void:
	if not ResourceLoader.exists("res://assets/vfx/shockwave.png"):
		return
	var r: TextureRect = TextureRect.new()
	# shockwave.png est une BANDE de 12 images : affichee entiere elle devient un filet
	# invisible. On en decoupe UNE via AtlasTexture, et on passe en additif (fond noir -> rien).
	var sheet: Texture2D = load("res://assets/vfx/shockwave.png")
	var fh: float = float(sheet.get_height())
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(fh * 2.0, 0.0, fh, fh)
	r.texture = atlas
	r.material = Tex.add_mat()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(240.0, 240.0)
	r.modulate = Color(0.55, 1.0, 0.75, 0.9)
	add_child(r)
	r.global_position = at.global_position + at.size * 0.5 - r.size * 0.5
	r.pivot_offset = r.size * 0.5
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	var t: Tween = r.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_parallel(true)
	t.tween_property(r, "scale", Vector2(2.4, 2.4), 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(r, "modulate:a", 0.0, 0.40)
	t.set_parallel(false)
	t.tween_callback(r.queue_free)

func _build_home() -> void:
	_clear()
	var vp: Vector2 = _viewport_size()
	var portrait: bool = vp.y > vp.x
	# echelle generale calee sur le PLUS PETIT cote : en portrait c'est la largeur qui
	# contraint, en paysage c'est la hauteur. Un seul facteur -> tout reste proportionne.
	var k: float = clampf(minf(vp.x, vp.y) / HOME_BASE, 0.62, 1.75)
	var safe: float = 22.0 * k
	if not get_viewport().size_changed.is_connected(_queue_relayout):
		get_viewport().size_changed.connect(_queue_relayout)

	# 1) art plein cadre + voile + degrade bas
	var art: TextureRect = TextureRect.new()
	if ResourceLoader.exists("res://assets/menu/hero_bg.png"):
		art.texture = load("res://assets/menu/hero_bg.png")
	elif ResourceLoader.exists("res://assets/menu/menu_bg.png"):
		art.texture = load("res://assets/menu/menu_bg.png")
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var bbc: BackBufferCopy = BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bbc)
	var veil: ColorRect = ColorRect.new()
	veil.material = ShaderMaterial.new()
	veil.material.shader = load("res://shaders/ui_blur.gdshader")
	veil.color = Color.WHITE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var grad: TextureRect = TextureRect.new()
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.05, 0.0)); g.set_color(1, Color(0.02, 0.03, 0.05, 0.96))
	gt.gradient = g
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grad.offset_top = -(vp.y * (0.42 if portrait else 0.38))
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)

	# 3) monnaies en haut a droite — dans un FLOW : elles passent a la ligne si l'ecran
	#    est trop etroit au lieu d'etre coupees.
	var chips: HFlowContainer = HFlowContainer.new()
	chips.set_anchors_preset(Control.PRESET_TOP_WIDE)
	chips.offset_left = safe; chips.offset_right = -safe
	chips.offset_top = 16.0 * k
	chips.alignment = FlowContainer.ALIGNMENT_END
	chips.add_theme_constant_override("h_separation", int(9.0 * k))
	chips.add_theme_constant_override("v_separation", int(7.0 * k))
	add_child(chips)
	chips.add_child(_chip("%d points" % SaveManager.sp(), Color(0.4, 0.92, 1.0), k, true))
	chips.add_child(_chip("%d" % int(SaveManager.data.get("meta_scrap", 0)), Color(1.0, 0.8, 0.35), k))
	chips.add_child(_chip("%d cristaux" % int(SaveManager.data.get("crystals", 0)), Color(0.6, 0.78, 1.0), k))

	# --- UNE SEULE COLONNE, CENTREE VERTICALEMENT -----------------------------
	# Avant : le titre etait colle en haut et les onglets ecrases tout en bas. Ici tout
	# vit dans une pile centree (embleme > titre > JOUER > la LISTE des sections), donc
	# le titre tombe naturellement au bon endroit et les onglets sont gros et centres.
	# `vk` compacte la pile quand la hauteur manque (paysage) et l'aere en portrait.
	var vk: float = k * clampf(vp.y / 900.0, 0.70, 1.18)
	# --- la pile doit RENTRER, le defilement n'est qu'un filet de securite ---------------
	# Hauteur demandee par la colonne, en unites de `vk` : embleme 78 + titre 58 + accroche
	# 17 + ecart 20 + legende 14 + JOUER 90 + ecart 16 + 6 sections a (56 + 9) = 683, plus
	# ~12 separations de 7 = 84. Soit ~767. On compresse `vk` juste ce qu'il faut pour tenir
	# dans la hauteur disponible, avec un plancher a 0,58 pour rester lisible au pouce.
	var dispo: float = vp.y - 128.0 * k
	var besoin: float = 767.0
	if dispo > 0.0 and vk * besoin > dispo:
		vk = maxf(0.58, dispo / besoin)
	# 🚨 EN 4:3 la pile debordait de 170 px : HISTOIRE passait entierement hors ecran et le
	# pied de page recouvrait QUOTIDIEN (mesure du testeur ergonomie). Un VBoxContainer ne
	# rogne pas — ses enfants depassent simplement son rectangle, sans que rien ne l'indique.
	# On l'enferme donc dans un ScrollContainer : il CENTRE quand tout rentre (grace aux
	# size_flags EXPAND_FILL) et FAIT DEFILER des que ca deborde. Plus rien ne peut sortir.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = safe; scroll.offset_right = -safe
	scroll.offset_top = 70.0 * k; scroll.offset_bottom = -(58.0 * k)   # sous les monnaies, au-dessus du pied
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(7.0 * vk))
	scroll.add_child(col)

	if ResourceLoader.exists("res://assets/menu/emblem_cut.png"):
		var em: TextureRect = TextureRect.new()
		em.texture = load("res://assets/menu/emblem_cut.png")
		em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var es: float = 78.0 * vk
		em.custom_minimum_size = Vector2(es, es)
		em.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		em.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(em)

	# TITRE : on part de la taille voulue et on REDUIT tant que ca ne rentre pas dans la
	# largeur (garantit une seule ligne partout). Une etiquette PAR LETTRE pour l'assemblage.
	var tfont: FontVariation = _orbitron(900)
	var fs: int = int(round(58.0 * vk))
	var maxw: float = vp.x - 2.0 * safe
	const TITLE_TXT: String = "MECHA-FORGE"
	var lsep: int = int(3.0 * k)
	var extra: float = float(lsep * (TITLE_TXT.length() - 1))
	while fs > 18 and tfont.get_string_size(TITLE_TXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + extra > maxw:
		fs -= 2
	var titlebox: HBoxContainer = HBoxContainer.new()
	titlebox.add_theme_constant_override("separation", lsep)
	titlebox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	titlebox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(titlebox)
	var li: int = 0
	for ch in TITLE_TXT:
		var cl: Label = Label.new()
		cl.text = ch
		cl.add_theme_font_override("font", tfont)
		cl.add_theme_font_size_override("font_size", fs)
		cl.add_theme_color_override("font_color", Color(0.74, 0.93, 1.0))
		cl.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.26))
		cl.add_theme_constant_override("outline_size", maxi(2, int(7.0 * vk)))
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		titlebox.add_child(cl)
		if _animate_home:
			cl.modulate.a = 0.0
			_intro_pop(cl, 0.035 * float(li), 1.35)
		li += 1
	# respiration lente : le titre reste vivant sans fatiguer. On pulse vers le BAS car
	# au-dessus de 1.0 le modulate est ecrete (le titre est deja quasi blanc).
	var breath: Tween = titlebox.create_tween()
	breath.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	breath.set_loops()
	breath.tween_property(titlebox, "modulate", Color(0.84, 0.88, 0.94, 1.0), 1.7).set_trans(Tween.TRANS_SINE)
	breath.tween_property(titlebox, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.7).set_trans(Tween.TRANS_SINE)

	var tag: Label = Label.new()
	tag.text = "SURVIVE THE HORDE" if vp.x < 640.0 else "S U R V I V E   T H E   H O R D E"
	tag.add_theme_font_size_override("font_size", maxi(13, int(17.0 * vk)))          # plancher lisibilite
	tag.add_theme_color_override("font_color", Palette.CYAN)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tag)

	var gap1: Control = Control.new()
	gap1.custom_minimum_size = Vector2(0, 20.0 * vk)
	gap1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap1)

	# JOUER : la seule action qui compte, donc la plus grosse et la plus coloree
	# 🚨 L'accueil affichait « CAMPAGNE · NORMAL » (la difficulte SAUVEGARDEE) alors que le
	# chapitre 1 se lance en FACILE : chaque chapitre impose la sienne (CHAPTERS[i].diff).
	# On annonce donc la progression, qui est vraie, au lieu d'une difficulte qui ment.
	var mode_on: bool = bool(SaveManager.setting("endless", false))
	var cap: Label = Label.new()
	if mode_on:
		cap.text = "SANS FIN  ·  %s" % String(GameState.diff().get("name", "NORMAL"))
	else:
		var nb: int = SaveManager.chapters_cleared_count()
		var total_ch: int = GameScript.CHAPTERS.size()
		cap.text = "CAMPAGNE  ·  %d / %d chapitres" % [clampi(nb, 0, total_ch), total_ch]
	cap.add_theme_font_size_override("font_size", maxi(15, int(14.0 * vk)))          # plancher lisibilite
	cap.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cap)
	var playw: float = minf(430.0 * k, vp.x - 2.0 * safe)
	var play: Button = Button.new()
	play.text = "JOUER"
	play.custom_minimum_size = Vector2(playw, 90.0 * vk)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override("font_size", maxi(18, int(40.0 * vk)))
	play.add_theme_color_override("font_color", Color.WHITE)
	var accent: Color = Color(0.16, 0.66, 0.4)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = accent
	sb.set_corner_radius_all(int(14.0 * k))
	sb.border_color = Color(0.4, 0.89, 0.63); sb.set_border_width_all(maxi(1, int(3.0 * k)))
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.55); sb.shadow_size = int(12.0 * k)
	var sbh: StyleBoxFlat = sb.duplicate(); sbh.bg_color = accent.lightened(0.16)
	var sbp: StyleBoxFlat = sb.duplicate(); sbp.bg_color = accent.darkened(0.16)
	play.add_theme_stylebox_override("normal", sb)
	play.add_theme_stylebox_override("hover", sbh)
	play.add_theme_stylebox_override("pressed", sbp)
	play.add_theme_stylebox_override("focus", sb)
	play.button_down.connect(func() -> void: _punch(play); _shock(play))
	play.pressed.connect(func() -> void: Audio.sfx("click"))
	play.pressed.connect(_on_play)
	col.add_child(play)

	var gap2: Control = Control.new()
	gap2.custom_minimum_size = Vector2(0, 16.0 * vk)
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap2)

	# LES SECTIONS : une LISTE VERTICALE sous JOUER, centree et large. Elles restent
	# secondaires (filet biseaute, pas de fond plein) mais deviennent enfin lisibles
	# et confortables au pouce — l'inverse de la rangee minuscule collee en bas.
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", int(9.0 * vk))
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(list)
	var tabw: float = playw * 0.86
	var tabh: float = maxf(48.0, 56.0 * vk)          # 48 dp mini (cible tactile)
	var tabfs: int = maxi(17, int(21.0 * vk))          # navigation principale : jamais sous 17 px
	var secs: Array = [
		["ARSENAL", _build_arsenal, Color(0.55, 0.4, 0.22)],
		["EQUIPEMENT", _build_gear, Color(0.42, 0.34, 0.6)],
		["GARAGE", _build_garage, Color(0.24, 0.42, 0.62)],
		# 🚨 une pastille quand une recompense du jour ou une quete terminee attend : sans elle,
		# le crochet de retention existe dans le code mais aucun joueur ne le voit.
		["QUOTIDIEN" + ("   •  A RECLAMER" if SaveManager.quotidien_a_reclamer() else ""),
			_build_daily, Color(0.24, 0.5, 0.37)],
		["HISTOIRE", _play_story, Color(0.6, 0.3, 0.24)],
		# 🚨 les reglages (musique, bruitages, auto-visee, ecran, mode SANS FIN) n'etaient
		# joignables que par un ecran JAMAIS ouvert : couper la musique imposait de lancer
		# une partie d'abord. Ils ont maintenant leur entree sur l'accueil.
		["REGLAGES", _open_settings, Color(0.32, 0.38, 0.46)],
	]
	var si: int = 0
	for sec in secs:
		var pb: Button = _pill(String(sec[0]), sec[1] as Callable, sec[2] as Color, k)
		pb.custom_minimum_size = Vector2(tabw, tabh)
		pb.add_theme_font_size_override("font_size", tabfs)
		pb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		list.add_child(pb)
		if _animate_home:
			pb.modulate.a = 0.0
			_intro_pop(pb, 0.05 * float(si), 0.92)   # cascade : un retard par section
		si += 1

	# 6) version + credits (CC-BY doit rester visible) : pleine largeur + retour a la
	#    ligne, sinon la ligne deborde en portrait.
	var foot: Label = Label.new()
	foot.text = "v%s   ·   Musique K. MacLeod (incompetech) CC-BY 4.0   ·   SFX Kenney CC0   ·   Polices Orbitron/Rajdhani OFL" % ProjectSettings.get_setting("application/config/version", "?")
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_left = safe; foot.offset_right = -safe
	foot.offset_top = -(46.0 * k); foot.offset_bottom = -(6.0 * k)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_LEFT
	foot.add_theme_font_size_override("font_size", maxi(11, int(12.0 * k)))          # mentions legales
	foot.add_theme_color_override("font_color", Color(0.5, 0.56, 0.64))
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foot)
	_screen_home = true

## Ouvre le panneau de reglages du jeu depuis le hub (il rouvre l'accueil en sortant).
func _open_settings() -> void:
	var g: Node = game
	queue_free()
	if g != null and g.has_method("show_settings"):
		g.show_settings(true)

func _play_story() -> void:
	var g: Node = game
	queue_free()
	# on passe par le jeu : il attend la fin des panneaux PUIS rouvre l'accueil.
	# (appeler _play_opening() directement laissait le joueur bloque sans menu)
	if g != null and g.has_method("play_story_then_home"):
		g.play_story_then_home()
	elif g != null and g.has_method("_play_opening"):
		g._play_opening()

## Une monnaie : panneau arrondi + pastille de couleur + valeur. Tout est mis a l'echelle.
func _chip(text: String, icol: Color, k: float, plus: bool = false) -> Control:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.12, 0.88)
	sb.set_corner_radius_all(int(10.0 * k))
	# 05/10, refonte UI hologramme : liseré cyan neon + halo au lieu du gris plat d'origine.
	sb.border_color = Color(0.15, 0.85, 1.0, 0.75); sb.set_border_width_all(maxi(1, int(2.0 * k)))
	sb.shadow_color = Color(0.15, 0.85, 1.0, 0.25); sb.shadow_size = int(6.0 * k)
	sb.content_margin_left = 11.0 * k; sb.content_margin_right = 11.0 * k
	sb.content_margin_top = 5.0 * k; sb.content_margin_bottom = 5.0 * k
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", int(7.0 * k))
	p.add_child(h)
	var dot: Panel = Panel.new()
	var dsz: float = 15.0 * k
	dot.custom_minimum_size = Vector2(dsz, dsz)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ds: StyleBoxFlat = StyleBoxFlat.new()
	ds.bg_color = icol; ds.set_corner_radius_all(int(dsz * 0.5))
	dot.add_theme_stylebox_override("panel", ds)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(dot)
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(15, int(19.0 * k)))          # plancher lisibilite
	l.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	if plus:
		var b: Button = Button.new()
		b.text = "+"
		b.flat = true
		b.add_theme_font_size_override("font_size", maxi(14, int(24.0 * k)))
		b.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		b.button_down.connect(func() -> void: _punch(b))
		b.pressed.connect(func() -> void: Audio.sfx("click"); _build_arsenal())
		h.add_child(b)
	return p

## Onglet du rail bas, style HUD BISEAUTE : le bouton ne dessine QUE son texte
## (styleboxes vides) et un cadre enfant dessine le biseau, le filet et les marques
## d'angle. Taille, police et marges suivent l'echelle de l'ecran.
func _pill(label: String, cb: Callable, accent: Color, k: float) -> Button:
	var b: Button = Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, maxf(38.0, 46.0 * k))
	b.add_theme_font_size_override("font_size", maxi(16, int(18.0 * k)))          # plancher lisibilite
	b.add_theme_color_override("font_color", Color(0.87, 0.95, 1.0))
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.content_margin_left = 18.0 * k
	empty.content_margin_right = 18.0 * k
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	var fr: HudTabFrame = HudTabFrame.new()
	fr.accent = accent
	fr.cut = 9.0 * k
	fr.line_w = maxf(1.5, 2.0 * k)
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.show_behind_parent = true          # le cadre passe DERRIERE le texte du bouton
	b.add_child(fr)
	fr.resized.connect(fr.queue_redraw)
	b.mouse_entered.connect(func() -> void: fr.hovered = true; fr.queue_redraw())
	b.mouse_exited.connect(func() -> void: fr.hovered = false; fr.queue_redraw())
	b.button_down.connect(func() -> void: fr.held = true; fr.queue_redraw(); _punch(b))
	b.button_up.connect(func() -> void: fr.held = false; fr.queue_redraw())
	b.pressed.connect(func() -> void: Audio.sfx("click"))
	b.pressed.connect(cb)
	return b
func _on_play() -> void:
	var g: Node = game
	queue_free()
	if g != null and g.has_method("_show_chapter_select"):
		g._show_chapter_select()   # progression : choix du chapitre (remplace le choix de difficulté)
	elif g != null and g.has_method("_show_difficulty_select"):
		g._show_difficulty_select()

func _clear() -> void:
	_screen_home = false      # un sous-ecran s'affiche : plus de relayout de l'accueil
	_revive_screen = false    # reinitialise a chaque ecran ; _build_revive() le remet a true
	for c in get_children():
		c.queue_free()

## Meme facteur d'echelle que l'accueil : les sous-menus suivent le meme rythme
## visuel sur tous les formats (avant, ils etaient en tailles FIXES).
func _ui_k() -> float:
	var vp: Vector2 = _viewport_size()
	return clampf(minf(vp.x, vp.y) / HOME_BASE, 0.62, 1.75)

func _scaffold(min_w: float = 540.0) -> VBoxContainer:
	# HOME hub gets the illustrated key-art background; every other panel keeps the flat dark bg.
	# MEME fond que l'accueil (hero_bg) : les sous-menus font partie du meme monde.
	# menu_bg.png est un gros plan de mecha qui noyait completement le texte.
	if _home and ResourceLoader.exists("res://assets/menu/hero_bg.png"):
		var art: TextureRect = TextureRect.new()
		art.texture = load("res://assets/menu/hero_bg.png")
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
		var bbc: BackBufferCopy = BackBufferCopy.new()
		bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(bbc)
		var veil: ColorRect = ColorRect.new()
		veil.material = ShaderMaterial.new()
		veil.material.shader = load("res://shaders/ui_blur.gdshader")
		veil.color = Color.WHITE
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(veil)
	else:
		var bbc: BackBufferCopy = BackBufferCopy.new()
		bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(bbc)
		var bg: ColorRect = ColorRect.new()
		bg.material = ShaderMaterial.new()
		bg.material.shader = load("res://shaders/ui_blur.gdshader")
		bg.color = Color.WHITE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	# A CenterContainer alone overflows off both edges once the content is taller than the viewport.
	# It already happened on the results screen (~750 px of content in 720 px of landscape, so the
	# bottom of REJOUER was clipped) and on a gear slot past ~11 parts, where RETOUR left the screen
	# entirely — with no way back. The ScrollContainer makes every panel safe by construction.
	var uk: float = _ui_k()
	var vps: Vector2 = _viewport_size()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18.0 * uk; scroll.offset_right = -18.0 * uk
	scroll.offset_top = 16.0 * uk; scroll.offset_bottom = -16.0 * uk
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.theme = Palette.ui_theme()       # definition PARTAGEE (voir Palette.gd)
	add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var v: VBoxContainer = VBoxContainer.new()
	# la largeur suit l'ecran (et ne le deborde jamais) au lieu d'etre figee a 540
	v.custom_minimum_size = Vector2(minf(min_w * uk, vps.x - 44.0 * uk), 0)
	v.add_theme_constant_override("separation", int(12.0 * uk))
	center.add_child(v)
	v.modulate.a = 0.0
	_intro_pop(v, 0.0, 0.92)
	_intro_slide(v, 0.0, 48.0 * uk)
	return v

func _title(v: VBoxContainer, text: String, color: Color, size: int = 40) -> void:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var uk3: float = _ui_k()
	l.add_theme_font_size_override("font_size", maxi(17, int(float(size) * uk3)))          # meme plancher que Palette.fs()
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(2, int(6.0 * uk3)))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # certains titres sont longs
	v.add_child(l)

func _big_button(v: VBoxContainer, text: String, cb: Callable, color: Color = Color(0.2, 0.55, 0.95)) -> void:
	# Meme langage visuel que les sections de l'accueil : biseau + filet de couleur,
	# taille a l'echelle de l'ecran. Avant : pastille arrondie pleine, taille figee.
	var uk: float = _ui_k()
	var b: Button = _pill(text, cb, color, uk)
	b.custom_minimum_size = Vector2(0, maxf(48.0, 58.0 * uk))
	b.add_theme_font_size_override("font_size", maxi(14, int(23.0 * uk)))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(b)

# --- revive prompt (death only, once per run) ---
func _build_revive() -> void:
	_clear()
	_revive_screen = true
	var v: VBoxContainer = _scaffold()
	_title(v, "MECHA DÉTRUIT", Color(1.0, 0.5, 0.4))
	_title(v, "Une seconde chance ?", Color(0.85, 0.9, 1.0), 22)
	if Ads.available("revive"):
		_big_button(v, "REVIVRE  (%s%d restantes)" % [_ad_tag(), Ads.remaining("revive")],
			_on_revive, Color(0.2, 0.7, 0.4))
	else:
		_title(v, "Plus de revive disponible aujourd'hui", Color(0.7, 0.6, 0.6), 17)
	_big_button(v, "Abandonner", _on_abandon, Color(0.4, 0.4, 0.5))

func _on_revive() -> void:
	# The screen stays up during the ad; only a completed watch revives. Cancelling falls through
	# to the results screen instead of silently doing nothing.
	Ads.show_rewarded("revive", func(rewarded: bool) -> void:
		if not rewarded:
			_build_shop()
			return
		if game != null and game.has_method("revive_player"):
			game.revive_player()
		queue_free())

func _on_abandon() -> void:
	_build_shop()

# --- talent shop + replay ---
func _build_shop() -> void:
	# Bank the run's earnings only at END OF RUN. The HOME hub reuses this builder, and banking
	# there would flush a phantom run into the daily quests (counted a "partie terminee" on launch).
	if not _home and game != null and game.has_method("ensure_banked"):
		game.ensure_banked()
	_clear()
	var v: VBoxContainer = _scaffold(560.0)
	if _home:
		if ResourceLoader.exists("res://assets/menu/emblem_cut.png"):
			var em: TextureRect = TextureRect.new()
			em.texture = load("res://assets/menu/emblem_cut.png")
			em.custom_minimum_size = Vector2(0, 128)
			em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			em.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(em)
		_title(v, "MECHA-FORGE", Color(0.7, 0.9, 1.0), 46)
		# version on the hub: the only way to tell at a glance WHICH build is on the phone
		_title(v, "Survivor-like mecha   ·   v%s" % ProjectSettings.get_setting("application/config/version", "?"),
			Color(0.6, 0.68, 0.8), 18)
		# CC-BY attribution (Incompetech) — must be visible in-game; Kenney SFX are CC0 (courtesy credit).
		_title(v, "Musique : K. MacLeod (incompetech.com) CC-BY 4.0   ·   SFX : Kenney CC0",
			Color(0.48, 0.53, 0.6), 12)
	else:
		if died:
			_title(v, "MECHA DÉTRUIT", Color(1.0, 0.5, 0.4))
		else:
			_title(v, "VICTOIRE !", Color(1.0, 0.9, 0.45))
		_title(v, "Niveau %d · %d kills · %ds" % [GameState.level, GameState.kills, int(GameState.run_time)], Color(0.8, 0.85, 0.95), 20)
		if GameState.endless:
			_title(v, "SANS FIN — vague %d atteinte" % GameState.endless_wave, Color(1.0, 0.85, 0.3), 22)
		var dn: String = String(GameState.diff().get("name", "NORMAL"))
		_title(v, "SCORE  %d    GRADE  %s    [%s]" % [GameState.score, GameState.grade(), dn], Color(1.0, 0.85, 0.4), 24)
		if _new_record:
			_title(v, "NOUVEAU RECORD !", Color(0.5, 1.0, 0.6), 20)
		else:
			_title(v, "record %s : %d" % [dn, SaveManager.best_score(GameState.difficulty)], Color(0.7, 0.78, 0.9), 16)
	# earned-this-run POINTS (loadout progression) + crystals (gacha)
	if not _home and game != null and int(game.get("last_sp")) > 0:
		_title(v, "+%d POINTS de competence" % int(game.get("last_sp")), Color(1.0, 0.85, 0.35), 24)
	if not _home and game != null and int(game.get("last_crystals")) > 0:
		_title(v, "+%d cristaux gagnes" % int(game.get("last_crystals")), Color(0.8, 0.6, 1.0), 20)
	if not _home and game != null and game.player != null and is_instance_valid(game.player) and game.player.has_method("weapons"):
		var ws2 = game.player.weapons()
		if ws2 != null:
			var owned: Array = ws2.owned_weapons()
			if not owned.is_empty():
				var names: Array = []
				for wid in owned:
					names.append(String(wid).capitalize())
				_title(v, "Armes de cette run : " + ", ".join(names), Color(0.7, 0.85, 1.0), 15)
		var passives: Dictionary = game.get("_passives") if game != null else {}
		var total_picks: int = 0
		for k in passives:
			total_picks += int(passives[k])
		if total_picks > 0:
			_title(v, "%d amelioration(s) prise(s) cette partie" % total_picks, Color(0.7, 0.85, 1.0), 15)
	_currency_row(v)

	# 🚨 REJOUER etait en 5e position, SOUS LA LIGNE DE FLOTTAISON (3 crans de molette pour
	# l'atteindre — testeur « nouveau joueur »). Dans un survivor-like la boucle vit sur la
	# re-entree immediate : l'action la plus probable passe en TETE, juste sous le score.
	if not _home:
		_prochain_objectif(v)
		_big_button(v, "REJOUER", _replay_now, Color(0.2, 0.6, 0.95))
		_big_button(v, "MENU PRINCIPAL", _replay, Color(0.4, 0.4, 0.5))
		var sp0: Control = Control.new()
		sp0.custom_minimum_size = Vector2(0, 14)
		v.add_child(sp0)

	for id: String in GameState.META:
		var d: Dictionary = GameState.META[id]
		var lvl: int = SaveManager.meta_level(id)
		var maxl: int = int(d["max"])
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_l: Label = Label.new()
		name_l.text = "%s   [%d/%d]" % [String(d["name"]), lvl, maxl]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.add_theme_font_size_override("font_size", Palette.fs(20))
		row.add_child(name_l)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(172, 52)
		if lvl >= maxl:
			b.text = "MAX"
			b.disabled = true
		else:
			var cost: int = int(d["cost"][lvl])
			b.text = "%d pt" % cost
			b.disabled = SaveManager.sp() < cost   # competences cost skill points now
			b.pressed.connect(_buy.bind(id, cost))
		row.add_child(b)
		v.add_child(row)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	v.add_child(spacer)
	# rewarded-ad payout: double what this run just banked, once, while the results are on screen
	if not _home and not _doubled and GameState.scrap > 0 and Ads.available("double_scrap"):
		_big_button(v, "DOUBLER LA FERRAILLE  (%s+%d)" % [_ad_tag(), GameState.scrap],
			_on_double_scrap, Color(0.75, 0.55, 0.2))
	# These used to be hub-only. The end-of-run screen is the moment of PEAK intent — the player has
	# just banked crystals and pushed quest progress — and it offered no way to go spend either.
	_big_button(v, "QUOTIDIEN  (recompenses + quetes)", _build_daily, Color(0.28, 0.6, 0.42))
	_big_button(v, "EQUIPEMENT  (pieces + amelioration)", _build_gear, Color(0.5, 0.4, 0.72))
	_big_button(v, "ARSENAL  (arme de depart + points)", _build_arsenal, Color(0.62, 0.46, 0.28))
	_big_button(v, "GARAGE  (mechs)", _build_garage, Color(0.3, 0.5, 0.72))
	if _home:
		_big_button(v, "JOUER", _on_play, Color(0.2, 0.7, 0.4))
	# REJOUER / MENU PRINCIPAL sont desormais places EN HAUT (voir plus haut) : les repeter
	# ici ferait deux boutons identiques dans le meme ecran.

## OU EN SUIS-JE de mon prochain achat ?
## 🚨 L'ecran de fin affichait le gain de la partie mais jamais la CIBLE : le joueur ne savait
## pas s'il etait a 40 ou a 1200 ferraille du prochain chassis, donc relancer n'avait pas
## d'objectif chiffre. On annonce l'achat atteignable le plus proche, avec ce qui manque.
func _prochain_objectif(v: VBoxContainer) -> void:
	var scrap: int = int(SaveManager.data.get("meta_scrap", 0))
	var sp: int = SaveManager.sp()
	# 1) un chassis non possede (la depense la plus lourde, donc le meilleur objectif)
	for m: Dictionary in GameState.MECHS:
		var mid: String = String(m["id"])
		var cout: int = int(m["cost"])
		if cout > 0 and not SaveManager.owns_mech(mid):
			var reste: int = cout - scrap
			if reste > 0:
				_title(v, "Encore %d ferraille pour %s" % [reste, String(m["name"])], Color(1.0, 0.82, 0.35), 18)
			else:
				_title(v, "%s est ACHETABLE au GARAGE" % String(m["name"]), Color(0.5, 1.0, 0.6), 18)
			return
	# 2) sinon, l'arme la moins chere encore verrouillee dans la gamme du chassis equipe
	var gamme: Array = GameState.mech_arsenal(SaveManager.equipped_mech())
	var best: Dictionary = {}
	for w: Dictionary in GameState.WEAPONS:
		var wid: String = String(w["id"])
		if not gamme.has(wid) or SaveManager.weapon_unlocked(wid):
			continue
		if best.is_empty() or int(w["cost"]) < int(best["cost"]):
			best = w
	if not best.is_empty():
		var manque: int = int(best["cost"]) - sp
		if manque > 0:
			_title(v, "Encore %d point%s pour %s" % [manque, "s" if manque > 1 else "", String(best["name"])],
				Color(0.55, 0.9, 1.0), 18)
		else:
			_title(v, "%s est debloquable a l'ARSENAL" % String(best["name"]), Color(0.5, 1.0, 0.6), 18)

## Currencies strip: banked ferraille (soft) + crystals/cores (reserved for the gacha & forge).
func _currency_row(v: VBoxContainer) -> void:
	var scrap: int = int(SaveManager.data.get("meta_scrap", 0))
	var crystals: int = int(SaveManager.data.get("crystals", 0))
	var cores: int = int(SaveManager.data.get("cores", 0))
	# POINTS de compétence : la monnaie de progression (loadout RPG), mise en avant.
	_title(v, "•  %d  POINTS" % SaveManager.sp(), Color(1.0, 0.85, 0.35), 26)
	_title(v, "%d  ferraille      %d  cristaux      %d  noyaux" % [scrap, crystals, cores],
		Color(0.6, 0.9, 1.0), 18)

## Label prefix for reward buttons. Says "pub" ONLY when a real network will actually play one —
## promising an ad that never shows is a Play policy risk, so the wording follows the provider.
func _ad_tag() -> String:
	return "pub — " if Ads.is_live() else ""

func _on_double_scrap() -> void:
	Ads.show_rewarded("double_scrap", func(rewarded: bool) -> void:
		if not rewarded:
			return
		_doubled = true                        # guard first: the rebuild below re-reads it
		SaveManager.bank_scrap(GameState.scrap)
		Audio.sfx("scrap")
		_build_shop())

func _buy(id: String, cost: int) -> void:
	if SaveManager.buy_meta(id, cost):
		_build_shop()   # refresh levels + scrap + button states

# --- mech garage: buy alternate chassis with scrap, equip for the next run ---
## ARSENAL — pick the STARTING weapon; locked ones cost skill points. Plus a rewarded-ad point top-up
## (the monetisation hook — points are the buyable progression currency).
func _build_arsenal() -> void:
	_clear()
	var v: VBoxContainer = _scaffold(640.0)
	_title(v, "ARSENAL", Color(0.7, 0.9, 1.0))
	_title(v, "Arme de depart      • %d points" % SaveManager.sp(), Color(1.0, 0.85, 0.35), 22)
	# Rapport Manus 26/09 : "un bandeau +3 POINTS (3/j) suggere une attribution quotidienne,
	# sans en expliquer l'origine" — verifie contre Game.gd : les points s'acquierent a la FIN
	# de chaque partie (echelle avec la difficulte), le bouton du bas n'est qu'un supplement pub.
	_title(v, "Gagnés à la fin de chaque partie (plus à haute difficulté)", Color(0.6, 0.65, 0.75), 14)
	# 🚨 L'ARSENAL est desormais PROPRE AU CHASSIS : chaque mecha a sa gamme de 5 armes et une
	# signature qu'il est le seul a booster. Lister les 9 armes ici laissait acheter une arme
	# que le mecha equipe ne sait pas manier — et qui serait silencieusement remplacee au
	# lancement de la partie. On n'affiche donc que sa gamme, et on dit laquelle est la sienne.
	var mid: String = SaveManager.equipped_mech()
	var mdef: Dictionary = GameState.mech_def(mid)
	var gamme: Array = GameState.mech_arsenal(mid)
	var sig: String = GameState.mech_signature(mid)
	_title(v, "%s   —   %s" % [String(mdef.get("name", mid)), String(mdef.get("ligne", ""))],
		Color(mdef.get("accent", Color(0.7, 0.9, 1.0))), 17)
	var cur: String = SaveManager.start_weapon()
	if not gamme.has(cur):
		cur = sig
	# 🚨 Les armes HORS GAMME etaient simplement masquees. Consequence relevee a l'audit
	# economie : un joueur qui a depense des points sur le Faisceau, puis achete BLUESTRIKE
	# (1400 ferraille, la depense la plus lourde du jeu), voit son achat DISPARAITRE sans un
	# mot — et sa partie suivante demarre avec une arme qu'il n'a pas choisie. Rien n'est
	# perdu (les deblocages sont globaux, ils reviennent avec le chassis), mais on ne le lui
	# disait pas. On les affiche donc, grisees, avec la raison.
	for w: Dictionary in GameState.WEAPONS:
		var id: String = String(w["id"])
		var hors_gamme: bool = not gamme.has(id)
		if hors_gamme and not SaveManager.weapon_unlocked(id):
			continue      # ni debloquee ni utilisable ici : inutile de l'afficher
		var unlocked: bool = SaveManager.weapon_unlocked(id)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_l: Label = Label.new()
		var marque: String = "   SIGNATURE  (+35% dégâts, tir plus rapide)" if id == sig else ""
		if hors_gamme:
			marque = "   —   hors de la gamme de %s (revient avec le châssis qui la porte)" % String(mdef.get("name", mid))
		name_l.text = "%s   -   %s%s" % [String(w["name"]), String(w["desc"]), marque]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.add_theme_font_size_override("font_size", Palette.fs(17))
		if hors_gamme:
			name_l.add_theme_color_override("font_color", Color(0.48, 0.52, 0.58))   # grisee
		elif id == sig:
			name_l.add_theme_color_override("font_color", Color(mdef.get("accent", Color(1.0, 0.9, 0.4))))
		elif id == cur:
			name_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		row.add_child(name_l)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(172, 52)
		if hors_gamme:
			b.text = "AUTRE CHÂSSIS"
			b.disabled = true
		elif id == cur:
			b.text = "EQUIPEE"
			b.disabled = true
		elif unlocked:
			b.text = "EQUIPER"
			b.pressed.connect(_equip_weapon.bind(id))
		else:
			var cost: int = int(w["cost"])
			b.text = "%d pt" % cost
			b.disabled = SaveManager.sp() < cost
			b.pressed.connect(_unlock_weapon.bind(id, cost))
		row.add_child(b)
		v.add_child(row)
	# --- COMPETENCES : spend points on permanent stat talents (moved out of the premium home) ---
	var csp: Control = Control.new(); csp.custom_minimum_size = Vector2(0, 6); v.add_child(csp)
	_title(v, "COMPETENCES", Color(0.7, 0.9, 1.0), 24)
	for cid: String in GameState.META:
		var cd: Dictionary = GameState.META[cid]
		var clvl: int = SaveManager.meta_level(cid)
		var cmax: int = int(cd["max"])
		var crow: HBoxContainer = HBoxContainer.new()
		crow.add_theme_constant_override("separation", 10)
		var cname: Label = Label.new()
		cname.text = "%s   [%d/%d]" % [String(cd["name"]), clvl, cmax]
		cname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cname.add_theme_font_size_override("font_size", Palette.fs(20))
		crow.add_child(cname)
		var cb: Button = Button.new()
		cb.custom_minimum_size = Vector2(172, 52)
		if clvl >= cmax:
			cb.text = "MAX"; cb.disabled = true
		else:
			var ccost: int = int(cd["cost"][clvl])
			cb.text = "%d pt" % ccost
			cb.disabled = SaveManager.sp() < ccost
			cb.pressed.connect(_buy_arsenal.bind(cid, ccost))
		crow.add_child(cb)
		v.add_child(crow)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	v.add_child(spacer)
	# monetisation: a rewarded-ad top-up of skill points
	if Ads.available("skill_points"):
		_big_button(v, "+3 POINTS  (%s%d/j)" % [_ad_tag(), Ads.remaining("skill_points")],
			_watch_sp_ad, Color(0.75, 0.55, 0.2))
	_big_button(v, "RETOUR", _back, Color(0.4, 0.4, 0.5))

func _buy_arsenal(id: String, cost: int) -> void:
	Audio.sfx("levelup" if SaveManager.buy_meta(id, cost) else "click")
	_build_arsenal()

func _equip_weapon(id: String) -> void:
	SaveManager.set_start_weapon(id)
	Audio.sfx("click")
	_build_arsenal()

func _unlock_weapon(id: String, cost: int) -> void:
	if SaveManager.unlock_weapon(id, cost):
		SaveManager.set_start_weapon(id)   # auto-equip what you just unlocked
		Audio.sfx("levelup")
	else:
		Audio.sfx("click")
	_build_arsenal()

func _watch_sp_ad() -> void:
	Ads.show_rewarded("skill_points", func(ok: bool) -> void:
		if ok:
			SaveManager.add_sp(3)
		_build_arsenal())

func _build_garage() -> void:
	_clear()
	var v: VBoxContainer = _scaffold(660.0)
	_title(v, "GARAGE DES MECHAS", Color(0.7, 0.9, 1.0))
	_title(v, "%d  ferraille disponible" % int(SaveManager.data.get("meta_scrap", 0)), Color(0.6, 0.9, 1.0), 20)
	
	# Live animated preview of equipped chassis
	var equipped: String = SaveManager.equipped_mech()
	var prev_center: CenterContainer = CenterContainer.new()
	prev_center.custom_minimum_size = Vector2(0, 150)
	var prev_wrap: Control = Control.new()
	prev_wrap.custom_minimum_size = Vector2(150, 150)
	var dmech: DirectionalMecha = DirectionalMecha.new()
	dmech.chassis = equipped
	dmech.display_height = 160.0
	dmech.position = Vector2(75, 100)
	prev_wrap.add_child(dmech)
	prev_center.add_child(prev_wrap)
	v.add_child(prev_center)
	dmech.play("walk")

	var _mk_titre: bool = false
	for mech: Dictionary in GameState.MECHS:
		var id: String = String(mech["id"])
		if mech.has("mk") and not _mk_titre:
			_mk_titre = true
			_title(v, "VERSIONS MK  (essai : memes mecaniques que leur chassis, pieces 3D en plus)", Color(1.0, 0.85, 0.4), 18)
		var owned: bool = SaveManager.owns_mech(id)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_l: Label = Label.new()
		# on annonce ce qui distingue REELLEMENT les chassis : leur gamme d'armes et leur signature
		var noms: Array = []
		for wid in GameState.mech_arsenal(id):
			for wd in GameState.WEAPONS:
				if String(wd["id"]) == String(wid):
					noms.append(String(wd["name"])); break
		# 🚨 Avec 8 chassis, trois lignes chacun rendaient le GARAGE interminable sur telephone
		# (l'audit ergonomie le signalait deja trop dense a DEUX chassis). On garde ce qui
		# DISTINGUE — la phrase d'identite et la gamme — et on laisse tomber la description
		# longue, qui redisait la meme chose en plus de mots.
		var sig_nom: String = GameState.mech_signature(id)
		for wd in GameState.WEAPONS:
			if String(wd["id"]) == sig_nom:
				sig_nom = String(wd["name"]); break
		name_l.text = "%s   —   %s
Armes : %s      signature : %s" % [
			String(mech["name"]), String(mech.get("ligne", "")), ", ".join(noms), sig_nom]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.add_theme_font_size_override("font_size", Palette.fs(17))
		if id == equipped:
			name_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		row.add_child(name_l)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(150, 48)   # 48 dp mini
		if id == equipped:
			b.text = "EQUIPE"
			b.disabled = true
		elif owned:
			b.text = "EQUIPER"
			b.pressed.connect(_equip_mech.bind(id))
		else:
			var cost: int = int(mech["cost"])
			# Rapport Manus 26/09 (identite/lisibilite) : "les couts 1400 et 1800 ne precisent
			# pas leur devise" — verifie contre la ligne du dessous : c'est bien meta_scrap (ferraille).
			b.text = "%d ferraille" % cost
			b.disabled = int(SaveManager.data.get("meta_scrap", 0)) < cost
			b.pressed.connect(_buy_mech.bind(id, cost))
		row.add_child(b)
		v.add_child(row)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	v.add_child(spacer)
	_big_button(v, "RETOUR", _back, Color(0.4, 0.4, 0.5))

func _buy_mech(id: String, cost: int) -> void:
	Audio.sfx("levelup" if SaveManager.buy_mech(id, cost) else "click")
	_build_garage()

func _equip_mech(id: String) -> void:
	SaveManager.equip_mech(id)
	Audio.sfx("click")
	_build_garage()

# --- QUOTIDIEN : daily login rewards (7-day escalating cycle) ---
func _reward_text(r: Dictionary) -> String:
	var parts: Array = []
	if int(r.get("scrap", 0)) > 0: parts.append("%d ferraille" % int(r["scrap"]))
	if int(r.get("crystals", 0)) > 0: parts.append("%d cristaux" % int(r["crystals"]))
	if int(r.get("cores", 0)) > 0: parts.append("%d noyaux" % int(r["cores"]))
	return "  +  ".join(parts)

func _build_daily() -> void:
	_clear()
	var v: VBoxContainer = _scaffold(560.0)
	_title(v, "RECOMPENSES QUOTIDIENNES", Color(0.5, 1.0, 0.7))
	_currency_row(v)
	var claimable: bool = SaveManager.daily_claimable()
	var today_day: int = SaveManager.daily_next_day()
	for i in 7:
		var day: int = i + 1
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl: Label = Label.new()
		lbl.text = "Jour %d   —   %s" % [day, _reward_text(SaveManager.DAILY_REWARDS[i])]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", Palette.fs(19))
		var mk: Label = Label.new()
		mk.add_theme_font_size_override("font_size", Palette.fs(18))
		if claimable and day == today_day:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			mk.text = "<< AUJOURD'HUI"
			mk.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		row.add_child(lbl)
		row.add_child(mk)
		v.add_child(row)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	v.add_child(spacer)
	if claimable:
		_big_button(v, "RECLAMER  (jour %d)" % today_day, _claim_daily, Color(0.2, 0.7, 0.4))
	else:
		_title(v, "Deja reclame aujourd'hui — reviens demain", Color(0.72, 0.8, 0.92), 18)

	# --- daily QUESTS (progress accumulates across the day's runs) ---
	var sp2: Control = Control.new()
	sp2.custom_minimum_size = Vector2(0, 14)
	v.add_child(sp2)
	_title(v, "QUETES DU JOUR", Color(0.5, 1.0, 0.7), 26)
	var qs: Array = SaveManager.quests()
	for i in qs.size():
		var q: Dictionary = qs[i]
		var def: Dictionary = SaveManager.quest_def(String(q.get("id", "")))
		if def.is_empty():
			continue
		var target: int = int(def["target"])
		var prog: int = mini(int(q.get("prog", 0)), target)
		var done: bool = prog >= target
		var claimed: bool = bool(q.get("claimed", false))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl: Label = Label.new()
		lbl.text = "%s   [%d/%d]" % [String(def["desc"]) % target, prog, target]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", Palette.fs(18))
		if claimed:
			lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.55))
		elif done:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		row.add_child(lbl)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(150, 48)   # 48 dp mini
		if claimed:
			b.text = "OK"
			b.disabled = true
		elif done:
			b.text = _reward_text(def.get("reward", {}))
			b.pressed.connect(_claim_quest.bind(i))
		else:
			# Rapport Manus (x2, 26/09) : "les recompenses des quetes ne sont pas affichees" —
			# ce n'etait vrai QUE tant que la quete n'etait pas finie ; le joueur ne savait donc
			# jamais pour quoi il jouait avant l'avoir deja terminee.
			b.text = _reward_text(def.get("reward", {}))
			b.disabled = true
		row.add_child(b)
		v.add_child(row)

	_big_button(v, "RETOUR", _back, Color(0.4, 0.4, 0.5))

func _claim_quest(i: int) -> void:
	var def: Dictionary = SaveManager.claim_quest(i)
	Audio.sfx("levelup" if not def.is_empty() else "click")
	_build_daily()

func _claim_daily() -> void:
	var res: Dictionary = SaveManager.claim_daily()
	Audio.sfx("levelup" if not res.is_empty() else "click")
	_build_daily()

# --- EQUIPEMENT : 4 slots, rarities, upgrade, recycle, crystal pulls ---
const RARITY_COL: Dictionary = {
	"commun": Color(0.72, 0.76, 0.82), "rare": Color(0.45, 0.75, 1.0),
	"epique": Color(0.78, 0.55, 1.0), "legendaire": Color(1.0, 0.82, 0.35)}

func _bonus_text(p: Dictionary) -> String:
	var b: Dictionary = SaveManager.gear_bonus_of(p)
	for k in b:
		var val: float = float(b[k])
		match k:
			"damage_pct": return "+%d%% degats" % int(round(val * 100.0))
			"hp":         return "+%d PV" % int(round(val))
			"speed_pct":  return "+%d%% vitesse" % int(round(val * 100.0))
			"crit":       return "+%d%% crit" % int(round(val * 100.0))
	return ""

func _part_text(p: Dictionary) -> String:
	return "%s niv.%d   %s" % [
		String(SaveManager.GEAR_RARITY_NAMES.get(String(p.get("rarity", "commun")), "?")),
		int(p.get("level", 1)), _bonus_text(p)]

func _build_gear() -> void:
	_clear()
	var v: VBoxContainer = _scaffold(600.0)
	_title(v, "EQUIPEMENT", Color(0.75, 0.65, 1.0))
	_currency_row(v)
	for slot: String in SaveManager.GEAR_SLOTS:
		var uid: int = int(SaveManager.gear_equipped().get(slot, -1))
		var p: Dictionary = SaveManager.gear_part(uid) if uid >= 0 else {}
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl: Label = Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", Palette.fs(18))
		if p.is_empty():
			lbl.text = "%s   —   (vide)" % String(SaveManager.GEAR_SLOT_NAMES[slot])
			lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
		else:
			lbl.text = "%s   —   %s" % [String(SaveManager.GEAR_SLOT_NAMES[slot]), _part_text(p)]
			lbl.add_theme_color_override("font_color", RARITY_COL.get(String(p.get("rarity", "commun")), Color.WHITE))
		row.add_child(lbl)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(140, 48)   # 48 dp mini
		b.text = "GERER"
		b.pressed.connect(_build_gear_slot.bind(slot))
		row.add_child(b)
		v.add_child(row)
	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(0, 12)
	v.add_child(sp)
	# FORGE DETERMINISTE (plan direction artistique, 26/09) : plans obtenus sur les boss (voir
	# Enemy._die -> SaveManager.grant_boss_plan), consommables ici pour fabriquer la piece EXACTE
	# (slot + rarete garantis, jamais de hasard) — vient EN PLUS de l'invocation ci-dessous,
	# ne la remplace pas. Legendaire reste volontairement hors de portee des plans.
	var boss_plans: Array = SaveManager.plans()
	if not boss_plans.is_empty():
		_title(v, "PLANS  (forge deterministe)", Color(0.85, 0.75, 1.0), 22)
		for i in boss_plans.size():
			var plan: Dictionary = boss_plans[i]
			var prow: HBoxContainer = HBoxContainer.new()
			prow.add_theme_constant_override("separation", 10)
			var plbl: Label = Label.new()
			plbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pslot: String = String(plan.get("slot", ""))
			var prarity: String = String(plan.get("rarity", "commun"))
			plbl.text = "%s   —   %s" % [String(SaveManager.GEAR_SLOT_NAMES.get(pslot, pslot)),
				String(SaveManager.GEAR_RARITY_NAMES.get(prarity, prarity))]
			plbl.add_theme_font_size_override("font_size", Palette.fs(18))
			plbl.add_theme_color_override("font_color", RARITY_COL.get(prarity, Color.WHITE))
			prow.add_child(plbl)
			var pb: Button = Button.new()
			pb.custom_minimum_size = Vector2(140, 48)
			pb.text = "FORGER"
			pb.pressed.connect(_forge_plan.bind(i))
			prow.add_child(pb)
			v.add_child(prow)
		var psp: Control = Control.new()
		psp.custom_minimum_size = Vector2(0, 10)
		v.add_child(psp)
	# Rapport Manus 26/09 : "quelle est la probabilite de chaque rarete ?" / "les doublons
	# sont-ils convertis automatiquement ?" — jamais affiche nulle part. Construit depuis les
	# VRAIES constantes (GEAR_RARITY_WEIGHT), jamais un chiffre fige qui pourrait diverger du
	# reglage reel si l'equilibrage change.
	var odds_total: int = 0
	for w2 in SaveManager.GEAR_RARITY_WEIGHT:
		odds_total += int(w2)
	var odds_str: String = "Chances : "
	for i2 in SaveManager.GEAR_RARITIES.size():
		var rn: String = String(SaveManager.GEAR_RARITY_NAMES.get(SaveManager.GEAR_RARITIES[i2], ""))
		var pct: float = 100.0 * float(SaveManager.GEAR_RARITY_WEIGHT[i2]) / maxf(1.0, float(odds_total))
		odds_str += "%s %d%%" % [rn, int(round(pct))]
		if i2 < SaveManager.GEAR_RARITIES.size() - 1:
			odds_str += "  ·  "
	_title(v, odds_str, Color(0.6, 0.65, 0.75), 14)
	# 🚨 verifie contre SaveManager.gear_pull()/gear_salvage() avant d'ecrire ceci : les doublons
	# ne sont PAS convertis automatiquement (gear_pull ne deduplique jamais) — c'est le bouton
	# RECYCLER (gear_salvage, pieces non equipees) qui le fait, a la main.
	_title(v, "Une pièce en trop ? RECYCLER la convertit en noyaux (bouton sur chaque pièce non équipée)",
		Color(0.6, 0.65, 0.75), 14)
	var can_pull: bool = int(SaveManager.data.get("crystals", 0)) >= SaveManager.GEAR_PULL_COST
	if can_pull:
		_big_button(v, "INVOQUER une piece  (%d cristaux)" % SaveManager.GEAR_PULL_COST, _gear_pull, Color(0.5, 0.35, 0.8))
	else:
		_title(v, "Invocation : %d cristaux requis (gagne-en en jouant et au quotidien)" % SaveManager.GEAR_PULL_COST,
			Color(0.7, 0.72, 0.8), 16)
	if Ads.available("free_pull"):
		_big_button(v, "INVOCATION GRATUITE  (%s%d restantes)" % [_ad_tag(), Ads.remaining("free_pull")],
			_gear_pull_ad, Color(0.75, 0.55, 0.2))
	_big_button(v, "RETOUR", _back, Color(0.4, 0.4, 0.5))

func _gear_pull_ad() -> void:
	Ads.show_rewarded("free_pull", func(rewarded: bool) -> void:
		if not rewarded:
			return
		SaveManager.gear_pull(true)   # free = true: no crystal cost, same roll table
		Audio.sfx("levelup")
		_build_gear())

func _gear_pull() -> void:
	var p: Dictionary = SaveManager.gear_pull()
	Audio.sfx("levelup" if not p.is_empty() else "click")
	_build_gear()

func _forge_plan(index: int) -> void:
	var p: Dictionary = SaveManager.forge_from_plan(index)
	Audio.sfx("levelup" if not p.is_empty() else "click")
	_build_gear()

## Per-slot management: equip / upgrade / recycle every owned part of that slot.
func _build_gear_slot(slot: String) -> void:
	_clear()
	var v: VBoxContainer = _scaffold(620.0)
	_title(v, String(SaveManager.GEAR_SLOT_NAMES[slot]), Color(0.75, 0.65, 1.0))
	_currency_row(v)
	var equipped_uid: int = int(SaveManager.gear_equipped().get(slot, -1))
	var any: bool = false
	for p: Dictionary in SaveManager.gear_parts():
		if String(p.get("slot", "")) != slot:
			continue
		any = true
		var uid: int = int(p.get("uid", -1))
		var is_eq: bool = uid == equipped_uid
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl: Label = Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", Palette.fs(17))
		lbl.text = ("* " if is_eq else "  ") + _part_text(p)
		lbl.add_theme_color_override("font_color", RARITY_COL.get(String(p.get("rarity", "commun")), Color.WHITE))
		row.add_child(lbl)
		var be: Button = Button.new()
		be.custom_minimum_size = Vector2(100, 48)   # 48 dp mini
		be.text = "EQUIPE" if is_eq else "EQUIPER"
		be.disabled = is_eq
		if not is_eq:
			be.pressed.connect(func() -> void:
				SaveManager.gear_equip(uid); Audio.sfx("click"); _build_gear_slot(slot))
		row.add_child(be)
		var bu: Button = Button.new()
		bu.custom_minimum_size = Vector2(110, 48)   # 48 dp mini
		var lvl: int = int(p.get("level", 1))
		if lvl >= SaveManager.GEAR_MAX_LEVEL:
			bu.text = "MAX"
			bu.disabled = true
		else:
			# 🚨 Rapport Manus 26/09 : "nx apparait dans le cout d'une amelioration, role et
			# origine non expliques" — "nx" n'est PAS une devise, c'est "cores" (noyaux, deja
			# nomme ailleurs) mal libelle. Le champ debite est bien SaveManager.data["cores"].
			bu.text = "+%d noyaux" % SaveManager.GEAR_UPGRADE_COST
			bu.disabled = int(SaveManager.data.get("cores", 0)) < SaveManager.GEAR_UPGRADE_COST
			bu.pressed.connect(func() -> void:
				Audio.sfx("levelup" if SaveManager.gear_upgrade(uid) else "click"); _build_gear_slot(slot))
		row.add_child(bu)
		var bs: Button = Button.new()
		bs.custom_minimum_size = Vector2(100, 48)   # 48 dp mini
		bs.text = "RECYCLER"
		bs.disabled = is_eq   # can't recycle what you're wearing
		if not is_eq:
			bs.pressed.connect(func() -> void:
				Audio.sfx("scrap" if SaveManager.gear_salvage(uid) else "click"); _build_gear_slot(slot))
		row.add_child(bs)
		v.add_child(row)
	if not any:
		_title(v, "Aucune piece pour cet emplacement — invoque-en une", Color(0.7, 0.72, 0.8), 17)
	_big_button(v, "RETOUR", _build_gear, Color(0.4, 0.4, 0.5))

## Back to the hub (full scene reload).
func _replay() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

## Straight into another run at the SAME difficulty — the survivor-like loop lives on fast
## re-entry, and going through hub -> JOUER -> difficulty for every retry kills it.
func _replay_now() -> void:
	var g: Node = game
	queue_free()
	get_tree().paused = false
	if g != null and g.has_method("restart_run"):
		g.restart_run()
	else:
		get_tree().reload_current_scene()
