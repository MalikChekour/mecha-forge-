extends Node2D
class_name DwellZone
## Zone a presence cumulee (27/09, rapports "Terminal de délestage" / "Archives-machines") :
## AUCUN pattern "accumuler tant qu'on reste dans la zone, remettre a zero en sortant" n'existait
## avant (GroundZone.gd est un pur minuteur ; les flips de PropScatter.gd sont instantanes).
## Distance simple par polling (meme convention que healer/pusher dans Enemy.gd) — pas de
## collision Area2D. Un seul noeud reutilisable : chaque prop l'instancie, lui donne `player`,
## et ecoute `filled` pour SA propre reaction (le visuel de jauge par defaut ci-dessous suffit
## pour un prototype, mais peut etre ignore si le prop dessine la sienne).
signal filled   # emis UNE fois quand progress atteint 1.0 ; ne se reemet qu'apres un reset complet

var player: Node2D            # injecte par le prop qui cree cette zone
var radius: float = 90.0
var fill_time: float = 1.2    # secondes de presence continue requises
var progress: float = 0.0     # 0..1, lecture seule pour le prop appelant
var active: bool = true       # le prop peut suspendre la zone (ex: en recharge) sans la detruire
var col: Color = Color(0.4, 0.9, 1.0, 0.85)
var _filled_emitted: bool = false

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D   # auto-resolu si non injecte
	if not active or player == null or not is_instance_valid(player):
		if progress > 0.0:
			progress = 0.0
			_filled_emitted = false
			queue_redraw()
		return
	var inside: bool = global_position.distance_squared_to(player.global_position) <= radius * radius
	var before: float = progress
	if inside:
		progress = minf(1.0, progress + delta / fill_time)
		if progress >= 1.0 and not _filled_emitted:
			_filled_emitted = true
			filled.emit()
	else:
		# "quitter le rayon annule la charge" (rapport, verbatim) : reset immediat, pas une decroissance.
		progress = 0.0
		_filled_emitted = false
	if progress != before:
		queue_redraw()

func _draw() -> void:
	if progress <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius * 0.9, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, col, 4.0, true)
