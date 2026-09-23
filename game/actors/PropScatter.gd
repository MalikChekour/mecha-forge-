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
# props that threaten the player — capped at one per chunk so you meet them at a readable cadence
const HAZARDS: Array = ["generateur", "antenne", "conduit", "tourelle", "capaciteur", "baril", "emetteur"]

var _chunks: Dictionary = {}       # Vector2i -> Array[Prop]  (ALL chunks, placed once, never freed)
var _last_cell: Vector2i = Vector2i(9999999, 9999999)
var arena_half: float = 0.0        # set by Game: the bounded arena half-size. 0 = legacy streaming.
const COVER_R: int = 1             # chunks around the player kept in cover_list (enemy steering)

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
	"baril":      {"f": "g20", "hp": 40.0,  "sz": 80.0,  "destruct": true,  "skill": 0.30, "boom": true, "glow": "orange"},
	"caisses":    {"f": "g21", "hp": 38.0,  "sz": 92.0,  "destruct": true,  "skill": 0.50},
	# ARC PYLON: zaps the nearest enemies with lightning, and blows an EMP shockwave when destroyed.
	# Neutral-helpful — lead the horde past it and it thins them; break it for a burst. Tougher HP.
	"generateur": {"f": "g22", "hp": 170.0, "sz": 128.0, "destruct": true, "glow": "cyan",
	               "arc": true, "arc_cd": 1.5, "arc_dmg": 22.0, "arc_r": 300.0},
	# BEACON: spawns enemies until destroyed -> a PRIORITY target. It makes standing still costly
	# and pushing in to silence it rewarding (the aggression the game was missing). Tougher HP so
	# killing it is a real commitment, not a stray shot.
	"antenne":    {"f": "g23", "hp": 220.0, "sz": 176.0, "destruct": true, "glow": "orange",
	               "beacon": true, "beacon_cd": 3.4, "beacon_kind": "drone"},
	# SLOW FIELD: a persistent zone that bogs down the player AND the horde. A trap AND a tool —
	# lead the swarm into it and hold the edge. Destroy it (low HP) to clear the zone.
	"conduit":    {"f": "g24", "hp": 90.0,  "sz": 118.0, "destruct": true, "glow": "cyan",
	               "slow": true, "slow_r": 200.0, "slow_mult": 0.5},
	# EMETTEUR — enemy REPAIR node: heals nearby foes over time, so it's a priority target (green glow
	# to read as "healing", distinct from the magenta beam capaciteur that shares this sprite).
	"emetteur":   {"f": "g25", "hp": 90.0,  "sz": 118.0, "destruct": true,  "glow": "green",
	               "aura": "heal", "aura_r": 260.0, "aura_p1": 5.0},
	# EPAVE — a DORMANT war robot: walk close and it wakes into a live enemy (ambush). Shoot it first
	# to kill it in its sleep. (awaken hook already handled in _process.)
	"epave":      {"f": "g26", "hp": 130.0, "sz": 168.0, "destruct": true, "awaken": "brute"},
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
	# CAPACITEUR — the arena's neutral hazard. Sweeps a beam along a FIXED cardinal axis on a
	# FIXED 4.4s cycle: predictable on purpose, so it can be learned and then exploited. It hurts
	# the player AND the horde, and hurts the horde ~4x more — that ratio is what turns it from a
	# tax into a weapon (lead the swarm across the line, strafe out, let it clear the field).
	# It is the answer to "the mech can retreat forever for free": dodging it demands a LATERAL
	# move, which breaks a straight-line retreat and lets the horde close.
	# Destructible (220 HP) because every hazard must have counterplay.
	"capaciteur": {"f": "g25", "hp": 220.0, "sz": 188.0, "destruct": true, "glow": "magenta",
	               "beam": true, "beam_dmg": 45.0, "beam_dmg_enemy": 170.0},
	# --- NATURE: indestructible scenery ---
	"rocher":     {"f": "g29", "hp": 170.0, "sz": 120.0, "nature": true},
	# CRISTAUX — shatters into damaging shards on destruction (+ a little Overdrive). Break it in a crowd.
	"cristaux":   {"f": "g30", "hp": 70.0,  "sz": 100.0, "nature": true, "destruct": true, "glow": "cyan", "shatter": true},
	"arbre":      {"f": "g31", "hp": 70.0,  "sz": 178.0, "nature": true},
	# PLANTE — toxic SPORE cloud: poisons + slows the player AND the horde in a radius.
	"plante":     {"f": "g32", "hp": 55.0,  "sz": 78.0,  "nature": true, "destruct": true, "glow": "green",
	               "aura": "spore", "aura_r": 150.0, "aura_p1": 7.0, "aura_p2": 0.7},
	# GLACE — FROST field: strongly slows any enemy nearby (a tactical tool — herd the swarm into it).
	"glace":      {"f": "g33", "hp": 70.0,  "sz": 122.0, "nature": true, "destruct": true, "glow": "cyan",
	               "aura": "frost", "aura_r": 170.0, "aura_p1": 0.4},
	# arche (catalogue no 16) — GARDEE, rendue solide : collider elargi (block 0.46 au lieu de 0.30)
	# pour qu'on ne passe plus / ne tire plus a travers l'ouverture de l'arche.
	"arche":      {"f": "g34", "hp": 190.0, "sz": 196.0, "nature": true, "block": 0.46},
	# LAVE — a BURNING pool: continuous fire damage to the player AND enemies standing in it.
	"lave":       {"f": "g35", "hp": 150.0, "sz": 112.0, "nature": true, "destruct": true, "glow": "orange",
	               "aura": "burn", "aura_r": 130.0, "aura_p1": 10.0},
	# RACINES — a SNARE: whatever enters (player or foe) is dragged to a crawl (a trap zone).
	"racines":    {"f": "g36", "hp": 95.0,  "sz": 132.0, "nature": true, "destruct": true, "glow": "green",
	               "aura": "snare", "aura_r": 120.0, "aura_p1": 0.35},
	# Catalogue nos 19-35 supprimes (patron) : immeuble(s), vaisseau(x), voiture, gravats, pylone,
	# panneau, barricade, carcasse, lave_geyser, champignon, campement, epave_gel, serveurs, capsule.
}

# What a smashed man-made prop leaves. A gold-glow crate ("skill" pre-rolled at spawn) always
# gives a competence — that promise stays readable. Everything else rolls here.
const DROPS: Array = [
	["xp", 34], ["scrap", 28], ["heal", 16], ["od", 14], ["emoji", 8],
]

# ROCK FAMILY — mineral scenery that now (a) is DESTRUCTIBLE and (b) gets placed in aligned
# RIDGES (a row of rocks reads as a natural outcrop; a row of trees would look planted, so only
# rocks form ridges). A ridge is a barrier: it blocks the player AND funnels the horde, so a
# straight-line retreat runs into a wall you must round or grind through. Destructible "but not
# too easily" — the HP band below is a real detour cost, not a speed bump. No loot: these are
# TERRAIN, not a farm (that keeps the patron's old anti-farm rule while dropping the old
# indestructible rule).
const ROCK_FAMILY: Array = ["rocher", "arche", "lave", "glace", "cristaux"]
const ROCK_HP: Dictionary = {
	"rocher": 210.0, "arche": 210.0, "lave": 175.0, "glace": 120.0, "cristaux": 110.0,
}
const RIDGE_CHANCE: float = 0.5   # per chunk, when the biome has a rock-family prop

# BORDER — the ring of indestructible natural elements that walls the bounded arena. Big biome
# props, rendered oversized, packed shoulder-to-shoulder so the edge reads as a solid, impassable
# natural barrier (mountains / rock / ruins). Purely decorative: the hard clamp on the player and
# spawns is the real wall, so these carry NO collider and are NOT in cover_list (60 props scanned
# by 220 enemies every frame would be the opposite of an optimisation).
const BIOME_BORDER: Dictionary = {
	"earth":     ["rocher", "arbre"],
	"volcanic":  ["lave", "rocher"],
	"desert":    ["arche", "rocher"],
	"ice":       ["glace", "cristaux"],
	"jungle":    ["arbre", "racines"],
	"swamp":     ["arbre", "racines"],
	"tech":      ["rocher", "cristaux"],
	"spaceship": ["rocher", "cristaux"],
	"ruines":    ["rocher", "cristaux"],   # immeuble/gravats2 supprimes -> mur de roche generique
}
const BORDER_STEP: float = 300.0    # spacing along the wall (props are rendered wider -> they overlap)
const BORDER_SZ: float = 320.0      # oversized wall props: big enough to touch at BORDER_STEP

## Build the arena wall: a packed ring of oversized biome props along the square perimeter at
## ±half. Called from Game._scatter_decor, so it is rebuilt with the right material each biome.
func build_border(half: float) -> void:
	var kinds: Array = BIOME_BORDER.get(biome, ["rocher", "arbre"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("border:%s" % biome)
	var n_side: int = int((half * 2.0) / BORDER_STEP) + 1
	for side in 4:
		for i in n_side:
			var t: float = -half + float(i) * BORDER_STEP + rng.randf_range(-24.0, 24.0)
			var jit: float = rng.randf_range(-18.0, 18.0)   # slight inward wobble -> organic, not a fence
			var pos: Vector2
			match side:
				0: pos = Vector2(t, -half + jit)   # top
				1: pos = Vector2(t, half - jit)    # bottom
				2: pos = Vector2(-half + jit, t)   # left
				_: pos = Vector2(half - jit, t)    # right
			_place_border(String(kinds[rng.randi() % kinds.size()]), pos, rng.randf_range(0.92, 1.22),
				rng.randf() < 0.5)

## One wall prop: sprite + ground shadow, no collider, no logic. Rendered from the shared decor art.
func _place_border(kind: String, pos: Vector2, scl: float, flip: bool) -> void:
	var d: Dictionary = DECOR.get(kind, {})
	var tex: Texture2D = load("res://assets/decor/%s.png" % String(d.get("f", "g29")))
	if tex == null:
		return
	var th: float = maxf(1.0, float(tex.get_height()))
	var sc: float = scl * (BORDER_SZ / th)
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
	shadow.modulate = Color(0, 0, 0, 0.5)
	shadow.position = pos + Vector2(0.0, th * sc * 0.36)
	shadow.scale = Vector2(float(tex.get_width()) * sc / 64.0 * 0.66, th * sc / 64.0 * 0.20)
	shadow.z_index = -2
	add_child(shadow)
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2.ONE * sc
	s.flip_h = flip
	s.z_index = int(pos.y)   # y-sort against actors so the wall overlaps correctly
	add_child(s)
# BIOME COHERENCE — every NATURE prop belongs ONLY to its own map: no rocks on the ice sheet,
# no trees in the desert, no ice in the spaceship. The ONLY props allowed everywhere are the
# DESTROYED ROBOTS (epave/carcasse — this is a robot war, wreckage is everywhere) and the BONUS
# crates (caisses/baril/container), which are man-made and carry the competences.
#   rocher -> earth/desert/volcanic | arbre -> earth/jungle/swamp | plante+racines+champignon ->
#   jungle/swamp | glace+epave_gel -> ice | lave+lave_geyser -> volcanic | arche+campement ->
#   desert | generateur/conduit/emetteur/antenne/tourelle/serveurs/capsule -> tech+spaceship
# EVERY biome now carries active battlefield hazards (turret + beam cannon + a spawn/slow emplacement)
# on top of its native flora/terrain — it is a ROBOT WAR, war-machines and wreckage litter every zone.
# So no level is ever a passive stroll: cannons fire, beams sweep, nests spew, whatever the biome.
const BIOME_DECOR: Dictionary = {
	# EVERY biome carries the full trap set: canon (tourelle) + rayon (capaciteur) + pylône-arc
	# (generateur) + mine (baril), on top of its native flora/terrain. No map is ever short on traps.
	"earth":     ["rocher", "tourelle", "capaciteur", "generateur", "baril", "antenne", "arbre", "epave", "caisses"],
	"volcanic":  ["lave", "tourelle", "capaciteur", "generateur", "baril", "lave", "rocher", "epave", "caisses"],
	"spaceship": ["generateur", "conduit", "capaciteur", "tourelle", "antenne", "emetteur", "baril", "cristaux", "container", "caisses"],
	"tech":      ["generateur", "conduit", "antenne", "capaciteur", "tourelle", "emetteur", "baril", "cristaux", "container", "caisses"],
	"desert":    ["arche", "tourelle", "capaciteur", "generateur", "baril", "antenne", "rocher", "epave", "caisses"],
	"ice":       ["glace", "tourelle", "capaciteur", "generateur", "baril", "conduit", "cristaux", "epave", "caisses"],
	"jungle":    ["plante", "tourelle", "capaciteur", "generateur", "baril", "antenne", "racines", "arbre", "epave", "caisses"],
	"swamp":     ["racines", "tourelle", "capaciteur", "generateur", "baril", "conduit", "plante", "arbre", "epave", "caisses"],
	# ruines repeuple avec les decors SURVIVANTS (robot-war wreckage) apres suppression des nos 19-35
	"ruines":    ["epave", "rocher", "capaciteur", "tourelle", "epave", "caisses", "baril", "container", "cristaux"],
}

## Kept for the old call site: seeds the chunks around the player straight away. The `count`
## argument is now ignored — density comes from PER_CHUNK and coverage is endless.
## Bounded arena: place ALL decor ONCE and leave it — the map is finite now, so nothing streams in
## or out as you move (that pop-in was what read as "the decor isn't fixed"). Props exist for the
## whole run and block the player physically via the collision engine (free, broad-phase). Only the
## ENEMY-steering list (cover_list) is kept small — see _refresh_cover.
func populate(_count: int = 28) -> void:
	if arena_half > 0.0:
		var cr: int = int(ceil(arena_half / CHUNK))   # chunks out to the wall (border hides any spill)
		for cy in range(-cr, cr + 1):
			for cx in range(-cr, cr + 1):
				_load_chunk(Vector2i(cx, cy))
		_refresh_cover(_cell_of(_player_pos()))
	else:
		_refresh(_cell_of(_player_pos()))   # legacy infinite streaming (unused once Game sets bounds)

## cover_list drives enemy steering and is O(enemies x list) every frame, so it must stay small.
## With fixed decor we can't let every prop self-register (200+ props x 220 enemies would melt a
## phone), so cover_list holds only the props in the 3x3 chunks around the player — the only props
## any enemy is ever near, since enemies chase the player.
func _refresh_cover(cell: Vector2i) -> void:
	if game == null or not ("cover_list" in game):
		return
	game.cover_list.clear()
	for dy in range(-COVER_R, COVER_R + 1):
		for dx in range(-COVER_R, COVER_R + 1):
			var props: Variant = _chunks.get(cell + Vector2i(dx, dy))
			if props == null:
				continue
			for p in props:
				if is_instance_valid(p):
					game.cover_list.append(p)

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
	# decor is fixed (placed once); only the near-player cover set is refreshed, and only when the
	# player crosses into a new chunk.
	var cell: Vector2i = _cell_of(_player_pos())
	if cell != _last_cell:
		_last_cell = cell
		if arena_half > 0.0:
			_refresh_cover(cell)
		else:
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

## Props smashed THIS RUN, keyed by rounded world position (stable: positions come from the chunk's
## seeded RNG). Chunks stream in and out as you walk, and without this a destroyed prop came back
## on every revisit — a 2000-unit round trip regenerated the scenery, so a gold crate handed out a
## free, uncapped draft upgrade roughly every 15 seconds, forever.
var _destroyed: Dictionary = {}

## 🚨 TEMPORAIRE (banc du 23/09) : le decor destructible n'avait AUCUNE trace de banc, contrairement
## a Enemy._palier_max_run pour l'IQ. Impossible de confirmer en headless qu'un rocher a seulement
## ete detruit une fois. A retirer une fois le systeme rejoue en vrai (souris/clavier).
static var _detruits_bench: int = 0

func mark_destroyed(pos: Vector2) -> void:
	_destroyed[Vector2i(pos.round())] = true
	_detruits_bench += 1

## Props that actively threaten the player. They are GATED BY RUN TIME so the arena escalates:
## the map at minute 12 must not be the map at minute 2. That sameness is the real source of
## boredom — the run got harder, the terrain never did.
##   0-3 min  : none (the player is learning the loop)
##   3-8 min  : hazards appear at 55% of their weight
##   8+ min   : full weight, plus an extra prop per chunk
## First kind in the biome list that is not a hazard (used to cap one hazard per chunk).
func _nonhazard(kinds: Array) -> String:
	for k in kinds:
		if not HAZARDS.has(String(k)):
			return String(k)
	return "caisses"

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
	# LAYOUT: chunks vary between OPEN (few props -> the horde surrounds you) and CLUSTERED (a rock
	# outcrop / nest of structures = cover, but your shots get blocked too). Density is seeded and
	# capped at 3 so cover_list stays bounded. At most ONE hazard per chunk -> turrets/pylons come
	# at a readable cadence, never a wall of them.
	var dr: float = rng.randf()
	# No empty chunks any more (was 16% empty -> dead stretches you could run through unthreatened).
	# Denser average, same max of 3 so cover_list stays bounded (3x3 chunks -> <=27 props).
	var want: int = 1 if dr < 0.22 else (2 if dr < 0.60 else 3)
	var clustered: bool = want >= 2 and rng.randf() < 0.55
	var anchor: Vector2 = origin + Vector2(rng.randf_range(lo, hi), rng.randf_range(lo, hi))
	var haz_count: int = 0   # up to TWO hazards per chunk (was one) -> cannons come thick enough to matter
	while placed.size() < want and tries < want * 10:
		tries += 1
		var pos: Vector2
		if clustered:
			var ca: float = rng.randf() * TAU
			pos = anchor + Vector2(cos(ca), sin(ca)) * rng.randf_range(40.0, 210.0)
			pos.x = clampf(pos.x, origin.x + lo, origin.x + hi)
			pos.y = clampf(pos.y, origin.y + lo, origin.y + hi)
		else:
			pos = origin + Vector2(rng.randf_range(lo, hi), rng.randf_range(lo, hi))
		if pos.distance_to(ppos) < CLEAR_R:
			continue                     # never spawn a prop on the player (spawn is at origin)
		var kind: String = String(kinds[rng.randi() % kinds.size()])
		if HAZARDS.has(kind):            # cap hazards per chunk -> swap extras for a harmless prop
			if haz_count >= 2:
				kind = _nonhazard(kinds)
			else:
				haz_count += 1
		# footprint radius: big props need far more room so their enemy-repulsion bubbles never overlap.
		var gap: float = 55.0 + float((DECOR.get(kind, {}) as Dictionary).get("sz", 110.0)) * 0.45
		var ok: bool = true
		for e in placed:
			if pos.distance_to(e["pos"]) < gap + float(e["gap"]):
				ok = false; break
		if not ok:
			continue
		placed.append({"pos": pos, "gap": gap})
		# Draw the seeded variation ALWAYS, before deciding to skip: bailing out early would leave
		# the RNG stream shifted and every later prop in the chunk would move.
		var rs: float = rng.randf_range(0.86, 1.16)
		var sr: float = rng.randf()
		var fl: bool = rng.randf() < 0.5
		if _destroyed.has(Vector2i(pos.round())):
			continue                     # smashed earlier this run — the spot stays empty
		made.append(_place(kind, pos, rs, sr, fl))
	_chunks[c] = made

func _unload_chunk(c: Vector2i) -> void:
	for p in _chunks[c]:
		if is_instance_valid(p):
			(p as Node).queue_free()     # Prop._exit_tree pulls it out of cover_list
	_chunks.erase(c)

## Variation values are drawn by the caller so a skipped (already-destroyed) prop cannot desync
## the chunk's RNG stream.
func _place(kind: String, pos: Vector2, rand_scale: float, skill_roll: float, flip: bool) -> Prop:
	var prop: Prop = Prop.new()
	prop.game = game
	prop.kind = kind
	prop.def = DECOR.get(kind, {})
	prop.position = pos
	prop.rand_scale = rand_scale
	prop.skill_roll = skill_roll
	prop.flip = flip                   # mirrored turrets cover the opposite arc (seeded -> stable)
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
	# --- BEACON: emits enemies until destroyed (see the DECOR entry) ---
	var _beacon: bool = false
	var _beacon_cd: float = 3.5
	var _beacon_kind: String = "drone"
	var _beacon_t: float = 0.0
	var _beacon_pulse: Sprite2D = null
	const BEACON_R: float = 1100.0    # only active while the player is near enough to see/reach it
	# --- ARC PYLON: zaps nearest enemies with lightning, EMP burst on destruction ---
	var _pylon: bool = false
	var _pylon_cd: float = 1.5
	var _pylon_dmg: float = 22.0
	var _pylon_r: float = 300.0
	var _pylon_t: float = 0.0
	# --- SLOW FIELD: persistent zone that dampens player + enemy movement ---
	var _slow: bool = false
	var _slow_r: float = 200.0
	var _slow_mult: float = 0.5
	var _slow_ring: Sprite2D = null
	# --- FIELD AURA: lave(burn) / plante(spore) / glace(frost) / racines(snare) / emetteur(heal) ---
	var _aura: String = ""
	var _aura_r: float = 160.0
	var _aura_p1: float = 10.0   # dmg-or-heal per tick, or slow-mult, depending on the kind
	var _aura_p2: float = 0.7    # secondary (spore's slow-mult)
	var _aura_ring: Sprite2D = null
	var _aura_t: float = 0.0
	const AURA_TICK: float = 0.4
	var _shatter: bool = false   # crystal: burst damaging shards on destruction
	# --- CAPACITEUR: neutral sweeping beam (see the DECOR entry for the design intent) ---
	var _beam: bool = false
	var _beam_dir: Vector2 = Vector2.RIGHT   # ONE fixed cardinal, chosen at build from the seed
	var _beam_dmg: float = 45.0
	var _beam_dmg_enemy: float = 170.0
	var _beam_state: int = 0                 # 0 idle, 1 telegraph, 2 firing
	var _beam_t: float = 0.0
	var _beam_line: Line2D = null    # mid layer: the coloured beam body
	var _beam_glow: Line2D = null    # wide additive halo under the body
	var _beam_core: Line2D = null    # white-hot thin core over the body
	var _beam_flash: Sprite2D = null # muzzle bloom at the emitter while firing
	const BEAM_IDLE: float = 4.4             # fixed cadence — learnable, never random
	const BEAM_TELL: float = 1.25            # well above mobile reaction time (~250 ms)
	const BEAM_FIRE: float = 0.4
	const BEAM_LEN: float = 2400.0           # crosses the screen on any aspect
	const BEAM_HALF_W: float = 26.0          # damage half-width (visual is a touch thinner)
	const BEAM_COL: Color = Color(1.0, 0.25, 0.85)   # magenta: unused by player shots (cyan/violet)
	                                                  # and by enemy bolts (orange/red)

	func _ready() -> void:
		hp = float(def.get("hp", 60.0))
		_awaken = String(def.get("awaken", ""))
		_boom = bool(def.get("boom", false))
		_shoot_r = float(def.get("shoot", 0.0))
		_shoot_cd = float(def.get("shoot_cd", 1.7))
		_shoot_dmg = float(def.get("shoot_dmg", 8.0))
		_shoot_t = randf() * _shoot_cd     # desync turrets so they never volley in unison
		_arc = deg_to_rad(float(def.get("arc", 30.0)))
		_beacon = bool(def.get("beacon", false))
		if _beacon:
			_beacon_cd = float(def.get("beacon_cd", 3.5))
			_beacon_kind = String(def.get("beacon_kind", "drone"))
			_beacon_t = randf() * _beacon_cd   # desync so beacons don't all emit on the same frame
			# a slow red pulse ring reads as "this is producing enemies — take it out"
			_beacon_pulse = _glow_sprite(Color(1.0, 0.3, 0.2), float(def.get("sz", 120.0)) * 1.6, 0.0)
			add_child(_beacon_pulse)
		_beam = bool(def.get("beam", false))
		if _beam:
			_beam_dmg = float(def.get("beam_dmg", 45.0))
			_beam_dmg_enemy = float(def.get("beam_dmg_enemy", 170.0))
			# axis from the chunk seed (skill_roll) -> the same emitter always sweeps the same way,
			# so a returning player can rely on what they learned
			_beam_dir = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][int(skill_roll * 4.0) % 4]
			_beam_t = randf() * BEAM_IDLE      # desync so emitters never fire in unison
			_beam_glow = _mk_beam(29)          # wide additive halo (under)
			_beam_line = _mk_beam(30)          # coloured beam body
			_beam_core = _mk_beam(31)          # white-hot core (over)
			_beam_flash = Sprite2D.new()       # emitter muzzle bloom while firing
			_beam_flash.texture = Tex.glow(BEAM_COL, 128)
			_beam_flash.material = Tex.add_mat()
			_beam_flash.top_level = true
			_beam_flash.z_index = 31
			_beam_flash.visible = false
			add_child(_beam_flash)
		_pylon = bool(def.get("arc", false))
		if _pylon:
			_pylon_cd = float(def.get("arc_cd", 1.5)); _pylon_dmg = float(def.get("arc_dmg", 22.0))
			_pylon_r = float(def.get("arc_r", 300.0)); _pylon_t = randf() * _pylon_cd
		_slow = bool(def.get("slow", false))
		if _slow:
			_slow_r = float(def.get("slow_r", 200.0)); _slow_mult = float(def.get("slow_mult", 0.5))
			# persistent field ring so the zone READS on the ground (violet = distinct from magenta beam)
			_slow_ring = _glow_sprite(Color(0.55, 0.4, 1.0), _slow_r * 2.0, 0.16)
			add_child(_slow_ring)
		_aura = String(def.get("aura", ""))
		if _aura != "":
			_aura_r = float(def.get("aura_r", 160.0))
			_aura_p1 = float(def.get("aura_p1", 10.0))
			_aura_p2 = float(def.get("aura_p2", 0.7))
			var arc_col: Color = {"burn": Color(1.0, 0.4, 0.12), "spore": Color(0.5, 0.95, 0.25),
				"frost": Color(0.55, 0.85, 1.0), "snare": Color(0.5, 0.9, 0.35),
				"heal": Color(0.35, 1.0, 0.5)}.get(_aura, Color.WHITE)
			_aura_ring = _glow_sprite(arc_col, _aura_r * 2.0, 0.18)
			add_child(_aura_ring)
		_shatter = bool(def.get("shatter", false))
		# props that need a per-frame tick
		set_process(_awaken != "" or _shoot_r > 0.0 or _boom or _beam or _beacon or _pylon or _slow or _aura != "")
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

		# Prop glow — was a persistent PointLight2D per glowing prop. With chunk streaming that's
		# a stack of always-on dynamic lights (each a canvas re-render) = a constant mobile tax.
		# An ADDITIVE glow sprite gives the same look for ~free.
		var glow: String = String(def.get("glow", ""))
		if glow != "":
			var gc: Color = Palette.CYAN
			if glow == "green": gc = Color(0.4, 1.0, 0.5)
			elif glow == "orange": gc = Color(1.0, 0.55, 0.2)
			add_child(_glow_sprite(gc, maxf(spanx, spany) * 0.9, 0.5))

		# a destructible crate MAY hold a competence -> warm gold tell so the player breaks it
		if bool(def.get("destruct", false)) and skill_roll < float(def.get("skill", 0.0)):
			_skill = true
			add_child(_glow_sprite(Palette.BONUS, maxf(spanx, spany) * 1.05, 0.7))

		# collision: blocks the player (mask 8) and bullets; enemies avoid via Game.cover_list.
		# "block" overrides the footprint fraction — arche uses a wider one so it reads as SOLID
		# (no passing or shooting through the archway opening).
		block_r = maxf(spanx, spany) * float(def.get("block", 0.30))
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = block_r
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = shape
		col.position = Vector2(0.0, spany * 0.12)   # centre the collider on the base, not the top
		add_child(col)
		add_to_group("cover")
		collision_layer = 8   # blocks the player physically (broad-phase, free) regardless of cover_list
		collision_mask = 0
		# NOTE: props do NOT self-register in cover_list any more. With fixed decor across a big
		# arena that would put 200+ props in the per-frame enemy-steering scan. PropScatter keeps
		# cover_list to the props near the player instead (see _refresh_cover).

	## Cheap additive glow used instead of a real Light2D (see call sites): same soft halo look,
	## none of the per-frame dynamic-light re-render cost that was hurting mobile.
	func _glow_sprite(c: Color, diameter: float, alpha: float) -> Sprite2D:
		var s: Sprite2D = Sprite2D.new()
		s.texture = Tex.glow(c, 128)
		var m: CanvasItemMaterial = CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
		s.scale = Vector2.ONE * (diameter / 128.0)
		s.modulate = Color(c.r, c.g, c.b, alpha)
		s.z_index = -1
		return s

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
						game.spawn_enemy_bolt(mz, _cannon, _shoot_dmg, Color(1.0, 0.55, 0.25), 1.5)   # heavy emplacement bolt
						if game.has_method("spawn_vfx"):
							# +90 deg: the muzzle sheet's flame is drawn pointing UP
							game.spawn_vfx("muzzle", mz, _cannon.angle() + PI * 0.5, 0.42,
								Color(1.0, 0.7, 0.4))

		# --- beacon: emit an enemy on a fixed cadence while the player is in range ---
		if _beacon:
			if _beacon_pulse != null:
				# breathe the warning ring so it reads as an active threat, not scenery
				var b: float = 0.28 + 0.22 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004))
				_beacon_pulse.modulate.a = b if dist < BEACON_R else 0.12
			if dist < BEACON_R:
				_beacon_t -= delta
				if _beacon_t <= 0.0:
					_beacon_t = _beacon_cd
					if game.has_method("beacon_spawn"):
						game.beacon_spawn(global_position, _beacon_kind)

		# --- arc pylon: zap the nearest enemy periodically while the player is near ---
		if _pylon and dist < 1300.0:
			_pylon_t -= delta
			if _pylon_t <= 0.0:
				_pylon_t = _pylon_cd
				_zap_nearest()

		# --- slow field: dampen the player and any enemy inside the ring, every frame ---
		if _slow:
			if _slow_ring != null:
				_slow_ring.modulate.a = 0.12 + 0.06 * sin(Time.get_ticks_msec() * 0.003)
			if dist < _slow_r and "field_slow" in _plr:
				_plr.field_slow = minf(_plr.field_slow, _slow_mult)
			if dist < 1300.0:   # only bother with enemies when the player is near this field
				var r2s: float = _slow_r * _slow_r
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and "field_slow" in e:
						if global_position.distance_squared_to((e as Node2D).global_position) <= r2s:
							e.field_slow = minf(e.field_slow, _slow_mult)

		# --- capaciteur: idle -> telegraph -> fire, on a fixed loop ---
		# Only while the player is near enough to see it: with fixed decor there are capacitors all
		# over the arena, and a far one firing would waste work and play off-screen sounds.
		if _beam and dist < 1500.0:
			_tick_beam(delta)

		# --- field aura: lave burns / plante poisons / glace frosts / racines snares / emetteur heals ---
		if _aura != "" and dist < 1400.0:
			_tick_aura(delta, dist)

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

	## Arc pylon: forks a lightning bolt to the nearest enemy in range and damages it. Reads as a
	## friendly-ish hazard — lead the horde past and it chips them.
	func _zap_nearest() -> void:
		var best: Node2D = null
		var bd: float = _pylon_r * _pylon_r
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and is_instance_valid(e) and "alive" in e and e.alive:
				var d: float = global_position.distance_squared_to((e as Node2D).global_position)
				if d < bd:
					bd = d; best = e
		if best == null:
			return
		if best.has_method("take_damage"):
			best.take_damage(_pylon_dmg)
		Audio.sfx("hit", 0.15)
		if game != null and game.has_method("spawn_arc"):
			game.spawn_arc(global_position + Vector2(0, -float(def.get("sz", 128.0)) * 0.35),
				best.global_position, Color(1.0, 0.95, 0.4))

	## EMP burst on destruction: damages + knocks back every enemy nearby. The reward for breaking it.
	func _emp_burst() -> void:
		var pos: Vector2 = global_position
		if game != null and game.has_method("spawn_vfx"):
			game.spawn_vfx("shockwave", pos, 0.0, 2.0, Color(1.0, 0.95, 0.4))
		Events.screen_shake.emit(6.0)
		var r2: float = 320.0 * 320.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and is_instance_valid(e) and "alive" in e and e.alive:
				var to: Vector2 = (e as Node2D).global_position - pos
				if to.length_squared() <= r2 and e.has_method("take_damage"):
					e.take_damage(_pylon_dmg * 1.6)
					if "velocity" in e:
						e.velocity += to.normalized() * 260.0   # knockback

	## Beam cycle. The telegraph is a thin bright line along the exact path the beam will take —
	## no guesswork, no tracking: the terrain does not chase the player, it simply exists, and a
	## hazard that aims at you reads as the game cheating.
	## Field-aura tick. burn/spore deal damage (every AURA_TICK); spore/frost/snare apply field_slow
	## every frame (it recovers each frame, so it must be re-applied); heal tops up nearby foes.
	func _tick_aura(delta: float, dist: float) -> void:
		if _aura_ring != null:
			_aura_ring.modulate.a = 0.12 + 0.07 * sin(Time.get_ticks_msec() * 0.004)
		_aura_t -= delta
		var tick: bool = _aura_t <= 0.0
		if tick:
			_aura_t = AURA_TICK
		var r2: float = _aura_r * _aura_r
		var plr_in: bool = dist < _aura_r
		match _aura:
			"burn":
				if plr_in and tick and _plr.has_method("take_damage"):
					_plr.take_damage(_aura_p1)
				if tick:
					for e in get_tree().get_nodes_in_group("enemies"):
						if e is Node2D and global_position.distance_squared_to((e as Node2D).global_position) <= r2 and e.has_method("take_damage"):
							e.take_damage(_aura_p1 * 1.4)
			"spore":
				if plr_in:
					if "field_slow" in _plr:
						_plr.field_slow = minf(_plr.field_slow, _aura_p2)
					if tick and _plr.has_method("take_damage"):
						_plr.take_damage(_aura_p1)
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
						if "field_slow" in e:
							e.field_slow = minf(e.field_slow, _aura_p2)
						if tick and e.has_method("take_damage"):
							e.take_damage(_aura_p1)
			"frost":   # enemies only — a tactical slow you herd the horde into
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and "field_slow" in e and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
						e.field_slow = minf(e.field_slow, _aura_p1)
			"snare":   # traps player AND foes
				if plr_in and "field_slow" in _plr:
					_plr.field_slow = minf(_plr.field_slow, _aura_p1)
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Node2D and "field_slow" in e and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
						e.field_slow = minf(e.field_slow, _aura_p1)
			"heal":    # repair node: tops up nearby foes -> a priority target
				if tick:
					for e in get_tree().get_nodes_in_group("enemies"):
						if e is Node2D and "hp" in e and "hp_max" in e and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
							e.hp = minf(float(e.hp_max), float(e.hp) + _aura_p1)

	## Crystal shatter on destruction: a damaging shard ring + a bright shockwave + a little Overdrive.
	func _shatter_burst() -> void:
		if game == null:
			return
		var r: float = 240.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and global_position.distance_squared_to((e as Node2D).global_position) <= r * r and e.has_method("take_damage"):
				e.take_damage(60.0)
		if game.has_method("aura_discharge_fx"):
			game.aura_discharge_fx(global_position, r, Color(0.5, 0.95, 1.0))
		GameState.add_overdrive(0.10)
		Audio.sfx("explosion", 0.1)

	## One additive round-capped beam layer at z-order `z` (glow/body/core share this).
	func _mk_beam(z: int) -> Line2D:
		var ln: Line2D = Line2D.new()
		ln.top_level = true                    # world space: not scaled by the prop
		ln.material = Tex.add_mat()
		ln.z_index = z
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		ln.visible = false
		add_child(ln)
		return ln

	## Layered energy beam: wide halo + coloured body + white-hot core + a muzzle bloom, with a
	## readable charge (thin bright warning line that thickens) then a fat pulsing discharge.
	func _tick_beam(delta: float) -> void:
		_beam_t -= delta
		var a: Vector2 = global_position
		var b: Vector2 = a + _beam_dir * BEAM_LEN
		var pts: PackedVector2Array = PackedVector2Array([a, b])
		match _beam_state:
			0:
				if _beam_t <= 0.0:
					_beam_state = 1
					_beam_t = BEAM_TELL
					for ln in [_beam_glow, _beam_line, _beam_core]:
						ln.points = pts; ln.visible = true
					Audio.sfx("w_railgun", 0.05)      # rising "capacitor charging" whine
			1:
				# thin bright warning line that thickens + brightens as the shot nears (readable)
				var k: float = 1.0 - clampf(_beam_t / BEAM_TELL, 0.0, 1.0)
				var puls: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
				_beam_core.width = 1.5 + k * 3.0
				_beam_core.default_color = Color(1, 1, 1, 0.35 + k * 0.5)
				_beam_line.width = 2.0 + k * 8.0
				_beam_line.default_color = Color(BEAM_COL.r, BEAM_COL.g, BEAM_COL.b, 0.22 + k * 0.4)
				_beam_glow.width = 6.0 + k * 26.0
				_beam_glow.default_color = Color(BEAM_COL.r, BEAM_COL.g, BEAM_COL.b, (0.10 + k * 0.20) * (0.6 + 0.4 * puls))
				if _beam_t <= 0.0:
					_beam_state = 2
					_beam_t = BEAM_FIRE
					_beam_flash.position = a
					_beam_flash.visible = true
					_fire_beam(a, b)
					Audio.sfx("w_plasma", 0.04)       # heavy discharge
			2:
				# fat, white-hot, flickering discharge that fades over BEAM_FIRE
				var f: float = clampf(_beam_t / BEAM_FIRE, 0.0, 1.0)
				var flick: float = 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.09)
				_beam_core.width = BEAM_HALF_W * 0.6 * flick
				_beam_core.default_color = Color(1, 1, 1, f)
				_beam_line.width = BEAM_HALF_W * 1.7 * flick
				_beam_line.default_color = Color(1.0, 0.6, 1.0, f * 0.95)
				_beam_glow.width = BEAM_HALF_W * 4.4 * flick
				_beam_glow.default_color = Color(BEAM_COL.r, BEAM_COL.g, BEAM_COL.b, f * 0.5)
				_beam_flash.scale = Vector2.ONE * (BEAM_HALF_W * 4.5 / 128.0) * (0.8 + 0.4 * flick)
				_beam_flash.modulate = Color(1.0, 0.7, 1.0, f)
				if _beam_t <= 0.0:
					_beam_state = 0
					_beam_t = BEAM_IDLE
					for ln in [_beam_glow, _beam_line, _beam_core]:
						ln.visible = false
					_beam_flash.visible = false

	## Damage is applied ONCE at discharge, not per frame: a per-frame beam would delete the player
	## instantly and read as unfair. Enemies take ~4x the player's hit, which is what makes leading
	## the horde into the line the strongest play available.
	func _fire_beam(a: Vector2, b: Vector2) -> void:
		Audio.sfx("explosion", 0.12)
		if game != null and game.has_method("spawn_vfx"):
			game.spawn_vfx("energy", a, 0.0, 1.1, BEAM_COL)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and is_instance_valid(e) and e.has_method("take_damage"):
				var p: Vector2 = (e as Node2D).global_position
				if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= BEAM_HALF_W + 34.0:
					e.take_damage(_beam_dmg_enemy)
		if _plr != null and is_instance_valid(_plr) and _plr.has_method("take_damage"):
			var pp: Vector2 = _plr.global_position
			if Geometry2D.get_closest_point_to_segment(pp, a, b).distance_to(pp) <= BEAM_HALF_W + 22.0:
				_plr.take_damage(_beam_dmg)
				Events.screen_shake.emit(7.0)

	## Fuel barrel detonation: hurts EVERYTHING in BOOM_R, the player included — the 4s fuse is
	## the fair warning. Leading the horde over a barrel is the reward.
	func _explode() -> void:
		set_process(false)
		var pos: Vector2 = global_position
		_mark_gone(pos)
		GameState.props_destroyed += 1   # barrels count for the daily quest too (they did not before)
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

	## Tell the scatter this spot is spent. Uses `position` (chunk-local placement), which is what
	## _load_chunk keys on — global_position matches since the scatter sits at the origin.
	func _mark_gone(pos: Vector2) -> void:
		var s: Node = get_parent()
		if s != null and s.has_method("mark_destroyed"):
			s.mark_destroyed(pos)

	## The beam Line2D is top_level, so it does NOT follow the prop out of the tree — it would hang
	## in the world as an orphan bright line after the emitter is destroyed or streamed out.
	func _clear_beam() -> void:
		if _beam_line != null and is_instance_valid(_beam_line):
			_beam_line.visible = false

	func _exit_tree() -> void:
		_clear_beam()
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
			GameState.props_destroyed += 1   # daily-quest tracking (flushed at run end)
			_mark_gone(global_position)      # stays broken when this chunk streams back in
			if _pylon:
				_emp_burst()                 # breaking an arc pylon releases an EMP shockwave
			if _shatter:
				_shatter_burst()             # breaking a crystal sprays damaging shards
			if game != null:
				if _beacon:
					# silencing a beacon is a real objective -> a proper burst + a scrap payout so
					# the commitment (220 HP under fire) is worth it
					if game.has_method("death_fx"):
						game.death_fx(global_position, 1, true)
					if game.has_method("spawn_scrap"):
						game.spawn_scrap(global_position, 14 + randi() % 10)
				elif game.has_method("death_fx"):
					game.death_fx(global_position, 0, false)   # no lightning on a plain crate
				_drop_loot(global_position)
				if "cover_list" in game:
					game.cover_list.erase(self)
			call_deferred("queue_free")
		else:
			var tw: Tween = create_tween()
			tw.tween_property(_sprite, "modulate", Color(2.2, 2.2, 2.4), 0.05)
			tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
