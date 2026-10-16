extends Node
## Central audio: pooled SFX (with anti-spam throttle) + music with crossfade.
## Placeholder procedural assets in assets/audio/ (tools/gen_sfx.py, gen_music.py) —
## swap for polished CC0/pro tracks later. Called directly (Audio.sfx / Audio.music)
## and via a few Events hooks. Runs during pause (menus).

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const _SFX_NAMES: Array[String] = ["shoot", "hit", "crit", "explosion", "xp", "scrap",
	"levelup", "hurt", "boss", "overdrive", "click", "victory",
	"w_autocannon", "w_missile", "w_railgun", "w_plasma", "w_sabre",
	# 15/10 : un timbre PROPRE a chaque niveau pour les tirs de tourelle (depart _a, impact _b),
	# generes par tools/gen_turret_sfx.py - voir TurretShots.gd
	"ts_weld_a", "ts_weld_b", "ts_solar_a", "ts_solar_b", "ts_pod_a", "ts_pod_b",
	"ts_slag_a", "ts_slag_b", "ts_flak_a", "ts_flak_b", "ts_frost_a", "ts_frost_b",
	"ts_plasma_a", "ts_plasma_b", "ts_acid_a", "ts_acid_b", "ts_missile_a", "ts_missile_b"]
# Rapid-fire weapons need their own throttle or the pool floods and every shot cancels the last.
const _THROTTLE: Dictionary = {"shoot": 0.11, "hit": 0.08, "xp": 0.05, "scrap": 0.06,
	"w_autocannon": 0.07, "w_missile": 0.14, "w_railgun": 0.12, "w_plasma": 0.12, "w_sabre": 0.13,
	"ts_flak_a": 0.1, "ts_flak_b": 0.08, "ts_missile_a": 0.09, "ts_acid_a": 0.12, "ts_acid_b": 0.1}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _idx: int = 0
var _last: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur: AudioStreamPlayer
var _music_track: String = ""

## Mute the Music / SFX buses from the settings menu.
func set_music_enabled(on: bool) -> void:
	var i: int = AudioServer.get_bus_index("Music")
	if i >= 0:
		AudioServer.set_bus_mute(i, not on)

func set_sfx_enabled(on: bool) -> void:
	var i: int = AudioServer.get_bus_index("SFX")
	if i >= 0:
		AudioServer.set_bus_mute(i, not on)

## Apply the saved audio settings (called once after SaveManager has loaded).
func apply_settings() -> void:
	set_music_enabled(bool(SaveManager.setting("music", true)))
	set_sfx_enabled(bool(SaveManager.setting("sfx", true)))

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

const SFX_ALIASES: Dictionary = {
	"powerup": "levelup",
	"dash": "w_autocannon",
	"teleport": "w_railgun",
}

func sfx(name: String, pitch_var: float = 0.0) -> void:
	var actual_name: String = String(SFX_ALIASES.get(name, name))
	if not _streams.has(actual_name) or _players.is_empty():
		return
	var thr: float = float(_THROTTLE.get(actual_name, 0.0))
	if thr > 0.0:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - float(_last.get(actual_name, -10.0)) < thr:
			return
		_last[actual_name] = now
	var pl: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	pl.stream = _streams[actual_name]
	pl.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	pl.play()

const MUSIC_FALLBACK: Dictionary = {
	"cryo": "ice",
	"reacteur": "tech",
	"ruche": "swamp",
	"citadelle": "spaceship",
}

func music(track: String) -> void:
	var actual_track: String = String(MUSIC_FALLBACK.get(track, track))
	if actual_track == _music_track:
		return
	var p: String = MUSIC_DIR + actual_track + ".ogg"
	if not ResourceLoader.exists(p):
		p = MUSIC_DIR + "tech.ogg"
		actual_track = "tech"
		if not ResourceLoader.exists(p):
			return
	_music_track = actual_track
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
