extends Node
## Live run state (reset each run). Progression math lives here so HUD/Player read
## one source of truth.

var run_time: float = 0.0
var level: int = 1
var xp: int = 0
var xp_to_next: int = 5
var kills: int = 0
var props_destroyed: int = 0   # decor broken this run (daily-quest tracking)
var scrap: int = 0
var run_xp_mult: float = 1.0     # passif +EXP (Koga Ninja Scroll) — reset chaque partie
var run_scrap_mult: float = 1.0  # passif +Or (Oil Bond) — reset chaque partie
var overdrive: float = 0.0    # 0..1 — fills with kills, unlocks the transformation
var overdrive_active: bool = false   # true during the Overdrive spike -> global XP magnet
var overdrive_count: int = 0  # transformations this run (diagnostic: uptime must stay well under 100%)
var overdrive_time: float = 0.0   # seconds spent transformed (i.e. invincible)
## Lockout after a transformation ends. Blocking mid-transform refill alone still left ~35% of the
## run spent invincible, because the gauge refilled instantly the moment it ended. The cooldown is
## what actually forces stretches of vulnerable play between spikes.
const OVERDRIVE_COOLDOWN: float = 16.0
var overdrive_cd: float = 0.0
var alive: bool = true
var score: int = 0            # run score (kills weighted by rank x difficulty) -> leaderboard/grade

# --- DIFFICULTY (chosen at run start) : scales foes + rewards + score weight ---
const DIFFICULTY: Array = [
	# 🚨 FACILE est la difficulte IMPOSEE par le chapitre 1, donc l'apprentissage du jeu.
	# Mesure : 70 PV de base, 6 a 15 PV par contact toutes les 0,5 s -> deux ennemis colles
	# vident la barre en quelques secondes, « une erreur ne se paie pas, elle se punit ».
	# On adoucit les DEGATS sur ce seul palier (0.68 -> 0.56). NORMAL et au-dela inchanges.
	# ⚠️ a reconfirmer manette/doigt en main : le testeur tournait a 2-3 im/s et le dit lui-meme.
	{"name": "FACILE",   "hp": 0.72, "dmg": 0.56, "speed": 0.92, "spawn": 0.85, "reward": 0.8, "score": 0.7},
	{"name": "NORMAL",   "hp": 1.00, "dmg": 1.00, "speed": 1.00, "spawn": 1.00, "reward": 1.0, "score": 1.0},
	{"name": "DIFFICILE","hp": 1.40, "dmg": 1.28, "speed": 1.06, "spawn": 1.20, "reward": 1.3, "score": 1.6},
	{"name": "VETERAN",  "hp": 1.85, "dmg": 1.62, "speed": 1.12, "spawn": 1.45, "reward": 1.7, "score": 2.4},
]
var difficulty: int = 1       # index into DIFFICULTY (default NORMAL)

# --- SANS FIN (endless) : the endboss stops being an ending and becomes a milestone. Waves keep
# coming with a permanent escalation per wave; the run ends only when the player dies.
var endless: bool = false
var endless_wave: int = 0     # endbosses put down this run

## Set by REJOUER: the next scene load drops straight into a run instead of the hub. Deliberately
## NOT cleared by reset() — it has to survive the reload it triggers.
var skip_hub: bool = false

func diff() -> Dictionary:
	return DIFFICULTY[clampi(difficulty, 0, DIFFICULTY.size() - 1)]

# Rank grade from final score (shown next to the player on results/leaderboard).
func grade() -> String:
	if score >= 60000: return "S+"
	elif score >= 38000: return "S"
	elif score >= 22000: return "A"
	elif score >= 12000: return "B"
	elif score >= 6000: return "C"
	elif score >= 2500: return "D"
	return "E"

# --- META-PROGRESSION (persistent talents bought with banked scrap between runs) ---
# Data-driven: id -> {name, stat, per(-level bonus), max(level), cost[per level]}.
# Caps kept modest (guide: meta <= ~+30%) so skill stays king, not pay/grind-to-win.
# Costs are now in SKILL POINTS (small numbers): you start with 7 and earn ~1-4 per run.
const META: Dictionary = {
	"vitalite":  {"name": "Vitalité",  "stat": "hp",        "per": 10.0, "max": 5, "cost": [1, 2, 3, 4, 5]},
	"puissance": {"name": "Puissance", "stat": "damage",    "per": 0.06, "max": 5, "cost": [2, 3, 4, 5, 6]},
	"agilite":   {"name": "Agilité",   "stat": "speed",     "per": 0.035, "max": 4, "cost": [1, 2, 3, 4]},
	"cupidite":  {"name": "Cupidité",  "stat": "xp",        "per": 0.08, "max": 4, "cost": [2, 3, 4, 5]},
	"surcharge": {"name": "Surcharge", "stat": "overdrive", "per": 0.10, "max": 3, "cost": [3, 4, 6]},
}
# STARTING WEAPONS — chosen in the hub. autocannon is free; the rest cost skill points to unlock.
const WEAPONS: Array = [
	{"id": "autocannon", "name": "Autocanon", "cost": 0, "desc": "Tir rapide, polyvalent"},
	{"id": "missilepod", "name": "Missiles",  "cost": 3, "desc": "Ogives chercheuses"},
	{"id": "railgun",    "name": "Railgun",   "cost": 4, "desc": "Perce les ennemis"},
	{"id": "plasma",     "name": "Plasma",    "cost": 5, "desc": "Dégâts de zone"},
	{"id": "sabre",      "name": "Sabre",     "cost": 4, "desc": "Mêlée en arc"},
	{"id": "disperseur", "name": "Disperseur","cost": 4, "desc": "Gerbe d'éclats, courte portée"},
	{"id": "ricochet",   "name": "Ricochet",  "cost": 5, "desc": "Obus qui rebondit d'ennemi en ennemi"},
	{"id": "disque",     "name": "Disque",    "cost": 5, "desc": "Part, traverse tout et revient"},
	{"id": "faisceau",   "name": "Faisceau",  "cost": 6, "desc": "Rayon continu, touche en ligne"},
]
var meta_hp: float = 0.0
var meta_dmg: float = 0.0
var meta_speed: float = 0.0
var meta_xp: float = 0.0
var meta_od: float = 0.0

# --- MECHS (alternate chassis bought with scrap "credits"; each plays DIFFERENTLY) ---
# Reuses the already-baked 4-dir sheets in assets/mecha/. hp = flat +max HP, dmg/speed =
# multipliers, crit = flat +chance, weapons = distinct starter loadout.
# Playable mechs = the animated 3D models (Quaternius + Meshy), each baked to 4-direction
# animated sheets (idle/walk/run/attack/hit/die). 'id' doubles as the DirectionalMecha chassis
# AND the stat block. mecha_joueur (AEGIS) is the free starter.
## 🚨 Le GARAGE n'avait qu'UN SEUL chassis (chasseur de bugs, B12) : tout l'ecran d'achat et
## d'equipement — pourtant entierement code — ne servait a rien.
## Les planches d'animation d'autres chassis EXISTENT dans assets/mecha/. Verification faite
## image par image (4 directions x idle/walk/attack/die) avant d'en ajouter :
## CHASSIS JOUABLES. Verification faite CADRE PAR CADRE, en grand, sur les 8 images de
## chaque animation et les 4 directions — et NON sur la premiere vignette, ce qui m'avait
## fait conclure a tort qu'une planche etait bonne.
##   • vortex     -> 24/24 planches propres                                   => OK
##   • bluestrike -> le bake JOUEUR avait les bras vers l'ARRIERE en vue de face (releve par
##                   le patron) et un profil recroqueville. Il existe une version CORRIGEE,
##                   celle dont derivent les ennemis bs_<biome> : bras bas et EN AVANT, arme
##                   tenue devant. Source : meshy_in/bluestrike_eyebase/walk_<dir>.png, la
##                   base neutre que tools/recolor_biomes_to_game.py repeint par biome.
##                   Les 4 planches de MARCHE corrigees ont remplace les anciennes ; les
##                   autres animations ont ete mises de cote dans
##                   _backup_bluestrike_bras_arriere/ pour que la chaine de repli de
##                   DirectionalMecha (voir _paths()) retombe sur la marche corrigee.
##                   => le chassis est toujours bien pose, jamais bras en arriere.      => OK
##   • george / mecha_joueur / darkstar / new_mecha -> bakes rates (mecha effondre de
##                   profil, poses incoherentes, art minuscule)                 => ecartes
## ARSENAL PAR CHASSIS.
## 🚨 Consigne patron : « chaque mecha doit avoir sa gamme d'armes specifique et son arme
## boostee specifique ; ils doivent avoir le MEME NOMBRE d'armes, avec des effets speciaux
## distingues et particuliers pour chacun. »
## Avant, le pool d'armes etait GLOBAL : les deux chassis tiraient dans les 9 memes armes et
## le champ "weapons" ne servait qu'a fixer l'arme de depart. Deux chassis, un seul ressenti.
##
## Chaque chassis a donc :
##   • arsenal  : les 5 SEULES armes qu'il peut piocher (signature comprise) — 5 pour tous,
##                a parite stricte. Les 9 armes sont reparties 5/5, « plasma » etant la seule
##                partagee (c'est le pivot neutre : degats de zone, sans famille).
##   • signature: son arme de depart, et la SEULE qu'il BOOSTE (voir WeaponSystem.SIG_DMG).
##   • accent   : la couleur qui repeint sa signature — projectile, amorce, impact. C'est ce
##                qui fait qu'un autocanon de VORTEX ne ressemble a rien d'autre dans le jeu.
##   • sig_muzzle : l'effet de bouche propre a sa signature. L'impact, lui, herite de
##                l'accent (la couleur voyage avec le projectile) et d'une gerbe 25 % plus
##                large — voir WeaponSystem.SIG_FX.
##
## Ajouter un chassis = une ligne ici. Le plafond d'emplacements (Game.MAX_ACTIFS) reste le
## garde-fou commun ; l'arsenal decide QUOI peut entrer dans ces emplacements.
const MECHS: Array = [
	{"id": "vortex", "name": "VORTEX", "cost": 0,
		"weapons": ["autocannon"], "hp": 20.0, "dmg": 1.20, "speed": 1.05, "crit": 0.08,
		"arsenal": ["autocannon", "railgun", "faisceau", "disque", "plasma"],
		"signature": "autocannon", "accent": Color(0.38, 0.92, 1.00),
		"sig_muzzle": ["aaa_beam", 0.46],
		"ligne": "ÉNERGIE DIRIGÉE — perce, traverse, aligne.",
		"desc": "Prototype VORTEX — armure noire, néon cyan, cœur orange, visée 360°"},
	{"id": "bluestrike", "name": "BLUESTRIKE", "cost": 1400,
		"weapons": ["disperseur"], "hp": 6.0, "dmg": 1.05, "speed": 1.24, "crit": 0.15,
		"arsenal": ["disperseur", "missilepod", "ricochet", "sabre", "plasma"],
		"signature": "disperseur", "accent": Color(1.00, 0.54, 0.16),
		"sig_muzzle": ["fire_blast", 0.40],
		"ligne": "SOUFFLE RAPPROCHÉ — sature, disloque, se replie.",
		"desc": "Éclaireur léger, très rapide, gerbe à courte portée. Frappe et se replie."},
	# --- PHASE DE TEST : ces trois chassis sont GRATUITS et possedes d'office ------------
	# 🚨 Consigne patron : « titan et vanguard 1 et 2 que je dois pouvoir jouer gratuitement
	# pour la phase de test ». Leur cout est a 0, et SaveManager les accorde automatiquement
	# (tout chassis a cout 0 est possede — voir _accorde_chassis_gratuits). Remettre un prix
	# ici suffira a les faire repasser payants, sans autre modification.
	{"id": "vanguard", "name": "VANGUARD", "cost": 0,
		"weapons": ["missilepod"], "hp": 28.0, "dmg": 1.10, "speed": 1.00, "crit": 0.09,
		"arsenal": ["missilepod", "plasma", "ricochet", "disperseur", "autocannon"],
		"signature": "missilepod", "accent": Color(1.00, 0.38, 0.22),
		"sig_muzzle": ["fire_blast", 0.48],
		"ligne": "SATURATION — le ciel retombe sur eux.",
		"desc": "Plateforme d'appui. Ogives chercheuses en gerbe, dégâts de zone."},
	{"id": "vanguard2", "name": "VANGUARD II", "cost": 0,
		"weapons": ["faisceau"], "hp": 16.0, "dmg": 1.28, "speed": 1.10, "crit": 0.12,
		"arsenal": ["faisceau", "railgun", "plasma", "disque", "autocannon"],
		"signature": "faisceau", "accent": Color(1.00, 0.35, 0.62),
		"sig_muzzle": ["aaa_charge", 0.50],
		"ligne": "RAYON CONTINU — ne vise pas, balaie.",
		"desc": "Évolution du VANGUARD. Rayon continu : reste aligné et tout fond."},
	{"id": "titan", "name": "TITAN", "cost": 0,
		"weapons": ["plasma"], "hp": 52.0, "dmg": 1.05, "speed": 0.86, "crit": 0.06,
		"arsenal": ["plasma", "missilepod", "sabre", "disperseur", "railgun"],
		"signature": "plasma", "accent": Color(0.80, 0.34, 1.00),
		"sig_muzzle": ["aaa_charge", 0.58],
		"ligne": "MASSE — il encaisse, puis il efface la zone.",
		"desc": "Le plus lourd du parc. Lent, très résistant, dégâts de zone violets."},
]

## Les 5 armes que ce chassis peut piocher. Repli : tout l'arsenal historique, pour qu'un
## chassis ajoute sans champ « arsenal » reste jouable au lieu de n'avoir aucune arme.
static func mech_arsenal(id: String) -> Array:
	var a: Array = mech_def(id).get("arsenal", [])
	if a.is_empty():
		var tous: Array = []
		for w in WEAPONS:
			tous.append(String(w["id"]))
		return tous
	return a

## L'arme signature du chassis : son arme de depart, et la seule qu'il booste.
static func mech_signature(id: String) -> String:
	var d: Dictionary = mech_def(id)
	return String(d.get("signature", String((d.get("weapons", ["autocannon"]) as Array)[0])))

static func mech_def(id: String) -> Dictionary:
	for m in MECHS:
		if String(m["id"]) == id:
			return m
	return MECHS[0]

func reset() -> void:
	run_time = 0.0
	level = 1
	xp = 0
	xp_to_next = 5
	kills = 0
	props_destroyed = 0
	scrap = 0
	run_xp_mult = 1.0
	run_scrap_mult = 1.0
	overdrive = 0.0
	overdrive_active = false
	overdrive_count = 0
	overdrive_time = 0.0
	overdrive_cd = 0.0
	alive = true
	score = 0
	difficulty = SaveManager.get_difficulty()   # default from last choice; run-start menu can override
	endless = bool(SaveManager.setting("endless", false))
	endless_wave = 0
	_compute_meta()

func _compute_meta() -> void:
	meta_hp = 0.0; meta_dmg = 0.0; meta_speed = 0.0; meta_xp = 0.0; meta_od = 0.0
	for id in META:
		var lvl: int = SaveManager.meta_level(id)
		if lvl <= 0:
			continue
		var d: Dictionary = META[id]
		var amt: float = float(d["per"]) * lvl
		match String(d["stat"]):
			"hp": meta_hp += amt
			"damage": meta_dmg += amt
			"speed": meta_speed += amt
			"xp": meta_xp += amt
			"overdrive": meta_od += amt

func add_xp(amount: int) -> void:
	amount = int(ceil(amount * (1.0 + meta_xp) * run_xp_mult))   # meta Cupidité + passif +EXP
	xp += amount
	Events.xp_gained.emit(amount)
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(xp_to_next * 1.35)) + 2
		Events.level_up.emit(level)

func add_scrap(amount: int) -> void:
	amount = int(round(amount * float(diff().get("reward", 1.0)) * Protocols.reward * run_scrap_mult))   # diff + protocole + passif +Or
	scrap += amount
	Events.scrap_collected.emit(amount)

func add_kill(pos: Vector2, rank: int) -> void:
	kills += 1
	score += int(round((10 + rank * 40) * float(diff().get("score", 1.0))))   # rank & difficulty weighted
	add_overdrive(0.055 + rank * 0.03)
	Events.enemy_killed.emit(pos, rank)

func add_overdrive(a: float) -> void:
	# The gauge does NOT refill while transformed. Overdrive grants INVINCIBILITY for TF_DUR (8 s),
	# and kills made during those 8 s used to refill it faster than it drained (measured: 58% uptime
	# with a weak bot, trending to 100% for a real build). That made every run unloseable and voided
	# the whole difficulty curve. The design intent is in Player.TF_DUR's comment: "short, intense,
	# then vulnerable again."
	if overdrive_active or overdrive_cd > 0.0:
		return
	overdrive = clampf(overdrive + a * (1.0 + meta_od), 0.0, 1.0)   # Surcharge meta talent
	Events.overdrive_changed.emit(overdrive)

## Ticked by Player each frame; gates the gauge for OVERDRIVE_COOLDOWN seconds after a spike ends.
func tick_overdrive_cd(delta: float) -> void:
	if overdrive_cd > 0.0:
		overdrive_cd = maxf(0.0, overdrive_cd - delta)
		if overdrive_cd == 0.0:
			Events.overdrive_changed.emit(overdrive)   # refresh the HUD when the gauge reopens
