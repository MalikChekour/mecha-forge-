extends Area2D
class_name Enemy

const StackPips = preload("res://actors/StackPips.gd")   # voir la note dans Player.gd

var game: Node
var player: Node2D
var kind: String = "brute"
var chassis: String = "brute"    # which baked sheets to render (may differ from kind)
var hp: float = 20.0
var hp_max: float = 20.0
var speed: float = 90.0
var contact_dmg: float = 8.0
var rank: int = 0
var alive: bool = true
## BRUISER "briser l'armure" (plan de differenciation des chassis, prototype C — 26/09).
## +4%/pile aux degats de TOUTES sources, jusqu'a 5 (+20%) ; moitie moins efficace contre les
## rangs >= 3 (boss), comme demande par le specialiste ("reduire le bonus contre les boss").
## Se vide UNE pile a la fois (pas d'un coup) si Bruiser arrete de toucher pendant 2s.
const BRISURE_STACK_DUR: float = 2.0
const BRISURE_PER_STACK: float = 0.04
var _brisure_stacks: int = 0
var _brisure_t: float = 0.0
var _last_weapon_id: String = ""   # derniere arme trackee a avoir touche -> GameState.add_kill
var _brisure_pips: StackPips
var is_final: bool = false       # the endboss: its death = run victory
var _hp_bg: Line2D
var _hp_fill: Line2D
var _hp_bar_w: float = 0.0
var _hp_bar_y: float = 0.0

var behavior: String = "rush"
var attack_dmg: float = 0.0
var attack_cd: float = 1.0
var prefer_dist: float = 340.0
var heavy: bool = false          # "canon lourd telegraphie": charge visible puis 2 gros bolts lents
var _charging: bool = false
var _charge_t: float = 0.0
var ogive: bool = false          # BOSS a ogives : gros projectiles lents explosifs
# >>> IA21 vars (21/10 : visee, garde active, formation, grade)
var aim_rate: float = 4.0          # rad/s : vitesse a laquelle le bras/canon se tourne vers sa cible
var aim_lead: float = 0.0          # 0..1 : part de l'anticipation du mouvement du joueur
var _aim: float = 0.0
var _aim_goal: float = 0.0
var _aim_init: bool = false
var garde: bool = false            # peut activer un bouclier energetique temporaire
var garde_cd: float = 9.0
var _garde_t: float = 0.0
var _garde_cd_t: float = 3.0
var _garde_pulse: float = 0.0
var form_pos: Vector2 = Vector2.ZERO
var form_w: float = 0.0            # 0 = comportement libre ; 1 = suit son emplacement de formation
var grade: String = ""             # "" soldat | "lieutenant" | "chef"
const _DIR_NAMES: Array = ["right", "front_right", "front", "front_left", "left", "back_left", "back", "back_right"]
const _DIR_DEG: Dictionary = {"right": 0.0, "front_right": 45.0, "front": 90.0, "front_left": 135.0, "left": 180.0, "back_left": -135.0, "back": -90.0, "back_right": -45.0}
# >>> IA22 vars (21/10 : signatures de tir par niveau, esquive, ordre du chef)
var zigzag: float = 0.0            # 0..1 : oscillation laterale de l'approche (Runner/Flyer de survivor-td)
var _tier_tint: Variant = null     # teinte de hierarchie (Mark 2 / inter / mini / boss), restauree apres une garde
var zone_shift: bool = true        # false : sa mort ne fait PAS changer de zone (boss 1/2 de la hierarchie par niveau)
var protecteur: bool = false       # projette un bouclier de zone sur ses allies (Shielder de survivor-td)
var _prot_t: float = 0.0           # >0 : protege par un allie (-40 % de degats)
var _prot_cd: float = 0.0
var _lod_n: int = 0
var tir_style: String = ""         # "" tir de palier | rafale | eventail | sniper | guide | anneau | orbe
var esquive: bool = false
var _esq_cd: float = 2.0
var _esq_t: float = 0.0
var _esq_dir: Vector2 = Vector2.ZERO
var _esq_scan: float = 0.0
var _burst_left: int = 0
var _burst_t: float = 0.0
var _burst_dir: Vector2 = Vector2.RIGHT
var _style_charge: float = 0.0
var chef_ref: Variant = null       # chef de meute de l'escouade : tant qu'il vit, ses troupes encaissent 25 % de moins
var _garde_dome: Node2D = null
var _rank_badge: Node2D = null
var _sniper_laser: Line2D = null

class GardeDome extends Node2D:
	var radius: float = 38.0
	var _t: float = 0.0
	func _ready() -> void:
		set_process(visible)
		visibility_changed.connect(func() -> void: set_process(visible))   # inactif tant que la garde n'est pas levee
	func _process(delta: float) -> void:
		if visible:
			_t += delta
			queue_redraw()
	func _draw() -> void:
		var pulse: float = 0.75 + 0.25 * sin(_t * 8.0)
		draw_circle(Vector2.ZERO, radius, Color(0.12, 0.85, 1.0, 0.25 * pulse))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.2, 0.95, 1.0, 0.95 * pulse), 3.5)
		draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 24, Color(0.4, 1.0, 1.0, 0.5 * pulse), 1.8)
		for i in 6:
			var a1: float = float(i) * TAU / 6.0 + _t * 1.2
			var a2: float = float(i + 1) * TAU / 6.0 + _t * 1.2
			var p1: Vector2 = Vector2.from_angle(a1) * (radius - 2.0)
			var p2: Vector2 = Vector2.from_angle(a2) * (radius - 2.0)
			draw_line(p1, p2, Color(0.65, 1.0, 1.0, 0.85 * pulse), 2.2)
			draw_line(Vector2.ZERO, p1, Color(0.2, 0.85, 1.0, 0.3 * pulse), 1.2)

class RankBadge extends Node2D:
	var grade_type: String = ""
	var _t: float = 0.0
	func _ready() -> void:
		set_process(visible)
		visibility_changed.connect(func() -> void: set_process(visible))
	func _process(delta: float) -> void:
		if visible:
			_t += delta
			queue_redraw()
	func _draw() -> void:
		var bob: float = sin(_t * 4.0) * 2.0
		if grade_type == "chef":
			var gold: Color = Color(1.0, 0.85, 0.2, 1.0)
			var y0: float = bob
			draw_line(Vector2(-12, y0 + 4), Vector2(0, y0 - 8), gold, 3.2)
			draw_line(Vector2(0, y0 - 8), Vector2(12, y0 + 4), gold, 3.2)
			draw_line(Vector2(-10, y0 + 11), Vector2(0, y0 - 1), gold, 2.6)
			draw_line(Vector2(0, y0 - 1), Vector2(10, y0 + 11), gold, 2.6)
			draw_circle(Vector2(0, y0 - 13), 4.0, Color(1.0, 1.0, 0.6))
		elif grade_type == "lieutenant":
			var cyan: Color = Color(0.55, 0.9, 1.25, 0.95)
			var y0: float = bob
			draw_line(Vector2(-9, y0 + 3), Vector2(0, y0 - 6), cyan, 2.6)
			draw_line(Vector2(0, y0 - 6), Vector2(9, y0 + 3), cyan, 2.6)
# <<< IA22 vars
# <<< IA21 vars
var barrage: bool = false        # variante 10-min : salve de 3 en eventail + tir radial periodique
## PHASES DE BOSS (plan de refonte, 29/09 : boss a 3 phases SUR MESURE). Remplace l'ancien
## bool `_phase2` (un seul palier a 50% PV, effet generique identique pour tous les boss) par
## un entier `_phase_idx` + des seuils PAR `kind` (EnemySpawner.BOSS_PHASE_THRESHOLDS) — matcher
## sur `chassis`/`behavior` ne suffit pas : midboss_a et midboss_b partagent les deux mais
## doivent rester differencies (Le Devastateur a deja barrage:true de base, pas Le Bombardier).
## Seul `kind` est unique par boss. Les seuils par defaut ([0.5, 0.2]) gardent le palier a 50%
## EXACTEMENT ou il etait pour les boss deja livres/eprouves — seul belier01 deplace le sien.
var _phase_idx: int = 0
var _boss_frenzy: bool = false      # phase 3 famille ranged+ogive : force l'anneau a CHAQUE tir
var _boss_hazard_cd: float = 0.0    # phase 3 crusherboss/cryoboss/reacteurboss/citadelleboss :
                                     # cooldown partage, differencie par `match kind` au declenchement
var _belier_burst_left: int = 0     # phase 3 belier01 : charges enchainees sans repasser par COOLDOWN
var _reacteur_pulse_on: bool = true     # phase 3 reacteurboss : alterne zone chargee/zone ventee
var _citadelle_push_out: bool = false   # phase 3 citadelleboss : alterne pousse/attire
var _boss_shot: int = 0
# CHARGE DE TAUREAU (ennemis de melee de base) : quand le joueur est en ligne de mire/portee, l'ennemi
# se cabre (telegraph flash) puis FONCE en ligne droite (direction verrouillee). Plafond global = anti-latence.
var bull: bool = false
var _bull_state: int = 0         # 0 = chasse, 1 = wind-up, 2 = charge
var _bull_t: float = 0.0
var _bull_cd: float = 0.0
var _bull_dir: Vector2 = Vector2.ZERO
var _bull_counted: bool = false
var _bull_mod0: Color = Color.WHITE   # teinte de base a restaurer apres la charge
static var _bulls_charging: int = 0
const BULL_CAP: int = 7          # max d'ennemis qui chargent en meme temps (lisibilite + perf)

# ===== NOUVEAUX COMPORTEMENTS (plan direction artistique, 26/09) — chassis DEJA existants,
# aucun nouvel asset : "chaque ennemi doit poser une question differente". =====
var _heal_cd: float = 0.0                  # REPARATEUR
const HEAL_RANGE: float = 260.0
const HEAL_TICK: float = 1.4
const HEAL_FRACTION: float = 0.06          # % du hp_max de LA CIBLE, par tick
var _push_cd: float = 0.0                  # DISPERSEUR (perturbateur)
const PUSH_INTERVAL: float = 2.6
const PUSH_RANGE: float = 150.0
const PUSH_FORCE: float = 420.0
var _mine_cd: float = 0.0                  # MINEUR
const MINE_RANGE: float = 90.0
const MINE_COOLDOWN: float = 4.0
var _kamikaze_arming: bool = false         # KAMIKAZE (29/09, bestiaire elargi)
var _kamikaze_fuse: float = 0.0
const KAMIKAZE_RANGE: float = 90.0
const KAMIKAZE_FUSE_TIME: float = 0.6
var _spr: Sprite2D
var _mat: ShaderMaterial
## 🚨 tente le 26/09 ("trop de lag") : un ShaderMaterial PARTAGE entre tous les ennemis (batching)
## + flash/warn en "instance uniform". Rejete au premier test headless : ce build Godot 4.3 ne
## supporte pas les instance uniforms sur les shaders canvas_item (echec de compilation + methode
## absente sur Sprite2D). Revenu a un ShaderMaterial par ennemi — voir enemy_read.gdshader.
var _frames: int = 1
var _fps: float = 14.0
var _t: float = 0.0
var _flash: float = 0.0
var _contact_cd: float = 0.0

# Energy shield (protection): absorbs damage before HP, ripples on hit, shatters when
# broken, then slowly regenerates. Only enemies with def "shield" > 0 carry one.
var shield_max: float = 0.0
var shield: float = 0.0
var _shield_spr: Sprite2D = null
var _shield_rim: Sprite2D = null
var _shield_regen_t: float = 0.0
var _shield_flash: float = 0.0
var _shield_tint: Color = Color(0.5, 0.9, 1.0)   # couleur du bouclier selon le porteur
var _shield_backA: float = 0.35                  # opacite couche fond (reglages editeur)
var _shield_frontA: float = 0.55                 # opacite couche avant
var _shield_bright: float = 1.0                  # luminosite (reglage editeur)
var _body_radius: float = 24.0
var _bolt_color: Color = Color(1.0, 0.55, 0.25)   # per-enemy ranged-bolt colour
var drops_bonus: bool = false                     # intermediate foes drop a bonus pickup on death
# Shared per-physics-frame snapshot of the enemy group: querying the group per-enemy per-frame is
# O(N^2) allocation at 220 foes (dominant mobile CPU cost). Build it ONCE per frame, all read it.
static var _enemies_frame: int = -1
static var _enemies_cache: Array = []

## 🚨 patron 26/09 ("trop de lag quand il y a beaucoup d'ennemis") : healer/pusher (ajoutes cette
## session) appelaient CHACUN get_tree().get_nodes_in_group("enemies") — une COPIE d'array fraiche,
## independamment de ce cache — exactement l'anti-pattern que le commentaire ci-dessus decrit deja.
## Avec une dizaine de reparateurs/perturbateurs vivants a la fois pres du plafond de 220 ennemis,
## ca fait autant de balayages complets et non synchronises entre eux par seconde. Seul point d'acces
## desormais : reutilise le meme instantane que la separation, reconstruit au plus une fois/frame.
func _shared_enemies() -> Array:
	var pf: int = Engine.get_physics_frames()
	if pf != _enemies_frame:
		_enemies_frame = pf
		_enemies_cache = get_tree().get_nodes_in_group("enemies")
	return _enemies_cache

# Movement internals
var velocity: Vector2 = Vector2.ZERO
# PROCEDURAL enemy (premium static-pose model, no baked walk cycle): the SPRITE is animated in code
# (hop while moving, breathe at rest, squash) so hard-surface mechs stay alive without skeletal skinning.
var _proc: bool = false
var _proc_hover: bool = false        # airborne drone -> continuous float, not a ground stomp
var _proc_base_pos: Vector2 = Vector2.ZERO
var _proc_base_scale: Vector2 = Vector2.ONE
var _proc_t: float = 0.0
var field_slow: float = 1.0   # transient: a slow-field prop dampens this each frame inside it
var _speed_mult: float = 1.0
## Ciblage prioritaire (27/09, rapport "Archives-machines" : rendre l'auto-visee interessante).
## Reduit fictivement la distance vue par Player._nearest_enemy()/_cone_target() -> cet ennemi
## devient plus susceptible d'etre choisi SANS bonus de degats et sans toucher au ciblage des
## missiles a tete chercheuse (Projectile._find_homing_target, boucle independante) ni aux zones
## de faisceau/melee (touchent tout ce qui est dans leur forme, pas seulement la "meilleure" cible).
## 0.0 = aucun effet (defaut). Purement lu par Player.gd ; jamais ecrit ici.
var priority_boost: float = 0.0
var _wander_phase: float = 0.0

# Attack internals
var _atk_cd: float = 0.0
var _phase: int = 0
var _phase_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0

# Animation state
var _anims: Dictionary = {}          # anim -> Texture2D (single) OR {front,back,left,right}
var _cur_anim: String = ""
## 🚨 patron 26/09 ("le jeu se bloque quelques instants et reprend") : _anims est par-INSTANCE,
## donc chaque ennemi refaisait ResourceLoader.exists()+load() sur jusqu'a 5 anims x 4 directions,
## MEME quand 50 "brute" d'affilee redemandent exactement les memes fichiers. Une vague qui spawn
## plusieurs ennemis d'un coup fait donc une pointe de lectures disque redondantes -> le trou net
## puis la reprise que le patron decrit. _feet_cache (plus bas) faisait deja ca correctement pour
## un autre besoin ; meme principe ici, par chassis+anim, partage par TOUS les ennemis.
static var _anim_cache: Dictionary = {}   # "<chassis>|<anim_name>" -> resultat de _load_anim()
var _one_shot: bool = false
var _anim_done: bool = false
var _base_loop: String = ""
var _idle_anim: String = ""
var _dying: bool = false
var _die_timer: float = 0.0
var _dir: String = "front"           # facing, chosen from movement like the player mecha
var _directional: bool = false       # true once any anim has 4-view sheets
const _DIRS: Array[String] = ["front", "back", "left", "right"]
const _DIAGS: Array[String] = ["front_right", "front_left", "back_right", "back_left"]   # 17/10 : ennemis a 8 directions (chapitres 1-18)

# Tuning constants
const _ACCEL: float = 700.0
const _SEP_RADIUS: float = 50.0
const _SEP_FORCE: float = 200.0
## ====================== INTELLIGENCE DES ENNEMIS ======================================
## Jusqu'ici un ennemi « rush » foncait en LIGNE DROITE sur la position COURANTE du joueur,
## avec une ondulation sinusoidale. Aucune anticipation, aucun flanc, aucune coordination :
## la horde etait une masse qui suit, et fuir en ligne droite marchait indefiniment.
##
## On introduit un indice d'intelligence `_iq` de 0 a 1, et QUATRE couches qui s'ouvrent l'une
## apres l'autre. Chacune est LISIBLE et donc CONTRABLE — c'est ce qui separe « plus malin »
## de « simplement plus dur » :
##   1. INTERCEPTION (des la 1re seconde, faible puis croissante) : viser ou le joueur SERA,
##      pas ou il est. Contre : changer de direction.
##   2. ENCERCLEMENT (a partir de ~35 s) : chaque ennemi garde un angle d'approche propre, de
##      plus en plus ecarte — la meute arrive par plusieurs releves au lieu de s'empiler
##      derriere. Contre : percer tot, avant que l'anneau ne se ferme.
##   3. PATIENCE (a partir de ~70 s) : un ennemi arrive SEUL hesite hors de portee et tourne
##      autour en attendant ses semblables, puis ils s'engagent ensemble. Contre : tuer les
##      isoles, ou forcer le passage avant le regroupement.
##   4. OPPORTUNISME (a partir de ~110 s) : quand le joueur est bas en vie, ils cessent
##      d'hesiter et presse le pas.
##
## 🚨 LE CRESCENDO SUIT AUSSI LE NIVEAU DU JOUEUR, pas seulement le temps. C'est voulu : le
## banc a montre que les parties sont BIMODALES (mort rapide, ou envolee jusqu'a 9 minutes) —
## un joueur qui prend l'avantage voyait le jeu s'ecrouler devant lui. Indexer l'intelligence
## sur son niveau met une pression qui monte avec lui, sans toucher aux degats ni aux PV.
## 🚨 SEUILS RECALES SUR LA DUREE REELLE DES PARTIES, pas sur une intention.
## Mesure, n=20, NORMAL/tech : mort mediane 58 s, niveau median 6, survie 15 % a 90 s, 0 % a
## 120 s. Avec les anciens seuils (180 s / niveau 12), 15 parties sur 20 ne depassaient JAMAIS
## le palier 1, 5 atteignaient le palier 2, et AUCUNE ne voyait le palier 3 : un crescendo a
## quatre paliers dont les trois quarts etaient injouables. C'est la meme erreur que les
## seuils de recompense qu'il a fallu recaler sur les durees reelles.
## Nouveaux seuils -> paliers a 30 / 60 / 90 s, ou aux niveaux 3,25 / 5,5 / 7,75.
## ⚠️ Le bot n'est PAS un joueur : il meurt plus tot qu'un humain. On ne colle donc pas au
## ras de sa mediane — 90 s pour le dernier palier laisse de la marge a une vraie partie,
## tout en le rendant atteignable au lieu de decoratif.
const IQ_TEMPS: float = 120.0   # secondes pour atteindre l'intelligence maximale
const IQ_NIVEAU: float = 9.0    # ... ou niveau du joueur qui y mene, au plus rapide des deux
const IQ_FLANC_T: float = 24.0  # ouverture de l'encerclement
const IQ_PATIENCE_T: float = 48.0
const IQ_OPPORTUNISME_T: float = 74.0
const FLANC_MAX: float = 1.15   # ecart d'angle maximal (rad) sur l'approche
var _flanc: float = 0.0         # angle d'approche propre a CET ennemi (stable toute sa vie)
var _allies: int = 0            # semblables proches, estime pendant le balayage d'evitement
var _hesite: float = 0.0        # minuterie de patience

## ====================== L'ARME DE L'ENNEMI, ET SES PALIERS =============================
## 🚨 CONSIGNE PATRON : « jamais plusieurs armes en meme temps pour un ennemi, plutot UNE arme
## qui a evolue a mesure que son intelligence a evolue, avec un effet d'arme specifique
## different visuellement a chaque evolution. »
## Un ennemi n'a donc jamais deux armes : il a LA SIENNE, et elle franchit quatre paliers,
## indexes sur le MEME indice d'intelligence que son comportement. Monter en palier change a
## la fois ce que l'arme fait ET a quoi elle ressemble — couleur, effet de bouche, silhouette
## du projectile. Le joueur doit pouvoir dire « celui-la a evolue » d'un coup d'oeil.
##
##   TIREURS (behavior = ranged) — leur arme est le canon :
##     0 CANON        1 obus, teinte de base                        (lent, lisible)
##     1 SURCHAUFFE   1 obus plus gros et plus rapide, blanc-ambre
##     2 GERBE        3 obus en eventail, orange                    (une arme, un tir groupe)
##     3 TRAQUEUR     3 obus CHERCHEURS, magenta                    (il faut casser la ligne)
##
##   CONTACTS (rush / dasher) — leur arme est la frappe :
##     0 CONTACT      degats au contact seulement
##     1 PERCUSSION   le contact produit une onde visible
##     2 ARC          frappe d'arc TELEGRAPHIEE a ~95 px : il touche sans etre colle
##     3 ARC LARGE    arc plus ouvert et plus rapide
##
## La montee de palier declenche un eclat unique sur l'ennemi (voir _annonce_palier) : c'est
## ce qui rend l'evolution VISIBLE au lieu d'etre une statistique invisible.
const ARME_COUL: Array[Color] = [
	Color(1.00, 0.55, 0.25),   # 0 — teinte de base, ambre
	Color(1.00, 0.88, 0.62),   # 1 — blanc-ambre surchauffe
	Color(1.00, 0.52, 0.12),   # 2 — orange franc
	Color(1.00, 0.30, 0.85),   # 3 — magenta traqueur
]
const ARME_MUZZLE: Array[String] = ["dp_muzzle", "aaa_muzzle", "fire_blast", "aaa_charge"]
const ARME_NOM: Array[String] = ["CANON", "SURCHAUFFE", "GERBE", "TRAQUEUR"]
var _palier: int = 0            # palier d'arme courant
var _palier_vu: int = 0         # dernier palier annonce (pour n'eclater qu'une fois)
static var _palier_max_run: int = 0   # plus haut palier VU dans la partie (trace de banc)
var _arc_cd: float = 0.0        # recharge de la frappe d'arc (contacts, palier >= 2)
var _arc_tel: float = 0.0       # telegraphe de l'arc en cours
var _arc_dir: Vector2 = Vector2.RIGHT   # direction VERROUILLEE a l'armement (cf. _arme_contact)

## Palier d'arme, derive du MEME indice que l'intelligence : l'arme evolue avec l'ennemi.
static var _palier_force: int = -1     # -1 = normal ; 0..3 = fige par `-- --arme=N` (banc)
func _arme_palier() -> int:
	if _palier_force >= 0:
		return _palier_force
	var q: float = _iq()
	if q >= 0.75: return 3
	if q >= 0.50: return 2
	if q >= 0.25: return 1
	return 0

## Eclat unique quand l'arme franchit un palier : l'evolution doit se VOIR.
func _annonce_palier() -> void:
	if game == null or not game.has_method("spawn_vfx"):
		return
	var c: Color = ARME_COUL[_palier]
	game.spawn_vfx("aaa_shockwave", global_position, 0.0, 0.34 + 0.08 * _palier, c)
	game.spawn_vfx(ARME_MUZZLE[_palier], global_position, 0.0, 0.30, c)

## Indice d'intelligence courant, 0 a 1. Le plus avance du temps ecoule et du niveau joueur.
func _iq() -> float:
	var t: float = GameState.run_time / IQ_TEMPS
	var n: float = float(GameState.level - 1) / IQ_NIVEAU
	return clampf(maxf(t, n), 0.0, 1.0)

const _SEP_SCAN: int = 26      # entrees examinees par image (cout borne, meme a 220 ennemis)
const _SEP_MAX: int = 8        # voisins REELLEMENT proches retenus
var _sep_vec: Vector2 = Vector2.ZERO
var _sep_tick: int = 0
var _sep_cursor: int = 0       # curseur tournant : sur quelques images, tout le voisinage est vu
const _WANDER_STR: float = 9.0

# Dasher phases
const _PH_DASH_WIND: int = 0
const _PH_DASH_ACTIVE: int = 1
const _PH_DASH_COOLDOWN: int = 2


func setup(k: String, def: Dictionary, plr: Node2D, g: Node) -> void:
	kind = k
	# A def may borrow another kind's baked sheets ('chassis'), so a new enemy can be defined
	# without re-rendering art. Defaults to the kind itself.
	chassis = String(def.get("chassis", k))
	player = plr
	game = g
	hp = float(def.get("hp", 20.0))
	hp_max = hp
	speed = float(def.get("speed", 90.0))
	contact_dmg = float(def.get("dmg", 8.0))
	rank = int(def.get("rank", 0))
	is_final = bool(def.get("final", false))
	# COLOSSES protocole: scale non-boss foes bigger — VISUAL *and* HITBOX together so a giant that
	# looks huge also HITS huge (coherent). Bosses (rank>=2) are exempt so they never fill the screen.
	var pscale: float = Protocols.enemy_scale if rank < 2 else 1.0
	
	behavior = String(def.get("behavior", "rush"))
	# angle d'approche propre : stable toute la vie de l'ennemi, sinon il zigzaguerait
	_flanc = randf_range(-1.0, 1.0)
	attack_dmg = float(def.get("attack_dmg", 0.0))
	attack_cd = float(def.get("attack_cd", 1.0))
	prefer_dist = float(def.get("prefer_dist", 340.0))
	heavy = bool(def.get("heavy", false))
	ogive = bool(def.get("ogive", false))
	barrage = bool(def.get("barrage", false))
	aim_rate = float(def.get("aim_rate", 4.0))
	aim_lead = float(def.get("aim_lead", 0.0))
	garde = bool(def.get("garde", false))
	garde_cd = float(def.get("garde_cd", 9.0))
	tir_style = String(def.get("tir_style", ""))
	zigzag = float(def.get("zigzag", 0.0))
	protecteur = bool(def.get("protecteur", false))
	zone_shift = bool(def.get("zone_shift", true))
	_prot_cd = randf_range(0.0, 0.5)
	esquive = bool(def.get("esquive", false))
	_esq_cd = randf_range(1.0, 3.0)
	_garde_cd_t = randf_range(2.0, 6.0)
	# charge de taureau : ON par defaut pour les ennemis de MELEE de base (rush, rank 0), sinon opt-in def
	bull = bool(def.get("bull", behavior == "rush" and int(def.get("rank", 0)) == 0))
	_bull_cd = randf_range(1.5, 3.5)   # staggered : pas de charge groupee au meme instant
	shield_max = float(def.get("shield", 0.0))
	shield = shield_max
	_body_radius = float(def.get("radius", 24.0)) * pscale
	_bolt_color = _kind_bolt_color(chassis)   # bolt color suit le chassis (reuse), pas la cle
	if heavy:
		_bolt_color = Color(0.32, 0.86, 0.96)   # teal = accent du canon lourd
	if ogive:
		_bolt_color = Color(1.0, 0.72, 0.2)     # or/orange = ogives du boss
	drops_bonus = bool(def.get("drops_bonus", false))
	_proc = bool(def.get("proc", false))
	_proc_hover = _proc and String(def.get("motion", "")) == "hover"

	_speed_mult = randf_range(0.85, 1.15)
	_wander_phase = randf() * TAU
	velocity = Vector2.ZERO
	
	_atk_cd = attack_cd
	_phase = _PH_DASH_WIND
	_phase_timer = 0.5   # so the dasher's FIRST dash also telegraphs (wind-up/flash) instead of firing raw
	_strafe_dir = 1.0 if randf() > 0.5 else -1.0
	
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	
	var cs: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = float(def.get("radius", 24.0)) * pscale
	cs.shape = c
	add_child(cs)

	_spr = Sprite2D.new()
	_spr.centered = true
	
	var motion: String = String(def.get("motion", ""))
	
	# Auto-discover animation sheets: directional 4-view (<kind>_<anim>_<dir>.png)
	# if present, else the single front-only sheet (<kind>_<anim>.png).
	var names_to_check: Array[String] = ["idle", "walk", "run", "attack", "hit", "die"]
	if motion != "":
		names_to_check.append(motion)
	for anim_name: String in names_to_check:
		if _anims.has(anim_name):
			continue
		var cache_key: String = "%s|%s" % [chassis, anim_name]
		var a: Variant
		if Enemy._anim_cache.has(cache_key):
			a = Enemy._anim_cache[cache_key]
		else:
			a = _load_anim(anim_name)
			Enemy._anim_cache[cache_key] = a
		if a != null:
			_anims[anim_name] = a
			if a is Dictionary:
				_directional = true

	if _anims.is_empty():
		# Fallback to default single sprite
		var tex: Texture2D = Tex.get_tex("res://assets/enemies/%s.png" % chassis, Palette.STEEL_DK, 160)
		_anims["idle"] = tex
		
	# Determine loop anims
	if _anims.has("walk"):
		_base_loop = "walk"
	elif _anims.has(motion):
		_base_loop = motion
	else:
		_base_loop = _anims.keys()[0]
		
	if _anims.has("idle"):
		_idle_anim = "idle"
	else:
		_idle_anim = _base_loop
		
	play(_base_loop, false)
	
	# Visual size bumped 1.28x (patron: mecha + enemies read too small). The `radius` hitbox is
	# UNCHANGED, so this is purely cosmetic and collisions stay exactly as fair as before.
	var vsize: float = float(def.get("size", 92.0)) * 1.28 * pscale
	var fh: float = float(_spr.texture.get_height())
	if fh > 0.0:
		_spr.scale = Vector2.ONE * (vsize / fh)
	_proc_base_pos = _spr.position
	_proc_base_scale = _spr.scale
	# CORRUPTION du biome: teinte la carcasse (self_modulate = ce sprite seul, pas les enfants).
	if game != null and "spawner" in game and game.spawner != null:
		_spr.self_modulate = game.spawner.enemy_tint

	# Shadows: ONLY flyers keep one (drone/eyedrone, motion "hover") — the offset shadow below them
	# reads as "airborne". Walkers get NO shadow (patron: the ground shadow on 3/4 walker art looked
	# pasted/floating no matter where we placed it, so it's cleaner without).
	var gsize: float = vsize
	if motion == "hover":
		var shadow: Sprite2D = Sprite2D.new()
		shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
		shadow.modulate = Color(0, 0, 0, 0.22)
		shadow.position = Vector2(0.0, gsize * 0.30)
		shadow.scale = Vector2(gsize / 64.0 * 0.5, gsize / 64.0 * 0.2)
		shadow.z_index = -1
		add_child(shadow)

	# Single-frame (proc/premium) sprites get the legibility shader (bright outline + shadow-lift so
	# dark hard-surface bodies read on busy terrain); multi-frame bosses keep the plain flash shader
	# (an outline would bleed across the 8 frames packed in one texture).
	# Legibility shader (bright outline + shadow-lift) for ALL enemies. Its 8-tap outline test only
	# fires on transparent pixels hugging the body; frames are packed with transparent margins, so it
	# is safe on multi-frame strips too (no cross-frame bleed in practice).
	_mat = ShaderMaterial.new()
	var read_path: String = "res://shaders/enemy_read.gdshader"
	if ResourceLoader.exists(read_path):
		_mat.shader = load(read_path)
		_spr.material = _mat
	elif ResourceLoader.exists("res://shaders/hit_flash.gdshader"):
		_mat.shader = load("res://shaders/hit_flash.gdshader")
		_spr.material = _mat
	add_child(_spr)

	# 🚨 25/09 : ce noeud etait cree ICI, pour CHAQUE ennemi (jusqu'a 220 en simultane), avec son
	# propre _process() tournant a chaque frame meme pour les ~99% jamais touches par Bruiser —
	# "lag meme avec peu d'ennemis" signale par le patron. Deplace en creation PARESSEUSE dans
	# take_damage() : n'existe que pour un ennemi qui recoit reellement une pile.

	# energy shield BUBBLE that ENVELOPS the whole body (a soft filled aura + crisp rim),
	# sized to the VISUAL sprite (vsize) so it wraps the mech, not a small ring in front.
	if shield_max > 0.0:
		# ELLIPSE ajustee au mecha selon les reglages patron (editeur), par porteur.
		var st: Dictionary = _shield_assets()
		var stex: Texture2D = st["tex"]
		_shield_tint = st["tint"]
		_shield_backA = float(st["backA"]); _shield_frontA = float(st["frontA"])
		_shield_bright = float(st.get("bright", 1.0))
		var tw: float = maxf(1.0, float(stex.get_width()))
		var sh_w: float = vsize * float(st["w"])
		var sh_h: float = vsize * float(st["h"])
		var spos: Vector2 = Vector2(vsize * float(st.get("ox", 0.0)), vsize * float(st["oy"])) + _visual_offset()   # centre sur le CORPS, pas sur l'origine du cadre
		var srot: float = deg_to_rad(float(st.get("rot", 0.0)))   # rotation de base (puis tourne)
		var gap: float = float(st["gap"])
		# couche FOND (pulse quand ca encaisse)
		_shield_spr = Sprite2D.new()
		_shield_spr.texture = stex
		var add_mat: CanvasItemMaterial = CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shield_spr.material = add_mat
		_shield_spr.scale = Vector2(sh_w / tw, sh_h / tw)
		_shield_spr.position = spos
		_shield_spr.rotation = srot
		_shield_spr.z_index = 3
		add_child(_shield_spr)
		# couche AVANT (membrane) qui TOURNE lentement, un peu plus grande (ecart = gap)
		_shield_rim = Sprite2D.new()
		_shield_rim.texture = stex
		var add_mat2: CanvasItemMaterial = CanvasItemMaterial.new()
		add_mat2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shield_rim.material = add_mat2
		_shield_rim.scale = Vector2(sh_w / tw, sh_h / tw) * gap
		_shield_rim.position = spos
		_shield_rim.rotation = srot
		_shield_rim.z_index = 3
		add_child(_shield_rim)

	# bosses (rank >= 3) get a floating health bar so the player sees the fight's progress
	if rank >= 3:
		_hp_bar_w = vsize * 1.1
		_hp_bar_y = -vsize * 0.62
		_hp_bg = Line2D.new()
		_hp_bg.width = 9.0
		_hp_bg.default_color = Color(0.0, 0.0, 0.0, 0.65)
		_hp_bg.points = PackedVector2Array([Vector2(-_hp_bar_w * 0.5, _hp_bar_y), Vector2(_hp_bar_w * 0.5, _hp_bar_y)])
		_hp_bg.z_index = 5
		add_child(_hp_bg)
		_hp_fill = Line2D.new()
		_hp_fill.width = 6.0
		_hp_fill.default_color = Color(1.0, 0.28, 0.22)
		_hp_fill.points = _hp_bg.points
		_hp_fill.z_index = 6
		add_child(_hp_fill)

	if def.has("tint"):
		_tier_tint = def["tint"]
		_spr.self_modulate = def["tint"]          # hierarchie Mark 2 / intermediaire / mini-boss / boss
	if protecteur:
		_spr.self_modulate = Color(0.6, 1.25, 1.05)   # teal : reconnaissable, a tuer en premier
	if garde:
		_garde_dome = GardeDome.new()
		_garde_dome.radius = _body_radius * 1.55
		_garde_dome.z_index = 4
		_garde_dome.position = _visual_offset()
		_garde_dome.visible = false
		add_child(_garde_dome)
	if grade != "":
		_update_rank_badge()


func _update_rank_badge() -> void:
	if grade == "" or grade == "soldat":
		if _rank_badge != null:
			_rank_badge.visible = false
		return
	if _rank_badge == null:
		_rank_badge = RankBadge.new()
		_rank_badge.position = Vector2(0, -_body_radius * 1.5 - 14.0)
		_rank_badge.z_index = 6
		add_child(_rank_badge)
	_rank_badge.grade_type = grade
	_rank_badge.visible = true
	_rank_badge.queue_redraw()


## Fraction (0..1 of texture height) of the LOWEST opaque row in frame 0 = where the feet are.
## Cached per texture path (computed once per kind). Used to sit the ground shadow at the feet.
static var _feet_cache: Dictionary = {}
func _feet_frac_of(tex: Texture2D) -> float:
	if tex == null:
		return 0.65
	var key: String = tex.resource_path
	if key != "" and _feet_cache.has(key):
		return _feet_cache[key]
	var ff: float = 0.65
	var img: Image = tex.get_image()
	if img != null:
		var tw: int = img.get_width()
		var th: int = img.get_height()
		var frames: int = 8 if tw >= th * 4 else 1   # 8-frame strips vs single-frame statics
		var fw: int = int(tw / maxi(1, frames))
		var y: int = th - 1
		while y >= 0:
			var x: int = 0
			var hit: bool = false
			while x < fw:
				if img.get_pixel(x, y).a > 0.08:
					hit = true
					break
				x += 3
			if hit:
				ff = float(y) / float(th)
				break
			y -= 1
	if key != "":
		_feet_cache[key] = ff
	return ff

func _kind_bolt_color(k: String) -> Color:
	# Readability rule: WARM = enemy/danger (cold hues are reserved for the player).
	match k:
		"drone": return Color(1.0, 0.6, 0.2)       # orange
		"warden": return Color(1.0, 0.28, 0.22)    # red
		"eyedrone": return Color(1.0, 0.35, 0.15)  # hot red eye-beam
		_: return Color(1.0, 0.5, 0.2)             # orange


func _load_anim(anim_name: String) -> Variant:
	# 4-view directional sheets take priority; fall back to a single front sheet.
	var dirs: Dictionary = {}
	for d: String in _DIRS:
		var p: String = "res://assets/enemies/%s_%s_%s.png" % [chassis, anim_name, d]
		if ResourceLoader.exists(p):
			var r: Variant = load(p)
			if r is Texture2D:
				dirs[d] = r
	if dirs.size() == _DIRS.size():
		for dg: String in _DIAGS:   # diagonales (optionnelles) : si presentes, le sprite regarde dans 8 directions
			var pd: String = "res://assets/enemies/%s_%s_%s.png" % [chassis, anim_name, dg]
			if ResourceLoader.exists(pd):
				var rd: Variant = load(pd)
				if rd is Texture2D:
					dirs[dg] = rd
		return dirs
	var sp: String = "res://assets/enemies/%s_%s.png" % [chassis, anim_name]
	if ResourceLoader.exists(sp):
		var r2: Variant = load(sp)
		if r2 is Texture2D:
			return r2
	return null


func _current_tex() -> Texture2D:
	var a: Variant = _anims.get(_cur_anim)
	if a is Dictionary:
		return a.get(_dir, a.get("front"))
	return a


func play(name: String, one_shot: bool = false) -> void:
	if not _anims.has(name) or _cur_anim == name:
		return
	_cur_anim = name
	_spr.texture = _current_tex()
	# Frame count is aspect-driven: a WIDE strip (tw >= 4x th) is an 8-frame sheet (old Quaternius art);
	# a square texture is a single-frame STATIC (premium models) animated live by the _proc branch.
	# (Previously hardcoded to 8, which sliced premium sheets into eighths and left _proc dead.)
	_frames = _frames_for(_spr.texture)
	_spr.hframes = _frames
	_spr.frame = 0
	_t = 0.0
	_one_shot = one_shot
	_anim_done = false


func _frames_for(t: Texture2D) -> int:
	# 17/10 : nombre d'images = largeur / hauteur (cellules carrees) -> accepte 5, 6 ou 8 images par planche
	if t != null and t.get_height() > 0 and t.get_width() >= t.get_height() * 3:
		return maxi(1, int(round(float(t.get_width()) / float(t.get_height()))))
	return 1


## Canon lourd : 2 gros bolts LENTS (perçants visuellement) tirés des 2 barillets,
## + flash de bouche + secousse. dir = vers le joueur au moment du tir.
## ====================== L'ARME DU TIREUR, PAR PALIER ==================================
## UNE arme, quatre etats. Le melange vers la teinte de palier est progressif : au palier 0 le
## tir garde la couleur du chassis (identite), aux paliers hauts la couleur de PALIER domine
## (lisibilite du danger). Les gerbes tirent MOINS VITE et chaque obus fait MOINS mal : trois
## obus plein pot a bout portant tueraient sans que le joueur ait vu quoi que ce soit.
const ARME_MELANGE: Array[float] = [0.00, 0.55, 0.78, 0.92]
const ARME_CADENCE: Array[float] = [1.00, 0.88, 1.06, 1.16]   # >1 = plus lent : l'arme s'alourdit
const ARME_TAILLE: Array[float]  = [1.00, 1.32, 1.14, 1.26]
const ARME_VITESSE: Array[float] = [300.0, 385.0, 340.0, 300.0]
const ARME_NB: Array[int]        = [1, 1, 3, 3]
const ARME_ECART: Array[float]   = [0.0, 0.0, 0.225, 0.275]   # demi-angle de la gerbe (rad)
const ARME_PART: Array[float]    = [1.00, 1.00, 0.70, 0.66]   # degats PAR obus
const ARME_GUIDAGE: Array[float] = [0.0, 0.0, 0.0, 2.15]      # rad/s, palier 3 seulement
## Le canon lourd corrige plus TOT mais plus DOUCEMENT : un gros missile qui vire sec serait
## illisible. Il oblige a se decaler tot, il ne colle pas aux talons.
const HEAVY_GUIDAGE: Array[float] = [0.0, 0.0, 0.85, 1.45]
const HEAVY_CHARGE: Array[float] = [0.50, 0.46, 0.42, 0.38]   # telegraphe du canon lourd

func _teinte_arme() -> Color:
	return _bolt_color.lerp(ARME_COUL[_palier], ARME_MELANGE[_palier])

func _tire_arme(dir: Vector2) -> void:
	if game == null or not game.has_method("spawn_enemy_bolt"):
		return
	var t: int = _palier
	var c: Color = _teinte_arme()
	var n: int = ARME_NB[t]
	var demi: float = ARME_ECART[t]
	var muzzle: Vector2 = global_position + dir * 22.0
	for i in range(n):
		# eventail centre : pour n=1 l'ecart vaut 0, pour n=3 on obtient -demi, 0, +demi.
		var a: float = 0.0 if n == 1 else (-demi + 2.0 * demi * float(i) / float(n - 1))
		game.spawn_enemy_bolt(muzzle, dir.rotated(a), attack_dmg * ARME_PART[t], c,
			ARME_TAILLE[t], ARME_VITESSE[t], false, ARME_GUIDAGE[t], "bolt:" + kind)
	if game.has_method("spawn_vfx") and Enemy._fx_ok():
		# effet de bouche PROPRE A CHAQUE PALIER : c'est le tell instantane du danger.
		game.spawn_vfx(ARME_MUZZLE[t], muzzle, dir.angle(), 0.42 + 0.16 * float(t), c)
		if t >= 2:
			# la gerbe souffle : un anneau au canon, qui s'ouvre avec le palier.
			game.spawn_vfx("aaa_shockwave", muzzle, 0.0, 0.16 + 0.07 * float(t), c)
	play("attack", true)

## ====================== L'ARME DU CONTACT, PAR PALIER =================================
## Meme regle : un seul moyen de blesser, qui grandit. Aux paliers 0-1 il faut etre COLLE ;
## a partir du palier 2 l'arme a de l'ALLONGE (~96 px) et se telegraphie avant de partir, ce
## qui rend la meute dangereuse sans la rendre injuste. Retour a zero a la mort (_die).
## 🚨 MESURE, n=8 par palier, biome et difficulte constants. Premier reglage : survie a 60 s
## = 6/8 au palier 0, 5/8 au palier 1, puis 2/8 au palier 2. Pas un crescendo : un MUR.
## Deux causes, toutes deux structurelles et pas une question de valeurs :
##  1. Les tireurs ne pesent que 1,6 % de la population au depart et ~11 % ensuite. Mes
##     paliers 0 et 1 ne touchaient QUE leur arme : pour 80 % des ennemis (les « rush »),
##     le palier 1 n'etait qu'un effet visuel. D'ou deux marches plates puis une falaise.
##  2. Rien ne bornait le nombre d'arcs SIMULTANES. Une vingtaine de cones de 96 px autour
##     du joueur couvrent tous les angles de fuite : le telegraphe devient decoratif, parce
##     qu'il n'existe plus de direction sure a lire. Un tell n'est lisible que s'il reste
##     une sortie.
## Correctifs : allonge plus courte, frappes plus rares, telegraphe plus long, AUCUN bonus
## de degats (la valeur de l'arme est son ALLONGE, pas sa frappe), plafond d'arcs simultanes,
## et une vraie marche mecanique au palier 1 pour les contacts (cf. CONTACT_PORTEE).
const ARC_PORTEE: float = 84.0
const ARC_ANGLE: float = 0.80          # demi-ouverture du cone touche (rad) ~ 46 deg
const ARC_TEL: Array[float] = [0.0, 0.0, 0.42, 0.34]    # duree du telegraphe
const ARC_CD: Array[float] = [0.0, 0.0, 2.80, 2.20]
## Plafond d'arcs simultanes — meme logique que BULL_CAP pour les charges. Au-dela, l'ennemi
## reste au contact simple : il faut qu'il existe toujours une direction ou fuir.
const ARC_CAP: int = 3
static var _arcs_armes: int = 0
static var _arcs_pic: int = 0     # plus haut nombre d'arcs simultanes vu dans la partie
var _arc_compte: bool = false          # cet ennemi occupe-t-il un slot d'arc ?

## L'arme de contact gagne aussi au palier 1, et MECANIQUEMENT : un peu d'allonge et une
## cadence un peu plus vive. Sans ca, 80 % des ennemis ne changeaient pas du tout entre le
## palier 0 et le palier 1 — le crescendo n'existait que pour une poignee de tireurs.
## 🚨 LEVIER LE PLUS SENSIBLE DU JEU. Premier essai a [44, 52, 52, 56] / [0.50, 0.44, ...] :
## la mediane de survie est tombee de 66 s a 37 s entre le palier 0 et le palier 1. Une
## allonge de +18 % sur 80 % de la population ne coute pas +18 % : a foule dense, quelques
## pixels de plus font entrer BEAUCOUP plus d'ennemis dans la zone de frappe au meme instant.
## Rampe divisee par trois.
const CONTACT_PORTEE: Array[float] = [44.0, 46.0, 48.0, 50.0]
const CONTACT_CAD: Array[float] = [0.500, 0.485, 0.470, 0.455]

## LE FONCEUR a deja son arme unique : la CHARGE. On ne lui colle donc PAS d'arc en plus
## (ce serait deux armes) — c'est la charge elle-meme qui monte en palier : elle s'arme plus
## vite et frappe avec un impact de plus en plus gros. ARC_* ne le concerne pas.
const DASH_ARMEMENT: Array[float] = [0.50, 0.46, 0.42, 0.38]   # duree du telegraphe par palier
const DASH_POUSSEE: Array[float] = [2.60, 2.75, 2.95, 3.15]    # vitesse de la ruee

## ====================== L'ARME DU « BULL » : SA CHARGE ================================
## 🚨 MESURE QUI A REFUTE MON EXPLICATION. J'avais attribue le mur du palier 2 a une nuee
## d'arcs simultanes, et ajoute un plafond. La trace `[game] ARCS pic=` a rendu **0** : l'arc
## ne part JAMAIS. Cause : `bull` vaut vrai par defaut pour tout « rush » de rang 0, soit
## 87 % de la population au depart et 69 % ensuite ; les « rush simples », seuls eligibles a
## l'arc, pesent 0 % avant 120 s et 4,3 % apres. Le plafond n'a donc rien explique.
## La VRAIE cause du mur : le telegraphe de charge des bulls tombait de 0,42 s a 0,30 s au
## palier 2 — un tell raccourci de 28 % pour 87 % des ennemis. Un tell plus court n'est pas
## « un peu plus dur » : en dessous du temps de reaction, il cesse d'etre un tell.
## D'ou une rampe plus douce ici (-19 % du palier 0 au palier 3 au lieu de -28 % des le 2),
## et une charge qui gagne aussi en VITESSE et en COULEUR pour que l'evolution se voie.
const BULL_ARMEMENT: Array[float] = [0.42, 0.40, 0.37, 0.34]
const BULL_VITESSE: Array[float] = [4.80, 5.00, 5.30, 5.60]

## Impact de la charge, par palier : la meme arme, de plus en plus lourde a encaisser.
func _impact_charge(dir: Vector2) -> void:
	if game == null or not game.has_method("spawn_vfx"):
		return
	var c: Color = _teinte_arme()
	var o: Vector2 = global_position + dir * 26.0
	match _palier:
		0: game.spawn_vfx("impact", o, dir.angle(), 0.70, c)
		1: game.spawn_vfx("aaa_shockwave", o, 0.0, 0.34, c)
		2:
			game.spawn_vfx("dp_blast", o, dir.angle(), 0.80, c)
			game.spawn_vfx("aaa_shockwave", o, 0.0, 0.42, c)
		_:
			game.spawn_vfx("aaa_impact", o, dir.angle(), 0.95, c)
			game.spawn_vfx("aaa_shockwave", o, 0.0, 0.55, c)

## Onde de percussion au corps a corps (palier >= 1) : le coup se VOIT partir.
func _percussion(dir: Vector2) -> void:
	if game == null or not game.has_method("spawn_vfx"):
		return
	var c: Color = _teinte_arme()
	# planche AAA et pas `shockwave` : mesure faite sur les feuilles, `shockwave` plafonne a
	# une luminance moyenne de 77 contre 255 pour `aaa_shockwave` — a 0,26 d'echelle la version
	# pale ne se verrait tout simplement pas sur le sol.
	game.spawn_vfx("aaa_shockwave", global_position + dir * 20.0, 0.0, 0.26 + 0.05 * float(_palier), c)

## Frappe d'arc a distance courte, paliers 2 et 3. Cible UNIQUE (le joueur) : un cone teste
## contre un seul point, donc cout nul meme a 40 ennemis a l'ecran.
func _arme_contact(delta: float, dist: float, dir: Vector2) -> void:
	# 🚨 UN SEUL ARMEMENT PAR CORPS. Le « bull » (celui qui se cabre puis charge) a deja SON
	# arme : la charge. Lui ajouter l'arc lui donnerait deux armes — et surtout DEUX
	# telegraphes rouges qui se disputent le meme uniforme `warn`, donc un tell illisible.
	# Sa charge monte en palier de son cote (voir DASH_ARMEMENT / _impact_charge).
	if bull or _palier < 2 or player == null or not is_instance_valid(player):
		_arc_tel = 0.0
		_libere_arc()
		return
	if _arc_tel > 0.0:
		_arc_tel -= delta
		# le corps vire au rouge pendant l'armement : meme langage que la charge du bull.
		if _mat != null and _mat.shader != null:
			_mat.set_shader_parameter("warn", 0.45 + 0.55 * absf(sin(float(Time.get_ticks_msec()) / 40.0)))
		if _arc_tel <= 0.0:
			if _mat != null and _mat.shader != null:
				_mat.set_shader_parameter("warn", 0.0)
			_frappe_arc(_arc_dir)
		return
	_arc_cd -= delta
	if _arc_cd <= 0.0 and dist < ARC_PORTEE and Enemy._arcs_armes < ARC_CAP:
		_arc_cd = ARC_CD[_palier]
		_arc_tel = ARC_TEL[_palier]
		_arc_compte = true
		Enemy._arcs_armes += 1
		# TRACE DE BANC : sans elle je ne peux pas distinguer « le plafond protege » de
		# « le plafond n'est jamais atteint, donc il n'explique rien ».
		if Enemy._arcs_armes > Enemy._arcs_pic:
			Enemy._arcs_pic = Enemy._arcs_armes
		# 🚨 DIRECTION VERROUILLEE ICI, pas a l'impact. Si on la recalculait au moment de la
		# frappe, le cone suivrait le joueur : le test d'angle comparerait la direction a
		# elle-meme (ecart toujours nul) et l'arc serait INESQUIVABLE lateralement — le
		# telegraphe ne donnerait aucune information exploitable. Verrouillee, se decaler
		# pendant les 0,34 s d'armement fait sortir du cone. C'est ce qui le rend juste.
		_arc_dir = dir

func _frappe_arc(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	var vers: Vector2 = player.global_position - global_position
	var d: float = vers.length()
	var c: Color = _teinte_arme()
	if game != null and game.has_method("spawn_vfx"):
		# Le balayage change de PLANCHE, pas seulement de taille : palier 2 = sabre sombre,
		# palier 3 = sabre AAA + onde AAA. Deux frappes qu'on ne confond pas de loin.
		if _palier >= 3:
			game.spawn_vfx("aaa_sabre", global_position + dir * 34.0, dir.angle(), 1.15, c)
			game.spawn_vfx("aaa_shockwave", global_position + dir * 34.0, 0.0, 0.42, c)
		else:
			game.spawn_vfx("dp_sabre", global_position + dir * 34.0, dir.angle(), 0.90, c)
			game.spawn_vfx("aaa_shockwave", global_position + dir * 34.0, 0.0, 0.30, c)
	# le cone ne touche que si le joueur est ENCORE dedans a la fin du telegraphe : reculer
	# ou passer derriere suffit a l'eviter. C'est ce qui rend l'allonge acceptable.
	if d < ARC_PORTEE + 14.0 and absf(angle_difference(dir.angle(), vers.angle())) < ARC_ANGLE:
		if player.has_method("take_damage"):
			# PAS de bonus de degats : ce que le palier apporte, c'est l'ALLONGE. Frapper plus
			# loin ET plus fort faisait deux ameliorations d'un coup — d'ou la falaise mesuree.
			player.take_damage(contact_dmg, global_position, "arc:" + kind)
	_libere_arc()
	play("attack", true)

## Rend le slot d'arc. Appele a la frappe, a la mort, et si le palier redevient inactif :
## un slot fuit = le plafond se referme tout seul et plus personne ne frappe.
func _libere_arc() -> void:
	if _arc_compte:
		_arc_compte = false
		Enemy._arcs_armes = maxi(0, Enemy._arcs_armes - 1)

func _fire_heavy(dir: Vector2) -> void:
	if game == null or not game.has_method("spawn_enemy_bolt"):
		return
	if ogive:
		_fire_ogive(dir)
		return
	# --- canon lourd (gunner) : UN seul gros missile (anti-saturation d'ecran) ---
	if EnemyProjectile._active_missiles >= EnemyProjectile.MISSILE_CAP:
		return   # ecran sature de missiles -> ce gunner ne tire pas ce round (anti-latence)
	# Le canon lourd EVOLUE lui aussi, et reste UN missile : il grossit, accelere, et au
	# dernier palier il CORRIGE sa course. Toujours une seule ogive en vol par tir — c'est
	# la condition pour qu'un missile reste lisible et esquivable au doigt.
	var t: int = _palier
	var c: Color = _teinte_arme()
	var muzzle: Vector2 = global_position + dir * 24.0
	game.spawn_enemy_bolt(muzzle, dir, attack_dmg, c,
		2.1 + 0.16 * float(t), 235.0 + 32.0 * float(t), true, HEAVY_GUIDAGE[t], "missile:" + kind)
	if game.has_method("spawn_vfx"):
		game.spawn_vfx(ARME_MUZZLE[t], muzzle, dir.angle(), 0.60 + 0.14 * float(t), c)
		if t >= 2:
			game.spawn_vfx("aaa_shockwave", muzzle, 0.0, 0.22 + 0.10 * float(t), c)
	if Events != null:
		Events.screen_shake.emit(1.2 + 0.18 * float(t))


## BOSS à ogives : lobe des ZONES AoE TELEGRAPHIEES au sol (facon Survivor.io). Le joueur voit
## le cercle rouge ~1s avant l'explosion et peut en sortir. 5-min = 1 grosse zone sur le joueur ;
## 10-min (barrage) = 3 zones autour du joueur, et un ANNEAU de 6 zones tous les 3 tirs.
const OGIVE_COL := Color(1.0, 0.42, 0.12)
func _fire_ogive(dir: Vector2) -> void:
	if not game.has_method("spawn_ground_zone"):
		return
	_boss_shot += 1
	var target: Vector2 = global_position + dir * 300.0
	if player != null and is_instance_valid(player):
		target = (player as Node2D).global_position
	if barrage and (_boss_frenzy or _boss_shot % 3 == 0):
		# ANNEAU : 6 zones en cercle autour du joueur (il faut trouver le trou). Phase 3
		# (_boss_frenzy) : a CHAQUE tir au lieu d'un sur 3, plutot que d'inventer un nouveau motif.
		for i in 6:
			var a: float = TAU * float(i) / 6.0 + randf() * 0.4
			game.spawn_ground_zone(target + Vector2.from_angle(a) * 150.0, 88.0, 1.05, attack_dmg * 0.85, OGIVE_COL)
	elif barrage:
		# 3 zones dispersees autour du joueur
		for k in 3:
			var off: Vector2 = Vector2(randf_range(-130.0, 130.0), randf_range(-130.0, 130.0))
			game.spawn_ground_zone(target + off, 96.0, 0.95, attack_dmg, OGIVE_COL)
	else:
		# 1 grosse zone pile sur le joueur
		game.spawn_ground_zone(target, 118.0, 1.0, attack_dmg, OGIVE_COL)
	# flash de tir a la bouche des ogives
	if game.has_method("spawn_vfx"):
		game.spawn_vfx("aaa_muzzle", global_position + dir * 30.0, dir.angle(), 0.75, _bolt_color)
	if Events != null:
		Events.screen_shake.emit(1.6)


## Avance _phase_idx d'au plus un cran par frame, seuils lus PAR `kind` (jamais une constante
## globale — deplacer le seuil de TOUS les boss rebalancerait silencieusement des combats deja
## livres/eprouves). La plomberie de signal (banniere/VFX/shake) est PARTAGEE ; le contenu de
## chaque phase (_apply_boss_phase) est sur mesure par boss.
func _check_boss_phase() -> void:
	if hp_max <= 0.0:
		return
	var thresholds: Array = EnemySpawner.BOSS_PHASE_THRESHOLDS.get(kind, [0.5])
	if _phase_idx >= thresholds.size():
		return
	if hp <= hp_max * float(thresholds[_phase_idx]):
		_phase_idx += 1
		if game != null:
			if game.has_method("show_banner"):
				show_banner_phase()
			if game.has_method("spawn_vfx"):
				game.spawn_vfx("shockwave", global_position, 0.0, _body_radius / 40.0, Color(1.0, 0.5, 0.35))
		Events.screen_shake.emit(5.0)
		_apply_boss_phase(_phase_idx)

func show_banner_phase() -> void:
	game.show_banner("PHASE %d" % (_phase_idx + 1), Color(1.0, 0.45, 0.35))

## Contenu SUR MESURE par boss — matche sur `kind`, jamais sur `chassis`/`behavior` (midboss_a et
## midboss_b partagent les deux et doivent pourtant rester differencies).
func _apply_boss_phase(idx: int) -> void:
	match kind:
		"midboss", "midboss_a", "midboss_b", "endboss":
			_phase_ranged_ogive(idx)
		"crusherboss":
			_phase_crusher(idx)
		"belier01":
			_phase_belier(idx)
		"cryoboss", "reacteurboss", "rucheboss", "citadelleboss":
			_phase_biome_boss(idx)
		_:
			pass   # tout futur rank>=3 sans config dediee : banniere seule, jamais de crash

## Colosse / Bombardier / Devastateur / Souverain : meme squelette de progression (deja motive
## par _fire_ogive, qui sait DEJA moduler son intensite via `barrage`), intensite differente par
## `kind`. Phase 2 = comportement d'origine INCHANGE (barrage + cadence -20%). Phase 3 = sursaut
## reel (cadence -40% de plus, anneau a CHAQUE tir via _boss_frenzy) — le Souverain (deja
## barrage:true des le debut) est donc le seul a ressentir la PLEINE differenciation phase2 vs
## phase1 des la phase 3 uniquement ; c'est voulu, il est cense etre le plus dur des quatre.
func _phase_ranged_ogive(idx: int) -> void:
	if idx == 1:
		barrage = true
		attack_cd = maxf(0.6, attack_cd * 0.8)
	elif idx == 2:
		_boss_frenzy = true
		attack_cd = maxf(0.4, attack_cd * 0.75)

## Broyeur Titan : pas de tir, pas de charge — chasse et degat de contact en continu (comme un
## ennemi "rush" normal, en plus gros). Phase 2 = plus rapide et plus dur au contact (« il
## s'enerve »). Phase 3 = en plus, laisse une trainee de GroundZone en chassant (modification de
## l'arene sans inventer un pattern d'attaque que ce boss n'a jamais eu).
func _phase_crusher(idx: int) -> void:
	if idx == 1:
		speed *= 1.2
		contact_dmg *= 1.15
	elif idx == 2:
		speed *= 1.15
		_boss_hazard_cd = 0.2   # amorce la trainee (voir _physics_process)

## Belier-01 : SANS bouclier par decision produit documentee ("le risque c'est la charge a
## esquiver, pas un palier de PV a ronger") — les 2 phases restent donc de la charge, jamais de
## bouclier. Phase 2 = tuning deja existant (cooldown court + windup rapide), simplement deplace
## de 50% a 66% comme demande. Phase 3 = charge DOUBLE (2 charges d'affilee sans repasser par
## COOLDOWN) + une GroundZone au point d'impact de chaque charge de cette phase.
func _phase_belier(idx: int) -> void:
	if idx == 2:
		_belier_burst_left = 1

## ====================== LES 4 BOSS DE CHAPITRE "15 MAPS" (cryo/reacteur/ruche/citadelle) =========
## Phases 1-2 = meme squelette ranged+ogive deja eprouve par Colosse/Bombardier/Devastateur/
## Souverain (_phase_ranged_ogive). Phase 3 = EN PLUS, une signature propre au biome de leur
## chapitre, qui reutilise un idiome deja prouve par le decor de CE biome (PropScatter.gd) plutot
## qu'un nouveau pattern d'attaque :
##   cryoboss      -> GroundZone a stun (idiome jet_de_cryo)
##   reacteurboss  -> pulse alterne degats/aucun degat (idiome zone_alternante)
##   rucheboss     -> aura continue de ralentissement (idiome sol_collant) ; PAS de GroundZone ici
##                    (son tie-in naturel, cocon -> awaken_enemy, est inerte tant que les ennemis
##                    reguliers restent vides - tradeoff documente, pas un oubli)
##   citadelleboss -> pulsion ponctuelle pousse/attire en alternance (idiome zone_push_pull)
const CRYO_HAZARD_CD: float = 2.3
const CRYO_HAZARD_R: float = 100.0
const CRYO_HAZARD_STUN: float = 1.1
const REACTEUR_HAZARD_CD: float = 1.8
const REACTEUR_HAZARD_R: float = 130.0
const RUCHE_AURA_R: float = 220.0
const RUCHE_AURA_MULT: float = 0.55
const RUCHE_VFX_CD: float = 2.0
const CITADELLE_PULSE_CD: float = 3.0
const CITADELLE_PULSE_R: float = 420.0
const CITADELLE_PULSE_FORCE: float = 260.0
func _phase_biome_boss(idx: int) -> void:
	_phase_ranged_ogive(idx)   # meme barrage (phase 2) / frenzy (phase 3) que les 4 boss existants
	if idx == 2:
		# amorce le pouls biome (voir le bloc _boss_hazard_cd dans _physics_process). Pour
		# rucheboss ce cooldown ne pilote qu'un ping VFX cosmetique (son effet reel, l'aura de
		# ralentissement, est CONTINU et gere separement plus bas dans _physics_process).
		_boss_hazard_cd = 0.2


func _physics_process(delta: float) -> void:
	if not alive:
		if _dying:
			_die_timer -= delta
			_advance_one_shot(delta)
			if _anim_done or _die_timer <= 0.0:
				queue_free()
		return
		
	var desired_vel: Vector2 = Vector2.ZERO
	var player_valid: bool = player != null and is_instance_valid(player) and GameState.alive
	
	_atk_cd -= delta
	if _atk_cd < 0.0:
		_atk_cd = 0.0
	if rank >= 3:
		_check_boss_phase()
	if player_valid and rank < 3 and _lod_far(delta):
		return
	if _prot_t > 0.0:
		_prot_t -= delta
	if protecteur:
		_protecteur_tick(delta)
	if garde:
		_garde_tick(delta, player_valid)
	if tir_style != "" or esquive:
		_style_tick(delta, player_valid)
	if player_valid and behavior == "ranged":
		_aim_tick(delta)
	if _boss_hazard_cd > 0.0:
		_boss_hazard_cd -= delta
		if _boss_hazard_cd <= 0.0 and game != null:
			match kind:
				"crusherboss":
					if game.has_method("spawn_ground_zone"):
						_boss_hazard_cd = 1.4
						game.spawn_ground_zone(global_position, 90.0, 0.9, contact_dmg * 0.7, Color(0.8, 0.2, 0.15))
				"cryoboss":
					# meme idiome que jet_de_cryo (PropScatter.gd) : GroundZone construite
					# directement car stun_duration n'est pas expose par game.spawn_ground_zone().
					_boss_hazard_cd = CRYO_HAZARD_CD
					if player != null and is_instance_valid(player) and "enemy_layer" in game:
						var zc: GroundZone = GroundZone.new()
						zc.radius = CRYO_HAZARD_R; zc.delay = 1.0; zc.damage = contact_dmg * 0.4
						zc.color = Color(0.6, 0.85, 1.0); zc.stun_duration = CRYO_HAZARD_STUN
						zc.game = game; zc.player = player
						zc.global_position = player.global_position
						game.enemy_layer.add_child(zc)
				"reacteurboss":
					# meme idiome que zone_alternante : alterne une zone qui degate ("chargee") et
					# une qui ne degate pas ("ventee"), via le spawn_ground_zone generique.
					_boss_hazard_cd = REACTEUR_HAZARD_CD
					_reacteur_pulse_on = not _reacteur_pulse_on
					if game.has_method("spawn_ground_zone"):
						var r_dmg: float = contact_dmg * 0.8 if _reacteur_pulse_on else 0.0
						var r_col: Color = Color(0.55, 1.0, 0.5) if _reacteur_pulse_on else Color(0.25, 0.45, 0.3)
						game.spawn_ground_zone(global_position, REACTEUR_HAZARD_R, 0.8, r_dmg, r_col)
				"rucheboss":
					# pas de GroundZone (cocon->awaken_enemy est inerte sans ennemis restaures) ;
					# juste le TELL visuel de l'aura continue geree plus bas (RUCHE_AURA_*).
					_boss_hazard_cd = RUCHE_VFX_CD
					if game.has_method("spawn_vfx") and player != null and is_instance_valid(player) \
							and global_position.distance_squared_to(player.global_position) < RUCHE_AURA_R * RUCHE_AURA_R:
						game.spawn_vfx("shockwave", global_position, 0.0, RUCHE_AURA_R / 95.0, Color(1.0, 0.75, 0.95))
				"citadelleboss":
					# meme math que zone_push_pull (PropScatter.gd) dupliquee ici (2 lignes, pas de
					# helper partage) mais en POULS ponctuel plutot qu'en nudge continu par frame.
					_boss_hazard_cd = CITADELLE_PULSE_CD
					_citadelle_push_out = not _citadelle_push_out
					if player != null and is_instance_valid(player):
						var away: Vector2 = player.global_position - global_position
						var dd: float = away.length()
						if dd > 1.0 and dd < CITADELLE_PULSE_R:
							player.global_position += away.normalized() * CITADELLE_PULSE_FORCE * (1.0 if _citadelle_push_out else -1.0)
							if game.has_method("spawn_vfx"):
								game.spawn_vfx("shockwave", global_position, 0.0, CITADELLE_PULSE_R / 95.0, Color(0.4, 0.85, 1.0))
				_:
					pass
	if _brisure_stacks > 0:
		_brisure_t -= delta
		if _brisure_t <= 0.0:
			_brisure_stacks -= 1                                    # une pile a la fois, pas tout d'un coup
			_brisure_t = BRISURE_STACK_DUR if _brisure_stacks > 0 else 0.0
			if _brisure_pips != null:
				_brisure_pips.count = _brisure_stacks
	# L'ARME EVOLUE AVEC L'INTELLIGENCE. Un seul point de verite : _palier est relu ici, et
	# toute montee declenche un eclat unique — l'evolution doit se voir a l'ecran, pas seulement
	# se subir. (_palier_vu ne redescend jamais : pas de clignotement en bordure de seuil.)
	_palier = _arme_palier()
	if _palier > _palier_vu:
		_palier_vu = _palier
		_annonce_palier()
		# TRACE DE BANC : premiere fois qu'un palier est atteint dans la partie. Sans ca je ne
		# peux pas distinguer « le palier 3 marche » de « le palier 3 n'a jamais ete joue ».
		if _palier > Enemy._palier_max_run:
			Enemy._palier_max_run = _palier
			print("[game] ARME palier=%d (%s) t=%ds lvl=%d" % [_palier, ARME_NOM[_palier],
				int(GameState.run_time), GameState.level])
		
	_contact_cd -= delta
	if _contact_cd < 0.0:
		_contact_cd = 0.0
		
	if player_valid:
		var to_player: Vector2 = player.global_position - global_position
		var dist_sq: float = to_player.length_squared()
		var dist: float = sqrt(dist_sq)

		# RUCHEBOSS phase 3 : aura CONTINUE de ralentissement tant que le joueur est a portee -
		# meme idiome que sol_collant (PropScatter.gd), independante du cooldown _boss_hazard_cd
		# (qui ne pilote que le ping VFX cosmetique de ce boss, voir plus haut).
		if kind == "rucheboss" and _phase_idx >= 2 and dist < RUCHE_AURA_R and "field_slow" in player:
			player.field_slow = minf(player.field_slow, RUCHE_AURA_MULT)

		if dist > 1.0:
			var dir: Vector2 = to_player / dist
			
			if behavior == "ranged":
				if _charging:
					desired_vel = Vector2.ZERO   # immobile pendant la charge (telegraph clair)
				else:
					var dist_margin: float = 40.0
					if dist > prefer_dist + dist_margin:
						desired_vel = dir * speed * _speed_mult
					elif dist < prefer_dist - dist_margin:
						desired_vel = -dir * speed * _speed_mult
					else:
						_strafe_timer -= delta
						if _strafe_timer <= 0.0:
							_strafe_dir *= -1.0
							_strafe_timer = randf_range(1.0, 2.5)
						var perp: Vector2 = Vector2(-dir.y, dir.x)
						desired_vel = perp * _strafe_dir * speed * _speed_mult * 0.75
					
			elif behavior == "dasher":
				_phase_timer -= delta
				if _phase == _PH_DASH_WIND:
					desired_vel = dir * speed * 0.1
					# CHARGE IMMINENTE : rouge PLEIN et clignotant, pas un flash blanc de plus.
					if _mat != null and _mat.shader != null:
						_mat.set_shader_parameter("warn",
							0.55 + 0.45 * absf(sin(float(Time.get_ticks_msec()) / 55.0)))
					if _phase_timer <= 0.0:
						_phase = _PH_DASH_ACTIVE
						_phase_timer = 0.45
						_dash_dir = dir
						_flash = 0.0
						if _mat != null and _mat.shader != null:
							_mat.set_shader_parameter("flash", 0.0)
							_mat.set_shader_parameter("warn", 0.0)
						# Un chassis avec un cycle "run" bake (brute/vanquisher) sprinte en boucle
						# pendant toute la charge (choisi par le dispatch mouvement plus bas) ; les
						# autres gardent le tell "attack" en un seul passage, comme avant.
						if not _anims.has("run"):
							play("attack", true)
				elif _phase == _PH_DASH_ACTIVE:
					desired_vel = _dash_dir * speed * DASH_POUSSEE[_palier]
					if dist < 44.0 and _contact_cd <= 0.0:
						_contact_cd = 0.5
						if player.has_method("take_damage"):
							# the charge lands the big hit (attack_dmg), not the light contact graze
							var charge_dmg: float = attack_dmg if attack_dmg > 0.0 else contact_dmg
							player.take_damage(charge_dmg, global_position, "charge:" + kind)
							_impact_charge(_dash_dir)
							# Phase 3 (BELIER-01) : chaque impact laisse une GroundZone — la charge
							# elle-meme modifie l'arene, sans nouveau pattern a lire pour le joueur.
							if _phase_idx >= 2 and game != null and game.has_method("spawn_ground_zone"):
								game.spawn_ground_zone(global_position, 80.0, 0.8, contact_dmg * 0.6, Color(1.0, 0.35, 0.15))

					if _phase_timer <= 0.0:
						if _belier_burst_left > 0:
							# Phase 3 : charge DOUBLE — repart directement en WIND (bref) sans repasser
							# par COOLDOWN, une seule fois par charge (pas une boucle infinie).
							_belier_burst_left -= 1
							_phase = _PH_DASH_WIND
							_phase_timer = 0.28
						else:
							_phase = _PH_DASH_COOLDOWN
							# Phase 2 (BELIER-01, "meme lecon, mais plus dense") : recupere plus vite ->
							# les charges s'enchainent, sans nouveau pattern a lire pour le joueur.
							_phase_timer = 0.7 if _phase_idx >= 1 else 1.2
							if _phase_idx >= 2:
								_belier_burst_left = 1   # arme la PROCHAINE charge pour un enchainement double
				elif _phase == _PH_DASH_COOLDOWN:
					desired_vel = dir * speed * 0.3
					if _phase_timer <= 0.0:
						_phase = _PH_DASH_WIND
						_phase_timer = DASH_ARMEMENT[_palier] * (0.7 if _phase_idx >= 1 else 1.0)

			elif behavior == "healer":
				# REPARATEUR : garde ses distances comme "ranged" (kite), soigne au lieu de tirer.
				# "Il doit devenir une cible prioritaire" — cf. le rayon vert, tres visible.
				var dm: float = 40.0
				if dist > prefer_dist + dm:
					desired_vel = dir * speed * _speed_mult
				elif dist < prefer_dist - dm:
					desired_vel = -dir * speed * _speed_mult
				else:
					desired_vel = Vector2.ZERO
				_heal_cd -= delta
				if _heal_cd <= 0.0:
					_heal_cd = HEAL_TICK
					var best: Enemy = null
					var best_missing: float = 0.0
					for e in _shared_enemies():
						if e == self or not (e is Enemy) or not (e as Enemy).alive:
							continue
						var en: Enemy = e as Enemy
						if global_position.distance_squared_to(en.global_position) > HEAL_RANGE * HEAL_RANGE:
							continue
						var missing: float = en.hp_max - en.hp
						if missing > best_missing:
							best_missing = missing
							best = en
					if best != null:
						best.hp = minf(best.hp_max, best.hp + best.hp_max * HEAL_FRACTION)
						if game != null and game.has_method("_streak"):
							var mid: Vector2 = (global_position + best.global_position) * 0.5
							game._streak(mid, (best.global_position - global_position).normalized(),
								Color(0.4, 1.0, 0.5), global_position.distance_to(best.global_position), 6.0, 0.22)

			elif behavior == "carrier":
				# PORTEUR : fuit — jamais vers le joueur. drops_bonus (deja sur sa fiche) recompense
				# la prise de risque de le poursuivre, cf. "choisir entre le poursuivre et rester en securite".
				desired_vel = -dir * speed * _speed_mult

			elif behavior == "pusher":
				# DISPERSEUR : n'attaque pas, repousse les ennemis proches a intervalle regulier —
				# "casse les strategies trop statiques" en dispersant la meute autour du joueur.
				desired_vel = Vector2.ZERO
				_push_cd -= delta
				if _push_cd <= 0.0:
					_push_cd = PUSH_INTERVAL
					for e in _shared_enemies():
						if e == self or not (e is Enemy):
							continue
						var en2: Enemy = e as Enemy
						var away: Vector2 = en2.global_position - global_position
						var alen: float = away.length()
						if alen > 1.0 and alen < PUSH_RANGE:
							en2.global_position += away / alen * PUSH_FORCE * 0.12
					if game != null and game.has_method("spawn_vfx"):
						game.spawn_vfx("shockwave", global_position, 0.0, PUSH_RANGE / 95.0, Color(0.85, 0.55, 1.0))

			elif behavior == "miner":
				# MINEUR : approche, pose une zone au sol telegraphiee (spawn_ground_zone existe
				# deja pour l'eruption volcanique), puis se tient a distance le temps du cooldown.
				if dist > MINE_RANGE + 20.0:
					desired_vel = dir * speed * _speed_mult
				else:
					# 21/10 (« les ennemis ont perdu leur mobilite ») : le mineur ne reste plus fige entre deux mines, il contourne le joueur
					_strafe_timer -= delta
					if _strafe_timer <= 0.0:
						_strafe_dir *= -1.0
						_strafe_timer = randf_range(1.2, 2.6)
					desired_vel = Vector2(-dir.y, dir.x) * _strafe_dir * speed * _speed_mult * 0.65
					_mine_cd -= delta
					if _mine_cd <= 0.0 and game != null and game.has_method("spawn_ground_zone"):
						_mine_cd = MINE_COOLDOWN
						var mine_dmg: float = attack_dmg if attack_dmg > 0.0 else contact_dmg * 1.8
						game.spawn_ground_zone(global_position, 110.0, 1.1, mine_dmg, Color(1.0, 0.42, 0.12))

			elif behavior == "kamikaze":
				# KAMIKAZE : quasi identique a "miner" (approche + GroundZone), SAUF qu'il ne
				# recule jamais — a portee, il s'arme (meche visible) puis fonce et se detruit ;
				# la GroundZone posee SUR LUI-MEME au moment du sacrifice EST l'explosion (reutilise
				# le systeme deja en place, qui ne degate que le joueur — meme convention que MINEUR).
				if not _kamikaze_arming:
					desired_vel = dir * speed * _speed_mult * 1.15   # fonce, plus vite qu'un rush normal
					if dist <= KAMIKAZE_RANGE:
						_kamikaze_arming = true
						_kamikaze_fuse = KAMIKAZE_FUSE_TIME
				else:
					desired_vel = dir * speed * _speed_mult * 0.3   # continue d'avancer pendant la meche
					_kamikaze_fuse -= delta
					var pulse: float = absf(sin(_kamikaze_fuse * 26.0))
					if _mat != null and _mat.shader != null:
						_mat.set_shader_parameter("warn", pulse)
					if _kamikaze_fuse <= 0.0:
						if game != null and game.has_method("spawn_ground_zone"):
							var boom_dmg: float = attack_dmg if attack_dmg > 0.0 else contact_dmg * 2.2
							# delai quasi nul : la meche de 0.6s (warn qui pulse) EST deja le telegraphe,
							# inutile de superposer le grand anneau de GroundZone par-dessus.
							game.spawn_ground_zone(global_position, 100.0, 0.05, boom_dmg, Color(1.0, 0.35, 0.1))
						take_damage(hp_max + 1.0)   # auto-destruction : reutilise le bookkeeping normal de _die()

			else:
				# --- CHARGE DE TAUREAU : cabrage (telegraph) -> charge LIGNE DROITE -> cooldown ---
				if _bull_state == 1:                       # WIND-UP : se cabre + rougeoie (tell CLAIR)
					desired_vel = -dir * speed * 0.12
					_bull_t -= delta
					var glow: float = absf(sin(_bull_t * 34.0))               # pulse de rage
					# la teinte d'armement porte la COULEUR DU PALIER : au palier 0 c'est le
					# rouge historique, plus haut elle vire vers la teinte de l'arme. C'est ce
					# qui rend l'evolution de la charge lisible a distance.
					# 🚨 Au palier 0 on rend EXACTEMENT le rouge historique : `--arme=0` doit etre
					# le jeu d'avant au pixel pres, sinon ce n'est plus un temoin de mesure.
					var rouge: Color = Color(1.7 + 0.9 * glow, 0.42, 0.24)
					if _palier > 0:
						self_modulate = rouge.lerp(ARME_COUL[_palier] * (1.3 + 0.7 * glow),
							0.30 * float(_palier))
					else:
						self_modulate = rouge
					if _bull_t <= 0.0:
						_bull_state = 2; _bull_t = 0.85; _bull_dir = dir     # direction VERROUILLEE (charge plus longue)
						self_modulate = Color(1.9, 0.6, 0.42)                # enrage pendant la charge
						if game != null and game.has_method("spawn_vfx"):
							game.spawn_vfx("aaa_muzzle", global_position, dir.angle(), 0.8, Color(1.0, 0.42, 0.18))
						if Events != null:
							Events.screen_shake.emit(0.8)
						play("attack", true)
				elif _bull_state == 2:                     # CHARGE : fonce tout droit, TRES rapide
					desired_vel = _bull_dir * speed * BULL_VITESSE[_palier]
					if dist < 46.0 and _contact_cd <= 0.0:
						_contact_cd = 0.5
						if player.has_method("take_damage"):
							player.take_damage(attack_dmg if attack_dmg > 0.0 else contact_dmg * 1.6, global_position, "bull:" + kind)
							_impact_charge(_bull_dir)   # meme arme, impact de plus en plus lourd
					_bull_t -= delta
					if _bull_t <= 0.0:
						_bull_state = 0; _bull_cd = randf_range(2.6, 4.2)
						self_modulate = _bull_mod0                          # restaure la teinte de base
						if _bull_counted:
							_bull_counted = false; Enemy._bulls_charging -= 1
				else:                                      # CHASSE normale + declenche la charge
					# ---------- INTELLIGENCE : interception, encerclement, patience ----------
					var iq: float = _iq()
					var vise: Vector2 = dir

					# 1. INTERCEPTION — viser ou le joueur SERA. Le temps d'avance est plafonne
					#    par le temps qu'il me faut pour arriver : au-dela, on viserait dans le
					#    vide. Contre du joueur : changer de cap (le point vise devient faux).
					if iq > 0.0 and "velocity" in player:
						var pv: Vector2 = player.velocity
						if pv.length() > 20.0:
							var avance: float = minf(0.45 * iq, dist / maxf(60.0, speed * _speed_mult))
							var cible: Vector2 = player.global_position + pv * avance
							vise = (cible - global_position).normalized()

					# 2. ENCERCLEMENT — chaque ennemi garde SON releve d'approche. L'ecart se
					#    referme quand il arrive au contact, sinon ils tourneraient sans jamais
					#    toucher. C'est la fermeture de l'anneau, pas un evitement.
					var f_iq: float = clampf((GameState.run_time - IQ_FLANC_T) / IQ_FLANC_T, 0.0, 1.0) * iq
					if f_iq > 0.0:
						var proche: float = clampf((dist - 90.0) / 260.0, 0.0, 1.0)
						vise = vise.rotated(_flanc * FLANC_MAX * f_iq * proche)

					desired_vel = vise * speed * _speed_mult
					var time_sec: float = Time.get_ticks_msec() / 1000.0
					var perp_rush: Vector2 = Vector2(-dir.y, dir.x)
					# l'ondulation aleatoire s'efface a mesure qu'ils deviennent intentionnels
					desired_vel += perp_rush * sin(time_sec * 1.3 + _wander_phase) * _WANDER_STR * (1.0 - 0.7 * iq)

					# 3. PATIENCE — arrive SEUL, il tourne autour au lieu de se jeter dedans, et
					#    attend ses semblables. Des qu'ils sont assez, tout le monde s'engage.
					#    4. OPPORTUNISME — si le joueur est bas en vie, plus personne n'hesite.
					if GameState.run_time > IQ_PATIENCE_T and _allies < 2 and dist < 210.0:
						var presse: bool = false
						if GameState.run_time > IQ_OPPORTUNISME_T and "hp" in player and "max_hp" in player:
							presse = player.hp < player.max_hp * 0.35
						if not presse:
							_hesite = minf(_hesite + delta, 2.2)
							if _hesite > 0.25:
								# on garde la distance en tournant : lisible, et ca laisse au
								# joueur le temps de percer avant que la meute ne soit la.
								var tang: Vector2 = Vector2(-vise.y, vise.x) * signf(_flanc)
								desired_vel = (tang * 0.85 - vise * 0.15) * speed * _speed_mult
						else:
							_hesite = 0.0
					else:
						_hesite = maxf(0.0, _hesite - delta * 2.0)

					if dist < CONTACT_PORTEE[_palier] and _contact_cd <= 0.0:
						_contact_cd = CONTACT_CAD[_palier]
						if player.has_method("take_damage"):
							player.take_damage(contact_dmg, global_position, "contact:" + kind)
							play("attack", true)
							if _palier >= 1:
								_percussion(dir)   # palier 1 : le coup au contact se VOIT partir
					# palier >= 2 : la meme arme a pris de l'ALLONGE (frappe d'arc telegraphiee)
					_arme_contact(delta, dist, dir)
					if bull:
						_bull_cd -= delta
						if _bull_cd <= 0.0 and dist > 130.0 and dist < 470.0 and Enemy._bulls_charging < BULL_CAP:
							# l'arme du bull = sa charge : elle s'arme plus vite a chaque palier
							_bull_state = 1; _bull_t = BULL_ARMEMENT[_palier]; _bull_counted = true
							_bull_mod0 = self_modulate       # memorise la teinte de base
							Enemy._bulls_charging += 1

			# --- EVITEMENT ENTRE ENNEMIS ---------------------------------------------------
			# 🚨 BOGUE MESURE. L'ancienne boucle s'arretait aux 10 PREMIERES ENTREES DU TABLEAU
			# (`if count >= 10: break`, count incremente meme pour soi-meme et pour les morts).
			# L'ordre du tableau est l'ordre d'apparition, pas la proximite : avec 46 ennemis a
			# l'ecran, un ennemi calculait donc son evitement contre dix voisins quelconques,
			# souvent a l'autre bout de la carte, et ignorait ceux qui le touchaient.
			# Consequence chiffree (banc, 8 parties/palier) : a 60 s il y a 7 ennemis a l'ecran
			# en NORMAL contre 46 en VETERAN — et le joueur a PLUS de vie en VETERAN (76 contre
			# 66 a 30 s). Les ennemis s'empilaient et se bloquaient mutuellement au lieu de
			# l'atteindre : la difficulte la plus haute etait devenue la plus sure (38 % de
			# survie a 150 s contre 0 % en NORMAL).
			# Correctif : on garde un budget borne (le cout doit rester constant a 220 ennemis)
			# mais on BALAIE a partir d'un curseur tournant, et seuls les voisins REELLEMENT
			# dans le rayon consomment le budget. En quelques images, chaque ennemi a donc vu
			# son vrai voisinage.
			var separation: Vector2 = _sep_vec
			var enemies: Array = _shared_enemies()
			var sep_rad_sq: float = _SEP_RADIUS * _SEP_RADIUS
			var nb: int = enemies.size()
			_sep_tick += 1
			# 21/10 (« trop d'ennemis, ca rame ») : balayage de voisinage 1 image sur 3 par ennemi (decale par instance) ; le vecteur
			# est reutilise entre-temps. MESURE a 200 ennemis : la separation pesait ~43 % du cout d'un ennemi.
			if nb > 1 and (_sep_tick + int(get_instance_id())) % 3 == 0:
				separation = Vector2.ZERO
				var depart: int = _sep_cursor % nb
				_sep_cursor = (_sep_cursor + 7) % nb   # pas premier : balaie tout le monde
				var examines: int = 0
				var retenus: int = 0
				var proches: int = 0
				var i: int = 0
				while i < nb and examines < _SEP_SCAN and retenus < _SEP_MAX:
					var e: Node = enemies[(depart + i) % nb]
					i += 1
					examines += 1
					if e == self or not (e is Enemy) or not (e as Enemy).alive:
						continue
					var to_other: Vector2 = global_position - (e as Node2D).global_position
					var d2: float = to_other.length_squared()
					if d2 > 0.0 and d2 < 46000.0:      # ~215 px : « mes semblables sont-ils la ? »
						proches += 1
					if d2 > 0.0 and d2 < sep_rad_sq:
						retenus += 1
						separation += to_other.normalized() * (1.0 - (d2 / sep_rad_sq))
			
				_allies = proches
				_sep_vec = separation
			if zigzag > 0.0 and dist > 200.0 and behavior == "rush" and _bull_state != 2:
				desired_vel += Vector2(-dir.y, dir.x) * sin(float(Time.get_ticks_msec()) * 0.005 + _wander_phase) * speed * zigzag
			if form_w > 0.0 and _bull_state != 2 and _phase != _PH_DASH_ACTIVE and not _kamikaze_arming:
				var to_slot: Vector2 = form_pos - global_position
				var sl: float = to_slot.length()
				var want: Vector2 = Vector2.ZERO if sl < 14.0 else to_slot / sl * minf(speed * 1.2, sl * 3.0)
				desired_vel = desired_vel.lerp(want, clampf(form_w, 0.0, 1.0))
			if separation != Vector2.ZERO and _bull_state != 2:   # charge = ligne droite (non deviee)
				desired_vel += separation * _SEP_FORCE

			if behavior == "ranged":
				if heavy:
					# CANON LOURD TELEGRAPHIE : charge visible (~0.5s) -> 2 gros bolts lents.
					if _charging:
						_charge_t -= delta
						var pulse: float = 0.45 + 0.55 * absf(sin(float(Time.get_ticks_msec()) / 45.0))
						if _mat != null and _mat.shader != null:
							_mat.set_shader_parameter("warn", pulse)   # rouge, pas blanc
						if _charge_t <= 0.0:
							_charging = false
							_atk_cd = attack_cd
							if _mat != null and _mat.shader != null:
								_mat.set_shader_parameter("warn", 0.0)
							_fire_heavy(_aim_dir(dir))
					elif _atk_cd <= 0.0 and dist < prefer_dist + 120.0 and Enemy._fire_ok(2.0, rank):
						_charging = true
						_charge_t = HEAVY_CHARGE[_palier]
				elif _atk_cd <= 0.0 and dist < prefer_dist + 100.0 and _aim_ready() and Enemy._fire_ok(_shot_cost(), rank):
					_atk_cd = attack_cd * ARME_CADENCE[_palier]
					_tire_dispatch(_aim_dir(dir))
					
	else:
		desired_vel = Vector2.ZERO

	if _esq_t > 0.0:
		_esq_t -= delta
		velocity = _esq_dir * speed * 2.8
		desired_vel = velocity
		_spr.self_modulate = Color(1.6, 2.0, 2.5)
		if _esq_t <= 0.0:
			_spr.self_modulate = _garde_base_tint()
	if _garde_t > 0.0:
		desired_vel *= 0.5      # derriere son bouclier il ne manoeuvre qu'a moitie vitesse : contre-jeu = patienter
	velocity = velocity.move_toward(desired_vel, _ACCEL * delta)
	field_slow = minf(1.0, field_slow + delta * 2.5)   # recover when out of a slow field
	global_position += velocity * delta * field_slow

	# enemies can't walk over decor props (like the player): push out of any solid prop -> they slide around
	if game != null and "cover_list" in game:
		for c in game.cover_list:
			if not is_instance_valid(c):
				continue
			var toc: Vector2 = global_position - (c as Node2D).global_position
			var minr: float = float(c.block_r) + _body_radius * 0.6
			var d2c: float = toc.length_squared()
			if d2c < minr * minr and d2c > 0.01:
				global_position = (c as Node2D).global_position + toc / sqrt(d2c) * minr

	if _directional:
		# Ranged foes face their target (they shoot at the player while strafing);
		# melee foes face where they move (which is toward the player anyway).
		var face_vec: Vector2 = velocity
		if behavior == "ranged" and player != null and is_instance_valid(player):
			face_vec = Vector2.from_angle(_aim) * 100.0 if _aim_init else player.global_position - global_position
		_update_facing(face_vec)
		_aim_tilt(delta)
	elif abs(velocity.x) > 2.0:
		_spr.flip_h = velocity.x < 0.0

	if _one_shot:
		_advance_one_shot(delta)
	else:
		# Movement-driven selection. Un cycle "run" distinct (quand le chassis en a un baké) ne
		# joue que pendant une VRAIE ruée/charge (dash actif, charge du bull) — pas pendant une
		# approche ordinaire — pour que l'art rapide serve exactement le moment qui le justifie.
		var sprinting: bool = _anims.has("run") and ((behavior == "dasher" and _phase == _PH_DASH_ACTIVE) or _bull_state == 2)
		var current_speed: float = velocity.length()
		var max_speed: float = speed * _speed_mult
		if max_speed > 0.0 and current_speed > (max_speed * 0.12):
			play("run" if sprinting else _base_loop, false)
		else:
			play(_idle_anim, false)
			
		if _frames > 1:
			var speed_factor: float = (current_speed / max_speed) if max_speed > 0 else 0.0
			speed_factor = maxf(0.65, minf(1.4, speed_factor))
			_t += delta * _fps * speed_factor
			_spr.frame = int(_t) % _frames
		elif _proc:
			# Procedural life for a static premium model. Ground units: a HOP + sway while moving (reads
			# as a mech stomping forward) + squash synced to the hop; a slow breathe at rest. Cadence
			# scales with speed so a heavy tank stomps slowly and a light raider scurries. Hover drones
			# get a continuous float instead of a ground stomp.
			_proc_t += delta
			if _proc_hover:
				# airborne bob: always floating, faster wobble while chasing
				var fl: float = sin(_proc_t * (4.2 if current_speed > (max_speed * 0.12) else 2.6))
				var tilt: float = sin(_proc_t * 1.7)
				_spr.position = _proc_base_pos + Vector2(tilt * 2.0, fl * 4.0)
				_spr.scale = _proc_base_scale
			else:
				var cad: float = clampf(max_speed / 26.0, 5.0, 11.0)   # slow tank .. quick raider
				var mv: bool = current_speed > (max_speed * 0.12)
				var hop: float = absf(sin(_proc_t * cad))
				var sway: float = sin(_proc_t * cad * 0.5)
				if mv:
					_spr.position = _proc_base_pos + Vector2(sway * 3.0, -hop * 6.0)
					_spr.scale = Vector2(_proc_base_scale.x * (1.0 + hop * 0.05), _proc_base_scale.y * (1.0 - hop * 0.05))
				else:
					var br: float = sin(_proc_t * 2.2)
					_spr.position = _proc_base_pos + Vector2(0.0, br * 1.5)
					_spr.scale = _proc_base_scale

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 7.0)
		if _mat != null and _mat.shader != null:
			_mat.set_shader_parameter("flash", _flash)

	_update_shield(delta)
	if _hp_fill != null:
		var frac: float = clampf(hp / maxf(1.0, hp_max), 0.0, 1.0)
		_hp_fill.points = PackedVector2Array([
			Vector2(-_hp_bar_w * 0.5, _hp_bar_y),
			Vector2(-_hp_bar_w * 0.5 + _hp_bar_w * frac, _hp_bar_y)])


## Style/couleur/geometrie du bouclier selon le PORTEUR (reglages patron via l'editeur, convertis
## x0.60 : l'editeur mesure en hauteur de CORPS rogne, le sprite en jeu a des marges de cadre).
func _shield_assets() -> Dictionary:
	# valeurs = reglages patron (editeur anime) converties x0.60 (editeur=hauteur corps, jeu=cadre vsize)
	match chassis:
		"midboss":     # Colosse : ecailles OR
			return {"tex": load("res://assets/vfx/shield_plated.png"), "tint": Color("ffbe37"), "w": 0.978, "h": 1.008, "ox": -0.006, "oy": 0.012, "rot": 33.0, "bright": 1.07, "backA": 0.35, "frontA": 0.55, "gap": 1.02}
		"crusherboss": # Broyeur : electrique ROUGE-ORANGE
			return {"tex": load("res://assets/vfx/shield_electric.png"), "tint": Color("ff7a45"), "w": 1.002, "h": 1.008, "ox": 0.0, "oy": -0.012, "rot": 0.0, "bright": 1.05, "backA": 0.35, "frontA": 0.55, "gap": 1.05}
		"endboss":     # Souverain : runique CRAMOISI/VIOLET
			return {"tex": load("res://assets/vfx/shield_runic.png"), "tint": Color("e055c0"), "w": 1.044, "h": 1.032, "ox": 0.0, "oy": -0.03, "rot": 0.0, "bright": 1.0, "backA": 0.35, "frontA": 0.55, "gap": 1.05}
		_:             # blindes de base : hex CYAN
			return {"tex": load("res://assets/vfx/shield_hex.png"), "tint": Color("6ad0ff"), "w": 1.008, "h": 1.044, "ox": 0.0, "oy": -0.03, "rot": 0.0, "bright": 1.0, "backA": 0.35, "frontA": 0.55, "gap": 1.05}

func _update_shield(delta: float) -> void:
	if shield_max <= 0.0:
		return
	# regenerate after a lull without taking damage
	if rank >= 3 and shield <= 0.0:
		pass  # bouclier de boss brise : reste perce pour eviter de faire durer le combat a l'infini
	elif _shield_regen_t > 0.0:
		_shield_regen_t -= delta
	elif shield < shield_max:
		var srate: float = 0.02 if rank >= 2 else 0.15
		shield = minf(shield_max, shield + shield_max * srate * delta)
	if _shield_flash > 0.0:
		_shield_flash = maxf(0.0, _shield_flash - delta * 4.0)
	if _shield_spr != null:
		var on: bool = shield > 0.5
		_shield_spr.visible = on
		if _shield_rim != null:
			_shield_rim.visible = on
		if on:
			var frac: float = clampf(shield / maxf(1.0, shield_max), 0.4, 1.0)   # s'affaiblit visuellement
			var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
			var a1: float = (_shield_backA + 0.14 * pulse + _shield_flash * 0.7) * frac * _shield_bright
			var a2: float = (_shield_frontA + 0.14 * pulse + _shield_flash * 0.6) * frac * _shield_bright
			_shield_spr.modulate = Color(_shield_tint.r, _shield_tint.g, _shield_tint.b, a1)
			_shield_rim.modulate = Color(_shield_tint.r, _shield_tint.g, _shield_tint.b, a2)
			_shield_rim.rotation += delta * 0.5     # rotation lente = bouclier vivant
			_shield_spr.rotation -= delta * 0.22


## ======================= VISEE (21/10, patron : « qu'ils n'aient pas le bras arme fige ») =======================
## Le canon se TOURNE vers sa cible a `aim_rate` rad/s et vise le point d'interception du joueur (part `aim_lead` de son
## mouvement). Il ne tire que lorsque l'ecart est < 0,28 rad : un joueur qui change de direction brusquement se fait
## rattraper moins vite par les niveaux bas (lent, peu d'anticipation) que par les hauts. Le sprite 8 directions est
## incline vers l'angle exact (+/- 0,4 rad) : le bras suit entre deux directions cuites.
## Le mecha cuit n'est pas centre dans son cadre (bbox ~23 px au-dessus du centre sur 176) : les boucliers se centrent sur le
## CENTRE VISIBLE du corps (bbox de l'alpha, mesuree une fois par chassis), pas sur l'origine du noeud.
static var _vc_cache: Dictionary = {}
func _visual_offset() -> Vector2:
	if _spr == null or _spr.texture == null:
		return Vector2.ZERO
	var off: Vector2
	if Enemy._vc_cache.has(chassis):
		off = Enemy._vc_cache[chassis]
	else:
		off = Vector2.ZERO
		var img: Image = _spr.texture.get_image()
		if img != null and not img.is_empty():
			var fw: int = mini(img.get_width(), img.get_height())   # cadres carres (cf. _frames_for) : hframes pas encore pose ici
			var r: Rect2i = img.get_region(Rect2i(0, 0, fw, img.get_height())).get_used_rect()
			if r.size.x > 0 and r.size.y > 0:
				off = Vector2(r.get_center()) - Vector2(float(fw) * 0.5, float(img.get_height()) * 0.5)
		Enemy._vc_cache[chassis] = off
	return off * _spr.scale

func _aim_tick(delta: float) -> void:
	var to_p: Vector2 = player.global_position - global_position
	var goal: Vector2 = player.global_position
	if aim_lead > 0.0 and "velocity" in player:
		var tof: float = to_p.length() / maxf(ARME_VITESSE[_palier], 100.0)
		goal += (player.velocity as Vector2) * tof * aim_lead
	_aim_goal = (goal - global_position).angle()
	if not _aim_init:
		_aim = _aim_goal
		_aim_init = true
		return
	var step: float = aim_rate * delta
	_aim += clampf(angle_difference(_aim, _aim_goal), -step, step)

func _aim_ready() -> bool:
	return not _aim_init or absf(angle_difference(_aim, _aim_goal)) < 0.28

func _aim_dir(fallback: Vector2) -> Vector2:
	return Vector2.from_angle(_aim) if _aim_init else fallback

func _aim_tilt(delta: float) -> void:
	var want: float = 0.0
	if _aim_init and _DIR_DEG.has(_dir) and _anims.get(_cur_anim) is Dictionary and (_anims.get(_cur_anim) as Dictionary).has("front_right"):
		want = clampf(angle_difference(deg_to_rad(float(_DIR_DEG[_dir])), _aim), -0.2, 0.2)
	_spr.rotation = lerp_angle(_spr.rotation, want, clampf(delta * 6.0, 0.0, 1.0))   # douce : pas de saut quand le secteur de direction change

## ======================= GARDE ACTIVE : bouclier energetique temporaire =======================
## 2,2 s a ~12 % des degats, puis recharge `garde_cd`. Se declenche quand le joueur est proche (~280 px) ou au premier coup
## encaisse. Ralentit son porteur de moitie (cf. _physics_process) : on peut patienter, contourner, ou viser un autre.
## ======================= SIGNATURES DE TIR (21/10, patron : « ils ont tous la meme attaque ») =======================
## Chaque niveau a SA facon de tirer, lisible a la couleur, a la vitesse et a la forme de la salve :
##  rafale (3 coups serres, orange) | eventail (5 plombs, jaune-vert) | sniper (charge 0,6 s puis coup rapide, blanc) |
##  guide (missile qui vire, violet) | anneau (10 tirs radiaux apres charge, vert) | orbe (grosse sphere lente, rouge).
## sniper / anneau / orbe se TELEGRAPHIENT (silhouette qui rougit) : on peut les lire et les esquiver.
const _STYLES: Dictionary = {
	"rafale":   {"col": Color(1.0, 0.55, 0.15), "charge": 0.0},
	"eventail": {"col": Color(0.85, 1.0, 0.3), "charge": 0.0},
	"sniper":   {"col": Color(0.75, 1.0, 1.0), "charge": 0.6},
	"guide":    {"col": Color(0.8, 0.4, 1.0), "charge": 0.0},
	"anneau":   {"col": Color(0.4, 1.0, 0.5), "charge": 0.5},
	"orbe":     {"col": Color(1.0, 0.3, 0.25), "charge": 0.45},
}

## BUDGET DE TIR GLOBAL (22/10, banc d'equilibre : des tireurs en foule tuaient le bot en 25-50 s aux niveaux 6, 9, 10, 12, 14, et
## chaque balle coute du rendu) : un seau a jetons partage par TOUS les ennemis. Debit `fire_rate` jetons/s (regle par le
## spawner selon niveau et temps), reserve 2 s. Un tir coute 1 (simple), 2 (rafale/eventail/lourd), 3 (anneau). Le feu entrant
## est donc BORNE quelle que soit la foule ; rang >= 2 (mini-boss, boss) exempte. Un tir refuse est simplement retarde.
static var fire_rate: float = 6.0
static var _tok: float = 8.0
static var _tok_f: int = 0
static func _fire_ok(cost: float, rk: int) -> bool:
	if rk >= 2:
		return true
	var f: int = Engine.get_physics_frames()
	if f != Enemy._tok_f:
		Enemy._tok = minf(Enemy.fire_rate * 2.0, Enemy._tok + Enemy.fire_rate * float(f - Enemy._tok_f) / 60.0)
		Enemy._tok_f = f
	if Enemy._tok < cost:
		return false
	Enemy._tok -= cost
	return true

func _shot_cost() -> float:
	match tir_style:
		"anneau": return 3.0
		"rafale", "eventail": return 2.0
	return 1.0

## budget d'effets de bouche : 6 par image au plus (au-dela, le tir part mais sans flamme)
static var _fx_frame: int = -1
static var _fx_n: int = 0
static func _fx_ok() -> bool:
	var f: int = Engine.get_physics_frames()
	if f != Enemy._fx_frame:
		Enemy._fx_frame = f
		Enemy._fx_n = 0
	Enemy._fx_n += 1
	return Enemy._fx_n <= 6

func _tire_dispatch(dir: Vector2) -> void:
	if tir_style == "" or not _STYLES.has(tir_style):
		_tire_arme(dir)
		return
	var ch: float = float(_STYLES[tir_style]["charge"])
	if ch > 0.0:
		_style_charge = ch
		_burst_dir = dir
		play("attack", true)
		return
	_style_fire(dir)

func _style_fire(dir: Vector2) -> void:
	if game == null or not game.has_method("spawn_enemy_bolt"):
		return
	var col: Color = _STYLES[tir_style]["col"]
	var muzzle: Vector2 = global_position + dir * 22.0
	var d: float = attack_dmg
	match tir_style:
		"rafale":
			_burst_left = 3
			_burst_t = 0.0
			_burst_dir = dir
		"eventail":
			for i in 5:
				game.spawn_enemy_bolt(muzzle, dir.rotated(-0.5 + 0.25 * float(i)), d * 0.5, col, 0.9, 270.0, false, 0.0, "style:eventail")
		"sniper":
			game.spawn_enemy_bolt(muzzle, dir, d * 1.8, col, 0.7, 780.0, false, 0.0, "style:sniper")
		"guide":
			game.spawn_enemy_bolt(muzzle, dir, d * 1.0, col, 1.2, 230.0, true, 1.2, "style:guide")
		"anneau":
			var nr: int = 10 if get_tree().get_nodes_in_group("enemies").size() < 90 else 6   # en foule : anneau allege (rendu)
			for i in nr:
				game.spawn_enemy_bolt(global_position, Vector2.from_angle(TAU * float(i) / float(nr) + _aim), d * 0.55, col, 1.0, 210.0, false, 0.0, "style:anneau")
			if game.has_method("spawn_vfx"):
				game.spawn_vfx("aaa_shockwave", global_position, 0.0, 0.5, col)
		"orbe":
			game.spawn_enemy_bolt(muzzle, dir, d * 1.6, col, 2.1, 175.0, true, 0.0, "style:orbe")
	if tir_style != "anneau" and game.has_method("spawn_vfx") and Enemy._fx_ok():
		game.spawn_vfx("fire_blast", muzzle, dir.angle(), 0.45, col)
	play("attack", true)

## Projectiles du joueur [pos, vitesse], releves UNE fois toutes les 0,1 s pour tous les ennemis (avant : chaque esquiveur
## reparcourait tout le calque a chaque scan -> plusieurs dizaines de milliers de tests/s en Web = saccades).
static var _shots_cache: Array = []
static var _shots_t: int = -999
static func _player_shots(game_ref: Node) -> Array:
	var f: int = Engine.get_physics_frames()
	if f - Enemy._shots_t >= 6:
		Enemy._shots_t = f
		Enemy._shots_cache = []
		for pr in game_ref.projectile_layer.get_children():
			if pr is Projectile and (pr as Projectile).visible and (pr as Projectile).velocity.length_squared() > 1.0:
				Enemy._shots_cache.append([(pr as Node2D).global_position, (pr as Projectile).velocity])
	return Enemy._shots_cache

func _style_tick(delta: float, player_valid: bool) -> void:
	# salve de rafale : un coup toutes les 0,11 s dans la direction figee au depart (lisible : on peut la contourner)
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = 0.11
			_burst_left -= 1
			if game != null and game.has_method("spawn_enemy_bolt"):
				game.spawn_enemy_bolt(global_position + _burst_dir * 22.0, _burst_dir, attack_dmg * 0.7, _STYLES["rafale"]["col"], 0.85, 430.0, false, 0.0, "style:rafale")
	# charge de sniper / anneau / orbe : la silhouette rougit, la visee continue de suivre pendant la charge
	if _style_charge > 0.0:
		_style_charge -= delta
		if _mat != null and _mat.shader != null:
			_mat.set_shader_parameter("warn", 0.45 + 0.55 * absf(sin(float(Time.get_ticks_msec()) / 45.0)))
		if tir_style == "sniper":
			if _sniper_laser == null:
				_sniper_laser = Line2D.new()
				_sniper_laser.width = 3.0
				_sniper_laser.z_index = 5
				add_child(_sniper_laser)
			_sniper_laser.visible = true
			var ldir: Vector2 = _aim_dir(_burst_dir)
			_sniper_laser.points = PackedVector2Array([Vector2.ZERO, ldir * 720.0])
			var pulse: float = 0.65 + 0.35 * absf(sin(float(Time.get_ticks_msec()) * 0.03))
			_sniper_laser.default_color = Color(1.0, 0.15, 0.15, pulse)
		elif tir_style == "anneau":
			if game != null and game.has_method("spawn_vfx") and (Engine.get_physics_frames() + get_instance_id()) % 12 == 0:
				game.spawn_vfx("aaa_shockwave", global_position, 0.0, 0.15, Color(0.4, 1.0, 0.5))
		elif tir_style == "orbe":
			if game != null and game.has_method("spawn_vfx") and (Engine.get_physics_frames() + get_instance_id()) % 12 == 0:
				game.spawn_vfx("fire_blast", global_position + _aim_dir(_burst_dir) * 22.0, 0.0, 0.3, Color(1.0, 0.3, 0.25))
		if _style_charge <= 0.0:
			_style_charge = 0.0
			if _mat != null and _mat.shader != null:
				_mat.set_shader_parameter("warn", 0.0)
			if _sniper_laser != null:
				_sniper_laser.visible = false
			_style_fire(_aim_dir(_burst_dir))
	# esquive : si un projectile du joueur fonce sur lui, il se jette de cote (recharge 3 s)
	if esquive:
		_esq_cd -= delta
		_esq_scan -= delta
		if _esq_cd <= 0.0 and _esq_scan <= 0.0 and _esq_t <= 0.0 and player_valid and game != null and "projectile_layer" in game and game.projectile_layer != null:
			_esq_scan = 0.1
			for pp in Enemy._player_shots(game):
				var rel: Vector2 = global_position - (pp[0] as Vector2)
				var pv: Vector2 = pp[1]
				if rel.length_squared() < 22500.0 and pv.dot(rel) > 0.0 and absf(pv.normalized().cross(rel.normalized())) < 0.5:
					var perp: Vector2 = Vector2(-pv.y, pv.x).normalized()
					_esq_dir = perp if perp.dot(rel) >= 0.0 else -perp
					_esq_t = 0.28
					_esq_cd = 3.0
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("aaa_shockwave", global_position, 0.0, 0.25, Color(0.6, 0.9, 1.0))
						game.spawn_vfx("fire_blast", global_position - _esq_dir * 18.0, _esq_dir.angle() + PI, 0.35, Color(0.4, 0.8, 1.0))
					break

## LOD de distance (leçon opensurvivor « enemy targeting throttle ») : au-dela de ~560 px (hors ecran) un ennemi ne
## reflechit qu'1 image sur 3 et poursuit sa course sur sa vitesse acquise entre-temps. Les boss ne sont pas concernes.
func _lod_far(delta: float) -> bool:
	if global_position.distance_squared_to(player.global_position) < 313600.0:
		return false
	_lod_n += 1
	if _lod_n % 3 == 0:
		return false
	global_position += velocity * delta * field_slow
	return true

## PROTECTEUR (Shielder de survivor-td) : toutes les 0,5 s, marque ses allies a <= 220 px (bouclier de zone -40 % de degats,
## ~0,8 s de remanence) et pulse un anneau pour qu'on le reconnaisse : le tuer en premier retire la protection.
func _protecteur_tick(delta: float) -> void:
	_prot_cd -= delta
	if _prot_cd > 0.0:
		return
	_prot_cd = 0.5
	for e in _shared_enemies():
		if e != self and e is Enemy and (e as Enemy).alive and global_position.distance_squared_to((e as Node2D).global_position) < 48400.0:
			(e as Enemy)._prot_t = 0.8
	if game != null and game.has_method("spawn_vfx") and Enemy._fx_ok() and int(Time.get_ticks_msec() / 500) % 3 == 0:
		game.spawn_vfx("aaa_shockwave", global_position + _visual_offset(), 0.0, 1.1, Color(0.4, 1.0, 0.85))

func _garde_on() -> void:
	_garde_t = 2.2
	_garde_cd_t = garde_cd + 2.2
	_garde_pulse = 0.0
	_spr.self_modulate = Color(0.55, 1.0, 1.5)
	if _garde_dome != null:
		_garde_dome.visible = true
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("shield", global_position + _visual_offset(), 0.0, _body_radius / 40.0, Palette.CYAN)

func _garde_tick(delta: float, player_valid: bool) -> void:
	_garde_cd_t -= delta
	_garde_pulse -= delta
	if _garde_t > 0.0:
		_garde_t -= delta
		if _garde_dome != null:
			_garde_dome.queue_redraw()
		if _garde_t <= 0.0:
			_garde_t = 0.0
			_spr.self_modulate = _garde_base_tint()
			if _garde_dome != null:
				_garde_dome.visible = false
	elif _garde_cd_t <= 0.0 and player_valid and global_position.distance_squared_to(player.global_position) < 78400.0:
		_garde_on()

func _garde_base_tint() -> Color:
	if _tier_tint != null:
		return _tier_tint
	if grade == "chef":
		return Color(1.0, 0.72, 0.28)
	if grade == "lieutenant":
		return Color(0.55, 0.85, 1.25)
	if game != null and "spawner" in game and game.spawner != null:
		return game.spawner.enemy_tint
	return Color(1, 1, 1)

func _update_facing(v: Vector2) -> void:
	# Same mapping as the player mecha: +x right, -x left, +y (toward camera) front, -y back.
	if v.length() < 8.0:
		return
	var nd: String
	var a_cur: Variant = _anims.get(_cur_anim)
	if a_cur is Dictionary and (a_cur as Dictionary).has("front_right"):
		# 8 directions : secteur de 45 deg centre sur chaque direction (repere ecran : +y = face camera)
		var ang: float = rad_to_deg(v.angle())
		var sec: int = int(round(ang / 45.0))
		nd = _DIR_NAMES[posmod(sec, 8)]
		# hysteresis : on ne change que si on est sorti de ~30 deg du centre courant
		var centers: Dictionary = _DIR_DEG
		if _dir != nd and centers.has(_dir) and absf(wrapf(ang - float(centers[_dir]), -180.0, 180.0)) < 30.0:
			return
	elif absf(v.x) > absf(v.y):
		nd = "right" if v.x > 0.0 else "left"
	else:
		nd = "front" if v.y > 0.0 else "back"
	if nd == _dir:
		return
	_dir = nd
	if _anims.get(_cur_anim) is Dictionary:
		var f: int = _spr.frame
		_spr.texture = _current_tex()
		_spr.hframes = _frames
		_spr.frame = mini(f, _frames - 1)


func _advance_one_shot(delta: float) -> void:
	if _anim_done:
		return
	_t += delta * 12.0
	var frame_idx: int = int(_t)
	if frame_idx >= _frames:
		_anim_done = true
		_spr.frame = _frames - 1
		if _cur_anim == "attack" or _cur_anim == "hit":
			play(_base_loop, false)
	else:
		_spr.frame = frame_idx


func take_damage(amount: float, source_chassis: String = "", weapon_id: String = "") -> void:
	if not alive:
		return
	# credite la DERNIERE arme trackee qui a touche cet ennemi (pour les conditions d'evolution
	# "N kills avec cette arme") — un coup de grace par une source non-arme (aura/drone/lame/
	# orbe du joueur, brasier plasma, tourelle capturee) laisse l'attribution precedente en
	# l'etat ; si l'ennemi n'a JAMAIS ete touche par une arme trackee, le kill ne credite rien
	# (voulu, cf. GameState.add_kill).
	if weapon_id != "":
		_last_weapon_id = weapon_id
	if _brisure_stacks > 0:
		var per_stack: float = BRISURE_PER_STACK * (0.5 if rank >= 3 else 1.0)   # moitie contre les boss
		amount *= (1.0 + per_stack * float(_brisure_stacks))
	if source_chassis == "bruiser":
		_brisure_stacks = mini(_brisure_stacks + 1, 5)
		_brisure_t = BRISURE_STACK_DUR
		if _brisure_pips == null:   # creation paresseuse — voir la note dans setup()
			_brisure_pips = StackPips.new()
			_brisure_pips.col = Color(1.0, 0.35, 0.25)
			_brisure_pips.offset_y = -_body_radius * 1.6
			_brisure_pips.z_index = 6
			add_child(_brisure_pips)
		_brisure_pips.count = _brisure_stacks
	if _prot_t > 0.0:
		amount *= 0.6             # bouclier de zone d'un protecteur allie
	if grade != "chef" and chef_ref != null and is_instance_valid(chef_ref) and chef_ref.alive \
			and global_position.distance_squared_to((chef_ref as Node2D).global_position) < 144400.0:
		amount *= 0.75            # « ordre de defense » : tant que le chef est a portee de voix (~380 px)
	if garde:
		if _garde_t <= 0.0 and _garde_cd_t <= 0.0:
			_garde_on()
		if _garde_t > 0.0:
			amount *= 0.12
			if game != null and game.has_method("shield_ripple") and _garde_pulse <= 0.0:
				_garde_pulse = 0.25
				game.shield_ripple(global_position + _visual_offset(), _body_radius * 1.6, Palette.CYAN)
			if amount <= 0.05:
				return
	# the energy shield soaks damage first; only the overflow reaches HP
	if shield > 0.0:
		var absorbed: float = minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		_shield_flash = 1.0
		_shield_regen_t = 6.0
		if game != null and game.has_method("shield_ripple"):
			game.shield_ripple(global_position + _visual_offset(), _body_radius * 1.5, Palette.CYAN)
		if shield <= 0.0:
			shield = 0.0
			if game != null and game.has_method("shield_break"):
				game.shield_break(global_position + _visual_offset(), _body_radius * 1.7, Palette.CYAN)
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("shield", global_position + _visual_offset(), 0.0, _body_radius / 55.0, Palette.CYAN)
		if amount <= 0.0:
			return
	hp -= amount
	# 🚨 le flash de coup etait a 1.0 = silhouette ENTIEREMENT blanche. Tres bon a l'unite,
	# mais « sept ennemis virant au blanc en meme temps » font une tache indifferenciee.
	# 0.55 confirme le coup sans effacer la silhouette, et laisse le telegraphe (rouge, plein)
	# ressortir au-dessus.
	_flash = 0.55
	if _mat != null and _mat.shader != null:
		_mat.set_shader_parameter("flash", 0.55)
	Events.hit_spark.emit(global_position, Palette.CYAN)
	if hp <= 0.0:
		alive = false
		remove_from_group("enemies")
		call_deferred("_die")
	else:
		play("hit", true)


func _die() -> void:
	if _dying:
		return
	_dying = true
	# 🚨 FUITE DU TELEGRAPHE : `warn` (la teinte ROUGE d'attaque imminente) n'est remis a zero
	# que par les deux sorties NORMALES de telegraphie. Un ennemi tue PENDANT sa charge
	# (fonceur en phase d'elan, canon lourd en train de charger) gardait donc sa silhouette
	# rouge pleine pendant toute son animation de mort (~0,7 s) au lieu de la jouer.
	if _mat != null and _mat.shader != null:
		_mat.set_shader_parameter("warn", 0.0)
	if _bull_counted:                 # relache le slot de charge si l'ennemi meurt en pleine charge
		_bull_counted = false; _bulls_charging = maxi(0, _bulls_charging - 1)
	_libere_arc()                     # idem pour l'arc : un slot non rendu referme le plafond
	alive = false
	remove_from_group("enemies")
	set_deferred("monitorable", false)
	if _hp_bg != null:
		_hp_bg.visible = false
	if _hp_fill != null:
		_hp_fill.visible = false
	if _sniper_laser != null:
		_sniper_laser.visible = false
	if _garde_dome != null:
		_garde_dome.visible = false
	if _rank_badge != null:
		_rank_badge.visible = false
	GameState.add_kill(global_position, rank, _last_weapon_id)
	if game != null:
		if game.has_method("death_fx"):
			# no destruction flash on regular enemies (swarm = constant kills); the endboss
			# keeps the full burst (rare, epic moment)
			game.death_fx(global_position, rank, is_final)
		if game.has_method("spawn_xp"):
			game.spawn_xp(global_position, 1 + rank)
		if drops_bonus and game.has_method("spawn_bonus"):
			game.spawn_bonus(global_position)   # intermediate foe -> guaranteed bonus drop (heal/scrap)
		# BUTIN DE GUERRE (patron, 23/09) : reserve aux BOSS (rank>=3 = midboss/crusherboss/
		# ogreboss/endboss), pas aux foes intermediaires deja couverts par drops_bonus
		# ci-dessus — sinon l'emprunt perdrait son cote "tu viens de battre une vraie menace".
		if rank >= 3 and game.has_method("spawn_weapon_loan"):
			game.spawn_weapon_loan(global_position)
		# FORGE DETERMINISTE (26/09) : chance de plan a la mort d'un boss — seulement les VRAIS
		# boss nommes (kind existe dans PLAN_SLOT_BY_BOSS/PLAN_RARITY_WEIGHT), pas n'importe quel
		# rank>=3 futur qui n'aurait pas d'affinite de slot definie.
		if rank >= 3 and (kind == "endboss" or SaveManager.PLAN_SLOT_BY_BOSS.has(kind)):
			var plan: Dictionary = SaveManager.grant_boss_plan(kind)
			if not plan.is_empty() and game.has_method("show_hint"):
				var sn: String = String(SaveManager.GEAR_SLOT_NAMES.get(plan.get("slot", ""), ""))
				var rn: String = String(SaveManager.GEAR_RARITY_NAMES.get(plan.get("rarity", ""), ""))
				game.show_hint("Plan obtenu : %s %s — forgez-le depuis Équipement." % [rn, sn],
					Color(0.85, 0.75, 1.0), 5.0)
	if is_final:
		# SANS FIN: the endboss is a milestone, not an ending — the run rolls on, harder.
		if GameState.endless and game != null and game.has_method("endless_boss_down"):
			game.endless_boss_down()
		else:
			Events.run_won.emit()   # the endboss is down -> victory
	elif rank >= 3 and zone_shift and game != null and game.has_method("next_map"):
		game.next_map()         # a major threat cleared -> shift to a new, harder zone
	if _anims.has("die"):
		play("die", true)
		_die_timer = 0.7
	else:
		queue_free()
