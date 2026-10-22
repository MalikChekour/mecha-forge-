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
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ch="): ch = int(a.substr(5))
		elif a.begins_with("--secs="): secs = float(a.substr(7))
		elif a.begins_with("--scale="): scale = float(a.substr(8))
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
	if rt >= _next or not GameState.alive or rt >= secs:
		var en: int = get_tree().get_nodes_in_group("enemies").size()
		print("BAL t=%3.0f niv=%2d pv=%3.0f/%3.0f ennemis=%3d kills=%4d vivant=%s (mur %.0f s) vit_joueur=%.0f vit_ennemis_moy=%.0f %s" % [rt, GameState.level, float(g.player.hp), float(g.player.max_hp), en, GameState.kills, str(GameState.alive), float(Time.get_ticks_msec() - _t_wall) / 1000.0, float(g.player.base_speed), _mean_speed(), _tiers()])
		_next = rt + (20.0 if rt >= 280.0 else 60.0)
		if not GameState.alive or rt >= secs:
			Engine.time_scale = 1.0
			get_tree().quit(0)

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
