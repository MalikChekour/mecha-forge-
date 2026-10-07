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
