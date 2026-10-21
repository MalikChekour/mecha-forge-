"""Enemy.gd : visee reelle (bras arme non fige), garde active (bouclier energetique), guidage de formation, grades."""
import os
p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "actors", "Enemy.gd")
raw = open(p, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
s = raw.replace("\r", "")
if "# >>> IA21 vars" in s:
    print("deja patche")
    raise SystemExit

def rep(old, new, count=1):
    global s
    assert old in s, old[:60]
    s = s.replace(old, new, count)

# 1) variables
rep("var barrage: bool = false", '''# >>> IA21 vars (21/10 : visee, garde active, formation, grade)
var aim_rate: float = 4.0          # rad/s : vitesse a laquelle le bras/canon se tourne vers sa cible
var aim_lead: float = 0.0          # 0..1 : part de l'anticipation du mouvement du joueur
var _aim: float = 0.0
var _aim_goal: float = 0.0
var _aim_init: bool = false
var garde: bool = false            # peut activer un bouclier energetique temporaire
var garde_cd: float = 9.0
var _garde_t: float = 0.0
var _garde_cd_t: float = 3.0
var _garde_pulse: float = 0.0
var form_pos: Vector2 = Vector2.ZERO
var form_w: float = 0.0            # 0 = comportement libre ; 1 = suit son emplacement de formation
var grade: String = ""             # "" soldat | "lieutenant" | "chef"
const _DIR_DEG: Dictionary = {"right": 0.0, "front_right": 45.0, "front": 90.0, "front_left": 135.0, "left": 180.0, "back_left": -135.0, "back": -90.0, "back_right": -45.0}
# <<< IA21 vars
var barrage: bool = false''')

# 2) setup
rep('	barrage = bool(def.get("barrage", false))\n', '''	barrage = bool(def.get("barrage", false))
	aim_rate = float(def.get("aim_rate", 4.0))
	aim_lead = float(def.get("aim_lead", 0.0))
	garde = bool(def.get("garde", false))
	garde_cd = float(def.get("garde_cd", 9.0))
	_garde_cd_t = randf_range(2.0, 6.0)
''')

# 3) timers de garde + visee (apres la boucle de rang/boss en tete de _physics_process)
rep('''	if rank >= 3:
		_check_boss_phase()
''', '''	if rank >= 3:
		_check_boss_phase()
	if garde:
		_garde_tick(delta, player_valid)
	if player_valid and behavior == "ranged":
		_aim_tick(delta)
''')

# 4) guidage de formation (avant la separation)
rep("			if separation != Vector2.ZERO and _bull_state != 2:", '''			if form_w > 0.0 and _bull_state != 2 and _phase != _PH_DASH_ACTIVE and not _kamikaze_arming:
				var to_slot: Vector2 = form_pos - global_position
				var sl: float = to_slot.length()
				var want: Vector2 = Vector2.ZERO if sl < 14.0 else to_slot / sl * minf(speed * 1.2, sl * 3.0)
				desired_vel = desired_vel.lerp(want, clampf(form_w, 0.0, 1.0))
			if separation != Vector2.ZERO and _bull_state != 2:''')

# 5) tirs vises
rep("					_atk_cd = attack_cd * ARME_CADENCE[_palier]\n					_tire_arme(dir)",
    "					_atk_cd = attack_cd * ARME_CADENCE[_palier]\n					_tire_arme(_aim_dir(dir))")
rep("				elif _atk_cd <= 0.0 and dist < prefer_dist + 100.0:\n",
    "				elif _atk_cd <= 0.0 and dist < prefer_dist + 100.0 and _aim_ready():\n")
rep("							_fire_heavy(dir)", "							_fire_heavy(_aim_dir(dir))")

# 6) ralentissement en garde
rep("	velocity = velocity.move_toward(desired_vel, _ACCEL * delta)",
    "	if _garde_t > 0.0:\n		desired_vel *= 0.5      # derriere son bouclier il ne manoeuvre qu'a moitie vitesse : contre-jeu = patienter\n	velocity = velocity.move_toward(desired_vel, _ACCEL * delta)")

# 7) orientation vers la visee + inclinaison fine du sprite
rep('''		if behavior == "ranged" and player != null and is_instance_valid(player):
			face_vec = player.global_position - global_position
		_update_facing(face_vec)''', '''		if behavior == "ranged" and player != null and is_instance_valid(player):
			face_vec = Vector2.from_angle(_aim) if _aim_init else player.global_position - global_position
		_update_facing(face_vec)
		_aim_tilt(delta)''')

# 8) degats : garde active
rep('''	# the energy shield soaks damage first; only the overflow reaches HP
	if shield > 0.0:''', '''	if garde:
		if _garde_t <= 0.0 and _garde_cd_t <= 0.0:
			_garde_on()
		if _garde_t > 0.0:
			amount *= 0.12
			if game != null and game.has_method("shield_ripple") and _garde_pulse <= 0.0:
				_garde_pulse = 0.25
				game.shield_ripple(global_position, _body_radius * 1.6, Palette.CYAN)
			if amount <= 0.05:
				return
	# the energy shield soaks damage first; only the overflow reaches HP
	if shield > 0.0:''')

# 9) fonctions
rep("func _update_facing(v: Vector2) -> void:", '''## ======================= VISEE (21/10, patron : « qu'ils n'aient pas le bras arme fige ») =======================
## Le canon se TOURNE vers sa cible a `aim_rate` rad/s et vise le point d'interception du joueur (part `aim_lead` de son
## mouvement). Il ne tire que lorsque l'ecart est < 0,28 rad : un joueur qui change de direction brusquement se fait
## rattraper moins vite par les niveaux bas (lent, peu d'anticipation) que par les hauts. Le sprite 8 directions est
## incline vers l'angle exact (+/- 0,4 rad) : le bras suit entre deux directions cuites.
func _aim_tick(delta: float) -> void:
	var to_p: Vector2 = player.global_position - global_position
	var goal: Vector2 = player.global_position
	if aim_lead > 0.0 and "velocity" in player:
		var tof: float = to_p.length() / maxf(ARME_VITESSE[_palier], 100.0)
		goal += (player.velocity as Vector2) * tof * aim_lead
	_aim_goal = (goal - global_position).angle()
	if not _aim_init:
		_aim = _aim_goal
		_aim_init = true
		return
	var step: float = aim_rate * delta
	_aim += clampf(angle_difference(_aim, _aim_goal), -step, step)

func _aim_ready() -> bool:
	return not _aim_init or absf(angle_difference(_aim, _aim_goal)) < 0.28

func _aim_dir(fallback: Vector2) -> Vector2:
	return Vector2.from_angle(_aim) if _aim_init else fallback

func _aim_tilt(delta: float) -> void:
	var want: float = 0.0
	if _aim_init and _DIR_DEG.has(_dir) and _anims.get(_cur_anim) is Dictionary and (_anims.get(_cur_anim) as Dictionary).has("front_right"):
		want = clampf(angle_difference(deg_to_rad(float(_DIR_DEG[_dir])), _aim), -0.4, 0.4)
	_spr.rotation = lerp_angle(_spr.rotation, want, clampf(delta * 14.0, 0.0, 1.0))

## ======================= GARDE ACTIVE : bouclier energetique temporaire =======================
## 2,2 s a ~12 % des degats, puis recharge `garde_cd`. Se declenche quand le joueur est proche (~280 px) ou au premier coup
## encaisse. Ralentit son porteur de moitie (cf. _physics_process) : on peut patienter, contourner, ou viser un autre.
func _garde_on() -> void:
	_garde_t = 2.2
	_garde_cd_t = garde_cd + 2.2
	_garde_pulse = 0.0
	_spr.self_modulate = Color(0.55, 1.0, 1.5)
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("shield", global_position, 0.0, _body_radius / 40.0, Palette.CYAN)

func _garde_tick(delta: float, player_valid: bool) -> void:
	_garde_cd_t -= delta
	_garde_pulse -= delta
	if _garde_t > 0.0:
		_garde_t -= delta
		if _garde_t <= 0.0:
			_garde_t = 0.0
			_spr.self_modulate = _garde_base_tint()
	elif _garde_cd_t <= 0.0 and player_valid and global_position.distance_squared_to(player.global_position) < 78400.0:
		_garde_on()

func _garde_base_tint() -> Color:
	if grade == "chef":
		return Color(1.0, 0.72, 0.28)
	if grade == "lieutenant":
		return Color(0.55, 0.85, 1.25)
	if game != null and "spawner" in game and game.spawner != null:
		return game.spawner.enemy_tint
	return Color(1, 1, 1)

func _update_facing(v: Vector2) -> void:''')

if crlf:
    s = s.replace("\n", "\r\n")
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok")
