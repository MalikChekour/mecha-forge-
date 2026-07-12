class_name WeaponSystem
extends Node2D

const WEAPON_ORDER: Array[String] = ["autocannon", "missilepod", "railgun", "plasma",
	"vulcan", "hydra", "annihilator", "singularity"]
const MAX_LEVEL: int = 5   # a weapon at MAX + its required passive can EVOLVE
const EVOLVED: Array[String] = ["vulcan", "hydra", "annihilator", "singularity"]
# The weapon is HELD at the mech's grip anchor (see DirectionalMecha.grip_anchor()).
# Sprites face +X (barrel right) and are scaled by LENGTH; their pivot is the grip so
# they rotate around the hand toward aim, staying glued to the body.
const WEAPON_LEN_PRIMARY: float = 90.0
const WEAPON_LEN_SECONDARY: float = 64.0
const GRIP_FX: float = 0.30     # grip position as a fraction of the (cropped) weapon width
const GRIP_FY: float = 0.50     # ... and height
const BARREL_TIP_FX: float = 0.95
const RECOIL_TIME: float = 0.08
const RECOIL_DIST: float = 8.0

const COOLDOWNS: Dictionary = {
	"autocannon": 0.34, "missilepod": 0.95, "railgun": 1.1, "plasma": 0.8,
	"vulcan": 0.12, "hydra": 0.66, "annihilator": 0.85, "singularity": 0.66,
}

const BASE_MULT: Dictionary = {
	"autocannon": 1.0, "missilepod": 1.6, "railgun": 2.2, "plasma": 1.4,
	"vulcan": 1.5, "hydra": 1.9, "annihilator": 3.2, "singularity": 2.0,
}

const COLORS: Dictionary = {
	"autocannon": Color(0.8, 0.95, 1.0), "missilepod": Color(1.0, 0.6, 0.3),
	"railgun": Color(0.7, 0.85, 1.0), "plasma": Color(0.7, 0.4, 1.0),
	"vulcan": Color(1.0, 0.85, 0.3), "hydra": Color(1.0, 0.5, 0.2),
	"annihilator": Color(0.55, 0.92, 1.0), "singularity": Color(0.85, 0.4, 1.0),
}

const SPEEDS: Dictionary = {
	"autocannon": 820.0, "missilepod": 430.0, "railgun": 1500.0, "plasma": 540.0,
	"vulcan": 950.0, "hydra": 500.0, "annihilator": 1800.0, "singularity": 560.0,
}

const PIERCE: Dictionary = {
	"autocannon": 0, "missilepod": 0, "railgun": 5, "plasma": 0,
	"vulcan": 2, "hydra": 0, "annihilator": 30, "singularity": 0,
}

const HOMING: Dictionary = {
	"autocannon": false, "missilepod": true, "railgun": false, "plasma": false,
	"vulcan": false, "hydra": true, "annihilator": false, "singularity": false,
}

const AOE: Dictionary = {
	"missilepod": 60.0, "plasma": 74.0,
	"hydra": 80.0, "singularity": 130.0,
}

const MULTISHOT: Dictionary = {   # projectiles fired per shot, spread around aim
	"vulcan": 3, "hydra": 3,
}

var muzzle_global: Vector2 = Vector2.ZERO

var _player: Node = null
var _active: bool = true
var _weapons: Dictionary = {}

func setup(p: Node) -> void:
	_player = p
	add_weapon("autocannon")

func add_weapon(id: String) -> void:
	if not WEAPON_ORDER.has(id):
		return
	if _weapons.has(id):
		var w: Dictionary = _weapons[id]
		w["level"] = mini(MAX_LEVEL, int(w["level"]) + 1)
		w["cooldown"] = maxf(0.08, float(w["cooldown"]) * 0.85)
	else:
		if _weapons.size() >= 4:
			return
		_install(id, _weapons.size(), _weapons.size() == 0)

func _install(id: String, slot: int, is_primary: bool) -> void:
	var sprite: Sprite2D = _create_sprite(id, is_primary)
	var shadow: Sprite2D = _create_shadow_sprite(sprite)   # drawn BEFORE the weapon (under it)
	if shadow != null:
		add_child(shadow)
	add_child(sprite)
	var muzzle: Sprite2D = _create_muzzle_sprite(id)
	add_child(muzzle)
	_weapons[id] = {
		"id": id,
		"level": 1,
		"cooldown": float(COOLDOWNS.get(id, 0.5)),
		"timer": 0.0,
		"sprite": sprite,
		"shadow": shadow,
		"muzzle": muzzle,
		"slot": slot,
		"len": WEAPON_LEN_PRIMARY if is_primary else WEAPON_LEN_SECONDARY,
		"is_primary": is_primary,
		"recoil": 0.0,
	}

func is_max(id: String) -> bool:
	return _weapons.has(id) and int(_weapons[id]["level"]) >= MAX_LEVEL

func owned_weapons() -> Array:
	return _weapons.keys()

# Evolve: swap a base weapon for its upgraded form, keeping the same slot.
func replace_weapon(old_id: String, new_id: String) -> void:
	if not _weapons.has(old_id) or _weapons.has(new_id):
		return
	var w: Dictionary = _weapons[old_id]
	for k in ["sprite", "shadow", "muzzle"]:
		var n: Variant = w.get(k)
		if n != null:
			(n as Node).queue_free()
	var slot: int = int(w.get("slot", 0))
	var is_primary: bool = bool(w.get("is_primary", slot == 0))
	_weapons.erase(old_id)
	_install(new_id, slot, is_primary)
	_weapons[new_id]["level"] = MAX_LEVEL   # an evolved weapon starts strong

func set_active(a: bool) -> void:
	_active = a
	visible = a   # hide the held weapon entirely while inactive (e.g. Overdrive beam mode)

static func _asset_path(id: String) -> String:
	# evolved weapons reuse their base sprite (tinted gold in _create_sprite)
	match id:
		"plasma", "singularity": return "res://assets/weapons/plasmacaster.png"
		"vulcan": return "res://assets/weapons/autocannon.png"
		"hydra": return "res://assets/weapons/missilepod.png"
		"annihilator": return "res://assets/weapons/railgun.png"
		_: return "res://assets/weapons/%s.png" % id

func _create_sprite(id: String, is_primary: bool) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	var path: String = _asset_path(id)
	var tex: Texture2D = Tex.get_tex(path)
	s.texture = tex
	var target_len: float = WEAPON_LEN_PRIMARY if is_primary else WEAPON_LEN_SECONDARY
	if tex != null and tex.get_width() > 1.0:
		var sc: float = target_len / float(tex.get_width())   # scale by LENGTH (barrel along +X)
		s.scale = Vector2(sc, sc)
		# pivot at the grip so rotation happens around the hand, not the sprite center
		s.offset = Vector2((0.5 - GRIP_FX) * float(tex.get_width()),
						   (0.5 - GRIP_FY) * float(tex.get_height()))
	else:
		s.scale = Vector2(0.5, 0.5)
	if EVOLVED.has(id):
		s.self_modulate = Color(1.7, 1.4, 0.6)   # evolved weapons glow gold
		s.scale *= 1.15
	else:
		s.self_modulate = Color(1.3, 1.35, 1.5)
	s.z_index = 6 if is_primary else 5
	return s

func _create_shadow_sprite(weapon_sprite: Sprite2D) -> Sprite2D:
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = weapon_sprite.texture
	shadow.offset = weapon_sprite.offset
	shadow.scale = weapon_sprite.scale * Vector2(1.04, 1.12)
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.32)
	shadow.z_index = 4
	return shadow

func _create_muzzle_sprite(id: String) -> Sprite2D:
	var muzzle: Sprite2D = Sprite2D.new()
	var color: Color = Color(COLORS.get(id, Color.WHITE))
	var tex: Texture2D = Tex.glow(color, 40)
	muzzle.texture = tex
	muzzle.scale = Vector2(0.45, 0.45)
	muzzle.modulate = Color(0.2, 0.2, 0.2)
	muzzle.z_index = 7
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	muzzle.material = mat
	return muzzle

func _process(delta: float) -> void:
	if _player == null:
		return
	
	var alive: bool = true
	if GameState != null and "alive" in GameState:
		alive = bool(GameState.alive)
	
	var aim: Vector2 = Vector2.RIGHT
	if "aim_dir" in _player:
		aim = Vector2(_player.aim_dir)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	
	var aim_ang: float = aim.angle()
	var perp: Vector2 = aim.rotated(PI * 0.5)
	var ppos: Vector2 = Vector2(_player.global_position)
	# grip anchor on the mech body for the current facing -> weapon is HELD, not floating
	var grip: Vector2 = Vector2.ZERO
	var baked: bool = false          # mech (e.g. VALIANT) already holds the gun in its mesh
	var gun: Vector2 = Vector2.ZERO
	if "mecha" in _player and _player.mecha != null:
		if _player.mecha.has_method("grip_anchor"):
			grip = _player.mecha.grip_anchor()
		if _player.mecha.has_method("has_baked_weapon") and _player.mecha.has_baked_weapon():
			baked = true
			if _player.mecha.has_method("gun_anchor"):
				gun = _player.mecha.gun_anchor()
	var first_muzzle: Vector2 = ppos + (gun if baked else grip)
	var first_set: bool = false

	var ids: Array = _weapons.keys()
	for i in range(ids.size()):
		var wid: String = String(ids[i])
		var w: Dictionary = _weapons[wid]
		var is_primary: bool = bool(w.get("is_primary", false))
		var slot: int = int(w.get("slot", 0))
		var wlen: float = float(w.get("len", WEAPON_LEN_PRIMARY))
		var recoil_t: float = float(w["recoil"])
		if recoil_t > 0.0:
			recoil_t = maxf(0.0, recoil_t - delta)
			w["recoil"] = recoil_t
		var recoil_norm: float = (recoil_t / RECOIL_TIME) if RECOIL_TIME > 0.0 else 0.0
		var recoil_off: float = recoil_norm * RECOIL_DIST

		# secondary weapons fan out slightly around the grip so they don't fully overlap
		var side: Vector2 = Vector2.ZERO
		if not is_primary:
			var s_dir: float = 1.0 if (slot % 2 == 1) else -1.0
			side = perp * s_dir * (10.0 + 6.0 * float(slot))
		var base_pos: Vector2 = grip + side - aim * recoil_off
		var muzzle_dist: float = (BARREL_TIP_FX - GRIP_FX) * wlen
		if baked:
			# the cannon is drawn in the mech sprite; don't draw a mounted weapon,
			# just fire from the cannon hand along aim.
			base_pos = gun - aim * recoil_off
			muzzle_dist = 26.0

		var sp: Sprite2D = w["sprite"] as Sprite2D
		sp.visible = not baked
		sp.position = base_pos
		sp.rotation = aim_ang

		var shadow: Sprite2D = w.get("shadow", null) as Sprite2D
		if shadow != null:
			shadow.visible = not baked
			shadow.position = base_pos + perp * 2.0
			shadow.rotation = aim_ang

		var muzzle_local: Vector2 = base_pos + aim * muzzle_dist
		var muzzle_world: Vector2 = ppos + muzzle_local
		if is_primary and not first_set:
			first_muzzle = muzzle_world
			first_set = true
		elif not first_set:
			first_muzzle = muzzle_world
			first_set = true

		var muzzle_sprite: Sprite2D = w.get("muzzle", null) as Sprite2D
		if muzzle_sprite != null:
			muzzle_sprite.position = muzzle_local
			muzzle_sprite.rotation = aim_ang
			if recoil_t > 0.0:
				var pulse: float = 0.7 + recoil_norm * 0.8
				muzzle_sprite.modulate = Color(pulse, pulse, pulse)
				muzzle_sprite.scale = Vector2(0.45 + recoil_norm * 0.4, 0.45 + recoil_norm * 0.4)
			else:
				muzzle_sprite.modulate = Color(0.2, 0.2, 0.2)
				muzzle_sprite.scale = Vector2(0.45, 0.45)
		
		if _active and alive and recoil_t <= 0.001:
			var t: float = float(w["timer"])
			t -= delta
			if t <= 0.0:
				var cdm: float = float(_player.cooldown_mult) if "cooldown_mult" in _player else 1.0
				t = float(w["cooldown"]) * cdm   # Hâte passive
				w["recoil"] = RECOIL_TIME
				_do_fire(wid, w, muzzle_world)
			w["timer"] = t
	
	muzzle_global = first_muzzle

func _do_fire(id: String, w: Dictionary, muzzle_world: Vector2) -> void:
	if _player == null:
		return
	var game: Node = null
	if "game" in _player:
		game = _player.game
	if game == null or not game.has_method("spawn_shot"):
		return
	var base_dmg: float = 1.0
	if "damage" in _player:
		base_dmg = float(_player.damage)
	var lvl: int = int(w["level"])
	var dmg_mult: float = float(BASE_MULT.get(id, 1.0)) * (1.0 + (lvl - 1) * 0.25)
	var params: Dictionary = {
		"dmg": base_dmg * dmg_mult,
		"speed": float(SPEEDS.get(id, 780.0)),
		"pierce": int(PIERCE.get(id, 0)),
		"homing": bool(HOMING.get(id, false)),
		"color": Color(COLORS.get(id, Color.CYAN)),
		"impact": id,
		"crit_chance": float(_player.crit_chance) if "crit_chance" in _player else 0.0,
		"crit_mult": float(_player.crit_mult) if "crit_mult" in _player else 2.0,
	}
	if AOE.has(id):
		params["aoe"] = float(AOE[id])
	var aim: Vector2 = Vector2.RIGHT
	if "aim_dir" in _player:
		aim = Vector2(_player.aim_dir)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var count: int = int(MULTISHOT.get(id, 1))
	if count <= 1:
		game.spawn_shot(muzzle_world, aim, params)
	else:
		var spread: float = deg_to_rad(11.0)
		var a0: float = aim.angle() - spread * (count - 1) * 0.5
		for i in count:
			game.spawn_shot(muzzle_world, Vector2.from_angle(a0 + spread * i), params)
