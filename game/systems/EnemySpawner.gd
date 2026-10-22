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
	"mech01": {"name": "Walker d'assemblage", "chassis": "en01_tech", "hp": 28.5, "speed": 172.0, "dmg": 7.4, "radius": 40.0, "size": 148.8, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 4.3, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech02": {"name": "Rodeur des dunes", "chassis": "en02_desert", "hp": 31.0, "speed": 176.0, "dmg": 7.8, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 4.7, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech03": {"name": "Broyeur forestier", "chassis": "en03_jungle", "hp": 33.5, "speed": 180.0, "dmg": 8.2, "radius": 40.0, "size": 158.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 5.0, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech04": {"name": "Fondeur de magma", "chassis": "en04_volcanic", "hp": 36.0, "speed": 168.0, "dmg": 8.6, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 5.4, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech05": {"name": "Excavateur de vase", "chassis": "en05_swamp", "hp": 38.5, "speed": 172.0, "dmg": 9.0, "radius": 40.0, "size": 151.2, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 5.8, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech06": {"name": "Foreur glaciaire", "chassis": "en06_cryo", "hp": 41.0, "speed": 176.0, "dmg": 9.4, "radius": 40.0, "size": 156.0, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 6.1, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech07": {"name": "Noyau irradie", "chassis": "en07_reacteur", "hp": 43.5, "speed": 180.0, "dmg": 9.8, "radius": 40.0, "size": 146.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 6.4, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech08": {"name": "Brise-ruche", "chassis": "en08_ruche", "hp": 46.0, "speed": 168.0, "dmg": 10.2, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 6.8, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech09": {"name": "Bastion orbital", "chassis": "en09_citadelle", "hp": 48.5, "speed": 172.0, "dmg": 10.6, "radius": 40.0, "size": 160.8, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 7.2, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech10": {"name": "Nautilus", "chassis": "en10_abyss", "hp": 51.0, "speed": 176.0, "dmg": 11.0, "radius": 40.0, "size": 158.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 7.5, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech11": {"name": "Marcheur de spores", "chassis": "en11_ether", "hp": 53.5, "speed": 180.0, "dmg": 11.4, "radius": 40.0, "size": 156.0, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 7.8, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech12": {"name": "Relique titan", "chassis": "en12_titans", "hp": 56.0, "speed": 168.0, "dmg": 11.8, "radius": 40.0, "size": 170.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 8.2, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech13": {"name": "Astro-vecteur", "chassis": "en13_orbit", "hp": 58.5, "speed": 172.0, "dmg": 12.2, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 8.6, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech14": {"name": "Cipher-byte", "chassis": "en14_quantum", "hp": 61.0, "speed": 176.0, "dmg": 12.6, "radius": 40.0, "size": 151.2, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 8.9, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech15": {"name": "Sauteur de foudre", "chassis": "en15_ozone", "hp": 63.5, "speed": 180.0, "dmg": 13.0, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 9.2, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech16": {"name": "Spectra-mecha", "chassis": "en16_prism", "hp": 66.0, "speed": 168.0, "dmg": 13.4, "radius": 40.0, "size": 156.0, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 9.6, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech17": {"name": "Terreur a vapeur", "chassis": "en17_steampunk", "hp": 68.5, "speed": 172.0, "dmg": 13.8, "radius": 40.0, "size": 158.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 9.9, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech18": {"name": "Gladiateur", "chassis": "en18_colosseum", "hp": 71.0, "speed": 176.0, "dmg": 14.2, "radius": 40.0, "size": 160.8, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 10.3, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
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
	"earth": [], "spaceship": [], "ice": [], "ruines": [],
	"tech": ["mech01"],
	"desert": ["mech02"],
	"jungle": ["mech03"],
	"volcanic": ["mech04"],
	"swamp": ["mech05"],
	"cryo": ["mech06"],
	"reacteur": ["mech07"],
	"ruche": ["mech08"],
	"citadelle": ["mech09"],
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
	_squad_tick(delta)
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
		_spawn_t = rate / maxf(0.2, eff_mult * (1.25 + 0.025 * float(int((PROFILES.get(current_biome, {}) as Dictionary).get("tier", 1)) - 1)) * _phase_rate())
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
		e.setup(kind, _def_for(kind), player, game)
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

## >>> PROFILS DE NIVEAU (21/10, patron : « une strategie d'apparition ET de combat par ennemi de base, plus dure a chaque niveau, mais pas impossible »)
## Chaque niveau a : un MOTIF d'apparition (ou/comment ils arrivent), un ROLE principal et un role secondaire (part `share`).
## Le rang `tier` (1..18) durcit : cadence +2 %/niveau, tirs plus rapides, boucliers plus epais, plus de roles speciaux
## simultanes. GARDE-FOUS (jamais impossible) : vitesse <= 80 % du joueur (cf. _scale_enemy), plafond de roles speciaux
## vivants (_special_cap), ENEMY_CAP, et aucun motif ne pose un ennemi a moins de ~420 px du joueur.
##   motifs : ring anneau regulier | ahead mur devant la fuite | pincer deux flancs | ambush grappe d'un cote
##            line rangee tangente | burst petites salves serrees | close anneau serre | encircle 4 points tournants
##            dropin proche mais rare | gates deux portes cardinales | fan trois eventails | sandwich devant/derriere
##   roles  : tir | charge (dasher) | mine (zones au sol) | kamikaze | bull (melee a charge) | blinde (bouclier) | lourd | barrage
const PROFILES: Dictionary = {
	"tech":      {"tier": 1, "forms": ["ligne","colonne"],  "pat": "ring",     "main": ["tir"],              "alt": [],                   "share": 0.0},
	"desert":    {"tier": 2, "forms": ["tenaille","colonne","ligne"],  "pat": "pincer",   "main": ["charge", "esquive"],           "alt": ["tir", "rafale"],              "share": 0.20},
	"jungle":    {"tier": 3, "forms": ["embuscade","tirailleurs"],  "pat": "ambush",   "main": ["eventail"],              "alt": ["bull", "garde"],             "share": 0.25},
	"volcanic":  {"tier": 4, "forms": ["coin","feu_et_mouvement"],  "pat": "ahead",    "main": ["mine", "esquive"],             "alt": ["orbe"],              "share": 0.25},
	"swamp":     {"tier": 5, "forms": ["colonne","fer_a_cheval"],  "pat": "close",    "main": ["bull", "garde"],             "alt": ["mine"],             "share": 0.20},
	"cryo":      {"tier": 6, "forms": ["ligne","vague","tirailleurs"],  "pat": "line",     "main": ["sniper", "blinde", "garde"], "alt": ["charge"],       "share": 0.25},
	"reacteur":  {"tier": 7, "forms": ["coin","vague","embuscade"],  "pat": "burst",    "main": ["kamikaze", "esquive"],         "alt": ["anneau"],              "share": 0.30},
	"ruche":     {"tier": 8, "forms": ["encerclement","vague"],  "pat": "burst",    "main": ["bull", "esquive"],             "alt": ["rafale", "garde"],              "share": 0.30},
	"citadelle": {"tier": 9, "forms": ["vague","echelon","feu_et_mouvement"],  "pat": "pincer",   "main": ["tir", "blinde", "lourd", "garde"], "alt": ["tir", "protecteur"], "share": 0.25},
	"abyss":     {"tier": 10, "forms": ["encerclement","spirale","fer_a_cheval"], "pat": "encircle", "main": ["guide", "garde"],     "alt": ["charge", "esquive"],           "share": 0.25},
	"ether":     {"tier": 11, "forms": ["leurre","embuscade","tenaille"], "pat": "dropin",   "main": ["charge", "esquive"],           "alt": ["kamikaze"],         "share": 0.20},
	"titans":    {"tier": 12, "forms": ["coin","echelon","ligne"], "pat": "ahead",    "main": ["mine", "blinde", "garde"], "alt": ["orbe", "protecteur"],       "share": 0.25},
	"orbit":     {"tier": 13, "forms": ["spirale","feu_et_mouvement","encerclement"], "pat": "fan",      "main": ["tir", "barrage", "esquive"],   "alt": ["charge"],           "share": 0.30},
	"quantum":   {"tier": 14, "forms": ["tenaille","leurre","encerclement"], "pat": "sandwich", "main": ["kamikaze", "esquive"],         "alt": ["sniper", "blinde", "garde"], "share": 0.35},
	"ozone":     {"tier": 15, "forms": ["echelon","tenaille","tirailleurs"], "pat": "line",     "main": ["charge", "esquive"],           "alt": ["rafale", "garde"],   "share": 0.30},
	"prism":     {"tier": 16, "forms": ["fer_a_cheval","feu_et_mouvement","spirale"], "pat": "fan",      "main": ["eventail", "blinde", "garde"], "alt": ["tir", "protecteur"],   "share": 0.30},
	"steampunk": {"tier": 17, "forms": ["vague","tenaille","echelon","fer_a_cheval"], "pat": "sandwich", "main": ["mine", "blinde", "garde"], "alt": ["tir", "protecteur"],     "share": 0.35},
	"colosseum": {"tier": 18, "forms": ["encerclement","tenaille","leurre","vague","feu_et_mouvement","spirale"], "pat": "gates",    "main": ["anneau", "blinde", "garde"], "alt": ["charge", "kamikaze", "rafale"], "share": 0.40},
}
## PHASES DE NIVEAU (lecons opensurvivor « wave_profiles » + survivor-td « enemyPool par minute ») : 4 phases annoncees par un
## bandeau, qui ajustent la part du role secondaire, la cadence d'apparition et la chance d'elite. Debut a 60 % de la part
## nominale (avant : constante), fin a 150 % : un niveau monte en pression au lieu de rester plat.
const PHASES: Array = [
	{"t": 0.0,   "label": "PRISE DE CONTACT",     "share": 0.6, "rate": 1.00, "elite": 1.0},
	{"t": 60.0,  "label": "PRESSION MONTANTE",    "share": 0.9, "rate": 1.05, "elite": 1.2},
	{"t": 180.0, "label": "MENACE D'ELITE",       "share": 1.2, "rate": 1.15, "elite": 1.6},
	{"t": 360.0, "label": "COTE D'ALERTE",        "share": 1.5, "rate": 1.30, "elite": 2.0},
]
var _phase_idx: int = -1
func _phase() -> Dictionary:
	var t: float = GameState.run_time
	var k: int = 0
	for i in PHASES.size():
		if t >= float(PHASES[i]["t"]):
			k = i
	return PHASES[k]
func _phase_rate() -> float:
	return float(_phase()["rate"]) * (0.6 if _boss_up() else 1.0)
var _prof_defs: Dictionary = {}     # cache (biome|tier|alt) -> def fusionne
var _pat_n: int = 0
var _anchor: float = 0.0
var _anchor_t: float = -99.0

## Plafond de roles « speciaux » (charge/kamikaze/mine) vivants en meme temps : 4 au niveau 1 -> 8 au 18.
func _special_cap(tier: int) -> int:
	return 4 + tier / 4

func _is_special(d: Dictionary) -> bool:
	var b: String = String(d.get("behavior", ""))
	return b == "dasher" or b == "kamikaze" or b == "miner"

func _role_def(kind: String, flags: Array, tier: int) -> Dictionary:
	var d: Dictionary = (DEFS[kind] as Dictionary).duplicate()
	var t: float = float(tier)
	# VITESSE (22/10, patron : « la vitesse doit etre recalculee mecha joueur vs ennemi ») : ratio 0,50 au niveau 1 -> 0,53 au niveau 18 (banc : 0,64 = rushes mortels aux niveaux 10-16 en moins de 90 s ; la vitesse est le reglage le plus sensible)
	# du joueur de REFERENCE (336 px/s, ameliorations exclues : elles restent un avantage). Facteurs de role plus bas. _scale_enemy
	# ajoute <= +25 % avec le temps puis plafonne a 80 % de la vitesse reelle du joueur.
	d["speed"] = 336.0 * (0.50 + 0.002 * (t - 1.0))
	d["behavior"] = "ranged"
	d["attack_cd"] = lerpf(2.0, 1.4, (t - 1.0) / 17.0)   # 21/10 : debuts trop faciles -> plus dur des le niveau 1
	d["attack_dmg"] = float(d["attack_dmg"]) * lerpf(1.4, 1.0, clampf((t - 1.0) / 8.0, 0.0, 1.0))
	d["aim_rate"] = lerpf(2.4, 5.5, (t - 1.0) / 17.0)
	d["aim_lead"] = clampf(0.25 + 0.035 * t, 0.25, 0.85)
	d["prefer_dist"] = lerpf(270.0, 215.0, (t - 1.0) / 17.0)
	for f in flags:
		match String(f):
			"charge":
				d["behavior"] = "dasher"
			"mine":
				d["speed"] = float(d["speed"]) * 0.85
				d["behavior"] = "miner"
				d["attack_dmg"] = float(d["attack_dmg"]) * 1.25   # banc : 1,6 tuait le bot en 19 s au niveau 17
			"kamikaze":
				d["behavior"] = "kamikaze"
				d["attack_dmg"] = 8.0 + 0.4 * t
				d["hp"] = float(d["hp"]) * 0.6
			"bull":
				d["behavior"] = "rush"
				d["bull"] = true
				d["zigzag"] = 0.4   # approche en lacets (Runner de survivor-td) : moins previsible qu'une ligne droite
			"rafale", "eventail", "sniper", "guide", "anneau", "orbe":
				d["tir_style"] = String(f)
			"esquive":
				d["esquive"] = true
			"zigzag":
				d["zigzag"] = 0.4
			"protecteur":
				d["protecteur"] = true
				d["tint_proteur"] = true
			"garde":
				d["garde"] = true
				d["garde_cd"] = lerpf(11.0, 6.5, (t - 1.0) / 17.0)
			"blinde":
				d["shield"] = 8.0 + 1.2 * t   # banc 22/10 : 14+2.2t rendait le niveau 9 intuable (77 ennemis vivants a 63 s)
			"lourd":
				d["speed"] = float(d["speed"]) * 0.9
				d["heavy"] = true
				d["attack_cd"] = float(d["attack_cd"]) * 1.25
			"barrage":
				d["barrage"] = true
				d["attack_cd"] = float(d["attack_cd"]) * 1.2
	return d

## Definition a utiliser pour CE spawn : role principal, ou secondaire selon `share`.
func _def_for(kind: String) -> Dictionary:
	var prof: Dictionary = PROFILES.get(current_biome, {})
	if prof.is_empty() or not DEFS.has(kind) or not kind.begins_with("mech"):
		return DEFS[kind] if DEFS.has(kind) else {}
	var tier: int = int(prof["tier"])
	if randf() < _mk2_share():
		var dm: Dictionary = _tier_def("mk2")
		if not dm.is_empty():
			return dm
	var use_alt: bool = not (prof["alt"] as Array).is_empty() and randf() < minf((float(prof["share"]) + 0.004 * float(tier)) * float(_phase()["share"]), 0.65)
	var key: String = "%s|%d|%d" % [current_biome, tier, 1 if use_alt else 0]
	if not _prof_defs.has(key):
		_prof_defs[key] = _role_def(kind, prof["alt"] if use_alt else prof["main"], tier)
	var d: Dictionary = _prof_defs[key]
	# MONTEE EN CHARGE (banc 22/10 : niveaux 6/9/10/12/14/16/18 mortels en 25-70 s, le bot n'avait pas le temps de monter en niveau) :
	# les ajouts de rang (bouclier, garde, PV) arrivent progressivement sur les 2 premieres minutes.
	var t0: float = GameState.run_time
	if t0 < 120.0:
		var ease: float = clampf(t0 / 120.0, 0.25, 1.0)
		d = d.duplicate()
		if t0 < 60.0:
			d.erase("shield")
		elif d.has("shield"):
			d["shield"] = float(d["shield"]) * clampf((t0 - 60.0) / 60.0, 0.25, 1.0)
		if t0 < 60.0:
			d.erase("garde")
		if t0 < 120.0:
			d.erase("protecteur")
		d["hp"] = float(d["hp"]) * lerpf(0.70, 1.0, ease)
	if t0 < 60.0 and _is_special(d):
		d = _role_def(kind, ["tir"], tier)   # banc : pas de charge/kamikaze/mine avant 1:00
	var lf: float = _lead_factor()
	if lf != 1.0 and d.has("aim_lead"):
		d = d.duplicate()
		d["aim_lead"] = clampf(float(d["aim_lead"]) * lf, 0.0, 0.95)
	if _is_special(d):
		var n: int = 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and (e as Enemy).behavior in ["dasher", "kamikaze", "miner"]:
				n += 1
		if n >= mini(_special_cap(tier), 2 + int(t0 / 30.0)):
			return _role_def(kind, ["tir"], tier)   # plafond atteint : tireur banal, jamais un mur de charges
	return d

## Point d'apparition selon le motif du niveau (relatif au joueur).
func _pattern_offset() -> Vector2:
	var prof: Dictionary = PROFILES.get(current_biome, {})
	if prof.is_empty():
		return _spawn_offset()
	_pat_n += 1
	var v: Vector2 = Vector2.ZERO
	if "velocity" in player:
		v = player.velocity
	var face: float = v.angle() if v.length() > 60.0 else _anchor
	var ang: float = 0.0
	var r: float = SPAWN_R
	match String(prof["pat"]):
		"ahead":
			if v.length() > 60.0 and randf() < 0.85:
				ang = face + randf_range(-AHEAD_ARC, AHEAD_ARC)
			else:
				ang = randf() * TAU
		"pincer":
			ang = face + (PI * 0.5 if _pat_n % 2 == 0 else -PI * 0.5) + randf_range(-0.3, 0.3)
		"ambush", "burst":
			var is_ambush: bool = String(prof["pat"]) == "ambush"
			if _t - _anchor_t > (7.0 if is_ambush else 3.5):
				_anchor_t = _t
				_anchor = randf() * TAU
			ang = _anchor + randf_range(-0.42, 0.42) * (1.0 if is_ambush else 0.5)
			r += randf_range(-40.0, 80.0)
		"line":
			if _t - _anchor_t > 9.0:
				_anchor_t = _t
				_anchor = randf() * TAU
			var along: float = float((_pat_n % 7) - 3) * 80.0
			return Vector2(cos(_anchor), sin(_anchor)) * r + Vector2(-sin(_anchor), cos(_anchor)) * along
		"close":
			ang = randf() * TAU
			r = 520.0
		"encircle":
			ang = float(_pat_n % 4) * PI * 0.5 + _t * 0.15 + randf_range(-0.2, 0.2)
			r = 560.0 + randf_range(0.0, 80.0)
		"dropin":
			ang = randf() * TAU
			r = 420.0 + randf_range(0.0, 70.0)
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("shockwave", player.global_position + Vector2(cos(ang), sin(ang)) * r, 0.0, 0.5, Color(0.75, 0.5, 1.0))
		"gates":
			if _t - _anchor_t > 8.0:
				_anchor_t = _t
				_anchor = float(randi() % 4) * PI * 0.5
			ang = _anchor + (PI if _pat_n % 2 == 0 else 0.0) + randf_range(-0.14, 0.14)
		"fan":
			if _t - _anchor_t > 6.0:
				_anchor_t = _t
				_anchor = randf() * TAU
			ang = _anchor + float(_pat_n % 3) * TAU / 3.0 + randf_range(-0.2, 0.2)
		"sandwich":
			ang = face + (0.0 if _pat_n % 2 == 0 else PI) + randf_range(-0.5, 0.5)
		_:
			return _spawn_offset()
	return Vector2(cos(ang), sin(ang)) * r

## ======================= IA SYNTHETIQUE : adaptation au mecha du joueur =======================
## (patron : « une IA synthetique en fonction du mecha du joueur »). Deux sources :
##  - le CHASSIS (statique) : VORTEX perce et aligne -> on evite ligne/colonne (une rangee se fait traverser) et on le
##    prend en flanc ; BLUESTRIKE est un tireur de courte portee -> on le harcele a distance (feu et mouvement,
##    tirailleurs) et on anticipe plus (il bouge beaucoup) ; TITAN est lent et blinde -> on l'enferme (encerclement,
##    spirale, tenaille, embuscade) et on anticipe moins.
##  - le COMPORTEMENT (dynamique, vitesse moyenne lissee sur ~3 s) : un joueur qui court se fait couper la route
##    (tenaille, encerclement, embuscade, fer a cheval) ; un joueur statique se fait user (feu et mouvement, tirailleurs).
var _pspeed: float = 0.0
var _squads: Array = []
var _squad_t: float = 40.0   # premiere escouade a 40 s (banc : escouade + roles speciaux des les premieres secondes = morts precoces)
var _banner_t: Dictionary = {}

func _lead_factor() -> float:
	var fam: String = String(player.chassis_family) if player != null and "chassis_family" in player else ""
	match fam:
		"bluestrike": return 1.15
		"titan": return 0.7
	return 1.0

func _player_style() -> Dictionary:
	var fam: String = String(player.chassis_family) if player != null and "chassis_family" in player else ""
	var prefer: Array = []
	var avoid: Array = []
	match fam:
		"bluestrike":
			prefer = ["feu_et_mouvement", "tirailleurs", "ligne"]
		"titan":
			prefer = ["encerclement", "spirale", "tenaille", "embuscade"]
		"vortex":
			prefer = ["tenaille", "vague", "echelon"]
			avoid = ["ligne", "colonne"]
	var bs: float = float(player.base_speed) if player != null and "base_speed" in player else 300.0
	var ratio: float = _pspeed / maxf(bs, 1.0)
	if ratio > 0.6:
		prefer = prefer + ["tenaille", "encerclement", "embuscade", "fer_a_cheval"]
	elif ratio < 0.2 and _t > 20.0:
		prefer = prefer + ["feu_et_mouvement", "tirailleurs", "vague"]
	return {"prefer": prefer, "avoid": avoid, "ratio": ratio}

func _pick_formation(prof: Dictionary) -> String:
	var forms: Array = prof["forms"]
	var st: Dictionary = _player_style()
	var ok: Array = forms.filter(func(f: String) -> bool: return not (st["avoid"] as Array).has(f))
	if ok.is_empty():
		ok = forms
	var pref: Array = ok.filter(func(f: String) -> bool: return (st["prefer"] as Array).has(f))
	if not pref.is_empty() and randf() < 0.7:
		return String(pref.pick_random())
	return String(ok.pick_random())

func _announce(form: String, text: String, col: Color) -> void:
	if game != null and game.has_method("show_banner") and _t - float(_banner_t.get(text, -99.0)) > 40.0:
		_banner_t[text] = _t
		game.show_banner(text, col)

func _squad_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not PROFILES.has(current_biome):
		return
	if "velocity" in player:
		_pspeed = lerpf(_pspeed, (player.velocity as Vector2).length(), 1.0 - exp(-delta / 3.0))
	var p: Vector2 = player.global_position
	Enemy.fire_rate = clampf(3.5 + 0.30 * float(int((PROFILES[current_biome] as Dictionary)["tier"])) + GameState.run_time / 100.0, 3.5, 14.0) * clampf(GameState.run_time / 60.0, 0.6, 1.0)   # budget de tir global (cf. Enemy._fire_ok)
	var ph: Dictionary = _phase()
	var pi: int = PHASES.find(ph)
	if pi != _phase_idx:
		if _phase_idx >= 0:
			_announce("", "PHASE : " + String(ph["label"]), Color(1.0, 0.45, 0.3))
		_phase_idx = pi
	_tier_tick(delta)
	for q in _squads:
		var ms: Array = q.live()
		if ms.is_empty():
			q.done = true
			continue
		q.update(delta, p, float((ms[0] as Enemy).speed))
		if q.chef_down:
			q.chef_down = false
			_announce("", "CHEF ABATTU - L'ESCOUADE HESITE", Color(1.0, 0.8, 0.3))
	_squads = _squads.filter(func(q: Squad) -> bool: return not q.done)
	_squad_t -= delta
	if _squad_t <= 0.0:
		var tier: int = int((PROFILES[current_biome] as Dictionary)["tier"])
		_squad_t = lerpf(24.0, 11.0, float(tier - 1) / 17.0)
		_spawn_squad()

## ELITE ALEATOIRE (survivor-td §8.2 : 5 % + 0,5 %/min) : un ennemi isole sur ~20 devient elite (or-rose, 3x PV, 1,6x degats, +10 %
## de vitesse sous le plafond de 80 % du joueur) et laisse un butin. Les escouades ont deja leurs grades.
func _maybe_elite(e: Enemy) -> void:
	if not PROFILES.has(current_biome) or not e.kind.begins_with("mech") or e.grade != "":
		return
	var minutes: float = GameState.run_time / 60.0
	if randf() >= minf((0.05 + 0.005 * minutes) * float(_phase()["elite"]), 0.3):
		return
	e.grade = "elite"
	e.hp *= minf(2.0 + 0.5 * minutes, 5.0)   # opensurvivor : l'elite devient plus coriace avec le temps
	e.hp_max = e.hp
	e.contact_dmg *= 1.6
	e.attack_dmg *= 1.6
	e.speed = minf(e.speed * 1.1, float(player.base_speed) * 0.8) if "base_speed" in player else e.speed
	e.drops_bonus = true
	e._spr.self_modulate = Color(1.5, 0.7, 1.4)
	e._spr.scale *= 1.1

func _spawn_squad(force: bool = false) -> void:
	var prof: Dictionary = PROFILES.get(current_biome, {})
	var pool: Array = BIOME_POOL.get(current_biome, [])
	if prof.is_empty() or pool.is_empty() or game == null:
		return
	var tier: int = int(prof["tier"])
	if _squads.size() >= 1 + tier / 7 and not force:
		return
	var n: int = clampi(4 + tier / 3, 4, 10)
	n = maxi(3, int(round(float(n) * clampf(0.5 + GameState.run_time / 240.0, 0.5, 1.0))))   # escouades plus petites en debut de partie
	if get_tree().get_nodes_in_group("enemies").size() + n > ENEMY_CAP:
		return
	var kind: String = String(pool[0])
	if not DEFS.has(kind):
		return
	var form: String = _pick_formation(prof)
	var p: Vector2 = player.global_position
	var anchor: float = randf() * TAU
	if "velocity" in player and (player.velocity as Vector2).length() > 60.0 and form in ["ligne", "colonne", "coin", "echelon", "vague", "embuscade"]:
		anchor = (player.velocity as Vector2).angle() + randf_range(-0.5, 0.5)   # ils se dressent sur sa route
	var q: Squad = Squad.new()
	q.setup(form, anchor, p + Vector2.from_angle(anchor) * 640.0, p)
	for i in n:
		var pos: Vector2 = q.slot(i, n, p)
		var off: Vector2 = pos - p
		if off.length() < 520.0:
			pos = p + (off.normalized() if off.length() > 1.0 else Vector2.RIGHT) * 560.0   # jamais d'apparition sur le joueur
		if arena_half > 0.0:
			pos.x = clampf(pos.x, arena.position.x, arena.end.x)
			pos.y = clampf(pos.y, arena.position.y, arena.end.y)
		var e: Enemy = Enemy.new()
		e.global_position = pos
		game.enemy_layer.add_child(e)
		e.setup(kind, _def_for(kind), player, game)
		_scale_enemy(e)
		q.members.append(e)
	q.assign_ranks()
	_squads.append(q)
	_announce(form, "FORMATION : " + Squad.label(form), Color(1.0, 0.62, 0.3))

## ======================= HIERARCHIE D'ENNEMIS PAR NIVEAU (22/10, patron : « integrer les Mark 2, intermediaires, mini-boss, boss ») =======================
## Meme modele 3D que l'ennemi de base du niveau (pas de nouvelle modelisation) ; ce qui change : taille, PV, teinte, armement, defenses.
##   mk2   : variante renforcee, melee au flux normal des 2 min a ~35 % des apparitions (bouclier actif + blinde)
##   inter : intermediaire (rang 1), 1 toutes les ~80 s des 2 min 30 (2 max vivants), lourd + blinde + garde
##   mini  : mini-boss (rang 2) a 5:00 et 10:00, salve en barrage + blinde + garde + esquive
##   boss  : boss de fin de niveau (rang 4, `final`) a 15:00 : sa mort = VICTOIRE ; invoque une escouade toutes les ~22 s ;
##           les apparitions normales ralentissent (x0,6) tant qu'il vit (survivor-td : pause des spawns pendant un boss)
const TIERS: Dictionary = {
	"mk2":   {"flags": ["blinde", "garde"],                          "hp": 2.4,   "dmg": 1.25, "size": 1.15, "radius": 1.1,  "rank": 0, "tint": Color(1.5, 0.85, 0.65), "label": "MARK 2"},
	"inter": {"flags": ["lourd", "blinde", "garde"],                 "hp": 12.0,  "dmg": 1.5,  "size": 1.45, "radius": 1.35, "rank": 1, "tint": Color(1.6, 0.55, 0.5),  "label": "INTERMEDIAIRE"},
	"mini":  {"flags": ["barrage", "blinde", "garde"],               "hp": 24.0,  "dmg": 1.5,  "size": 1.8,  "radius": 1.7,  "rank": 2, "tint": Color(1.7, 0.4, 0.9),   "label": "MINI-BOSS", "shield": 80.0},
	"boss1": {"flags": ["barrage", "blinde"],                         "hp": 48.0,  "dmg": 1.4,  "size": 2.0,  "radius": 1.9,  "rank": 3, "tint": Color(1.8, 0.5, 0.35), "label": "BOSS", "shield": 180.0, "zone_shift": false},
	"boss2": {"flags": ["barrage", "lourd", "blinde"],               "hp": 85.0,  "dmg": 1.5,  "size": 2.15, "radius": 2.0,  "rank": 3, "tint": Color(1.8, 0.4, 0.3),  "label": "BOSS", "shield": 280.0, "zone_shift": false},
	"boss":  {"flags": ["barrage", "lourd", "blinde"],               "hp": 130.0, "dmg": 1.6,  "size": 2.3,  "radius": 2.1,  "rank": 4, "tint": Color(1.8, 0.35, 0.3),  "label": "BOSS", "shield": 420.0},
}
var _boss_ref: Variant = null
var _tier_last: Dictionary = {"inter": 120.0, "summon": 0.0}
var _tier_fired: Dictionary = {}

func _tier_def(tier_name: String) -> Dictionary:
	var pool: Array = BIOME_POOL.get(current_biome, [])
	var prof: Dictionary = PROFILES.get(current_biome, {})
	if pool.is_empty() or prof.is_empty() or not DEFS.has(String(pool[0])):
		return {}
	var key: String = "T|%s|%s" % [current_biome, tier_name]
	if _prof_defs.has(key):
		return _prof_defs[key]
	var tp: Dictionary = TIERS[tier_name]
	var tier: int = int(prof["tier"])
	var d: Dictionary = _role_def(String(pool[0]), (prof["main"] as Array) + (tp["flags"] as Array), tier)
	d["name"] = "%s %s" % [String(DEFS[String(pool[0])]["name"]), String(tp["label"])]
	d["hp"] = float(d["hp"]) * float(tp["hp"])
	if tp.has("shield"):
		d["shield"] = float(tp["shield"])
	d["dmg"] = float(d["dmg"]) * float(tp["dmg"])
	d["attack_dmg"] = float(d["attack_dmg"]) * float(tp["dmg"])
	d["size"] = float(d["size"]) * float(tp["size"])
	d["radius"] = float(d["radius"]) * float(tp["radius"])
	d["rank"] = int(tp["rank"])
	d["tint"] = tp["tint"]
	d["speed"] = float(d["speed"]) * (0.9 if int(tp["rank"]) >= 2 else 1.0)
	d["zone_shift"] = bool(tp.get("zone_shift", true))
	if tier_name.begins_with("boss"):
		d["ogive"] = true
		d["final"] = (tier_name == "boss") and not GameState.endless
		d["behavior"] = "ranged"
		d["prefer_dist"] = 300.0
	_prof_defs[key] = d
	return d

func _spawn_tier(tier_name: String) -> Enemy:
	var d: Dictionary = _tier_def(tier_name)
	if d.is_empty() or player == null or not is_instance_valid(player) or game == null:
		return null
	var pool: Array = BIOME_POOL.get(current_biome, [])
	var e: Enemy = Enemy.new()
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2.from_angle(ang) * 700.0
	if arena_half > 0.0:
		e.global_position.x = clampf(e.global_position.x, arena.position.x, arena.end.x)
		e.global_position.y = clampf(e.global_position.y, arena.position.y, arena.end.y)
	game.enemy_layer.add_child(e)
	e.setup(String(pool[0]) + "_" + tier_name, d, player, game)
	_scale_enemy(e)
	var tp: Dictionary = TIERS[tier_name]
	if game.has_method("spawn_vfx"):
		game.spawn_vfx("shockwave", e.global_position, 0.0, 1.5 + float(tp["size"]), tp["tint"])
	_announce("", "!  %s  !" % String(tp["label"]), tp["tint"])
	Audio.sfx("boss", 0.1)
	if tier_name.begins_with("boss"):
		_boss_ref = e
		Audio.music("boss")
	return e

func _live_tier(rank_min: int) -> int:
	var n: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).alive and int((e as Enemy).rank) >= rank_min and (e as Enemy).kind.contains("_"):
			n += 1
	return n

func _boss_up() -> bool:
	return _boss_ref != null and is_instance_valid(_boss_ref) and _boss_ref.alive

## ORDRE D'APPARITION (22/10, patron : « l'ordre d'apparition » ; base de reference : docs/SURVIVOR_IO_PLAYBOOK.md §5, timeline
## d'evenements scriptee, boss 5/10/15 min, mini-boss/elite entre, la pietaille « devient blindee » apres un boss) :
##   0:00  ennemi de BASE (continu)            1:30  MARK 2 introduits (part croissante)      2:00  INTERMEDIAIRE (puis ~1 / 90 s, 2 max)
##   3:00  MINI-BOSS (puis 8:00, 12:00)        5:00  BOSS 1 (la base devient surtout MARK 2)  10:00 BOSS 2 (Mark 2 dominant)
##   15:00 BOSS FINAL (victoire) ; invocations d'escouade toutes les 22 s pendant un boss, apparitions x0,6.
const TIER_EVENTS: Array = [
	{"t": 180.0, "tier": "mini"}, {"t": 300.0, "tier": "boss1"}, {"t": 480.0, "tier": "mini"},
	{"t": 600.0, "tier": "boss2"}, {"t": 720.0, "tier": "mini"}, {"t": 900.0, "tier": "boss"},
]
## Echeancier de la hierarchie (appele par _squad_tick, apres les phases)
func _tier_tick(_delta: float) -> void:
	var t: float = GameState.run_time
	if t >= 120.0 and t - float(_tier_last["inter"]) >= 90.0 and not _boss_up() and _live_tier(1) < 2:
		_tier_last["inter"] = t
		_spawn_tier("inter")
	for ev in TIER_EVENTS:
		var et: float = float(ev["t"])
		if t >= et and not _tier_fired.has(et) and not _boss_up():
			_tier_fired[et] = true
			_spawn_tier(String(ev["tier"]))
	if _boss_up() and t - float(_tier_last["summon"]) >= 22.0:
		_tier_last["summon"] = t
		_spawn_squad(true)

## MARK 2 : part des apparitions de base. Introduits des 1:30, puis « swap de base » apres le boss 1 (5:00) et le boss 2 (10:00).
func _mk2_share() -> float:
	var t: float = GameState.run_time
	if t >= 600.0:
		return 0.8
	if t >= 300.0:
		return 0.6
	return clampf((t - 90.0) / 210.0, 0.0, 1.0) * 0.35
## <<< PROFILS DE NIVEAU

func _spawn() -> void:
	if player == null or not is_instance_valid(player):
		return
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return
	var kind: String = _weighted_pick()
	if not DEFS.has(kind):
		return
	var e: Enemy = Enemy.new()
	var spos: Vector2 = player.global_position + _pattern_offset()
	if arena_half > 0.0:
		# Keep spawns inside the walls. Fleeing toward a wall means the ahead-spawns land ON the
		# wall in front of you -> you get pinned, which is the whole point of the bounded arena.
		spos.x = clampf(spos.x, arena.position.x, arena.end.x)
		spos.y = clampf(spos.y, arena.position.y, arena.end.y)
	e.global_position = spos
	game.enemy_layer.add_child(e)
	e.setup(kind, _def_for(kind), player, game)
	_scale_enemy(e)
	_maybe_elite(e)

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
	# 22/10 (banc d'equilibre) : la difficulte doit MONTER avec le niveau (chapitre) : +4 % de PV par rang de niveau.
	# MONTEE EN CHARGE sur les 90 premieres secondes : adoucit les multiplicateurs extremes de tier et de protocole (ex: COLOSSES)
	# pour que le joueur de niveau 1-2 puisse faire ses premiers kills et lancer son build (supprime les 25% de morts precoces).
	var tier_n: float = float(int((PROFILES.get(current_biome, {}) as Dictionary).get("tier", 1)) - 1)
	var t0: float = GameState.run_time
	var tier_ease: float = clampf(t0 / 90.0, 0.35, 1.0)
	var proto_hp: float = lerpf(1.0, Protocols.enemy_hp, clampf(t0 / 75.0, 0.0, 1.0))
	var hp_scale: float = (1.0 + 0.04 * tier_n * tier_ease) * (1.0 + t0 * 0.0020) * (1.0 + difficulty_bonus) * float(d.get("hp", 1.0)) * proto_hp
	e.hp *= hp_scale
	e.hp_max = e.hp
	if e.shield_max > 0.0:               # shields scale with HP too, else late-game shields are trivial
		e.shield_max *= hp_scale
		e.shield = e.shield_max
	var proto_dmg: float = lerpf(1.0, Protocols.enemy_dmg, clampf(t0 / 75.0, 0.0, 1.0))
	var dmg_scale: float = (1.0 + GameState.run_time * 0.0008) * (1.0 + difficulty_bonus * 0.5) * float(d.get("dmg", 1.0)) * proto_dmg
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
