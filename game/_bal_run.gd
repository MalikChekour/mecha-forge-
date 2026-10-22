extends Node
## BANC D'EQUILIBRE (22/10) : le vrai jeu en headless, bot joueur, un chapitre, N secondes de partie. Usage :
##   godot --headless --path game res://_bal_run.tscn -- --ch=8 --secs=360 --scale=6 [--mech=vortex]
## Sortie : une ligne par ~30 s de partie (niveau, PV, ennemis vivants, kills) puis la cause de fin.
const GameScene = preload("res://scenes/Main.tscn")
const GameScript = preload("res://scenes/Game.gd")
var g: Node
var ch: int = 1
var secs: float = 300.0
var scale: float = 6.0
var _next: float = 20.0
var _t_wall: int = 0
var _tier_spawns: Dictionary = {}
var _won: bool = false
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ch="): ch = int(a.substr(5))
		elif a.begins_with("--secs="): secs = float(a.substr(7))
		elif a.begins_with("--scale="): scale = float(a.substr(8))
	Events.run_won.connect(func() -> void:
		_won = true
		print("BAL [VICTOIRE t=%.0f s niv=%d kills=%d]" % [GameState.run_time, GameState.level, GameState.kills])
	)
	g = GameScene.instantiate()
	add_child(g)
	var c: Dictionary = GameScript.CHAPTERS[ch - 1]
	g._headless_frames = 2000000000   # le banc ne s'arrete pas au smoke du CI
	g._chapter = ch
	g._apply_chapter_biome(String(c["biome"]))
	print("BAL chapitre %d (%s) %.0f s, x%.0f" % [ch, c["biome"], secs, scale])
	Engine.time_scale = scale
	_t_wall = Time.get_ticks_msec()
func _process(_d: float) -> void:
	var rt: float = GameState.run_time
	# Suivi des apparitions de rangs
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).kind.contains("_") and (e as Enemy).alive:
			var eid: int = e.get_instance_id()
			if not _tier_spawns.has(eid):
				var tk: String = (e as Enemy).kind.get_slice("_", 1)
				_tier_spawns[eid] = {"tier": tk, "t0": rt, "ref": e}
				print("BAL [SPAWN %s t=%.0f s pv=%.0f]" % [tk, rt, (e as Enemy).hp_max])
	# Suivi des eliminations de rangs
	var dead_eids: Array = []
	for eid in _tier_spawns:
		var info: Dictionary = _tier_spawns[eid]
		var ref = info.get("ref")
		if ref == null or not is_instance_valid(ref) or not (ref as Enemy).alive:
			var dur: float = rt - float(info["t0"])
			print("BAL [KILL %s en %.1f s (t=%.0f s)]" % [info["tier"], dur, rt])
			dead_eids.append(eid)
	for eid in dead_eids:
		_tier_spawns.erase(eid)

	if rt >= _next or not GameState.alive or _won or rt >= secs:
		var en: int = get_tree().get_nodes_in_group("enemies").size()
		var cause: String = ""
		if _won:
			cause = " [VICTOIRE]"
		elif not GameState.alive:
			cause = " [mort:%s]" % GameState.death_cause
		var dtop: String = _top_damage()
		print("BAL t=%3.0f niv=%2d pv=%3.0f/%3.0f ennemis=%3d kills=%4d vivant=%s (mur %.0f s) vit_joueur=%.0f vit_ennemis_moy=%.0f %s%s %s" % [rt, GameState.level, float(g.player.hp), float(g.player.max_hp), en, GameState.kills, str(GameState.alive), float(Time.get_ticks_msec() - _t_wall) / 1000.0, float(g.player.base_speed), _mean_speed(), _tiers(), cause, dtop])
		_next = rt + (20.0 if rt >= 280.0 else 60.0)
		if not GameState.alive or _won or rt >= secs:
			Engine.time_scale = 1.0
			get_tree().quit(0)

func _top_damage() -> String:
	if g == null or g.player == null or not ("damage_log" in g.player):
		return ""
	var dlog: Dictionary = g.player.damage_log
	if dlog.is_empty():
		return ""
	var items: Array = []
	for k in dlog:
		items.append([k, float(dlog[k])])
	items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var parts: Array = []
	for i in mini(4, items.size()):
		parts.append("%s:%.0f" % [items[i][0], items[i][1]])
	return "[degats: " + ", ".join(parts) + "]"

func _mean_speed() -> float:
	var n: int = 0
	var sum: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and int((e as Enemy).rank) == 0 and not (e as Enemy).kind.contains("_"):
			sum += (e as Enemy).speed
			n += 1
	return sum / float(maxi(n, 1))

func _tiers() -> String:
	var out: String = ""
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).kind.contains("_") and (e as Enemy).alive:
			out += "[%s %.0f/%.0f]" % [(e as Enemy).kind.get_slice("_", 1), (e as Enemy).hp, (e as Enemy).hp_max]
	return out
