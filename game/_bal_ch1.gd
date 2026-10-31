extends Node
## BANC CH1 (30/10) : mesure fine d'une partie bot (PV, degats, soins, densite, niveaux, arsenal, TTK des rangs).
##   godot --headless --path game res://_bal_ch1.tscn -- --ch=1 --diff=1 --secs=960 --scale=6 [--seed=N]
const GameScene = preload("res://scenes/Main.tscn")
const GameScript = preload("res://scenes/Game.gd")
var g: Node
var ch: int = 1
var diff: int = 1
var secs: float = 960.0
var scale: float = 6.0
var _won: bool = false
var _prev_hp: float = -1.0
var _prev_max: float = -1.0
var heal_tot: float = 0.0
var min_hp: float = 1e9
var min_hp_frac: float = 1.0
var min_hp_t: float = 0.0
var _acc_t: float = 0.0
var _min_next: float = 60.0
var en_sum: float = 0.0
var en_n: int = 0
var en_max: int = 0
var od_t: float = 0.0
var sh_t: float = 0.0
var _rank: Dictionary = {}
var lvl_times: Array = []
var _last_lvl: int = 1
var _min_dmg0: float = 0.0
var _min_heal0: float = 0.0
var _min_kills0: int = 0
var first_hit_t: float = -1.0
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ch="): ch = int(a.substr(5))
		elif a.begins_with("--diff="): diff = int(a.substr(7))
		elif a.begins_with("--secs="): secs = float(a.substr(7))
		elif a.begins_with("--scale="): scale = float(a.substr(8))
		elif a.begins_with("--seed="): seed(int(a.substr(7)))
	Events.run_won.connect(func() -> void: _won = true)
	GameState.difficulty = diff   # avant add_child : Game._ready lit la difficulte
	g = GameScene.instantiate()
	add_child(g)
	GameState.difficulty = diff
	var c: Dictionary = GameScript.CHAPTERS[ch - 1]
	g._headless_frames = 2000000000
	g._chapter = ch
	g._apply_chapter_biome(String(c["biome"]))
	print("CH1 chapitre %d (%s) diff=%s %.0f s x%.0f" % [ch, c["biome"], GameState.diff()["name"], secs, scale])
	Engine.physics_ticks_per_second = int(60.0 * scale)
	Engine.time_scale = scale
func _dmg() -> float:
	var s: float = 0.0
	for k in g.player.damage_log:
		s += float(g.player.damage_log[k])
	return s
func _physics_process(delta: float) -> void:
	if g == null or g.player == null:
		return
	var p = g.player
	var rt: float = GameState.run_time
	var hp: float = float(p.hp)
	var mx: float = float(p.max_hp)
	if _prev_hp >= 0.0 and hp > _prev_hp:
		var gain: float = hp - _prev_hp
		if mx > _prev_max:
			gain = maxf(0.0, gain - (mx - _prev_max))   # hausse de PV max (niveau) : pas un soin
		heal_tot += gain
	_prev_hp = hp
	_prev_max = mx
	if rt > 3.0 and GameState.alive:
		if hp < min_hp:
			min_hp = hp
			min_hp_t = rt
		if mx > 0.0 and hp / mx < min_hp_frac:
			min_hp_frac = hp / mx
	if first_hit_t < 0.0 and _dmg() > 0.0:
		first_hit_t = rt
	if p.transformed: od_t += delta
	if float(p.shield_t) > 0.0: sh_t += delta
	if GameState.level != _last_lvl:
		_last_lvl = GameState.level
		lvl_times.append(rt)
	_acc_t += delta
	if _acc_t >= 1.0:
		_acc_t = 0.0
		var en: int = get_tree().get_nodes_in_group("enemies").size()
		en_sum += en; en_n += 1; en_max = maxi(en_max, en)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).alive and int((e as Enemy).rank) >= 1:
			var id: int = e.get_instance_id()
			if not _rank.has(id):
				_rank[id] = {"k": (e as Enemy).kind, "r": int((e as Enemy).rank), "t0": rt, "hp": (e as Enemy).hp_max, "ref": e}
	for id in _rank.keys():
		var info: Dictionary = _rank[id]
		if info.has("done"):
			continue
		var ref = info["ref"]
		if ref == null or not is_instance_valid(ref) or not (ref as Enemy).alive:
			info["done"] = rt - float(info["t0"])
			if int(info["r"]) >= 2:
				print("CH1 RANG %s r%d pv=%.0f tue en %.1f s (t=%.0f)" % [info["k"], info["r"], info["hp"], info["done"], rt])
	if rt >= _min_next or not GameState.alive or _won or rt >= secs:
		var nw: int = int(p._weapons._weapons.size()) if p._weapons != null else -1
		var dm: float = _dmg()
		print("CH1 MIN t=%3.0f niv=%2d pv=%3.0f/%3.0f deg+%4.0f soin+%4.0f kills+%4d ennemis_moy=%.0f max=%d armes=%d od=%.0f%% bouclier=%.0f%%" % [
			rt, GameState.level, hp, mx, dm - _min_dmg0, heal_tot - _min_heal0, GameState.kills - _min_kills0, en_sum / maxf(1.0, float(en_n)), en_max, nw, 100.0 * od_t / maxf(rt, 1.0), 100.0 * sh_t / maxf(rt, 1.0)])
		_min_dmg0 = dm; _min_heal0 = heal_tot; _min_kills0 = GameState.kills
		en_sum = 0.0; en_n = 0; en_max = 0
		_min_next += 60.0
		if not GameState.alive or _won or rt >= secs:
			var ttk_r1: Array = []
			for id in _rank:
				if int(_rank[id]["r"]) == 1 and _rank[id].has("done"):
					ttk_r1.append(float(_rank[id]["done"]))
			var avg1: float = 0.0
			for x in ttk_r1: avg1 += x
			avg1 /= maxf(1.0, float(ttk_r1.size()))
			var lv5: float = lvl_times[3] if lvl_times.size() > 3 else -1.0
			var lv10: float = lvl_times[8] if lvl_times.size() > 8 else -1.0
			print("CH1 FIN %s t=%.0f niv=%d kills=%d deg_total=%.0f soin_total=%.0f pv_min=%.0f (%.0f%% a t=%.0f) 1er_coup=%.0fs niv5=%.0fs niv10=%.0fs ttk_rang1_moy=%.1fs (n=%d) od=%.0f%% degats_par_source=%s soins_par_source=%s regen=%.1f" % [
				"VICTOIRE" if _won else ("MORT:" + GameState.death_cause if not GameState.alive else "TEMPS"), rt, GameState.level, GameState.kills, _dmg(), heal_tot, min_hp, 100.0 * min_hp_frac, min_hp_t, first_hit_t, lv5, lv10, avg1, ttk_r1.size(), 100.0 * od_t / maxf(rt, 1.0), str(p.damage_log), str(p.heal_log), float(p.hp_regen)])
			Engine.time_scale = 1.0
			get_tree().quit(0)
