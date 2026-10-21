"""Enemy.gd : styles de tir distincts, esquive, ordre du chef (aura). Idempotent."""
import os
p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "actors", "Enemy.gd")
raw = open(p, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
s = raw.replace("\r", "")
if "# >>> IA22 vars" in s:
    print("deja patche")
    raise SystemExit

def rep(old, new, count=1):
    global s
    assert old in s, old[:70]
    s = s.replace(old, new, count)

rep("# <<< IA21 vars", '''# >>> IA22 vars (21/10 : signatures de tir par niveau, esquive, ordre du chef)
var tir_style: String = ""         # "" tir de palier | rafale | eventail | sniper | guide | anneau | orbe
var esquive: bool = false
var _esq_cd: float = 2.0
var _esq_t: float = 0.0
var _esq_dir: Vector2 = Vector2.ZERO
var _esq_scan: float = 0.0
var _burst_left: int = 0
var _burst_t: float = 0.0
var _burst_dir: Vector2 = Vector2.RIGHT
var _style_charge: float = 0.0
var chef_ref: Variant = null       # chef de meute de l'escouade : tant qu'il vit, ses troupes encaissent 25 % de moins
# <<< IA22 vars
# <<< IA21 vars''')

rep('	garde_cd = float(def.get("garde_cd", 9.0))\n', '''	garde_cd = float(def.get("garde_cd", 9.0))
	tir_style = String(def.get("tir_style", ""))
	esquive = bool(def.get("esquive", false))
	_esq_cd = randf_range(1.0, 3.0)
''')

rep('''	if garde:
		_garde_tick(delta, player_valid)''', '''	if garde:
		_garde_tick(delta, player_valid)
	if tir_style != "" or esquive:
		_style_tick(delta, player_valid)''')

# tir : dispatch
rep("_tire_arme(_aim_dir(dir))", "_tire_dispatch(_aim_dir(dir))")

# esquive : impulsion laterale (apres la garde, avant le deplacement)
rep("	if _garde_t > 0.0:\n		desired_vel *= 0.5", '''	if _esq_t > 0.0:
		_esq_t -= delta
		velocity = _esq_dir * speed * 2.8
		desired_vel = velocity
	if _garde_t > 0.0:
		desired_vel *= 0.5''')

# ordre du chef
rep('''	if garde:
		if _garde_t <= 0.0 and _garde_cd_t <= 0.0:''', '''	if grade != "chef" and chef_ref != null and is_instance_valid(chef_ref) and chef_ref.alive \\
			and global_position.distance_squared_to((chef_ref as Node2D).global_position) < 144400.0:
		amount *= 0.75            # « ordre de defense » : tant que le chef est a portee de voix (~380 px)
	if garde:
		if _garde_t <= 0.0 and _garde_cd_t <= 0.0:''')

rep("func _garde_on() -> void:", '''## ======================= SIGNATURES DE TIR (21/10, patron : « ils ont tous la meme attaque ») =======================
## Chaque niveau a SA facon de tirer, lisible a la couleur, a la vitesse et a la forme de la salve :
##  rafale (3 coups serres, orange) | eventail (5 plombs, jaune-vert) | sniper (charge 0,6 s puis coup rapide, blanc) |
##  guide (missile qui vire, violet) | anneau (10 tirs radiaux apres charge, vert) | orbe (grosse sphere lente, rouge).
## sniper / anneau / orbe se TELEGRAPHIENT (silhouette qui rougit) : on peut les lire et les esquiver.
const _STYLES: Dictionary = {
	"rafale":   {"col": Color(1.0, 0.55, 0.15), "charge": 0.0},
	"eventail": {"col": Color(0.85, 1.0, 0.3), "charge": 0.0},
	"sniper":   {"col": Color(0.75, 1.0, 1.0), "charge": 0.6},
	"guide":    {"col": Color(0.8, 0.4, 1.0), "charge": 0.0},
	"anneau":   {"col": Color(0.4, 1.0, 0.5), "charge": 0.5},
	"orbe":     {"col": Color(1.0, 0.3, 0.25), "charge": 0.45},
}

func _tire_dispatch(dir: Vector2) -> void:
	if tir_style == "" or not _STYLES.has(tir_style):
		_tire_arme(dir)
		return
	var ch: float = float(_STYLES[tir_style]["charge"])
	if ch > 0.0:
		_style_charge = ch
		_burst_dir = dir
		play("attack", true)
		return
	_style_fire(dir)

func _style_fire(dir: Vector2) -> void:
	if game == null or not game.has_method("spawn_enemy_bolt"):
		return
	var col: Color = _STYLES[tir_style]["col"]
	var muzzle: Vector2 = global_position + dir * 22.0
	var d: float = attack_dmg
	match tir_style:
		"rafale":
			_burst_left = 3
			_burst_t = 0.0
			_burst_dir = dir
		"eventail":
			for i in 5:
				game.spawn_enemy_bolt(muzzle, dir.rotated(-0.5 + 0.25 * float(i)), d * 0.5, col, 0.9, 270.0, false, 0.0)
		"sniper":
			game.spawn_enemy_bolt(muzzle, dir, d * 2.4, col, 0.7, 780.0, false, 0.0)
		"guide":
			game.spawn_enemy_bolt(muzzle, dir, d * 1.3, col, 1.2, 230.0, true, 2.2)
		"anneau":
			for i in 10:
				game.spawn_enemy_bolt(global_position, Vector2.from_angle(TAU * float(i) / 10.0 + _aim), d * 0.55, col, 1.0, 210.0, false, 0.0)
			if game.has_method("spawn_vfx"):
				game.spawn_vfx("aaa_shockwave", global_position, 0.0, 0.5, col)
		"orbe":
			game.spawn_enemy_bolt(muzzle, dir, d * 2.0, col, 2.1, 175.0, true, 0.0)
	if tir_style != "anneau" and game.has_method("spawn_vfx"):
		game.spawn_vfx("fire_blast", muzzle, dir.angle(), 0.45, col)
	play("attack", true)

func _style_tick(delta: float, player_valid: bool) -> void:
	# salve de rafale : un coup toutes les 0,11 s dans la direction figee au depart (lisible : on peut la contourner)
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = 0.11
			_burst_left -= 1
			if game != null and game.has_method("spawn_enemy_bolt"):
				game.spawn_enemy_bolt(global_position + _burst_dir * 22.0, _burst_dir, attack_dmg * 0.7, _STYLES["rafale"]["col"], 0.85, 430.0, false, 0.0)
	# charge de sniper / anneau / orbe : la silhouette rougit, la visee continue de suivre pendant la charge
	if _style_charge > 0.0:
		_style_charge -= delta
		if _mat != null and _mat.shader != null:
			_mat.set_shader_parameter("warn", 0.45 + 0.55 * absf(sin(float(Time.get_ticks_msec()) / 45.0)))
		if _style_charge <= 0.0:
			_style_charge = 0.0
			if _mat != null and _mat.shader != null:
				_mat.set_shader_parameter("warn", 0.0)
			_style_fire(_aim_dir(_burst_dir))
	# esquive : si un projectile du joueur fonce sur lui, il se jette de cote (recharge 3 s)
	if esquive:
		_esq_cd -= delta
		_esq_scan -= delta
		if _esq_cd <= 0.0 and _esq_scan <= 0.0 and _esq_t <= 0.0 and player_valid and game != null and "projectile_layer" in game and game.projectile_layer != null:
			_esq_scan = 0.1
			for pr in game.projectile_layer.get_children():
				if not (pr is Projectile) or not (pr as Projectile).visible:
					continue
				var rel: Vector2 = global_position - (pr as Node2D).global_position
				var pv: Vector2 = (pr as Projectile).velocity
				if rel.length_squared() < 22500.0 and pv.length_squared() > 1.0 and pv.dot(rel) > 0.0 and absf(pv.normalized().cross(rel.normalized())) < 0.5:
					var perp: Vector2 = Vector2(-pv.y, pv.x).normalized()
					_esq_dir = perp if perp.dot(rel) >= 0.0 else -perp
					_esq_t = 0.28
					_esq_cd = 3.0
					if game.has_method("spawn_vfx"):
						game.spawn_vfx("aaa_shockwave", global_position, 0.0, 0.25, Color(0.6, 0.9, 1.0))
					break

func _garde_on() -> void:''')

if crlf:
    s = s.replace("\n", "\r\n")
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok")
