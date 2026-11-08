extends Area2D
class_name OrbitalDropPod

## Ravitaillement Orbital / Drop Pod d'Urgence (In-Run Dynamic Event).
## Capsule spatiale parachutée périodiquement offrant un objectif tactique dynamique :
## sécuriser la zone pendant 3 secondes pour déverrouiller un coffre chanceux,
## une onde de choc EMP et un boost massif de ressources.

var game: Node
var player: Node2D
var active: bool = true
var time_left: float = 45.0
var capture_progress: float = 0.0
var capture_radius: float = 95.0
var _anim_t: float = 0.0
var _pulse: float = 0.0

func _ready() -> void:
	z_index = 3
	add_to_group("drop_pods")
	monitoring = false
	monitorable = false

func setup(g: Node, p: Node2D, pos: Vector2) -> void:
	game = g
	player = p
	global_position = pos
	time_left = 45.0
	capture_progress = 0.0
	active = true
	queue_redraw()

func _process(delta: float) -> void:
	if not active or not GameState.alive:
		return
	
	_anim_t += delta
	time_left -= delta
	if time_left <= 0.0:
		_expire()
		return
	
	# Verification presence joueur dans la zone de capture
	var inside: bool = false
	if player != null and is_instance_valid(player):
		var d: float = global_position.distance_to(player.global_position)
		if d <= capture_radius:
			inside = true
	
	if inside:
		capture_progress += delta / 3.0   # 3 secondes complètes requises
		if capture_progress >= 1.0:
			_capture_success()
			return
	else:
		capture_progress = maxf(0.0, capture_progress - delta * 0.25)
	
	queue_redraw()

func _capture_success() -> void:
	active = false
	Haptics.victory()
	Audio.sfx("victory")
	
	# 1. Onde de choc EMP massive détruisant les sbires proches
	if game != null and game.has_method("shield_ripple"):
		game.shield_ripple(global_position, 340.0, Color(1.0, 0.88, 0.35))
	
	var tree: SceneTree = get_tree()
	if tree != null:
		for e in tree.get_nodes_in_group("enemies"):
			if e is Enemy and (e as Enemy).alive:
				var dist: float = global_position.distance_to((e as Node2D).global_position)
				if dist <= 350.0:
					(e as Enemy).take_damage(160.0, "emp_pod", "bombe")
	
	# 2. Recompenses et ressources
	SaveManager.bank_scrap(35)
	SaveManager.data["crystals"] = int(SaveManager.data.get("crystals", 0)) + 3
	
	# Soin de 35% PV
	if player != null and is_instance_valid(player):
		player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.35)
		Events.player_damaged.emit(player.hp, player.max_hp)
	
	# 3. Ouverture du coffre chanceux (Lucky Chest de 1, 3 ou 5 cartes)
	if game != null and game.has_method("open_lucky_chest"):
		game.open_lucky_chest()
	
	if game != null and game.has_method("show_banner"):
		game.show_banner("★ LARGAGE ORBITAL SÉCURISÉ ! ★", Color(1.0, 0.88, 0.35))
	
	queue_free()

func _expire() -> void:
	active = false
	if game != null and game.has_method("show_hint"):
		game.show_hint("Largage orbital expiré...", Color(0.7, 0.75, 0.8), 2.5)
	queue_free()

func _draw() -> void:
	if not active:
		return
	
	var pulse: float = 0.85 + 0.15 * sin(_anim_t * 5.0)
	var col_gold: Color = Color(1.0, 0.82, 0.28, 0.95 * pulse)
	var col_zone: Color = Color(1.0, 0.75, 0.2, 0.18 * pulse)
	
	# 1. Zone de capture au sol
	draw_circle(Vector2.ZERO, capture_radius, col_zone)
	draw_arc(Vector2.ZERO, capture_radius, 0.0, TAU, 48, col_gold, 2.5, true)
	
	# 2. Anneau de progression circulaire
	if capture_progress > 0.0:
		var fill_ang: float = TAU * clampf(capture_progress, 0.0, 1.0)
		draw_arc(Vector2.ZERO, capture_radius + 4.0, -PI * 0.5, -PI * 0.5 + fill_ang, 40, Color(0.3, 1.0, 0.5, 0.95), 4.0, true)
	
	# 3. Faisceau laser vertical ascendant vers l'orbite
	var beam_col: Color = Color(1.0, 0.85, 0.3, 0.45 * pulse)
	draw_line(Vector2.ZERO, Vector2(0, -600), beam_col, 8.0)
	draw_line(Vector2.ZERO, Vector2(0, -600), Color(1.0, 1.0, 0.8, 0.85), 2.5)
	
	# 4. Corps hexagonal du Pod
	var hex: PackedVector2Array = PackedVector2Array()
	var pr: float = 24.0
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		hex.append(Vector2(cos(a) * pr, sin(a) * pr))
	draw_colored_polygon(hex, Color(0.12, 0.09, 0.04, 0.95))
	var hex_c: PackedVector2Array = hex.duplicate()
	hex_c.append(hex[0])
	draw_polyline(hex_c, col_gold, 3.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.9, 0.6, pulse))
	
	# 5. Étiquette holographique : décompte de temps
	var font: Font = ThemeDB.fallback_font
	var fs: int = 13
	var txt: String = "📦 DROP POD [%ds]" % int(ceil(time_left))
	var sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var tpos: Vector2 = Vector2(-sz.x * 0.5, -34.0)
	var bg_rect: Rect2 = Rect2(tpos.x - 6.0, tpos.y - fs + 2.0, sz.x + 12.0, fs + 6.0)
	draw_rect(bg_rect, Color(0.05, 0.04, 0.02, 0.85), true)
	draw_rect(bg_rect, col_gold, false, 1.5)
	draw_string(font, tpos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
