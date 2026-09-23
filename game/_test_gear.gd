extends Node
## Headless regression harness for the EQUIPMENT system. Exercises the real SaveManager API
## (pulls, auto-equip, totals, upgrade, recycle guards, affordability) plus construction of the
## populated MetaScreen panels. Run it after touching gear or MetaScreen:
##   godot --headless --path game res://_test_gear.tscn
## It WRITES to the save — back up user://mecha_forge_save.json first.

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	seed(12345)
	print("=== TEST EQUIPEMENT ===")
	# clean slate (the real save is backed up / restored by the runner)
	SaveManager.data["parts"] = []
	SaveManager.data["equipped"] = {}
	SaveManager.data["crystals"] = 200
	SaveManager.data["cores"] = 100
	SaveManager.data["part_uid"] = 1

	# --- 1. pulls cost crystals and create parts
	var got: Array = []
	for i in 5:
		var p: Dictionary = SaveManager.gear_pull()
		if not p.is_empty():
			got.append(p)
	_ok(got.size() == 5, "5 invocations reussies", "obtenu=%d" % got.size())
	_ok(int(SaveManager.data["crystals"]) == 200 - 5 * SaveManager.GEAR_PULL_COST,
		"cristaux debites", "reste=%d attendu=%d" % [int(SaveManager.data["crystals"]), 200 - 5 * SaveManager.GEAR_PULL_COST])
	_ok(SaveManager.gear_parts().size() == 5, "inventaire = 5 pieces")
	var uids: Dictionary = {}
	for p: Dictionary in SaveManager.gear_parts():
		uids[int(p["uid"])] = true
	_ok(uids.size() == 5, "uid uniques")

	# --- 2. auto-equip filled the empty slots
	var eq: Dictionary = SaveManager.gear_equipped()
	print("  equipe: ", eq)
	var all_valid: bool = true
	for slot in eq:
		var p2: Dictionary = SaveManager.gear_part(int(eq[slot]))
		if p2.is_empty() or String(p2["slot"]) != String(slot):
			all_valid = false
	_ok(all_valid and eq.size() > 0, "auto-equipement coherent (piece du bon slot)")

	# --- 3. totals = sum of equipped bonuses only
	var manual: Dictionary = {"damage_pct": 0.0, "hp": 0.0, "speed_pct": 0.0, "crit": 0.0}
	for slot in eq:
		var b: Dictionary = SaveManager.gear_bonus_of(SaveManager.gear_part(int(eq[slot])))
		for k in b:
			manual[k] = float(manual[k]) + float(b[k])
	var tot: Dictionary = SaveManager.gear_totals()
	var same: bool = true
	for k in manual:
		if absf(float(manual[k]) - float(tot.get(k, 0.0))) > 0.0001:
			same = false
	_ok(same, "gear_totals = somme des pieces equipees", str(tot))

	# --- 4. rarity math: legendaire lvl1 = 3.5x commun lvl1
	var c1: Dictionary = SaveManager.gear_bonus_of({"slot": "blindage", "rarity": "commun", "level": 1})
	var l1: Dictionary = SaveManager.gear_bonus_of({"slot": "blindage", "rarity": "legendaire", "level": 1})
	_ok(absf(float(l1["hp"]) - float(c1["hp"]) * 3.5) < 0.001, "multiplicateur de rarete",
		"commun=%.1f legendaire=%.1f" % [float(c1["hp"]), float(l1["hp"])])
	var c5: Dictionary = SaveManager.gear_bonus_of({"slot": "blindage", "rarity": "commun", "level": 5})
	_ok(absf(float(c5["hp"]) - float(c1["hp"]) * 1.6) < 0.001, "montee en niveau (+15%/niv)",
		"niv1=%.1f niv5=%.1f" % [float(c1["hp"]), float(c5["hp"])])

	# --- 5. upgrade spends cores and raises the bonus
	var target: int = int(SaveManager.gear_parts()[0]["uid"])
	var before: float = float(SaveManager.gear_bonus_of(SaveManager.gear_part(target)).values()[0])
	var cores_before: int = int(SaveManager.data["cores"])
	var up_ok: bool = SaveManager.gear_upgrade(target)
	var after: float = float(SaveManager.gear_bonus_of(SaveManager.gear_part(target)).values()[0])
	_ok(up_ok and after > before, "amelioration augmente le bonus", "%.3f -> %.3f" % [before, after])
	_ok(int(SaveManager.data["cores"]) == cores_before - SaveManager.GEAR_UPGRADE_COST, "noyaux debites")

	# --- 6. level cap
	for i in 10:
		SaveManager.data["cores"] = 999
		SaveManager.gear_upgrade(target)
	_ok(int(SaveManager.gear_part(target)["level"]) == SaveManager.GEAR_MAX_LEVEL,
		"niveau plafonne a %d" % SaveManager.GEAR_MAX_LEVEL, "niv=%d" % int(SaveManager.gear_part(target)["level"]))

	# --- 7. equipped parts cannot be recycled
	var eq_uid: int = int(SaveManager.gear_equipped().values()[0])
	_ok(not SaveManager.gear_salvage(eq_uid), "recyclage refuse sur piece equipee")
	_ok(not SaveManager.gear_part(eq_uid).is_empty(), "piece equipee toujours presente")

	# --- 8. recycling a spare yields cores and removes it
	var spare: int = -1
	for p: Dictionary in SaveManager.gear_parts():
		if not SaveManager.gear_equipped().values().has(int(p["uid"])):
			spare = int(p["uid"]); break
	if spare >= 0:
		var n_before: int = SaveManager.gear_parts().size()
		SaveManager.data["cores"] = 0
		var sal: bool = SaveManager.gear_salvage(spare)
		_ok(sal and SaveManager.gear_parts().size() == n_before - 1, "recyclage retire la piece")
		_ok(int(SaveManager.data["cores"]) > 0, "recyclage rend des noyaux", "+%d" % int(SaveManager.data["cores"]))
	else:
		print("  (pas de piece en double a recycler ce tirage)")

	# --- 9. cannot pull without crystals
	SaveManager.data["crystals"] = 0
	_ok(SaveManager.gear_pull().is_empty(), "invocation bloquee sans cristaux")

	# --- 10. equipping swaps within the slot
	SaveManager.data["crystals"] = 600
	var slot_target: String = ""
	var cand: Array = []
	for i in 12:
		var p3: Dictionary = SaveManager.gear_pull()
		if p3.is_empty():
			continue
		if String(p3["slot"]) != String(SaveManager.gear_equipped().keys()[0]):
			continue
		cand.append(int(p3["uid"]))
	slot_target = String(SaveManager.gear_equipped().keys()[0])
	if cand.size() > 0:
		SaveManager.gear_equip(int(cand[0]))
		_ok(int(SaveManager.gear_equipped()[slot_target]) == int(cand[0]), "changement de piece dans le slot")
	# --- 11. the POPULATED ui actually constructs (the empty-state screenshot can't prove this)
	SaveManager.data["parts"] = [
		{"uid": 101, "slot": "arme", "rarity": "legendaire", "level": 5},
		{"uid": 102, "slot": "arme", "rarity": "commun", "level": 1},
		{"uid": 103, "slot": "blindage", "rarity": "epique", "level": 3},
		{"uid": 104, "slot": "senseur", "rarity": "rare", "level": 2},
	]
	SaveManager.data["equipped"] = {"arme": 101, "blindage": 103}
	SaveManager.data["crystals"] = 500
	SaveManager.data["cores"] = 500
	var ms: MetaScreen = MetaScreen.new()
	add_child(ms)
	ms.game = null
	ms._home = true
	ms._build_gear()
	await get_tree().process_frame
	_ok(_count_buttons(ms) >= 5, "panneau EQUIPEMENT peuple construit",
		"%d boutons (4 GERER + invoquer + retour)" % _count_buttons(ms))
	for slot: String in SaveManager.GEAR_SLOTS:
		ms._build_gear_slot(slot)
		await get_tree().process_frame
		var n: int = _count_buttons(ms)
		_ok(n >= 1, "panneau slot '%s' construit" % slot, "%d boutons" % n)
	# label text on a real part must show rarity + level + a bonus
	var txt: String = ms._part_text(SaveManager.gear_part(101))
	_ok(txt.contains("Legendaire") and txt.contains("niv.5") and txt.contains("%"),
		"libelle de piece complet", txt)
	# an equipped part must be un-recyclable through the same guard the UI relies on
	_ok(not SaveManager.gear_salvage(101), "garde-fou recyclage tient sur piece equipee")
	ms.queue_free()

	# --- 12. rewarded-ad caps: a cancelled ad must never burn a daily view
	print("--- pubs recompensees ---")
	SaveManager.data["ads"] = {}
	_ok(Ads.available("revive"), "placement disponible a neuf")
	_ok(Ads.remaining("revive") == int(Ads.CAPS["revive"]), "compteur restant initial",
		"%d" % Ads.remaining("revive"))
	var got_reward: Array = []
	Ads.show_rewarded("revive", func(r: bool) -> void: got_reward.append(r))
	_ok(not Ads.available("revive"), "aucun second ad pendant qu'un ad est affiche")
	Ads._finish(false)                                    # user cancelled
	_ok(got_reward.size() == 1 and got_reward[0] == false, "annulation renvoie false")
	_ok(SaveManager.ads_used("revive") == 0, "annulation ne consomme PAS de quota")
	Ads.show_rewarded("revive", func(r: bool) -> void: got_reward.append(r))
	Ads._finish(true)                                     # watched to the end
	_ok(got_reward.size() == 2 and got_reward[1] == true, "visionnage complet renvoie true")
	_ok(SaveManager.ads_used("revive") == 1, "visionnage complet consomme 1 quota")
	# exhaust the cap
	for i in int(Ads.CAPS["revive"]):
		SaveManager.ads_consume("revive")
	_ok(not Ads.available("revive"), "placement bloque une fois le quota atteint")
	_ok(Ads.remaining("revive") == 0, "compteur restant a zero")
	# a blocked placement still calls back (with false) instead of hanging the caller
	var blocked: Array = []
	Ads.show_rewarded("revive", func(r: bool) -> void: blocked.append(r))
	_ok(blocked.size() == 1 and blocked[0] == false, "placement sature rappelle quand meme false")
	# free pull grants a part without spending crystals
	SaveManager.data["crystals"] = 0
	var n0: int = SaveManager.gear_parts().size()
	var fp: Dictionary = SaveManager.gear_pull(true)
	_ok(not fp.is_empty() and SaveManager.gear_parts().size() == n0 + 1,
		"invocation gratuite donne une piece sans cristaux")
	_ok(int(SaveManager.data["crystals"]) == 0, "invocation gratuite ne debite rien")
	# Crystal payout: purely proportional, and a too-short run pays NOTHING. The old flat "+4
	# whatever happens" made dying instantly and restarting beat playing well 4:1.
	SaveManager.data["crystals"] = 0
	var low: int = SaveManager.bank_crystals_for_run(2000, 600.0)
	SaveManager.data["crystals"] = 0
	var high: int = SaveManager.bank_crystals_for_run(22000, 600.0)
	_ok(high > low, "cristaux par partie croissent avec le score",
		"score 2000 -> %d, score 22000 -> %d" % [low, high])
	SaveManager.data["crystals"] = 0
	var suicide: int = SaveManager.bank_crystals_for_run(9000, 10.0)
	_ok(suicide == 0 and int(SaveManager.data["crystals"]) == 0,
		"partie trop courte ne rapporte RIEN (anti-farm par suicide)", "%d cristaux" % suicide)

	print("=== %s (%d echec(s)) ===" % ["OK" if _fail == 0 else "ECHEC", _fail])
	get_tree().quit()

func _count_buttons(n: Node) -> int:
	var c: int = 1 if n is Button else 0
	for ch in n.get_children():
		c += _count_buttons(ch)
	return c
