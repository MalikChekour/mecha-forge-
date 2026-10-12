extends Node
## Minimal persistence (meta scrap + settings) to user://. Expanded in Phase 2
## (meta tree, chassis, unlocks).

const PATH: String = "user://mecha_forge_save.json"

var data: Dictionary = {
	"meta_scrap": 0,
	# --- RPG LOADOUT: skill points are the competence currency (replaced scrap for talents). Start
	# with 7, earn more per run (scaled by difficulty), and they're monetisable (rewarded ad / IAP).
	"skill_points": 7,
	"start_weapon": "autocannon",       # weapon the run begins with (chosen in the hub)
	"weapons_unlocked": ["autocannon"], # the rest are unlocked by spending points
	"meta": {},                       # talent id -> purchased level
	"settings": {"shake": true, "damage_numbers": true,
		"music": true, "sfx": true, "auto_aim": true, "orientation": "auto",
		"endless": false},          # SANS FIN mode chosen at run start
	"difficulty": 1,                  # last chosen difficulty index
	"chapters_cleared": 0,            # PROGRESSION campagne : plus haut chapitre battu (chapitre N debloque si N <= cleared+1)
	"best_scores": {},                # difficulty index (as str) -> best score (local leaderboard)
	"owned_mechs": ["vortex"],  # unlocked chassis (base always owned)
	"equipped_mech": "vortex",
	# --- equipment economy / retention. load_data() merges per-key, so old saves absorb these. ---
	"parts": [],                      # [{uid, slot, rarity, level}] — see GEAR_* constants below
	"equipped": {},                   # slot -> part uid
	"part_uid": 1,                    # monotonic id source for new parts
	"crystals": 0,                    # gacha currency (earned per run + daily calendar)
	"cores": 0,                       # upgrade currency (from recycling spare parts)
	"ads": {},                        # {"date": "YYYY-MM-DD", "counts": {placement -> n}} daily caps
	"last_played": 0,                 # unix ts for daily reward / offline gains
	"first_run": true,                # RESERVED (Vague 1): future FTUE gate — NOT yet read (Game._ready always shows the modal)
}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if FileAccess.file_exists(PATH):
		var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for k in d:
					data[k] = d[k]
	load_visual_scales()
	_accorde_chassis_gratuits()

## Tout chassis dont le cout vaut 0 est POSSEDE d'office.
## 🚨 Sans ca, mettre un prix a 0 ne suffirait pas : l'ecran GARAGE afficherait un bouton
## « 0 » a cliquer, et surtout les sauvegardes DEJA EXISTANTES resteraient bloquees sur leur
## ancienne liste (celle du patron ne connait que VORTEX). On repasse donc la liste a chaque
## chargement : c'est ce qui rend les chassis de la phase de test immediatement jouables,
## y compris sur une partie en cours. Remettre un prix les fait repasser payants sans autre
## modification — ils ne sont PAS retires de owned_mechs, ce qui est le bon sens : un joueur
## ne doit pas perdre un chassis qu'il a pu equiper.
func _accorde_chassis_gratuits() -> void:
	var owned: Array = data.get("owned_mechs", ["vortex"])
	var change: bool = false
	for m: Dictionary in GameState.MECHS:
		var id: String = String(m["id"])
		if int(m.get("cost", 0)) == 0 and not owned.has(id):
			owned.append(id)
			change = true
	# 🚨 Si le chassis EQUIPE n'existe plus au catalogue (retire entre deux versions), on
	# retombe sur VORTEX. Sans ca, mech_def() renverrait silencieusement les stats de VORTEX
	# tout en affichant les sprites de l'ancien chassis : un mecha qui ne joue pas ce qu'il
	# montre. Cas reel : trois chassis retires apres la phase d'essai du garage.
	var eq: String = String(data.get("equipped_mech", "vortex"))
	var connu: bool = false
	for m2: Dictionary in GameState.MECHS:
		if String(m2["id"]) == eq:
			connu = true
			break
	if not connu:
		data["equipped_mech"] = "vortex"
		change = true
	if change:
		data["owned_mechs"] = owned
		save_data()

func save_data() -> void:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))

func bank_scrap(amount: int) -> void:
	data["meta_scrap"] = int(data.get("meta_scrap", 0)) + amount
	save_data()

## Cristaux earned by PLAYING (gacha currency). Without this the only source is the daily
## calendar (day 3/5/7), so a 30-crystal pull would take ~3 real days — the whole equipment
## system would stay invisible to a new player. Scales with run score so better runs pay more.
func bank_crystals_for_run(score: int, run_time: float = 999.0) -> int:
	# NO FLAT FLOOR. A flat "+4 whatever happens" made dying instantly and restarting worth ~10
	# crystals/min against ~2.5 for a well-played 15-minute run — suicide-farming beat playing 4:1.
	# Payout is now purely proportional, and a run shorter than MIN_RUN pays nothing at all.
	# 🚨 MESURE (banc, 8 parties/difficulte) : duree MEDIANE d'une partie = 124 s en FACILE,
	# mais 63 / 81 / 82 s aux trois paliers superieurs. A 90 s, 75 % des parties en NORMAL et
	# en DIFFICILE ne rapportaient AUCUN cristal — donc l'ecran EQUIPEMENT, entierement code,
	# restait quasi vide pour qui ne joue pas en FACILE. 55 s laisse la garde anti-farm
	# operante (le gain reste proportionnel au score, sans plancher) tout en rendant la
	# progression perceptible aux difficultes ou l'on joue reellement.
	const MIN_RUN: float = 55.0
	if run_time < MIN_RUN:
		return 0
	var earned: int = int(score / 1800.0)
	data["crystals"] = int(data.get("crystals", 0)) + earned
	save_data()
	return earned

func meta_level(id: String) -> int:
	var m: Dictionary = data.get("meta", {})
	return int(m.get(id, 0))

## Per-key settings access (reads with a default so old saves absorb new keys gracefully).
func setting(key: String, default_value: Variant) -> Variant:
	return (data.get("settings", {}) as Dictionary).get(key, default_value)

func set_setting(key: String, value: Variant) -> void:
	var s: Dictionary = data.get("settings", {})
	s[key] = value
	data["settings"] = s
	save_data()

# --- DAILY LOGIN REWARDS ---------------------------------------------------------------
# A 7-day escalating cycle. Claim once per calendar day; claiming on consecutive days advances
# the streak, missing a day resets it to day 1. Grants soft (ferraille) + premium (cristaux).
const DAILY_REWARDS: Array = [
	{"scrap": 60},   {"scrap": 100},  {"crystals": 20}, {"scrap": 180},
	{"crystals": 35}, {"scrap": 300}, {"crystals": 70},
]

func _today() -> String:
	var d: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _yesterday() -> String:
	# Both ends of the streak check MUST read the same clock. _today() is LOCAL, so yesterday has to
	# be derived from the local date too. Feeding real unix time to get_datetime_dict_from_unix_time
	# returns UTC: east of Greenwich that made _yesterday() point at the day BEFORE last, so a player
	# returning the next morning had their streak reset despite playing two days running (UTC+9 =
	# broken every day before 09:00 local — exactly the biggest market for this genre).
	# Round-tripping the local dict keeps the offset consistent on both sides.
	var local: Dictionary = Time.get_datetime_dict_from_system()
	var t: int = int(Time.get_unix_time_from_datetime_dict(local)) - 86400
	var y: Dictionary = Time.get_datetime_dict_from_unix_time(t)
	return "%04d-%02d-%02d" % [y.year, y.month, y.day]

func daily_claimable() -> bool:
	return String(data.get("daily_last", "")) != _today()

## Cycle day (1..7) that a claim right now would grant (streak continues from yesterday, else 1).
func daily_next_day() -> int:
	var last: String = String(data.get("daily_last", ""))
	if last == "" or last == _yesterday() or last == _today():
		return clampi(int(data.get("daily_day", 1)), 1, 7)
	return 1   # a day was missed -> streak resets

func claim_daily() -> Dictionary:
	if not daily_claimable():
		return {}
	var day: int = daily_next_day()
	var reward: Dictionary = DAILY_REWARDS[(day - 1) % 7]
	_grant_reward(reward)
	data["daily_last"] = _today()
	data["daily_day"] = (day % 7) + 1   # advance for tomorrow
	save_data()
	return {"day": day, "reward": reward}

## Add a bundle of currencies (used by daily, quests, gacha refunds…).
func _grant_reward(r: Dictionary) -> void:
	data["meta_scrap"] = int(data.get("meta_scrap", 0)) + int(r.get("scrap", 0))
	data["crystals"] = int(data.get("crystals", 0)) + int(r.get("crystals", 0))
	data["cores"] = int(data.get("cores", 0)) + int(r.get("cores", 0))

# --- DAILY QUESTS ----------------------------------------------------------------------
# 3 objectives per day, picked by rotating the pool with the date (stable all day). Progress
# is CUMULATIVE across the day's runs and is flushed once per run — never per kill, which
# would mean a disk write per enemy.
const QUEST_POOL: Array = [
	{"id": "kills", "desc": "Detruire %d ennemis",           "target": 150, "reward": {"scrap": 120}},
	{"id": "runs",  "desc": "Terminer %d parties",           "target": 3,   "reward": {"crystals": 25}},
	{"id": "time",  "desc": "Survivre %d minutes au total",  "target": 10,  "reward": {"scrap": 150}},
	{"id": "props", "desc": "Detruire %d objets de decor",   "target": 25,  "reward": {"scrap": 80}},
]

func quest_def(id: String) -> Dictionary:
	for q: Dictionary in QUEST_POOL:
		if String(q["id"]) == id:
			return q
	return {}

## Roll a fresh set of 3 when the calendar day changes (deterministic rotation, no RNG drift).
func _ensure_quests() -> void:
	if String(data.get("quests_date", "")) == _today():
		return
	var d: Dictionary = Time.get_datetime_dict_from_system()
	var start: int = (int(d.year) * 372 + int(d.month) * 31 + int(d.day)) % QUEST_POOL.size()
	var picked: Array = []
	for k in 3:
		var def: Dictionary = QUEST_POOL[(start + k) % QUEST_POOL.size()]
		picked.append({"id": String(def["id"]), "prog": 0, "claimed": false})
	data["quests_date"] = _today()
	data["quests"] = picked
	save_data()

func quests() -> Array:
	_ensure_quests()
	return data.get("quests", [])

## Add progress IN MEMORY only (cheap). Call quest_commit() once to persist.
func quest_add(id: String, amount: int) -> void:
	if amount <= 0:
		return
	_ensure_quests()
	for q in data.get("quests", []):
		if String(q.get("id", "")) == id and not bool(q.get("claimed", false)):
			q["prog"] = int(q.get("prog", 0)) + amount

func quest_commit() -> void:
	save_data()

## Y a-t-il quelque chose A RECLAMER, tout de suite ? (recompense du jour ou quete terminee)
## 🚨 Ces deux crochets de retention etaient entierement codes mais INVISIBLES : rien sur
## l'accueil ni sur l'ecran de fin n'indiquait qu'une recompense attendait — il fallait ouvrir
## l'ecran QUOTIDIEN pour le decouvrir. Un crochet qu'on ne voit pas ne ramene personne.
func quotidien_a_reclamer() -> bool:
	if daily_claimable():
		return true
	for q in quests():
		if bool(q.get("claimed", false)):
			continue
		var def: Dictionary = quest_def(String(q.get("id", "")))
		if not def.is_empty() and int(q.get("prog", 0)) >= int(def["target"]):
			return true
	return false

## Claim quest i if its target is reached. Returns the quest def (for the reward text) or {}.
func claim_quest(i: int) -> Dictionary:
	var qs: Array = quests()
	if i < 0 or i >= qs.size():
		return {}
	var q: Dictionary = qs[i]
	if bool(q.get("claimed", false)):
		return {}
	var def: Dictionary = quest_def(String(q.get("id", "")))
	if def.is_empty() or int(q.get("prog", 0)) < int(def["target"]):
		return {}
	q["claimed"] = true
	_grant_reward(def.get("reward", {}))
	save_data()
	return def

# --- EQUIPMENT / GEAR -------------------------------------------------------------------
# 4 slots, 4 rarities, upgradable. Economy loop: daily -> cristaux -> pulls -> parts;
# duplicate parts -> recycle -> noyaux -> upgrades. Equipped bonuses are applied by Player.
const GEAR_SLOTS: Array = ["arme", "blindage", "reacteur", "senseur"]
const GEAR_SLOT_NAMES: Dictionary = {
	"arme": "ARME", "blindage": "BLINDAGE", "reacteur": "REACTEUR", "senseur": "SENSEUR"}
const GEAR_RARITIES: Array = ["commun", "rare", "epique", "legendaire"]
const GEAR_RARITY_NAMES: Dictionary = {
	"commun": "Commun", "rare": "Rare", "epique": "Epique", "legendaire": "Legendaire"}
const GEAR_RARITY_MULT: Dictionary = {"commun": 1.0, "rare": 1.6, "epique": 2.4, "legendaire": 3.5}
const GEAR_RARITY_WEIGHT: Array = [62, 25, 10, 3]        # pull odds, same order as GEAR_RARITIES
const GEAR_SALVAGE: Dictionary = {"commun": 5, "rare": 12, "epique": 30, "legendaire": 80}
const GEAR_BASE: Dictionary = {                           # bonus at commun, level 1
	"arme":     {"stat": "damage_pct", "value": 0.06},
	"blindage": {"stat": "hp",         "value": 12.0},
	"reacteur": {"stat": "speed_pct",  "value": 0.04},
	"senseur":  {"stat": "crit",       "value": 0.03},
}
const GEAR_PULL_COST: int = 30       # cristaux
const GEAR_UPGRADE_COST: int = 15    # noyaux per level
const GEAR_MAX_LEVEL: int = 5

## FORGE DETERMINISTE (plan direction artistique, 26/09 — validee par le patron : "en plus" de
## l'invocation, pas a sa place ; plans issus des drops de boss ; Legendaire reste EXCLUSIF a
## l'invocation, jamais forgeable, pour que le jackpot garde un interet). Chaque boss non-final
## a une affinite de SLOT fixe (raison de viser tel boss plutot qu'un autre) ; le boss determine
## aussi le PALIER de rarete du plan qu'il peut laisser tomber. endboss (Souverain, universel,
## deja lie au chapitre final) laisse un plan de slot ALEATOIRE, au palier le plus genereux.
const PLAN_SLOT_BY_BOSS: Dictionary = {
	"midboss": "blindage", "crusherboss": "arme", "midboss_a": "senseur", "midboss_b": "reacteur",
}
const PLAN_DROP_CHANCE: float = 0.35
# poids de rarete du PLAN (jamais legendaire — reserve a l'invocation), par boss :
const PLAN_RARITY_WEIGHT: Dictionary = {
	"midboss": {"commun": 70, "rare": 30}, "crusherboss": {"commun": 70, "rare": 30},
	"midboss_a": {"rare": 55, "epique": 45}, "midboss_b": {"rare": 55, "epique": 45},
	"endboss": {"rare": 40, "epique": 60},
}

func plans() -> Array:
	return data.get("plans", [])

func _roll_plan_rarity(boss_kind: String) -> String:
	var weights: Dictionary = PLAN_RARITY_WEIGHT.get(boss_kind, {"commun": 100})
	var total: int = 0
	for w in weights.values():
		total += int(w)
	var r: int = randi() % maxi(1, total)
	var acc: int = 0
	for rarity: String in weights:
		acc += int(weights[rarity])
		if r < acc:
			return rarity
	return "commun"

## Appele a la mort d'un boss (Enemy._die, rank >= 3). Rend le plan si un a ete accorde ({} sinon)
## pour que l'appelant puisse afficher un indice — c'est un evenement rare, il merite d'etre dit.
func grant_boss_plan(boss_kind: String) -> Dictionary:
	if randf() > PLAN_DROP_CHANCE:
		return {}
	var slot: String = String(PLAN_SLOT_BY_BOSS.get(boss_kind, GEAR_SLOTS[randi() % GEAR_SLOTS.size()]))
	var rarity: String = _roll_plan_rarity(boss_kind)
	var plan: Dictionary = {"slot": slot, "rarity": rarity, "source": boss_kind}
	var ps: Array = plans()
	ps.append(plan)
	data["plans"] = ps
	save_data()
	return plan

## Consomme le plan a cet index : fabrique la piece EXACTE (slot + rarete garantis, pas de
## hasard) au lieu de gear_pull() qui tire les deux. Auto-equipe si le slot est vide, comme un
## tirage normal.
func forge_from_plan(index: int) -> Dictionary:
	var ps: Array = plans()
	if index < 0 or index >= ps.size():
		return {}
	var plan: Dictionary = ps[index]
	var uid: int = int(data.get("part_uid", 1))
	data["part_uid"] = uid + 1
	var part: Dictionary = {"uid": uid, "slot": String(plan["slot"]), "rarity": String(plan["rarity"]), "level": 1}
	var parts: Array = gear_parts()
	parts.append(part)
	data["parts"] = parts
	var eq: Dictionary = gear_equipped()
	if not eq.has(String(part["slot"])):
		eq[String(part["slot"])] = uid
		data["equipped"] = eq
	ps.remove_at(index)
	data["plans"] = ps
	save_data()
	return part

func gear_parts() -> Array:
	return data.get("parts", [])

func gear_equipped() -> Dictionary:
	return data.get("equipped", {})

func gear_part(uid: int) -> Dictionary:
	for p: Dictionary in gear_parts():
		if int(p.get("uid", -1)) == uid:
			return p
	return {}

## A part's bonus: base * rarity multiplier * level scaling. Returns {stat_name: value}.
func gear_bonus_of(p: Dictionary) -> Dictionary:
	var slot: String = String(p.get("slot", ""))
	if not GEAR_BASE.has(slot):
		return {}
	var base: Dictionary = GEAR_BASE[slot]
	var mult: float = float(GEAR_RARITY_MULT.get(String(p.get("rarity", "commun")), 1.0))
	var lvl: int = maxi(1, int(p.get("level", 1)))
	return {String(base["stat"]): float(base["value"]) * mult * (1.0 + 0.15 * (lvl - 1))}

## Summed bonuses of everything currently equipped (read by Player at spawn).
func gear_totals() -> Dictionary:
	var t: Dictionary = {"damage_pct": 0.0, "hp": 0.0, "speed_pct": 0.0, "crit": 0.0}
	for slot: String in GEAR_SLOTS:
		var uid: int = int(gear_equipped().get(slot, -1))
		if uid < 0:
			continue
		var p: Dictionary = gear_part(uid)
		if p.is_empty():
			continue
		var b: Dictionary = gear_bonus_of(p)
		for k in b:
			t[k] = float(t.get(k, 0.0)) + float(b[k])
	return t

func _roll_rarity() -> String:
	var total: int = 0
	for w in GEAR_RARITY_WEIGHT:
		total += int(w)
	var r: int = randi() % total
	var acc: int = 0
	for i in GEAR_RARITY_WEIGHT.size():
		acc += int(GEAR_RARITY_WEIGHT[i])
		if r < acc:
			return String(GEAR_RARITIES[i])
	return "commun"

## Spend cristaux for a random part. Returns the new part, or {} if you can't afford it.
## free = true skips the cost (rewarded-ad pull); the roll itself is identical.
func gear_pull(free: bool = false) -> Dictionary:
	if not free:
		if int(data.get("crystals", 0)) < GEAR_PULL_COST:
			return {}
		data["crystals"] = int(data["crystals"]) - GEAR_PULL_COST
	var uid: int = int(data.get("part_uid", 1))
	data["part_uid"] = uid + 1
	var part: Dictionary = {
		"uid": uid,
		"slot": String(GEAR_SLOTS[randi() % GEAR_SLOTS.size()]),
		"rarity": _roll_rarity(),
		"level": 1,
	}
	var ps: Array = gear_parts()
	ps.append(part)
	data["parts"] = ps
	# auto-equip if that slot is empty, so a first pull is immediately useful
	var eq: Dictionary = gear_equipped()
	if not eq.has(String(part["slot"])):
		eq[String(part["slot"])] = uid
		data["equipped"] = eq
	save_data()
	return part

func gear_equip(uid: int) -> void:
	var p: Dictionary = gear_part(uid)
	if p.is_empty():
		return
	var eq: Dictionary = gear_equipped()
	eq[String(p.get("slot", ""))] = uid
	data["equipped"] = eq
	save_data()

func gear_upgrade(uid: int) -> bool:
	var p: Dictionary = gear_part(uid)
	if p.is_empty() or int(p.get("level", 1)) >= GEAR_MAX_LEVEL:
		return false
	if int(data.get("cores", 0)) < GEAR_UPGRADE_COST:
		return false
	data["cores"] = int(data["cores"]) - GEAR_UPGRADE_COST
	p["level"] = int(p.get("level", 1)) + 1
	save_data()
	return true

## Recycle a part into noyaux. Equipped parts are protected (no accidental loss).
func gear_salvage(uid: int) -> bool:
	var p: Dictionary = gear_part(uid)
	if p.is_empty():
		return false
	for slot: String in gear_equipped():
		if int(gear_equipped()[slot]) == uid:
			return false   # equipped -> refuse
	var ps: Array = gear_parts()
	for i in ps.size():
		if int(ps[i].get("uid", -1)) == uid:
			ps.remove_at(i)
			break
	data["parts"] = ps
	data["cores"] = int(data.get("cores", 0)) + int(GEAR_SALVAGE.get(String(p.get("rarity", "commun")), 5))
	save_data()
	return true

# --- REWARDED-AD DAILY CAPS ---------------------------------------------------------------
# Counts reset on date change (same rotation trick as the daily quests). Kept here rather than
# in Ads.gd so a reinstall/reload can't be used to farm past the cap within a day.
func _ensure_ads() -> void:
	var a: Dictionary = data.get("ads", {})
	if String(a.get("date", "")) != _today():
		a = {"date": _today(), "counts": {}}
		data["ads"] = a

func ads_used(placement: String) -> int:
	_ensure_ads()
	return int(data["ads"].get("counts", {}).get(placement, 0))

func ads_consume(placement: String) -> void:
	_ensure_ads()
	var c: Dictionary = data["ads"].get("counts", {})
	c[placement] = int(c.get(placement, 0)) + 1
	data["ads"]["counts"] = c
	save_data()

## --- PROGRESSION EN CHAPITRES (facon Survivor.io : deblocage en chaine) ---
func chapters_cleared_count() -> int:
	return int(data.get("chapters_cleared", 0))

## Chapitre N (1-based) jouable ? Le chapitre 1 est toujours ouvert ; N s'ouvre en battant N-1.
func chapter_unlocked(n: int) -> bool:
	return n <= int(data.get("chapters_cleared", 0)) + 1

## Marque le chapitre N battu. Renvoie true si c'est un PREMIER clear (nouveau chapitre debloque).
func clear_chapter(n: int) -> bool:
	if n > int(data.get("chapters_cleared", 0)):
		data["chapters_cleared"] = n
		save_data()
		return true
	return false

func get_difficulty() -> int:
	return int(data.get("difficulty", 1))

func set_difficulty(idx: int) -> void:
	data["difficulty"] = clampi(idx, 0, GameState.DIFFICULTY.size() - 1)
	save_data()

# Record a run's score for its difficulty; returns true if it's a new personal best.
func record_score(difficulty: int, score: int) -> bool:
	var bs: Dictionary = data.get("best_scores", {})
	var key: String = str(difficulty)
	var prev: int = int(bs.get(key, 0))
	if score > prev:
		bs[key] = score
		data["best_scores"] = bs
		save_data()
		return true
	return false

func best_score(difficulty: int) -> int:
	return int(data.get("best_scores", {}).get(str(difficulty), 0))

# --- mech garage ---
func owns_mech(id: String) -> bool:
	if id == "darkstar" or id == "mecha_joueur":
		return true
	return (data.get("owned_mechs", []) as Array).has(id)

func equipped_mech() -> String:
	return String(data.get("equipped_mech", "vortex"))

func equip_mech(id: String) -> void:
	if owns_mech(id):
		data["equipped_mech"] = id
		save_data()

# Buy `id` for `cost` scrap and auto-equip. Returns true on success.
func buy_mech(id: String, cost: int) -> bool:
	if owns_mech(id) or int(data.get("meta_scrap", 0)) < cost:
		return false
	data["meta_scrap"] = int(data["meta_scrap"]) - cost
	var owned: Array = data.get("owned_mechs", [])
	owned.append(id)
	data["owned_mechs"] = owned
	data["equipped_mech"] = id
	save_data()
	return true

# Try to buy the next level of talent `id` for `cost` scrap. Returns true on success.
func buy_meta(id: String, cost: int) -> bool:
	var d: Dictionary = GameState.META.get(id, {})
	if d.is_empty():
		return false
	var m: Dictionary = data.get("meta", {})
	if int(m.get(id, 0)) >= int(d.get("max", 0)):
		return false   # already maxed: enforce the cap at the data layer, not just the UI
	if not spend_sp(cost):   # competences now cost SKILL POINTS, not scrap
		return false
	m[id] = int(m.get(id, 0)) + 1
	data["meta"] = m
	save_data()
	return true

## --- SKILL POINTS (RPG loadout currency) ---
func sp() -> int:
	return int(data.get("skill_points", 0))

func add_sp(n: int) -> void:
	data["skill_points"] = sp() + n
	save_data()

func spend_sp(n: int) -> bool:
	if sp() < n:
		return false
	data["skill_points"] = sp() - n
	save_data()
	return true

## --- STARTING WEAPONS (unlocked with points; autocannon is free) ---
func weapon_unlocked(id: String) -> bool:
	return id == "autocannon" or (data.get("weapons_unlocked", ["autocannon"]) as Array).has(id)

func unlock_weapon(id: String, cost: int) -> bool:
	if weapon_unlocked(id) or not spend_sp(cost):
		return false
	var w: Array = data.get("weapons_unlocked", ["autocannon"])
	w.append(id)
	data["weapons_unlocked"] = w
	save_data()
	return true

func start_weapon() -> String:
	return String(data.get("start_weapon", "autocannon"))

func set_start_weapon(id: String) -> void:
	if weapon_unlocked(id):
		data["start_weapon"] = id
		save_data()

## --- ÉCHELLES VISUELLES DÉCOR & VFX (configurées via le Studio Web externe) ---
var visual_scales: Dictionary = {
	"decor_global": 1.0,
	"vfx_global": 1.0,
	"decor_categories": {},
	"vfx_categories": {},
	"decor_custom": {},
	"vfx_custom": {},
}

func load_visual_scales() -> void:
	var path: String = "res://visual_scales.json"
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var txt: String = f.get_as_text()
			var p: Variant = JSON.parse_string(txt)
			if p is Dictionary:
				visual_scales = p
	if FileAccess.file_exists("user://visual_scales.json"):
		var fu: FileAccess = FileAccess.open("user://visual_scales.json", FileAccess.READ)
		if fu != null:
			var txtu: String = fu.get_as_text()
			var pu: Variant = JSON.parse_string(txtu)
			if pu is Dictionary:
				for k in pu.keys():
					visual_scales[k] = pu[k]

func get_decor_scale(kind: String, cat: String = "") -> float:
	var g: float = float(visual_scales.get("decor_global", 1.0))
	var c: float = float((visual_scales.get("decor_categories", {}) as Dictionary).get(cat, 1.0))
	var item: float = float((visual_scales.get("decor_custom", {}) as Dictionary).get(kind, 1.0))
	return clampf(g * c * item, 0.2, 3.0)

func get_vfx_scale(id: String, cat: String = "") -> float:
	var g: float = float(visual_scales.get("vfx_global", 1.0))
	var c: float = float((visual_scales.get("vfx_categories", {}) as Dictionary).get(cat, 1.0))
	var item: float = float((visual_scales.get("vfx_custom", {}) as Dictionary).get(id, 1.0))
	return clampf(g * c * item, 0.2, 3.0)
