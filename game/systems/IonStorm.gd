extends Node2D

## Événement In-Run Dynamique : Tempête Ionique & Surtension Électromagnétique.
## Provoque une surtension des réacteurs du joueur (+25% cadence + arcs électriques passifs)
## tout en bombardant l'arène de frappes d'éclairs télégraphiées à esquiver.
## À l'extinction de la tempête, un Noyau Ionique Surchargé est généré sur place.

var game: Node
var player: Node2D
var active: bool = true
var duration: float = 22.0
var _elapsed: float = 0.0
var _zap_cd: float = 0.8
var _strike_timer: float = 2.0
var _ambient_pulse: float = 0.0

# Danger strike zones: [{ "pos": Vector2, "timer": float, "max_t": float, "radius": float }]
var _strikes: Array = []
# Visual active lightning bolts: [{ "from": Vector2, "to": Vector2, "alpha": float }]
var _bolts: Array = []

func _ready() -> void:
	z_index = 6
	add_to_group("ion_storms")

func setup(g: Node, p: Node2D) -> void:
	game = g
	player = p
	active = true
	_elapsed = 0.0
	_strikes.clear()
	_bolts.clear()
	
	if game != null and game.has_method("show_banner"):
		game.show_banner("⚡ SURTENSION IONIQUE DÉTECTÉE ! ⚡", Color(0.3, 0.85, 1.0))
	Haptics.overdrive()
	Audio.sfx("levelup")

func _process(delta: float) -> void:
	if not active or not GameState.alive:
		return
	
	_elapsed += delta
	_ambient_pulse += delta * 6.0
	
	# Mise à jour des éclairs visuels actifs
	var bi: int = _bolts.size() - 1
	while bi >= 0:
		_bolts[bi]["alpha"] -= delta * 3.5
		if _bolts[bi]["alpha"] <= 0.0:
			_bolts.remove_at(bi)
		bi -= 1
	
	# Fin de la tempête ?
	if _elapsed >= duration:
		_complete_storm()
		return
	
	# 1. Buff Joueur : Décharge d'arcs électriques passifs vers les ennemis proches
	_zap_cd -= delta
	if _zap_cd <= 0.0 and player != null and is_instance_valid(player):
		_zap_cd = 1.1
		_trigger_player_ion_discharge()
	
	# 2. Spawn des zones de frappes de foudre télégraphiées
	_strike_timer -= delta
	if _strike_timer <= 0.0 and player != null and is_instance_valid(player):
		_strike_timer = randf_range(2.6, 3.4)
		_spawn_strike_telegraphs()
	
	# 3. Progression et détonation des frappes
	var si: int = _strikes.size() - 1
	while si >= 0:
		var st: Dictionary = _strikes[si]
		st["timer"] -= delta
		if st["timer"] <= 0.0:
			_detonate_lightning_strike(st["pos"], float(st.get("radius", 90.0)))
			_strikes.remove_at(si)
		si -= 1
	
	queue_redraw()

func _trigger_player_ion_discharge() -> void:
	if player == null or not is_instance_valid(player):
		return
	var origin: Vector2 = player.global_position
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var targets: Array = []
	for e in enemies:
		if e is Enemy and (e as Enemy).alive:
			var d: float = origin.distance_to((e as Node2D).global_position)
			if d <= 320.0:
				targets.append({"enemy": e, "dist": d})
	
	if targets.is_empty():
		return
	
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])
	var max_hits: int = mini(3, targets.size())
	for i in range(max_hits):
		var en: Enemy = targets[i]["enemy"]
		if en != null and is_instance_valid(en) and en.alive:
			en.take_damage(48.0, "ion_overcharge", "plasma")
			_bolts.append({
				"from": to_local(origin),
				"to": to_local(en.global_position),
				"alpha": 1.0,
				"col": Color(0.4, 0.9, 1.0)
			})
	Haptics.tap()

func _spawn_strike_telegraphs() -> void:
	if player == null or not is_instance_valid(player):
		return
	var p_pos: Vector2 = player.global_position
	var count: int = randi_range(2, 3)
	for i in count:
		var angle: float = randf() * TAU
		var dist: float = randf_range(70.0, 260.0)
		var strike_pos: Vector2 = p_pos + Vector2(cos(angle), sin(angle)) * dist
		_strikes.append({
			"pos": strike_pos,
			"timer": 1.35,
			"max_t": 1.35,
			"radius": 95.0
		})

func _detonate_lightning_strike(pos: Vector2, radius: float) -> void:
	Haptics.heavy()
	Audio.sfx("explosion")
	
	# Éclair vertical descendant du ciel vers la position
	var local_pos: Vector2 = to_local(pos)
	_bolts.append({
		"from": local_pos + Vector2(randf_range(-40.0, 40.0), -600.0),
		"to": local_pos,
		"alpha": 1.4,
		"col": Color(1.0, 1.0, 1.0)
	})
	
	if game != null and game.has_method("shield_ripple"):
		game.shield_ripple(pos, radius * 1.6, Color(0.3, 0.8, 1.0))
	
	# Dégâts aux ennemis pris dans l'impact
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e is Enemy and (e as Enemy).alive:
			var d: float = pos.distance_to((e as Node2D).global_position)
			if d <= radius:
				(e as Enemy).take_damage(190.0, "ion_storm", "bombe")
	
	# Dégâts modérés au joueur s'il est resté dans la zone
	if player != null and is_instance_valid(player):
		var d_player: float = pos.distance_to(player.global_position)
		if d_player <= radius:
			player.take_damage(20.0, pos)

func _complete_storm() -> void:
	active = false
	Haptics.victory()
	Audio.sfx("victory")
	
	# Récompenses & drop du Noyau Ionique Surchargé
	SaveManager.bank_scrap(45)
	SaveManager.data["crystals"] = int(SaveManager.data.get("crystals", 0)) + 2
	
	if game != null and game.has_method("show_banner"):
		game.show_banner("⚡ SURTENSION DISSIPÉE — SYSTÈMES RECHARGÉS ! ⚡", Color(0.4, 0.95, 0.6))
	
	# Rechargement complet du bouclier du joueur
	if player != null and is_instance_valid(player) and player.has_node("ShieldSystem"):
		var shield: Node = player.get_node("ShieldSystem")
		if shield != null and shield.has_method("restore"):
			shield.restore()
	
	queue_free()

func _draw() -> void:
	# 1. Rendu des zones télégraphiées de frappes au sol
	for st in _strikes:
		var lp: Vector2 = to_local(st["pos"])
		var rad: float = float(st.get("radius", 95.0))
		var progress: float = 1.0 - (float(st["timer"]) / maxf(0.01, float(st["max_t"])))
		
		# Cercle extérieur d'avertissement
		draw_arc(lp, rad, 0.0, TAU, 32, Color(0.2, 0.7, 1.0, 0.65), 2.5, true)
		# Remplissage pulsant
		draw_circle(lp, rad, Color(0.1, 0.5, 0.9, 0.12 + 0.1 * sin(_ambient_pulse)))
		# Anneau de rétrécissement de danger
		var cur_r: float = rad * (1.0 - progress)
		draw_circle(lp, maxf(4.0, cur_r), Color(1.0, 0.35, 0.35, 0.45))
		draw_arc(lp, maxf(4.0, cur_r), 0.0, TAU, 24, Color(1.0, 0.9, 0.3, 0.85), 3.0, true)
		# Croix centrale de ciblage
		var cr: float = 12.0
		draw_line(lp - Vector2(cr, 0), lp + Vector2(cr, 0), Color(1.0, 1.0, 1.0, 0.85), 2.0)
		draw_line(lp - Vector2(0, cr), lp + Vector2(0, cr), Color(1.0, 1.0, 1.0, 0.85), 2.0)
	
	# 2. Rendu des arcs et éclairs
	for b in _bolts:
		var from_p: Vector2 = b["from"]
		var to_p: Vector2 = b["to"]
		var alpha: float = clampf(float(b.get("alpha", 1.0)), 0.0, 1.0)
		var base_col: Color = b.get("col", Color(0.4, 0.9, 1.0))
		var col: Color = Color(base_col.r, base_col.g, base_col.b, alpha)
		
		# Tracé en zigzag de foudre
		var steps: int = 5
		var prev: Vector2 = from_p
		for s in range(1, steps):
			var t: float = float(s) / float(steps)
			var mid: Vector2 = from_p.lerp(to_p, t)
			var perp: Vector2 = (to_p - from_p).orthogonal().normalized()
			mid += perp * randf_range(-14.0, 14.0)
			draw_line(prev, mid, col, 3.0)
			draw_line(prev, mid, Color(1, 1, 1, alpha * 0.8), 1.5)
			prev = mid
		draw_line(prev, to_p, col, 3.0)
		draw_line(prev, to_p, Color(1, 1, 1, alpha * 0.8), 1.5)
