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
var difficulty_bonus: float = 0.0   # permanent step-up per cleared zone (set by Game.next_map)
var current_biome: String = "tech"   # set by Game per zone -> filtre le pool d ennemis
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
const DEFS: Dictionary = {
	# ===== TEST : Blue Strike = SEUL ennemi, une peinture + specificite PAR CARTE =====
	"bs_tech":      {"name": "Machine Tech", "chassis": "bs_tech", "hp": 26.0, "speed": 178.0, "dmg": 9.0, "radius": 32.0, "size": 150.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
	"bs_earth":     {"name": "Broyeur Terre", "chassis": "bs_earth", "hp": 42.0, "speed": 150.0, "dmg": 12.0, "radius": 34.0, "size": 158.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
	"bs_spaceship": {"name": "Spectre", "chassis": "bs_spaceship", "hp": 22.0, "speed": 214.0, "dmg": 8.0, "radius": 30.0, "size": 146.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "dasher", "unlock": 0.0},
	"bs_volcanic":  {"name": "Fondeur", "chassis": "bs_volcanic", "hp": 28.0, "speed": 192.0, "dmg": 15.0, "radius": 32.0, "size": 150.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
	"bs_desert":    {"name": "Raider", "chassis": "bs_desert", "hp": 20.0, "speed": 232.0, "dmg": 8.0, "radius": 30.0, "size": 144.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
	"bs_ice":       {"name": "Blinde Givre", "chassis": "bs_ice", "hp": 46.0, "speed": 150.0, "dmg": 10.0, "radius": 34.0, "size": 158.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "shield": 14.0, "unlock": 0.0},
	"bs_jungle":    {"name": "Rodeur Jungle", "chassis": "bs_jungle", "hp": 18.0, "speed": 202.0, "dmg": 7.0, "radius": 28.0, "size": 142.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
	"bs_swamp":     {"name": "Corrosif", "chassis": "bs_swamp", "hp": 30.0, "speed": 152.0, "dmg": 11.0, "radius": 32.0, "size": 150.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
	"bs_ruines":    {"name": "Charognard", "chassis": "bs_ruines", "hp": 26.0, "speed": 186.0, "dmg": 9.0, "radius": 32.0, "size": 150.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "drops_bonus": true, "unlock": 0.0},
	# ===== ENNEMI TIREUR : canon lourd telegraphie (bi-canon modelise, accent teal, yeux rouges) =====
	"gunner":       {"name": "Artilleur lourd", "chassis": "gunner", "hp": 36.0, "speed": 148.0, "dmg": 8.0, "radius": 34.0, "size": 178.0, "motion": "walk", "rank": 0, "w": 1, "behavior": "ranged", "heavy": true, "attack_dmg": 20.0, "attack_cd": 2.4, "prefer_dist": 360.0, "unlock": 0.0},
	# behavior: rush | ranged | dasher.  "chassis" = baked art reuse (10 chassis). "name" = affichage.
	# La CORRUPTION par biome (teinte) est appliquee au spawn (enemy_tint), pas ici.
	# ---------- UNIVERSELS (pool de CHAQUE biome ; cles brute/drone conservees = refs carcasse/beacon) ----------
	"brute":     {"name": "Rodeur", "chassis": "u_rodeur", "proc": true, "hp": 14.0, "speed": 224.0, "dmg": 6.0, "radius": 30.0, "size": 124.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "unlock": 0.0},
	"drone":     {"name": "Guepe", "chassis": "u_guepe", "proc": true, "hp": 10.0, "speed": 300.0, "dmg": 3.0, "radius": 18.0, "size": 78.0, "motion": "hover", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 4.0, "attack_cd": 1.9, "prefer_dist": 280.0, "unlock": 40.0},
	"quadshell": {"name": "Belier", "chassis": "u_belier", "proc": true, "hp": 18.0, "speed": 214.0, "dmg": 9.0, "radius": 26.0, "size": 122.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "dasher", "unlock": 55.0},
	# ---------- SPECIALISTES par biome (cles neuves, chassis reutilise) ----------
	"sentinelle": {"name": "Sentinelle", "chassis": "shielded", "proc": true, "hp": 26.0, "speed": 196.0, "dmg": 8.0, "radius": 32.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "rush", "shield": 16.0, "unlock": 25.0},
	"tourelle":   {"name": "Tourelle", "chassis": "warden", "proc": true, "hp": 72.0, "speed": 168.0, "dmg": 12.0, "radius": 34.0, "size": 146.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "ranged", "attack_dmg": 14.0, "attack_cd": 1.7, "prefer_dist": 360.0, "drops_bonus": true, "unlock": 120.0},
	"charognard": {"name": "Charognard", "chassis": "elite", "proc": true, "hp": 16.0, "speed": 250.0, "dmg": 7.0, "radius": 28.0, "size": 130.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
	"broyeur":    {"name": "Broyeur", "chassis": "crusher", "proc": true, "hp": 80.0, "speed": 170.0, "dmg": 17.0, "radius": 36.0, "size": 156.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "rush", "drops_bonus": true, "unlock": 120.0},
	"voltigeur":  {"name": "Voltigeur", "chassis": "elite", "proc": true, "hp": 16.0, "speed": 242.0, "dmg": 8.0, "radius": 26.0, "size": 118.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "dasher", "unlock": 0.0},
	"essaim":     {"name": "Essaim", "chassis": "eyedrone", "proc": true, "hp": 13.0, "speed": 180.0, "dmg": 5.0, "radius": 20.0, "size": 96.0, "motion": "hover", "rank": 1, "w": 1, "behavior": "ranged", "attack_dmg": 9.0, "attack_cd": 1.4, "prefer_dist": 320.0, "drops_bonus": true, "unlock": 90.0},
	"lancefeu":   {"name": "Lance-feu", "chassis": "warden", "proc": true, "hp": 70.0, "speed": 172.0, "dmg": 11.0, "radius": 32.0, "size": 142.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "attack_dmg": 11.0, "attack_cd": 1.6, "prefer_dist": 330.0, "unlock": 30.0},
	"fondeur":    {"name": "Fondeur", "chassis": "crusher", "proc": true, "hp": 90.0, "speed": 168.0, "dmg": 18.0, "radius": 36.0, "size": 158.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "rush", "drops_bonus": true, "unlock": 120.0},
	"pillard":    {"name": "Pillard", "chassis": "elite", "proc": true, "hp": 15.0, "speed": 268.0, "dmg": 7.0, "radius": 28.0, "size": 128.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
	"foreuse":    {"name": "Foreuse", "chassis": "crusher", "proc": true, "hp": 68.0, "speed": 196.0, "dmg": 16.0, "radius": 30.0, "size": 140.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "dasher", "drops_bonus": true, "unlock": 120.0},
	"eclat":      {"name": "Eclat", "chassis": "shielded", "proc": true, "hp": 24.0, "speed": 188.0, "dmg": 8.0, "radius": 32.0, "size": 134.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "rush", "shield": 12.0, "unlock": 25.0},
	"givre":      {"name": "Givre", "chassis": "crusher", "proc": true, "hp": 86.0, "speed": 150.0, "dmg": 16.0, "radius": 36.0, "size": 158.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "rush", "drops_bonus": true, "unlock": 120.0},
	"fourmi":     {"name": "Fourmi", "chassis": "elite", "proc": true, "hp": 11.0, "speed": 244.0, "dmg": 5.0, "radius": 26.0, "size": 110.0, "motion": "walk", "rank": 0, "w": 5, "behavior": "rush", "unlock": 0.0},
	"cracheur":   {"name": "Cracheur", "chassis": "warden", "proc": true, "hp": 70.0, "speed": 170.0, "dmg": 11.0, "radius": 32.0, "size": 142.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "ranged", "attack_dmg": 12.0, "attack_cd": 1.6, "prefer_dist": 340.0, "drops_bonus": true, "unlock": 120.0},
	"rampant":    {"name": "Rampant", "chassis": "shielded", "proc": true, "hp": 28.0, "speed": 180.0, "dmg": 8.0, "radius": 32.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "rush", "shield": 14.0, "unlock": 25.0},
	"sangsue":    {"name": "Sangsue", "chassis": "crusher", "proc": true, "hp": 84.0, "speed": 160.0, "dmg": 15.0, "radius": 36.0, "size": 156.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "rush", "drops_bonus": true, "unlock": 120.0},
	"garde":      {"name": "Garde d assaut", "chassis": "elite", "proc": true, "hp": 20.0, "speed": 228.0, "dmg": 9.0, "radius": 30.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
	"artilleur":  {"name": "Artilleur", "chassis": "warden", "proc": true, "hp": 74.0, "speed": 166.0, "dmg": 12.0, "radius": 34.0, "size": 146.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "ranged", "attack_dmg": 15.0, "attack_cd": 1.8, "prefer_dist": 370.0, "drops_bonus": true, "unlock": 120.0},
	# ---------- BOSS (w:0 -> planifies, hors pick) : 3 boss "top Meshy + jambes qui marchent" ----------
	# COLOSSE (5 min) : ZONEUR AoE. Acier & or, ranged + ogive (zones telegraphiees) + bouclier.
	"midboss": {"name": "Colosse", "chassis": "midboss", "hp": 950.0, "speed": 150.0, "dmg": 24.0, "radius": 60.0, "size": 320.0, "motion": "walk", "rank": 3, "w": 0, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 22.0, "attack_cd": 2.2, "prefer_dist": 300.0, "shield": 240.0, "drops_bonus": true},
	# BROYEUR (10 min, bonus) : BRUTE rusheuse. Rouille, gros bouclier + gros degats de contact, rapide.
	"crusherboss": {"name": "Broyeur Titan", "chassis": "crusherboss", "hp": 1500.0, "speed": 190.0, "dmg": 30.0, "radius": 66.0, "size": 340.0, "motion": "walk", "rank": 3, "w": 0, "behavior": "rush", "shield": 380.0, "drops_bonus": true},
	# ===== MINI-BOSS a OGIVES (chassis ogreboss, Noir+Or) : GROS + boucliers + ogives explosives =====
	# 5 min : ogive UNIQUE lente + AoE, bouclier standard.  10 min : SALVE 3 + tir RADIAL, bouclier DOUBLE + +PV.
	"midboss_a": {"name": "Le Bombardier", "chassis": "ogreboss", "hp": 900.0, "speed": 150.0, "dmg": 22.0, "radius": 62.0, "size": 340.0, "motion": "walk", "rank": 3, "w": 0, "behavior": "ranged", "heavy": true, "ogive": true, "attack_dmg": 22.0, "attack_cd": 2.2, "prefer_dist": 300.0, "shield": 220.0, "drops_bonus": true},
	"midboss_b": {"name": "Le Devastateur", "chassis": "ogreboss", "hp": 1450.0, "speed": 160.0, "dmg": 26.0, "radius": 70.0, "size": 380.0, "motion": "walk", "rank": 3, "w": 0, "behavior": "ranged", "heavy": true, "ogive": true, "barrage": true, "attack_dmg": 20.0, "attack_cd": 1.7, "prefer_dist": 300.0, "shield": 450.0, "drops_bonus": true},
	# SOUVERAIN (15 min, FINAL) : obsidienne. Barrage + ANNEAU AoE (ogive+barrage) + bouclier max.
	"endboss": {"name": "Souverain", "chassis": "endboss", "hp": 2800.0, "speed": 160.0, "dmg": 32.0, "radius": 78.0, "size": 380.0, "motion": "walk", "rank": 4, "w": 0, "behavior": "ranged", "heavy": true, "ogive": true, "barrage": true, "attack_dmg": 22.0, "attack_cd": 1.7, "prefer_dist": 300.0, "shield": 500.0, "final": true, "drops_bonus": true},
}

# Pool PAR BIOME : 3 universels (brute/drone/quadshell) + 2 specialistes. Le pick est filtre dessus.
const BIOME_POOL: Dictionary = {
	"tech": ["bs_tech", "gunner"], "earth": ["bs_earth", "gunner"], "spaceship": ["bs_spaceship", "gunner"], "volcanic": ["bs_volcanic", "gunner"],
	"desert": ["bs_desert", "gunner"], "ice": ["bs_ice", "gunner"], "jungle": ["bs_jungle", "gunner"], "swamp": ["bs_swamp", "gunner"], "ruines": ["bs_ruines", "gunner"],
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
}

# Timed run structure: bosses at 5 min (build filter), 10 min, 15 min (final -> victory).
# Matches Survivor.io's chapter 1 beats exactly (boss 5:00, boss ~10:00, final boss 15:00).
const BOSS_SCHEDULE: Array = [
	{"t": 300.0, "kind": "midboss"},      # 5 min : COLOSSE (zoneur AoE, acier & or)
	{"t": 600.0, "kind": "crusherboss"},  # 10 min : BROYEUR TITAN (brute rusheuse, rouille) = mini-boss bonus
	{"t": 900.0, "kind": "endboss"},      # 15 min : SOUVERAIN (boss final = victoire, obsidienne)
]
var _bosses_fired: int = 0
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
		if live < floor_pop:
			var deficit: float = float(floor_pop - live) / float(floor_pop)
			rate /= (1.0 + 3.0 * deficit)
		_spawn_t = rate / maxf(0.2, spawn_mult * float(GameState.diff().get("spawn", 1.0)) * Protocols.spawn_rate)
		_spawn()
	if _bosses_fired < BOSS_SCHEDULE.size() and GameState.run_time >= float(BOSS_SCHEDULE[_bosses_fired]["t"]) * _boss_scale:
		if not _boss_alive():   # never let two bosses coexist -> avoids double next_map in one frame
			_spawn_boss(String(BOSS_SCHEDULE[_bosses_fired]["kind"]))
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
	if player == null or not is_instance_valid(player):
		return
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
	var pool: Array = BIOME_POOL.get(current_biome, ["brute", "drone", "quadshell"])   # filtre PAR BIOME
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
		return "brute"                     # always-available opener (never fall back to a locked kind)
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
	var e: Enemy = Enemy.new()
	var spos: Vector2 = player.global_position + _spawn_offset()
	if arena_half > 0.0:
		# Keep spawns inside the walls. Fleeing toward a wall means the ahead-spawns land ON the
		# wall in front of you -> you get pinned, which is the whole point of the bounded arena.
		spos.x = clampf(spos.x, -arena_half, arena_half)
		spos.y = clampf(spos.y, -arena_half, arena_half)
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
		kind = "drone"
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return
	var e: Enemy = Enemy.new()
	var p: Vector2 = pos
	if arena_half > 0.0:
		p.x = clampf(p.x, -arena_half, arena_half)
		p.y = clampf(p.y, -arena_half, arena_half)
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
	var spd_scale: float = minf(1.0 + difficulty_bonus * 0.10 + GameState.run_time * 0.00018, 1.40)
	e.speed *= speed_mult * float(d.get("speed", 1.0)) * spd_scale * Protocols.enemy_speed
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
