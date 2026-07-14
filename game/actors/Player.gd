extends CharacterBody2D
class_name Player
## Top-down player with an "Overdrive" transformation, continuous energy beam, and melee saber.

var game: Node
var mecha   # the mech visual (DirectionalMecha baked sheets OR HeroRig 2D cut-out rig)
var base_speed: float = 320.0
var move_mult: float = 1.0   # biome modifier on movement (e.g. swamp slows, low-g speeds up)
var hp: float = 100.0
var max_hp: float = 100.0
var damage: float = 12.0
# passive-driven combat stats (raised by draft cards)
var crit_chance: float = 0.05
var crit_mult: float = 2.0
var armor: float = 0.0            # incoming damage reduction, 0..~0.6
var cooldown_mult: float = 1.0    # haste: <1 = faster weapons
var magnet_range: float = 360.0   # pickup vacuum radius
# --- helper systems (drafted, entity/VFX-based -- NEVER modeled on the mech sprite) ---
var aura_level: int = 0            # damaging shield ring around the mech; radius grows per pick
var aura_radius: float = 0.0
var aura_dmg: float = 7.0
var _aura_spr: Sprite2D = null
var _aura_t: float = 0.0
var _aura_flash: float = 0.0       # brief brighten when the ring "discharges" (damage tick)
var _drones: Array = []            # orbiting companion drones that auto-fire
var arena: Rect2 = Rect2(-1000000, -1000000, 2000000, 2000000)   # effectively unbounded (no felt wall)

var bot_active: bool = false
var bot_move: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.DOWN

var _iframe: float = 0.0
var _firing_t: float = 0.0   # >0 while a weapon fired recently (drives the standing shoot pose)
var _stick_id: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_vec: Vector2 = Vector2.ZERO
var _aim_stick_id: int = -1
var _aim_stick_origin: Vector2 = Vector2.ZERO
var _thruster: CPUParticles2D
var _laser: Line2D
var _laser_dot: Sprite2D
var _weapons: WeaponSystem

var transformed: bool = false
var _tf_t: float = 0.0
var base_chassis: String = ""
const TF_DUR: float = 8.0   # Overdrive "harvester" spike: short, intense, then vulnerable again
var _space_was: bool = false

const BEAM_LEN: float = 1000.0
const BEAM_DPS: float = 90.0
var _beam: Line2D
var _beam_glow: Line2D
var _beam_dot: Sprite2D
var _beam_light: PointLight2D

var _od_aura: Sprite2D       # overdrive/transform aura around the mech

func get_layer_ok() -> bool:
	return mecha != null

func _ready() -> void:
	add_to_group("player")
	# equipped mech (garage) + persistent meta-progression talents, applied together
	var mech: Dictionary = GameState.mech_def(SaveManager.equipped_mech())
	max_hp += GameState.meta_hp + float(mech.get("hp", 0.0))
	damage *= (1.0 + GameState.meta_dmg) * float(mech.get("dmg", 1.0))
	base_speed *= (1.0 + GameState.meta_speed) * float(mech.get("speed", 1.0))
	crit_chance += float(mech.get("crit", 0.0))
	hp = max_hp
	# VISUAL: Quaternius CC0 mech "george" rendered to 4-dir animated spritesheets (bpy Cycles CPU).
	# Uses the baked DirectionalMecha path (walk/run/idle/attack/hit/die per facing). Aim = movement
	# direction (no auto-aim) so it never spins; the gait animates from movement. Gameplay stats still
	# come from the equipped garage mech above.
	# Player visual = Gemini-painted hero on a 2D cut-out rig (George dropped). Swappable per chosen hero.
	mecha = HeroRig.new()
	mecha.display_height = 214.0
	add_child(mecha)
	base_chassis = "hero"

	_weapons = WeaponSystem.new()
	add_child(_weapons)
	_weapons.setup(self, mech.get("weapons", ["autocannon"]))   # starter loadout per mech
	_weapons.visuals_hidden = true   # no floating gun: the mech's own arms + Shoot anim + projectiles read the combat
	_weapons.fired.connect(_on_weapon_fired)

	var cs: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = 26.0
	cs.shape = c
	add_child(cs)
	collision_layer = 1
	collision_mask = 0

	_thruster = CPUParticles2D.new()
	_thruster.amount = 24
	_thruster.lifetime = 0.4
	_thruster.local_coords = false
	_thruster.emitting = false
	_thruster.spread = 20.0
	_thruster.gravity = Vector2.ZERO
	_thruster.initial_velocity_min = 60.0
	_thruster.initial_velocity_max = 140.0
	_thruster.scale_amount_min = 2.0
	_thruster.scale_amount_max = 4.5
	_thruster.color = Palette.CYAN
	_thruster.z_index = -1
	var tm: CanvasItemMaterial = CanvasItemMaterial.new()
	tm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_thruster.material = tm
	add_child(_thruster)

	_laser = Line2D.new()
	_laser.width = 3.0
	_laser.default_color = Color(1.0, 0.3, 0.3, 0.5)
	var lm: CanvasItemMaterial = CanvasItemMaterial.new()
	lm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_laser.material = lm
	_laser.z_index = 3
	_laser.add_point(Vector2.ZERO)
	_laser.add_point(Vector2.ZERO)
	add_child(_laser)

	_laser_dot = Sprite2D.new()
	_laser_dot.texture = Tex.glow(Color(1.0, 0.4, 0.4), 48)
	var dm: CanvasItemMaterial = CanvasItemMaterial.new()
	dm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_laser_dot.material = dm
	_laser_dot.z_index = 3
	add_child(_laser_dot)

	_beam_glow = Line2D.new()
	_beam_glow.width = 34.0
	_beam_glow.default_color = Color(0.2, 0.7, 1.0, 0.35)
	var bm_glow: CanvasItemMaterial = CanvasItemMaterial.new()
	bm_glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam_glow.material = bm_glow
	_beam_glow.z_index = 3
	_beam_glow.add_point(Vector2.ZERO)
	_beam_glow.add_point(Vector2.ZERO)
	_beam_glow.visible = false
	add_child(_beam_glow)

	_beam = Line2D.new()
	_beam.width = 16.0
	_beam.default_color = Color(0.6, 0.95, 1.0, 0.9)
	var bm: CanvasItemMaterial = CanvasItemMaterial.new()
	bm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = bm
	_beam.z_index = 3
	_beam.add_point(Vector2.ZERO)
	_beam.add_point(Vector2.ZERO)
	_beam.visible = false
	add_child(_beam)

	_beam_dot = Sprite2D.new()
	_beam_dot.texture = Tex.glow(Color(0.7, 0.97, 1.0), 96)
	var bdm: CanvasItemMaterial = CanvasItemMaterial.new()
	bdm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam_dot.material = bdm
	_beam_dot.z_index = 3
	_beam_dot.visible = false
	add_child(_beam_dot)

	_beam_light = PointLight2D.new()
	_beam_light.color = Color(0.6, 0.95, 1.0, 0.9)
	_beam_light.energy = 2.0
	_beam_light.texture_scale = 1.5
	_beam_light.texture = Tex.glow(Color(0.7, 0.97, 1.0), 128)
	_beam_light.visible = false
	add_child(_beam_light)

	# overdrive aura around the mech during the transform
	_od_aura = Sprite2D.new()
	_od_aura.texture = Tex.glow(Color(1.0, 0.6, 0.2), 128)
	var aum: CanvasItemMaterial = CanvasItemMaterial.new()
	aum.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_od_aura.material = aum
	_od_aura.scale = Vector2(2.4, 2.4)
	_od_aura.z_index = -1
	_od_aura.visible = false
	add_child(_od_aura)

func _physics_process(delta: float) -> void:
	var alive_now: bool = GameState.alive
	if not alive_now:
		_laser.visible = false
		_laser_dot.visible = false
		_thruster.emitting = false
		_hide_beam()
		if _weapons != null:
			_weapons.set_active(false)
		return

	var edge: bool = Input.is_key_pressed(KEY_SPACE)
	if edge and not _space_was and not transformed and GameState.overdrive >= 1.0:
		_transform_on()
	if bot_active and not transformed and GameState.overdrive >= 1.0:
		_transform_on()
	_space_was = edge

	if transformed:
		_tf_t -= delta
		if _tf_t <= 0.0:
			_transform_off()

	_iframe = maxf(0.0, _iframe - delta)
	var mv: Vector2 = _move_input()
	velocity = mv * base_speed * move_mult * (2.0 if transformed else 1.0)   # Overdrive = x2 speed
	move_and_slide()
	global_position.x = clampf(global_position.x, arena.position.x, arena.end.x)
	global_position.y = clampf(global_position.y, arena.position.y, arena.end.y)

	_firing_t = maxf(0.0, _firing_t - delta)
	if mv.length() > 0.1:
		# MOVING always walks/runs — movement wins over the shoot pose so the mech never
		# freezes mid-stride. The held weapon (WeaponSystem) still points at the target, so
		# the mech "strafes while keeping its gun trained on the enemy".
		_thruster.emitting = true
		_thruster.direction = -mv
		# run is reserved for Overdrive; a fixed 360 threshold on an ever-growing base_speed
		# makes the walk sheet unreachable after ~2 speed upgrades, so gate on transform.
		var want: String = "run" if transformed else "walk"
		if mecha.current_anim() != want:
			mecha.play(want)
	else:
		# STANDING: show the arms-up shoot pose while recently firing, else idle.
		# NOTE: "attack" is intentionally absent from the idle fallback list — cutting the
		# one-shot when _firing_t expires truncated the recoil. Let DirectionalMecha play the
		# attack one-shot fully and auto-return it to idle on its own.
		_thruster.emitting = false
		if _firing_t > 0.0 and not transformed:
			if mecha.current_anim() != "attack":
				mecha.play("attack")
		elif mecha.current_anim() in ["walk", "run"]:
			mecha.play("idle")

	_update_aim()
	mecha.set_facing_from(aim_dir)   # face the movement direction (aim = movement, no auto-aim -> no spin)
	_update_helpers(delta)

	if transformed:
		if _od_aura != null:
			var ta: float = Time.get_ticks_msec() / 1000.0
			_od_aura.scale = Vector2.ONE * (2.3 + 0.3 * sin(ta * 6.0))
			_od_aura.modulate = Color(1, 1, 1, 0.55 + 0.2 * sin(ta * 6.0))
		_weapons.set_active(false)
		_laser.visible = false
		_laser_dot.visible = false
		_process_beam(delta)
	else:
		_hide_beam()
		_weapons.set_active(true)
		if _weapons != null:
			var m: Vector2 = _weapons.muzzle_global
			_laser.set_point_position(0, to_local(m))
			_laser.set_point_position(1, to_local(m + aim_dir * 900.0))
			_laser_dot.position = to_local(m + aim_dir * 900.0)
			_laser.visible = true
			_laser_dot.visible = true

func add_weapon(id: String) -> void:
	if _weapons != null:
		_weapons.add_weapon(id)

func weapons() -> WeaponSystem:
	return _weapons

func _on_weapon_fired(_muzzle: Vector2) -> void:
	_firing_t = 0.36   # standing shoot-pose window = full attack anim (8f @ 22fps) so the recoil plays out
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("muzzle", _muzzle, aim_dir.angle(), 0.42)   # animated flash at the barrel, aimed

# --- Damaging shield aura (draftable, radius grows each time it's chosen) ---
func add_aura() -> void:
	aura_level += 1
	if aura_level == 1:
		aura_radius = 92.0        # sensible first size (reaches just past the mech), not huge
	else:
		aura_radius += 40.0       # gentle growth per extra pick
	aura_dmg += 2.0
	if _aura_spr == null:
		_aura_spr = Sprite2D.new()
		_aura_spr.texture = Tex.ring(Color(0.55, 0.95, 1.0), 192)   # bigger tex -> crisp thin rim
		var m: CanvasItemMaterial = CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_aura_spr.material = m
		_aura_spr.z_index = -1
		add_child(_aura_spr)

# --- Companion drone (draftable, stackable): orbits and auto-fires at foes ---
func add_drone() -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = Tex.glow(Color(0.72, 0.97, 1.0), 56)
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = m
	spr.scale = Vector2(0.95, 0.95)
	spr.z_index = 2
	# small solid core so the drone reads as a physical unit, not just a light
	var core: Sprite2D = Sprite2D.new()
	core.texture = Tex.glow(Color(0.95, 1.0, 1.0), 24)
	var cm: CanvasItemMaterial = CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	core.material = cm
	spr.add_child(core)
	add_child(spr)
	_drones.append({"spr": spr, "ang": randf() * TAU, "cd": randf_range(0.0, 0.6)})

func _update_helpers(delta: float) -> void:
	# damaging aura — a thin rotating energy ring that "discharges" (brightens) on each tick
	if aura_level > 0 and _aura_spr != null:
		var diam: float = aura_radius * 2.0
		var beat: float = sin(Time.get_ticks_msec() / 260.0)
		_aura_spr.scale = Vector2.ONE * (diam / 192.0) * (0.97 + 0.03 * beat)
		_aura_spr.rotation += delta * 0.5
		_aura_flash = maxf(0.0, _aura_flash - delta * 2.2)
		_aura_spr.modulate = Color(0.55, 0.95, 1.0, 0.4 + 0.1 * beat + _aura_flash * 0.5)
		_aura_t -= delta
		if _aura_t <= 0.0:
			_aura_t = 0.5
			_aura_flash = 1.0   # discharge flash
			var r2: float = aura_radius * aura_radius
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Enemy and e.alive and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
					var is_crit: bool = randf() < crit_chance   # aura crits like every other weapon
					var dmg: float = aura_dmg * (crit_mult if is_crit else 1.0)
					(e as Enemy).take_damage(dmg)
					if is_crit:
						Events.damage_dealt.emit((e as Node2D).global_position, int(dmg), true)
	# orbiting drones
	for i in _drones.size():
		var d: Dictionary = _drones[i]
		d["ang"] = float(d["ang"]) + delta * 2.2
		var orbit_r: float = 158.0 + float(i % 4) * 26.0
		var sp: Sprite2D = d["spr"]
		sp.position = Vector2(cos(d["ang"]), sin(d["ang"])) * orbit_r
		d["cd"] = float(d["cd"]) - delta
		if float(d["cd"]) <= 0.0:
			var tgt: Node2D = _nearest_enemy()
			if tgt != null and game != null and game.has_method("spawn_shot"):
				d["cd"] = 0.7
				var mw: Vector2 = global_position + sp.position
				var dir: Vector2 = (tgt.global_position - mw).normalized()
				game.spawn_shot(mw, dir, {"dmg": damage * 0.5, "speed": 760.0,
					"color": Color(0.5, 0.95, 1.0), "impact": "drone",
					"crit_chance": crit_chance, "crit_mult": crit_mult})

func _process_beam(delta: float) -> void:
	var start: Vector2 = aim_dir * 46.0
	var end: Vector2 = aim_dir * BEAM_LEN

	_beam.set_point_position(0, start)
	_beam.set_point_position(1, end)
	_beam.visible = true

	_beam_glow.set_point_position(0, start)
	_beam_glow.set_point_position(1, end)
	_beam_glow.visible = true

	_beam_dot.position = end
	_beam_dot.visible = true

	_beam_light.position = end
	_beam_light.visible = true

	var gs: Vector2 = global_position + start
	var ge: Vector2 = global_position + end

	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and e.alive and e.has_method("take_damage"):
			var ep: Vector2 = (e as Node2D).global_position
			var seg_vec: Vector2 = ge - gs
			var seg_len_sq: float = seg_vec.length_squared()
			var t: float = 0.0
			if seg_len_sq > 0.0:
				t = (ep - gs).dot(seg_vec) / seg_len_sq
			if t >= 0.0 and t <= 1.0:
				var proj: Vector2 = gs + seg_vec * t
				if proj.distance_to(ep) < 30.0:
					(e as Node2D).take_damage(BEAM_DPS * delta)
					if randf() < 0.15:
						Events.hit_spark.emit(ep, Color(0.6, 0.95, 1.0))

func _hide_beam() -> void:
	if _beam != null:
		_beam.visible = false
	if _beam_glow != null:
		_beam_glow.visible = false
	if _beam_dot != null:
		_beam_dot.visible = false
	if _beam_light != null:
		_beam_light.visible = false

## Public trigger for the Overdrive (used by the HUD touch button on mobile; desktop also
## has the SPACE key). Only fires when the gauge is full and we're alive & not already in it.
func activate_overdrive() -> void:
	if not transformed and GameState.alive and GameState.overdrive >= 1.0:
		_transform_on()

func _transform_on() -> void:
	# OVERDRIVE "HARVESTER": invincible + double speed + global XP magnet for TF_DUR seconds,
	# plus the continuous energy beam. A huge dopamine spike, then back to vulnerable.
	transformed = true
	_tf_t = TF_DUR
	GameState.overdrive = 0.0
	GameState.overdrive_active = true
	Events.overdrive_changed.emit(0.0)
	if mecha.has_method("set_tint"):
		mecha.set_tint(Color(1.6, 1.35, 0.95))
	if _od_aura != null:
		_od_aura.visible = true
	if game != null and game.has_method("transform_fx"):
		game.transform_fx(global_position, true)
	Events.player_transformed.emit(true)

func _transform_off() -> void:
	transformed = false
	GameState.overdrive_active = false
	if mecha.has_method("set_tint"):
		mecha.set_tint(Color.WHITE)
	if _od_aura != null:
		_od_aura.visible = false
	if game != null and game.has_method("transform_fx"):
		game.transform_fx(global_position, false)
	Events.player_transformed.emit(false)

func _update_aim() -> void:
	# NO auto-aim: the mech shoots where it MOVES/faces (you aim by steering). Manual overrides:
	# the right aim-stick (touch) or a held mouse button (desktop) still let you aim freely.
	# When standing still, keep the last direction so we don't flip/spin.
	if _aim_stick_id != -1:
		return   # manual aim stick wins (aim_dir already set in _unhandled_input)
	if not bot_active and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		var m: Vector2 = (get_global_mouse_position() - global_position).normalized()
		if m != Vector2.ZERO:
			aim_dir = m
		return
	if bot_active:
		# The CI/headless bot keeps auto-aim so the smoke test reliably scores kills.
		var t: Node2D = _nearest_enemy()
		if t != null:
			aim_dir = (t.global_position - global_position).normalized()
	else:
		# Real players: aim follows the movement direction; keep last dir while standing.
		var mv: Vector2 = _move_input()
		if mv.length() > 0.1:
			aim_dir = mv.normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.DOWN

func _move_input() -> Vector2:
	if bot_active:
		return bot_move
	var kb: Vector2 = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if kb == Vector2.ZERO:
		if Input.is_key_pressed(KEY_A): kb.x -= 1.0
		if Input.is_key_pressed(KEY_D): kb.x += 1.0
		if Input.is_key_pressed(KEY_W): kb.y -= 1.0
		if Input.is_key_pressed(KEY_S): kb.y += 1.0
	if kb.length() > 0.1:
		return kb.normalized()
	if _stick_id != -1:
		return _stick_vec
	return Vector2.ZERO

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _stick_id == -1 and e.position.x < get_viewport_rect().size.x * 0.55:
			_stick_id = e.index
			_stick_origin = e.position
			_stick_vec = Vector2.ZERO
		elif e.pressed and _aim_stick_id == -1 and e.position.x >= get_viewport_rect().size.x * 0.55:
			_aim_stick_id = e.index
			_aim_stick_origin = e.position
		elif not e.pressed:
			if e.index == _stick_id:
				_stick_id = -1
				_stick_vec = Vector2.ZERO
			if e.index == _aim_stick_id:
				_aim_stick_id = -1
	elif e is InputEventScreenDrag:
		if e.index == _stick_id:
			_stick_vec = (e.position - _stick_origin).limit_length(80.0) / 80.0
		elif e.index == _aim_stick_id:
			var d: Vector2 = e.position - _aim_stick_origin
			if d.length() > 10.0:
				aim_dir = d.normalized()

var _nearest_frame: int = -1
var _nearest_cache: Node2D = null
func _nearest_enemy() -> Node2D:
	# cached per physics frame: called by every drone + aura + beam + aim in the same frame,
	# each of which used to re-scan (alloc) the whole enemy group.
	var pf: int = Engine.get_physics_frames()
	if pf == _nearest_frame:
		if _nearest_cache != null and is_instance_valid(_nearest_cache):
			return _nearest_cache
	_nearest_frame = pf
	var best: Node2D = null
	var bd: float = 1.0e12
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D:
			var d: float = global_position.distance_squared_to((e as Node2D).global_position)
			if d < bd:
				bd = d
				best = e
	_nearest_cache = best
	return best

func take_damage(amount: float) -> void:
	if _iframe > 0.0 or not GameState.alive:
		return
	if transformed:   # Overdrive = invincible; the hit just sparks off the aura
		if game != null and game.has_method("shield_ripple"):
			game.shield_ripple(global_position, 150.0, Color(1.0, 0.85, 0.4))
		return
	amount *= (1.0 - clampf(armor, 0.0, 0.75))   # Armure passive
	hp -= amount
	_iframe = 0.55
	Audio.sfx("hurt", 0.1)
	Events.player_damaged.emit(hp, max_hp)
	Events.screen_shake.emit(6.0)
	if game != null and game.has_method("shield_ripple"):
		game.shield_ripple(global_position, 130.0, Color(0.5, 0.8, 1.0))   # armour absorb flash
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("impact", global_position, 0.0, 0.7, Color(1.0, 0.7, 0.55))   # hit spark when the player is struck
	if hp <= 0.0:
		hp = 0.0
		GameState.alive = false
		mecha.play("die")
		Events.player_died.emit()
	elif velocity.length() < 0.1:
		# visible flinch on a non-lethal hit, but only when standing still so it never
		# stutters the walk/run cycle (the one-shot auto-returns to idle, _process reasserts
		# walk/run next frame if the player is moving).
		mecha.play("hit")

func heal(amount: float) -> void:
	if not GameState.alive:
		return
	hp = minf(max_hp, hp + amount)
	Events.player_damaged.emit(hp, max_hp)   # refresh the health bar

func grant_invuln(t: float) -> void:
	_iframe = maxf(_iframe, t)
