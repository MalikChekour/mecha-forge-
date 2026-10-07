extends Node2D
class_name LockChevron
## Repere de verrouillage missile (polish VFX, 27/09 — rapport externe "Missiles : verrouillage
## et courbe amortie"). Affiche quelle cible un missile a tete chercheuse poursuit REELLEMENT,
## pour que le joueur comprenne pourquoi elle a ete touchee. Purement cosmetique : ne touche
## jamais au ciblage (Projectile._find_homing_target reste l'unique source de verite).
var col: Color = Color(1.0, 0.75, 0.25)

func _draw() -> void:
	var w: float = 9.0
	var h: float = 10.0
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-w, -h * 0.25), Vector2(0.0, h * 0.85), Vector2(w, -h * 0.25),
		Vector2(0.0, h * 0.25),
	])
	draw_colored_polygon(pts, col)
