extends Area2D
class_name Pickup
## XP gem / scrap / bonus drop. Bobs in place until the player is near, then vacuums in
## (magnet). No physics signals — proximity handled by distance so nothing can crash
## inside area callbacks. Pooled by Game (deactivate/reactivate instead of free).

var kind: String = "xp"
var value: int = 1
var player: Node2D
var game: Node

var _spr: Sprite2D
var _light: Sprite2D          # additive glow, not a dynamic light (see _ready)
var _t: float = 0.0
var _base_y: float = 0.0
var _homing: bool = false

func setup(pos: Vector2, k: String, val: int, plr: Node2D) -> void:
	global_position = pos
	_base_y = pos.y
	kind = k
	value = val
	player = plr
	_t = 0.0
	_homing = false
	monitoring = false
	monitorable = false
	visible = true
	set_physics_process(true)
	add_to_group("pickups")
	if _spr == null:
		_spr = Sprite2D.new()
		add_child(_spr)
		# Additive glow sprite, NOT a PointLight2D. Pickups are unbounded (every kill drops one) and
		# in gl_compatibility each dynamic light pulls its lit items out of the batch and is tested
		# against them every frame — dozens of gems on screen was a constant mobile tax.
		_light = Sprite2D.new()
		_light.material = Tex.add_mat()
		_light.z_index = -1
		add_child(_light)
	# refresh appearance every time (a pooled xp gem may be reused as scrap/bonus)
	# XP gems are colour-tiered by value so the player reads a swarm-drop vs an elite-drop at a glance
	var col: Color
	if k == "xp":
		col = Color(0.45, 1.0, 0.55) if val <= 1 else (Color(0.35, 0.7, 1.0) if val == 2 else Palette.BONUS)  # green<blue<gold
	elif k == "bonus":
		col = Palette.BONUS
	elif k == "skill":
		# 🚨 DALTONISME. Mesure (matrices Machado, severite 1.0, distance RGB sur 441) :
		# l'ancien violet (0.78,0.52,1.0) et la gemme d'XP bleue etaient separes de 3 SEULEMENT
		# en deuteranopie — la forme la plus frequente, ~5 % des hommes. Autrement dit :
		# indiscernables. Idem pour l'ancien vert de soin (0.4,1.0,0.5) et la gemme verte,
		# separes de 13 en deuteranopie... et de 18 en vision NORMALE, donc confus pour tout
		# le monde. Les deux valeurs ci-dessous ont ete CHOISIES en maximisant la pire
		# separation sur les quatre visions (normale, protan, deutan, tritan) : elle passe de
		# 3 a 57. Toute retouche de ces teintes doit refaire ce calcul.
		col = Color(0.85, 0.2, 0.95)          # magenta franc : orbe de competence
	elif k == "heal":
		col = Color(0.85, 1.0, 0.92)          # vert presque blanc : trousse de soin
	elif k == "od":
		col = Color(1.0, 0.62, 0.2)           # amber energy cell -> Overdrive gauge
	elif k == "arme_volee":
		# 🚨 violet/indigo choisi pour rester loin des signaux deja pris (rouge = degats subis,
		# or = bonus, ambre = od, magenta = skill) — mais PAS repasse par la mesure Machado
		# qui a fixe les teintes skill/heal ci-dessus. A refaire si un daltonien le confond.
		col = Color(0.55, 0.48, 1.0)          # butin de guerre : arme empruntee sur un boss
	elif k == "scrap":
		col = Palette.ACCENT
	else:
		col = Palette.CYAN
	var big: bool = k == "bonus" or k == "skill" or k == "heal" or k == "od" or k == "arme_volee"
	_spr.texture = Tex.get_tex("res://assets/pickups/%s.png" % k, col, 24)
	# `skill` rejoint les teintes appliquees : sans ca, seul son halo prenait la couleur et la
	# correction daltonisme ci-dessus n'aurait porte que sur la lueur, pas sur l'objet.
	_spr.modulate = col if (k == "xp" or k == "heal" or k == "od" or k == "skill") else Color.WHITE
	var th: float = float(_spr.texture.get_height())
	if th > 0.0:
		_spr.scale = Vector2.ONE * ((34.0 if big else 24.0) / th)
	_light.texture = Tex.glow(col, 64)
	_light.modulate = Color(col.r, col.g, col.b, 0.52 if big else 0.32)
	_light.scale = Vector2.ONE * ((2.8 if big else 1.9) * (34.0 if big else 24.0) / 64.0)

func _physics_process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return
	var to: Vector2 = player.global_position - global_position
	var d: float = to.length()
	var mrange: float = float(player.magnet_range) if "magnet_range" in player else 360.0
	if d < mrange or GameState.overdrive_active:   # Overdrive vacuums every pickup on the map
		_homing = true
	if _homing:
		# vacuum speed stays above player speed so gems catch a fleeing player
		global_position += to.normalized() * (400.0 + (360.0 - min(d, 360.0))) * delta
	else:
		global_position.y = _base_y + sin(_t * 3.0) * 3.0
	if d < 30.0:
		Audio.sfx("scrap" if kind == "scrap" else "xp", 0.12)
		if kind == "xp":
			GameState.add_xp(value)
		elif kind == "skill":
			if game != null and game.has_method("grant_skill"):
				game.grant_skill()                                          # free random competence
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("levelup", player.global_position, 0.0, 1.2)  # golden burst
		elif kind == "bonus":
			if player.has_method("heal"):
				player.heal(25.0)
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("heal", player.global_position, 0.0, 1.3)   # green rising sparkles on the player
			GameState.add_overdrive(0.18)
			GameState.add_scrap(6)
		elif kind == "heal":
			if player.has_method("heal"):
				player.heal(30.0)
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("heal", player.global_position, 0.0, 1.2)
		elif kind == "od":
			GameState.add_overdrive(0.30)                                   # a real chunk of the gauge
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("energy", player.global_position, 0.0, 1.0, Color(1.0, 0.7, 0.3))
		elif kind == "arme_volee":
			# 🚨 BUTIN DE GUERRE (patron, 23/09) : emprunt temporaire, gere entierement cote
			# Player (choix de l'arme + minuteur + restauration) pour que Pickup.gd reste ce
			# qu'il est deja — un simple dispatcher, aucune logique de jeu propre ici.
			if player.has_method("borrow_weapon"):
				player.borrow_weapon()
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("energy", player.global_position, 0.0, 1.0, Color(0.55, 0.48, 1.0))
		else:
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("pickup", global_position, 0.0, 0.42, Color(1.0, 0.85, 0.4))   # small sparkle on scrap
			GameState.add_scrap(value)
		_collected()

func _collected() -> void:
	if game != null and game.has_method("reclaim_pickup"):
		game.reclaim_pickup(self)
	else:
		queue_free()

func deactivate() -> void:
	set_physics_process(false)
	visible = false
	global_position = Vector2(1.0e7, 1.0e7)
	remove_from_group("pickups")
