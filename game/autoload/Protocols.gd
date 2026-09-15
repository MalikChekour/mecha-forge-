extends Node
## PROTOCOLES — modificateurs de run tirés au sort au départ. Le moteur de FRAÎCHEUR : deux runs
## ne se ressemblent jamais. Zéro art de mecha — ce sont des multiplicateurs purs, empilés aux
## MÊMES points que les multiplicateurs de difficulté (cf. GameState.diff / EnemySpawner._scale_enemy).
##
## Chaque protocole publie un dict "m" de multiplicateurs (défaut 1.0 = neutre). roll() en tire 1-2,
## compose leurs multiplicateurs, et remplit les champs lus par le reste du jeu.

# --- multiplicateurs composés (1.0 = aucun effet), recalculés à chaque roll() ---
var spawn_rate: float = 1.0    # densité de spawn (EnemySpawner)
var enemy_hp: float = 1.0
var enemy_speed: float = 1.0
var enemy_dmg: float = 1.0
var enemy_scale: float = 1.0   # taille VISUELLE seulement (le hitbox 'radius' ne bouge pas)
var reward: float = 1.0        # xp + scrap
var player_speed: float = 1.0

var active: Array = []         # protocoles en vigueur ce run (dicts du CATALOG)

# "tag" = catégorie d'axe. On ne tire jamais deux protocoles de la MÊME catégorie ensemble, sinon
# leurs effets s'empilent de façon incohérente (ex. BLINDÉS×COLOSSES = ×3.1 PV, injouable au Lv1).
const CATALOG: Array = [
	# 🚨 renomme : ce protocole s'appelait « SURCHARGE », exactement comme le BOUTON d'arme du
	# HUD (la transformation du joueur). Les deux pouvaient s'afficher en meme temps — bandeau
	# de protocole en haut, bouton en bas a droite — et rien ne distinguait un modificateur de
	# densite d'ennemis d'une capacite du joueur. Le nom du bouton ne bouge pas, c'est le
	# protocole qui change. L'id reste « surcharge » (sauvegardes et telemetrie).
	{"id": "surcharge", "name": "DÉFERLANTE", "tag": "densite", "desc": "Ça grouille — et ça paie.",
		"color": Color(0.88, 0.45, 0.22), "m": {"spawn_rate": 1.6, "reward": 1.35}},
	{"id": "essaim", "name": "ESSAIM", "tag": "densite", "desc": "Deux fois plus, deux fois plus fragiles.",
		"color": Color(0.30, 0.78, 0.86), "m": {"spawn_rate": 2.0, "enemy_hp": 0.55}},
	{"id": "blindes", "name": "BLINDÉS", "tag": "tank", "desc": "Des murs sur pattes — butin épais.",
		"color": Color(0.62, 0.68, 0.80), "m": {"enemy_hp": 1.55, "reward": 1.4}},
	{"id": "colosses", "name": "COLOSSES", "tag": "tank", "desc": "Moins nombreux, bien plus lourds.",
		"color": Color(0.68, 0.55, 0.92), "m": {"enemy_hp": 1.9, "enemy_dmg": 1.2, "enemy_scale": 1.3, "spawn_rate": 0.6, "reward": 1.6}},
	{"id": "frenesie", "name": "FRÉNÉSIE", "tag": "vitesse", "desc": "Tout accélère, toi compris.",
		"color": Color(0.90, 0.78, 0.30), "m": {"enemy_speed": 1.30, "player_speed": 1.22, "reward": 1.2}},
	{"id": "veloces", "name": "VÉLOCES", "tag": "vitesse", "desc": "Vifs et cassants.",
		"color": Color(0.45, 0.85, 0.55), "m": {"enemy_speed": 1.35, "enemy_hp": 0.78}},
	{"id": "manne", "name": "MANNE", "tag": "eco", "desc": "Le jackpot — mais ils frappent fort.",
		"color": Color(0.95, 0.80, 0.35), "m": {"reward": 2.0, "enemy_dmg": 1.3}},
	{"id": "assaut", "name": "ASSAUT", "tag": "aggro", "desc": "Ils cognent — mais tu files.",
		"color": Color(0.86, 0.40, 0.40), "m": {"enemy_dmg": 1.4, "player_speed": 1.18, "reward": 1.3}},
]

func reset() -> void:
	spawn_rate = 1.0; enemy_hp = 1.0; enemy_speed = 1.0; enemy_dmg = 1.0
	enemy_scale = 1.0; reward = 1.0; player_speed = 1.0
	active = []

## Tire des protocoles pour le run. n<0 -> 1-2 aléatoire (majorité de 2), catégories DISTINCTES.
func roll(n: int = -1) -> void:
	reset()
	var pool: Array = CATALOG.duplicate()
	pool.shuffle()
	var count: int = n if n > 0 else (2 if randf() < 0.72 else 1)
	var used_tags: Array = []
	for p in pool:
		if active.size() >= count:
			break
		if String(p["tag"]) in used_tags:   # jamais deux protocoles de la même catégorie
			continue
		used_tags.append(String(p["tag"]))
		active.append(p)
		var m: Dictionary = p["m"]
		spawn_rate *= float(m.get("spawn_rate", 1.0))
		enemy_hp *= float(m.get("enemy_hp", 1.0))
		enemy_speed *= float(m.get("enemy_speed", 1.0))
		enemy_dmg *= float(m.get("enemy_dmg", 1.0))
		enemy_scale *= float(m.get("enemy_scale", 1.0))
		reward *= float(m.get("reward", 1.0))
		player_speed *= float(m.get("player_speed", 1.0))
	# Filet de sécurité : borne les stacks pour qu'aucune combinaison ne rende un run incohérent.
	enemy_hp = clampf(enemy_hp, 0.45, 2.1)
	enemy_speed = clampf(enemy_speed, 0.7, 1.5)
	enemy_dmg = clampf(enemy_dmg, 0.6, 1.6)
	spawn_rate = clampf(spawn_rate, 0.5, 2.4)
	player_speed = clampf(player_speed, 0.9, 1.35)
	reward = clampf(reward, 0.8, 2.6)

## "SURCHARGE · BLINDÉS" — for the HUD banner/chips.
func label() -> String:
	var names: Array = []
	for p in active:
		names.append(String(p["name"]))
	return " · ".join(names)

## Grammatically-correct banner line (singular/plural).
func banner_text() -> String:
	var word: String = "PROTOCOLE" if active.size() <= 1 else "PROTOCOLES"
	return "%s   %s" % [word, label()]

## Ce que les protocoles du run FONT, en clair.
## 🚨 Seul leur NOM etait annonce. Or ils changent la partie enormement — jusqu'a x2,0 sur le
## nombre d'ennemis, x1,9 sur leurs PV, x1,6 sur leurs degats — et c'est tire au hasard. Mesure
## sur le banc : a difficulte ET biome identiques, la densite moyenne d'ennemis va de 5 a 57
## selon le protocole tire. Un joueur pouvait donc trouver le meme chapitre « trop dur » puis
## « trop facile » sans avoir rien change, sans aucune explication a l'ecran.
func desc_text() -> String:
	var out: Array = []
	for p in active:
		var d: String = String(p.get("desc", ""))
		if d != "":
			out.append("%s : %s" % [String(p["name"]), d])
	return "   ".join(out)
