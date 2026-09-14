extends Node2D
class_name PropScatter
## Scatters the Gemini decor sprites across the arena, coherently per biome. Every prop is a
## StaticBody2D (blocks the player; enemies steer around it via Game.cover_list). Some crates are
## DESTRUCTIBLE and drop a skill bonus; the rest are indestructible obstacles.
##
## STREAMING: the arena is unbounded, so decor is generated in CHUNKS around the player and
## recycled behind them -> the whole map is decorated, not just the start area. Each chunk's
## layout is seeded from its coordinates, so leaving and coming back gives the same scenery.

var game: Node
var biome: String = "tech"

# Sized against the CAMERA, not guessed: the view is 1280x720 world units (zoom 1), so the
# player never sees past ~840 units even on an ultrawide. LOAD_R=1 guarantees a full CHUNK
# (1000 u) of decor in every direction — covers the view with margin. The old 900/LOAD_R=2 kept
# 50 props alive over 22x the visible area: 50 sprites+shadows+colliders+lights for nothing,
# and every one of 220 enemies rescanned all of them each physics frame.
const CHUNK: float = 1000.0        # world units per chunk
const LOAD_R: int = 1              # chunks kept alive around the player (3x3 -> 18 props)
const PER_CHUNK: int = 2           # props per chunk (density 2.0 per million units^2)
const MARGIN: float = 170.0        # inset from chunk edges >= max gap -> no cross-border overlap
const CLEAR_R: float = 340.0       # never drop a prop on top of the player

var _chunks: Dictionary = {}       # Vector2i -> Array[Prop]
var _last_cell: Vector2i = Vector2i(9999999, 9999999)

# DESTRUCTIBILITY RULE (patron):
#   * NATURE is scenery you cannot break — rock, tree, plant, roots, ice, lava, arch, mushroom,
#     crystals. It is there to shape the arena, not to farm. ("nature": true)
#   * EVERYTHING MAN-MADE / ROBOT DEBRIS breaks — easily, but not for free (HP band below) — and
#     leaves a drop (see DROPS): xp, scrap, health, overdrive charge, a competence, or a laugh.
#   * The mecha CARCASS is the exception: it is not loot, it wakes a guardian (see "awaken").
# HP band: crates 38-50 | gear 70-90 | wrecks 110-140 | structures 180-220.
# key -> f(ile g<n>), hp, sz(on-screen height px), destruct, nature, skill(chance the crate is a
# gold competence cache), glow, boom(fuel barrel), shoot*(hostile turret), awaken(carcass)
const DECOR: Dictionary = {
	# --- fuel barrels: get close and they arm, then blow up (see BOOM_* in Prop) ---
	"baril":      {"f": "g20", "hp": 40.0,  "sz": 88.0,  "destruct": true,  "skill": 0.30, "boom": true, "glow": "orange"},
	"caisses":    {"f": "g21", "hp": 38.0,  "sz": 96.0,  "destruct": true,  "skill": 0.50},
	"generateur": {"f": "g22", "hp": 90.0,  "sz": 124.0, "destruct": true,  "glow": "cyan"},
	"antenne":    {"f": "g23", "hp": 70.0,  "sz": 132.0, "destruct": true},
	"conduit":    {"f": "g24", "hp": 70.0,  "sz": 112.0, "destruct": true,  "glow": "cyan"},
	"emetteur":   {"f": "g25", "hp": 75.0,  "sz": 118.0, "destruct": true,  "glow": "cyan"},
	"epave":      {"f": "g26", "hp": 130.0, "sz": 150.0, "destruct": true},
	# Leftover war machine: still online and hostile, and DESTRUCTIBLE so you can silence it.
	# Its cannon is BAKED into the 3/4 art and cannot rotate (rotating a 3/4 head in 2D would
	# tip it onto its back). So it behaves like a fixed emplacement gun: it only fires ALONG its
	# real barrel axis, and only when you walk into that arc — the shot always matches the art.
	#   aim  = barrel axis in the art, degrees (measured off the sprite: down-left)
	#   arc  = half-angle of the firing cone
	#   muzzle = barrel tip, local px at the texture's native size (centered origin)
	"tourelle":   {"f": "g27", "hp": 140.0, "sz": 130.0, "destruct": true, "glow": "orange",
	               "shoot": 470.0, "shoot_cd": 1.7, "shoot_dmg": 8.0,
	               "aim": 140.0, "arc": 30.0, "muzzle": [-162.5, 117.0]},
	"container":  {"f": "g28", "hp": 45.0,  "sz": 140.0, "destruct": true,  "skill": 0.55},
	# --- NATURE: indestructible scenery ---
	"rocher":     {"f": "g29", "hp": 170.0, "sz": 120.0, "nature": true},
	"cristaux":   {"f": "g30", "hp": 48.0,  "sz": 110.0, "nature": true, "glow": "cyan"},
	"arbre":      {"f": "g31", "hp": 70.0,  "sz": 142.0, "nature": true},
	"plante":     {"f": "g32", "hp": 40.0,  "sz": 100.0, "nature": true, "glow": "green"},
	"glace":      {"f": "g33", "hp": 58.0,  "sz": 122.0, "nature": true},
	"arche":      {"f": "g34", "hp": 190.0, "sz": 152.0, "nature": true},
	"lave":       {"f": "g35", "hp": 150.0, "sz": 112.0, "nature": true, "glow": "orange"},
	"racines":    {"f": "g36", "hp": 95.0,  "sz": 132.0, "nature": true, "glow": "green"},
	# --- ruined-city map (parked, kept coherent) ---
	"immeuble":   {"f": "g37",  "hp": 220.0, "sz": 224.0, "destruct": true, "glow": "cyan"},
	"immeuble2":  {"f": "g37b", "hp": 220.0, "sz": 212.0, "destruct": true},
	"vaisseau":   {"f": "g39",  "hp": 180.0, "sz": 202.0, "destruct": true},
	"vaisseau2":  {"f": "g39b", "hp": 180.0, "sz": 196.0, "destruct": true},
	"voiture":    {"f": "g40",  "hp": 55.0,  "sz": 120.0, "destruct": true, "skill": 0.30, "boom": true},
	"gravats":    {"f": "g41",  "hp": 40.0,  "sz": 102.0, "destruct": true},
	"gravats2":   {"f": "g41b", "hp": 45.0,  "sz": 110.0, "destruct": true},
	"pylone":     {"f": "g42",  "hp": 85.0,  "sz": 150.0, "destruct": true},
	"panneau":    {"f": "g43",  "hp": 70.0,  "sz": 150.0, "destruct": true, "glow": "cyan"},
	"barricade":  {"f": "g44",  "hp": 50.0,  "sz": 130.0, "destruct": true, "skill": 0.40},
	# robot carcass: NOT loot and not something you shoot — walk near it and the guardian lying
	# dormant in the wreck stands up (proximity trigger, see Prop._process / Game.awaken_enemy)
	"carcasse":   {"f": "g45",  "hp": 300.0, "sz": 172.0, "awaken": "sentinelle"},
	# --- biome enrichers ---
	"lave_geyser":{"f": "g47",  "hp": 9999.0,"sz": 132.0, "nature": true, "glow": "orange"},
	"champignon": {"f": "g48",  "hp": 40.0,  "sz": 122.0, "nature": true, "glow": "cyan"},
	"campement":  {"f": "g49",  "hp": 50.0,  "sz": 122.0, "destruct": true},
	"epave_gel":  {"f": "g50",  "hp": 110.0, "sz": 132.0, "destruct": true},
	"serveurs":   {"f": "g51",  "hp": 80.0,  "sz": 122.0, "destruct": true, "glow": "cyan"},
	"capsule":    {"f": "g52",  "hp": 75.0,  "sz": 116.0, "destruct": true, "glow": "cyan"},
}

# What a smashed man-made prop leaves. A gold-glow crate ("skill" pre-rolled at spawn) always
# gives a competence — that promise stays readable. Everything else rolls here.
const DROPS: Array = [
	["xp", 34], ["scrap", 28], ["heal", 16], ["od", 14], ["emoji", 8],
]
# BIOME COHERENCE — every NATURE prop belongs ONLY to its own map: no rocks on the ice sheet,
# no trees in the desert, no ice in the spaceship. The ONLY props allowed everywhere are the
# DESTROYED ROBOTS (epave/carcasse — this is a robot war, wreckage is everywhere) and the BONUS
# crates (caisses/baril/container), which are man-made and carry the competences.
#   rocher -> earth/desert/volcanic | arbre -> earth/jungle/swamp | plante+racines+champignon ->
#   jungle/swamp | glace+epave_gel -> ice | lave+lave_geyser -> volcanic | arche+campement ->
#   desert | generateur/conduit/emetteur/antenne/tourelle/serveurs/capsule -> tech+spaceship
const BIOME_DECOR: Dictionary = {
	"earth":     ["rocher", "arbre", "rocher", "arbre", "epave", "caisses", "baril", "carcasse"],
	"volcanic":  ["lave", "lave", "lave_geyser", "rocher", "epave", "caisses", "baril", "carcasse"],
	"spaceship": ["generateur", "conduit", "emetteur", "tourelle", "antenne", "serveurs", "capsule", "cristaux", "container", "caisses", "baril", "carcasse"],
	"tech":      ["generateur", "conduit", "antenne", "tourelle", "serveurs", "cristaux", "container", "caisses", "baril", "carcasse"],
	"desert":    ["arche", "rocher", "arche", "campement", "epave", "caisses", "baril", "carcasse"],
	"ice":       ["glace", "glace", "cristaux", "epave_gel", "epave", "caisses", "baril", "carcasse"],
	"jungle":    ["plante", "racines", "arbre", "plante", "champignon", "epave", "caisses", "carcasse"],
	"swamp":     ["racines", "plante", "arbre", "racines", "champignon", "epave", "caisses", "carcasse"],
	"ruines":    ["immeuble", "immeuble2", "vaisseau", "vaisseau2", "voiture", "gravats", "gravats2",
	              "pylone", "panneau", "barricade", "carcasse", "gravats"],
}

## Kept for the old call site: seeds the chunks around the player straight away. The `count`
## argument is now ignored — density comes from PER_CHUNK and coverage is endless.
func populate(_count: int = 28) -> void:
	_refresh(_cell_of(_player_pos()))

var _player: Node2D = null
func _player_pos() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		return _player.global_position
	return Vector2.ZERO   # built before the player exists -> seed around the spawn

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK)), int(floor(p.y / CHUNK)))

func _process(_delta: float) -> void:
	# stream: only re-evaluate when the player crosses into a new chunk
	var cell: Vector2i = _cell_of(_player_pos())
	if cell != _last_cell:
		_refresh(cell)

func _refresh(cell: Vector2i) -> void:
	_last_cell = cell
	for dy in range(-LOAD_R, LOAD_R + 1):
		for dx in range(-LOAD_R, LOAD_R + 1):
			var c: Vector2i = cell + Vector2i(dx, dy)
			if not _chunks.has(c):
				_load_chunk(c)
	for c in _chunks.keys():
		if absi(c.x - cell.x) > LOAD_R or absi(c.y - cell.y) > LOAD_R:
			_unload_chunk(c)

func _load_chunk(c: Vector2i) -> void:
	var kinds: Array = BIOME_DECOR.get(biome, BIOME_DECOR["tech"])
	# deterministic per chunk (and per biome) -> revisiting a zone shows the same scenery
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [biome, c.x, c.y])
	var origin: Vector2 = Vector2(float(c.x) * CHUNK, float(c.y) * CHUNK)
	var lo: float = MARGIN
	var hi: float = CHUNK - MARGIN
	var ppos: Vector2 = _player_pos()
	var made: Array = []
	var placed: Array = []               # [{pos, gap}] — gap scales with prop size
	var tries: int = 0
	while placed.size() < PER_CHUNK and tries < PER_CHUNK * 8:
		tries += 1
		var pos: Vector2 = origin + Vector2(rng.randf_range(lo, hi), rng.randf_range(lo, hi))
		if pos.distance_to(ppos) < CLEAR_R:
			continue                     # never spawn a prop on the player
		var kind: String = String(kinds[rng.randi() % kinds.size()])
		# footprint radius: big ruins props (immeuble/vaisseau) need far more room so their
		# enemy-repulsion bubbles never overlap (which would jitter/bottleneck the swarm).
		var gap: float = 55.0 + float((DECOR.get(kind, {}) as Dictionary).get("sz", 110.0)) * 0.45
		var ok: bool = true
		for e in placed:
			if pos.distance_to(e["pos"]) < gap + float(e["gap"]):
				ok = false; break
		if not ok:
			continue
		placed.append({"pos": pos, "gap": gap})
		made.append(_place(kind, pos, rng))
	_chunks[c] = made

func _unload_chunk(c: Vector2i) -> void:
	for p in _chunks[c]:
		if is_instance_valid(p):
			(p as Node).queue_free()     # Prop._exit_tree pulls it out of cover_list
	_chunks.erase(c)

func _place(kind: String, pos: Vector2, rng: RandomNumberGenerator) -> Prop:
	var prop: Prop = Prop.new()
	prop.game = game
	prop.kind = kind
	prop.def = DECOR.get(kind, {})
	prop.position = pos
	prop.rand_scale = rng.randf_range(0.86, 1.16)
	prop.skill_roll = rng.randf()
	prop.flip = rng.randf() < 0.5      # mirrored turrets cover the opposite arc (seeded -> stable)
	add_child(prop)
	return prop

class Prop extends StaticBody2D:
	var game: Node
	var kind: String
	var def: Dictionary
	var hp: float
	var block_r: float = 40.0        # radius enemies steer around (read by Enemy)
	var rand_scale: float = 1.0      # from the chunk's seeded RNG (stable across reloads)
	var skill_roll: float = 1.0      # ditto
	var _sprite: Sprite2D
	var _skill: bool = false
	var _awaken: String = ""         # non-empty on a robot carcass: the foe it frees on approach
	var _awoken: bool = false
	var _plr: Node2D = null
	const AWAKEN_R: float = 230.0    # walk this close to the wreck and it stands up
	# hostile turret: still-online war machine that shoots the player
	var _shoot_r: float = 0.0
	var _shoot_cd: float = 1.7
	var _shoot_dmg: float = 8.0
	var _shoot_t: float = 0.0
	var _cannon: Vector2 = Vector2.RIGHT   # world direction the baked barrel actually points
	var _arc: float = 0.52                 # half-angle of the firing cone (rad)
	var _muzzle: Vector2 = Vector2.ZERO    # barrel tip, local px (already scaled)
	var flip: bool = false                 # mirrored copy -> cannon points down-RIGHT instead
	# fuel barrel: arms when you come near, then blows. 4s is enough to walk clear on purpose —
	# so it's a TOOL (lead the horde over it) as much as a hazard.
	var _boom: bool = false
	var _armed: float = -1.0         # >=0 -> counting down
	const BOOM_ARM_R: float = 190.0
	const BOOM_FUSE: float = 4.0
	const BOOM_R: float = 250.0
	const BOOM_DMG: float = 68.0

	func _ready() -> void:
		hp = float(def.get("hp", 60.0))
		_awaken = String(def.get("awaken", ""))
		_boom = bool(def.get("boom", false))
		_shoot_r = float(def.get("shoot", 0.0))
		_shoot_cd = float(def.get("shoot_cd", 1.7))
		_shoot_dmg = float(def.get("shoot_dmg", 8.0))
		_shoot_t = randf() * _shoot_cd     # desync turrets so they never volley in unison
		_arc = deg_to_rad(float(def.get("arc", 30.0)))
		# only carcasses (proximity), turrets (firing) and barrels (fuse) need a per-frame tick
		set_process(_awaken != "" or _shoot_r > 0.0 or _boom)
		var tex: Texture2D = load("res://assets/decor/%s.png" % String(def.get("f", "g20")))
		var th: float = maxf(1.0, float(tex.get_height()))
		var sc: float = rand_scale * (float(def.get("sz", 110.0)) / th)
		var spanx: float = float(tex.get_width()) * sc
		var spany: float = th * sc

		# ground contact shadow -> the prop sits in the world instead of floating
		var shadow: Sprite2D = Sprite2D.new()
		shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.position = Vector2(0.0, spany * 0.36)
		shadow.scale = Vector2(spanx / 64.0 * 0.66, spany / 64.0 * 0.20)
		shadow.z_index = -2
		add_child(shadow)

		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.scale = Vector2.ONE * sc
		add_child(_sprite)

		# Fixed emplacement gun: derive the FIRING AXIS from the art itself so the bolt always
		# leaves the barrel we drew, never the opposite side. Mirroring the sprite mirrors both
		# the axis and the muzzle, which buys a second orientation for free.
		if _shoot_r > 0.0:
			_sprite.flip_h = flip
			var a: float = deg_to_rad(float(def.get("aim", 0.0)))
			_cannon = Vector2.RIGHT.rotated(a)
			var m: Array = def.get("muzzle", [0.0, 0.0])
			_muzzle = Vector2(float(m[0]), float(m[1])) * sc
			if flip:
				_cannon.x = -_cannon.x
				_muzzle.x = -_muzzle.x

		var glow: String = String(def.get("glow", ""))
		if glow != "":
			var gc: Color = Palette.CYAN
			if glow == "green": gc = Color(0.4, 1.0, 0.5)
			elif glow == "orange": gc = Color(1.0, 0.55, 0.2)
			var l: PointLight2D = PointLight2D.new()
			l.texture = Tex.glow(gc, 128); l.color = gc; l.energy = 0.7
			l.texture_scale = maxf(spanx, spany) / 128.0 * 1.8
			add_child(l)

		# a destructible crate MAY hold a competence -> warm gold tell so the player breaks it
		if bool(def.get("destruct", false)) and skill_roll < float(def.get("skill", 0.0)):
			_skill = true
			var bl: PointLight2D = PointLight2D.new()
			bl.texture = Tex.glow(Palette.BONUS, 128); bl.color = Palette.BONUS; bl.energy = 1.2
			bl.texture_scale = maxf(spanx, spany) / 128.0 * 2.2
			add_child(bl)

		# collision: blocks the player (mask 8) and bullets; enemies avoid via Game.cover_list
		block_r = maxf(spanx, spany) * 0.30
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = block_r
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = shape
		col.position = Vector2(0.0, spany * 0.12)   # centre the collider on the base, not the top
		add_child(col)
		add_to_group("cover")
		collision_layer = 8
		collision_mask = 0
		if game != null and "cover_list" in game:
			game.cover_list.append(self)

	## Only runs on props that need it (see set_process in _ready): CARCASSES watch for the player
	## walking close (the wreck IS the sleeping robot and stands up), TURRETS shoot at the player.
	func _process(delta: float) -> void:
		if game == null or not is_instance_valid(game) or not GameState.alive:
			return
		if _plr == null or not is_instance_valid(_plr):
			_plr = get_tree().get_first_node_in_group("player") as Node2D
			if _plr == null:
				return
		var dist: float = global_position.distance_to(_plr.global_position)

		# --- hostile turret: fires ONLY along its baked barrel, and only into its own arc ---
		# The cannon is part of the 3/4 drawing and can't turn, so we never fake a tracking shot:
		# walk into the cone it actually covers and it opens up, straight down the tube.
		if _shoot_r > 0.0:
			_shoot_t -= delta
			if _shoot_t <= 0.0 and dist < _shoot_r:
				var to_plr: Vector2 = (_plr.global_position - global_position).normalized()
				if to_plr != Vector2.ZERO and absf(_cannon.angle_to(to_plr)) <= _arc:
					_shoot_t = _shoot_cd
					if game.has_method("spawn_enemy_bolt"):
						var mz: Vector2 = global_position + _muzzle
						game.spawn_enemy_bolt(mz, _cannon, _shoot_dmg, Color(1.0, 0.55, 0.25))
						if game.has_method("spawn_vfx"):
							# +90 deg: the muzzle sheet's flame is drawn pointing UP
							game.spawn_vfx("muzzle", mz, _cannon.angle() + PI * 0.5, 0.42,
								Color(1.0, 0.7, 0.4))

		# --- fuel barrel: arm on approach, blink faster as the fuse burns, then blow ---
		if _boom:
			if _armed < 0.0 and dist <= BOOM_ARM_R:
				_armed = BOOM_FUSE
				Audio.sfx("click", 0.1)
			if _armed >= 0.0:
				_armed -= delta
				# blink rate ramps from ~3Hz to ~14Hz as the fuse runs out -> readable urgency
				var urg: float = 1.0 - clampf(_armed / BOOM_FUSE, 0.0, 1.0)
				var blink: float = sin(Time.get_ticks_msec() * 0.001 * (18.0 + urg * 70.0))
				if _sprite != null:
					_sprite.modulate = Color(1.0, 1.0, 1.0).lerp(Color(3.0, 0.5, 0.35), 0.5 + 0.5 * blink)
				if _armed <= 0.0:
					_explode()
					return

		# --- carcass: the guardian inside wakes when you come close ---
		if _awaken != "" and not _awoken and dist <= AWAKEN_R:
			_awoken = true
			set_process(false)
			if game.has_method("awaken_enemy"):
				game.awaken_enemy(global_position, _awaken)
			call_deferred("queue_free")   # _exit_tree pulls us out of cover_list

	## Fuel barrel detonation: hurts EVERYTHING in BOOM_R, the player included — the 4s fuse is
	## the fair warning. Leading the horde over a barrel is the reward.
	func _explode() -> void:
		set_process(false)
		var pos: Vector2 = global_position
		if game != null and is_instance_valid(game):
			if game.has_method("death_fx"):
				game.death_fx(pos, 2, true)      # the big lightning burst is EARNED here (rare event)
			if game.has_method("spawn_vfx"):
				game.spawn_vfx("shockwave", pos, 0.0, 2.4, Color(1.0, 0.6, 0.25))
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node2D and is_instance_valid(e) and "alive" in e and e.alive:
					if pos.distance_to((e as Node2D).global_position) <= BOOM_R and e.has_method("take_damage"):
						e.take_damage(BOOM_DMG)
			if _plr != null and is_instance_valid(_plr) and pos.distance_to(_plr.global_position) <= BOOM_R:
				if _plr.has_method("take_damage"):
					_plr.take_damage(BOOM_DMG * 0.35)   # you were warned; painful, not lethal on its own
			_drop_loot(pos)
			if "cover_list" in game:
				game.cover_list.erase(self)
		call_deferred("queue_free")

	## Roll what a smashed prop leaves behind. Gold-glow crates always pay a competence.
	func _drop_loot(pos: Vector2) -> void:
		if game == null or not is_instance_valid(game):
			return
		if _skill and game.has_method("spawn_skill"):
			game.spawn_skill(pos)
			return
		var total: int = 0
		for d in DROPS:
			total += int(d[1])
		var r: int = randi() % maxi(1, total)
		for d in DROPS:
			r -= int(d[1])
			if r < 0:
				match String(d[0]):
					"xp":    if game.has_method("spawn_xp"): game.spawn_xp(pos, 1 + randi() % 2)
					"scrap": if game.has_method("spawn_scrap"): game.spawn_scrap(pos, 2 + randi() % 3)
					"heal":  if game.has_method("spawn_heal"): game.spawn_heal(pos)
					"od":    if game.has_method("spawn_od"): game.spawn_od(pos)
					"emoji": if game.has_method("spawn_emoji"): game.spawn_emoji(pos)
				return

	func _exit_tree() -> void:
		# streaming unload (or a break) must pull us out of cover_list, else it grows with
		# freed nodes that every enemy re-scans each frame
		if game != null and is_instance_valid(game) and "cover_list" in game:
			game.cover_list.erase(self)

	func take_damage(amount: float) -> void:
		if not bool(def.get("destruct", false)):
			return   # NATURE / carcass: indestructible (bullets already stopped by the collider)
		hp -= amount
		if hp <= 0.0:
			if _boom:
				_explode()      # shooting a fuel barrel sets it off — no fuse, you chose this
				return
			if game != null:
				if game.has_method("death_fx"):
					game.death_fx(global_position, 0, false)   # no lightning on a plain crate
				_drop_loot(global_position)
				if "cover_list" in game:
					game.cover_list.erase(self)
			call_deferred("queue_free")
		else:
			var tw: Tween = create_tween()
			tw.tween_property(_sprite, "modulate", Color(2.2, 2.2, 2.4), 0.05)
			tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
