class_name WeaponSystem
extends Node2D

signal fired(muzzle_world: Vector2)   # a weapon volley left the barrel (drives the mech's shoot pose)

## When true, the flat held-weapon sprites are hidden (the layered MechaRig shows the gun
## via its own aiming hardpoint instead). Firing/muzzle math still runs.
var visuals_hidden: bool = false

const WEAPON_ORDER: Array[String] = ["autocannon", "missilepod", "railgun", "plasma", "sabre",
	"disperseur", "ricochet", "disque", "faisceau",
	"vulcan", "hydra", "annihilator", "singularity", "tempest",
	"deflagrateur", "carambole", "guillotine", "rayon_spectre"]
const MAX_LEVEL: int = 5   # a weapon at MAX + its required passive can EVOLVE
const EVOLVED: Array[String] = ["vulcan", "hydra", "annihilator", "singularity", "tempest",
	"deflagrateur", "carambole", "guillotine", "rayon_spectre"]

# FAISCEAU : pas de projectile — un rayon continu qui balaie (voir _do_beam).
# portee = longueur du rayon, demi_largeur = tolerance laterale du couloir touche.
const BEAM: Dictionary = {
	"faisceau":      {"portee": 520.0, "demi_largeur": 26.0},
	"rayon_spectre": {"portee": 660.0, "demi_largeur": 36.0},
}
# gerbe : angle TOTAL d'ouverture (deg). 11 par defaut pour les armes existantes.
const SPREAD: Dictionary = {"disperseur": 38.0, "deflagrateur": 46.0}
# duree de vie du projectile : c'est elle qui donne la PORTEE COURTE de la gerbe.
const LIFE: Dictionary = {"disperseur": 0.34, "deflagrateur": 0.40, "disque": 1.7, "guillotine": 2.0}
const BOUNCES: Dictionary = {"ricochet": 3, "carambole": 6}
const BOOMERANG: Array[String] = ["disque", "guillotine"]
# MELEE forms: no projectile — they sweep an arc around the mech (see _do_melee).
# reach = radius, arc = full sweep angle. Tempest is the evolution: a full 360° storm.
const MELEE: Dictionary = {
	"sabre":   {"reach": 150.0, "arc": 130.0},
	"tempest": {"reach": 205.0, "arc": 360.0},
}
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
	"disperseur": 0.85, "ricochet": 0.70, "disque": 0.95, "faisceau": 0.55,
	"deflagrateur": 0.72, "carambole": 0.58, "guillotine": 0.80, "rayon_spectre": 0.42,
	"vulcan": 0.12, "hydra": 0.66, "annihilator": 0.85, "singularity": 0.66,
	"sabre": 0.5, "tempest": 0.42,
}

const BASE_MULT: Dictionary = {
	"autocannon": 1.0, "missilepod": 1.6, "railgun": 2.2, "plasma": 1.4,
	"disperseur": 0.42, "ricochet": 1.15, "disque": 1.3, "faisceau": 0.75,
	"deflagrateur": 0.50, "carambole": 1.40, "guillotine": 1.7, "rayon_spectre": 1.0,
	"vulcan": 1.5, "hydra": 1.9, "annihilator": 3.2, "singularity": 2.0,
	"sabre": 1.7, "tempest": 2.6,   # melee: hits every foe in the arc, but you must be in their face
}

const COLORS: Dictionary = {
	"autocannon": Color(1.0, 0.72, 0.15), "missilepod": Color(1.0, 0.45, 0.12),   # amber / fire-orange
	"railgun": Color(0.2, 0.85, 1.0), "plasma": Color(0.75, 0.3, 1.0),            # electric cyan / violet
	"disperseur": Color(1.0, 0.62, 0.22), "deflagrateur": Color(1.0, 0.78, 0.35),
	"ricochet": Color(0.55, 1.0, 0.55), "carambole": Color(0.75, 1.0, 0.6),
	"disque": Color(0.95, 0.9, 0.45), "guillotine": Color(1.0, 0.97, 0.6),
	"faisceau": Color(1.0, 0.35, 0.55), "rayon_spectre": Color(1.0, 0.55, 0.8),
	"vulcan": Color(1.0, 0.85, 0.3), "hydra": Color(1.0, 0.5, 0.2),
	"annihilator": Color(0.55, 0.92, 1.0), "singularity": Color(0.85, 0.4, 1.0),
	"sabre": Color(0.35, 0.95, 1.0), "tempest": Color(0.6, 1.0, 1.0),   # incandescent cyan blade
}

const SPEEDS: Dictionary = {
	"autocannon": 820.0, "missilepod": 430.0, "railgun": 1500.0, "plasma": 540.0,
	"disperseur": 760.0, "ricochet": 700.0, "disque": 620.0,
	"deflagrateur": 800.0, "carambole": 760.0, "guillotine": 700.0,
	"vulcan": 950.0, "hydra": 500.0, "annihilator": 1800.0, "singularity": 560.0,
}

const PIERCE: Dictionary = {
	"autocannon": 0, "missilepod": 0, "railgun": 5, "plasma": 0,
	"disperseur": 0, "ricochet": 0, "disque": 20,
	"deflagrateur": 1, "carambole": 0, "guillotine": 30,
	"vulcan": 2, "hydra": 0, "annihilator": 30, "singularity": 0,
}

const HOMING: Dictionary = {
	"autocannon": false, "missilepod": true, "railgun": false, "plasma": false,
	"vulcan": false, "hydra": true, "annihilator": false, "singularity": false,
}

# DARK-PREMIUM per-weapon MUZZLE/CAST effect (id -> [vfx_id, scale]). Each weapon spawns ITS OWN
# effect on firing, tinted with its accent colour (COLORS[id]) -> no two weapons look the same.
const MUZZLE_FX: Dictionary = {
	"autocannon": ["aaa_muzzle", 0.5], "vulcan": ["aaa_muzzle", 0.62],   # directional bloomed flash + rays
	"missilepod": ["fire_blast", 0.34], "hydra": ["fire_blast", 0.46],   # fiery launch
	"disperseur": ["aaa_muzzle", 0.6], "deflagrateur": ["aaa_muzzle", 0.72],
	"ricochet": ["dp_muzzle", 0.5], "carambole": ["dp_muzzle", 0.6],
	"disque": ["aaa_muzzle", 0.5], "guillotine": ["aaa_muzzle", 0.6],
	"faisceau": ["aaa_charge", 0.5], "rayon_spectre": ["aaa_charge", 0.62],
	"railgun": ["aaa_muzzle", 0.44], "annihilator": ["aaa_muzzle", 0.56],# electric forward flash
	"plasma": ["aaa_charge", 0.4], "singularity": ["aaa_charge", 0.52],  # plasma charge bloom
}

const AOE: Dictionary = {
	"missilepod": 60.0, "plasma": 74.0,
	"deflagrateur": 34.0,
	"hydra": 80.0, "singularity": 130.0,
}

const MULTISHOT: Dictionary = {   # projectiles fired per shot, spread around aim
	"vulcan": 3, "hydra": 3,
	"disperseur": 6, "deflagrateur": 9,
}

var muzzle_global: Vector2 = Vector2.ZERO

var _player: Node = null
var _active: bool = true
var _weapons: Dictionary = {}

## --- SIGNATURE DU CHASSIS ---------------------------------------------------------------
## Chaque mecha a UNE arme signature (voir GameState.MECHS) : c'est la seule qu'il booste, et
## elle porte SA couleur et SON effet de bouche. Deux chassis qui tireraient la meme arme ne
## produiraient pas la meme image — c'est ce qui les distingue autrement que par des chiffres.
const SIG_DMG: float = 1.35      # +35 % de degats sur la signature
const SIG_CD: float = 0.86       # -14 % de temps de recharge
const SIG_FX: float = 1.25       # gerbe d'impact et projectile 25 % plus gros
var _sig: String = ""
var _accent: Color = Color.WHITE
var _sig_muzzle: Array = []

func setup(p: Node, starters: Array = ["autocannon"]) -> void:
	_player = p
	var mid: String = SaveManager.equipped_mech()
	var mdef: Dictionary = GameState.mech_def(mid)
	_sig = GameState.mech_signature(mid)
	_accent = Color(mdef.get("accent", Color.WHITE))
	_sig_muzzle = mdef.get("sig_muzzle", [])
	for wid in starters:
		add_weapon(String(wid))

func signature() -> String:
	return _sig

## Couleur d'une arme : sa teinte habituelle, SAUF la signature du chassis, repeinte a son
## accent. C'est ce qui fait qu'un autocanon de VORTEX (cyan electrique) et celui d'un autre
## chassis ne se ressemblent pas, alors que c'est la meme arme.
func _col(id: String) -> Color:
	if id == _sig:
		return _accent
	return Color(COLORS.get(id, Color.CYAN))   # 🚨 lookup DIRECT : surtout pas _col(), recursion

func weapon_level(id: String) -> int:
	return int(_weapons[id]["level"]) if _weapons.has(id) else 0

func add_weapon(id: String) -> void:
	if not WEAPON_ORDER.has(id):
		return
	if _weapons.has(id):
		var w: Dictionary = _weapons[id]
		w["level"] = mini(MAX_LEVEL, int(w["level"]) + 1)
		w["cooldown"] = maxf(0.08, float(w["cooldown"]) * 0.85)
	else:
		if _weapons.size() >= 6:   # 6 slots d'armes/actives (parite Survivor.io)
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
		"cooldown": float(COOLDOWNS.get(id, 0.5)) * (SIG_CD if id == _sig else 1.0),
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
		"disperseur", "deflagrateur": return "res://assets/weapons/autocannon.png"
		"ricochet", "carambole": return "res://assets/weapons/missilepod.png"
		"disque", "guillotine": return "res://assets/weapons/railgun.png"
		"faisceau", "rayon_spectre": return "res://assets/weapons/plasmacaster.png"
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
	if MELEE.has(id):
		s.visible = false   # blade forms have no held gun sprite — the swing FX IS the weapon
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
	var color: Color = _col(id)
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
	var tip_anchored: bool = false   # gun_anchor() is the barrel TIP (VORTEX) -> flash rides the tip
	var gun: Vector2 = Vector2.ZERO
	if "mecha" in _player and _player.mecha != null:
		if _player.mecha.has_method("grip_anchor"):
			grip = _player.mecha.grip_anchor()
		if _player.mecha.has_method("has_baked_weapon") and _player.mecha.has_baked_weapon():
			baked = true
			if _player.mecha.has_method("gun_anchor"):
				gun = _player.mecha.gun_anchor()
			tip_anchored = _player.mecha.has_method("gun_at_tip") and _player.mecha.gun_at_tip()
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
			# just fire from the cannon along aim.
			base_pos = gun - aim * recoil_off
			# gun_anchor() is the barrel TIP for VORTEX (measured) -> almost no extra offset;
			# for hand-anchored chassis (VALIANT) push out to the barrel end.
			muzzle_dist = 2.0 if tip_anchored else 26.0
		elif visuals_hidden:
			# VORTEX carries an ARM-CANNON baked into its sprite: fire the beam/muzzle from the cannon
			# TIP (further out than a bare wrist) so the shot leaves the barrel, not the elbow.
			muzzle_dist = 46.0

		var show_wp: bool = not baked and not visuals_hidden
		var sp: Sprite2D = w["sprite"] as Sprite2D
		sp.visible = show_wp
		sp.position = base_pos
		sp.rotation = aim_ang
		
		# Flip weapon vertically when aiming leftwards so the gun stays right-side-up
		var base_sc_x: float = absf(sp.scale.x)
		var base_sc_y: float = absf(sp.scale.y)
		if aim.x < -0.05:
			sp.scale.y = -base_sc_y
		elif aim.x > 0.05:
			sp.scale.y = base_sc_y
			
		# Depth z-index sorting: when facing back (away from camera), weapon sits behind torso
		var back_facing: bool = false
		if "mecha" in _player and _player.mecha != null and _player.mecha.has_method("facing"):
			back_facing = (_player.mecha.facing() == "back")
		sp.z_index = -1 if back_facing else (6 if is_primary else 5)

		var shadow: Sprite2D = w.get("shadow", null) as Sprite2D
		if shadow != null:
			shadow.visible = show_wp
			shadow.position = base_pos + perp * 2.0
			shadow.rotation = aim_ang
			shadow.scale = Vector2(sp.scale.x * 1.04, sp.scale.y * 1.12)
			shadow.z_index = -2 if back_facing else 4

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
			# VORTEX's flash is this LOCAL sprite (child -> glued to the moving mech, zero lag). It only
			# shows on the shot; the trailing world-space bloom is suppressed for it (see _do_fire).
			muzzle_sprite.visible = show_wp or (tip_anchored and recoil_t > 0.0)
			muzzle_sprite.position = muzzle_local
			muzzle_sprite.rotation = aim_ang
			if recoil_t > 0.0:
				var pulse: float = 0.7 + recoil_norm * 0.8
				muzzle_sprite.modulate = Color(pulse, pulse, pulse)
				var msc: float = (0.7 if tip_anchored else 0.45) + recoil_norm * 0.5
				muzzle_sprite.scale = Vector2(msc, msc)
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

## Each weapon FAMILY (base + its evolution) maps to its own report (see gen_weapon_sfx.py).
const SFX_FOR: Dictionary = {
	"autocannon": "w_autocannon", "vulcan": "w_autocannon",
	"missilepod": "w_missile", "hydra": "w_missile",
	"disperseur": "w_autocannon", "deflagrateur": "w_autocannon",
	"ricochet": "w_missile", "carambole": "w_missile",
	"disque": "w_railgun", "guillotine": "w_railgun",
	"faisceau": "w_plasma", "rayon_spectre": "w_plasma",
	"railgun": "w_railgun", "annihilator": "w_railgun",
	"plasma": "w_plasma", "singularity": "w_plasma",
	"sabre": "w_sabre", "tempest": "w_sabre",
}

func _do_fire(id: String, w: Dictionary, muzzle_world: Vector2) -> void:
	if _player == null:
		return
	var game: Node = null
	if "game" in _player:
		game = _player.game
	if game == null or not game.has_method("spawn_shot"):
		return
	Audio.sfx(String(SFX_FOR.get(id, "shoot")), 0.06)   # distinct report per weapon
	var base_dmg: float = 1.0
	if "damage" in _player:
		base_dmg = float(_player.damage)
	var lvl: int = int(w["level"])
	var dmg_mult: float = float(BASE_MULT.get(id, 1.0)) * (1.0 + (lvl - 1) * 0.25)
	if id == _sig:
		dmg_mult *= SIG_DMG      # arme signature du chassis
	# VFX grow with the weapon's level so every level-up is visibly stronger — the addictive part.
	# Each weapon grows the way that fits it: AoE weapons blast WIDER, and every weapon's muzzle,
	# bolt and impact scale up together (see fx_scale flowing through the projectile to impact_fx).
	var fx_scale: float = 1.0 + float(lvl - 1) * 0.14
	if id == _sig:
		fx_scale *= SIG_FX     # la signature frappe plus gros — l'accent voyage jusqu'a l'impact
	if MELEE.has(id):                       # blade forms sweep an arc instead of firing
		_do_melee(id, base_dmg * dmg_mult, game)
		fired.emit(muzzle_world)
		return
	if BEAM.has(id):                        # le faisceau balaie un couloir, sans projectile
		_do_beam(id, base_dmg * dmg_mult, game, muzzle_world, fx_scale)
		fired.emit(muzzle_world)
		return
	var pspeed: float = float(_player.proj_speed_mult) if "proj_speed_mult" in _player else 1.0
	var psize: float = float(_player.size_mult) if "size_mult" in _player else 1.0
	var params: Dictionary = {
		"dmg": base_dmg * dmg_mult,
		"speed": float(SPEEDS.get(id, 780.0)) * pspeed,      # Ammo Thruster
		"pierce": int(PIERCE.get(id, 0)),
		"homing": bool(HOMING.get(id, false)),
		"color": _col(id),
		"impact": id,
		"crit_chance": float(_player.crit_chance) if "crit_chance" in _player else 0.0,
		"crit_mult": float(_player.crit_mult) if "crit_mult" in _player else 2.0,
		"fx_scale": fx_scale * psize,                        # HE Fuel (taille)
		"life": float(LIFE.get(id, 2.0)),                    # portee courte de la gerbe
		"bounces": int(BOUNCES.get(id, 0)),                  # ricochet
		"boomerang": BOOMERANG.has(id),                      # disque
	}
	if AOE.has(id):
		# blast radius grows with level: an AoE weapon LITERALLY covers more ground each level.
		params["aoe"] = float(AOE[id]) * (1.0 + float(lvl - 1) * 0.16) * psize   # HE Fuel
	var aim: Vector2 = Vector2.RIGHT
	if "aim_dir" in _player:
		aim = Vector2(_player.aim_dir)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var count: int = int(MULTISHOT.get(id, 1))
	if count <= 1:
		game.spawn_shot(muzzle_world, aim, params)
	else:
		var spread: float = deg_to_rad(float(SPREAD.get(id, 11.0)) / maxf(1.0, float(count - 1)))
		var a0: float = aim.angle() - spread * (count - 1) * 0.5
		for i in count:
			game.spawn_shot(muzzle_world, Vector2.from_angle(a0 + spread * i), params)
	# each weapon casts its OWN dark-premium effect (distinct shape + its accent colour).
	# For a TIP-anchored arm-cannon (VORTEX) the flash is the LOCAL child sprite that stays glued to
	# the moving mech; a world-space bloom here would be left behind while walking (the "décalage"),
	# so skip it for that case.
	var tip_flash: bool = "mecha" in _player and _player.mecha != null \
		and _player.mecha.has_method("gun_at_tip") and _player.mecha.gun_at_tip()
	if game.has_method("spawn_vfx") and not tip_flash:
		# la signature a SON effet de bouche (declare par le chassis), plus large que celui de
		# l'arme generique : c'est la premiere chose qu'on voit de l'identite du mecha.
		var mfx: Array = _sig_muzzle if (id == _sig and _sig_muzzle.size() == 2) else MUZZLE_FX.get(id, ["dp_muzzle", 0.55])
		var mc: Color = _col(id)
		var acc: Color = Color(mc.r * 1.4 + 0.25, mc.g * 1.4 + 0.25, mc.b * 1.4 + 0.25)  # bloomed accent
		# horizontal-drawn effects align to aim directly; up-drawn (fire) need +90; radial ones don't care
		var rot: float = aim.angle() if String(mfx[0]) in ["elec_beam", "hq_muzzle", "hq_beam", "aaa_muzzle", "aaa_beam"] else aim.angle() + PI * 0.5
		game.spawn_vfx(String(mfx[0]), muzzle_world + aim * 10.0, rot, float(mfx[1]) * fx_scale, acc)
	fired.emit(muzzle_world)

## FAISCEAU : un rayon continu part de la bouche vers la visee et touche TOUT ce qui se
## trouve dans un couloir etroit, jusqu'a sa portee. C'est l'archetype "laser" qui manquait :
## pas de projectile a esquiver, mais il faut rester aligne sur la cible.
func _do_beam(id: String, dmg: float, game: Node, muzzle: Vector2, fx_scale: float) -> void:
	var d: Dictionary = BEAM[id]
	var reach: float = float(d["portee"])
	var half: float = float(d["demi_largeur"])
	var aim: Vector2 = Vector2.RIGHT
	if "aim_dir" in _player:
		aim = Vector2(_player.aim_dir)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var cc: float = float(_player.crit_chance) if "crit_chance" in _player else 0.0
	var cm: float = float(_player.crit_mult) if "crit_mult" in _player else 2.0
	var col: Color = _col(id)
	for e in _player.get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or not (e as Enemy).alive:
			continue
		var to: Vector2 = (e as Node2D).global_position - muzzle
		var along: float = to.dot(aim)
		if along < 0.0 or along > reach:
			continue
		if absf(to.cross(aim)) > half:            # distance laterale au rayon
			continue
		var is_crit: bool = randf() < cc
		var hit: float = dmg * (cm if is_crit else 1.0)
		(e as Enemy).take_damage(hit)
		Events.damage_dealt.emit((e as Node2D).global_position, int(hit), is_crit)
	# --- RENDU : un COMPOSITE, jamais un trait ------------------------------------
	# Le rayon est une PLANCHE ANIMEE etiree sur toute sa longueur (elle vit et scintille
	# d'elle-meme), doublee d'un coeur blanc plus fin, avec une amorce a la bouche, un
	# impact au bout et une secousse. C'est ce qui separe un effet d'un placeholder.
	if not game.has_method("spawn_vfx"):
		return
	var hot: Color = col.lerp(Color.WHITE, 0.55)
	var ang: float = aim.angle()
	var mid: Vector2 = muzzle + aim * (reach * 0.5)
	var tip: Vector2 = muzzle + aim * reach
	# 1) TROIS COUCHES de trait additif : halo diffus, corps colore, coeur blanc.
	#    (la planche animee seule ne suffit pas : son trait utile est fin au centre de
	#     l'image, donc une fois etiree elle disparait — mesure faite en jeu)
	if game.has_method("_streak"):
		game._streak(mid, aim, Color(col.r, col.g, col.b, 0.30), reach, half * 2.8 * fx_scale, 0.20)
		game._streak(mid, aim, col, reach, half * 1.25 * fx_scale, 0.17)
		game._streak(mid, aim, hot, reach, half * 0.45 * fx_scale, 0.14)
	# 2) la planche animee PAR-DESSUS : c'est elle qui fait vivre le rayon (scintillement)
	var body_scl: float = (half * 3.2 / 168.0) * fx_scale
	game.spawn_vfx("aaa_beam", mid, ang, body_scl, col,
		Vector2(reach / maxf(1.0, 168.0 * body_scl), 1.0))
	# 3) amorce a la bouche + halo
	game.spawn_vfx("aaa_muzzle", muzzle + aim * 14.0, ang, 0.52 * fx_scale, hot)
	game.spawn_vfx("aaa_charge", muzzle, 0.0, 0.34 * fx_scale, col)
	# 4) impact au bout du rayon : eclat + onde
	game.spawn_vfx("aaa_impact", tip, 0.0, 0.46 * fx_scale, col)
	game.spawn_vfx("aaa_shockwave", tip, 0.0, 0.30 * fx_scale, hot)
	# 5) la secousse : le rayon doit se SENTIR
	Events.screen_shake.emit(2.4 * fx_scale)

## MELEE sweep: damages every live foe inside an arc centred on aim, then draws the blade.
## Alternates the sweep side each swing so repeated slashes read as a real combo, not a stamp.
var _swing_side: float = 1.0

func _do_melee(id: String, dmg: float, game: Node) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var d: Dictionary = MELEE[id]
	var reach: float = float(d["reach"])
	var half: float = deg_to_rad(float(d["arc"]) * 0.5)
	var full: bool = float(d["arc"]) >= 359.0
	var aim: Vector2 = Vector2.RIGHT
	if "aim_dir" in _player:
		aim = Vector2(_player.aim_dir)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var origin: Vector2 = (_player as Node2D).global_position
	var acc: Color = _col(id)
	var crit_chance: float = float(_player.crit_chance) if "crit_chance" in _player else 0.0
	var crit_mult: float = float(_player.crit_mult) if "crit_mult" in _player else 2.0
	var reach_sq: float = reach * reach
	var hits: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or not is_instance_valid(e) or not (e as Enemy).alive:
			continue
		var ep: Vector2 = (e as Node2D).global_position
		var to: Vector2 = ep - origin
		if to.length_squared() > reach_sq:
			continue
		if not full and absf(wrapf(to.angle() - aim.angle(), -PI, PI)) > half:
			continue
		var is_crit: bool = randf() < crit_chance
		var out: float = dmg * (crit_mult if is_crit else 1.0)
		(e as Enemy).take_damage(out)
		Events.damage_dealt.emit(ep, int(out), is_crit)
		if is_crit:
			Audio.sfx("crit", 0.1)
		hits += 1
	# blade FX: the crescent is drawn around the mech, tilted to the swing side
	if game.has_method("spawn_vfx"):
		var tilt: float = 0.0 if full else _swing_side * deg_to_rad(26.0)
		game.spawn_vfx("aaa_sabre", origin + aim * (reach * 0.32), aim.angle() + tilt,
			reach / 190.0, Color(acc.r * 1.5 + 0.2, acc.g * 1.5 + 0.2, acc.b * 1.5 + 0.2))
	_swing_side *= -1.0
	if hits > 0:
		Audio.sfx("hit", 0.12)
		Events.screen_shake.emit(1.6 if not full else 2.6)
		if game.has_method("hit_stop"):
			game.hit_stop(0.03)
