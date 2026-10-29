class_name EnemyOverlay
extends Node2D
## LISIBILITE SANS CREDIT (29/10, plan diversite, etape 1). Dessin STATIQUE (aucun _process : redessine
## seulement quand une propriete change) -> cout quasi nul meme a 220 ennemis.
##   mode "under" (z -1, sous le sprite) : insigne de ROLE au sol (anneau couleur du role + glyphe + points
##                de palier) et CAPE des elites.
##   mode "over"  (z 4, sur le sprite)   : EPEE + NOM des elites, plaques/chevrons MK2, blindage INTER.

var mode: String = "under"
var role: String = ""
var col: Color = Color.WHITE
var center: Vector2 = Vector2.ZERO     # centre visible du corps (Enemy._visual_offset)
var body_h: float = 124.0
var half_w: float = 44.0
var elite: bool = false
var tier_tag: String = ""
var label: String = ""
var dtier: int = 1
var cape_col: Color = Color(0.62, 0.08, 0.12)

func _feet() -> Vector2:
	return Vector2(center.x, center.y + body_h * 0.44)

func _draw() -> void:
	if mode == "under":
		if elite:
			_draw_cape()
		_draw_insignia()
	else:
		if tier_tag == "inter":
			_draw_inter()
		elif tier_tag == "mk2":
			_draw_mk2()
		if elite:
			_draw_sword()
			_draw_name()

func _draw_insignia() -> void:
	var f: Vector2 = _feet()
	var r: float = half_w
	draw_set_transform(f, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, r, Color(col, 0.16))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(col, 0.9), 4.0)
	var g: float = r * 0.42
	var gc: Color = Color(col, 0.95)
	match role:
		"fantassin":
			draw_line(Vector2(-g, 0), Vector2(g, 0), gc, 5.0)
		"essaim":
			draw_polyline(PackedVector2Array([Vector2(-g, g * 0.5), Vector2(0, -g * 0.6), Vector2(g, g * 0.5)]), gc, 5.0)
			draw_polyline(PackedVector2Array([Vector2(-g, g * 1.2), Vector2(0, g * 0.1), Vector2(g, g * 1.2)]), gc, 4.0)
		"bouclier":
			var hx: PackedVector2Array = PackedVector2Array()
			for i in 7:
				hx.append(Vector2.from_angle(TAU * float(i) / 6.0 + PI / 6.0) * g)
			draw_polyline(hx, gc, 5.0)
		"sniper":
			draw_arc(Vector2.ZERO, g * 0.8, 0.0, TAU, 20, gc, 3.0)
			draw_line(Vector2(-g * 1.3, 0), Vector2(g * 1.3, 0), gc, 3.0)
			draw_line(Vector2(0, -g * 1.3), Vector2(0, g * 1.3), gc, 3.0)
		"kamikaze":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -g), Vector2(g, g * 0.8), Vector2(-g, g * 0.8)]), gc)
			draw_line(Vector2(0, -g * 0.4), Vector2(0, g * 0.3), Color(0, 0, 0, 0.9), 4.0)
		"invocateur":
			for i in 3:
				draw_circle(Vector2.from_angle(TAU * float(i) / 3.0 - PI / 2.0) * g * 0.8, g * 0.32, gc)
		"artilleur":
			draw_arc(Vector2.ZERO, g, 0.0, TAU, 20, gc, 3.0)
			draw_circle(Vector2.ZERO, g * 0.3, gc)
			for i in 4:
				var v: Vector2 = Vector2.from_angle(TAU * float(i) / 4.0)
				draw_line(v * g * 1.05, v * g * 1.55, gc, 3.0)
		"reparateur":
			draw_rect(Rect2(-g * 0.28, -g, g * 0.56, g * 2.0), gc)
			draw_rect(Rect2(-g, -g * 0.28, g * 2.0, g * 0.56), gc)
		"elite":
			var st: PackedVector2Array = PackedVector2Array()
			for i in 11:
				var rr: float = g * (1.15 if i % 2 == 0 else 0.5)
				st.append(Vector2.from_angle(-PI / 2.0 + TAU * float(i) / 10.0) * rr)
			draw_colored_polygon(st.slice(0, 10), gc)
	# points de PALIER (1..6) sur l'avant de l'anneau : le crescendo se lit d'un coup d'oeil
	for i in dtier:
		var a: float = PI * 0.5 + (float(i) - float(dtier - 1) * 0.5) * 0.28
		draw_circle(Vector2.from_angle(a) * (r + 7.0), 4.0, Color(1.0, 1.0, 1.0, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_cape() -> void:
	var c: Vector2 = center
	var sy: float = c.y - body_h * 0.24
	var by: float = c.y + body_h * 0.40
	var w0: float = half_w * 0.45
	var w1: float = half_w * 0.95
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(c.x - w0, sy), Vector2(c.x + w0, sy), Vector2(c.x + w1, by),
		Vector2(c.x + w1 * 0.35, by - 10.0), Vector2(c.x, by + 6.0), Vector2(c.x - w1 * 0.35, by - 10.0), Vector2(c.x - w1, by)])
	draw_colored_polygon(pts, Color(cape_col, 0.92))
	pts.append(pts[0])
	draw_polyline(pts, Color(1.0, 0.8, 0.3, 0.9), 2.0)

func _draw_sword() -> void:
	var c: Vector2 = center
	var hilt: Vector2 = Vector2(c.x + half_w * 0.85, c.y + body_h * 0.12)
	var tip: Vector2 = Vector2(c.x + half_w * 1.25, c.y - body_h * 0.55)
	draw_line(hilt, tip, Color(0.55, 0.95, 1.0, 0.30), 11.0)
	draw_line(hilt, tip, Color(0.92, 1.0, 1.0, 0.95), 4.0)
	var ax: Vector2 = (tip - hilt).normalized().orthogonal() * 9.0
	draw_line(hilt - ax, hilt + ax, Color(1.0, 0.78, 0.25), 4.0)

func _draw_name() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null or label == "":
		return
	var pos: Vector2 = Vector2(-110.0, center.y - body_h * 0.62 - 10.0)
	draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 13, 4, Color(0, 0, 0, 0.85))
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 13, Color(1.0, 0.82, 0.3))

func _draw_mk2() -> void:
	var c: Vector2 = center
	var oc: Color = Color(1.0, 0.62, 0.25, 0.95)
	for k in 2:
		var y: float = c.y - body_h * 0.08 + float(k) * 10.0
		draw_polyline(PackedVector2Array([Vector2(c.x - 14.0, y), Vector2(c.x, y - 8.0), Vector2(c.x + 14.0, y)]), oc, 4.0)
	draw_arc(c, half_w * 1.02, PI * 1.15, PI * 1.85, 14, Color(0.85, 0.88, 0.95, 0.75), 4.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var pos: Vector2 = Vector2(-40.0, c.y - body_h * 0.55)
		draw_string_outline(font, pos, "MK2", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, 4, Color(0, 0, 0, 0.85))
		draw_string(font, pos, "MK2", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, oc)

func _draw_inter() -> void:
	var c: Vector2 = center
	var steel: Color = Color(0.78, 0.82, 0.9, 0.9)
	for i in 4:
		var a0: float = TAU * float(i) / 4.0 + 0.25
		draw_arc(c, half_w * 1.12, a0, a0 + 1.05, 10, steel, 6.0)
	draw_arc(c, half_w * 1.12, 0.0, TAU, 36, Color(1.0, 0.35, 0.3, 0.35), 2.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var pos: Vector2 = Vector2(-60.0, c.y - body_h * 0.62 - 12.0)
		draw_string_outline(font, pos, "INTERMEDIAIRE", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, 4, Color(0, 0, 0, 0.85))
		draw_string(font, pos, "INTERMEDIAIRE", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, Color(1.0, 0.55, 0.45))