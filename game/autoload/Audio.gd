extends Node
## Central audio: pooled SFX (with anti-spam throttle) + music with crossfade.
## Placeholder procedural assets in assets/audio/ (tools/gen_sfx.py, gen_music.py) —
## swap for polished CC0/pro tracks later. Called directly (Audio.sfx / Audio.music)
## and via a few Events hooks. Runs during pause (menus).

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const _SFX_NAMES: Array[String] = ["shoot", "hit", "crit", "explosion", "xp", "scrap",
	"levelup", "hurt", "boss", "overdrive", "click", "victory"]
const _THROTTLE: Dictionary = {"shoot": 0.11, "hit": 0.08, "xp": 0.05, "scrap": 0.06}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _idx: int = 0
var _last: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur: AudioStreamPlayer
var _music_track: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n: String in _SFX_NAMES:
		var p: String = SFX_DIR + n + ".wav"
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in 16:
		var pl: AudioStreamPlayer = AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		_players.append(pl)
	_music_a = _mk_music()
	_music_b = _mk_music()
	_music_cur = _music_a
	Events.level_up.connect(func(_l: int) -> void: sfx("levelup"))
	Events.run_won.connect(func() -> void: sfx("victory"))
	Events.player_transformed.connect(func(on: bool) -> void:
		if on:
			sfx("overdrive"))

func _mk_music() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p

func sfx(name: String, pitch_var: float = 0.0) -> void:
	if not _streams.has(name) or _players.is_empty():
		return
	var thr: float = float(_THROTTLE.get(name, 0.0))
	if thr > 0.0:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - float(_last.get(name, -10.0)) < thr:
			return
		_last[name] = now
	var pl: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	pl.stream = _streams[name]
	pl.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	pl.play()

func music(track: String) -> void:
	if track == _music_track:
		return
	var p: String = MUSIC_DIR + track + ".ogg"
	if not ResourceLoader.exists(p):
		return
	_music_track = track
	var s: AudioStream = load(p)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var nxt: AudioStreamPlayer = _music_b if _music_cur == _music_a else _music_a
	nxt.stream = s
	nxt.volume_db = -30.0
	nxt.play()
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0, 1.0)
	tw.tween_property(_music_cur, "volume_db", -30.0, 1.0)
	tw.chain().tween_callback(_music_cur.stop)
	_music_cur = nxt

func set_bus_db(bus: String, db: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, db)
