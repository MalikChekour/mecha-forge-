extends Node
## Shared color palette (mirror of the bpy render palette in tools/build_mecha.py).
## Used as tints for procedural placeholders when a rendered sprite is missing.

const STEEL: Color = Color(0.34, 0.40, 0.52)
const STEEL_DK: Color = Color(0.17, 0.21, 0.30)
const ACCENT: Color = Color(0.10, 0.55, 0.95)
const CYAN: Color = Color(0.10, 0.85, 1.00)
const GUNMETAL: Color = Color(0.14, 0.15, 0.19)
const ARENA_BG: Color = Color(0.06, 0.055, 0.10)
const BONUS: Color = Color(1.0, 0.82, 0.30)   # gold — bonus caches / their pickups

## Per-biome decor tint. The 3D decor bakes are grey; multiplying a sprite by its
## biome tint "paints" props and scenery into the environment (harmonised) instead of
## leaving them default grey, while staying bright enough not to camouflage.
const BIOME_TINT: Dictionary = {
	"tech":      Color(0.72, 0.83, 1.00),
	"earth":     Color(1.00, 0.83, 0.58),
	"spaceship": Color(0.87, 0.91, 0.99),
	"volcanic":  Color(1.00, 0.60, 0.46),
	"desert":    Color(1.00, 0.86, 0.56),
	"ice":       Color(0.80, 0.93, 1.00),
	"jungle":    Color(0.70, 0.94, 0.62),
	"swamp":     Color(0.76, 0.84, 0.54),
	"cryo":      Color(0.78, 0.94, 1.00),
	"reacteur":  Color(0.75, 1.05, 0.75),
	"ruche":     Color(1.05, 0.78, 1.08),
	"citadelle": Color(1.08, 1.02, 0.82),
	"ruines":    Color(0.95, 0.88, 0.80),
	"abyss":     Color(0.65, 0.95, 1.20),
	"ether":     Color(0.85, 0.65, 1.15),
	"titans":    Color(1.15, 0.85, 0.65),
	"orbit":     Color(0.80, 0.95, 1.15),
	"quantum":   Color(1.10, 1.05, 0.70),
	"ozone":     Color(1.10, 0.70, 1.15),
	"prism":     Color(0.95, 1.10, 1.15),
	"steampunk": Color(1.15, 0.90, 0.70),
	"colosseum": Color(0.90, 1.05, 1.10),
}

static func biome_tint(name: String) -> Color:
	return BIOME_TINT.get(name, Color(0.86, 0.89, 0.96))


## Taille de police d'INTERFACE, commune a tout le jeu.
## Les tailles etaient ecrites en dur (15 a 20 px) sur une base 1280x720 : une fois
## l'ecran d'un telephone, c'etait illisible. Ici on met a l'echelle du plus petit
## cote (comme le reste de l'UI) ET on impose un PLANCHER de lisibilite.
func fs(base: float) -> int:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: float = clampf(minf(vp.x, vp.y) / 720.0, 0.85, 1.7)
	return maxi(17, int(round(base * 1.18 * k)))


## Theme d'interface COMMUN a tout le jeu (menus, sous-menus, ecrans en partie) :
## angles vifs + filet de couleur, comme les sections de l'accueil. Une seule
## definition ici, sinon chaque ecran repart sur les boutons gris de Godot.
func ui_theme() -> Theme:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: float = clampf(minf(vp.x, vp.y) / 720.0, 0.85, 1.7)
	var th: Theme = Theme.new()
	# 05/10, refonte UI hologramme : theme bouton generique cyan+verre, remplace l'ancien gris plat.
	var base: Color = Color(0.15, 0.85, 1.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.12, 0.85)
	sb.set_corner_radius_all(int(8.0 * k))
	sb.border_color = Color(base.r, base.g, base.b, 0.75)
	sb.set_border_width_all(maxi(1, int(2.0 * k)))
	sb.shadow_color = Color(base.r, base.g, base.b, 0.25)
	sb.shadow_size = int(6.0 * k)
	sb.content_margin_left = 16.0 * k; sb.content_margin_right = 16.0 * k
	sb.content_margin_top = 9.0 * k; sb.content_margin_bottom = 9.0 * k
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = Color(base.r * 0.30, base.g * 0.30, base.b * 0.30, 0.88)
	hov.border_color = Color(base.r, base.g, base.b, 1.0)
	hov.shadow_color = Color(base.r, base.g, base.b, 0.45)
	hov.shadow_size = int(10.0 * k)
	var pre: StyleBoxFlat = sb.duplicate()
	pre.bg_color = Color(base.r * 0.48, base.g * 0.48, base.b * 0.48, 0.94)
	pre.border_color = Color(1.0, 1.0, 1.0, 0.9)
	var dis: StyleBoxFlat = sb.duplicate()
	dis.bg_color = Color(0.05, 0.06, 0.08, 0.55); dis.border_color = Color(0.20, 0.25, 0.30)
	dis.shadow_size = 0
	th.set_stylebox("normal", "Button", sb)
	th.set_stylebox("hover", "Button", hov)
	th.set_stylebox("pressed", "Button", pre)
	th.set_stylebox("focus", "Button", sb)
	th.set_stylebox("disabled", "Button", dis)
	th.set_color("font_color", "Button", Color(0.88, 0.94, 1.0))
	th.set_color("font_disabled_color", "Button", Color(0.46, 0.51, 0.57))
	th.set_font_size("font_size", "Button", fs(18))
	return th

# --- MOTION DESIGN & ANIMATION (UI) ---
# Centralized motion design system for a premium "Hologram" feel.

## Simple Fade-In for backgrounds or whole layers (100% safe).
static func fade_in(node: CanvasItem, delay: float = 0.0, dur: float = 0.25) -> Tween:
	node.modulate.a = 0.0
	var t: Tween = node.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(node, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return t

## Pop-in (safe for Container children): starts at alpha 0 and scale from_scale, settles at scale 1.0 and alpha 1.0.
## Never alters node.position so Container layouts remain 100% pixel-perfect.
static func pop_in(node: Control, delay: float = 0.0, dur: float = 0.26, from_scale: float = 0.92) -> void:
	node.modulate.a = 0.0
	var run = func() -> void:
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
		node.pivot_offset = node.size * 0.5
		node.scale = Vector2(from_scale, from_scale)
		var t: Tween = node.create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.set_parallel(true)
		t.tween_property(node, "modulate:a", 1.0, dur * 0.7).set_delay(delay)
		t.tween_property(node, "scale", Vector2.ONE, dur).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if node.is_inside_tree():
		node.get_tree().process_frame.connect(run, Object.CONNECT_ONE_SHOT)
	else:
		node.ready.connect(func() -> void:
			if is_instance_valid(node) and node.is_inside_tree():
				node.get_tree().process_frame.connect(run, Object.CONNECT_ONE_SHOT)
		, Object.CONNECT_ONE_SHOT)

## Staggered reveal for children in a Container (safe: animates alpha and subtle scale, NEVER position).
static func stagger_reveal(container: Control, stagger: float = 0.04, base_delay: float = 0.0) -> void:
	var d: float = base_delay
	for c in container.get_children():
		if c is Control:
			pop_in(c, d, 0.25, 0.94)
			d += stagger

## Alias for backward compatibility: redirects to safe stagger_reveal without breaking positions.
static func stagger_slide(container: Control, _offset: Vector2 = Vector2.ZERO, stagger: float = 0.04, base_delay: float = 0.0) -> void:
	stagger_reveal(container, stagger, base_delay)

## Slide-in: safe fade that does not destroy layout.
static func slide_in(node: Control, _offset: Vector2 = Vector2.ZERO, delay: float = 0.0, dur: float = 0.3) -> Tween:
	return fade_in(node, delay, dur)

## Binds a simple scale bounce to button hover events (desktop only).
static func bind_hover_scale(btn: Control, scale_factor: float = 1.04, dur: float = 0.1) -> void:
	if DisplayServer.is_touchscreen_available():
		return
	btn.mouse_entered.connect(func() -> void:
		if btn.size.length() > 1.0: btn.pivot_offset = btn.size / 2.0
		var t: Tween = btn.create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(btn, "scale", Vector2(scale_factor, scale_factor), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		var t: Tween = btn.create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(btn, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)

