extends Node2D
## Run orchestrator: builds the arena, player, spawner, HUD; owns pools/containers,
## weapon fire, in-engine FX (muzzle flash, damage numbers, hit sparks, screen
## shake), the level-up draft, and the death/result flow. Also a headless autoplay
## bot that drives the real loop (move/fire/kill/pickup/level-up + draft UI) and
## quits with an exit code so CI can catch regressions.

var player: Player
var spawner: EnemySpawner
var hud: HUD
var cam: Camera2D
var enemy_layer: Node2D
var projectile_layer: Node2D
var pickup_layer: Node2D
var fx_layer: Node2D

var _shake: float = 0.0
var _dmg_active: int = 0
var _headless: bool = false
# 04/10 tour 2 : boite a outils VFX premium (couches coeur/onde/etincelles/fumee/traces au sol).
const FxKit = preload("res://scenes/FxKit.gd")
var _biome: int = 0
const CAM_OFFSET: Vector2 = Vector2(0.0, -84.0)   # view pushed up -> player ~60% down-screen

# ARENA MODE. BOUNDED = walled arena (clamp + border ring + fixed decor). !BOUNDED = the original
# INFINITE streaming map (no wall, decor streams around the player). Reverted to infinite per the
# patron: fleeing is possible again, mitigated only by the spawn-ahead rule. The bounded code is
# kept intact behind this switch, so flipping it back is one line.
const BOUNDED: bool = false
const ARENA_HALF: float = 3000.0        # only used when BOUNDED
const ARENA_WALL_IN: float = 190.0      # clamp inset -> you stop AT the visible wall face
const ARENA_CLAMP: float = ARENA_HALF - ARENA_WALL_IN
var _hitstop: bool = false
# 8 biome maps (Gemini-generated ground textures in assets/decor/ground_<name>.png)
# NOTE: "ruines" (ville detruite) is PARKED — the art didn't hold up, we'll revisit it later.
# Its ground texture, decor and BIOME_DECOR entry all stay on disk: re-adding it here is enough.
const BIOMES: Array = ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "cryo", "reacteur", "ruche", "citadelle", "abyss", "ether", "titans", "orbit", "quantum", "ozone", "prism", "steampunk", "colosseum"]
# PROGRESSION façon Survivor.io : 5 chapitres qui se débloquent en chaîne. Chaque chapitre = un
# biome fixe + un palier de difficulté + un palier de puissance conseillé (gate). Battre le boss
# final d'un chapitre (mode campagne) débloque le suivant + donne une récompense de 1er clear.
const CHAPTERS: Array = [
	{"name": "L'Usine",          "sub": "Le Reveil",       "biome": "tech",     "diff": 0, "gate": 1000},
	{"name": "Terres Calcinees", "sub": "La Traversee",    "biome": "desert",   "diff": 1, "gate": 2500},
	{"name": "La Ruine Verte",   "sub": "L'Enlisement",    "biome": "jungle",   "diff": 1, "gate": 5000},
	{"name": "La Forge",         "sub": "Le Coeur Ardent", "biome": "volcanic", "diff": 2, "gate": 9000},
	{"name": "La Cite Dechue",   "sub": "Le Souverain",    "biome": "swamp",    "diff": 3, "gate": 15000},
	# 03/10, suite demandee par le patron (plan "15 maps") : 4 chapitres bonus post-campagne, tous
	# a la difficulte MAX (pas de palier au-dela de VETERAN) - verifie INOFFENSIF avant d'ajouter :
	# chapter_unlocked()/clear_chapter() (SaveManager.gd) lisent un simple compteur, aucun "5" en
	# dur ; le seul "5" en dur vivait dans MetaScreen.gd (corrige dans le meme lot). "gate" n'est
	# deja lu nulle part (bug connu, cf. commentaire plus bas) : garde seulement pour la coherence
	# visuelle avec les 5 chapitres existants.
	{"name": "Le Cryo-Laboratoire",  "sub": "Le Sommeil Froid",            "biome": "cryo",      "diff": 3, "gate": 22000},
	{"name": "Le Noyau Instable",    "sub": "Le Compte a Rebours",         "biome": "reacteur",  "diff": 3, "gate": 28000},
	{"name": "La Ruche",             "sub": "Ce Qui Grandit Dans l'Ombre", "biome": "ruche",     "diff": 3, "gate": 34000},
	{"name": "La Citadelle Orbitale","sub": "La Forge Finale",             "biome": "citadelle", "diff": 3, "gate": 40000},
	{"name": "Les Abysses",          "sub": "La Cité Engloutie",           "biome": "abyss",     "diff": 3, "gate": 46000},
	{"name": "Forêt Psychédélique",  "sub": "Les Spores Luissantes",       "biome": "ether",     "diff": 3, "gate": 52000},
	{"name": "La Nécropole d'Acier", "sub": "Sanctuaire Titans",           "biome": "titans",    "diff": 3, "gate": 58000},
	{"name": "Le Champ Orbital",     "sub": "Dérive Zéro-G",               "biome": "orbit",     "diff": 3, "gate": 64000},
	{"name": "Archives Quantiques",  "sub": "La Matrice Pure",             "biome": "quantum",   "diff": 3, "gate": 70000},
	{"name": "Faille d'Ozone (Orage)", "sub": "L'Orage Perpétuel",          "biome": "ozone",     "diff": 3, "gate": 76000},
	{"name": "Grotte Prismatique",   "sub": "Les Grottes Réfringentes",    "biome": "prism",     "diff": 3, "gate": 82000},
	{"name": "Le Bastion Vapeur",    "sub": "Bastion Stellaire",           "biome": "steampunk", "diff": 3, "gate": 88000},
	{"name": "Le Colisée Virtuel",   "sub": "L'Épreuve Finale",            "biome": "colosseum", "diff": 3, "gate": 95000},
]
var _chapter: int = 1   # chapitre campagne en cours (1-based)
# Each biome is GAMEPLAY, not just cosmetic: speed/spawn modifiers + optional ground hazard.
const BIOME_MODS: Dictionary = {
	"tech":      {"label": "SECTEUR TECH"},
	"earth":     {"label": "FRICHE"},
	"spaceship": {"label": "GRAVITE FAIBLE  —  tout va plus vite", "player_speed_mult": 1.15, "enemy_speed_mult": 1.12, "player_proj_speed": 1.3},
	"volcanic":  {"label": "VOLCAN  —  eruptions de lave", "hazard": "lava"},
	"desert":    {"label": "DESERT  —  ennemis enrages (+18% vit.)", "enemy_speed_mult": 1.18},
	"ice":       {"label": "GLACE  —  sol glissant", "enemy_speed_mult": 0.8, "player_inertia": 0.82},
	"jungle":    {"label": "JUNGLE  —  nuees denses (+35%)", "enemy_spawn_mult": 1.35},
	"swamp":     {"label": "MARAIS  —  tout est englue", "enemy_speed_mult": 0.85, "player_speed_mult": 0.9},
	"ruines":    {"label": "VILLE EN RUINES  —  champ de bataille robotique"},
	"cryo":      {"label": "ZONE CRYO  —  laboratoire gele"},
	"reacteur":  {"label": "NOYAU INSTABLE  —  reacteur en surchauffe"},
	"ruche":     {"label": "BIOMECANIQUE  —  la ruche respire"},
	"citadelle": {"label": "FORGE FINALE  —  citadelle orbitale"},
	"abyss":     {"label": "CITÉ SUBMERGÉE  —  ruines abyssales", "player_speed_mult": 0.88},
	"ether":     {"label": "FORÊT PSYCHÉDÉLIQUE  —  canopée fongique bioluminescente"},
	"titans":    {"label": "NÉCROPOLE DES TITANS  —  cimetière d'acier colossal"},
	"orbit":     {"label": "CHAMP ORBITAL  —  gravité zéro & débris spatiaux", "player_speed_mult": 1.12, "player_proj_speed": 1.25},
	"quantum":   {"label": "ARCHIVES QUANTIQUES  —  matrice de données & réfractions"},
	"ozone":     {"label": "FAILLE D'OZONE (ORAGE)  —  orage ionique perpétuel"},
	"prism":     {"label": "GROTTE PRISMATIQUE  —  cavernes de quartz réflectif"},
	"steampunk": {"label": "BASTION VAPEUR  —  usine victorienne d'airain & de laiton"},
	"colosseum": {"label": "COLISÉE VIRTUEL  —  arène tactique de calibrage militaire"},
}
## Flavour lines for the per-map intro/outro cutscenes (see _map_intro / _map_outro). One short
## line each; the intro title is the biome label, the outro title is a generic victory banner.
const CUT_LINES: Dictionary = {
	"tech":      {"in": "La cite-machine est tombee. Quelque chose bouge encore dans les neons.", "out": "Le silence revient sur les tours mortes."},
	"earth":     {"in": "La nature a repris la ruine. Les charognards aussi.", "out": "La friche respire de nouveau."},
	"spaceship": {"in": "Gravite defaillante. L'epave derive, et elle n'est pas vide.", "out": "L'epave se tait. Cap sur les etoiles."},
	"volcanic":  {"in": "La fournaise ne pardonne pas. Eux non plus.", "out": "Les flammes retombent. Tu tiens encore debout."},
	"desert":    {"in": "Rien ne survit ici, sauf ce qui te chasse.", "out": "La tempete est passee. Toi aussi."},
	"ice":       {"in": "Le gel ralentit tout. Ne baisse pas ta garde.", "out": "Le blizzard s'apaise. Ton coeur brule encore."},
	"jungle":    {"in": "La jungle grouille. Ils sont partout.", "out": "La canopee s'illumine, paisible enfin."},
	"swamp":     {"in": "Tout englue. Chaque pas est un combat.", "out": "La brume se leve sur la vase."},
	"cryo":      {"in": "Le froid a tout fige ici. Meme la lumiere semble lente.", "out": "Le givre se depose. Le calme, enfin."},
	"reacteur":  {"in": "Le noyau respire mal. Chaque alarme est un compte a rebours.", "out": "Le coeur se stabilise. Pour l'instant."},
	"ruche":     {"in": "Les parois pulsent. Quelque chose grandit ici, et ca ne dort pas.", "out": "La ruche se tait. Pour combien de temps ?"},
	"citadelle": {"in": "La citadelle orbitale tourne encore. Le vide n'attend personne.", "out": "La forge se refroidit. Le silence a un poids, ici."},
	"abyss":     {"in": "La pression des abysses broie les coques. Les néons bleus percent l'obscurité.", "out": "L'océan s'apaise. Les secrets engloutis demeurent."},
	"ether":     {"in": "Des spores incandescentes flottent dans l'air lourd. La forêt observe chaque pas.", "out": "La brume d'éther se disperse sous vos tirs."},
	"titans":    {"in": "Des carcasses d'automates géants dorment sous la rouille. Quelque chose veille encore.", "out": "Les colosses de fer s'effondrent enfin dans le silence."},
	"orbit":     {"in": "La station est en morceaux. Le silence de l'espace est brisé par les arcs IEM.", "out": "L'orbite est nettoyée. Cap vers l'infini."},
	"quantum":   {"in": "Les serveurs d'obsidienne vibrent de code pur. La matrice calcule votre fin.", "out": "Les algorithmes s'éteignent. Les données sont purgées."},
	"ozone":     {"in": "La foudre déchire le ciel sans fin. L'air sent l'ozone et le plasma brûlé.", "out": "L'orage s'éloigne. La terre ionisée fume encore."},
	"prism":     {"in": "Les cristaux démultiplient chaque reflet et chaque tir. La lumière est une arme.", "out": "Les géodes scintillent doucement dans le calme retrouvé."},
	"steampunk": {"in": "Le grondement des pistons résonne dans la vapeur brûlante. L'industrie ne dort jamais.", "out": "Les cheminées cessent de fumer. La machinerie est vaincue."},
	"colosseum": {"in": "Les projecteurs de l'arène s'allument. L'épreuve suprême commence.", "out": "Victoire écrasante. Le protocole d'exercice est validé."},
}
## 04/10, trou signale par le patron : la derive d'une map a l'autre a l'interieur d'un chapitre
## (PropScatter.BIOME_MAP_SEGMENTS / current_map_phase) etait 100% silencieuse - rien ne la
## distinguait du changement de biome (deja annonce par next_map()). Noms repris du document "15
## maps" source, un triplet par biome "15 maps" uniquement (les biomes plus anciens n'ont pas de
## decoupage par map -> absents ici, _map_phase_shown reste simplement a -1 pour eux).
const MAP_PHASE_NAMES: Dictionary = {
	"tech":      ["Hall d'Assemblage", "Fonderie des Pistons", "Quai de Chargement"],
	"desert":    ["Dunes de Silice", "Mer de Verre", "Cratère Solaire"],
	"jungle":    ["Lisière Envahie", "Canopée Profonde", "Cœur Végétal"],
	"volcanic":  ["Failles de Lave", "Haut Fourneau", "Cœur de Magma"],
	"swamp":     ["Quartiers Noyés", "Ponts Submergés", "Centre Inondé"],
	"cryo":      ["Cryo-Voute", "Serres Gelees", "Lac de Permafrost"],
	"reacteur":  ["Bassins Toxiques", "Salle des Turbines", "Noyau Fissure"],
	"ruche":     ["Couvoir Mecanique", "Veines Vivantes", "Jardin de Spores"],
	"citadelle": ["Pont Orbital", "Anneau de Gravite", "Chambre de la Forge"],
	"abyss":     ["Quais Immergés", "Faille Abyssale", "Nécropole Sous-Marine"],
	"ether":     ["Sous-Bois Toxique", "Canopée Luminescente", "Cœur de Mycélium"],
	"titans":    ["Fosse des Châssis", "Chantier des Cuirassés", "Trône du Roi d'Acier"],
	"orbit":     ["Sas Dépressurisé", "Champ de Panneaux", "Noyau de Propulsion"],
	"quantum":   ["Portail Vectoriel", "Couloirs de Monolithes", "Sanctuaire du Noyau"],
	"ozone":     ["Plaine des Fulgurites", "Pylônes Parafoudres", "Œil de la Tempête"],
	"prism":     ["Galerie de Silice", "Forêt de Calcite", "Chambre Réfringente"],
	"steampunk": ["Fonderie de Cuivre", "Salle des Soupapes", "Beffroi d'Horlogerie"],
	"colosseum": ["Gradins Blindés", "Fosse d'Échauffement", "Noyau des Champions"],
}
var _map_phase_shown: int = -1   # -1 = rien affiche encore ce run ; reset a chaque nouveau biome
var _mods: Dictionary = {}
var _cut_seen: Dictionary = {}   # per-run guard: a biome's intro/outro panel shows once per run
var _hazard: String = ""
var _hazard_t: float = 0.0
var _proj_pool: Array = []      # recycled Projectile nodes (no queue_free in the hot loop)
var _enemy_proj_pool: Array = []   # balles ennemies recyclees (fix latence : plus de new/queue_free en boucle)
var _pickup_pool: Array = []    # recycled Pickup nodes (xp/scrap/bonus)
var _revived: bool = false      # one watch-ad revive per run
var _banked: bool = false       # run scrap banked into meta wallet exactly once
var last_crystals: int = 0      # cristaux earned by the run just ended (shown on the results screen)
var last_sp: int = 0            # skill points earned by the run just ended (shown on results)


var _cmod: CanvasModulate
var _ambient: Ambient = null
var _plight: PointLight2D
## Headless smoke normally ends at frame 1400 (a short vertical slice). The SANS FIN regression
## (`-- --fast-bosses`) needs a long soak so waves can actually accumulate.
## La variable d'environnement MF_FRAMES permet une partie LONGUE *sans* compresser l'horloge
## des boss : c'est ce qu'il faut pour mesurer une vraie courbe de difficulte (1400 images =
## 12 s de jeu, beaucoup trop court pour juger quoi que ce soit).
## 🚨 parse defensif : `int("abc")` rend 0 en GDScript, ce qui terminerait la partie a l'image 0.
@onready var _headless_frames: int = _frames_budget()

func _frames_budget() -> int:
	if OS.get_cmdline_user_args().has("--fast-bosses"):
		return 30000
	var mf: String = OS.get_environment("MF_FRAMES")
	if mf.is_valid_int() and int(mf) > 0:
		return int(mf)
	return 1400
## `-- --perf` prints live node/object counts. FX allocation is this game's dominant cost, so a
## number beats an intention — every optimisation claim should be checked against this.
@onready var _perf: bool = OS.get_cmdline_user_args().has("--perf")
var _perf_last_obj: int = 0
var _maps_cleared: int = 0       # zones cleared (each = a permanent difficulty step up)
var _mort_t: float = 0.0         # temps ecoule depuis la mort (arret anticipe du banc headless)
var _bot: bool = false
var _frames: int = 0
var _draft_open: bool = false
var _pending_drafts: int = 0   # level-ups earned while a draft is already open (queued, not dropped)
var _cards: Array = []
var _rerolls: int = 3          # reroll charges per run (agency over the draft)
var _banishes: int = 2         # banish charges: remove a card from the run's pool
var _banished: Array = []      # upgrade ids banished for this run
var _passives: Dictionary = {} # picked upgrade ids -> count (evolution eligibility)
var _hyb_slots_freed: int = 0  # nb de fusions hybrides cette run -> compense _slots_used("act")
var _floor_mat: ShaderMaterial
# Weapon EVOLUTIONS: base weapon at MAX level + a condition -> evolved form.
# 🚨 29/09, plan de refonte (rapport externe) : la condition etait auparavant "avoir pioche au
# moins 1 fois telle carte d'amelioration cette run" (_passives.has(...)). Remplacee par une
# condition TYPEE, verifiee par _evo_cond_met() : soit un niveau de competence META PERSISTANT
# (SaveManager.meta_level, achete entre les parties), soit un nombre de KILLS avec CETTE arme
# (GameState.kills_by_weapon, cf. Enemy.take_damage/GameState.add_kill). 5 armes reprennent la
# condition du rapport (Puissance/Agilite/Cupidite/Surcharge) ; les 4 non couvertes par le
# rapport (missilepod/railgun/disperseur/ricochet) passent en kills, seuils de 1ere passe.
const EVO_RULES: Dictionary = {
	"autocannon": {"cond": {"type": "meta", "key": "puissance", "level": 3}, "evo": "vulcan", "name": "EVOLUTION : Vulcan (barrage)"},
	"missilepod": {"cond": {"type": "kills", "count": 25}, "evo": "hydra", "name": "EVOLUTION : Hydra (essaim)"},
	"railgun": {"cond": {"type": "kills", "count": 30}, "evo": "annihilator", "name": "EVOLUTION : Annihilateur"},
	"plasma": {"cond": {"type": "meta", "key": "surcharge", "level": 2}, "evo": "singularity", "name": "EVOLUTION : Singularite"},
	"sabre": {"cond": {"type": "meta", "key": "agilite", "level": 2}, "evo": "tempest", "name": "EVOLUTION : Tempete (360)"},
	"disperseur": {"cond": {"type": "kills", "count": 25}, "evo": "deflagrateur", "name": "EVOLUTION : Deflagrateur"},
	"ricochet": {"cond": {"type": "kills", "count": 30}, "evo": "carambole", "name": "EVOLUTION : Carambole"},
	"disque": {"cond": {"type": "meta", "key": "agilite", "level": 3}, "evo": "guillotine", "name": "EVOLUTION : Guillotine"},
	"faisceau": {"cond": {"type": "meta", "key": "cupidite", "level": 3}, "evo": "rayon_spectre", "name": "EVOLUTION : Rayon Spectre"},
}

## ARMES HYBRIDES (plan de refonte, 29/09) : fusionne DEUX armes de base MAX (jamais 1 seule
## comme une evolution) en une arme neuve, via WeaponSystem.merge_weapons(). Paires choisies pour
## que les 7 chassis a arsenal restreint (GameState.MECHS) aient chacun acces a au moins une
## hybridation — priorite a l'equite entre chassis, pas aux paires du rapport externe (qui en
## laissait 2 sur 7 sans AUCUN acces). Ni l'une ni l'autre ne touche BEAM/MELEE : uniquement des
## entrees de dictionnaires dans WeaponSystem.gd, aucun code neuf dans _do_beam/_do_melee.
const HYBRID_RULES: Array = [
	{"pair": ["railgun", "plasma"], "evo": "rail_nova", "name": "FUSION : Rail-Nova (perce + zone)"},
	{"pair": ["missilepod", "ricochet"], "evo": "frelon", "name": "FUSION : Frelon (chercheur + rebonds)"},
]

const UPGRADES: Array = [
	{"id": "dmg", "name": "+25% Degats"},
	{"id": "spd", "name": "+12% Vitesse"},
	{"id": "hp", "name": "+25 PV max (+soin)"},
	{"id": "haste", "name": "+12% Cadence de tir"},
	{"id": "crit", "name": "+8% Chance de critique"},
	{"id": "armor", "name": "+8% Armure"},
	{"id": "magnet", "name": "Aimant a XP  (+portee)"},
	{"id": "he_fuel", "name": "Carburant HE  (+taille & portee)"},   # HE Fuel : projectiles+effets plus gros
	{"id": "ammo", "name": "Propulseur de munitions  (+vitesse tirs)"},  # Ammo Thruster
	{"id": "regen", "name": "Regeneration  (+PV / s)"},                # Energy Drink
	{"id": "xpgain", "name": "Parchemin ninja  (+15% EXP)"},           # Koga Ninja Scroll
	{"id": "goldgain", "name": "Liaison a huile  (+20% Or)"},          # Oil Bond
	{"id": "w_autocannon", "name": "Arme : Autocanon"},
	{"id": "w_missile", "name": "Arme : Missiles chercheurs"},
	{"id": "w_railgun", "name": "Arme : Railgun percant"},
	{"id": "w_plasma", "name": "Arme : Plasma (zone)"},
	{"id": "w_sabre", "name": "Arme : Sabre (melee, arc)"},
	{"id": "w_disperseur", "name": "Arme : Disperseur (gerbe)"},
	{"id": "w_ricochet", "name": "Arme : Ricochet (rebonds)"},
	{"id": "w_disque", "name": "Arme : Disque (aller-retour)"},
	{"id": "w_faisceau", "name": "Arme : Faisceau (rayon)"},
	{"id": "aura", "name": "Bouclier a impulsions (+rayon)"},   # damaging ring, grows each pick
	{"id": "drone", "name": "Drone de combat (+1)"},            # stackable orbiting auto-turret
	{"id": "blade", "name": "Lame orbitale (+1)"},              # spinning contact-damage blade
	{"id": "orb", "name": "Orbe plasma - charge/decharge (+1)"},# orbiting AoE burst
	{"id": "arc", "name": "Arc Tesla  (eclair en chaine)"},     # chain lightning (role Lightning, maison)
	{"id": "pool", "name": "Brasier plasma  (mare au sol)"},    # burning ground pool (role Molotov, maison)
]
# maps a weapon draft-card id -> its WeaponSystem id (for showing the current level on the card)
const _WEAPON_CARD: Dictionary = {"w_autocannon": "autocannon", "w_missile": "missilepod", "w_railgun": "railgun", "w_plasma": "plasma",
	"w_sabre": "sabre", "w_disperseur": "disperseur", "w_ricochet": "ricochet",
	"w_disque": "disque", "w_faisceau": "faisceau"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep orchestrating (bot/draft) while the tree is paused
	EnemyProjectile._smoke_active = 0   # reset des compteurs statiques (sinon ils fuient entre runs)
	EnemyProjectile._active_missiles = 0
	EnemyProjectile._tires_bench = 0    # 🚨 TEMPORAIRE (banc du 23/09), voir declaration
	PropScatter._detruits_bench = 0     # 🚨 TEMPORAIRE (banc du 23/09), voir declaration
	Player._emprunts_bench = 0          # 🚨 TEMPORAIRE (banc du 23/09), voir declaration
	Player._rendus_bench = 0
	Enemy._bulls_charging = 0
	Enemy._arcs_armes = 0
	Enemy._arcs_pic = 0      # statique : sans remise a zero, le plafond d'arcs se referme d'une partie a l'autre
	Enemy._palier_max_run = 0   # statique : sans remise a zero, la 2e partie ne tracerait rien
	# BANC : `-- --arme=N` fige le palier d'arme des ennemis. Sans ca, verifier le palier 3
	# demanderait de survivre 135 s a chaque essai — donc je ne le verifierais jamais.
	Enemy._palier_force = -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arme="):
			var v: String = a.substr(7)
			if v.is_valid_int():
				Enemy._palier_force = clampi(int(v), 0, 3)
				print("[game] ARME FORCEE palier=%d" % Enemy._palier_force)
		elif a.begins_with("--mech="):
			# banc headless : sans ca, un chassis fraichement ajoute (cout > 0, jamais possede sur
			# une sauvegarde vierge) ne serait JAMAIS equipe par le bot -> son code reste mort dans
			# tous les tests. 🚨 la 1ere version ecrivait dans SaveManager.data (owned_mechs +
			# equipped_mech) -> une simple ecriture de sauvegarde plus tard (fin de run, etc.)
			# PERSISTAIT ce choix sur le vrai fichier user://, contaminant les runs manuels suivants
			# (verifie : equipped_mech="cerclier" retrouve sur MECHA-FORGE/mecha_forge_save.json
			# apres un seul banc). Purement en memoire desormais, jamais ecrit sur disque.
			var mid: String = a.substr(7)
			if GameState.mech_def(mid):
				GameState.debug_force_mech = mid
				print("[game] MECH FORCE id=%s (memoire seule, jamais sauvegarde)" % mid)
	randomize()   # vary the biome (and other RNG) per run
	RenderingServer.set_default_clear_color(Palette.ARENA_BG)
	GameState.reset()
	Protocols.roll()   # roll this run's combat modifiers (freshness engine) — before player/enemies spawn
	_headless = DisplayServer.get_name() == "headless"
	_bot = _headless or OS.get_cmdline_user_args().has("--autoplay")
	if not _headless:
		_prewarm_fx()   # genere les textures FX procedurales MAINTENANT, pas au 1er impact (saccade)

	Audio.apply_settings()                                   # music/sfx mute from saved settings
	_apply_orientation(String(SaveManager.setting("orientation", "auto")))

	_build_environment()
	enemy_layer = _mk_layer()
	projectile_layer = _mk_layer()
	pickup_layer = _mk_layer()
	fx_layer = _mk_layer()
	# Game is PROCESS_MODE_ALWAYS (keeps orchestrating bot/draft while paused). Its INHERIT
	# children would inherit ALWAYS too, so get_tree().paused would NOT freeze the sim — enemies
	# kept moving/spawning behind the difficulty menu and during level-up drafts. Mark the sim
	# layers PAUSABLE so a real pause actually stops the action (overlays stay ALWAYS to stay live).
	enemy_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	projectile_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	# The layers are plain siblings, so they draw in tree order and `player` is added AFTER
	# fx_layer -> every VFX (saber slash, muzzle flash, the impact when the player is hit) was
	# painted UNDER the mech and vanished behind it. Lift the FX above the actors so they read
	# ON the sprite. Stays below the overdrive beam (60) and the point lights (100).
	fx_layer.z_index = 40

	player = Player.new()
	player.game = self
	player.bot_active = _bot
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE   # freeze the mech while paused
	player.collision_mask = 8   # collide with cover props (StaticBody layer 8)
	
	if not _headless:
		_cmod = CanvasModulate.new()
		_cmod.color = Color.WHITE
		add_child(_cmod)
		
		_plight = PointLight2D.new()
		_plight.texture = Tex.glow(Color.WHITE, 384)
		_plight.texture_scale = 1.0
		_plight.energy = 0.0
		_plight.blend_mode = Light2D.BLEND_MODE_ADD
		player.add_child(_plight)

	cam = Camera2D.new()
	# The camera is a CHILD of the player, so it already follows exactly. Smoothing on a child
	# camera makes it lag/rubber-band behind, which reads as the whole world (decor) DRIFTING
	# while you move. Off = the scenery stays rock-solid under the mech.
	cam.position_smoothing_enabled = false
	cam.offset = CAM_OFFSET   # push the view up so the player sits ~60% down (thumb clears the south)
	if BOUNDED:
		# Stop the view at the walls (global-space limits work even on a player-child camera).
		var lim: int = int(ARENA_HALF + 170.0)
		cam.limit_left = -lim; cam.limit_top = -lim; cam.limit_right = lim; cam.limit_bottom = lim
	player.add_child(cam)
	if BOUNDED:
		player.arena_half = ARENA_CLAMP   # hard clamp: the player cannot pass the wall
	# 🚨 27/09 : zoom jamais fixe nulle part -> restait (1,1) quel que soit le viewport. En stretch
	# canvas_items/expand (voir project.godot), le rect visible SUIT les pixels reels de la fenetre :
	# sur un ecran etroit/portrait, ca ne redimensionne pas la vue, ca en montre une TRANCHE plus
	# etroite -- exactement l'inverse de ce que la lisibilite des telegraphes (annonce -> esquive)
	# suppose. Meme idiome que HUD._k() (base 720 = le cote court du canevas de concu 1280x720),
	# mais jamais > 1.0 : le desktop reste au zoom deja teste toute la session, seuls les ecrans plus
	# etroits que 720 dans leur plus petite dimension sont compenses (dezoome) pour retrouver la
	# meme largeur de terrain visible que celle sur laquelle tout a ete regle.
	_update_cam_zoom()
	if not get_viewport().size_changed.is_connected(_update_cam_zoom):
		get_viewport().size_changed.connect(_update_cam_zoom)

	_ambient = Ambient.new()
	add_child(_ambient)
	_ambient.setup(player)
	_ambient.apply_biome(BIOMES[clampi(_biome, 0, BIOMES.size() - 1)])
	_apply_biome_lighting(BIOMES[clampi(_biome, 0, BIOMES.size() - 1)])

	spawner = EnemySpawner.new()
	spawner.game = self
	spawner.player = player
	if BOUNDED:
		spawner.arena_half = ARENA_CLAMP   # enemies pile up at the wall instead of spawning past it
	spawner.speed_mult = float(_mods.get("enemy_speed_mult", 1.0))
	spawner.spawn_mult = float(_mods.get("enemy_spawn_mult", 1.0))
	spawner.current_biome = BIOMES[clampi(_biome, 0, BIOMES.size() - 1)]   # pool d'ennemis du biome
	spawner.enemy_tint = EnemySpawner.BIOME_TINT.get(spawner.current_biome, Color(1, 1, 1))  # corruption
	spawner.chapter = _chapter   # SANS FIN garde 1 (defaut, jamais reecrit) ; _on_chapter_chosen() le corrige pour la campagne
	add_child(spawner)
	spawner.process_mode = Node.PROCESS_MODE_PAUSABLE   # no spawns behind the menu / during drafts
	player.move_mult = float(_mods.get("player_speed_mult", 1.0))
	player.biome_proj_speed = float(_mods.get("player_proj_speed", 1.0))
	player.inertia = float(_mods.get("player_inertia", 0.0))

	hud = HUD.new()
	add_child(hud)
	hud.setup(player)
	hud.visible = _bot   # hidden on the HOME hub / difficulty screen; shown when the run begins
	hud.card_picked.connect(_on_card_picked)
	hud.reroll_requested.connect(_reroll_draft)
	hud.banish_requested.connect(_on_banish)

	Events.screen_shake.connect(func(a: float) -> void: _shake = maxf(_shake, a))
	Events.hit_spark.connect(_on_hit_spark)
	Events.damage_dealt.connect(func(pos: Vector2, amt: int, crit: bool) -> void: _damage_number(pos, amt, crit))
	Events.level_up.connect(func(_l: int) -> void: _open_draft())
	Events.level_up.connect(func(_l: int) -> void: _level_fx())
	Events.player_died.connect(_on_player_died)
	Events.run_won.connect(_on_run_won)
	Events.overdrive_changed.connect(_on_overdrive_hint)   # explique la SURCHARGE la 1re fois
	if _headless:
		Events.player_transformed.connect(func(on: bool) -> void: print("[game] TRANSFORM ", on))
		Events.run_won.connect(func() -> void: print("[game] VICTORY"))
		var _pn: Array = []
		for _p in Protocols.active:
			_pn.append(String(_p.get("name", "?")))
		print("[game] PROTOCOLES %s | spawn=%.2f hp=%.2f dmg=%.2f spd=%.2f reward=%.2f pspeed=%.2f | diff=%s" % [
			", ".join(_pn), Protocols.spawn_rate, Protocols.enemy_hp, Protocols.enemy_dmg,
			Protocols.enemy_speed, Protocols.reward, Protocols.player_speed,
			String(GameState.diff().get("name", "?"))])

	# Flow: bot -> straight into a run. Player -> HOME hub (play / meta) -> difficulty -> run.
	# REJOUER sets skip_hub so a retry is ONE tap: reload (clean state, no manual teardown of
	# enemies/projectiles/props) then drop straight back in at the same difficulty.
	if _bot or GameState.skip_hub:
		GameState.skip_hub = false
		_begin_run()
	else:
		_show_home()

## Called by the results screen's REJOUER. The reload is what guarantees a clean run; skip_hub is
## what makes it feel instant.
func restart_run() -> void:
	GameState.skip_hub = true
	get_tree().paused = false
	get_tree().reload_current_scene()

## The launch hub (title, currencies, meta systems, JOUER). Reused MetaScreen in "home" mode so
## the between-runs shop/garage/gear live in one place. JOUER -> difficulty select -> run.
func _show_home() -> void:
	# 🚨 AUCUNE musique ne jouait dans les menus ni dans la cinematique (B11) : Audio.music()
	# n'etait appele que par _biome_music(), donc uniquement une fois la partie lancee.
	# On pose la piste du secteur TECH des le hub : c'est aussi celle du chapitre 1, donc
	# l'enchainement menu -> partie est continu (music() ne fait rien si la piste est la meme).
	Audio.music("tech")
	# First launch ever: play the 6-panel origin story once, THEN reveal the menu.
	if not _bot and not bool(SaveManager.data.get("seen_intro", false)):
		SaveManager.data["seen_intro"] = true
		SaveManager.save_data()
		await _play_opening()
	var hs: MetaScreen = MetaScreen.new()
	add_child(hs)
	hs.setup_home(self)

## HISTOIRE depuis le hub : rejouer la cinematique d'ouverture PUIS revenir au menu.
## Sans ce retour on restait sur le decor de jeu, sans menu ni HUD, et il fallait
## recharger la page : le hub etait libere avant de lancer la cinematique et rien ne
## le recreait. On attend donc la fin des panneaux avant de rouvrir l'accueil.
func play_story_then_home() -> void:
	await _play_opening()
	_show_home()

## ---- in-engine map cutscenes (Survivor.io-style panels; see Cutscene.gd) ----
## Missing art or a bot/headless run -> silent no-op, so this is safe to call unconditionally and the
## smoke soak never stalls. Art lives in res://assets/cutscenes/<biome>_intro.png / _outro.png.
## 🚨 res://assets/cutscenes/ N'EXISTE PAS (verifie) : le repli affichait `hero_bg.png`,
## c'est-a-dire que le panneau « SECTEUR TECH » montrait litteralement LE FOND D'ECRAN DU MENU,
## identique pour les huit biomes (chasseur de bugs, B8). Nouveau repli, par ordre de verite :
##   1. l'illustration dediee si elle existe un jour ;
##   2. sinon le SOL reel du biome (assets/decor/ground_<biome>.png) — c'est vraiment ce secteur,
##      et chaque biome a donc enfin sa propre image ;
const BIOME_ART: Dictionary = {
	"tech": "res://assets/chapters/chap_1_tech.jpg",
	"desert": "res://assets/chapters/chap_2_desert.jpg",
	"jungle": "res://assets/chapters/chap_3_jungle.jpg",
	"volcanic": "res://assets/chapters/chap_4_volcanic.jpg",
	"swamp": "res://assets/chapters/chap_5_swamp.jpg",
	"cryo": "res://assets/chapters/chap_6_cryo.jpg",
	"reacteur": "res://assets/chapters/chap_7_reacteur.jpg",
	"ruche": "res://assets/chapters/chap_8_ruche.jpg",
	"citadelle": "res://assets/chapters/chap_9_citadelle.jpg",
	"abyss":     "res://assets/chapters/chap_10_abyss.jpg",
	"ether":     "res://assets/chapters/chap_11_ether.jpg",
	"titans":    "res://assets/chapters/chap_12_titans.jpg",
	"orbit":     "res://assets/chapters/chap_13_orbit.jpg",
	"quantum":   "res://assets/chapters/chap_14_quantum.jpg",
	"ozone":     "res://assets/chapters/chap_15_ozone.jpg",
	"prism":     "res://assets/chapters/chap_16_prism.jpg",
	"steampunk": "res://assets/chapters/chap_17_steampunk.jpg",
	"colosseum": "res://assets/chapters/chap_18_colosseum.jpg",
	"earth": "res://assets/chapters/chap_earth.jpg",
	"spaceship": "res://assets/chapters/chap_spaceship.jpg",
	"ice": "res://assets/chapters/chap_ice.jpg",
}

func _load_cut(fname: String) -> Texture2D:
	var p: String = "res://assets/cutscenes/%s.png" % fname
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	var biome: String = fname.replace("_intro", "").replace("_outro", "")
	if BIOME_ART.has(biome):
		var art_path: String = String(BIOME_ART[biome])
		if ResourceLoader.exists(art_path):
			return load(art_path) as Texture2D
	return null

func _run_cutscene(panels: Array) -> void:
	var cut: Cutscene = Cutscene.new()
	add_child(cut)
	cut.play(panels)
	await cut.finished

func _map_intro(biome: String) -> void:
	if _bot or _cut_seen.get("in_" + biome, false):
		return
	var tex: Texture2D = _load_cut(biome + "_intro")
	if tex == null:
		return
	_cut_seen["in_" + biome] = true
	var lbl: String = String(BIOME_MODS.get(biome, {}).get("label", biome.to_upper()))
	var line: String = String(CUT_LINES.get(biome, {}).get("in", ""))
	await _run_cutscene([{"tex": tex, "title": lbl, "text": line, "ken": "in"}])

func _map_outro(biome: String) -> void:
	if _bot or _cut_seen.get("out_" + biome, false):
		return
	var tex: Texture2D = _load_cut(biome + "_outro")
	if tex == null:
		return
	_cut_seen["out_" + biome] = true
	var line: String = String(CUT_LINES.get(biome, {}).get("out", ""))
	await _run_cutscene([{"tex": tex, "title": "SECTEUR PURGE", "text": line, "ken": "out"}])

func _load_menu(fname: String) -> Texture2D:
	var p: String = "res://assets/menu/%s.png" % fname
	return load(p) if ResourceLoader.exists(p) else null

## The 6-panel origin story (res://assets/menu/cine1..6.png), shown once on first launch.
func _play_opening() -> void:
	var caps: Array = [
		["UN MONDE EN CENDRES", "Les machines ont submerge le monde des hommes."],
		["LA FORGE OUBLIEE", "Dans les ruines dort un dernier geant d'acier."],
		["LE DERNIER PILOTE", "Un survivant tend la main vers son coeur eteint."],
		["LE REVEIL DU NOYAU", "Une etincelle cyan. Le geant ouvre les yeux."],
		["SEUL CONTRE LA HORDE", "Debout, encercle. Il ne reculera pas."],
		["MECHA-FORGE", "Survis. Forge ta legende."],
	]
	var kens: Array = ["in", "left", "in", "out", "right", "in"]
	var panels: Array = []
	for i in range(caps.size()):
		var tex: Texture2D = _load_menu("cine%d" % (i + 1))
		if tex != null:
			panels.append({"tex": tex, "title": caps[i][0], "text": caps[i][1], "ken": kens[i]})
	if not panels.is_empty():
		await _run_cutscene(panels)

# Kick off the actual run (biome banner + music). Called after the difficulty is chosen.
func _begin_run() -> void:
	if not _bot:
		await _map_intro(BIOMES[clampi(_biome, 0, BIOMES.size() - 1)])   # arrival panel for map 1
	if player != null and player.has_method("reset_input_state"):
		player.reset_input_state()
	if hud != null:
		hud.visible = true   # reveal the in-run HUD now that the fight starts
	var dname: String = String(GameState.diff().get("name", "NORMAL"))
	var lbl: String = String(_mods.get("label", ""))
	show_banner((lbl + "   [" + dname + "]") if lbl != "" else dname)
	_announce_protocols()   # sequenced AFTER the sector title (fire-and-forget coroutine)
	_first_run_hints()      # FTUE minimale, une seule fois dans la vie du joueur
	_biome_music()
	_play_intro()

## Announce this run's PROTOCOLES with the same banner system as the sector title, but sequenced
## after it so the two never share the screen. Not awaited — it must not delay _play_intro.
func _announce_protocols() -> void:
	if _bot or Protocols.active.size() == 0:
		return
	await get_tree().create_timer(3.5).timeout   # let the sector-title banner finish (~3.4s)
	if not is_inside_tree():
		return
	var pcol: Color = Color(Protocols.active[0].get("color", Color(0.95, 0.78, 0.4)))
	# 🚨 le glyphe ◈ (U+25C8) est absent de Rajdhani : il s'affichait en carre vide avec son
	# code hexa, en plein ecran, a chaque annonce de protocole. Remplace par « • » (present).
	show_banner("• " + Protocols.banner_text(), pcol)
	# ... et ce qu'ils FONT : le nom seul ne disait rien d'un modificateur qui peut doubler
	# le nombre d'ennemis. Le detail passe par show_hint (il fait des phrases, pas des titres).
	await get_tree().create_timer(3.5).timeout   # la banniere du nom a fini, l'indice de
	if is_inside_tree():                         # deplacement aussi (il se termine a 5,8 s)
		show_hint(Protocols.desc_text(), pcol, 4.0)

# Run-start TELEPORT-IN: a light beam slams down, the mech materialises from an over-bright
# flash with a ground shockwave, brief invuln + a spawn hold so the entrance reads clean.
func _play_intro() -> void:
	if _headless or player == null:
		return
	var pos: Vector2 = player.global_position
	spawn_vfx("portal", pos, 0.0, 2.2, Color(0.7, 0.95, 1.2))   # teleport-in swirl
	player.grant_invuln(2.2)
	if spawner != null and spawner.has_method("delay_spawns"):
		spawner.delay_spawns(1.1)
	var col: Color = Color(0.6, 0.95, 1.0)
	var beam: Line2D = Line2D.new()
	beam.width = 30.0
	beam.default_color = Color(col.r, col.g, col.b, 0.9)
	beam.material = _add_mat()
	beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam.add_point(pos + Vector2(0.0, -1200.0))
	beam.add_point(pos)
	beam.z_index = 60
	beam.modulate = Color(1, 1, 1, 0)
	fx_layer.add_child(beam)
	var m = player.mecha
	if m != null:
		m.modulate = Color(1, 1, 1, 0)         # materialise from nothing
		m.set_tint(Color(2.4, 2.6, 3.0))       # over-bright while forming
	_ring(pos, col, 10.0, 300.0, 0.6)
	_light_pop(pos, col, 3.0, 0.6, 2.2)
	var tw: Tween = create_tween()
	tw.tween_property(beam, "modulate:a", 1.0, 0.12)   # beam slams down
	tw.tween_callback(func() -> void:
		_flash_sprite(pos, Color(0.85, 0.97, 1.0), 260.0, 0.4)
		_ring(pos, col, 20.0, 240.0, 0.5)
		_debris(pos, col, 18, 0.5, 120.0, 380.0)
		Events.screen_shake.emit(7.0))
	if m != null:
		tw.parallel().tween_property(m, "modulate:a", 1.0, 0.45)   # mech fades in
	tw.tween_interval(0.15)
	tw.tween_property(beam, "modulate:a", 0.0, 0.35)   # beam retracts + fades
	tw.parallel().tween_property(beam, "width", 4.0, 0.35)
	tw.tween_callback(func() -> void:
		if m != null:
			m.set_tint(Color.WHITE)
		beam.queue_free())

# Full-screen difficulty picker shown at run start.
func _show_difficulty_select() -> void:
	get_tree().paused = true
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 40
	cl.process_mode = Node.PROCESS_MODE_ALWAYS   # works while the tree is paused
	add_child(cl)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(bg)
	# CenterContainer sizes the menu to its content and centres it on ANY screen aspect
	# (portrait phone included) — no fixed offsets that pushed buttons off-screen before.
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = Palette.ui_theme()   # meme langage que les menus hors partie
	cl.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title: Label = Label.new()
	title.text = "CHOISIS TA DIFFICULTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", Palette.fs(32))
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	box.add_child(title)
	# --- MODE: campagne (boss final = victoire) vs sans fin (vagues infinies) ---
	var mode_btn: Button = Button.new()
	mode_btn.add_theme_font_size_override("font_size", Palette.fs(20))
	mode_btn.custom_minimum_size = Vector2(_panel_w(460.0), 50)
	var mode_desc: Label = Label.new()
	mode_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_desc.add_theme_font_size_override("font_size", Palette.fs(15))
	mode_desc.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	var paint_mode: Callable = func() -> void:
		var on: bool = bool(SaveManager.setting("endless", false))
		mode_btn.text = "MODE : SANS FIN" if on else "MODE : CAMPAGNE"
		mode_btn.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.3) if on else Color(0.6, 0.9, 1.0))
		mode_desc.text = ("Vagues infinies — chaque boss durcit la suite" if on
			else "15 min, boss final = victoire")
	paint_mode.call()
	mode_btn.pressed.connect(func() -> void:
		SaveManager.set_setting("endless", not bool(SaveManager.setting("endless", false)))
		paint_mode.call())
	box.add_child(mode_btn)
	box.add_child(mode_desc)
	var descs: Array = [
		"Foes plus faibles - pour decouvrir",
		"L'experience equilibree",
		"Foes coriaces, +30% recompenses",
		"Brutal - score x2.4",
	]
	var cur: int = SaveManager.get_difficulty()
	for i in GameState.DIFFICULTY.size():
		var d: Dictionary = GameState.DIFFICULTY[i]
		var b: Button = Button.new()
		b.text = "%s   —   %s" % [String(d["name"]), String(descs[i])]
		b.add_theme_font_size_override("font_size", Palette.fs(20))
		b.custom_minimum_size = Vector2(_panel_w(480.0), 64)
		if i == cur:
			b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		b.pressed.connect(_on_difficulty_chosen.bind(i, cl))
		box.add_child(b)
	# --- OPTIONS: a 2x2 grid of BIG touch toggles (fits portrait, comfortably tappable) ---
	var oh: Label = Label.new()
	oh.text = "— OPTIONS —"
	oh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oh.add_theme_font_size_override("font_size", Palette.fs(16))
	oh.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	box.add_child(oh)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	_add_toggle(grid, "music", "MUSIQUE", true)
	_add_toggle(grid, "sfx", "BRUITAGES", true)
	_add_toggle(grid, "auto_aim", "AUTO-VISEE", true)
	_add_toggle(grid, "lock_reticle", "VERROUILLAGE", true)
	_add_orient_toggle(grid)
	# Way out. Without it this screen was a dead end: _on_play() already freed the hub, so a
	# mis-tap on JOUER trapped the player into either a 15-minute run or killing the app.
	var back: Button = Button.new()
	back.text = "RETOUR"
	back.add_theme_font_size_override("font_size", Palette.fs(20))
	back.custom_minimum_size = Vector2(_panel_w(460.0), 50)
	back.pressed.connect(func() -> void:
		Audio.sfx("click")
		if is_instance_valid(cl):
			cl.queue_free()
		_show_home())
	box.add_child(back)
	# (headless/bot never reaches here: _ready calls _begin_run() directly for _bot)

## In-run settings panel (opened by the HUD's OPTIONS button). Pauses the game and reuses the
## same toggles as the start menu — they apply live (auto-aim updates the active player, music/sfx
## mute buses, orientation re-locks).
var _settings_open: bool = false

## Largeur utile d'un panneau plein ecran (reglages, choix de difficulte, choix de chapitre).
## 🚨 Ces ecrans etaient les SEULS du jeu a garder des largeurs EN DUR (460, 480, 520 px, et
## une grille de 2x240+10 = 490). Sur un telephone etroit ils sont plus larges que l'ecran :
## a 360 px de large, un bouton de 460 px deborde de 50 px de chaque cote — et CenterContainer
## centre sans redimensionner, donc le texte sort du cadre des deux cotes. Audit d'ergonomie :
## « le seul ecran du jeu qui n'utilise pas le facteur d'echelle ». Tout passe desormais par
## cette fonction, bornee a la largeur reelle moins une marge.
func _panel_w(voulu: float = 460.0) -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: float = clampf(minf(vp.x, vp.y) / 720.0, 0.62, 1.75)
	return minf(voulu * k, vp.x - 32.0)
## from_home = true : ouvert depuis le hub, pas en pleine partie.
## 🚨 Les reglages n'etaient joignables QUE par _show_difficulty_select(), or _on_play() appelle
## toujours _show_chapter_select() : cette branche n'etait JAMAIS executee. Consequence mesuree
## par le chasseur de bugs : impossible de couper la musique sans lancer une partie d'abord, et
## tout le mode SANS FIN etait du code mort. Le hub a maintenant son propre bouton REGLAGES.
func show_settings(from_home: bool = false) -> void:
	if _headless or _settings_open:
		return
	_settings_open = true
	get_tree().paused = true
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 45
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = Palette.ui_theme()   # meme langage que les menus hors partie
	cl.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title: Label = Label.new()
	title.text = "REGLAGES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", Palette.fs(32))
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	box.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	_add_toggle(grid, "music", "MUSIQUE", true)
	_add_toggle(grid, "sfx", "BRUITAGES", true)
	_add_toggle(grid, "auto_aim", "AUTO-VISEE", true)
	_add_toggle(grid, "lock_reticle", "VERROUILLAGE", true)
	_add_orient_toggle(grid)
	_add_toggle(grid, "shake", "SECOUSSES", true)
	_add_toggle(grid, "damage_numbers", "DEGATS CHIFFRES", true)
	# MODE DE JEU : seul endroit ou SANS FIN etait reglable, dans un ecran inatteignable.
	# On le remonte ici pour que le mode existe reellement. Hors partie uniquement : changer
	# de mode au milieu d'un run n'aurait aucun sens.
	if from_home:
		var mode_btn: Button = Button.new()
		mode_btn.add_theme_font_size_override("font_size", Palette.fs(19))
		mode_btn.custom_minimum_size = Vector2(_panel_w(460.0), 56)
		var paint_mode: Callable = func() -> void:
			var on: bool = bool(SaveManager.setting("endless", false))
			mode_btn.text = ("MODE : SANS FIN  —  vagues infinies" if on
				else "MODE : CAMPAGNE  —  boss final = victoire")
			mode_btn.add_theme_color_override("font_color",
				Color(1.0, 0.85, 0.3) if on else Color(0.6, 0.9, 1.0))
		paint_mode.call()
		mode_btn.pressed.connect(func() -> void:
			SaveManager.set_setting("endless", not bool(SaveManager.setting("endless", false)))
			Audio.sfx("click")
			paint_mode.call())
		box.add_child(mode_btn)
	var resume: Button = Button.new()
	resume.text = "RETOUR" if from_home else "REPRENDRE"
	resume.add_theme_font_size_override("font_size", Palette.fs(22))
	resume.custom_minimum_size = Vector2(_panel_w(460.0), 58)
	resume.pressed.connect(func() -> void:
		Audio.sfx("click")
		_settings_open = false
		if is_instance_valid(cl):
			cl.queue_free()
		if from_home:
			_show_home()     # on revient au hub, qui se remet en pause tout seul
		else:
			get_tree().paused = false
			if player != null and player.has_method("reset_input_state"):
				player.reset_input_state())
	box.add_child(resume)
	if from_home:
		return   # pas d'« ABANDONNER » hors partie
	# Way out of a run: settle what was earned, then reload into the HUB (not straight back into a
	# run). Without this the pause screen could only RESUME — no way home mid-run.
	var to_menu: Button = Button.new()
	to_menu.text = "ABANDONNER  —  menu principal"
	to_menu.add_theme_font_size_override("font_size", Palette.fs(20))
	to_menu.custom_minimum_size = Vector2(_panel_w(460.0), 50)
	to_menu.pressed.connect(func() -> void:
		Audio.sfx("click")
		ensure_banked()               # keep the crystals/points earned so far (SP still gated at 60s)
		GameState.skip_hub = false    # land on the hub, not a fresh run
		_settings_open = false
		get_tree().paused = false
		get_tree().reload_current_scene())
	box.add_child(to_menu)

## One ON/OFF settings button that persists + applies live.
func _add_toggle(parent: Node, key: String, label: String, default_on: bool) -> void:
	var b: Button = Button.new()
	b.add_theme_font_size_override("font_size", Palette.fs(17))
	b.custom_minimum_size = Vector2(_panel_w(460.0) * 0.5 - 6.0, 62)
	var paint: Callable = func(on: bool) -> void:
		b.text = "%s\n%s" % [label, "ON" if on else "OFF"]
		b.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if on else Color(0.7, 0.72, 0.78))
	paint.call(bool(SaveManager.setting(key, default_on)))
	b.pressed.connect(func() -> void:
		var nv: bool = not bool(SaveManager.setting(key, default_on))
		SaveManager.set_setting(key, nv)
		paint.call(nv)
		match key:
			"music": Audio.set_music_enabled(nv)
			"sfx": Audio.set_sfx_enabled(nv)
			"auto_aim":
				if player != null and is_instance_valid(player):
					player.auto_aim = nv
			"lock_reticle":
				if player != null and is_instance_valid(player):
					player.lock_reticle_enabled = nv
		Audio.sfx("click"))
	parent.add_child(b)

## Orientation cycles Auto -> Portrait -> Paysage (web: best-effort lock; native APK: full).
func _add_orient_toggle(parent: Node) -> void:
	var modes: Array = ["auto", "portrait", "landscape"]
	var labels: Dictionary = {"auto": "AUTO", "portrait": "PORTRAIT", "landscape": "PAYSAGE"}
	var b: Button = Button.new()
	b.add_theme_font_size_override("font_size", Palette.fs(17))
	b.custom_minimum_size = Vector2(_panel_w(460.0) * 0.5 - 6.0, 62)
	b.text = "ECRAN\n%s" % labels[String(SaveManager.setting("orientation", "auto"))]
	b.pressed.connect(func() -> void:
		var cur: String = String(SaveManager.setting("orientation", "auto"))
		var nm: String = String(modes[(modes.find(cur) + 1) % modes.size()])
		SaveManager.set_setting("orientation", nm)
		b.text = "ECRAN\n%s" % labels[nm]
		_apply_orientation(nm)
		Audio.sfx("click"))
	parent.add_child(b)

## Best-effort orientation control. On the web the lock only fully takes on some browsers and
## needs fullscreen (we request it); the game itself already renders correctly in any aspect.
## On the native Android build the manifest orientation governs; this is a no-op there.
func _update_cam_zoom() -> void:
	if cam == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var k: float = clampf(minf(vp.x, vp.y) / 720.0, 0.4, 1.0)
	cam.zoom = Vector2.ONE * k

func _apply_orientation(mode: String) -> void:
	if OS.has_feature("web"):
		var js: String = ""
		if mode == "portrait":
			js = "(function(){try{var e=document.documentElement;if(e.requestFullscreen)e.requestFullscreen();if(screen.orientation&&screen.orientation.lock)screen.orientation.lock('portrait');}catch(x){}})()"
		elif mode == "landscape":
			js = "(function(){try{var e=document.documentElement;if(e.requestFullscreen)e.requestFullscreen();if(screen.orientation&&screen.orientation.lock)screen.orientation.lock('landscape');}catch(x){}})()"
		else:
			js = "(function(){try{if(screen.orientation&&screen.orientation.unlock)screen.orientation.unlock();}catch(x){}})()"
		JavaScriptBridge.eval(js, true)
		return
	# NATIVE (Android): lock orientation safely to landscape by default (allows 180 flip)
	var o: int = DisplayServer.SCREEN_SENSOR_LANDSCAPE
	if mode == "portrait":
		o = DisplayServer.SCREEN_PORTRAIT
	elif mode == "landscape":
		o = DisplayServer.SCREEN_SENSOR_LANDSCAPE
	DisplayServer.screen_set_orientation(o)

func _on_difficulty_chosen(idx: int, overlay: CanvasLayer) -> void:
	GameState.difficulty = clampi(idx, 0, GameState.DIFFICULTY.size() - 1)
	SaveManager.set_difficulty(GameState.difficulty)
	# Re-read the mode HERE: GameState.reset() only runs on scene load, so the MODE toggle on this
	# very screen would otherwise apply to the NEXT run and the player would get a campaign after
	# asking for SANS FIN.
	GameState.endless = bool(SaveManager.setting("endless", false))
	Audio.sfx("click")
	if is_instance_valid(overlay):
		overlay.queue_free()
	get_tree().paused = false
	if player != null:
		player.refresh_equipped_chassis()
	_begin_run()

## SELECTION DE CHAPITRE (remplace le choix de difficulté). Liste les 5 chapitres ; les
## verrouillés sont grisés (🔒). Choisir un chapitre débloqué lance ce biome en mode campagne.
func _show_chapter_select() -> void:
	get_tree().paused = true
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 40
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.add_child(bg)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var card_w: float = clampf(vp.x * 0.82, 700.0, 980.0)
	if vp.x < 740.0:
		card_w = vp.x - 24.0
	var card_h: float = clampf(vp.y * 0.165, 96.0, 118.0)

	# Conteneur centré plein écran pour aligner parfaitement le menu horizontalement et verticalement
	var center_root: CenterContainer = CenterContainer.new()
	center_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_root.theme = Palette.ui_theme()
	cl.add_child(center_root)

	var col: VBoxContainer = VBoxContainer.new()
	# 14/10 (patron : « le menu des niveaux n'est pas centre au milieu ») : la colonne prenait TOUJOURS
	# toute la hauteur de l'ecran -> sur un telephone en portrait, 9 cartes occupaient le haut, RETOUR
	# restait colle en bas et un grand vide les separait. La hauteur est maintenant celle du contenu
	# (centre verticalement par le CenterContainer) tant qu'il tient ; au-dela, ecran plein + defilement.
	var head_h: float = float(Palette.fs(32)) * 1.75 + float(Palette.fs(14)) * 1.75 + 6.0
	var content_est: float = head_h + 10.0 + float(CHAPTERS.size()) * card_h 		+ float(CHAPTERS.size() - 1) * 10.0 + 10.0 + 50.0 + 24.0
	var col_h: float = clampf(content_est, 300.0, maxf(vp.y - 32.0, 300.0))
	col.custom_minimum_size = Vector2(card_w + 16.0, col_h)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center_root.add_child(col)

	# --- En-tête centré ---
	var header_box: VBoxContainer = VBoxContainer.new()
	header_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header_box.add_theme_constant_override("separation", 2)
	col.add_child(header_box)

	var title: Label = Label.new()
	title.text = "CHOISIS UN CHAPITRE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", Palette.fs(32))
	title.add_theme_color_override("font_color", Color(0.75, 0.94, 1.0))
	header_box.add_child(title)

	var subhead: Label = Label.new()
	subhead.text = "CAMPAGNE TACTIQUE  •  SELECTIONNE UNE ZONE"
	subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subhead.add_theme_font_size_override("font_size", Palette.fs(14))
	subhead.add_theme_color_override("font_color", Color(0.48, 0.65, 0.8))
	header_box.add_child(subhead)

	# --- Zone qui défile (liste des 9 chapitres) ---
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.follow_focus = true
	col.add_child(sc)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	sc.add_child(box)

	var cleared: int = SaveManager.chapters_cleared_count()
	var th_h: float = card_h - 16.0
	var th_w: float = roundf(th_h * (16.0 / 9.0))
	if card_w < 500.0:
		th_w = minf(th_w, card_w * 0.28)

	for i in CHAPTERS.size():
		var ch: Dictionary = CHAPTERS[i]
		var n: int = i + 1
		var is_unlocked: bool = SaveManager.chapter_unlocked(n)

		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(card_w, card_h)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.text = ""
		b.clip_text = false

		# Style cyber / carte tactique
		var sb_n: StyleBoxFlat = StyleBoxFlat.new()
		sb_n.bg_color = Color(0.04, 0.08, 0.15, 0.92)
		sb_n.border_color = Color(0.2, 0.5, 0.8, 0.5) if is_unlocked else Color(0.14, 0.18, 0.24, 0.4)
		sb_n.set_border_width_all(1)
		sb_n.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", sb_n)

		var sb_h: StyleBoxFlat = StyleBoxFlat.new()
		sb_h.bg_color = Color(0.08, 0.18, 0.32, 0.98)
		sb_h.border_color = Color(0.35, 0.9, 1.0, 0.95)
		sb_h.set_border_width_all(2)
		sb_h.set_corner_radius_all(8)
		b.add_theme_stylebox_override("hover", sb_h)
		b.add_theme_stylebox_override("focus", sb_h)

		var sb_p: StyleBoxFlat = StyleBoxFlat.new()
		sb_p.bg_color = Color(0.02, 0.06, 0.12, 0.98)
		sb_p.border_color = Color(0.2, 0.8, 1.0, 1.0)
		sb_p.set_border_width_all(2)
		sb_p.set_corner_radius_all(8)
		b.add_theme_stylebox_override("pressed", sb_p)

		var sb_d: StyleBoxFlat = StyleBoxFlat.new()
		sb_d.bg_color = Color(0.03, 0.04, 0.06, 0.75)
		sb_d.border_color = Color(0.14, 0.16, 0.2, 0.35)
		sb_d.set_border_width_all(1)
		sb_d.set_corner_radius_all(8)
		b.add_theme_stylebox_override("disabled", sb_d)

		# Contenu interactif à l'intérieur du bouton
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 8
		hbox.offset_right = -16
		hbox.offset_top = 8
		hbox.offset_bottom = -8
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 16)
		b.add_child(hbox)

		# 1. Vignette 16:9 du niveau (grande illustration)
		var thumb_panel: PanelContainer = PanelContainer.new()
		thumb_panel.custom_minimum_size = Vector2(th_w, th_h)
		thumb_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb_th: StyleBoxFlat = StyleBoxFlat.new()
		sb_th.bg_color = Color(0.02, 0.03, 0.05, 1.0)
		sb_th.set_corner_radius_all(6)
		sb_th.border_color = Color(0.3, 0.75, 1.0, 0.5) if is_unlocked else Color(0.18, 0.2, 0.24, 0.35)
		sb_th.set_border_width_all(1)
		thumb_panel.add_theme_stylebox_override("panel", sb_th)
		thumb_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

		var img_rect: TextureRect = TextureRect.new()
		img_rect.texture = Tex.get_tex("res://assets/chapters/chap_%d_%s.jpg" % [n, ch["biome"]])
		img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not is_unlocked:
			img_rect.modulate = Color(0.35, 0.35, 0.4, 0.55)
		thumb_panel.add_child(img_rect)

		if not is_unlocked:
			var lock_overlay: Label = Label.new()
			lock_overlay.text = "[ BLOQUE ]"
			lock_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock_overlay.add_theme_font_size_override("font_size", Palette.fs(13))
			lock_overlay.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7, 0.9))
			thumb_panel.add_child(lock_overlay)
		hbox.add_child(thumb_panel)

		# 2. Informations du chapitre (Titre + Sous-titre / Biome + Conseil)
		var info_box: VBoxContainer = VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.alignment = BoxContainer.ALIGNMENT_CENTER
		info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.add_theme_constant_override("separation", 3)

		var lbl_title: Label = Label.new()
		lbl_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_title.clip_text = true
		lbl_title.add_theme_font_size_override("font_size", Palette.fs(20))
		lbl_title.text = "%d.  %s" % [n, String(ch["name"]).to_upper()]
		if is_unlocked:
			if cleared >= n:
				lbl_title.add_theme_color_override("font_color", Color(0.65, 0.95, 0.75))
			else:
				lbl_title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
		else:
			lbl_title.add_theme_color_override("font_color", Color(0.48, 0.52, 0.58))
		info_box.add_child(lbl_title)

		var lbl_sub: Label = Label.new()
		lbl_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_sub.clip_text = true
		lbl_sub.add_theme_font_size_override("font_size", Palette.fs(14))
		if is_unlocked:
			lbl_sub.text = "%s  •  %s" % [String(ch["sub"]), _biome_label(ch["biome"])]
			lbl_sub.add_theme_color_override("font_color", Color(0.55, 0.76, 0.92))
		else:
			lbl_sub.text = "Debloque apres avoir vaincu le chapitre %d" % [n - 1]
			lbl_sub.add_theme_color_override("font_color", Color(0.75, 0.45, 0.45))
		info_box.add_child(lbl_sub)
		hbox.add_child(info_box)

		# 3. Badges de droite (Difficulté + Statut d'action)
		var right_box: VBoxContainer = VBoxContainer.new()
		right_box.alignment = BoxContainer.ALIGNMENT_CENTER
		right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_box.add_theme_constant_override("separation", 4)

		if is_unlocked:
			var diff_idx: int = clampi(int(ch["diff"]), 0, GameState.DIFFICULTY.size() - 1)
			var dn: String = String(GameState.DIFFICULTY[diff_idx].get("name", ""))
			var lbl_diff: Label = Label.new()
			lbl_diff.text = "[ %s ]" % dn
			lbl_diff.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl_diff.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lbl_diff.add_theme_font_size_override("font_size", Palette.fs(12))
			match diff_idx:
				0: lbl_diff.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
				1: lbl_diff.add_theme_color_override("font_color", Color(0.35, 0.8, 1.0))
				2: lbl_diff.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
				3: lbl_diff.add_theme_color_override("font_color", Color(0.95, 0.45, 0.85))
			right_box.add_child(lbl_diff)

			if int(ch.get("gate", 0)) > 0:
				var lbl_gate: Label = Label.new()
				lbl_gate.text = "Pce rec. : %d" % int(ch["gate"])
				lbl_gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
				lbl_gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				lbl_gate.add_theme_font_size_override("font_size", Palette.fs(11))
				lbl_gate.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9, 0.85))
				right_box.add_child(lbl_gate)

			var lbl_stat: Label = Label.new()
			lbl_stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lbl_stat.add_theme_font_size_override("font_size", Palette.fs(14))
			if cleared >= n:
				lbl_stat.text = "BATTU"
				lbl_stat.add_theme_color_override("font_color", Color(0.45, 0.92, 0.6))
			else:
				lbl_stat.text = "DEPLOYER >"
				lbl_stat.add_theme_color_override("font_color", Color(0.3, 0.88, 1.0))
			right_box.add_child(lbl_stat)

			b.pressed.connect(_on_chapter_chosen.bind(i, cl))
		else:
			var lbl_lock: Label = Label.new()
			lbl_lock.text = "VERROUILLE"
			lbl_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl_lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lbl_lock.add_theme_font_size_override("font_size", Palette.fs(12))
			lbl_lock.add_theme_color_override("font_color", Color(0.48, 0.5, 0.55))
			right_box.add_child(lbl_lock)
			b.disabled = true

		hbox.add_child(right_box)
		box.add_child(b)

	# --- Bouton RETOUR en bas, largeur calée sur la liste ---
	var back: Button = Button.new()
	back.text = "RETOUR"
	back.add_theme_font_size_override("font_size", Palette.fs(20))
	back.custom_minimum_size = Vector2(card_w, 50.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var esc: InputEventAction = InputEventAction.new()
	esc.action = "ui_cancel"
	var sh: Shortcut = Shortcut.new()
	sh.events = [esc]
	back.shortcut = sh
	back.pressed.connect(func() -> void:
		Audio.sfx("click")
		if is_instance_valid(cl):
			cl.queue_free()
		_show_home())
	col.add_child(back)

	# --- MOTION DESIGN ---
	Palette.fade_in(bg)
	Palette.fade_in(col)
	Palette.stagger_reveal(box, 0.03, 0.04)
	Palette.pop_in(back, 0.12, 0.24, 0.94)


func _biome_label(b: String) -> String:
	match b:
		"tech": return "Secteur Industriel"
		"desert": return "Désert Toxique"
		"jungle": return "Ruines Végétales"
		"volcanic": return "Forge Magmatique"
		"swamp": return "Cité Engloutie"
		"cryo": return "Cryo-Laboratoire"
		"reacteur": return "Cœur Réacteur"
		"ruche": return "Ruche Xéno"
		"citadelle": return "Citadelle Orbitale"
		"abyss": return "Abysses Englouties"
		"ether": return "Forêt Psychédélique"
		"titans": return "Nécropole des Titans"
		"orbit": return "Champ Orbital 0G"
		"quantum": return "Archives Quantiques"
		"ozone": return "Faille d'Ozone (Orage)"
		"prism": return "Grotte Prismatique"
		"steampunk": return "Bastion Vapeur"
		"colosseum": return "Colisée Virtuel"
		_: return b.capitalize()


func _on_chapter_chosen(idx: int, overlay: CanvasLayer) -> void:
	var ch: Dictionary = CHAPTERS[idx]
	_chapter = idx + 1
	# spawner existe deja (construit dans _ready() avec chapter=1 par defaut) : sans cette ligne,
	# un choix de chapitre 2-5 laisserait spawner.chapter bloque a 1 -> BELIER-01 remplacerait le
	# Souverain PARTOUT, pas seulement au chapitre 1. Voir EnemySpawner.gd, resolution du boss 15 min.
	if spawner != null:
		spawner.chapter = _chapter
	GameState.difficulty = clampi(int(ch["diff"]), 0, GameState.DIFFICULTY.size() - 1)
	SaveManager.set_difficulty(GameState.difficulty)
	GameState.endless = false   # chapitre = campagne (boss final = clear + déblocage)
	Audio.sfx("click")
	if is_instance_valid(overlay):
		overlay.queue_free()
	get_tree().paused = false
	_apply_chapter_biome(String(ch["biome"]))
	if player != null:
		player.refresh_equipped_chassis()
	_begin_run()


func _apply_biome_lighting(biome_name: String) -> void:
	if _cmod == null:
		return
	var c: Color = Color(0.92, 0.94, 0.98)
	var plight_c: Color = Color(0.5, 0.85, 1.0)
	var plight_e: float = 0.45
	match biome_name:
		"tech":
			c = Color(0.90, 0.94, 1.00)
			plight_c = Color(0.3, 0.85, 1.0)
			plight_e = 0.50
		"desert":
			c = Color(1.02, 0.95, 0.82)
			plight_c = Color(1.0, 0.85, 0.5)
			plight_e = 0.35
		"jungle":
			c = Color(0.84, 0.96, 0.84)
			plight_c = Color(0.4, 1.0, 0.5)
			plight_e = 0.45
		"volcanic":
			c = Color(0.95, 0.80, 0.72)
			plight_c = Color(1.0, 0.6, 0.2)
			plight_e = 0.55
		"swamp":
			c = Color(0.85, 0.92, 0.82)
			plight_c = Color(0.3, 0.9, 0.7)
			plight_e = 0.45
		"cryo", "ice":
			c = Color(0.84, 0.94, 1.04)
			plight_c = Color(0.6, 0.95, 1.0)
			plight_e = 0.50
		"reacteur":
			c = Color(0.82, 1.02, 0.84)
			plight_c = Color(0.3, 1.0, 0.4)
			plight_e = 0.55
		"ruche":
			c = Color(0.92, 0.78, 0.96)
			plight_c = Color(0.85, 0.35, 1.0)
			plight_e = 0.50
		"citadelle", "spaceship":
			c = Color(0.96, 0.96, 1.02)
			plight_c = Color(0.4, 0.8, 1.0)
			plight_e = 0.45
		"abyss":
			c = Color(0.72, 0.88, 1.05)
			plight_c = Color(0.2, 0.8, 1.0)
			plight_e = 0.55
		"ether":
			c = Color(0.88, 0.80, 1.02)
			plight_c = Color(0.8, 0.4, 1.0)
			plight_e = 0.50
		"titans":
			c = Color(0.98, 0.90, 0.80)
			plight_c = Color(1.0, 0.65, 0.35)
			plight_e = 0.45
		"orbit":
			c = Color(0.82, 0.90, 1.05)
			plight_c = Color(0.4, 0.75, 1.0)
			plight_e = 0.50
		"quantum":
			c = Color(0.95, 0.95, 0.85)
			plight_c = Color(1.0, 0.9, 0.4)
			plight_e = 0.50
		"ozone":
			c = Color(0.90, 0.82, 1.05)
			plight_c = Color(0.9, 0.5, 1.0)
			plight_e = 0.60
		"prism":
			c = Color(0.88, 0.96, 1.05)
			plight_c = Color(0.5, 0.95, 1.0)
			plight_e = 0.50
		"steampunk":
			c = Color(1.05, 0.90, 0.78)
			plight_c = Color(1.0, 0.65, 0.25)
			plight_e = 0.55
		"colosseum":
			c = Color(0.92, 0.96, 1.00)
			plight_c = Color(0.4, 0.85, 1.0)
			plight_e = 0.50
		_:
			c = Color(0.92, 0.94, 0.98)
			plight_c = Color(0.5, 0.85, 1.0)
			plight_e = 0.40
	_cmod.color = c
	if _plight != null:
		_plight.color = plight_c
		_plight.energy = plight_e

## Force le biome d'un chapitre (sol + décor + pool d'ennemis + musique) — même logique que
## next_map() mais sans incrémenter les zones (on démarre pile sur ce biome).
func _apply_chapter_biome(biome_name: String) -> void:
	_biome = BIOMES.find(biome_name)
	if _biome < 0:
		_biome = 0
	_mods = BIOME_MODS.get(biome_name, {})
	_hazard = String(_mods.get("hazard", ""))
	if _floor_mat != null:
		_apply_biome_floor(biome_name)
	_scatter_decor(biome_name)
	if _ambient != null and _ambient.has_method("apply_biome"):
		_ambient.apply_biome(biome_name)
	_apply_biome_lighting(biome_name)
	if spawner != null:
		spawner.speed_mult = float(_mods.get("enemy_speed_mult", 1.0))
		spawner.spawn_mult = float(_mods.get("enemy_spawn_mult", 1.0))
		spawner.current_biome = biome_name
		spawner.enemy_tint = EnemySpawner.BIOME_TINT.get(biome_name, Color(1, 1, 1))
	if player != null:
		player.move_mult = float(_mods.get("player_speed_mult", 1.0))
		player.biome_proj_speed = float(_mods.get("player_proj_speed", 1.0))
		player.inertia = float(_mods.get("player_inertia", 0.0))


func _mk_layer() -> Node2D:
	var n: Node2D = Node2D.new()
	add_child(n)
	return n

# ---- weapon fire (pooled: reuse instead of new/queue_free in the hot loop) ----
func spawn_shot(muzzle: Vector2, dir: Vector2, params: Dictionary) -> void:
	var p: Projectile
	if _proj_pool.is_empty():
		p = Projectile.new()
		p.game = self
		projectile_layer.add_child(p)
	else:
		p = _proj_pool.pop_back()
	p.setup(muzzle, dir, params)
	_muzzle_flash(muzzle, dir, Color(params.get("color", Palette.CYAN)))
	Audio.sfx("shoot", 0.14)

func reclaim_proj(p: Projectile) -> void:
	p.deactivate()
	_proj_pool.append(p)

func spawn_bolt(pos: Vector2, dir: Vector2, dmg: float) -> void:
	spawn_shot(pos, dir, {"dmg": dmg, "pierce": player.bolt_pierce})

func _spawn_pickup(pos: Vector2, kind: String, val: int) -> void:
	var g: Pickup
	if _pickup_pool.is_empty():
		g = Pickup.new()
		g.game = self
		pickup_layer.add_child(g)
	else:
		g = _pickup_pool.pop_back()
	g.setup(pos, kind, val, player)

func reclaim_pickup(p: Pickup) -> void:
	p.deactivate()
	_pickup_pool.append(p)

func spawn_xp(pos: Vector2, val: int) -> void:
	_spawn_pickup(pos, "xp", val)

func spawn_scrap(pos: Vector2, amount: int) -> void:
	_spawn_pickup(pos, "scrap", amount)

func spawn_bonus(pos: Vector2) -> void:
	# a gold cache: heals + tops up overdrive + a little scrap when vacuumed up
	_spawn_pickup(pos, "bonus", 1)

func spawn_skill(pos: Vector2) -> void:
	# dropped by a broken skill-crate: grants a random competence when collected
	_spawn_pickup(pos, "skill", 1)

func spawn_weapon_loan(pos: Vector2) -> void:
	# BUTIN DE GUERRE (patron, 23/09) : un BOSS tue laisse une arme a emprunter — rare et
	# guarantie (pas un jet de chance), a la difference du "bonus" des ennemis intermediaires.
	_spawn_pickup(pos, "arme_volee", 1)

func spawn_heal(pos: Vector2) -> void:
	# pure med-pack out of a smashed crate
	_spawn_pickup(pos, "heal", 1)

func spawn_od(pos: Vector2) -> void:
	# energy cell: tops the Overdrive gauge straight up
	_spawn_pickup(pos, "od", 1)

# --- Emoji pop: a smashed crate sometimes just makes you laugh. Zero gameplay weight, pure joy.
# Real colour emoji baked from the system emoji font into assets/emoji/e*.png.
const EMOJI_COUNT: int = 10
func spawn_emoji(pos: Vector2) -> void:
	var p: String = "res://assets/emoji/e%d.png" % (randi() % EMOJI_COUNT)
	if not ResourceLoader.exists(p):
		return
	var s: Sprite2D = Sprite2D.new()
	s.texture = load(p)
	s.position = pos
	s.scale = Vector2.ZERO
	s.z_index = 30
	fx_layer.add_child(s)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * 0.85, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position", pos + Vector2(randf_range(-24.0, 24.0), -104.0), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(s, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(s.queue_free)

# Grant a random permanent competence (a free draft pick), called when a "skill" pickup is vacuumed.
const _SKILL_POOL: Array = ["dmg", "spd", "hp", "haste", "crit", "armor", "magnet", "aura", "drone"]
const _SKILL_NAME: Dictionary = {
	"dmg": "PUISSANCE +25%", "spd": "VITESSE +12%", "hp": "VITALITE +25", "haste": "CADENCE +",
	"crit": "CRITIQUE +8%", "armor": "ARMURE +8%", "magnet": "AIMANT +", "aura": "AURA", "drone": "DRONE",
}
func grant_skill() -> void:
	var id: String = String(_SKILL_POOL[randi() % _SKILL_POOL.size()])
	_apply_upgrade(id)
	Audio.sfx("levelup")
	show_banner("COMPETENCE : %s" % String(_SKILL_NAME.get(id, id)), Palette.BONUS)

func spawn_enemy_bolt(pos: Vector2, dir: Vector2, dmg: float, color: Color = Color(1.0, 0.55, 0.25), bolt_size: float = 1.0, bolt_speed: float = 300.0, is_missile: bool = false, homing: float = 0.0) -> void:
	var b: EnemyProjectile
	if _enemy_proj_pool.is_empty():
		b = EnemyProjectile.new()
		b.game = self
		projectile_layer.add_child(b)
	else:
		b = _enemy_proj_pool.pop_back()   # RECYCLE : pas de new/queue_free dans la boucle chaude
	b.tint = color
	b.size = bolt_size
	b.missile = is_missile               # tirs lourds = missile (sprite ogive + trainee)
	b.homing = homing                    # > 0 : palier 3 de l'arme ennemie (« TRAQUEUR »)
	b.setup(pos, dir, dmg, bolt_speed)

func recycle_enemy_bolt(b: EnemyProjectile) -> void:
	_enemy_proj_pool.append(b)

## Zone AoE telegraphiee au sol (boss a ogives) : cercle rouge -> delai -> explosion.
func spawn_ground_zone(pos: Vector2, radius: float, delay: float, dmg: float, color: Color = Color(1.0, 0.45, 0.12), fx_kind: String = "decor_hit") -> void:
	var z: GroundZone = GroundZone.new()
	z.radius = radius; z.delay = delay; z.damage = dmg; z.color = color; z.fx_kind = fx_kind
	z.game = self; z.player = player
	enemy_layer.add_child(z)   # meme espace-monde que les ennemis ; z_index -2 = au sol
	z.global_position = pos

# Weapon-signature impact FX: every family hits with a DISTINCT, readable look so the
# arsenal never feels samey. Explosive = fireball+smoke, piercing = sharp lance, energy =
# crackling arcs, kinetic = quick spark, drone = small blue pop. Evolved weapons are amplified.
func impact_fx(pos: Vector2, color: Color, kind: String, dir: Vector2 = Vector2.ZERO, scale: float = 1.0) -> void:
	# SPECTACULAR = a COMPOSITE, not one sprite: bloomed accent sprite + core flash + expanding
	# ring(s) + radial sparks + a DYNAMIC light pop (lights up the floor = the "premium" tell) +
	# scaled shake. Each weapon keeps its single vivid accent colour.
	# `scale` grows the WHOLE burst with the weapon's level, so a maxed weapon reads as far more
	# powerful than a level-1 one — the visual reward for investing in it.
	match kind:
		"missilepod", "hydra":   # EXPLOSIVE -> FIRE
			var big: float = (1.4 if kind == "hydra" else 1.0) * scale
			var fire: Color = Color(1.0, 0.5, 0.15)
			spawn_vfx("aaa_explosion", pos, 0.0, 0.62 * big, Color.WHITE)   # native fireball
			_flash_sprite(pos, fire.lerp(Color.WHITE, 0.6), 104.0 * big, 0.13)
			_ring(pos, fire, 12.0, 120.0 * big, 0.32)
			_debris(pos, Color(1.0, 0.7, 0.3), int(12 * big), 0.46, 150.0, 400.0)
			_smoke(pos, int(6 * big))
			_light_pop(pos, fire, 3.4 * big, 0.30, 1.7 * big)
			Events.screen_shake.emit(4.2 * big)
			Audio.sfx("explosion", 0.1)
		"railgun", "annihilator", "rail_nova":   # PIERCING -> ELECTRIC lance (04/10 : rail_nova
		# ajoutee, meme famille - elle reprend le mecanisme de perforation du railgun, cf.
		# Projectile.BULLET_FAMILY)
			var big2: float = (1.45 if kind == "annihilator" else 1.0) * scale
			var beam: Color = color.lerp(Color.WHITE, 0.3)
			_streak(pos, dir, beam, 260.0 * big2, 9.0 * big2, 0.15)     # bright piercing lance
			spawn_vfx("aaa_beam", pos, dir.angle(), 0.34 * big2, color)   # crackling energy discharge
			spawn_vfx("aaa_shockwave", pos, 0.0, 0.30 * big2, beam)       # pierce shock ring
			_flash_sprite(pos, beam, 66.0 * big2, 0.10)
			_light_pop(pos, beam, 2.4 * big2, 0.15, 1.2 * big2)
			_debris(pos, color, int(5 * big2), 0.30, 140.0, 340.0)
			if kind == "annihilator":
				Events.screen_shake.emit(3.2)
			Audio.sfx("hit", 0.15)
		"plasma", "singularity":   # ENERGY -> violet dome
			var big3: float = (1.45 if kind == "singularity" else 1.0) * scale
			var en: Color = color
			spawn_vfx("aaa_aoe", pos, 0.0, 0.6 * big3, Color.WHITE)       # native plasma dome + arcs
			_flash_sprite(pos, en.lerp(Color.WHITE, 0.4), 90.0 * big3, 0.15)
			_ring(pos, en, 8.0, 92.0 * big3, 0.26)
			_arcs(pos, en, int(5 * big3), 76.0 * big3)
			_light_pop(pos, en, 2.8 * big3, 0.25, 1.5 * big3)
			if kind == "singularity":
				Events.screen_shake.emit(2.8)
			Audio.sfx("explosion" if kind == "singularity" else "hit", 0.12)
		"drone":   # friendly drone bolt: compact cyan pop
			var dc: Color = Color(0.5, 0.95, 1.0)
			spawn_vfx("aaa_impact", pos, 0.0, 0.26 * scale, dc)
			_flash_sprite(pos, dc, 48.0 * scale, 0.11)
			_light_pop(pos, dc, 1.3, 0.12, 0.7 * scale)
			_debris(pos, dc, 3, 0.24, 90.0, 210.0)
		"disperseur", "deflagrateur":   # GERBE -> souffle court + pluie d'eclats
			var bg: float = (1.35 if kind == "deflagrateur" else 1.0) * scale
			var sc: Color = color.lerp(Color.WHITE, 0.35)
			spawn_vfx("dp_blast", pos, dir.angle(), 0.34 * bg, color)
			_flash_sprite(pos, sc, 62.0 * bg, 0.09)
			_ring(pos, color, 8.0, 74.0 * bg, 0.20)
			_debris(pos, color, int(9 * bg), 0.28, 170.0, 420.0)   # la gerbe projette
			_light_pop(pos, sc, 1.8 * bg, 0.13, 1.0 * bg)
			Audio.sfx("hit", 0.12)
		"ricochet", "carambole", "frelon":   # REBOND -> flash net + anneau qui repart (04/10 :
		# frelon ajoutee, meme famille - elle rebondit comme ricochet, cf. Projectile.BULLET_FAMILY)
			var rb: float = (1.3 if kind == "carambole" else 1.0) * scale
			var rc: Color = color.lerp(Color.WHITE, 0.4)
			spawn_vfx("aaa_impact", pos, 0.0, 0.40 * rb, color)
			spawn_vfx("shockwave", pos, 0.0, 0.26 * rb, rc)        # l'onde du rebond
			_flash_sprite(pos, rc, 58.0 * rb, 0.10)
			_arcs(pos, color, int(3 * rb), 54.0 * rb)
			_light_pop(pos, rc, 1.7 * rb, 0.14, 0.9 * rb)
			Audio.sfx("hit", 0.13)
		"disque", "guillotine":   # TRANCHANT -> entaille lumineuse + etincelles
			var dg: float = (1.4 if kind == "guillotine" else 1.0) * scale
			var dc2: Color = color.lerp(Color.WHITE, 0.45)
			spawn_vfx("aaa_sabre", pos, dir.angle(), 0.40 * dg, color)   # arc tranchant
			_streak(pos, dir, dc2, 150.0 * dg, 7.0 * dg, 0.13)
			_flash_sprite(pos, dc2, 60.0 * dg, 0.10)
			_debris(pos, color, int(6 * dg), 0.26, 150.0, 360.0)
			_light_pop(pos, dc2, 2.0 * dg, 0.15, 1.1 * dg)
			Audio.sfx("hit", 0.14)
		# ---- SIGNATURE BIOME HAZARDS & TURRETS (04/10 + 15/10) -------------------------
		"volcanic_mortier_scories", "volcanic_event_magma":
			var b_volc: float = 1.35 * scale
			spawn_signature_vfx("volcanic_fx_obus_lave", pos, dir.angle(), 1.2 * b_volc, 0.5, Color(1.0, 0.45, 0.15))
			FxKit.recipe_fire(self, pos, Color(1.0, 0.45, 0.15), b_volc)
			_light_pop(pos, Color(1.0, 0.55, 0.2), 3.8 * b_volc, 0.45, 2.0 * b_volc)
			Events.screen_shake.emit(4.5 * b_volc)
			Audio.sfx("explosion", 0.12)
		"desert_miroir_solaire", "desert_generateur_tempete":
			var b_des: float = 1.3 * scale
			spawn_signature_vfx("desert_fx_rayon_solaire", pos, dir.angle(), 1.2 * b_des, 0.45, Color(1.0, 0.85, 0.25))
			FxKit.recipe_energy(self, pos, Color(1.0, 0.85, 0.25), b_des)
			_light_pop(pos, Color(1.0, 0.9, 0.4), 3.6 * b_des, 0.35, 1.8 * b_des)
			Events.screen_shake.emit(3.8 * b_des)
			Audio.sfx("explosion", 0.1)
		"jungle_mortier_plante", "jungle_fruit_grenade":
			var b_jun: float = 1.25 * scale
			spawn_signature_vfx("jungle_fx_cosse_epines", pos, dir.angle(), 1.15 * b_jun, 0.45, Color(0.4, 0.9, 0.25))
			FxKit.recipe_bio(self, pos, Color(0.4, 0.9, 0.25), b_jun)
			_light_pop(pos, Color(0.5, 0.95, 0.3), 3.2 * b_jun, 0.35, 1.6 * b_jun)
			Events.screen_shake.emit(3.5 * b_jun)
			Audio.sfx("hit", 0.12)
		"swamp_tourelle_dca", "swamp_bouee_mine":
			var b_swp: float = 1.3 * scale
			spawn_signature_vfx("swamp_fx_obus_fusee", pos, dir.angle(), 1.2 * b_swp, 0.45, Color(1.0, 0.55, 0.2))
			FxKit.recipe_fire(self, pos, Color(1.0, 0.55, 0.2), b_swp)
			_light_pop(pos, Color(1.0, 0.6, 0.25), 3.5 * b_swp, 0.35, 1.8 * b_swp)
			Events.screen_shake.emit(4.0 * b_swp)
			Audio.sfx("explosion", 0.12)
		"tech_tourelle_soudeuse", "tech_soudeuse":
			var b_tech: float = 1.25 * scale
			spawn_signature_vfx("tech_fx_arc_soudure", pos, dir.angle(), 1.15 * b_tech, 0.4, Color(0.35, 0.9, 1.0))
			FxKit.recipe_energy(self, pos, Color(0.35, 0.9, 1.0), b_tech)
			_light_pop(pos, Color(0.4, 0.95, 1.0), 3.4 * b_tech, 0.3, 1.6 * b_tech)
			Events.screen_shake.emit(3.0 * b_tech)
			Audio.sfx("hit", 0.14)
		"cryo_canon_azote":
			var b_cryo: float = 1.3 * scale
			spawn_signature_vfx("cryo_fx_orbe_givre", pos, dir.angle(), 1.2 * b_cryo, 0.5, Color(0.65, 0.88, 1.0))
			FxKit.recipe_ice(self, pos, Color(0.65, 0.88, 1.0), b_cryo)
			_light_pop(pos, Color(0.7, 0.95, 1.0), 3.4 * b_cryo, 0.35, 1.7 * b_cryo)
			Events.screen_shake.emit(3.2 * b_cryo)
			Audio.sfx("hit", 0.12)
		"reacteur_canon_particules":
			var b_reac: float = 1.35 * scale
			spawn_signature_vfx("reacteur_fx_tir_fragmente", pos, dir.angle(), 1.2 * b_reac, 0.45, Color(0.45, 1.0, 0.55))
			FxKit.recipe_energy(self, pos, Color(0.45, 1.0, 0.55), b_reac)
			_light_pop(pos, Color(0.5, 1.0, 0.6), 3.6 * b_reac, 0.35, 1.8 * b_reac)
			Events.screen_shake.emit(3.8 * b_reac)
			Audio.sfx("explosion", 0.12)
		"ruche_organe_acide":
			var b_ruc: float = 1.25 * scale
			spawn_signature_vfx("ruche_fx_globule_acide", pos, dir.angle(), 1.15 * b_ruc, 0.45, Color(0.85, 0.95, 0.25))
			FxKit.recipe_bio(self, pos, Color(0.85, 0.95, 0.25), b_ruc)
			_light_pop(pos, Color(0.85, 1.0, 0.3), 3.2 * b_ruc, 0.35, 1.6 * b_ruc)
			Events.screen_shake.emit(3.0 * b_ruc)
			Audio.sfx("hit", 0.12)
		"citadelle_lanceur_guide":
			var b_cit: float = 1.35 * scale
			spawn_signature_vfx("citadelle_fx_missile_plasma", pos, dir.angle(), 1.25 * b_cit, 0.5, Color(1.0, 0.45, 0.85))
			FxKit.recipe_energy(self, pos, Color(1.0, 0.45, 0.85), b_cit)
			_light_pop(pos, Color(1.0, 0.55, 0.9), 3.8 * b_cit, 0.4, 2.0 * b_cit)
			Events.screen_shake.emit(4.2 * b_cit)
			Audio.sfx("explosion", 0.14)
		# ---- DECOR INTERACTIF (04/10 tour 2, « encore bas de gamme ») ----------------------
		# Chaque famille de danger passe par une RECETTE FxKit en 6 couches (coeur anamorphique,
		# halo, onde a front net, matiere projetee, fumee/vapeur/eclats, trace au sol qui reste).
		"surchauffe_sol", "baril", "zone_alternante":
			var b_fire: float = 1.2 * scale
			FxKit.recipe_fire(self, pos, color, b_fire)
			_light_pop(pos, Color(1.0, 0.55, 0.2), 3.5 * b_fire, 0.4, 1.9 * b_fire)
			Events.screen_shake.emit(4.0 * b_fire)
			Audio.sfx("explosion", 0.1)
		"jet_de_cryo", "pic_de_glace", "glace_fragile", "capsule_cryogenique", "plaque_de_glace", "borne_thermique", "radiateur":
			var b_ice: float = 1.1 * scale
			FxKit.recipe_ice(self, pos, color, b_ice)
			_light_pop(pos, color.lerp(Color.WHITE, 0.3), 3.0 * b_ice, 0.3, 1.3 * b_ice)
			Events.screen_shake.emit(2.5 * b_ice)
			Audio.sfx("hit", 0.12)
		"grille_ventilation", "zone_depressurisation", "zone_push_pull", "poche_de_vent", "console_vent":
			var b_wind: float = 1.2 * scale
			FxKit.recipe_wind(self, pos, color, b_wind)
			_light_pop(pos, color, 1.8 * b_wind, 0.22, 1.0 * b_wind)
			Events.screen_shake.emit(3.0 * b_wind)
			Audio.sfx("hit", 0.1)
		"tentacule_emergence", "cocon", "plante_lumineuse", "bassin_toxique", "residu_biomecanique", "sol_collant", "nuage_spores":
			var b_bio: float = 1.1 * scale
			FxKit.recipe_bio(self, pos, color, b_bio)
			_light_pop(pos, color, 2.6 * b_bio, 0.3, 1.4 * b_bio)
			Events.screen_shake.emit(2.0 * b_bio)
			Audio.sfx("hit", 0.1)
		"generateur", "capaciteur", "cristaux", "cristal_instable", "emetteur_laser_rotatif", "pilier_energie", "pulse_energie", "antenne", "terminal", "archives", "vanne_refroidissement", "vanne_drainage":
			var b_en: float = 1.2 * scale
			FxKit.recipe_energy(self, pos, color, b_en)
			_light_pop(pos, color, 3.5 * b_en, 0.28, 1.7 * b_en)
			Events.screen_shake.emit(3.5 * b_en)
			Audio.sfx("explosion", 0.12)
		"caisses", "container", "container_mobile", "quai", "convoyeur", "convoyeur_sol", "bras_presseur", "piston_hydraulique", "zone_chargement", "epave", "tourelle", "porte_automatique", "porte_securite_orbitale", "segment_mur_modulaire", "decor_hit":
			var b_kin: float = 1.1 * scale
			FxKit.recipe_kinetic(self, pos, color, b_kin)
			_light_pop(pos, Color(1.0, 0.8, 0.5), 3.0 * b_kin, 0.22, 1.3 * b_kin)
			Events.screen_shake.emit(3.0 * b_kin)
			Audio.sfx("hit", 0.15)
		_:   # KINETIC rapid (autocannon / vulcan)
			# 🚨 « l'impact de l'autocanon est un dessin au trait : une gerbe de fines lignes
			# dorees en fil de fer avec un anneau. Ca ne claque pas, ca ressemble a un croquis. »
			# On applique la regle maison (halo + coeur + lisere) : coeur blanc sur-expose,
			# anneau de souffle, gerbe d'eclats plus fournie et projetee plus loin.
			var big4: float = (1.3 if kind == "vulcan" else 1.0) * scale
			var acc: Color = color
			var hot: Color = acc.lerp(Color.WHITE, 0.72)
			spawn_vfx("aaa_impact", pos, 0.0, 0.68 * big4, acc)          # bloomed accent burst + sparks
			_flash_sprite(pos, hot, 96.0 * big4, 0.12)                    # COEUR blanc, franc
			_ring(pos, acc, 9.0, 78.0 * big4, 0.22)                       # LISERE : onde de souffle
			_debris(pos, acc, int(9 * big4), 0.32, 190.0, 430.0)
			_light_pop(pos, hot, 2.3 * big4, 0.14, 1.25 * big4)
			Audio.sfx("hit", 0.15)

# A forked lightning bolt between two points (arc pylon zapping an enemy). Jagged additive line
# that flashes and fades — cheap, no per-frame cost after it fires.
func spawn_arc(a: Vector2, b: Vector2, color: Color) -> void:
	if _headless:
		return
	var l: Line2D = Line2D.new()
	l.top_level = true
	l.material = Tex.add_mat()
	l.width = 4.0
	l.default_color = Color(color.r, color.g, color.b, 0.95)
	var n: int = 6
	var pts: PackedVector2Array = PackedVector2Array()
	var perp: Vector2 = (b - a).orthogonal().normalized()
	for i in n + 1:
		var base: Vector2 = a.lerp(b, float(i) / n)
		var j: float = 0.0 if (i == 0 or i == n) else randf_range(-18.0, 18.0)
		pts.append(base + perp * j)
	l.points = pts
	fx_layer.add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.18)
	tw.tween_callback(l.queue_free)

# The shield bubble releasing its pulse: an expanding shockwave from the mech out to the shield
# radius + a light flash, so the discharge READS as a release of stored energy, not a blink.
func aura_discharge_fx(pos: Vector2, radius: float, color: Color) -> void:
	if _headless:
		return
	_ring(pos, color, radius * 0.35, radius * 1.12, 0.30)
	_light_pop(pos, color, 1.5, 0.16, radius / 90.0)

# Energy-shield hit ripple (used by shielded enemies and the player's guard).
func shield_ripple(pos: Vector2, radius: float, color: Color) -> void:
	_ring(pos, color, radius * 0.6, radius * 1.15, 0.22)
	_flash_sprite(pos, color, radius * 0.9, 0.12)

func shield_break(pos: Vector2, radius: float, color: Color) -> void:
	_ring(pos, color, radius * 0.4, radius * 1.5, 0.34)
	_flash_sprite(pos, color, radius * 1.4, 0.22)
	_debris(pos, color, 16, 0.5, 150.0, 360.0)
	Events.screen_shake.emit(4.0)

# ---- FX ----
func _muzzle_flash(pos: Vector2, dir: Vector2, color: Color = Palette.CYAN) -> void:
	var bright: Color = color.lerp(Color.WHITE, 0.62)
	
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.muzzle_tex()
	s.material = _add_mat()
	s.position = pos
	s.rotation = dir.angle()
	s.modulate = bright
	s.scale = Vector2(0.2, 0.15)
	fx_layer.add_child(s)
	
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2(1.1, 0.8), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position", pos + dir * 10.0, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)

	_light_pop(pos + dir * 6.0, color, 1.9, 0.12, 1.1)

func _damage_number(pos: Vector2, amt: int, crit: bool) -> void:
	if crit:
		spawn_vfx("crit", pos, 0.0, 0.7)   # red-gold starburst on a critical hit
	if not bool(SaveManager.data.get("settings", {}).get("damage_numbers", true)):
		return
	if _dmg_active > 26:
		return
	# 🚨 « le 14 est un chiffre blanc sur cercle blanc au milieu de lignes dorees ; le 28 est
	# dore dans un anneau dore. On les lit mal. » Trois corrections : un CONTOUR noir epais,
	# une teinte froide qui tranche avec la gerbe (chaude), et un decalage lateral aleatoire
	# pour ne plus empiler le chiffre pile sur le coeur de l'explosion.
	var l: Label = Label.new()
	l.text = str(amt)
	l.position = pos + Vector2(randf_range(-34.0, 18.0), -30.0)
	l.z_index = 100
	l.add_theme_font_size_override("font_size", 30 if crit else 23)
	l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28) if crit else Color(0.80, 0.95, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", 7 if crit else 6)
	fx_layer.add_child(l)
	_dmg_active += 1
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector2(0, -42), 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		l.queue_free()
		_dmg_active -= 1)

# --- HIT SPARKS: the single biggest allocation source in the game ---
# Every damage tick used to build 6 nodes INCLUDING a CPUParticles2D, unpooled and unthrottled.
# An AoE hit on 25 foes made 150 nodes in one frame, and the Overdrive beam — which calls
# take_damage on every enemy in range EVERY physics frame — reached ~5400 objects/second. That is
# the stutter reported on mid-range Android.
# Fix: no particle system here (6 specks are invisible in a swarm anyway), and a token bucket so
# bursts still read punchy while sustained output is hard-capped. Big one-off events (deaths,
# explosions) keep their full debris — they are rare.
const SPARK_RATE: float = 26.0     # sustained sparks per second
const SPARK_BURST: float = 14.0    # instantaneous allowance
var _spark_tokens: float = SPARK_BURST

func _on_hit_spark(pos: Vector2, color: Color) -> void:
	if _headless or _spark_tokens < 1.0:
		return
	_spark_tokens -= 1.0
	_flash_sprite(pos, color, 48.0, 0.12)

# --- Animated VFX (baked Kenney-particle spritesheets, ADDITIVE, pooled) ---
const VFX_DEF: Dictionary = {
	"explosion": {"frames": 16, "fps": 30},
	"muzzle":    {"frames": 6,  "fps": 34},
	"impact":    {"frames": 10, "fps": 34},
	"slash":     {"frames": 9,  "fps": 30},
	"levelup":   {"frames": 16, "fps": 26},
	"crit":      {"frames": 9,  "fps": 28},
	"energy":    {"frames": 14, "fps": 24},
	"shockwave": {"frames": 12, "fps": 30},
	"shield":    {"frames": 16, "fps": 22},
	"heal":      {"frames": 16, "fps": 24},
	"portal":    {"frames": 16, "fps": 26},
	"pickup":    {"frames": 9,  "fps": 30},
	# --- STYLE "Dark contrast premium" (Agent 9) + saveurs feu/électrique, baked from the VFX
	# workflow. Additive, one vivid bloomed accent per effect on deep black. ---
	"dp_muzzle": {"frames": 16, "fps": 34},
	"dp_tracer": {"frames": 24, "fps": 30},
	"dp_blast":  {"frames": 24, "fps": 30},
	"dp_beam":   {"frames": 18, "fps": 28},
	"dp_aoe":    {"frames": 24, "fps": 26},
	"dp_sabre":  {"frames": 24, "fps": 30},
	"fire_blast":{"frames": 24, "fps": 30},
	"elec_beam": {"frames": 24, "fps": 28},
	# HQ pipeline (my own HDR+bloom, Agent-9 aesthetic but punchy) — used for the weapon casts/impacts
	"hq_muzzle":   {"frames": 28, "fps": 40},
	"hq_impact":   {"frames": 28, "fps": 40},
	"hq_explosion":{"frames": 28, "fps": 32},
	"hq_beam":     {"frames": 28, "fps": 30},
	"hq_aoe":      {"frames": 28, "fps": 28},
	"hq_sabre":    {"frames": 28, "fps": 32},
	# AAA pipeline (256px HDR multi-scale bloom + ACES, dark-premium) — the spectacular cores.
	# White-hot sheets tint to each weapon's accent; explosion/aoe keep their native fire/plasma hue.
	"aaa_muzzle":    {"frames": 28, "fps": 68},
	"aaa_impact":    {"frames": 28, "fps": 72},
	"aaa_explosion": {"frames": 30, "fps": 58},
	"aaa_beam":      {"frames": 26, "fps": 62},
	"aaa_aoe":       {"frames": 28, "fps": 54},
	"aaa_sabre":     {"frames": 26, "fps": 58},
	"aaa_shockwave": {"frames": 26, "fps": 62},
	"aaa_charge":    {"frames": 28, "fps": 46},
}
var _vfx_pool: Array = []
var _vfx_tex: Dictionary = {}   # id -> Texture2D (cached load)
var cover_list: Array = []      # decor props (PropScatter) enemies steer around (blocks the player physically)
var _scatter: Node2D            # current PropScatter — rebuilt per biome on next_map()

## Play a one-shot animated effect. pos=anchor, rot(rad)=orientation, scl scales the 160px cell,
## col tints it (sheets are neutral white on black). Pooled -> no alloc in the hot loop.
func spawn_vfx(id: String, pos: Vector2, rot: float = 0.0, scl: float = 1.0, col: Color = Color.WHITE,
		stretch: Vector2 = Vector2.ONE) -> void:
	var d: Dictionary = VFX_DEF.get(id, {})
	if d.is_empty() or fx_layer == null:
		return
	if not _vfx_tex.has(id):
		var p: String = "res://assets/vfx/%s.png" % id
		_vfx_tex[id] = load(p) if ResourceLoader.exists(p) else null
	var tex: Texture2D = _vfx_tex[id]
	if tex == null:
		return
	var v: VfxSprite
	if _vfx_pool.is_empty():
		v = VfxSprite.new()
		v.game = self
		fx_layer.add_child(v)
	else:
		v = _vfx_pool.pop_back()
	v.play(tex, int(d["frames"]), float(d["fps"]), pos, rot, scl, col, stretch)

func reclaim_vfx(v: VfxSprite) -> void:
	if _vfx_pool.size() < 40:
		_vfx_pool.append(v)
	else:
		v.queue_free()

var _sig_vfx_tex: Dictionary = {}

## Single-frame 1024x1024 additive signature VFX on solid black background.
## Tweened ease-out scale & fade to create a high-contrast glowing bloom effect.
func spawn_signature_vfx(vfx_name: String, pos: Vector2, rot: float = 0.0, scl: float = 1.0, dur: float = 0.45, col: Color = Color.WHITE) -> void:
	if _headless or fx_layer == null:
		return
	if not _sig_vfx_tex.has(vfx_name):
		var p: String = "res://assets/vfx/%s.png" % vfx_name
		_sig_vfx_tex[vfx_name] = load(p) if ResourceLoader.exists(p) else null
	var tex: Texture2D = _sig_vfx_tex[vfx_name]
	if tex == null:
		return
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = true
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.position = pos
	s.rotation = rot
	# 1024px single frame: scale base is ~0.24 (245px) scaled by scl
	var base_sc: float = 0.24 * scl
	s.scale = Vector2(base_sc * 0.45, base_sc * 0.45)
	s.modulate = col
	fx_layer.add_child(s)
	
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2(base_sc * 1.35, base_sc * 1.35), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)

func death_fx(pos: Vector2, rank: int, flash: bool = true) -> void:
	if rank >= 2:
		hit_stop(0.05)   # punchy freeze on heavy/elite kills
	var col: Color = Color(1.0, 0.72, 0.32)
	_debris(pos, col, 12 + rank * 12, 0.5, 130.0, 360.0)
	# 'flash' = the full destruction burst. The "explosion" sheet is literally a LIGHTNING bolt,
	# and enemies die non-stop in the swarm -> they pass flash=false and get a soft shockwave
	# puff instead. Crates/props and the endboss (rare events) keep the full lightning burst.
	if flash:
		spawn_vfx("aaa_explosion", pos, 0.0, 0.72 + rank * 0.5)   # AAA fireball on crates/boss deaths
		_flash_sprite(pos, col, 118.0 + rank * 80.0, 0.20)
		_ring(pos, col, 14.0, 96.0 + rank * 90.0, 0.34)
		_smoke(pos, 4 + rank * 3)
	else:
		spawn_vfx("shockwave", pos, 0.0, 0.5 + rank * 0.22, Color(1.0, 0.62, 0.34))
		# death glow: additive sprite (capped by _light_pop) — one per kill, so it scaled with the horde
		_light_pop(pos, col, 2.3 + float(rank), 0.28, 1.5 + rank * 0.4)
	Events.screen_shake.emit((5.0 + rank * 6.0) if flash else (2.0 + rank * 3.0))

## A broken robot carcass frees the guardian dormant inside it. Two-beat transition so the
## reveal reads: (1) the wreck discharges energy + a warning ring, (2) ~0.45s later a portal
## tears open and the big sentinel steps out. Never blocks: if anything is missing we just
## spawn the foe.
## A beacon structure emits an enemy near itself. Small hatch flash so the source is readable —
## the player should learn "that thing keeps making enemies, kill it".
func beacon_spawn(pos: Vector2, kind: String) -> void:
	if spawner == null or not is_instance_valid(spawner):
		return
	var at: Vector2 = pos + Vector2(randf_range(-70.0, 70.0), randf_range(30.0, 90.0))
	if not _headless:
		_ring(at, Color(1.0, 0.4, 0.25), 8.0, 70.0, 0.3)
	spawner.spawn_at(at, kind)
	if OS.get_cmdline_user_args().has("--perf"):
		print("[beacon] emission %s @ %s" % [kind, at.round()])

func awaken_enemy(pos: Vector2, kind: String) -> void:
	var col: Color = Color(1.0, 0.45, 0.25)
	# beat 1 — the wreck wakes up
	spawn_vfx("energy", pos, 0.0, 2.0, col)
	_ring(pos, col, 20.0, 240.0, 0.45)
	_debris(pos, col, 16, 0.5, 90.0, 260.0)
	Events.screen_shake.emit(7.0)
	Audio.sfx("boss", 0.0)
	if _headless:
		_awaken_spawn(pos, kind, col)   # tests must not depend on a timer
		return
	var t: SceneTreeTimer = get_tree().create_timer(0.45)
	t.timeout.connect(_awaken_spawn.bind(pos, kind, col))

func _awaken_spawn(pos: Vector2, kind: String, col: Color) -> void:
	if not GameState.alive or spawner == null or not is_instance_valid(spawner):
		return
	# beat 2 — the portal tears open and the guardian is there
	spawn_vfx("portal", pos, 0.0, 2.6, col)
	_flash_sprite(pos, col, 260.0, 0.24)
	Events.screen_shake.emit(11.0)
	var e: Enemy = spawner.spawn_kind_at(kind, pos)
	if e != null:
		show_banner("!  GARDIEN REVEILLE  !", col)

## Brief real-time freeze for weighty impacts (crits / heavy deaths). Uses an
## ignore-time-scale timer so it self-restores even while the game is slowed.
func hit_stop(dur: float) -> void:
	if _hitstop or _headless:
		return
	_hitstop = true
	Engine.time_scale = 0.03
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop = false

# Volcanic biome ground hazard: a telegraphed lava eruption that hurts the player if
# they linger in it. Telegraphs (red ring grows) then bursts.
func _spawn_lava_hazard() -> void:
	var ang: float = randf() * TAU
	var pos: Vector2 = player.global_position + Vector2(cos(ang), sin(ang)) * randf_range(110.0, 430.0)
	var R: float = 96.0
	var warn: Sprite2D = Sprite2D.new()
	warn.texture = Tex.ring(Color(1.0, 0.32, 0.1), 128)
	warn.material = _add_mat()
	warn.position = pos
	warn.scale = Vector2.ONE * (R * 2.0 / 128.0)
	warn.modulate = Color(1.0, 0.4, 0.1, 0.0)
	fx_layer.add_child(warn)
	var tw: Tween = create_tween()
	tw.tween_property(warn, "modulate:a", 0.85, 0.7)   # telegraph window
	tw.tween_callback(func() -> void:
		_flash_sprite(pos, Color(1.0, 0.6, 0.2), R * 2.4, 0.22)
		_ring(pos, Color(1.0, 0.5, 0.15), R * 0.5, R * 1.7, 0.32)
		_debris(pos, Color(1.0, 0.5, 0.2), 14, 0.5, 150.0, 380.0)
		Events.screen_shake.emit(4.0)
		if GameState.alive and player != null and player.global_position.distance_to(pos) < R:
			if player.has_method("take_damage"):
				player.take_damage(14.0, pos)
		warn.queue_free())

func show_banner(text: String, color: Color = Color(1.0, 0.92, 0.7)) -> void:
	if text == "" or _headless:
		return
	var cl: CanvasLayer = CanvasLayer.new(); cl.layer = 20
	add_child(cl)
	var lb: Label = Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", Palette.fs(32))
	lb.add_theme_color_override("font_color", color)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lb.add_theme_constant_override("outline_size", 6)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lb.offset_top = 74.0
	lb.offset_bottom = 120.0
	cl.add_child(lb)
	lb.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(lb, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.4)
	tw.tween_property(lb, "modulate:a", 0.0, 0.6)
	tw.tween_callback(cl.queue_free)

## INDICE d'apprentissage : une PHRASE, pas un titre.
## show_banner() est calibre pour deux mots (police 32, pas de retour a la ligne, ancre en
## haut a 74 px) : une phrase y deborderait horizontalement sur ecran etroit et viendrait se
## poser sur le bandeau du HUD, qui descend jusqu'a ~137 px en portrait. Les indices vivent
## donc EN BAS, au-dessus du bouton SURCHARGE, avec retour a la ligne et un fond lisible.
func show_hint(text: String, color: Color = Color(0.72, 0.92, 1.0), duree: float = 4.5) -> void:
	if text == "" or _headless:
		return
	# 🚨 un indice ne doit jamais apparaitre alors que la partie est finie : l'ecran de
	# resultats est au calque 40, l'indice au 22 — il serait invisible, mais surtout il
	# parlerait dans le vide. Mesure : immobile, le joueur meurt en ~14 s, soit AVANT la
	# fin de la sequence d'accueil.
	if not GameState.alive:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: float = clampf(minf(vp.x, vp.y) / 720.0, 0.62, 1.75)
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 22
	add_child(cl)
	var pc: PanelContainer = PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pc.offset_left = 24.0 * k
	pc.offset_right = -24.0 * k
	pc.offset_top = -(196.0 * k)
	pc.offset_bottom = -(122.0 * k)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.07, 0.80)
	sb.border_color = Color(color.r, color.g, color.b, 0.55)
	sb.set_border_width_all(maxi(1, int(2.0 * k)))
	sb.set_corner_radius_all(int(8.0 * k))
	sb.content_margin_left = 16.0 * k
	sb.content_margin_right = 16.0 * k
	sb.content_margin_top = 10.0 * k
	sb.content_margin_bottom = 10.0 * k
	pc.add_theme_stylebox_override("panel", sb)
	cl.add_child(pc)
	var lb: Label = Label.new()
	lb.text = text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.add_theme_font_size_override("font_size", Palette.fs(17))
	lb.add_theme_color_override("font_color", color)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lb.add_theme_constant_override("outline_size", 4)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(lb)
	pc.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(pc, "modulate:a", 1.0, 0.35)
	tw.tween_interval(duree)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(cl.queue_free)

## PREMIERE PARTIE : le jeu n'expliquait AUCUNE de ses quatre mecaniques de base (deplacement,
## tir automatique, SURCHARGE, gemmes) et ne contient aucun tutoriel — verifie : zero occurrence
## de « tutoriel » dans tout le code. Trois jeux de reference sur quatre enseignent au moins leur
## regle centrale ; le seul qui n'explique rien (Vampire Survivors) n'a QU'UN seul verbe, alors
## qu'ici il y en a deux (se deplacer + declencher la SURCHARGE). D'ou ces deux phrases, montrees
## une seule fois dans la vie du joueur.
func _first_run_hints() -> void:
	if _bot or _headless:
		return
	if not bool(SaveManager.data.get("first_run", true)):
		return
	# 🚨 le drapeau n'est consomme qu'une fois la sequence TERMINEE. Consomme des l'entree,
	# il grillait les indices d'une partie ou le joueur meurt avant la fin : or immobile on
	# meurt en ~14 s, et le dernier indice tombe a 12 s. Le mauvais cote de l'erreur est de
	# revoir un indice une fois de trop, pas de ne jamais le voir.
	# SEQUENCEMENT. Cinq messages se bousculaient dans les 15 premieres secondes (titre de
	# secteur, nom du protocole, description du protocole, et les deux indices) alors qu'un
	# joueur immobile meurt en ~14 s. Le plus utile passe donc en PREMIER, tout de suite :
	#   t=1,2 s  deplacement + tir auto  (indice, en bas)
	#   t=3,5 s  nom du protocole        (banniere, en haut — voir _announce_protocols)
	#   t=7,0 s  effet du protocole      (indice, en bas)
	#   t=12 s   gemmes                  (indice, en bas)
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	show_hint("Déplacez-vous avec les FLÈCHES ou le stick  —  le tir est AUTOMATIQUE.", Color(0.66, 0.95, 1.0), 4.6)
	await get_tree().create_timer(10.8).timeout
	if not is_inside_tree():
		return
	show_hint("Ramassez les gemmes laissées par les ennemis : elles font monter de niveau.", Color(0.6, 1.0, 0.78), 4.6)
	SaveManager.data["first_run"] = false        # sequence allee au bout : on ne la rejoue plus
	SaveManager.save_data()

## La SURCHARGE est la SEULE action manuelle du jeu, et son effet est enorme — 8 s
## d'invincibilite, vitesse doublee, aimant a XP global et rayon d'energie continu — mais rien
## a l'ecran ne le disait : le bouton affiche juste « SURCHARGE ». Explique une fois, la
## premiere fois que la jauge se remplit.
func _on_overdrive_hint(v: float) -> void:
	if _bot or _headless or v < 1.0:
		return
	if bool(SaveManager.data.get("seen_od_hint", false)):
		return
	SaveManager.data["seen_od_hint"] = true
	SaveManager.save_data()
	show_hint("SURCHARGE prête : appuyez pour 8 s d'invincibilité, vitesse doublée et aimant total.",
		Color(1.0, 0.82, 0.32), 5.5)

## Rapport de test Manus (26/09) : « comment utiliser les caisses ou elements du decor » n'etait
## explique nulle part — aucun indice n'existait pour le decor destructible, contrairement au
## mouvement/gemmes/Surcharge qui en ont deja un. Meme motif : une fois, la premiere fois que
## le joueur en detruit un, peu importe la partie (cf. _on_overdrive_hint juste au-dessus).
func hint_prop_destroyed() -> void:
	if _bot or _headless:
		return
	if bool(SaveManager.data.get("seen_prop_hint", false)):
		return
	SaveManager.data["seen_prop_hint"] = true
	SaveManager.save_data()
	show_hint("Détruisez les caisses et éléments du décor : ils lâchent XP, ferraille, soin ou une compétence.",
		Color(0.85, 0.95, 0.6), 5.0)

## PANCARTE de decor (14/10, patron : « certains decors n'ont aucun effet visible, on ne sait pas
## a quoi ils servent ») : la PREMIERE fois qu'un decor a effet (PropScatter.INFO) passe a portee de
## vue, une pancarte l'explique — nom, effet, et l'action a faire pour l'activer. Une seule fois par
## type de decor dans toute la vie du joueur (SaveManager.data["seen_props"]) ; file d'attente pour
## que deux decors vus ensemble ne se recouvrent pas. Le drapeau est consomme AU MOMENT de
## l'affichage (pas a la fin) : un joueur qui meurt pendant la pancarte l'a bien lue.
var _pancarte_queue: Array = []   # [cle, texture, id du decor/ennemi, info]
const PANCARTE_PROX: float = 460.0   # le joueur doit etre encore PRES du decor au moment d'afficher

## ENNEMIS (14/10) : meme pancarte, meme regle (une fois, a proximite). Cle = comportement, pas le
## nom du chassis : tout nouvel ennemi d'un comportement deja explique reste couvert. (Le roster est
## vide pour la publication — ces pancartes servent des que des ennemis reviennent, boss compris.)
const ENEMY_INFO: Dictionary = {
	"rush": ["Ennemi de mêlée", "Fonce sur vous au corps à corps et peut charger : gardez vos distances en tirant.", "orange"],
	"ranged": ["Tireur", "Garde ses distances et vous tire dessus : rapprochez-vous ou esquivez ses tirs.", "orange"],
	"dasher": ["Bondisseur", "Il se fige et clignote en rouge, puis fonce en ligne droite : esquivez de côté juste après.", "orange"],
	"healer": ["Réparateur", "Soigne les ennemis proches (rayon vert) : cible prioritaire.", "green"],
	"carrier": ["Porteur", "Il fuit devant vous mais laisse un bonus à sa mort : poursuivez-le si le risque en vaut la peine.", "gold"],
	"pusher": ["Disperseur", "N'attaque pas, mais repousse les ennemis proches pour casser vos positions statiques.", "magenta"],
	"miner": ["Mineur", "Pose des zones explosives au sol (cercle marqué) : sortez du cercle avant l'explosion.", "orange"],
	"kamikaze": ["Kamikaze", "Fonce, allume une mèche puis explose sur vous : tuez-le avant, ou reculez.", "orange"],
	"boss": ["Boss", "Bien plus résistant ; il change d'attaques quand sa vie descend (50 % puis 20 %).", "magenta"],
}

func pancarte_prop(kind: String, tex: Texture2D, prop: Node2D = null) -> void:
	if PropScatter.INFO.has(kind):
		_pancarte_add(kind, PropScatter.INFO[kind], tex, prop)

func pancarte_enemy(key: String, tex: Texture2D, node: Node2D = null) -> void:
	# 19/10 : une planche d'animation (ex. 6 images de 176 px cote a cote) s'affichait ENTIERE, en bande minuscule : on ne garde que l'image 1
	if tex != null and tex.get_height() > 0 and tex.get_width() >= tex.get_height() * 3:
		var at: AtlasTexture = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, tex.get_height(), tex.get_height())
		tex = at
	if ENEMY_INFO.has(key):
		_pancarte_add("enemy:" + key, ENEMY_INFO[key], tex, node)

var _pancarte_migre: bool = false

func _pancarte_add(key: String, info: Array, tex: Texture2D, node: Node2D) -> void:
	if _bot or _headless:
		return
	# 14/10 : les premieres versions des pancartes marquaient « vu » un decor des la mise en file, avant
	# tout affichage (et plusieurs versions ne les affichaient jamais). Les sauvegardes existantes
	# contiennent donc des decors « vus » qui n'ont jamais ete lus -> remise a zero UNE fois.
	if not _pancarte_migre:
		_pancarte_migre = true
		if int(SaveManager.data.get("seen_props_ver", 0)) < 2:
			SaveManager.data["seen_props"] = {}
			SaveManager.data["seen_props_ver"] = 2
			SaveManager.save_data()
	var seen: Dictionary = SaveManager.data.get("seen_props", {}) as Dictionary
	if bool(seen.get(key, false)):
		return
	for q in _pancarte_queue:   # deja en attente : le balayage la redemande toutes les 0,3 s
		if q[0] == key:
			return
	# l'ID, jamais l'objet : le decor peut etre libere (chunk dechargé) pendant l'attente, et caster un
	# objet libere plante l'export Web (« memory access out of bounds » / « null function »).
	_pancarte_queue.append([key, tex, node.get_instance_id() if node != null else 0, info])

## Balayage des ennemis proches (appele par Game._process, cadence limitee).
var _pancarte_enemy_t: float = 0.0
func _scan_enemy_pancartes(delta: float) -> void:
	_pancarte_enemy_t -= delta
	if _pancarte_enemy_t > 0.0 or _bot or _headless or player == null or not is_instance_valid(player):
		return
	_pancarte_enemy_t = 0.3
	var r2: float = 320.0 * 320.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or not is_instance_valid(e):
			continue
		var en: Enemy = e as Enemy
		if en.global_position.distance_squared_to(player.global_position) > r2:
			continue
		var key: String = "boss" if (en.rank >= 2 or en.is_final) else en.behavior
		var tex: Texture2D = en._spr.texture if en._spr != null else null
		pancarte_enemy(key, tex, en)

## « Le joueur est-il encore pres de ce qui a declenche la pancarte ? » Pour un decor on interroge le
## scatter COURANT par TYPE (le scatter est reconstruit au demarrage / a chaque changement de map :
## l'objet repere au moment de la mise en file peut avoir ete libere entre-temps, et en garder la
## reference plantait l'export Web). Pour un ennemi on garde l'ID de l'instance.
func _pancarte_dist(key: String, node_id: int) -> float:
	if player == null or not is_instance_valid(player):
		return 1e9
	if key.begins_with("enemy:"):
		var o: Object = instance_from_id(node_id) if node_id != 0 else null
		if o == null or not is_instance_valid(o) or not (o is Node2D):
			return 1e9
		return (o as Node2D).global_position.distance_to(player.global_position)
	if _scatter == null or not is_instance_valid(_scatter):
		return 1e9
	return (_scatter as PropScatter).kind_dist(key, player.global_position)

## Pancarte COURANTE : une seule a l'ecran. 14/10 (patron : « elle doit s'afficher des qu'on passe pres
## de quelque chose, et CHANGER immediatement des qu'on croise autre chose de nouveau ») : plus
## d'attente de 17 s, plus de file qui s'egrene — une nouveaute proche REMPLACE la pancarte affichee,
## apres un minimum de 0,5 s de lecture (sinon deux nouveautes dans le meme balayage se mangeraient
## sans qu'aucune soit lue ; la seconde patiente, non memorisee, jusqu'a ce delai). Pas de coroutine
## (un `await` en boucle plantait l'export Web — « null function ») : Game._process appelle ceci a
## chaque frame.
const PANCARTE_MIN_LECTURE: float = 0.5   # 14/10 : etait 1,5 s -> la nouveaute remplace la pancarte quasi tout de suite
var _pancarte_layer: CanvasLayer = null
var _pancarte_tween: Tween = null
var _pancarte_t0: float = 0.0   # Time.get_ticks_msec() de l'affichage courant

func _pancarte_pump() -> void:
	if _pancarte_queue.is_empty() or not GameState.alive:
		return
	if _pancarte_layer != null and is_instance_valid(_pancarte_layer) 			and float(Time.get_ticks_msec() - _pancarte_t0) < PANCARTE_MIN_LECTURE * 1000.0:
		return
	# la nouveaute la PLUS PROCHE encore a portee gagne ; celles qui ne le sont plus sont oubliees
	# (non memorisees : elles reviendront a la prochaine approche)
	var best_i: int = -1
	var best_d: float = PANCARTE_PROX
	var i: int = _pancarte_queue.size() - 1
	while i >= 0:
		var q: Array = _pancarte_queue[i]
		var d: float = _pancarte_dist(String(q[0]), int(q[2]))
		if d > PANCARTE_PROX:
			_pancarte_queue.remove_at(i)
		elif d <= best_d:
			best_d = d
			best_i = i
		i -= 1
	if best_i < 0 or best_i >= _pancarte_queue.size():
		return
	var it: Array = _pancarte_queue[best_i]
	_pancarte_queue.remove_at(best_i)
	var seen: Dictionary = SaveManager.data.get("seen_props", {}) as Dictionary
	seen[String(it[0])] = true   # memorise AU MOMENT de l'affichage (un joueur qui meurt l'a lue)
	SaveManager.data["seen_props"] = seen
	SaveManager.save_data()
	_pancarte_show(it[3] as Array, it[1] as Texture2D)

func _pancarte_show(info: Array, tex: Texture2D) -> void:
	var col: Color = Palette.CYAN
	match String(info[2]):
		"orange": col = Color(1.0, 0.62, 0.25)
		"green": col = Color(0.5, 1.0, 0.6)
		"magenta": col = Color(1.0, 0.45, 0.9)
		"gold": col = Color(1.0, 0.85, 0.35)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: float = clampf(minf(vp.x, vp.y) / 720.0, 0.62, 1.75)
	# remplace sans transition la pancarte precedente (voir _pancarte_pump)
	if _pancarte_tween != null and _pancarte_tween.is_valid():
		_pancarte_tween.kill()
	if _pancarte_layer != null and is_instance_valid(_pancarte_layer):
		_pancarte_layer.queue_free()
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 23   # au-dessus des indices (22), sous l'ecran de resultats (40)
	add_child(cl)
	_pancarte_layer = cl
	_pancarte_t0 = float(Time.get_ticks_msec())
	var pc: PanelContainer = PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pc.offset_left = 20.0 * k
	pc.offset_right = -20.0 * k
	pc.offset_top = -(318.0 * k)
	pc.offset_bottom = -(206.0 * k)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.9)
	sb.border_color = col
	sb.set_border_width_all(maxi(2, int(3.0 * k)))
	sb.border_width_top = maxi(4, int(6.0 * k))   # liseré haut epais = « planche » de pancarte
	sb.set_corner_radius_all(int(6.0 * k))
	sb.content_margin_left = 14.0 * k
	sb.content_margin_right = 14.0 * k
	sb.content_margin_top = 8.0 * k
	sb.content_margin_bottom = 8.0 * k
	pc.add_theme_stylebox_override("panel", sb)
	cl.add_child(pc)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(14.0 * k))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)
	if tex != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(76.0 * k, 76.0 * k)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var col_txt: VBoxContainer = VBoxContainer.new()
	col_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_txt.alignment = BoxContainer.ALIGNMENT_CENTER
	col_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col_txt)
	var title: Label = Label.new()
	title.text = String(info[0]).to_upper()
	title.add_theme_font_size_override("font_size", Palette.fs(19))
	title.add_theme_color_override("font_color", col)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_txt.add_child(title)
	var body: Label = Label.new()
	body.text = String(info[1])
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", Palette.fs(16))
	body.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	body.add_theme_constant_override("outline_size", 3)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_txt.add_child(body)
	pc.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(pc, "modulate:a", 1.0, 0.08)
	tw.tween_interval(6.5)
	tw.tween_property(pc, "modulate:a", 0.0, 0.5)
	tw.tween_callback(cl.queue_free)
	_pancarte_tween = tw

## 04/10 tour 2 : textures FX procedurales generees au chargement de la partie (cachees dans
## l'autoload Tex -> une seule fois par session), sinon le 1er impact de chaque type saccade.
func _prewarm_fx() -> void:
	Tex.spark_tex(); Tex.puff_tex(); Tex.shard_tex(); Tex.shock_tex(); Tex.flare_tex()
	Tex.disc_tex(); Tex.hazard_ring_tex(); Tex.scorch_tex()
	Tex.glow(Color.WHITE, 128); Tex.glow(Color.WHITE, 32)

# 04/10 tour 2 : flash = coeur qui JAILLIT (ease-out expo) puis s'eteint en ease-in, au lieu
# d'un grossissement lineaire mou.
func _flash_sprite(pos: Vector2, color: Color, size: float, dur: float) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.glow(color, 64)
	s.material = _add_mat()
	s.position = pos
	s.scale = Vector2.ONE * (size * 0.35 / 64.0)
	fx_layer.add_child(s)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (size / 64.0), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)

# 04/10 tour 2 : onde a FRONT NET (Tex.shock_tex, blanche teintee) avec inertie (ease-out expo)
# et fondu tardif (ease-in cubic) -> une vraie onde de pression, plus un anneau gaussien mou.
func _ring(pos: Vector2, color: Color, r0: float, r1: float, dur: float) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.shock_tex()
	s.material = _add_mat()
	s.position = pos
	s.modulate = color
	s.scale = Vector2.ONE * (r0 / 128.0)
	fx_layer.add_child(s)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (r1 / 128.0), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)

# 04/10 tour 2 : les debris etaient des CARRES sans texture, tous projetes dans le cone par
# defaut de CPUParticles2D (45 deg vers la droite). Maintenant : etincelles etirees alignees sur
# leur vitesse, gerbe a 360 deg, refroidissement blanc -> couleur -> sombre (FxKit.sparks).
func _debris(pos: Vector2, color: Color, n: int, life: float, vmin: float, vmax: float) -> void:
	if _headless:
		return
	FxKit.sparks(self, pos, color, n, vmin, vmax * 1.25, life * 1.15, Vector2(0.0, 260.0), 0.85)

func _level_fx() -> void:
	spawn_vfx("levelup", player.global_position, 0.0, 1.35)   # animated golden burst + rising stars
	_ring(player.global_position, Palette.CYAN, 24.0, 340.0, 0.5)
	Events.screen_shake.emit(4.0)

func transform_fx(pos: Vector2, into: bool) -> void:
	if into:
		spawn_vfx("energy", pos, 0.0, 2.4)   # swirling energy burst on Overdrive transform
		# 🚨 HABILLAGE "BUTIN DE GUERRE" (patron, 23/09) : la SURCHARGE est deja nommee
		# "HARVESTER" en interne (_transform_on) — un anneau qui SE REFERME (r0>r1, l'inverse
		# des anneaux qui s'ouvrent juste en dessous) juste avant l'eclat donne la lecture
		# "le mecha absorbe la casse du champ de bataille" avant de la relacher. Reutilise
		# _ring() tel quel, aucune nouvelle primitive, aucun reglage existant touche.
		_ring(pos, col_absorption(), 480.0, 16.0, 0.22)
	var col: Color = Palette.CYAN if into else Color(0.6, 0.72, 0.92)
	_flash_sprite(pos, col, 280.0, 0.38)
	_ring(pos, col, 20.0, 430.0, 0.55)
	_ring(pos, col, 12.0, 260.0, 0.4)
	_debris(pos, col, 24, 0.6, 170.0, 440.0)
	Events.screen_shake.emit(13.0 if into else 6.0)

## Teinte de l'anneau d'absorption : un cyan legerement plus chaud/dore que celui de
## l'eclat qui suit, pour que les deux temps (absorption puis relachement) se distinguent
## a l'oeil au lieu de se confondre en un seul flash.
func col_absorption() -> Color:
	return Color(0.85, 0.92, 0.55)

## ONE shared additive material for every FX node. It used to return a fresh CanvasItemMaterial per
## node — and two nodes with distinct material instances can never batch, so a busy frame produced
## 800-1000+ draw calls where a mid-range Adreno holds 300-600 at 60 fps. Nothing mutates it, so
## sharing is safe.
func _add_mat() -> CanvasItemMaterial:
	return Tex.add_mat()

# short-lived coloured light burst (adds punch to explosions / energy hits)
var _lightpop_active: int = 0
## A soft glow flash at an impact. Was a real PointLight2D per hit — devastating on mobile,
## since every dynamic light forces a canvas re-render, and a bullet-heaven spawns dozens per
## second. Now a cheap ADDITIVE sprite (no re-render) with a hard cap so a big crowd can't
## flood the frame. The floor no longer lights up, but the bloom-flash reads the same.
func _light_pop(pos: Vector2, color: Color, energy: float, dur: float, scale: float) -> void:
	if _headless or _lightpop_active > 14:   # cap: never let flashes alone tank the framerate
		return
	_lightpop_active += 1
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.glow(color, 128)
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.position = pos
	s.scale = Vector2.ONE * scale * 1.5
	s.modulate = Color(color.r, color.g, color.b, clampf(energy * 0.4, 0.0, 1.0))
	s.z_index = 41
	fx_layer.add_child(s)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.tween_property(s, "scale", s.scale * 1.35, dur)
	tw.chain().tween_callback(func() -> void:
		_lightpop_active -= 1
		s.queue_free())

# a bright thin lance along the shot direction (railgun/annihilator signature)
func _streak(pos: Vector2, dir: Vector2, color: Color, length: float, width: float, dur: float) -> void:
	if _headless:
		return
	var d: Vector2 = dir if dir != Vector2.ZERO else Vector2.RIGHT
	var ln: Line2D = Line2D.new()
	ln.width = width
	ln.default_color = color
	ln.material = _add_mat()
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.add_point(pos - d * length * 0.5)
	ln.add_point(pos + d * length * 0.5)
	fx_layer.add_child(ln)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(ln, "width", 0.0, dur)
	tw.tween_property(ln, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(ln.queue_free)

# dark smoke puff drifting up (explosions)
# 04/10 tour 2 : bouffees bruitees qui tournent et gonflent (FxKit.smoke) au lieu de carres gris.
func _smoke(pos: Vector2, n: int) -> void:
	if _headless:
		return
	FxKit.smoke(self, pos, maxi(1, n), Color(0.11, 0.1, 0.11), 0.8, 0.6, false, 40.0, 70.0)

# jagged electric arcs radiating out (plasma/singularity signature)
func _arcs(pos: Vector2, color: Color, n: int, length: float) -> void:
	if _headless:
		return
	for i in n:
		var ang: float = randf() * TAU
		var ln: Line2D = Line2D.new()
		ln.width = 2.5
		ln.default_color = color
		ln.material = _add_mat()
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.position = pos
		ln.add_point(Vector2.ZERO)
		var steps: int = 4
		for s in range(1, steps + 1):
			var t: float = float(s) / float(steps)
			var along: Vector2 = Vector2.from_angle(ang) * length * t
			along += Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
			ln.add_point(along)
		fx_layer.add_child(ln)
		var tw: Tween = create_tween()
		tw.tween_property(ln, "modulate:a", 0.0, 0.16)
		tw.tween_callback(ln.queue_free)

func _build_environment() -> void:
	var floor_cl: CanvasLayer = CanvasLayer.new()
	floor_cl.layer = -100
	add_child(floor_cl)
	var fr: ColorRect = ColorRect.new()
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome = _pick_biome()
	var biome_name: String = BIOMES[clampi(_biome, 0, BIOMES.size() - 1)]
	_mods = BIOME_MODS.get(biome_name, {})
	_hazard = String(_mods.get("hazard", ""))
	_floor_mat = ShaderMaterial.new()
	_apply_biome_floor(biome_name)
	fr.material = _floor_mat
	floor_cl.add_child(fr)
	# Gemini decor scatter: biome-coherent props that block the player + enemies and (crates)
	# can be broken for a competence. Added under the floor layer so actors walk in front.
	_scatter_decor(biome_name)
	var vig_cl: CanvasLayer = CanvasLayer.new()
	vig_cl.layer = 15
	add_child(vig_cl)
	var vr: ColorRect = ColorRect.new()
	vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm: ShaderMaterial = ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vm.set_shader_parameter("strength", 0.5)
	vr.material = vm
	vig_cl.add_child(vr)

## (Re)build the Gemini decor scatter for a biome. Called at build AND on every next_map so a
## cleared zone gets ITS biome's props (else 'ruines' buildings never appear via progression and
## old colliders linger in cover_list).
func _scatter_decor(biome_name: String) -> void:
	if _scatter != null and is_instance_valid(_scatter):
		_scatter.queue_free()
	cover_list.clear()
	_map_phase_shown = -1   # 04/10 : nouveau biome -> jamais bannerer son tout premier etat de map
	var s: PropScatter = PropScatter.new()
	s.game = self
	s.biome = biome_name
	s.z_index = -1        # world-space, behind the actors, above the floor CanvasLayer
	if BOUNDED:
		s.arena_half = ARENA_HALF   # fixed decor across the whole bounded arena (no streaming)
	add_child(s)
	s.populate(28)                  # arena_half=0 -> legacy infinite streaming (decor follows player)
	if BOUNDED:
		s.build_border(ARENA_HALF)  # the ring of indestructible natural elements walling the arena
	_scatter = s

## Each map has its OWN ambience (assets/audio/music/<biome>.ogg), themed to the biome and
## deliberately calm — never aggressive. Audio.music() no-ops on a missing track and crossfades
## over 1s, so this is safe even if a biome has no bespoke piece yet.
func _biome_music() -> void:
	Audio.music(BIOMES[clampi(_biome, 0, BIOMES.size() - 1)])

func _apply_biome_floor(biome_name: String) -> void:
	# Point the (persistent) floor material at this biome's ground. Used at build time
	# and again on every map change, so switching zones only repaints — no rebuild.
	var ground_path: String = "res://assets/decor/ground_%s.png" % biome_name
	if ResourceLoader.exists(ground_path) or FileAccess.file_exists(ground_path):
		# seamless Blender-baked ground tile, repeated in world space (sharp + scrolls)
		_floor_mat.shader = load("res://shaders/floor_tex.gdshader")
		_floor_mat.set_shader_parameter("ground", Tex.get_tex(ground_path))
		_floor_mat.set_shader_parameter("tile", 1080.0)   # ~1 tile per screen -> no side-by-side repeat
	else:
		_floor_mat.shader = load("res://shaders/floor.gdshader")
		_floor_mat.set_shader_parameter("biome", float(_biome))   # 0 tech / 1 earth / 2 spaceship / 3 volcanic

	# Bornes d'arene : UNIQUEMENT en mode BOUNDED.
	# 🚨 05/10 : ce bloc s'appliquait sans condition -> clamp du joueur a +-2810 et limites de
	# camera a +-3170 alors que la map est INFINIE (BOUNDED = false, aucun anneau de bordure
	# construit). Resultat vecu par le patron : un MUR INVISIBLE qui bloque le mecha en pleine map.
	if BOUNDED:
		if player != null:
			player.arena = Rect2(-ARENA_CLAMP, -ARENA_CLAMP, ARENA_CLAMP * 2.0, ARENA_CLAMP * 2.0)
		if spawner != null:
			spawner.arena = Rect2(-ARENA_CLAMP, -ARENA_CLAMP, ARENA_CLAMP * 2.0, ARENA_CLAMP * 2.0)
		if cam != null:
			var lim: int = int(ARENA_HALF + 170.0)
			cam.limit_left = -lim; cam.limit_right = lim; cam.limit_top = -lim; cam.limit_bottom = lim


# A major threat down -> advance to a NEW zone. Difficulty is NEVER reset: run_time keeps
# climbing AND each cleared map adds a permanent escalation (tougher foes on every new map).
func next_map() -> void:
	if not _bot:
		await _map_outro(BIOMES[clampi(_biome, 0, BIOMES.size() - 1)])   # victory panel: sector cleared
	_maps_cleared += 1
	_biome = (_biome + 1) % BIOMES.size()
	var biome_name: String = BIOMES[_biome]
	_mods = BIOME_MODS.get(biome_name, {})
	_hazard = String(_mods.get("hazard", ""))
	if _floor_mat != null:
		_apply_biome_floor(biome_name)
	_scatter_decor(biome_name)   # rebuild decor for the new biome (else ruines props never appear)
	if _ambient != null and _ambient.has_method("apply_biome"):
		_ambient.apply_biome(biome_name)
	_apply_biome_lighting(biome_name)
	if spawner != null:
		spawner.speed_mult = float(_mods.get("enemy_speed_mult", 1.0))
		spawner.spawn_mult = float(_mods.get("enemy_spawn_mult", 1.0))
		spawner.current_biome = biome_name                                  # nouveau pool d'ennemis
		spawner.enemy_tint = EnemySpawner.BIOME_TINT.get(biome_name, Color(1, 1, 1))  # nouvelle corruption
		# Single source of truth: recomputed on every zone change, so the SANS FIN ratchet can't be
		# wiped by a later next_map() (it would be, if the wave bonus were added with += elsewhere).
		spawner.difficulty_bonus = float(_maps_cleared) * 0.18 + float(GameState.endless_wave) * 0.25
	if player != null:
		player.move_mult = float(_mods.get("player_speed_mult", 1.0))
		player.biome_proj_speed = float(_mods.get("player_proj_speed", 1.0))
		player.inertia = float(_mods.get("player_inertia", 0.0))
		if player.has_method("grant_invuln"):
			player.grant_invuln(1.5)   # brief breather during the transition flash
	# quick "zone shift" flash so the repaint reads as an event, not a glitch
	Events.screen_shake.emit(6.0)
	show_banner("ZONE %d  —  %s" % [_maps_cleared + 1, String(_mods.get("label", biome_name.to_upper()))],
		Color(0.55, 0.95, 1.0))
	_biome_music()   # the new zone brings its own ambience (crossfades over 1s)
	if not _bot:
		await _map_intro(biome_name)   # arrival panel for the new sector

# damaging-aura pulse ring (fires each aura tick; cheap, skipped when headless)
func aura_pulse_fx(pos: Vector2, radius: float) -> void:
	if _headless:
		return
	_ring(pos, Palette.CYAN, radius * 0.82, radius * 1.1, 0.3)

# ---- level-up draft ----
func _open_draft() -> void:
	if _draft_open:
		_pending_drafts += 1   # gained another level mid-draft -> queue it, don't drop the card
		return
	_draft_open = true
	_draw_cards()
	get_tree().paused = true
	hud.show_draft(_cards, _rerolls, _banishes)
	if _headless:
		var noms: Array = []
		for c in _cards:
			noms.append(String(c.get("name", "?")))
		print("[game] DRAFT opened (level %d) — %s" % [GameState.level, " | ".join(noms)])

## Nombre d'emplacements, comme les references du genre : Vampire Survivors plafonne
## strictement a 6 armes + 6 objets passifs, Survivor.io a ~5-6 + 6. MECHA-FORGE n'avait
## AUCUN plafond : on pouvait tout accumuler (9 armes + les 6 systemes d'aide + tous les
## passifs). Or si l'on peut tout prendre, choisir n'engage plus rien — et le tirage de
## cartes est le coeur du genre. Une fois un emplacement plein, les cartes qui ouvriraient
## une NOUVELLE ligne disparaissent du tirage ; celles qui font MONTER ce qu'on possede
## deja restent, ainsi que les evolutions (qui remplacent une arme, sans en ajouter).
const MAX_ACTIFS: int = 6     # armes + systemes d'aide (aura, drone, lame, orbe, arc, brasier)
const MAX_PASSIFS: int = 6    # lignes de bonus distinctes (degats, vitesse, PV, ...)

## Emplacements occupes par categorie. L'arme de depart compte : elle occupe un actif sans
## avoir jamais ete tiree comme carte.
func _slots_used(cat: String) -> int:
	var n: int = 0
	for id: String in _passives:
		if _card_cat({"id": id}) == cat:
			n += 1
	if cat == "act":
		n += 1
		# 🚨 29/09 : ce decompte lit _passives (jamais decremente), pas WeaponSystem._weapons —
		# ca marchait par coincidence pour une EVOLUTION (swap 1-pour-1, la branche evo_ de
		# _apply_upgrade ne touche jamais _passives). Une FUSION hybride est un swap 2-pour-1 :
		# sans ce correctif, le slot reellement libere par merge_weapons() n'existerait JAMAIS
		# dans ce decompte, silencieusement (le joueur ne comprendrait pas pourquoi fusionner ne
		# debloque aucune carte active neuve). _hyb_slots_freed compense, incremente a chaque
		# fusion dans _apply_upgrade().
		n -= _hyb_slots_freed
	return n

## Nom lisible d'une arme (le catalogue GameState.WEAPONS porte les libelles francais).
func _nom_arme(wid: String) -> String:
	for w in GameState.WEAPONS:
		if String(w["id"]) == wid:
			return String(w["name"])
	return wid

## Ce que le PROCHAIN niveau de cette arme apporte, calcule depuis les formules reelles.
## Voir WeaponSystem : degats = BASE_MULT * (1 + (niv-1) * 0.25), recharge *= 0.85 a chaque
## montee, et le rayon des armes de zone croit de 16 % par niveau.
func _gain_niveau(wid: String, lv: int) -> String:
	if lv >= WeaponSystem.MAX_LEVEL:
		return "NIVEAU MAX"
	# 🚨 seule la 1re chaine passe par l'operateur % : elle seule doit doubler son signe pour
	# cent. Les litterales qui suivent s'ecrivent avec UN seul %, sinon on affiche « 15%% ».
	var bouts: Array = ["Niv.%d : +25%% degats" % (lv + 1), "tir 15% plus rapide"]
	if WeaponSystem.AOE.has(wid):
		bouts.append("+16% de rayon")
	return ", ".join(bouts)

func _draw_cards() -> void:
	var act_plein: bool = _slots_used("act") >= MAX_ACTIFS
	var pas_plein: bool = _slots_used("pas") >= MAX_PASSIFS
	# ARSENAL DU CHASSIS : une carte d'arme n'est proposee que si l'arme appartient a la gamme
	# du mecha equipe (GameState.mech_arsenal). Avant, le pool etait GLOBAL : les deux chassis
	# piochaient dans les 9 memes armes et finissaient par se ressembler. Les cartes qui ne
	# sont pas des armes (passifs, systemes d'aide) restent communes a tous.
	var gamme: Array = GameState.mech_arsenal(SaveManager.equipped_mech())
	var pool: Array = []
	var replis: Array = []      # cartes ecartees par le plafond : filet si le pool est trop maigre
	for u: Dictionary in UPGRADES:
		if _banished.has(u["id"]):
			continue
		var uid: String = String(u["id"])
		var warme: String = String(_WEAPON_CARD.get(uid, ""))
		if warme != "" and not gamme.has(warme):
			continue                     # arme hors de la gamme de ce chassis
		var neuve: bool = not _passives.has(uid)
		if warme != "" and player != null and player.has_method("weapons"):
			var ws_owned: WeaponSystem = player.weapons()
			if ws_owned != null and ws_owned.owned_weapons().has(warme):
				neuve = false
		var bloquee: bool = neuve and ((_card_cat(u) == "act" and act_plein) or (_card_cat(u) == "pas" and pas_plein))
		if bloquee:
			replis.append(u)
		else:
			pool.append(u)
	# Filet de securite : si tout est plafonne ou banni, on ne doit JAMAIS afficher un draft
	# vide — le joueur resterait bloque sur un panneau sans carte, jeu en pause.
	if pool.size() < 3:
		replis.shuffle()
		pool += replis
	pool.shuffle()
	_cards = pool.slice(0, 3)
	# DIVERSITE legere : eviter 3 cartes de la meme categorie (actives vs passifs) -> build plus riche
	if _cards.size() == 3 and _card_cat(_cards[0]) == _card_cat(_cards[1]) and _card_cat(_cards[1]) == _card_cat(_cards[2]):
		var want_cat: String = "act" if _card_cat(_cards[0]) == "pas" else "pas"
		for u2: Dictionary in pool.slice(3, pool.size()):
			if _card_cat(u2) == want_cat:
				_cards[2] = u2; break
	# guarantee-offer any eligible weapon EVOLUTION (base at MAX + required passive owned)
	var evos: Array = _eligible_evolutions()
	if not evos.is_empty():
		evos.shuffle()
		_cards = (evos.slice(0, mini(evos.size(), 3)) + _cards).slice(0, 3)
	# meme garantie pour les FUSIONS hybrides (deux armes de base MAX) — meme priorite que les
	# evolutions, les deux peuvent coexister dans le tirage (jamais plus de 3 cartes au total).
	var hybs: Array = _eligible_hybrids()
	if not hybs.is_empty():
		hybs.shuffle()
		_cards = (hybs.slice(0, mini(hybs.size(), 3)) + _cards).slice(0, 3)
	# Annoter les cartes d'arme avec CE QUE LE NIVEAU SUIVANT APPORTE.
	# 🚨 La carte disait seulement « Arme : Railgun percant (Niv.2) » : le joueur ne pouvait pas
	# savoir ce que monter cette arme lui rapporte, donc pas arbitrer entre monter une arme et en
	# prendre une neuve. C'est l'archetype du genre (chaque palier a son texte chez les clones de
	# Vampire Survivors) et c'est aussi ce que la session de test reprochait : 40 % des libelles
	# etaient opaques.
	# Le texte est DERIVE DES FORMULES (WeaponSystem : +25 % de degats par niveau, recharge x0,85,
	# AoE +16 %) et non ecrit a la main : il ne peut donc pas diverger du code si on reequilibre.
	if player != null and player.has_method("weapons"):
		var ws2: WeaponSystem = player.weapons()
		if ws2 != null:
			for i in _cards.size():
				var cid: String = String(_cards[i].get("id", ""))
				var wid: String = String(_WEAPON_CARD.get(cid, ""))
				if wid != "":
					var lv: int = ws2.weapon_level(wid)
					if lv > 0:
						var c: Dictionary = (_cards[i] as Dictionary).duplicate()
						c["name"] = "%s   —   %s" % [String(c["name"]), _gain_niveau(wid, lv)]
						_cards[i] = c
				elif cid.begins_with("evo_"):
					# Le mot « EVOLUTION » n'etait explique nulle part : on dit ce qu'il fait.
					var base_id: String = cid.substr(4)
					var c2: Dictionary = (_cards[i] as Dictionary).duplicate()
					c2["name"] = "%s   —   remplace %s et demarre au niveau max" % [
						String(c2["name"]), _nom_arme(base_id)]
					_cards[i] = c2

## Categorie d'une carte : "act" = arme/competence active, "pas" = passif/stat. Sert a diversifier le draft.
func _card_cat(c: Dictionary) -> String:
	var id: String = String(c.get("id", ""))
	if id.begins_with("w_") or id in ["aura", "drone", "blade", "orb", "arc", "pool"]:
		return "act"
	return "pas"

func _eligible_evolutions() -> Array:
	var out: Array = []
	if player == null or not player.has_method("weapons"):
		return out
	var ws: WeaponSystem = player.weapons()
	if ws == null:
		return out
	for base: String in EVO_RULES:
		var r: Dictionary = EVO_RULES[base]
		if ws.is_max(base) and _evo_cond_met(base, r["cond"]) and not ws.owned_weapons().has(r["evo"]):
			out.append({"id": "evo_" + base, "name": String(r["name"]), "evo": true})
	return out

## Verifie la condition typee d'une regle d'evolution (voir EVO_RULES). "meta" lit un niveau de
## competence PERSISTANT (achete entre les parties, SaveManager) ; "kills" lit le compteur PAR
## ARME de cette run (GameState.kills_by_weapon, alimente par Enemy.take_damage/_die).
func _evo_cond_met(base: String, cond: Dictionary) -> bool:
	match String(cond.get("type", "")):
		"meta":
			return SaveManager.meta_level(String(cond.get("key", ""))) >= int(cond.get("level", 99))
		"kills":
			return int(GameState.kills_by_weapon.get(base, 0)) >= int(cond.get("count", 999))
	return false

## Calque sur _eligible_evolutions() : une fusion exige les DEUX armes de la paire au niveau MAX
## (jamais une condition annexe — contrairement a une evolution, la "condition" d'une fusion,
## c'est deja d'avoir investi dans DEUX armes differentes jusqu'au bout).
func _eligible_hybrids() -> Array:
	var out: Array = []
	if player == null or not player.has_method("weapons"):
		return out
	var ws: WeaponSystem = player.weapons()
	if ws == null:
		return out
	for r: Dictionary in HYBRID_RULES:
		var pair: Array = r["pair"]
		var a: String = String(pair[0])
		var b: String = String(pair[1])
		if ws.is_max(a) and ws.is_max(b) and not ws.owned_weapons().has(String(r["evo"])):
			out.append({"id": "hyb_%s_%s" % [a, b], "name": String(r["name"]), "hybrid": true,
				"_pair": [a, b], "_evo": String(r["evo"])})
	return out

func _reroll_draft() -> void:
	if not _draft_open or _rerolls <= 0:
		return
	_rerolls -= 1
	Audio.sfx("click")
	_draw_cards()
	hud.show_draft(_cards, _rerolls, _banishes)

func _on_banish(index: int) -> void:
	if not _draft_open or _banishes <= 0 or index < 0 or index >= _cards.size():
		return
	var id: String = String(_cards[index].get("id", ""))
	if id.begins_with("evo_") or id.begins_with("hyb_"):
		return                      # never banish an evolution or a fusion offer
	_banishes -= 1
	if not _banished.has(id):
		_banished.append(id)
	Audio.sfx("click")
	_draw_cards()
	hud.show_draft(_cards, _rerolls, _banishes)

func _on_card_picked(index: int) -> void:
	if index >= 0 and index < _cards.size():
		_apply_upgrade(String(_cards[index].get("id", "")))
	_draft_open = false
	if _pending_drafts > 0:            # more level-ups were banked while this draft was open
		_pending_drafts -= 1
		call_deferred("_open_draft")   # keep the tree paused; open the next card
	else:
		get_tree().paused = false
		if player != null and player.has_method("reset_input_state"):
			player.reset_input_state()

func _apply_upgrade(id: String) -> void:
	if id.begins_with("evo_"):
		var base: String = id.substr(4)
		if EVO_RULES.has(base) and player.has_method("weapons"):
			player.weapons().replace_weapon(base, String(EVO_RULES[base]["evo"]))
			Audio.sfx("levelup")
			show_banner("EVOLUTION !", Color(1.0, 0.85, 0.3))
		return
	if id.begins_with("hyb_"):
		for r: Dictionary in HYBRID_RULES:
			var pair: Array = r["pair"]
			if id == "hyb_%s_%s" % [String(pair[0]), String(pair[1])]:
				if player.has_method("weapons"):
					player.weapons().merge_weapons(String(pair[0]), String(pair[1]), String(r["evo"]))
					_hyb_slots_freed += 1   # compense _slots_used("act") : fusion = swap 2-pour-1
					Audio.sfx("levelup")
					show_banner("FUSION !", Color(0.75, 0.5, 1.0))
				break
		return
	_passives[id] = int(_passives.get(id, 0)) + 1
	match id:
		"dmg": player.damage *= 1.25
		"spd": player.base_speed *= 1.12
		"hp":
			player.max_hp += 25.0
			player.hp = minf(player.max_hp, player.hp + 25.0)
			Events.player_damaged.emit(player.hp, player.max_hp)
		"haste": player.cooldown_mult = maxf(0.35, player.cooldown_mult * 0.88)
		"crit": player.crit_chance = minf(0.75, player.crit_chance + 0.08)
		"armor": player.armor = minf(0.6, player.armor + 0.08)
		"magnet": player.magnet_range += 105.0   # base is tiny now -> each pick is a real jump in reach
		"he_fuel": player.size_mult = minf(1.7, player.size_mult + 0.15)
		"ammo": player.proj_speed_mult = minf(1.6, player.proj_speed_mult + 0.12)
		"regen": player.hp_regen += 1.5
		"xpgain": GameState.run_xp_mult += 0.15
		"goldgain": GameState.run_scrap_mult += 0.20
		"w_autocannon": player.add_weapon("autocannon")
		"w_missile": player.add_weapon("missilepod")
		"w_railgun": player.add_weapon("railgun")
		"w_disperseur": player.add_weapon("disperseur")
		"w_ricochet": player.add_weapon("ricochet")
		"w_disque": player.add_weapon("disque")
		"w_faisceau": player.add_weapon("faisceau")
		"w_plasma": player.add_weapon("plasma")
		"w_sabre": player.add_weapon("sabre")
		"aura":
			player.add_aura()
			show_banner("BOUCLIER A IMPULSIONS  niv.%d" % player.aura_level, Color(0.5, 0.95, 1.0))
		"drone":
			player.add_drone()
			show_banner("DRONE DE COMBAT  x%d" % player._drones.size(), Color(0.5, 0.95, 1.0))
		"blade":
			player.add_blade()
			show_banner("LAME ORBITALE  x%d" % player._blades.size(), Color(0.5, 0.95, 1.0))
		"orb":
			player.add_orb()
			show_banner("ORBE PLASMA  x%d" % player._orbs.size(), Color(0.5, 0.95, 1.0))
		"arc":
			player.add_arc()
			show_banner("ARC TESLA  niv.%d" % player._arc_lv, Color(0.6, 0.95, 1.0))
		"pool":
			player.add_pool()
			show_banner("BRASIER PLASMA  niv.%d" % player._pool_lv, Color(0.5, 0.95, 1.0))

## Bank an in-progress run when the app leaves the foreground. A mobile session normally ends by
## a call, an app switch or a swipe-away — none of which reach the death/victory screen, so every
## bit of scrap, crystals and quest progress used to be lost. Godot delivers these notifications
## even while the tree is paused.
func _notification(what: int) -> void:
	# Godot 4 names: APPLICATION_PAUSED fires when Android backgrounds the app, FOCUS_OUT covers
	# an app switch, CLOSE_REQUEST a deliberate quit. (NOTIFICATION_WM_GO_BACKGROUND is Godot 3.)
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.alive and not _headless:
			ensure_banked(false)   # grind only: the run is not over, so no crystals and no run count

## Amounts already written to the save, so banking can happen MORE THAN ONCE per run (an app
## switch flushes mid-run, then death flushes only what came after). Without this a background
## save would consume the once-only guard and everything earned afterwards would be lost.
var _flushed_scrap: int = 0
var _flushed_kills: int = 0
var _flushed_props: int = 0
var _flushed_min: int = 0

## final = true only on death/victory: that is when the run counts as "played" and when the score
## is settled enough to pay crystals. A mid-run flush banks the grind, never the run itself.
func ensure_banked(final: bool = true) -> void:
	if _banked:
		return
	var d_scrap: int = GameState.scrap - _flushed_scrap
	if d_scrap > 0:
		SaveManager.bank_scrap(d_scrap)
		_flushed_scrap = GameState.scrap
	# Daily quests: contribute in deltas, in ONE write (never per kill — that would be a disk
	# write per enemy).
	var d_kills: int = GameState.kills - _flushed_kills
	var d_props: int = GameState.props_destroyed - _flushed_props
	var d_min: int = int(GameState.run_time / 60.0) - _flushed_min
	if d_kills > 0:
		SaveManager.quest_add("kills", d_kills); _flushed_kills = GameState.kills
	if d_props > 0:
		SaveManager.quest_add("props", d_props); _flushed_props = GameState.props_destroyed
	if d_min > 0:
		SaveManager.quest_add("time", d_min); _flushed_min = int(GameState.run_time / 60.0)
	if final:
		_banked = true   # from here the run is settled; a revive cannot double-count it
		last_crystals = SaveManager.bank_crystals_for_run(GameState.score, GameState.run_time)
		last_sp = _run_sp_reward()
		if last_sp > 0:
			SaveManager.add_sp(last_sp)   # RPG loadout progression, scaled by difficulty
		SaveManager.quest_add("runs", 1)
	SaveManager.quest_commit()

## Skill points earned this run: (1 + zones cleared + endless waves) scaled by the difficulty reward.
## Le seuil empeche de farmer en mourant volontairement pour relancer.
## 🚨 MESURE (banc : 8 parties par difficulte, biome unique, protocoles neutralises) — duree
## MEDIANE d'une partie : FACILE 124 s, NORMAL 63 s, DIFFICILE 81 s, VETERAN 82 s. Le seuil
## de 60 s, cale a l'epoque sur une partie censee durer 15 minutes, tombait donc en plein
## dans la distribution : 25 a 38 % des parties au-dessus de FACILE ne rapportaient AUCUN
## point. Un joueur qui perd n'a alors plus rien a montrer de sa partie. A 30 s, la garde
## anti-farm tient toujours (une mort volontaire est bien plus rapide) et une partie jouee
## rapporte quelque chose meme quand elle tourne mal.
const SP_MIN_RUN: float = 30.0
func _run_sp_reward() -> int:
	if GameState.run_time < SP_MIN_RUN:
		return 0
	var base: int = 1 + _maps_cleared + GameState.endless_wave * 2
	return int(ceil(base * float(GameState.diff().get("reward", 1.0))))

func _on_player_died() -> void:
	if _headless:
		ensure_banked()
		return
	var ms: MetaScreen = MetaScreen.new()   # offer a revive first, else the meta shop
	add_child(ms)
	ms.setup(self, true, not _revived)

## SANS FIN: an endboss went down but the run continues. Each wave banks score, grants a short
## breather heal, then rolls into a fresh zone — next_map() picks up the escalation.
func endless_boss_down() -> void:
	GameState.endless_wave += 1
	GameState.score += 2000 * GameState.endless_wave
	if player != null:
		player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.35)
	show_banner("VAGUE %d SURVECUE" % GameState.endless_wave, Color(1.0, 0.85, 0.3))
	Audio.sfx("victory")
	next_map()

func _on_run_won() -> void:
	if not GameState.alive:
		return
	GameState.alive = false   # stop spawns/movement, freeze the run on the win
	ensure_banked()
	# PROGRESSION : battre le boss final d'un chapitre (campagne) débloque le suivant.
	if not GameState.endless:
		var first_clear: bool = SaveManager.clear_chapter(_chapter)
		print("[game] RUN_WON chapter=%d first_clear=%s" % [_chapter, str(first_clear)])
		if first_clear:
			SaveManager.data["crystals"] = int(SaveManager.data.get("crystals", 0)) + 20
			SaveManager.bank_scrap(150)   # sauvegarde cristaux + ferraille
			show_banner("CHAPITRE %d TERMINE  —  +20 cristaux, +150 ferraille" % _chapter, Color(1.0, 0.85, 0.3))
	if _headless:
		return
	var ms: MetaScreen = MetaScreen.new()
	add_child(ms)
	ms.setup(self, false, false)

func revive_player() -> void:
	_revived = true
	GameState.alive = true
	# 🚨 le HUD se masque a la mort (il restait affiche PAR-DESSUS l'ecran de fin, B6) :
	# il faut donc le REMONTRER ici, sinon une seconde chance repartait sans barres de vie,
	# sans horloge et sans bouton SURCHARGE.
	if hud != null and is_instance_valid(hud):
		hud.visible = true
	player.hp = player.max_hp * 0.5
	if player.mecha != null:
		player.mecha.play("idle")   # get up: the death anim left the mech on the ground
	if player.has_method("grant_invuln"):
		player.grant_invuln(2.5)
	# clear the crowd around the player so the revive isn't instant death
	for e in get_tree().get_nodes_in_group("enemies"):
		# spare bosses (rank >= 3): nuking them here = free victory / free zone-skip
		if e is Enemy and (e as Enemy).rank < 3 and player.global_position.distance_to((e as Node2D).global_position) < 420.0:
			(e as Enemy).take_damage(99999.0)
	show_banner("SECONDE CHANCE", Color(0.5, 1.0, 0.6))
	Events.player_damaged.emit(player.hp, player.max_hp)

# ---- main loop + headless bot ----
func _process(delta: float) -> void:
	_frames += 1
	_scan_enemy_pancartes(delta)
	_pancarte_pump()
	_spark_tokens = minf(SPARK_BURST, _spark_tokens + SPARK_RATE * delta)
	if _perf and _frames % 60 == 0:
		var obj: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		print("[perf] t=%3.0fs ennemis=%3d fx=%4d nodes=%4d objets=%5d  delta_obj/s=%+d" % [
			GameState.run_time, get_tree().get_nodes_in_group("enemies").size(),
			fx_layer.get_child_count() if fx_layer != null else 0,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), obj,
			obj - _perf_last_obj])
		_perf_last_obj = obj
	if _floor_mat != null and player != null:
		_floor_mat.set_shader_parameter("world_offset", player.global_position)
		_floor_mat.set_shader_parameter("vp_size", get_viewport_rect().size)
		_floor_mat.set_shader_parameter("time", GameState.run_time)
	if GameState.alive and not _draft_open and not get_tree().paused:
		GameState.run_time += delta
		Events.run_time_changed.emit(GameState.run_time)
		# 04/10, bannière discrète pour la derive silencieuse d'une map a l'autre a l'interieur
		# d'un chapitre (cf. MAP_PHASE_NAMES plus haut). Jamais au tout premier calcul (idx 0 des
		# le debut du run) : deja couvert par la banniere/intro du changement de BIOME.
		if _scatter != null and is_instance_valid(_scatter) and MAP_PHASE_NAMES.has(_scatter.biome):
			var _ph: int = _scatter.current_map_phase()
			if _map_phase_shown < 0:
				_map_phase_shown = _ph
			elif _ph != _map_phase_shown:
				_map_phase_shown = _ph
				show_banner("ZONE : " + String(MAP_PHASE_NAMES[_scatter.biome][_ph]), Color(0.75, 0.9, 1.0))
		if _hazard == "lava" and player != null:
			_hazard_t -= delta
			if _hazard_t <= 0.0:
				_hazard_t = randf_range(1.1, 1.9)
				_spawn_lava_hazard()
		

	if bool(SaveManager.data.get("settings", {}).get("shake", true)) and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 34.0)
		cam.offset = CAM_OFFSET + Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif cam.offset != CAM_OFFSET:
		cam.offset = CAM_OFFSET

	if _bot:
		_drive_bot()
		if _headless and _frames % 60 == 0:
			print("[game] f=%d t=%.0fs lvl=%d xp=%d/%d kills=%d hp=%.0f enemies=%d gems=%d" % [
				_frames, GameState.run_time, GameState.level, GameState.xp, GameState.xp_to_next,
				GameState.kills, player.hp, get_tree().get_nodes_in_group("enemies").size(),
				get_tree().get_nodes_in_group("pickups").size()])
		# 🚨 La partie headless continuait jusqu'au budget d'images MEME APRES LA MORT : sur une
		# partie ou le bot meurt a 42 s pour un budget de 210 s, on brulait 80 % du temps de
		# simulation a re-imprimer la meme ligne. Sur un banc de 12 parties c'est plus d'une
		# heure perdue. On s'arrete 1,5 s apres la mort : la mesure est finie, le reste est du
		# vide. (Le budget reste la borne haute pour les parties ou le bot survit.)
		if _headless and not GameState.alive:
			_mort_t += get_process_delta_time()
			if _mort_t >= 1.5:
				_finish_headless()
		if _headless and _frames >= _headless_frames:
			_finish_headless()

func _drive_bot() -> void:
	if _headless and _frames == 1050 and GameState.overdrive < 1.0:
		GameState.overdrive = 1.0     # CI: force-fill LATE so normal collection/level-up runs first, then beam
		Events.overdrive_changed.emit(1.0)
	if _draft_open:
		hud.pick(0)
		return
	if not GameState.alive:
		player.bot_move = Vector2.ZERO
		return
	var strafe: Vector2 = Vector2(cos(GameState.run_time * 2.0), sin(GameState.run_time * 2.0)) * 0.35
	# --- MENACE : on fuit la MASSE, pas le plus proche -------------------------------------
	# 🚨 Le bot ne regardait QUE l'ennemi le plus proche (< 140 px). Dans une horde, s'ecarter
	# d'un seul ennemi, c'est foncer dans les autres.
	# On calcule donc une repulsion ponderee par l'inverse de la distance sur tous les
	# ennemis proches : le resultat pointe vers l'espace libre.
	var pp: Vector2 = player.global_position
	var repulse: Vector2 = Vector2.ZERO
	var serres: int = 0
	var plus_proche: float = 1.0e12
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D):
			continue
		var v: Vector2 = pp - (e as Node2D).global_position
		var dd: float = v.length()
		if dd < 260.0 and dd > 1.0:
			repulse += v / (dd * dd)      # 1/d : les colles pesent bien plus que les lointains
			plus_proche = minf(plus_proche, dd)
			if dd < 150.0:
				serres += 1
	var danger: Vector2 = Vector2.ZERO
	if repulse != Vector2.ZERO and plus_proche < 170.0:
		danger = repulse.normalized()
	# Le bot n'esquive plus : l'esquive a ete RETIREE du jeu (voir Player.gd). Le banc a
	# 3 bras l'avait de toute facon mesuree nuisible — plus il esquivait, plus vite il
	# mourait. Il ne reste que la fuite vers l'espace libre, calculee ci-dessus.
	var move: Vector2 = danger
	if danger == Vector2.ZERO:
		var gem: Node2D = _nearest_pickup()
		if gem != null:
			move = (gem.global_position - player.global_position).normalized()
		else:
			move = strafe + (Vector2.ZERO - player.global_position) * 0.0006
	player.bot_move = (move + strafe * 0.2).limit_length(1.0)

func _pick_biome() -> int:
	# On web, allow forcing a biome via the URL hash (#0..#3) for demos; otherwise random.
	# eval returns a NUMBER: 0 when no hash (-> random), else biome+1.
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("location.hash.length>1 ? ((parseInt(location.hash.slice(1))||0)+1) : 0", true)
		if v != null and int(v) > 0:
			return clampi(int(v) - 1, 0, BIOMES.size() - 1)
	# headless test hook: `-- --biome=tech` forces a biome so a smoke can exercise its props
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--biome="):
			var want: String = a.substr(8)
			var idx: int = BIOMES.find(want)
			if idx >= 0:
				return idx
	return randi() % BIOMES.size()

func _nearest_pickup() -> Node2D:
	var best: Node2D = null
	var bd: float = 1.0e12
	for g in get_tree().get_nodes_in_group("pickups"):
		if g is Node2D:
			var d: float = player.global_position.distance_squared_to((g as Node2D).global_position)
			if d < bd:
				bd = d
				best = g
	return best

func _finish_headless() -> void:
	# require a real vertical slice: kills + XP + at least one level-up/draft resolved
	var ok: bool = GameState.kills > 0 and GameState.level >= 2 and player.get_layer_ok()
	
	# 04/10: Si le roster ennemi est vide (publication itch sans ennemis), on passe le smoke.
	if spawner != null and spawner.DEFS.is_empty():
		ok = true
		
	if ok:
		# pv/dmg exposed so mech + meta-talent + GEAR stat plumbing is checkable from the smoke run
		# od = Overdrive uptime: the player is INVINCIBLE while transformed, so a high percentage
		# means the run is unloseable. Anything approaching 100% is a balance failure, not a stat.
		var od_pct: float = 0.0
		if GameState.run_time > 0.0:
			od_pct = GameState.overdrive_time / GameState.run_time * 100.0
		# Pic d'arcs simultanes : sert a savoir si le plafond ARC_CAP a REELLEMENT joue.
		# Un plafond jamais atteint n'explique rien — autant le savoir.
		print("[game] ARCS pic=%d/%d palier_max=%d" % [Enemy._arcs_pic, Enemy.ARC_CAP, Enemy._palier_max_run])
		# 🚨 TEMPORAIRE (banc du 23/09) : les trois systemes non joues depuis leur ecriture.
		# L'IQ ennemie (Enemy.gd, 4 couches) n'avait AUCUNE trace de banc — contrairement au
		# palier d'ARME ci-dessus, qui est un systeme different malgre le nom voisin. On
		# recalcule ici la MEME formule que Enemy._iq() (t/IQ_TEMPS vs (niveau-1)/IQ_NIVEAU,
		# le plus rapide des deux) pour savoir combien de couches ont eu une CHANCE de jouer.
		var iq_final: float = maxf(GameState.run_time / Enemy.IQ_TEMPS,
			float(GameState.level - 1) / Enemy.IQ_NIVEAU)
		print("[game] BANC decor_detruits=%d missiles_tires=%d iq_finale=%.2f encerclement=%s patience=%s opportunisme=%s emprunts=%d rendus=%d" % [
			PropScatter._detruits_bench, EnemyProjectile._tires_bench, iq_final,
			str(GameState.run_time > Enemy.IQ_FLANC_T), str(GameState.run_time > Enemy.IQ_PATIENCE_T),
			str(GameState.run_time > Enemy.IQ_OPPORTUNISME_T),
			Player._emprunts_bench, Player._rendus_bench])
		print("[game] SMOKE PASS — kills=%d level=%d scrap=%d pv=%d dmg=%.2f endless=%s vague=%d od=%dx/%.0f%% (draft exercised), 0 errors" % [
			GameState.kills, GameState.level, GameState.scrap, int(player.max_hp), player.damage,
			str(GameState.endless), GameState.endless_wave, GameState.overdrive_count, od_pct])
		get_tree().quit(0)
	else:
		print("[game] SMOKE FAIL — kills=%d level=%d (level-up/draft not reached)" % [
			GameState.kills, GameState.level])
		get_tree().quit(1)

