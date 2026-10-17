import os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game"))
p = 'scenes/ui/HUD.gd'
s = open(p, encoding='utf-8').read()

CLS = '''## ======================= ONGLET DE COMPETENCES (17/10, patron : « un onglet bien evident, stylise, en bas a droite ») =======================
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

'''
anchor = "class StickRing extends Control:"
assert anchor in s
s = s.replace(anchor, CLS + anchor, 1)
s = s.replace("var _od_btn: Button       # tactile trigger", "var _dock: Control\nvar _skill_btns: Array = []\nvar _od_btn: Button       # tactile trigger", 1)

old = "	# OPTIONS button (top-right) — opens the in-run settings panel (music/sfx/auto-aim/orientation)"
assert old in s
BUILD = '''	# --- ONGLET DE COMPETENCES : cadre + 3 boutons (BOUCLIER / SPECIAL / JET PACK), ancre en bas a droite ---
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

'''
s = s.replace(old, BUILD + old, 1)

old = "	_od_btn.position = Vector2(vp.x - ob.x - pad, vp.y - ob.y - pad * 1.4)\n"
assert old in s
LAY = '''	# dock de competences : bas droite ; la SURCHARGE se pose JUSTE AU-DESSUS quand elle est prete
	var bs: float = clampf(70.0 * k, 54.0, 92.0)
	var gap: float = 10.0 * k
	var dock_w: float = bs * 3.0 + gap * 4.0 + 8.0
	var dock_h: float = bs + 28.0 + 26.0 * k
	if _dock != null:
		_dock.size = Vector2(dock_w, dock_h)
		_dock.position = Vector2(vp.x - dock_w - pad, vp.y - dock_h - pad * 1.2)
		for i in _skill_btns.size():
			var sb2: Control = _skill_btns[i]
			sb2.size = Vector2(bs, bs)
			sb2.position = Vector2(gap + 4.0 + float(i) * (bs + gap), 28.0)
	_od_btn.position = Vector2(vp.x - ob.x - pad, vp.y - dock_h - ob.y - pad * 2.0)
'''
s = s.replace(old, LAY, 1)

old = "func _on_od_pressed() -> void:"
HAND = '''func _on_skill_pressed(id: String) -> void:
	if player != null and is_instance_valid(player) and player.has_method("use_skill"):
		player.use_skill(id)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_J: _on_skill_pressed("shield")
			KEY_K: _on_skill_pressed("special")
			KEY_L: _on_skill_pressed("jet")

'''
s = s.replace(old, HAND + old, 1)
open(p, 'w', encoding='utf-8', newline='').write(s)
print("ok")
