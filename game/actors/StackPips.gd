extends Node2D
class_name StackPips
## Compteur de piles minimal et reutilisable (plan de differenciation des chassis, 26/09) :
## VORTEX (chaine d'alignement, sur le joueur) et BRUISER (brisure, sur la cible marquee)
## en ont chacun besoin. Des points pleins en rangee plutot qu'un texte : pas de police a
## charger, lisible a toute echelle, jamais de risque de chevaucher un systeme de teinte
## deja en place (cf. Enemy.self_modulate, deja utilise par charge/enrage).

## 🚨 patron 26/09 : "lag meme sans beaucoup d'ennemis" — ce noeud tournait a chaque frame pour
## TOUS les porteurs, meme a 0 pile. set() reveille _process() a la creation d'une pile et le
## rendort des qu'il retombe a 0 — plus aucun cout tant que rien n'est affiche.
var count: int = 0:
	set(v):
		count = v
		if v > 0:
			set_process(true)
var col: Color = Color.WHITE
var offset_y: float = -46.0   # au-dessus du sprite par defaut

func _ready() -> void:
	set_process(count > 0)

func _process(_delta: float) -> void:
	visible = count > 0
	if visible:
		queue_redraw()
	else:
		set_process(false)

func _draw() -> void:
	if count <= 0:
		return
	var n: int = mini(count, 5)
	var r: float = 5.0
	var gap: float = 14.0
	var w: float = float(n - 1) * gap
	for i in n:
		var x: float = -w * 0.5 + float(i) * gap
		draw_circle(Vector2(x, offset_y), r, col)
		draw_arc(Vector2(x, offset_y), r, 0.0, TAU, 16, Color(0, 0, 0, 0.6), 1.6, true)
