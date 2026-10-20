extends Node
class_name EnemySpawner
## Ring-spawns Meshy enemies around the player, ramping rate over the run.
## Data-driven; the 'motion' field maps to the baked animation sheet
## (enemies/<kind>_<motion>.png).

var game: Node
var player: Node2D
var _t: float = 0.0
var _spawn_t: float = 0.0
var speed_mult: float = 1.0   # biome modifier on enemy movement speed
var spawn_mult: float = 1.0   # biome modifier on spawn density
var arena_half: float = 0.0   # bounded-arena clamp for spawns (0 = unbounded)
var arena: Rect2 = Rect2(-1000000, -1000000, 2000000, 2000000)
var difficulty_bonus: float = 0.0   # permanent step-up per cleared zone (set by Game.next_map)
var current_biome: String = "tech"   # set by Game per zone -> filtre le pool d ennemis
## Quel chapitre a ete choisi au demarrage de la run (pas par zone -> jamais touche par
## next_map()/_apply_chapter_biome, seulement au lancement). Sert UNIQUEMENT a distinguer
## "chapitre 1" pour BELIER-01 (voir plus bas) ; ne change jamais en cours de run.
var chapter: int = 1
var enemy_tint: Color = Color(1, 1, 1)   # corruption visuelle du biome, appliquee a chaque ennemi
# Scripted HORDES: a massive coordinated wave that crashes in at timed moments. First at
# ~1 min, then on an interval; each wave grows with run time and stays mobile-safe (capped).
var _wave_t: float = 38.0
const WAVE_INTERVAL: float = 50.0
const ENEMY_CAP: int = 220   # weak swarm dies fast -> allow a denser horde on screen

# SURVIVOR.IO DIFFICULTY MODEL. Their chapter 1 does NOT dump every archetype at once: it
# introduces them one at a time so each new threat reads, then punctuates with scripted elites
# and bosses. Timeline we replicate ('unlock' = when the kind may spawn at all, in seconds):
#   0:00 melee swarm only      1:00 ranged units join      1:30 a 2nd melee type
#   3:00 intermediates + ELITE event      5:00 boss      12:00 ELITE event      15:00 final boss
# 30/09 : roster entier retire a la demande du patron (47 entrees). Vide deliberement, pas un
# oubli — toutes les fonctions de spawn plus bas sont gardees contre un DEFS/BIOME_POOL vide
# (kind absent -> no-op silencieux, jamais un crash). L'art (assets/enemies/) et le dispatch de
# comportement generique (Enemy.gd) restent en place, prets si des ennemis reviennent un jour.
const DEFS: Dictionary = {
	# 04/10, DESACTIVES pour la publication itch (demande explicite du patron : "sans ennemis,
	# juste decors/maps"). Code/tests/phases intacts, prets a etre reactives (decommenter les 4
	# lignes) des que le vrai art Meshy de ces 4 boss sera pret - voir _test_boss_chapitres.gd,
	# toujours vert, qui construit ces Enemy directement sans passer par DEFS.
	# 17/10 (patron : « integre les ennemis de base pour tester ») : les 3 ennemis UNIVERSELS reviennent (Rodeur, Guepe, Belier), copies telles
	# quelles de EnemySpawner.gd.fullroster. Les specialistes par biome et les boss restent desactives.
	"brute":     {"name": "Rodeur", "chassis": "u_rodeur", "proc": true, "hp": 14.0, "speed": 185.0, "dmg": 6.0, "radius": 30.0, "size": 124.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "unlock": 0.0},
	"drone":     {"name": "Guepe", "chassis": "u_guepe", "proc": true, "hp": 10.0, "speed": 235.0, "dmg": 3.0, "radius": 18.0, "size": 78.0, "motion": "hover", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 4.0, "attack_cd": 1.9, "prefer_dist": 280.0, "unlock": 40.0},
	"quadshell": {"name": "Belier", "chassis": "u_belier", "proc": true, "hp": 18.0, "speed": 178.0, "dmg": 9.0, "radius": 26.0, "size": 122.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "dasher", "unlock": 55.0},
	# 19/10 : ENNEMIS DE BASE DE CHAQUE NIVEAU (mecha des 18 chapitres, Meshy -> 8 directions). Un par chapitre, ajoutes un a un.
	"mech10": {"name": "Nautilus", "chassis": "en10_abyss", "hp": 51.0, "speed": 176.0, "dmg": 11.0, "radius": 40.0, "size": 158.9, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 7.5, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech11": {"name": "Marcheur de spores", "chassis": "en11_ether", "hp": 53.5, "speed": 180.0, "dmg": 11.4, "radius": 40.0, "size": 156.5, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 7.8, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech12": {"name": "Relique titan", "chassis": "en12_titans", "hp": 56.0, "speed": 168.0, "dmg": 11.8, "radius": 40.0, "size": 171.0, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 8.2, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech13": {"name": "Astro-vecteur", "chassis": "en13_orbit", "hp": 58.5, "speed": 172.0, "dmg": 12.2, "radius": 40.0, "size": 154.1, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 8.6, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech14": {"name": "Cipher-byte", "chassis": "en14_quantum", "hp": 61.0, "speed": 176.0, "dmg": 12.6, "radius": 40.0, "size": 151.7, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 8.9, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech15": {"name": "Sauteur de foudre", "chassis": "en15_ozone", "hp": 63.5, "speed": 180.0, "dmg": 13.0, "radius": 40.0, "size": 154.1, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 9.2, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech16": {"name": "Spectra-mecha", "chassis": "en16_prism", "hp": 66.0, "speed": 168.0, "dmg": 13.4, "radius": 40.0, "size": 156.5, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 9.6, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech17": {"name": "Terreur a vapeur", "chassis": "en17_steampunk", "hp": 68.5, "speed": 172.0, "dmg": 13.8, "radius": 40.0, "size": 158.9, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 9.9, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech18": {"name": "Gladiateur", "chassis": "en18_colosseum", "hp": 71.0, "speed": 176.0, "dmg": 14.2, "radius": 40.0, "size": 161.3, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 10.3, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	# "cryoboss":      {"name": "Le Cryarque",   "chassis": "cryoboss",      "hp": 2800.0, "speed": 236.0, "dmg": 30.0, "radius": 78.0, "size": 360.0, "rank": 4, "w": 0, "final": true, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 26.0, "attack_cd": 2.2, "prefer_dist": 360.0, "shield": 380.0},
	# "reacteurboss":  {"name": "Le Fulgurant",  "chassis": "reacteurboss",  "hp": 2940.0, "speed": 240.0, "dmg": 31.0, "radius": 78.0, "size": 370.0, "rank": 4, "w": 0, "final": true, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 27.0, "attack_cd": 2.2, "prefer_dist": 360.0, "shield": 400.0},
	# "rucheboss":     {"name": "La Matriarche", "chassis": "rucheboss",     "hp": 3080.0, "speed": 244.0, "dmg": 32.0, "radius": 80.0, "size": 385.0, "rank": 4, "w": 0, "final": true, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 28.0, "attack_cd": 2.2, "prefer_dist": 360.0, "shield": 420.0},
	# "citadelleboss": {"name": "L'Arcange",     "chassis": "citadelleboss", "hp": 3220.0, "speed": 248.0, "dmg": 34.0, "radius": 82.0, "size": 400.0, "rank": 4, "w": 0, "final": true, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 30.0, "attack_cd": 2.2, "prefer_dist": 360.0, "shield": 440.0},
}

const BOSS_PHASE_THRESHOLDS: Dictionary = {
	# 2 seuils -> la phase 3 (idx==2) est atteignable ; le defaut [0.5] (un seul seuil) ne
	# l'atteindrait jamais, cf. _check_boss_phase() dans Enemy.gd.
	"cryoboss": [0.5, 0.2],
	"reacteurboss": [0.5, 0.2],
	"rucheboss": [0.5, 0.2],
	"citadelleboss": [0.5, 0.2],
}

# 19/10 (patron : « supprime les ennemis de la demo ») : plus de Rodeur/Guepe/Belier dans les pools. Chaque niveau 10-18 n'a QUE son ennemi de base,
# des le debut (unlock 0). Niveaux 1-9 : aucun ennemi tant que leurs mecha ne sont pas modelises (les DEFS brute/drone/quadshell restent : refs carcasse/balise).
const BIOME_POOL: Dictionary = {
	"tech": [], "earth": [], "spaceship": [],
	"volcanic": [], "desert": [], "ice": [],
	"jungle": [], "swamp": [], "ruines": [],
	"cryo": [], "reacteur": [], "ruche": [],
	"citadelle": [],
	"abyss": ["mech10"],
	"ether": ["mech11"],
	"titans": ["mech12"],
	"orbit": ["mech13"],
	"quantum": ["mech14"],
	"ozone": ["mech15"],
	"prism": ["mech16"],
	"steampunk": ["mech17"],
	"colosseum": ["mech18"],
}

# CORRUPTION visuelle par biome : teinte multiplicative sur CHAQUE ennemi (self_modulate). Subtile.
const BIOME_TINT: Dictionary = {
	"tech":      Color(0.82, 0.92, 1.10),
	"earth":     Color(1.10, 0.92, 0.70),
	"spaceship": Color(0.90, 0.88, 1.14),
	"volcanic":  Color(1.30, 0.72, 0.54),
	"desert":    Color(1.16, 1.00, 0.68),
	"ice":       Color(0.74, 0.94, 1.18),
	"jungle":    Color(0.76, 1.14, 0.74),
	"swamp":     Color(0.86, 1.04, 0.68),
	"ruines":    Color(1.08, 0.90, 0.78),
	"cryo":      Color(0.80, 0.94, 1.15),
	"reacteur":  Color(0.80, 1.10, 0.75),
	"ruche":     Color(1.05, 0.80, 1.10),
	"citadelle": Color(1.15, 1.05, 0.75),
	"abyss":     Color(0.65, 0.95, 1.20),
	"ether":     Color(0.85, 0.65, 1.15),
	"titans":    Color(1.15, 0.85, 0.65),
	"orbit":     Color(0.80, 0.95, 1.15),
	"quantum":   Color(1.10, 1.05, 0.70),
	"ozone":     Color(1.10, 0.70, 1.15),
	"prism":     Color(0.95, 1.10, 1.15),
	"steampunk": Color(1.15, 0.90, 0.70),
	"colosseum": Color(0.90, 1.05, 1.10),
}

# Timed run structure: bosses at 5 min (build filter), 10 min, 15 min (final -> victory).
# Matches Survivor.io's chapter 1 beats exactly (boss 5:00, boss ~10:00, final boss 15:00).
# 🚨 Plan direction artistique (26/09) : "chaque environnement devrait avoir un boss qui
# reutilise ses materiaux et ses mecaniques" — jusqu'ici les 5min/10min etaient FIXES
# (midboss/crusherboss) quel que soit le biome. Les slots 0/1 sont maintenant resolus par
# _mid_boss_for() ci-dessous, qui fait tourner 4 chassis mi-boss existants (dont midboss_a/
# midboss_b, "Le Bombardier"/"Le Devastateur" — voir le commentaire au-dessus des DEFS : ils
# n'etaient cables NULLE PART, "pas un bug, un choix produit non tranche" ; le choix est fait).
# endboss (Souverain) reste universel a 15 min : boss FINAL de victoire, deja lie au chapitre 5
# "La Cite Dechue" par son propre nom — pas un boss de zone comme les deux autres.
const BOSS_SCHEDULE: Array = [
	{"t": 300.0, "slot": 0},           # 5 min : mi-boss n°1, depend du biome
	{"t": 600.0, "slot": 1},           # 10 min : mi-boss n°2, depend du biome (toujours != n°1)
	{"t": 900.0, "kind": "endboss"},   # 15 min : SOUVERAIN (boss final = victoire, obsidienne)
]
var _bosses_fired: int = 0
const BIOME_ORDER: Array = ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "cryo", "reacteur", "ruche", "citadelle", "abyss", "ether", "titans", "orbit", "quantum", "ozone", "prism", "steampunk", "colosseum"]
const MID_BOSSES: Array = ["midboss", "midboss_a", "crusherboss", "midboss_b"]
func _mid_boss_for(offset: int) -> String:
	var bi: int = maxi(0, BIOME_ORDER.find(current_biome))
	return String(MID_BOSSES[(bi + offset) % MID_BOSSES.size()])

# 03/10, "5 arenes de boss" (plan "15 maps") : certains chapitres remplacent le Souverain
# universel par LEUR propre cloture a 15 min. Chapitre 1 = BELIER-01 (27/09, deja en prod) ;
# chapitres 6-9 = les 4 nouveaux boss de biome. Dict + fonction pure plutot qu'un "if" par
# chapitre : testable directement, sans faire tourner 900s d'horloge de run.
const CHAPTER_FINAL_BOSS: Dictionary = {
	1: "belier01", 6: "cryoboss", 7: "reacteurboss", 8: "rucheboss", 9: "citadelleboss",
}
## Quel "kind" remplace "endboss" pour ce chapitre (ou "endboss" lui-meme si ce chapitre n'a pas
## de cloture dediee, ou si SANS FIN est actif - meme garde qu'avant, jamais de boss de campagne
## en SANS FIN).
func _final_boss_for(chapter_n: int, endless: bool) -> String:
	if endless or not CHAPTER_FINAL_BOSS.has(chapter_n):
		return "endboss"
	return String(CHAPTER_FINAL_BOSS[chapter_n])
# SANS FIN: once the scheduled bosses are spent, endbosses keep coming on this cadence forever.
const ENDLESS_BOSS_INTERVAL: float = 210.0
var _endless_next_boss: float = 0.0
## Regression-test only (`-- --fast-bosses`): compresses the boss clock so an automated run can
## actually reach the endboss and the SANS FIN waves after it, instead of needing 15 real minutes.
@onready var _boss_scale: float = 0.02 if OS.get_cmdline_user_args().has("--fast-bosses") else 1.0

# Scripted ELITE events: a single tanky foe announced as an event, between the bosses — the
# "an elite monster will come, stronger than normal units, takes longer to kill" beat at 3:00
# and 12:00. Distinct from the rare intermediates that trickle out of the random pool.
const ELITE_SCHEDULE: Array = [
	{"t": 180.0, "kind": "crusher"},
	{"t": 720.0, "kind": "warden"},
]
var _elites_fired: int = 0

func _process(delta: float) -> void:
	if not GameState.alive:
		return
	_drain_wave()   # spread a queued horde over frames (no spawn hitch)
	_t += delta
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		# swarm cadence: already dense at the start, ramps to a heavy horde (weak foes -> OK)
		var rate: float = clampf(0.82 - _t * 0.0016, 0.15, 0.82)
		# --- PRESSION DE FOND ----------------------------------------------------------
		# 🚨 MESURE DU TESTEUR SENSATIONS : sur 125 captures d'une partie de 3:11, « 65 % des
		# images sont quasi vides et 4 % montrent un mur de 55 ennemis ». Ecran totalement
		# vide a 00:16, a 00:25 et encore a 03:06 — puis 55 ennemis 5 secondes plus tard.
		# On passe du desert au mur sans plateau. Cause : la cadence de fond est FIXE, donc
		# des que le joueur tue plus vite qu'elle ne produit, l'ecran se vide et plus rien
		# ne le remplit avant la vague suivante (50 s d'intervalle).
		# Correctif : un PLANCHER de population vivante qui monte avec le temps. Tant qu'on
		# est sous ce plancher, la cadence s'accelere (jusqu'a x4) ; des qu'il est atteint,
		# on retombe exactement sur l'ancien comportement. Les pics de vague sont conserves.
		var live: int = get_tree().get_nodes_in_group("enemies").size()
		var floor_pop: int = clampi(5 + int(_t / 22.0), 5, 24)
		# 🚨 Rapport de test Manus (26/09, P0) : « mort possible en 20-30s des la difficulte
		# Facile » — le plancher etait deja a 5 des t=0, et le rattrapage pouvait multiplier la
		# cadence par x4 ; un joueur qui n'a pas encore appris le deplacement encaisse la pleine
		# pression avant d'avoir compris les controles. GRACE adoucit plancher ET rattrapage
		# pendant les 18 premieres secondes de CHAQUE partie, puis s'efface completement —
		# aucun effet passe ce cap, ni sur la vague scriptee (38s), ni sur le sans-fin.
		var grace: float = clampf(_t / 18.0, 0.0, 1.0)
		floor_pop = clampi(mini(floor_pop, 2 + int(3.0 * grace)), 2, 24)
		if live < floor_pop:
			var deficit: float = float(floor_pop - live) / float(floor_pop)
			rate /= (1.0 + 3.0 * deficit * lerpf(0.4, 1.0, grace))
		# 🚨 Rapport Manus (26/09, session suivante) : mort a 12-23s CONFIRMEE, MALGRE le
		# correctif ci-dessus — celui-ci n'adoucissait que le rattrapage de population, pas le
		# reste du calcul. Or un biome (Jungle "nuees denses" = spawn_mult 1.35) ou une
		# combinaison de Protocoles (jusqu'a spawn_rate 2.4, cf. Protocols.gd) multiplient CE
		# diviseur directement, des t=0, sans jamais passer par le rattrapage — pour un nouveau
		# joueur qui tombe sur cette combinaison au tout premier essai, la grace precedente
		# n'avait donc pratiquement aucun effet. Meme fenetre de 18s, mais elle plafonne
		# maintenant le produit ENTIER (biome x difficulte x protocoles) a 1.0 au depart (jamais
		# pire qu'un rythme normal), puis le laisse remonter jusqu'a sa vraie valeur.
		var full_mult: float = spawn_mult * float(GameState.diff().get("spawn", 1.0)) * Protocols.spawn_rate
		var eff_mult: float = lerpf(minf(1.0, full_mult), full_mult, grace)
		_spawn_t = rate / maxf(0.2, eff_mult)
		_spawn()
	if _bosses_fired < BOSS_SCHEDULE.size() and GameState.run_time >= float(BOSS_SCHEDULE[_bosses_fired]["t"]) * _boss_scale:
		if not _boss_alive():   # never let two bosses coexist -> avoids double next_map in one frame
			var sched: Dictionary = BOSS_SCHEDULE[_bosses_fired]
			var kind: String = String(sched["kind"]) if sched.has("kind") else _mid_boss_for(int(sched["slot"]) * 2)
			# BELIER-01/boss de biome (03/10, generalise depuis le seul "chapitre 1 -> belier01"
			# du 27/09) : certains chapitres recoivent LEUR propre cloture a 15 min au lieu du
			# Souverain universel. Garde SANS FIN indispensable : ce mode ne fixe jamais `chapter`
			# (reste a 1 par defaut) -> sans elle, une run SANS FIN spawnerait un boss de campagne
			# comme-final ici au lieu de l'endboss RECURRENT attendu plus bas.
			if kind == "endboss":
				kind = _final_boss_for(chapter, GameState.endless)
			_spawn_boss(kind)
			_bosses_fired += 1
	elif GameState.endless and _bosses_fired >= BOSS_SCHEDULE.size():
		# schedule the first endless boss relative to when the scripted run ran out, not to t=0
		if _endless_next_boss <= 0.0:
			_endless_next_boss = GameState.run_time + ENDLESS_BOSS_INTERVAL * _boss_scale
		elif GameState.run_time >= _endless_next_boss and not _boss_alive():
			_spawn_boss("endboss")
			_endless_next_boss = GameState.run_time + ENDLESS_BOSS_INTERVAL * _boss_scale
	if _elites_fired < ELITE_SCHEDULE.size() and GameState.run_time >= float(ELITE_SCHEDULE[_elites_fired]["t"]):
		_spawn_elite(String(ELITE_SCHEDULE[_elites_fired]["kind"]))
		_elites_fired += 1
	_wave_t -= delta
	if _wave_t <= 0.0:
		_wave_t = WAVE_INTERVAL
		_spawn_wave()

## Hold off spawning for `s` seconds (used by the run-start teleport intro).
func delay_spawns(s: float) -> void:
	_spawn_t = maxf(_spawn_t, s)

# Pending wave members, drained a few per frame by _drain_wave() so a 50-strong horde never
# builds in a single frame. Cleared implicitly as it drains.
var _wave_queue: Array = []
const WAVE_PER_FRAME: int = 4      # ~50 foes spread over ~12 frames (0.2s) instead of 1

func _drain_wave() -> void:
	if _wave_queue.is_empty() or player == null or not is_instance_valid(player):
		return
	var budget: int = WAVE_PER_FRAME
	while budget > 0 and not _wave_queue.is_empty():
		if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
			_wave_queue.clear()   # cap reached mid-drain: drop the rest, don't queue forever
			return
		budget -= 1
		var w: Dictionary = _wave_queue.pop_front()
		var kind: String = String(w["kind"])
		if not DEFS.has(kind):
			continue
		var e: Enemy = Enemy.new()
		e.global_position = player.global_position + Vector2(cos(w["ang"]), sin(w["ang"])) * float(w["dist"])
		game.enemy_layer.add_child(e)
		e.setup(kind, DEFS[kind], player, game)
		_scale_enemy(e)

## Spawn one specific enemy at an exact spot (used by the robot carcass awakening).
## Scaled like any other foe so a late-run carcass stays a real threat.
func spawn_kind_at(kind: String, pos: Vector2) -> Enemy:
	if not DEFS.has(kind) or player == null or not is_instance_valid(player):
		return null
	var e: Enemy = Enemy.new()
	e.global_position = pos
	game.enemy_layer.add_child(e)
	e.setup(kind, DEFS[kind], player, game)
	_scale_enemy(e)
	return e

## Scripted elite event (Survivor.io beat at 3:00 / 12:00): ONE tanky foe, announced, beefed up
## over its pool version so it reads as a named threat rather than another intermediate.
func _spawn_elite(kind: String) -> void:
	# Biome-aware: pick a rank>=1 specialist from THIS biome's pool (the schedule's old hard-coded
	# names are gone). Falls back to the passed kind if the pool has no elite.
	var pool: Array = BIOME_POOL.get(current_biome, [])
	var elites: Array = []
	for k in pool:
		if DEFS.has(k) and int(DEFS[k].get("rank", 0)) >= 1 and int(DEFS[k].get("w", 0)) > 0:
			elites.append(k)
	if not elites.is_empty():
		kind = String(elites[randi() % elites.size()])
	var e: Enemy = spawn_kind_at(kind, Vector2.ZERO)
	if e == null:
		return
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 680.0
	e.hp_max *= 2.4          # "takes longer to kill" — a real speed bump between bosses
	e.hp = e.hp_max
	e.contact_dmg *= 1.2
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("shockwave", e.global_position, 0.0, 2.2, Color(1.0, 0.7, 0.3))
	if game != null and game.has_method("show_banner"):
		game.show_banner("!  ELITE  !", Color(1.0, 0.75, 0.35))
	Audio.sfx("boss", 0.1)

func _spawn_boss(kind: String) -> void:
	if not DEFS.has(kind):
		return
	if player == null or not is_instance_valid(player):
		return
	print("[game] BOSS kind=%s chapter=%d endless=%s final=%s t=%.1f" % [
		kind, chapter, str(GameState.endless), str(bool(DEFS[kind].get("final", false))), GameState.run_time])
	var e: Enemy = Enemy.new()
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 760.0
	game.enemy_layer.add_child(e)
	e.setup(kind, DEFS[kind], player, game)
	_scale_enemy(e)   # bosses scale with run time + cleared-zone bonus + difficulty, like the trash
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("shockwave", e.global_position, 0.0, 3.0, Color(1.0, 0.5, 0.4))   # menacing arrival ring
	if game != null and game.has_method("show_banner"):
		game.show_banner("!  MENACE MAJEURE  !", Color(1.0, 0.4, 0.3))
	Audio.sfx("boss")
	Audio.music("boss")

func _boss_alive() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).alive and int((e as Enemy).rank) >= 3:
			return true
	return false

func _kind_unlocked(k: String, t: float) -> bool:
	# Survivor.io-style STAGED introduction: each archetype has its own entry time (see DEFS),
	# so the player meets one new threat at a time instead of all of them at 0:00.
	return t >= float(DEFS[k].get("unlock", 0.0))

func _weighted_pick(fodder_only: bool = false) -> String:
	var t: float = GameState.run_time
	var picks: Array = []
	var total: int = 0
	var pool: Array = BIOME_POOL.get(current_biome, [])   # filtre PAR BIOME
	for k in pool:
		if not DEFS.has(k):
			continue
		var w: int = int(DEFS[k]["w"])
		if w <= 0:
			continue                       # bosses (spawned on schedule, not here)
		if fodder_only and int(DEFS[k]["rank"]) > 0:
			continue                       # massive waves = the weak swarm only (no tanky intermediates)
		if not _kind_unlocked(k, t):
			continue
		picks.append([k, w]); total += w
	if picks.is_empty():
		return ""                          # aucun ennemi defini/debloque -> rien a piocher
	var r: int = randi() % maxi(1, total)
	for pw in picks:
		r -= int(pw[1])
		if r < 0:
			return String(pw[0])
	return String(picks[0][0])

## Where a fresh enemy appears, relative to the player.
##
## THE POINT: spawning on a uniform ring meant a straight-line retreat was free forever — you
## simply outran the ring and everything trailed behind you in a queue. Now, while the player is
## actually fleeing, most spawns land in an arc AHEAD of their movement, so retreating walks you
## INTO the new wave. Standing and fighting keeps the old even ring.
## Reversing direction is still an out, which is exactly the decision we want to force.
const SPAWN_R: float = 640.0
const FLEE_SPEED: float = 240.0     # above this the player is running, not repositioning
const AHEAD_SHARE: float = 0.62     # share of spawns placed in the flight arc
const AHEAD_ARC: float = 1.15       # half-width of that arc (rad) — a wall, not a single point
func _spawn_offset() -> Vector2:
	var v: Vector2 = Vector2.ZERO
	if "velocity" in player:
		v = player.velocity
	if v.length() > FLEE_SPEED and randf() < AHEAD_SHARE:
		var a: float = v.angle() + randf_range(-AHEAD_ARC, AHEAD_ARC)
		return Vector2(cos(a), sin(a)) * SPAWN_R
	var ang: float = randf() * TAU
	return Vector2(cos(ang), sin(ang)) * SPAWN_R

func _spawn() -> void:
	if player == null or not is_instance_valid(player):
		return
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return
	var kind: String = _weighted_pick()
	if not DEFS.has(kind):
		return
	var e: Enemy = Enemy.new()
	var spos: Vector2 = player.global_position + _spawn_offset()
	if arena_half > 0.0:
		# Keep spawns inside the walls. Fleeing toward a wall means the ahead-spawns land ON the
		# wall in front of you -> you get pinned, which is the whole point of the bounded arena.
		spos.x = clampf(spos.x, arena.position.x, arena.end.x)
		spos.y = clampf(spos.y, arena.position.y, arena.end.y)
	e.global_position = spos
	game.enemy_layer.add_child(e)
	e.setup(kind, DEFS[kind], player, game)
	_scale_enemy(e)

## Spawn one enemy at a fixed world point (beacon structures use this). Respects the enemy cap and
## the arena bounds, and scales the enemy like any normal spawn.
func spawn_at(pos: Vector2, kind: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not DEFS.has(kind):
		return
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return
	var e: Enemy = Enemy.new()
	var p: Vector2 = pos
	if arena_half > 0.0:
		p.x = clampf(p.x, arena.position.x, arena.end.x)
		p.y = clampf(p.y, arena.position.y, arena.end.y)
	e.global_position = p
	game.enemy_layer.add_child(e)
	e.setup(kind, DEFS[kind], player, game)
	_scale_enemy(e)

# Scale a fresh enemy, per stat (not uniformly):
#   HP     = run-time crescendo + per-zone bonus + difficulty (full stack)
#   damage = per-zone bonus + difficulty (contact AND ranged bolts)
#   speed  = biome modifier + difficulty only (intentionally NOT time/zone — enemy speed must
#            not creep upward over a run; cf. Game.next_map where difficulty_bonus feeds HP/dmg)
func _scale_enemy(e: Enemy) -> void:
	var d: Dictionary = GameState.diff()
	# Speed DOES scale now, capped at +40%. It used to be flat forever, which meant a player at
	# 512 px/s (agility + speed picks) simply outran every non-boss foe at 224 px/s for the whole
	# run — kiting was free and permanent, and ENEMY_CAP forbids raising pressure by numbers.
	# The cap keeps them beatable: even maxed they stay slower than an upgraded player.
	var spd_scale: float = minf(1.0 + difficulty_bonus * 0.10 + GameState.run_time * 0.00018, 1.25)   # 17/10 : plafond 1,40 -> 1,25
	e.speed *= speed_mult * float(d.get("speed", 1.0)) * spd_scale * clampf(Protocols.enemy_speed, 0.8, 1.2)
	# 17/10 (patron : « les ennemis sont trop rapides ») : un ennemi ne rattrape plus un mecha qui FUIT. Plafond = 80 % de la vitesse du
	# joueur : la poursuite reste menacante (on ne peut pas s'arreter), mais on peut toujours repositionner en courant. Les ruees
	# (dasher) et le coefficient individuel (+/-15 %) s'ajoutent par-dessus : brefs, pas permanents.
	if player != null and "base_speed" in player:
		e.speed = minf(e.speed, float(player.base_speed) * 0.80)
	var hp_scale: float = (1.0 + GameState.run_time * 0.0011) * (1.0 + difficulty_bonus) * float(d.get("hp", 1.0)) * Protocols.enemy_hp
	e.hp *= hp_scale
	e.hp_max = e.hp
	if e.shield_max > 0.0:               # shields scale with HP too, else late-game shields are trivial
		e.shield_max *= hp_scale
		e.shield = e.shield_max
	var dmg_scale: float = (1.0 + difficulty_bonus * 0.5) * float(d.get("dmg", 1.0)) * Protocols.enemy_dmg
	e.contact_dmg *= dmg_scale
	e.attack_dmg *= dmg_scale             # ranged bolts scale too (else late-game shooters are harmless)

# Scripted horde: a big ring of foes crashes in at once. Leans on one archetype for a
# coherent "swarm" read, mixes in a few others, and stays under the enemy cap for mobile.
func _spawn_wave() -> void:
	if player == null or not is_instance_valid(player):
		return
	var existing: int = get_tree().get_nodes_in_group("enemies").size()
	var want: int = 24 + int(GameState.run_time / 40.0) * 6 + int(difficulty_bonus * 24.0)
	var count: int = clampi(want, 0, maxi(0, ENEMY_CAP - existing))
	if count <= 0:
		return
	var lead: String = _weighted_pick(true)   # waves are pure weak swarm (fodder only)
	if lead == "":
		return   # aucun ennemi defini -> pas de vague (evite une banniere "VAGUE MASSIVE" pour rien)
	var base_ang: float = randf() * TAU
	# STAGGERED: building ~50 enemies (sprite + shadow + collider + shader material each) in ONE
	# frame was a ~200-node spike -> a visible hitch every wave, on any hardware. Queue them and
	# drain a few per frame instead: same ring, same instant, no freeze.
	# 🚨 « les ennemis arrivent en colonnes trop regulieres — des rangees presque parfaitement
	# alignees, des arcs de cercle nets. Ca se lit comme du spawn en ligne, pas comme une horde. »
	# En cause : un angle strictement regulier (i/count * TAU, +/- 0,06 rad) et une distance
	# quasi constante. On repartit maintenant la vague en 3 a 5 PAQUETS places au hasard sur le
	# tour, chacun avec sa propre dispersion angulaire et sa profondeur : on lit une meute.
	var packs: int = clampi(3 + randi() % 3, 3, 5)
	var pack_ang: Array = []
	for pi in packs:
		pack_ang.append(base_ang + float(pi) / float(packs) * TAU + randf_range(-0.45, 0.45))
	for i in count:
		var pk: int = i % packs
		_wave_queue.append({
			"ang": float(pack_ang[pk]) + randf_range(-0.42, 0.42),
			"dist": 700.0 + randf_range(-90.0, 260.0),
			"kind": lead if randf() < 0.82 else _weighted_pick(true),
		})
	if game != null and game.has_method("show_banner"):
		game.show_banner(">>>  VAGUE MASSIVE  <<<", Color(1.0, 0.55, 0.3))
	Audio.sfx("boss", 0.1)
