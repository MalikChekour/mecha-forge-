extends RefCounted
## (charge par preload dans EnemySpawner : pas de class_name -> pas de cache de classes a regenerer)
## VAGUES PAR TRANCHE DE TEMPS (05/11, patron : « chaque type d'ennemis arrive par vagues successives par tranche de temps,
## pas tous des les premieres secondes, et plus coriaces a l'approche du mini-boss / boss »).
## Modele repris des jeux du genre (voir _waves_progress.md) :
##   - Vampire Survivors / HoloCure : une table par minute, chaque type a une FENETRE de presence (les faibles s'effacent) ;
##   - Survivor.io : 1 type au depart, un nouveau toutes les 1-2 min, horde avant l'elite, boss 5/10/15, blindes apres un boss ;
##   - Brotato : PV et degats montent LINEAIREMENT (+8 %/min, +4 %/min), la vitesse ne monte pas ;
##   - Halls of Torment : une elite juste avant chaque boss ; HoloCure : PV du boss selon sa minute d'apparition.
## Emplacements (slots) -> ennemi reel du biome (EnemySpawner._wv_kind) :
##   melee = ennemi de base en melee (mechNN_melee) | swarm = essaim rapide (mechNN_swarm) | tir = ennemi de base tireur (mechNN, role du
##   profil du niveau) | shield = blinde a bouclier (mechNN_shield) | kami = kamikaze (mechNN_kami) | sniper = mechNN_sniper |
##   summoner = invocateur (mechNN_summoner). « mk2 » = part de MARK 2 (variante blindee de la base), « elite » = facteur de
##   chance d'elite aleatoire, « dens » = densite (cadence + plancher de population).
## Le chapitre 1 est regle a la main (CH1) ; les chapitres 2-18 sont GENERES par build(tier) avec la meme logique.

const SLOTS: Array[String] = ["melee", "swarm", "tir", "shield", "kami", "sniper", "summoner"]
const FODDER: Array[String] = ["melee", "swarm", "kami"]   # hordes : uniquement la pietaille
const SLOT_LABEL: Dictionary = {"melee": "FANTASSINS", "swarm": "UNITES RAPIDES", "tir": "TIREURS", "shield": "BOUCLIERS",
	"kami": "KAMIKAZES", "sniper": "SNIPERS", "summoner": "INVOCATEURS"}

const CH1: Array = [
	{"t": 0.0,   "w": {"melee": 10},                                                                          "dens": 0.85, "elite": 0.0, "mk2": 0.0},
	{"t": 90.0,  "w": {"melee": 8, "swarm": 5},                                                               "dens": 1.00, "elite": 0.0, "mk2": 0.0},
	{"t": 180.0, "w": {"melee": 6, "swarm": 5, "tir": 4},                                                     "dens": 1.00, "elite": 1.0, "mk2": 0.0},
	{"t": 240.0, "w": {"melee": 5, "swarm": 5, "tir": 5, "shield": 2},                                        "dens": 1.10, "elite": 1.0, "mk2": 0.0},
	{"t": 300.0, "w": {"melee": 4, "swarm": 4, "tir": 5, "shield": 3},                                        "dens": 1.00, "elite": 1.2, "mk2": 0.25},
	{"t": 360.0, "w": {"melee": 3, "swarm": 4, "tir": 5, "shield": 3, "kami": 3},                             "dens": 1.15, "elite": 1.2, "mk2": 0.30},
	{"t": 450.0, "w": {"melee": 2, "swarm": 3, "tir": 5, "shield": 3, "kami": 3, "sniper": 2},                "dens": 1.25, "elite": 1.4, "mk2": 0.35},
	{"t": 540.0, "w": {"melee": 1, "swarm": 3, "tir": 5, "shield": 4, "kami": 3, "sniper": 3, "summoner": 1}, "dens": 1.30, "elite": 1.6, "mk2": 0.50},
	{"t": 600.0, "w": {"swarm": 3, "tir": 5, "shield": 4, "kami": 3, "sniper": 3, "summoner": 2},             "dens": 1.25, "elite": 1.8, "mk2": 0.70},
	{"t": 660.0, "w": {"swarm": 3, "tir": 4, "shield": 4, "kami": 3, "sniper": 3, "summoner": 2},             "dens": 1.40, "elite": 2.0, "mk2": 0.80},
	{"t": 900.0, "w": {"swarm": 3, "tir": 4, "shield": 4, "kami": 2, "sniper": 3, "summoner": 2},             "dens": 0.90, "elite": 2.0, "mk2": 0.80},
]
## Hordes chronometrees (Survivor.io 2:00/4:00/8:00, HoloCure « wall/ring ») : n = taille relative, lead = slot dominant.
const CH1_HORDES: Array = [
	{"t": 120.0, "n": 0.55, "lead": "melee"}, {"t": 200.0, "n": 0.75, "lead": "swarm"}, {"t": 240.0, "n": 1.30, "lead": "swarm", "big": true},
	{"t": 340.0, "n": 0.80, "lead": "melee"}, {"t": 420.0, "n": 0.90, "lead": "swarm"}, {"t": 480.0, "n": 1.00, "lead": "swarm"},
	{"t": 555.0, "n": 1.25, "lead": "swarm", "big": true}, {"t": 650.0, "n": 0.90, "lead": "swarm"}, {"t": 720.0, "n": 1.00, "lead": "melee"},
	{"t": 790.0, "n": 1.10, "lead": "swarm"}, {"t": 850.0, "n": 1.30, "lead": "swarm", "big": true},
]
const BOSS_T: Array[float] = [300.0, 600.0, 900.0]   # mini-boss 1, mini-boss 2, boss final (TIER_EVENTS boss1/boss2/boss)
const ELITE_T: Array[float] = [180.0, 285.0, 585.0, 885.0]   # 1re elite 3:00 + une elite 15 s avant chaque boss
const SURGE_LEN: float = 90.0        # montee pre-boss : 90 s
const SURGE_HP: float = 0.25         # +25 % PV en fin de montee
const SURGE_DENS: float = 0.40       # +40 % de densite en fin de montee
const HP_PER_MIN: float = 0.08
const DMG_PER_MIN: float = 0.04
const BOSS_HP_PER_MIN: float = 0.03  # en plus de la rampe : le boss de 15:00 est plus coriace que celui de 5:00
const RELIEF_S: float = 25.0         # accalmie apres la mort d'un mini-boss
const RELIEF_DENS: float = 0.30

static var _cache: Dictionary = {}

## Table du niveau de rang `tier` (1..18). tier 1 = CH1 tel quel.
static func build(tier: int) -> Dictionary:
	if _cache.has(tier):
		return _cache[tier]
	var slices: Array = []
	var hordes: Array = []
	var x: float = clampf(float(tier - 1) / 17.0, 0.0, 1.0)
	var k: float = lerpf(1.0, 0.7, x)          # les introductions arrivent plus tot dans les chapitres avances
	for s in CH1:
		var d: Dictionary = (s as Dictionary).duplicate(true)
		d["t"] = _squeeze(float(s["t"]), k)
		d["dens"] = float(s["dens"]) * (1.0 + 0.012 * float(tier - 1))
		d["mk2"] = minf(float(s["mk2"]) + (0.015 * float(tier - 1) if float(s["t"]) >= 300.0 else 0.0), 0.9)
		if tier >= 4 and float(s["t"]) < 90.0:
			(d["w"] as Dictionary)["swarm"] = 2      # chapitres avances : 2 types des le depart
		if tier >= 7 and float(s["t"]) >= 180.0 and float(s["t"]) < 300.0:
			(d["w"] as Dictionary)["kami"] = 1       # puis les roles speciaux plus tot
		slices.append(d)
	for h in CH1_HORDES:
		var hd: Dictionary = (h as Dictionary).duplicate()
		hd["t"] = _squeeze(float(h["t"]), k)
		hd["n"] = float(h["n"]) * (1.0 + 0.01 * float(tier - 1))
		hordes.append(hd)
	var elites: Array[float] = []
	for e in ELITE_T:
		elites.append(e if e > 200.0 else _squeeze(e, k))
	var out: Dictionary = {"slices": slices, "hordes": hordes, "elites": elites, "tier": tier}
	_cache[tier] = out
	return out

## Les debuts de tranche se resserrent vers le debut de leur segment de boss (0-5, 5-10, 10-15 min) ; les boss restent a 5/10/15.
static func _squeeze(t: float, k: float) -> float:
	if t >= 900.0:
		return t
	var seg: float = floorf(t / 300.0) * 300.0
	return seg + (t - seg) * k

static func slice_idx(sched: Dictionary, t: float) -> int:
	var sl: Array = sched["slices"]
	var k: int = 0
	for i in sl.size():
		if t >= float(sl[i]["t"]):
			k = i
	return k

static func slice(sched: Dictionary, t: float) -> Dictionary:
	return (sched["slices"] as Array)[slice_idx(sched, t)]

## 0 hors fenetre ; 0 -> 1 pendant les 90 s qui precedent un boss (5:00, 10:00, 15:00).
static func surge(t: float) -> float:
	for b in BOSS_T:
		if t >= b - SURGE_LEN and t < b:
			return clampf((t - (b - SURGE_LEN)) / SURGE_LEN, 0.0, 1.0)
	return 0.0

static func hp_mult(t: float) -> float:
	return (1.0 + HP_PER_MIN * t / 60.0) * (1.0 + SURGE_HP * surge(t))

static func dmg_mult(t: float) -> float:
	return 1.0 + DMG_PER_MIN * t / 60.0

static func boss_hp_mult(t: float) -> float:
	return 1.0 + BOSS_HP_PER_MIN * t / 60.0

static func dens(sched: Dictionary, t: float) -> float:
	return float(slice(sched, t)["dens"]) * (1.0 + SURGE_DENS * surge(t))

## Premier instant ou `slot` a un poids > 0 (pour la reduction de degats des snipers a leur arrivee).
static func intro_t(sched: Dictionary, slot: String) -> float:
	for s in sched["slices"]:
		if int((s["w"] as Dictionary).get(slot, 0)) > 0:
			return float(s["t"])
	return 1.0e9

static func pick(sched: Dictionary, t: float, fodder_only: bool) -> String:
	var w: Dictionary = slice(sched, t)["w"]
	var tot: int = 0
	for s in w:
		if fodder_only and not FODDER.has(String(s)):
			continue
		tot += int(w[s])
	if tot <= 0:
		return "melee" if int(w.get("melee", 0)) > 0 or fodder_only else "tir"
	var r: int = randi() % tot
	for s in w:
		if fodder_only and not FODDER.has(String(s)):
			continue
		r -= int(w[s])
		if r < 0:
			return String(s)
	return "melee"

static func allowed(sched: Dictionary, t: float, slot: String) -> bool:
	return int((slice(sched, t)["w"] as Dictionary).get(slot, 0)) > 0

## Texte lisible de la table (rapport / banc).
static func describe(tier: int) -> String:
	var s: Dictionary = build(tier)
	var lines: PackedStringArray = []
	for sl in s["slices"]:
		var t: float = float(sl["t"])
		lines.append("%02d:%02d %s dens=%.2f mk2=%.0f%% elite=x%.1f" % [int(t) / 60, int(t) % 60, str(sl["w"]), float(sl["dens"]), 100.0 * float(sl["mk2"]), float(sl["elite"])])
	return "\n".join(lines)
