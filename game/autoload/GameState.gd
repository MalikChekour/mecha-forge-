extends Node
## Live run state (reset each run). Progression math lives here so HUD/Player read
## one source of truth.

var run_time: float = 0.0
var level: int = 1
var xp: int = 0
var xp_to_next: int = 5
var kills: int = 0
var kills_by_weapon: Dictionary = {}   # weapon id -> kill count this run (evolution "kills" condition)
var damage_by_weapon: Dictionary = {}  # weapon id -> total damage dealt this run
var total_damage: float = 0.0          # total damage dealt across all weapons
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
## PHASE 1 — aimant. Vacuum global SANS invulnerabilite. Pickup teste ce flag A COTE de
## overdrive_active ; ne jamais le fusionner avec Overdrive (pas d'i-frames, pas de jauge).
var magnet_vacuum: bool = false
var magnet_vacuum_t: float = 0.0
const MAGNET_VACUUM_DUR: float = 2.5
## Phase 3 — charge Overdrive offerte par le set Anahei 4 pieces (consommee dans Player._transform_off).
var overdrive_free_casts: int = 0
## Defis de maitrise de la run en cours. Remis a zero dans reset().
var mastery_boss5_active: bool = false
var mastery_boss5_clean: bool = true
var mastery_boss5_ok: bool = false
var mastery_ranged: bool = false
const BOMB_RADIUS: float = 420.0
const BOMB_TRASH_HP_FRAC: float = 0.35   # part de hp_max, ennemis non-boss (rank < 3)
const BOMB_BOSS_HP_FRAC: float = 0.08    # degats reduits sur boss (rank >= 3)
const BOMB_BOSS_STUN: float = 1.2
const BOMB_KNOCKBACK: float = 1400.0     # repli si Enemy.apply_stun est absent
const PHASE1_GRACE: float = 18.0         # meme fenetre que la grace du spawner
const PHASE1_BOMB_P_FODDER: float = 0.007
const PHASE1_MAGNET_P_FODDER: float = 0.016
const PHASE1_BOMB_P_ELITE: float = 0.08
const PHASE1_MAGNET_P_ELITE: float = 0.12
const PHASE1_MAGNET_P_BOSS: float = 0.10
var alive: bool = true
var score: int = 0            # run score (kills weighted by rank x difficulty) -> leaderboard/grade
var death_cause: String = ""  # source qui a porte le coup fatal (banc d'equilibre)

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
## Banc headless `-- --mech=<id>` (Game.gd) : force un chassis EN MEMOIRE SEULEMENT, jamais ecrit
## dans SaveManager.data (voir la note pres du parsing de l'argument -> ce champ a remplace une
## 1ere version qui contaminait le vrai fichier de sauvegarde). "" = pas de forçage, cas normal.
var debug_force_mech: String = ""
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
		"weapons": ["disperseur"], "hp": 6.0, "dmg": 1.05, "speed": 1.05, "crit": 0.15,
		"arsenal": ["disperseur", "missilepod", "ricochet", "sabre", "plasma"],
		"signature": "disperseur", "accent": Color(1.00, 0.54, 0.16),
		"sig_muzzle": ["fire_blast", 0.40],
		"ligne": "SOUFFLE RAPPROCHÉ — sature, disloque, se replie.",
		"desc": "Éclaireur léger, gerbe à courte portée. Frappe et se replie."},
	## TITAN (patron, 24/09) — INTEGRATION D'ESSAI. Premier chassis choregraphie a la main
	## (build_titan_anims.py, sur le modele de Vortex/Bluestrike) plutot que par le pipeline
	## generique qui avait produit les 6 chassis ecartes. 28 planches verifiees une par une :
	## aucun saut de pose, aucun desequilibre — la garde basse tient sur les 8 images de
	## chaque animation. « Si c'est pas bon on retire » : stats/arme choisies pour un premier
	## test, pas figees.
	{"id": "titan", "name": "TITAN", "cost": 1800,
		"weapons": ["missilepod"], "hp": 30.0, "dmg": 1.15, "speed": 1.05, "crit": 0.05,
		"arsenal": ["missilepod", "railgun", "plasma", "disque", "faisceau"],
		"signature": "missilepod", "accent": Color(0.55, 0.68, 0.42),
		"sig_muzzle": ["fire_blast", 0.44],
		"ligne": "BLINDAGE LOURD — encaisse, avance, ne recule pas.",
		"desc": "Chassis blinde et massif. Garde basse, tir stabilise, absorbe plus qu'il n'esquive."},
	## BRUISER (patron, 24/09) — INTEGRATION D'ESSAI. Premier chassis genere FRAIS via Meshy
	## pour ce jeu (pas un modele recycle) : concept FLUX -> image-to-3D -> rig, 4 corrections
	## successives du patron avant validation (pas de lame car c'est un tireur ; plus musclu/
	## massif, pas svelte ; doit lire comme un engin PILOTE a echelle vehicule, pas un androide
	## a taille humaine ; arme explicitement tenue en main, pas les poings vides). Rig mesure
	## via bpy (27.0°/21.1° de hanche, 5.9° d'ecart) -> correctif applique + choregraphie de
	## vortex reprise A L'IDENTIQUE (build_bruiser_anims.py). « Si c'est pas bon on retire » :
	## stats/arme choisies pour un premier test, pas figees.
	{"id": "bruiser", "name": "BRUISER", "cost": 0,
		"weapons": ["plasma"], "hp": 22.0, "dmg": 1.35, "speed": 1.05, "crit": 0.06,
		"arsenal": ["plasma", "autocannon", "railgun", "disque", "faisceau"],
		"signature": "plasma", "accent": Color(0.82, 0.24, 0.20),
		"sig_muzzle": ["fire_blast", 0.46],
		"ligne": "FORCE BRUTE — chaque impact plie l'acier.",
		"desc": "Chassis massif taillé pour l'assaut. Canon lourd en main, encaisse pour mieux frapper."},
	## VANQUISHER (patron, 24/09) — INTEGRATION D'ESSAI. Genere depuis une image de reference
	## fournie par le patron (pas un prompt FLUX texte) : evite le cycle iteratif couteux de
	## bruiser en partant d'un design deja valide visuellement (canons doubles tenus en main,
	## cockpit vitre visible, pod de missiles a l'epaule, aucune lame). Rig mesure via bpy
	## (36.8°/28.6° de hanche, 8.2° d'ecart — la rotation seule ne peut PAS parfaitement
	## egaliser les deux jambes sur ce rig, meilleur appariement trouve a 0.1° d'ecart) +
	## choregraphie de vortex reprise A L'IDENTIQUE. « Si c'est pas bon on retire » : stats/
	## arme choisies pour un premier test, pas figees.
	{"id": "vanquisher", "name": "VANQUISHER", "cost": 0,
		"weapons": ["ricochet"], "hp": 23.0, "dmg": 1.10, "speed": 1.05, "crit": 0.10,
		"arsenal": ["ricochet", "autocannon", "missilepod", "disque", "faisceau"],
		"signature": "ricochet", "accent": Color(0.45, 0.55, 0.68),
		"sig_muzzle": ["aaa_beam", 0.44],
		"ligne": "SUPPRESSION CONTINUE — deux canons, aucun répit.",
		"desc": "Chassis d'assaut à double canon et pod de missiles. Ne laisse jamais l'ennemi se regrouper."},
	## PYLONE / CERCLIER (27/09, rapport "concepts visuels" — P2, apres differenciation des 5
	## chassis ci-dessus, deja faite). RESKIN deliberement : reprennent les planches de titan/
	## vanquisher (RENDER_CHASSIS plus bas) au lieu d'un nouveau bake Meshy — aucune depense
	## d'image/3D IA sans validation prealable. Mecanique reelle propre a chacun malgre le
	## sprite partage (voir Player.gd "pylone"/"cerclier" et Projectile.gd pour le disque).
	{"id": "pylone", "name": "PYLÔNE", "cost": 1600,
		"weapons": ["faisceau"], "hp": 28.0, "dmg": 1.05, "speed": 1.05, "crit": 0.05,
		"arsenal": ["faisceau", "autocannon", "railgun", "plasma", "disque"],
		"signature": "faisceau", "accent": Color(1.0, 0.78, 0.25),
		"sig_muzzle": ["aaa_beam", 0.48],
		"ligne": "ANCRAGE — immobile, le faisceau s'allonge et se resserre.",
		"desc": "Tient un couloir a l'arret : rester immobile ~0,5s deploie l'ancrage, portee et precision du Faisceau augmentent. Bouger le rompt aussitot."},
	{"id": "cerclier", "name": "CERCLIER", "cost": 1600,
		"weapons": ["disque"], "hp": 18.0, "dmg": 1.08, "speed": 1.05, "crit": 0.12,
		"arsenal": ["disque", "autocannon", "railgun", "plasma", "faisceau"],
		"signature": "disque", "accent": Color(0.55, 1.0, 0.35),
		"sig_muzzle": ["fire_blast", 0.40],
		"ligne": "RELANCE — le premier retour du Disque repart une fois.",
		"desc": "Chassis bas et circulaire. A son premier retour, le Disque peut repartir une fois vers une cible proche, a degats reduits."},
	## ---- VERSIONS MK (16/10, ESSAI) : memes rig, poses et meca que leur chassis de base (Player.chassis_family), pieces 3D en plus
	## (tools/mk_parts.py, cuites par tools/build_mk_anims.py). cout 0 = jouables tout de suite pour juger. A retirer si non retenues.
	{"id": "vortexmk2", "name": "VORTEX MK II", "cost": 0, "mk": 2, "base": "vortex",
		"weapons": ["autocannon"], "hp": 24.0, "dmg": 1.28, "speed": 1.05, "crit": 0.09,
		"arsenal": ["autocannon", "railgun", "faisceau", "disque", "plasma"],
		"signature": "autocannon", "accent": Color(0.38, 0.92, 1.00),
		"sig_muzzle": ["aaa_beam", 0.46],
		"ligne": "ÉNERGIE DIRIGÉE — blindage renforcé.",
		"desc": "Mk II : pauldrons, canon d'avant-bras, émetteur de paume. Même style que le VORTEX, plus robuste."},
	{"id": "vortexmk3", "name": "VORTEX MK III", "cost": 0, "mk": 3, "base": "vortex",
		"weapons": ["autocannon"], "hp": 28.0, "dmg": 1.36, "speed": 1.05, "crit": 0.1,
		"arsenal": ["autocannon", "railgun", "faisceau", "disque", "plasma"],
		"signature": "autocannon", "accent": Color(0.38, 0.92, 1.00),
		"sig_muzzle": ["aaa_beam", 0.46],
		"ligne": "ÉNERGIE DIRIGÉE — double canon.",
		"desc": "Mk III : canons jumeaux d'avant-bras, propulseurs dorsaux, plastron."},
	{"id": "vortexmk4", "name": "VORTEX MK IV", "cost": 0, "mk": 4, "base": "vortex",
		"weapons": ["autocannon"], "hp": 34.0, "dmg": 1.46, "speed": 1.05, "crit": 0.12,
		"arsenal": ["autocannon", "railgun", "faisceau", "disque", "plasma"],
		"signature": "autocannon", "accent": Color(0.38, 0.92, 1.00),
		"sig_muzzle": ["aaa_beam", 0.46],
		"ligne": "ÉNERGIE DIRIGÉE — version d'élite.",
		"desc": "Mk IV : gatling au bras, plaques flottantes et halos."},
	{"id": "bluestrikemk2", "name": "BLUESTRIKE MK II", "cost": 0, "mk": 2, "base": "bluestrike",
		"weapons": ["disperseur"], "hp": 9.0, "dmg": 1.12, "speed": 1.05, "crit": 0.16,
		"arsenal": ["disperseur", "missilepod", "ricochet", "sabre", "plasma"],
		"signature": "disperseur", "accent": Color(1.00, 0.54, 0.16),
		"sig_muzzle": ["fire_blast", 0.40],
		"ligne": "SOUFFLE RAPPROCHÉ — blindage renforcé.",
		"desc": "Mk II : blasters aux mains, évents d'épaule, genouillères."},
	{"id": "bluestrikemk3", "name": "BLUESTRIKE MK III", "cost": 0, "mk": 3, "base": "bluestrike",
		"weapons": ["disperseur"], "hp": 12.0, "dmg": 1.2, "speed": 1.05, "crit": 0.17,
		"arsenal": ["disperseur", "missilepod", "ricochet", "sabre", "plasma"],
		"signature": "disperseur", "accent": Color(1.00, 0.54, 0.16),
		"sig_muzzle": ["fire_blast", 0.40],
		"ligne": "SOUFFLE RAPPROCHÉ — assaut.",
		"desc": "Mk III : canons jumeaux d'avant-bras, propulseurs dorsaux."},
	{"id": "bluestrikemk4", "name": "BLUESTRIKE MK IV", "cost": 0, "mk": 4, "base": "bluestrike",
		"weapons": ["disperseur"], "hp": 16.0, "dmg": 1.3, "speed": 1.05, "crit": 0.19,
		"arsenal": ["disperseur", "missilepod", "ricochet", "sabre", "plasma"],
		"signature": "disperseur", "accent": Color(1.00, 0.54, 0.16),
		"sig_muzzle": ["fire_blast", 0.40],
		"ligne": "SOUFFLE RAPPROCHÉ — version d'élite.",
		"desc": "Mk IV : gatling au bras, ailes d'énergie, halo."},
]

## RESKIN (27/09) : id de MECHS -> chassis dont on reutilise les planches deja bakees (voir la
## note ci-dessus). base_chassis (mecanique/sauvegarde) reste l'id reel ; SEUL le rendu visuel
## est reroute ici. Un id absent de ce dict se rend avec ses propres planches (cas normal).
const RENDER_CHASSIS: Dictionary = {
	"pylone": "titan",
	"cerclier": "vanquisher",
}

## 🚨 CHASSIS ECARTES, et pourquoi — a lire avant d'en rajouter un.
## Le depot contient dix autres mechas. Verification faite CADRE PAR CADRE (8 images x 4
## directions, en grand — pas sur la premiere vignette, erreur que j'ai deja commise ici) :
##   • valiant / vanguard / vanguard2 / titan / pilot / mecha_joueur : essayes en jeu, ecartes
##     par le patron apres examen des planches. Ils ont un rigged.glb dans meshy_in/, donc ils
##     sont RE-BAKABLES proprement si on veut y revenir (Cycles CPU, ~1 h 30 par chassis ;
##     le module bpy est installe, aucun GPU n'est necessaire).
##   • george / darkstar / new_mecha / lourd : AUCUN modele source dans meshy_in. Leurs bakes
##     rates (mecha effondre de profil, art minuscule) ne sont re-rendables sur AUCUNE machine.
##     Il faudrait les remodeliser, pas les re-rendre.
## Ajouter un chassis = une ligne ci-dessus. Ce qui le distingue vraiment, c'est sa SIGNATURE
## (arme boostee + accent + effet de bouche), pas la liste de sa gamme.

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

## Famille mecanique d'un chassis : les versions MK (vortexmk2...) jouent comme leur chassis de base.
static func chassis_family(id: String) -> String:
	for b in ["vortex", "bluestrike"]:
		if id.begins_with(b + "mk"):
			return b
	return id

## Phase 3 — un passif permanent + un actif a cooldown, par famille de chassis.
const CHASSIS_KITS: Dictionary = {
	"vortex": {"passif": "damage", "pval": 0.06, "passif_nom": "Percee +6% degats", "actif": "align_burst", "actif_nom": "Salve d'alignement", "cd": 12.0},
	"bluestrike": {"passif": "speed", "pval": 0.05, "passif_nom": "Glisse +5% vitesse", "actif": "dash", "actif_nom": "Dash de chasse", "cd": 8.0},
	"titan": {"passif": "hp", "pval": 18.0, "passif_nom": "Blindage +18 PV", "actif": "shock", "actif_nom": "Onde de choc", "cd": 16.0},
	"bruiser": {"passif": "damage", "pval": 0.08, "passif_nom": "Brisure +8% degats", "actif": "shock", "actif_nom": "Choc de brisure", "cd": 14.0},
	"vanquisher": {"passif": "crit", "pval": 0.04, "passif_nom": "Visee +4% crit", "actif": "align_burst", "actif_nom": "Rafale critique", "cd": 11.0},
	"pylone": {"passif": "damage", "pval": 0.05, "passif_nom": "Ancrage +5% degats", "actif": "shock", "actif_nom": "Impulsion d'ancre", "cd": 15.0},
	"cerclier": {"passif": "speed", "pval": 0.04, "passif_nom": "Orbite +4% vitesse", "actif": "dash", "actif_nom": "Dash orbital", "cd": 9.0},
}

static func chassis_kit(id: String) -> Dictionary:
	var fam: String = chassis_family(id)
	if CHASSIS_KITS.has(fam):
		return CHASSIS_KITS[fam]
	return {"passif": "damage", "pval": 0.04, "passif_nom": "Signature +4% degats", "actif": "shock", "actif_nom": "Onde courte", "cd": 14.0}

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
	kills_by_weapon = {}
	damage_by_weapon = {}
	total_damage = 0.0
	props_destroyed = 0
	scrap = 0
	run_xp_mult = 1.0
	run_scrap_mult = 1.0
	overdrive = 0.0
	overdrive_active = false
	overdrive_count = 0
	overdrive_time = 0.0
	overdrive_cd = 0.0
	magnet_vacuum = false
	magnet_vacuum_t = 0.0
	overdrive_free_casts = 0
	mastery_boss5_active = false
	mastery_boss5_clean = true
	mastery_boss5_ok = false
	mastery_ranged = false
	alive = true
	death_cause = ""
	score = 0
	difficulty = SaveManager.get_difficulty()   # default from last choice; run-start menu can override
	endless = bool(SaveManager.setting("endless", false))
	endless_wave = 0
	compute_meta()

func compute_meta() -> void:
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
		# 22/10 (leçons survivor-td / opensurvivor) : au lieu de x1.35 exponentiel qui bloque le joueur
		# a 15 min (niveau 17-18 bloqué car il faut 2000-3000 XP/niveau face a des PV qui montent de +12%/min),
		# une courbe progressive permet de continuer a debloquer des ameliorations jusqu'au boss (lvl 22-26).
		if level < 6:
			xp_to_next = 5 + (level - 1) * 7
		else:
			xp_to_next = 33 + int(round(pow(float(level - 5), 1.38) * 6.5))
		Events.level_up.emit(level)

func add_scrap(amount: int) -> void:
	amount = int(round(amount * float(diff().get("reward", 1.0)) * Protocols.reward * run_scrap_mult))   # diff + protocole + passif +Or
	scrap += amount
	Events.scrap_collected.emit(amount)

func add_damage(weapon_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	total_damage += amount
	var key: String = weapon_id if weapon_id != "" else "divers"
	damage_by_weapon[key] = float(damage_by_weapon.get(key, 0.0)) + amount

func add_kill(pos: Vector2, rank: int, weapon_id: String = "") -> void:
	kills += 1
	# weapon_id vide = tue par une source non-arme (aura/drone/lame/orbe, brasier plasma,
	# tourelle capturee...) : ne credite AUCUNE arme plutot que de deviner. Voulu, pas un oubli.
	if weapon_id != "":
		kills_by_weapon[weapon_id] = int(kills_by_weapon.get(weapon_id, 0)) + 1
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

## Appele par Player chaque frame (y compris pendant Overdrive et le hitstop). Le timer est
## en temps de jeu : un hitstop de 40 ms ne le gele presque pas, et la fin d'Overdrive ne le coupe pas.
func tick_magnet_vacuum(delta: float) -> void:
	if magnet_vacuum_t <= 0.0:
		return
	magnet_vacuum_t = maxf(0.0, magnet_vacuum_t - delta)
	if magnet_vacuum_t <= 0.0:
		magnet_vacuum = false

## Pickup kind "aimant". N'ecrit PAS overdrive_active / transformed / iframes.
func activate_magnet_vacuum(duration: float = MAGNET_VACUUM_DUR) -> void:
	magnet_vacuum = true
	magnet_vacuum_t = maxf(magnet_vacuum_t, duration)

## Pickup kind "bombe". Centre = position du joueur au ramassage (le pickup est deja a < 30 px).
## Non-boss : 35 % de hp_max via Enemy.take_damage (bouclier et garde s'appliquent).
## Boss (rank >= 3) : apply_stun(1.2) si la methode existe, sinon knockback fort ; degats reduits.
func detonate_bomb(origin: Vector2, game: Node) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var radius_sq: float = BOMB_RADIUS * BOMB_RADIUS
	for n in tree.get_nodes_in_group("enemies"):
		if not (n is Enemy):
			continue
		var e: Enemy = n as Enemy
		if not e.alive:
			continue
		if origin.distance_squared_to(e.global_position) > radius_sq:
			continue
		if e.rank >= 3:
			var reduced: float = e.hp_max * BOMB_BOSS_HP_FRAC
			if e.has_method("apply_stun"):
				e.apply_stun(BOMB_BOSS_STUN)
			else:
				var away: Vector2 = e.global_position - origin
				if away.length_squared() < 4.0:
					away = Vector2.RIGHT
				e.velocity = away.normalized() * BOMB_KNOCKBACK
			if reduced > 0.0:
				e.take_damage(reduced, "", "bombe")
		else:
			var chunk: float = e.hp_max * BOMB_TRASH_HP_FRAC
			if chunk > 0.0:
				e.take_damage(chunk, "", "bombe")
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("shockwave", origin, 0.0, 3.6, Color(1.0, 0.45, 0.12))
		game.spawn_vfx("aaa_shockwave", origin, 0.0, 2.2, Color(1.0, 0.95, 0.75))
	Events.screen_shake.emit(11.0)
	Audio.sfx("explosion", 0.06)
	_bomb_flash()

func _bomb_flash() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 80
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(1.0, 0.9, 0.62, 0.82)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	var tw: Tween = layer.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.18)
	tw.tween_callback(layer.queue_free)

## Hook mort : Enemy._die appelle ceci apres le butin standard (spawn_xp / spawn_bonus / coffre).
## Marquage elite : EnemySpawner._maybe_elite (grade == "elite") et _spawn_elite (meta "phase1_elite").
## Un kill credite a l'arme "bombe" ne relance pas le tirage — pas de chaine bombe -> bombe.
func roll_phase1_drop(enemy: Node) -> void:
	if enemy == null or run_time < PHASE1_GRACE:
		return
	var wid: Variant = enemy.get("_last_weapon_id")
	if wid is String and String(wid) == "bombe":
		return
	var rank_v: Variant = enemy.get("rank")
	var rank: int = int(rank_v) if (rank_v is int or rank_v is float) else 0
	var elite: bool = _phase1_is_elite(enemy)
	var bomb_p: float = 0.0
	var magnet_p: float = 0.0
	if rank >= 3:
		magnet_p = PHASE1_MAGNET_P_BOSS
	elif elite:
		bomb_p = PHASE1_BOMB_P_ELITE
		magnet_p = PHASE1_MAGNET_P_ELITE
	else:
		bomb_p = PHASE1_BOMB_P_FODDER
		magnet_p = PHASE1_MAGNET_P_FODDER
	var roll: float = randf()
	var drop_kind: String = ""
	if roll < bomb_p:
		drop_kind = "bombe"
	elif roll < bomb_p + magnet_p:
		drop_kind = "aimant"
	if drop_kind == "":
		return
	var pos: Vector2 = (enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO
	var g: Node = null
	var g_v: Variant = enemy.get("game")
	if g_v is Node:
		g = g_v as Node
	var plr: Node2D = null
	var plr_v: Variant = enemy.get("player")
	if is_instance_valid(plr_v) and plr_v is Node2D:
		plr = plr_v as Node2D
	if plr == null:
		return
	_spawn_phase1_pickup(pos, drop_kind, g, plr)

func _phase1_is_elite(enemy: Node) -> bool:
	var grade_v: Variant = enemy.get("grade")
	if grade_v is String and String(grade_v) == "elite":
		return true
	if enemy.has_meta("phase1_elite") and bool(enemy.get_meta("phase1_elite")):
		return true
	return false

## Priorite : game.spawn_phase1_pickup(pos, kind) puis game.spawn_pickup(pos, kind, value),
## sinon Pickup instancie a la main (reclaim_pickup le reprend au ramassage si game est renseigne).
## Voir docs/PHASE1_INTEGRATION.md pour brancher le pool existant de spawn_xp.
func _spawn_phase1_pickup(pos: Vector2, kind: String, game: Node, plr: Node2D) -> void:
	if game != null and game.has_method("spawn_phase1_pickup"):
		game.spawn_phase1_pickup(pos, kind)
		return
	if game != null and game.has_method("spawn_pickup"):
		game.spawn_pickup(pos, kind, 1)
		return
	var parent: Node = game if game != null else (get_tree().current_scene if get_tree() != null else null)
	if parent == null:
		return
	var p: Pickup = Pickup.new()
	parent.add_child(p)
	p.game = game
	p.setup(pos, kind, 1, plr)

## Debugger / checklist : pose une bombe ou un aimant sans attendre le tirage.
func debug_drop_phase1(kind: String, pos: Vector2, game: Node, plr: Node2D) -> void:
	_spawn_phase1_pickup(pos, kind, game, plr)


