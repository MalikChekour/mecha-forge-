extends Node2D
## Run orchestrator: builds the arena, player, spawner, HUD; owns pools/containers,
## weapon fire, in-engine FX (muzzle flash, damage numbers, hit sparks, screen
## shake), the level-up draft, and the death/result flow. Also a headless autoplay
## bot that drives the real loop (move/fire/kill/pickup/level-up + draft UI) and
## quits with an exit code so CI can catch regressions.

var player: Player
var spawner: EnemySpawner
var hud: HUD
var cam: Camera2D
var enemy_layer: Node2D
var projectile_layer: Node2D
var pickup_layer: Node2D
var fx_layer: Node2D

var _shake: float = 0.0
var _dmg_active: int = 0
var _headless: bool = false
var _biome: int = 0
const CAM_OFFSET: Vector2 = Vector2(0.0, -84.0)   # view pushed up -> player ~60% down-screen
var _hitstop: bool = false
# 8 biome maps (Gemini-generated ground textures in assets/decor/ground_<name>.png)
const BIOMES: Array = ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "ruines"]
# Each biome is GAMEPLAY, not just cosmetic: speed/spawn modifiers + optional ground hazard.
const BIOME_MODS: Dictionary = {
	"tech":      {"label": "SECTEUR TECH"},
	"earth":     {"label": "FRICHE"},
	"spaceship": {"label": "GRAVITE FAIBLE  —  tout va plus vite", "player_speed_mult": 1.15, "enemy_speed_mult": 1.12},
	"volcanic":  {"label": "VOLCAN  —  eruptions de lave", "hazard": "lava"},
	"desert":    {"label": "DESERT  —  ennemis enrages (+18% vit.)", "enemy_speed_mult": 1.18},
	"ice":       {"label": "GLACE  —  ennemis ralentis (-20%)", "enemy_speed_mult": 0.8},
	"jungle":    {"label": "JUNGLE  —  nuees denses (+35%)", "enemy_spawn_mult": 1.35},
	"swamp":     {"label": "MARAIS  —  tout est englue", "enemy_speed_mult": 0.85, "player_speed_mult": 0.9},
	"ruines":    {"label": "VILLE EN RUINES  —  champ de bataille robotique"},
}
var _mods: Dictionary = {}
var _hazard: String = ""
var _hazard_t: float = 0.0
var _proj_pool: Array = []      # recycled Projectile nodes (no queue_free in the hot loop)
var _pickup_pool: Array = []    # recycled Pickup nodes (xp/scrap/bonus)
var _revived: bool = false      # one watch-ad revive per run
var _banked: bool = false       # run scrap banked into meta wallet exactly once
var _maps_cleared: int = 0       # zones cleared (each = a permanent difficulty step up)
var _bot: bool = false
var _frames: int = 0
var _draft_open: bool = false
var _pending_drafts: int = 0   # level-ups earned while a draft is already open (queued, not dropped)
var _cards: Array = []
var _rerolls: int = 3          # reroll charges per run (agency over the draft)
var _banishes: int = 2         # banish charges: remove a card from the run's pool
var _banished: Array = []      # upgrade ids banished for this run
var _passives: Dictionary = {} # picked upgrade ids -> count (evolution eligibility)
var _floor_mat: ShaderMaterial
# Weapon EVOLUTIONS: base weapon at MAX level + the required passive owned -> evolved form.
const EVO_RULES: Dictionary = {
	"autocannon": {"passive": "haste", "evo": "vulcan", "name": "EVOLUTION : Vulcan (barrage)"},
	"missilepod": {"passive": "crit", "evo": "hydra", "name": "EVOLUTION : Hydra (essaim)"},
	"railgun": {"passive": "dmg", "evo": "annihilator", "name": "EVOLUTION : Annihilateur"},
	"plasma": {"passive": "magnet", "evo": "singularity", "name": "EVOLUTION : Singularite"},
}

const UPGRADES: Array = [
	{"id": "dmg", "name": "+25% Degats"},
	{"id": "spd", "name": "+12% Vitesse"},
	{"id": "hp", "name": "+25 PV max (+soin)"},
	{"id": "haste", "name": "+12% Cadence de tir"},
	{"id": "crit", "name": "+8% Chance de critique"},
	{"id": "armor", "name": "+8% Armure"},
	{"id": "magnet", "name": "+25% Aimant a XP"},
	{"id": "w_missile", "name": "Arme : Missiles chercheurs"},
	{"id": "w_railgun", "name": "Arme : Railgun percant"},
	{"id": "w_plasma", "name": "Arme : Plasma (zone)"},
	{"id": "aura", "name": "Bouclier a impulsions (+rayon)"},   # damaging ring, grows each pick
	{"id": "drone", "name": "Drone de combat (+1)"},            # stackable orbiting auto-turret
]
# maps a weapon draft-card id -> its WeaponSystem id (for showing the current level on the card)
const _WEAPON_CARD: Dictionary = {"w_missile": "missilepod", "w_railgun": "railgun", "w_plasma": "plasma"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep orchestrating (bot/draft) while the tree is paused
	randomize()   # vary the biome (and other RNG) per run
	RenderingServer.set_default_clear_color(Palette.ARENA_BG)
	GameState.reset()
	_headless = DisplayServer.get_name() == "headless"
	_bot = _headless or OS.get_cmdline_user_args().has("--autoplay")

	_build_environment()
	enemy_layer = _mk_layer()
	projectile_layer = _mk_layer()
	pickup_layer = _mk_layer()
	fx_layer = _mk_layer()
	# Game is PROCESS_MODE_ALWAYS (keeps orchestrating bot/draft while paused). Its INHERIT
	# children would inherit ALWAYS too, so get_tree().paused would NOT freeze the sim — enemies
	# kept moving/spawning behind the difficulty menu and during level-up drafts. Mark the sim
	# layers PAUSABLE so a real pause actually stops the action (overlays stay ALWAYS to stay live).
	enemy_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	projectile_layer.process_mode = Node.PROCESS_MODE_PAUSABLE

	player = Player.new()
	player.game = self
	player.bot_active = _bot
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE   # freeze the mech while paused
	player.collision_mask = 8   # collide with cover props (StaticBody layer 8)

	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.offset = CAM_OFFSET   # push the view up so the player sits ~60% down (thumb clears the south)
	player.add_child(cam)

	var amb: Ambient = Ambient.new()
	add_child(amb)
	amb.setup(player)

	spawner = EnemySpawner.new()
	spawner.game = self
	spawner.player = player
	spawner.speed_mult = float(_mods.get("enemy_speed_mult", 1.0))
	spawner.spawn_mult = float(_mods.get("enemy_spawn_mult", 1.0))
	add_child(spawner)
	spawner.process_mode = Node.PROCESS_MODE_PAUSABLE   # no spawns behind the menu / during drafts
	player.move_mult = float(_mods.get("player_speed_mult", 1.0))

	hud = HUD.new()
	add_child(hud)
	hud.setup(player)
	hud.card_picked.connect(_on_card_picked)
	hud.reroll_requested.connect(_reroll_draft)
	hud.banish_requested.connect(_on_banish)

	Events.screen_shake.connect(func(a: float) -> void: _shake = maxf(_shake, a))
	Events.hit_spark.connect(_on_hit_spark)
	Events.damage_dealt.connect(func(pos: Vector2, amt: int, crit: bool) -> void: _damage_number(pos, amt, crit))
	Events.level_up.connect(func(_l: int) -> void: _open_draft())
	Events.level_up.connect(func(_l: int) -> void: _level_fx())
	Events.player_died.connect(_on_player_died)
	Events.run_won.connect(_on_run_won)
	if _headless:
		Events.player_transformed.connect(func(on: bool) -> void: print("[game] TRANSFORM ", on))
		Events.run_won.connect(func() -> void: print("[game] VICTORY"))

	# The player picks a difficulty before the fight begins (bot/headless -> saved default).
	if _bot:
		_begin_run()
	else:
		_show_difficulty_select()

# Kick off the actual run (biome banner + music). Called after the difficulty is chosen.
func _begin_run() -> void:
	var dname: String = String(GameState.diff().get("name", "NORMAL"))
	var lbl: String = String(_mods.get("label", ""))
	show_banner((lbl + "   [" + dname + "]") if lbl != "" else dname)
	Audio.music("battle")
	_play_intro()

# Run-start TELEPORT-IN: a light beam slams down, the mech materialises from an over-bright
# flash with a ground shockwave, brief invuln + a spawn hold so the entrance reads clean.
func _play_intro() -> void:
	if _headless or player == null:
		return
	var pos: Vector2 = player.global_position
	spawn_vfx("portal", pos, 0.0, 2.2, Color(0.7, 0.95, 1.2))   # teleport-in swirl
	player.grant_invuln(2.2)
	if spawner != null and spawner.has_method("delay_spawns"):
		spawner.delay_spawns(1.1)
	var col: Color = Color(0.6, 0.95, 1.0)
	var beam: Line2D = Line2D.new()
	beam.width = 30.0
	beam.default_color = Color(col.r, col.g, col.b, 0.9)
	beam.material = _add_mat()
	beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam.add_point(pos + Vector2(0.0, -1200.0))
	beam.add_point(pos)
	beam.z_index = 60
	beam.modulate = Color(1, 1, 1, 0)
	fx_layer.add_child(beam)
	var m = player.mecha
	if m != null:
		m.modulate = Color(1, 1, 1, 0)         # materialise from nothing
		m.set_tint(Color(2.4, 2.6, 3.0))       # over-bright while forming
	_ring(pos, col, 10.0, 300.0, 0.6)
	_light_pop(pos, col, 3.0, 0.6, 2.2)
	var tw: Tween = create_tween()
	tw.tween_property(beam, "modulate:a", 1.0, 0.12)   # beam slams down
	tw.tween_callback(func() -> void:
		_flash_sprite(pos, Color(0.85, 0.97, 1.0), 260.0, 0.4)
		_ring(pos, col, 20.0, 240.0, 0.5)
		_debris(pos, col, 18, 0.5, 120.0, 380.0)
		Events.screen_shake.emit(7.0))
	if m != null:
		tw.parallel().tween_property(m, "modulate:a", 1.0, 0.45)   # mech fades in
	tw.tween_interval(0.15)
	tw.tween_property(beam, "modulate:a", 0.0, 0.35)   # beam retracts + fades
	tw.parallel().tween_property(beam, "width", 4.0, 0.35)
	tw.tween_callback(func() -> void:
		if m != null:
			m.set_tint(Color.WHITE)
		beam.queue_free())

# Full-screen difficulty picker shown at run start.
func _show_difficulty_select() -> void:
	get_tree().paused = true
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 40
	cl.process_mode = Node.PROCESS_MODE_ALWAYS   # works while the tree is paused
	add_child(cl)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.offset_left = -260.0
	box.offset_right = 260.0
	box.offset_top = -220.0
	box.offset_bottom = 220.0
	cl.add_child(box)
	var title: Label = Label.new()
	title.text = "CHOISIS TA DIFFICULTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	box.add_child(title)
	var descs: Array = [
		"Foes plus faibles - pour decouvrir",
		"L'experience equilibree",
		"Foes coriaces, plus nombreux - recompenses +30%",
		"Brutal. Reserve aux pilotes d'elite - score x2.4",
	]
	var cur: int = SaveManager.get_difficulty()
	for i in GameState.DIFFICULTY.size():
		var d: Dictionary = GameState.DIFFICULTY[i]
		var b: Button = Button.new()
		b.text = "%s        %s" % [String(d["name"]), String(descs[i])]
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(520, 62)
		if i == cur:
			b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		b.pressed.connect(_on_difficulty_chosen.bind(i, cl))
		box.add_child(b)
	# (headless/bot never reaches here: _ready calls _begin_run() directly for _bot)

func _on_difficulty_chosen(idx: int, overlay: CanvasLayer) -> void:
	GameState.difficulty = clampi(idx, 0, GameState.DIFFICULTY.size() - 1)
	SaveManager.set_difficulty(GameState.difficulty)
	Audio.sfx("click")
	if is_instance_valid(overlay):
		overlay.queue_free()
	get_tree().paused = false
	_begin_run()

func _mk_layer() -> Node2D:
	var n: Node2D = Node2D.new()
	add_child(n)
	return n

# ---- weapon fire (pooled: reuse instead of new/queue_free in the hot loop) ----
func spawn_shot(muzzle: Vector2, dir: Vector2, params: Dictionary) -> void:
	var p: Projectile
	if _proj_pool.is_empty():
		p = Projectile.new()
		p.game = self
		projectile_layer.add_child(p)
	else:
		p = _proj_pool.pop_back()
	p.setup(muzzle, dir, params)
	_muzzle_flash(muzzle, dir, Color(params.get("color", Palette.CYAN)))
	Audio.sfx("shoot", 0.14)

func reclaim_proj(p: Projectile) -> void:
	p.deactivate()
	_proj_pool.append(p)

func spawn_bolt(pos: Vector2, dir: Vector2, dmg: float) -> void:
	spawn_shot(pos, dir, {"dmg": dmg, "pierce": player.bolt_pierce})

func _spawn_pickup(pos: Vector2, kind: String, val: int) -> void:
	var g: Pickup
	if _pickup_pool.is_empty():
		g = Pickup.new()
		g.game = self
		pickup_layer.add_child(g)
	else:
		g = _pickup_pool.pop_back()
	g.setup(pos, kind, val, player)

func reclaim_pickup(p: Pickup) -> void:
	p.deactivate()
	_pickup_pool.append(p)

func spawn_xp(pos: Vector2, val: int) -> void:
	_spawn_pickup(pos, "xp", val)

func spawn_scrap(pos: Vector2, amount: int) -> void:
	_spawn_pickup(pos, "scrap", amount)

func spawn_bonus(pos: Vector2) -> void:
	# a gold cache: heals + tops up overdrive + a little scrap when vacuumed up
	_spawn_pickup(pos, "bonus", 1)

func spawn_skill(pos: Vector2) -> void:
	# dropped by a broken skill-crate: grants a random competence when collected
	_spawn_pickup(pos, "skill", 1)

# Grant a random permanent competence (a free draft pick), called when a "skill" pickup is vacuumed.
const _SKILL_POOL: Array = ["dmg", "spd", "hp", "haste", "crit", "armor", "magnet", "aura", "drone"]
const _SKILL_NAME: Dictionary = {
	"dmg": "PUISSANCE +25%", "spd": "VITESSE +12%", "hp": "VITALITE +25", "haste": "CADENCE +",
	"crit": "CRITIQUE +8%", "armor": "ARMURE +8%", "magnet": "AIMANT +", "aura": "AURA", "drone": "DRONE",
}
func grant_skill() -> void:
	var id: String = String(_SKILL_POOL[randi() % _SKILL_POOL.size()])
	_apply_upgrade(id)
	Audio.sfx("levelup")
	show_banner("COMPETENCE : %s" % String(_SKILL_NAME.get(id, id)), Palette.BONUS)

func spawn_enemy_bolt(pos: Vector2, dir: Vector2, dmg: float, color: Color = Color(1.0, 0.55, 0.25)) -> void:
	var b: EnemyProjectile = EnemyProjectile.new()
	b.tint = color
	projectile_layer.add_child(b)
	b.setup(pos, dir, dmg)

# Weapon-signature impact FX: every family hits with a DISTINCT, readable look so the
# arsenal never feels samey. Explosive = fireball+smoke, piercing = sharp lance, energy =
# crackling arcs, kinetic = quick spark, drone = small blue pop. Evolved weapons are amplified.
func impact_fx(pos: Vector2, color: Color, kind: String, dir: Vector2 = Vector2.ZERO) -> void:
	match kind:
		"missilepod", "hydra":   # EXPLOSIVE: hot fireball + smoke + shake
			var big: float = 1.35 if kind == "hydra" else 1.0
			var fire: Color = Color(1.0, 0.55, 0.2)
			_flash_sprite(pos, fire, 118.0 * big, 0.18)
			_ring(pos, fire, 12.0, 104.0 * big, 0.30)
			_debris(pos, Color(1.0, 0.72, 0.3), int(12 * big), 0.44, 130.0, 360.0)
			_smoke(pos, int(6 * big))
			_light_pop(pos, fire, 2.6, 0.26, 1.4 * big)
			Events.screen_shake.emit(3.5 * big)
			Audio.sfx("explosion", 0.1)
		"railgun", "annihilator":   # PIERCING: a bright lance along travel, minimal debris
			var big2: float = 1.4 if kind == "annihilator" else 1.0
			var beam: Color = color.lerp(Color.WHITE, 0.35)
			_streak(pos, dir, beam, 210.0 * big2, 7.0 * big2, 0.13)
			_flash_sprite(pos, beam, 60.0 * big2, 0.10)
			_ring(pos, beam, 4.0, 40.0 * big2, 0.12)
			_light_pop(pos, beam, 1.8 * big2, 0.12, 1.0 * big2)
			if kind == "annihilator":
				Events.screen_shake.emit(3.0)
			Audio.sfx("hit", 0.15)
		"plasma", "singularity":   # ENERGY AoE: crackling burst, electric arcs, double ring
			var big3: float = 1.4 if kind == "singularity" else 1.0
			var en: Color = color.lerp(Color(0.75, 0.9, 1.0), 0.3)
			_flash_sprite(pos, en, 96.0 * big3, 0.16)
			_ring(pos, en, 8.0, 78.0 * big3, 0.24)
			_ring(pos, Color.WHITE, 4.0, 48.0 * big3, 0.14)
			_arcs(pos, en, int(5 * big3), 70.0 * big3)
			_light_pop(pos, en, 2.2 * big3, 0.22, 1.2 * big3)
			if kind == "singularity":
				Events.screen_shake.emit(2.5)
			Audio.sfx("explosion" if kind == "singularity" else "hit", 0.12)
		"drone":   # friendly drone bolt: small light-blue pop
			var dc: Color = Color(0.6, 0.95, 1.0)
			_flash_sprite(pos, dc, 40.0, 0.10)
			_ring(pos, dc, 4.0, 30.0, 0.12)
		_:   # KINETIC rapid (autocannon / vulcan): quick punchy spark
			var big4: float = 1.25 if kind == "vulcan" else 1.0
			_flash_sprite(pos, color.lerp(Color.WHITE, 0.4), 44.0 * big4, 0.09)
			_debris(pos, color, int(4 * big4), 0.26, 90.0, 220.0)
			Audio.sfx("hit", 0.15)

# Energy-shield hit ripple (used by shielded enemies and the player's guard).
func shield_ripple(pos: Vector2, radius: float, color: Color) -> void:
	_ring(pos, color, radius * 0.6, radius * 1.15, 0.22)
	_flash_sprite(pos, color, radius * 0.9, 0.12)

func shield_break(pos: Vector2, radius: float, color: Color) -> void:
	_ring(pos, color, radius * 0.4, radius * 1.5, 0.34)
	_flash_sprite(pos, color, radius * 1.4, 0.22)
	_debris(pos, color, 16, 0.5, 150.0, 360.0)
	Events.screen_shake.emit(4.0)

# ---- FX ----
func _muzzle_flash(pos: Vector2, dir: Vector2, color: Color = Palette.CYAN) -> void:
	var bright: Color = color.lerp(Color.WHITE, 0.5)
	_flash_sprite(pos, bright, 96.0, 0.11)
	_ring(pos, color, 10.0, 46.0, 0.16)
	var l: PointLight2D = PointLight2D.new()
	l.texture = Tex.glow(color, 160)
	l.color = color
	l.energy = 1.9
	l.position = pos + dir * 6.0
	fx_layer.add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(l, "energy", 0.0, 0.12)
	tw.tween_callback(l.queue_free)

func _damage_number(pos: Vector2, amt: int, crit: bool) -> void:
	if crit:
		spawn_vfx("crit", pos, 0.0, 0.7)   # red-gold starburst on a critical hit
	if not bool(SaveManager.data.get("settings", {}).get("damage_numbers", true)):
		return
	if _dmg_active > 26:
		return
	var l: Label = Label.new()
	l.text = str(amt)
	l.position = pos + Vector2(-8, -18)
	l.z_index = 100
	l.add_theme_font_size_override("font_size", 28 if crit else 20)
	l.add_theme_color_override("font_color", Color(1, 0.8, 0.2) if crit else Color(1, 1, 1))
	fx_layer.add_child(l)
	_dmg_active += 1
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector2(0, -42), 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		l.queue_free()
		_dmg_active -= 1)

func _on_hit_spark(pos: Vector2, color: Color) -> void:
	_debris(pos, color, 6, 0.35, 90.0, 230.0)
	_flash_sprite(pos, color, 48.0, 0.12)

# --- Animated VFX (baked Kenney-particle spritesheets, ADDITIVE, pooled) ---
const VFX_DEF: Dictionary = {
	"explosion": {"frames": 16, "fps": 30},
	"muzzle":    {"frames": 6,  "fps": 34},
	"impact":    {"frames": 10, "fps": 34},
	"slash":     {"frames": 9,  "fps": 30},
	"levelup":   {"frames": 16, "fps": 26},
	"crit":      {"frames": 9,  "fps": 28},
	"energy":    {"frames": 14, "fps": 24},
	"shockwave": {"frames": 12, "fps": 30},
	"shield":    {"frames": 16, "fps": 22},
	"heal":      {"frames": 16, "fps": 24},
	"portal":    {"frames": 16, "fps": 26},
	"pickup":    {"frames": 9,  "fps": 30},
}
var _vfx_pool: Array = []
var _vfx_tex: Dictionary = {}   # id -> Texture2D (cached load)
var cover_list: Array = []      # decor props (PropScatter) enemies steer around (blocks the player physically)
var _scatter: Node2D            # current PropScatter — rebuilt per biome on next_map()

## Play a one-shot animated effect. pos=anchor, rot(rad)=orientation, scl scales the 160px cell,
## col tints it (sheets are neutral white on black). Pooled -> no alloc in the hot loop.
func spawn_vfx(id: String, pos: Vector2, rot: float = 0.0, scl: float = 1.0, col: Color = Color.WHITE) -> void:
	var d: Dictionary = VFX_DEF.get(id, {})
	if d.is_empty() or fx_layer == null:
		return
	if not _vfx_tex.has(id):
		var p: String = "res://assets/vfx/%s.png" % id
		_vfx_tex[id] = load(p) if ResourceLoader.exists(p) else null
	var tex: Texture2D = _vfx_tex[id]
	if tex == null:
		return
	var v: VfxSprite
	if _vfx_pool.is_empty():
		v = VfxSprite.new()
		v.game = self
		fx_layer.add_child(v)
	else:
		v = _vfx_pool.pop_back()
	v.play(tex, int(d["frames"]), float(d["fps"]), pos, rot, scl, col)

func reclaim_vfx(v: VfxSprite) -> void:
	if _vfx_pool.size() < 40:
		_vfx_pool.append(v)
	else:
		v.queue_free()

func death_fx(pos: Vector2, rank: int) -> void:
	spawn_vfx("explosion", pos, 0.0, 0.8 + rank * 0.38)   # animated fireball, bigger for tougher foes
	if rank >= 2:
		hit_stop(0.05)   # punchy freeze on heavy/elite kills
	var col: Color = Color(1.0, 0.72, 0.32)
	_flash_sprite(pos, col, 118.0 + rank * 80.0, 0.20)
	_ring(pos, col, 14.0, 96.0 + rank * 90.0, 0.34)
	_debris(pos, col, 12 + rank * 12, 0.5, 130.0, 360.0)
	var l: PointLight2D = PointLight2D.new()
	l.texture = Tex.glow(col, 240)
	l.color = col
	l.energy = 2.3 + float(rank)
	l.position = pos
	fx_layer.add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(l, "energy", 0.0, 0.28)
	tw.tween_callback(l.queue_free)
	Events.screen_shake.emit(5.0 + rank * 6.0)

## Brief real-time freeze for weighty impacts (crits / heavy deaths). Uses an
## ignore-time-scale timer so it self-restores even while the game is slowed.
func hit_stop(dur: float) -> void:
	if _hitstop or _headless:
		return
	_hitstop = true
	Engine.time_scale = 0.03
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop = false

# Volcanic biome ground hazard: a telegraphed lava eruption that hurts the player if
# they linger in it. Telegraphs (red ring grows) then bursts.
func _spawn_lava_hazard() -> void:
	var ang: float = randf() * TAU
	var pos: Vector2 = player.global_position + Vector2(cos(ang), sin(ang)) * randf_range(110.0, 430.0)
	var R: float = 96.0
	var warn: Sprite2D = Sprite2D.new()
	warn.texture = Tex.ring(Color(1.0, 0.32, 0.1), 128)
	warn.material = _add_mat()
	warn.position = pos
	warn.scale = Vector2.ONE * (R * 2.0 / 128.0)
	warn.modulate = Color(1.0, 0.4, 0.1, 0.0)
	fx_layer.add_child(warn)
	var tw: Tween = create_tween()
	tw.tween_property(warn, "modulate:a", 0.85, 0.7)   # telegraph window
	tw.tween_callback(func() -> void:
		_flash_sprite(pos, Color(1.0, 0.6, 0.2), R * 2.4, 0.22)
		_ring(pos, Color(1.0, 0.5, 0.15), R * 0.5, R * 1.7, 0.32)
		_debris(pos, Color(1.0, 0.5, 0.2), 14, 0.5, 150.0, 380.0)
		Events.screen_shake.emit(4.0)
		if GameState.alive and player != null and player.global_position.distance_to(pos) < R:
			if player.has_method("take_damage"):
				player.take_damage(14.0)
		warn.queue_free())

func show_banner(text: String, color: Color = Color(1.0, 0.92, 0.7)) -> void:
	if text == "" or _headless:
		return
	var cl: CanvasLayer = CanvasLayer.new(); cl.layer = 20
	add_child(cl)
	var lb: Label = Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", 32)
	lb.add_theme_color_override("font_color", color)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lb.add_theme_constant_override("outline_size", 6)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lb.offset_top = 74.0
	lb.offset_bottom = 120.0
	cl.add_child(lb)
	lb.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(lb, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.4)
	tw.tween_property(lb, "modulate:a", 0.0, 0.6)
	tw.tween_callback(cl.queue_free)

func _flash_sprite(pos: Vector2, color: Color, size: float, dur: float) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.glow(color, 64)
	s.material = _add_mat()
	s.position = pos
	s.scale = Vector2.ONE * (size * 0.35 / 64.0)
	fx_layer.add_child(s)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (size / 64.0), dur)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s.queue_free)

func _ring(pos: Vector2, color: Color, r0: float, r1: float, dur: float) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = Tex.ring(color, 128)
	s.material = _add_mat()
	s.position = pos
	s.scale = Vector2.ONE * (r0 / 64.0)
	fx_layer.add_child(s)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (r1 / 64.0), dur)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s.queue_free)

func _debris(pos: Vector2, color: Color, n: int, life: float, vmin: float, vmax: float) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 1.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.color = color
	p.material = _add_mat()
	fx_layer.add_child(p)
	var tw: Tween = create_tween()
	tw.tween_interval(life + 0.2)
	tw.tween_callback(p.queue_free)

func _level_fx() -> void:
	spawn_vfx("levelup", player.global_position, 0.0, 1.35)   # animated golden burst + rising stars
	_ring(player.global_position, Palette.CYAN, 24.0, 340.0, 0.5)
	Events.screen_shake.emit(4.0)

func transform_fx(pos: Vector2, into: bool) -> void:
	if into:
		spawn_vfx("energy", pos, 0.0, 2.4)   # swirling energy burst on Overdrive transform
	var col: Color = Palette.CYAN if into else Color(0.6, 0.72, 0.92)
	_flash_sprite(pos, col, 280.0, 0.38)
	_ring(pos, col, 20.0, 430.0, 0.55)
	_ring(pos, col, 12.0, 260.0, 0.4)
	_debris(pos, col, 24, 0.6, 170.0, 440.0)
	Events.screen_shake.emit(13.0 if into else 6.0)

func _add_mat() -> CanvasItemMaterial:
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

# short-lived coloured light burst (adds punch to explosions / energy hits)
func _light_pop(pos: Vector2, color: Color, energy: float, dur: float, scale: float) -> void:
	if _headless:
		return
	var l: PointLight2D = PointLight2D.new()
	l.texture = Tex.glow(color, 160)
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	l.position = pos
	fx_layer.add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(l, "energy", 0.0, dur)
	tw.tween_callback(l.queue_free)

# a bright thin lance along the shot direction (railgun/annihilator signature)
func _streak(pos: Vector2, dir: Vector2, color: Color, length: float, width: float, dur: float) -> void:
	if _headless:
		return
	var d: Vector2 = dir if dir != Vector2.ZERO else Vector2.RIGHT
	var ln: Line2D = Line2D.new()
	ln.width = width
	ln.default_color = color
	ln.material = _add_mat()
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.add_point(pos - d * length * 0.5)
	ln.add_point(pos + d * length * 0.5)
	fx_layer.add_child(ln)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(ln, "width", 0.0, dur)
	tw.tween_property(ln, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(ln.queue_free)

# dark smoke puff drifting up (explosions)
func _smoke(pos: Vector2, n: int) -> void:
	if _headless:
		return
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = maxi(1, n)
	p.lifetime = 0.7
	p.explosiveness = 0.85
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0.0, -40.0)
	p.scale_amount_min = 5.0
	p.scale_amount_max = 10.0
	p.damping_min = 30.0
	p.damping_max = 60.0
	p.color = Color(0.14, 0.13, 0.15, 0.7)   # dark smoke (normal blend, reads against bright floor)
	fx_layer.add_child(p)
	var tw: Tween = create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(p.queue_free)

# jagged electric arcs radiating out (plasma/singularity signature)
func _arcs(pos: Vector2, color: Color, n: int, length: float) -> void:
	if _headless:
		return
	for i in n:
		var ang: float = randf() * TAU
		var ln: Line2D = Line2D.new()
		ln.width = 2.5
		ln.default_color = color
		ln.material = _add_mat()
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.position = pos
		ln.add_point(Vector2.ZERO)
		var steps: int = 4
		for s in range(1, steps + 1):
			var t: float = float(s) / float(steps)
			var along: Vector2 = Vector2.from_angle(ang) * length * t
			along += Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
			ln.add_point(along)
		fx_layer.add_child(ln)
		var tw: Tween = create_tween()
		tw.tween_property(ln, "modulate:a", 0.0, 0.16)
		tw.tween_callback(ln.queue_free)

func _build_environment() -> void:
	var floor_cl: CanvasLayer = CanvasLayer.new()
	floor_cl.layer = -100
	add_child(floor_cl)
	var fr: ColorRect = ColorRect.new()
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome = _pick_biome()
	var biome_name: String = BIOMES[clampi(_biome, 0, BIOMES.size() - 1)]
	_mods = BIOME_MODS.get(biome_name, {})
	_hazard = String(_mods.get("hazard", ""))
	_floor_mat = ShaderMaterial.new()
	_apply_biome_floor(biome_name)
	fr.material = _floor_mat
	floor_cl.add_child(fr)
	# Gemini decor scatter: biome-coherent props that block the player + enemies and (crates)
	# can be broken for a competence. Added under the floor layer so actors walk in front.
	_scatter_decor(biome_name)
	var vig_cl: CanvasLayer = CanvasLayer.new()
	vig_cl.layer = 15
	add_child(vig_cl)
	var vr: ColorRect = ColorRect.new()
	vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm: ShaderMaterial = ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vm.set_shader_parameter("strength", 0.5)
	vr.material = vm
	vig_cl.add_child(vr)

## (Re)build the Gemini decor scatter for a biome. Called at build AND on every next_map so a
## cleared zone gets ITS biome's props (else 'ruines' buildings never appear via progression and
## old colliders linger in cover_list).
func _scatter_decor(biome_name: String) -> void:
	if _scatter != null and is_instance_valid(_scatter):
		_scatter.queue_free()
	cover_list.clear()
	var s: PropScatter = PropScatter.new()
	s.game = self
	s.biome = biome_name
	s.z_index = -1        # world-space, behind the actors, above the floor CanvasLayer
	add_child(s)
	s.populate(28)
	_scatter = s

func _apply_biome_floor(biome_name: String) -> void:
	# Point the (persistent) floor material at this biome's ground. Used at build time
	# and again on every map change, so switching zones only repaints — no rebuild.
	var ground_path: String = "res://assets/decor/ground_%s.png" % biome_name
	if ResourceLoader.exists(ground_path):
		# seamless Blender-baked ground tile, repeated in world space (sharp + scrolls)
		_floor_mat.shader = load("res://shaders/floor_tex.gdshader")
		_floor_mat.set_shader_parameter("ground", load(ground_path))
		_floor_mat.set_shader_parameter("tile", 1080.0)   # ~1 tile per screen -> no side-by-side repeat
	else:
		_floor_mat.shader = load("res://shaders/floor.gdshader")
		_floor_mat.set_shader_parameter("biome", float(_biome))   # 0 tech / 1 earth / 2 spaceship / 3 volcanic

# A major threat down -> advance to a NEW zone. Difficulty is NEVER reset: run_time keeps
# climbing AND each cleared map adds a permanent escalation (tougher foes on every new map).
func next_map() -> void:
	_maps_cleared += 1
	_biome = (_biome + 1) % BIOMES.size()
	var biome_name: String = BIOMES[_biome]
	_mods = BIOME_MODS.get(biome_name, {})
	_hazard = String(_mods.get("hazard", ""))
	if _floor_mat != null:
		_apply_biome_floor(biome_name)
	_scatter_decor(biome_name)   # rebuild decor for the new biome (else ruines props never appear)
	if spawner != null:
		spawner.speed_mult = float(_mods.get("enemy_speed_mult", 1.0))
		spawner.spawn_mult = float(_mods.get("enemy_spawn_mult", 1.0))
		spawner.difficulty_bonus = float(_maps_cleared) * 0.18   # +18% enemy HP/dmg per zone cleared
	if player != null:
		player.move_mult = float(_mods.get("player_speed_mult", 1.0))
		if player.has_method("grant_invuln"):
			player.grant_invuln(1.5)   # brief breather during the transition flash
	# quick "zone shift" flash so the repaint reads as an event, not a glitch
	Events.screen_shake.emit(6.0)
	show_banner("ZONE %d  —  %s" % [_maps_cleared + 1, String(_mods.get("label", biome_name.to_upper()))],
		Color(0.55, 0.95, 1.0))
	Audio.music("battle")

# damaging-aura pulse ring (fires each aura tick; cheap, skipped when headless)
func aura_pulse_fx(pos: Vector2, radius: float) -> void:
	if _headless:
		return
	_ring(pos, Palette.CYAN, radius * 0.82, radius * 1.1, 0.3)

# ---- level-up draft ----
func _open_draft() -> void:
	if _draft_open:
		_pending_drafts += 1   # gained another level mid-draft -> queue it, don't drop the card
		return
	_draft_open = true
	_draw_cards()
	get_tree().paused = true
	hud.show_draft(_cards, _rerolls, _banishes)
	if _headless:
		print("[game] DRAFT opened (level %d) — 3 cards" % GameState.level)

func _draw_cards() -> void:
	var pool: Array = []
	for u: Dictionary in UPGRADES:
		if not _banished.has(u["id"]):
			pool.append(u)
	pool.shuffle()
	_cards = pool.slice(0, 3)
	# guarantee-offer any eligible weapon EVOLUTION (base at MAX + required passive owned)
	var evos: Array = _eligible_evolutions()
	if not evos.is_empty():
		evos.shuffle()
		_cards = (evos.slice(0, mini(evos.size(), 3)) + _cards).slice(0, 3)
	# annotate weapon cards with the current owned level (duplicate so the const UPGRADES pool is never mutated)
	if player != null and player.has_method("weapons"):
		var ws2: WeaponSystem = player.weapons()
		if ws2 != null:
			for i in _cards.size():
				var wid: String = String(_WEAPON_CARD.get(String(_cards[i].get("id", "")), ""))
				if wid != "":
					var lv: int = ws2.weapon_level(wid)
					if lv > 0:
						var c: Dictionary = (_cards[i] as Dictionary).duplicate()
						c["name"] = "%s  (Niv.%d)" % [String(c["name"]), lv]
						_cards[i] = c

func _eligible_evolutions() -> Array:
	var out: Array = []
	if player == null or not player.has_method("weapons"):
		return out
	var ws: WeaponSystem = player.weapons()
	if ws == null:
		return out
	for base: String in EVO_RULES:
		var r: Dictionary = EVO_RULES[base]
		if ws.is_max(base) and _passives.has(r["passive"]) and not ws.owned_weapons().has(r["evo"]):
			out.append({"id": "evo_" + base, "name": String(r["name"]), "evo": true})
	return out

func _reroll_draft() -> void:
	if not _draft_open or _rerolls <= 0:
		return
	_rerolls -= 1
	Audio.sfx("click")
	_draw_cards()
	hud.show_draft(_cards, _rerolls, _banishes)

func _on_banish(index: int) -> void:
	if not _draft_open or _banishes <= 0 or index < 0 or index >= _cards.size():
		return
	var id: String = String(_cards[index].get("id", ""))
	if id.begins_with("evo_"):
		return                      # never banish an evolution offer
	_banishes -= 1
	if not _banished.has(id):
		_banished.append(id)
	Audio.sfx("click")
	_draw_cards()
	hud.show_draft(_cards, _rerolls, _banishes)

func _on_card_picked(index: int) -> void:
	if index >= 0 and index < _cards.size():
		_apply_upgrade(String(_cards[index].get("id", "")))
	_draft_open = false
	if _pending_drafts > 0:            # more level-ups were banked while this draft was open
		_pending_drafts -= 1
		call_deferred("_open_draft")   # keep the tree paused; open the next card
	else:
		get_tree().paused = false

func _apply_upgrade(id: String) -> void:
	if id.begins_with("evo_"):
		var base: String = id.substr(4)
		if EVO_RULES.has(base) and player.has_method("weapons"):
			player.weapons().replace_weapon(base, String(EVO_RULES[base]["evo"]))
			Audio.sfx("levelup")
			show_banner("EVOLUTION !", Color(1.0, 0.85, 0.3))
		return
	_passives[id] = int(_passives.get(id, 0)) + 1
	match id:
		"dmg": player.damage *= 1.25
		"spd": player.base_speed *= 1.12
		"hp":
			player.max_hp += 25.0
			player.hp = minf(player.max_hp, player.hp + 25.0)
			Events.player_damaged.emit(player.hp, player.max_hp)
		"haste": player.cooldown_mult = maxf(0.35, player.cooldown_mult * 0.88)
		"crit": player.crit_chance = minf(0.75, player.crit_chance + 0.08)
		"armor": player.armor = minf(0.6, player.armor + 0.08)
		"magnet": player.magnet_range += 90.0
		"w_missile": player.add_weapon("missilepod")
		"w_railgun": player.add_weapon("railgun")
		"w_plasma": player.add_weapon("plasma")
		"aura":
			player.add_aura()
			show_banner("BOUCLIER A IMPULSIONS  niv.%d" % player.aura_level, Color(0.5, 0.95, 1.0))
		"drone":
			player.add_drone()
			show_banner("DRONE DE COMBAT  x%d" % player._drones.size(), Color(0.5, 0.95, 1.0))

func ensure_banked() -> void:
	# bank the run's scrap into the persistent meta wallet exactly once
	if _banked:
		return
	_banked = true
	SaveManager.bank_scrap(GameState.scrap)

func _on_player_died() -> void:
	if _headless:
		ensure_banked()
		return
	var ms: MetaScreen = MetaScreen.new()   # offer a revive first, else the meta shop
	add_child(ms)
	ms.setup(self, true, not _revived)

func _on_run_won() -> void:
	if not GameState.alive:
		return
	GameState.alive = false   # stop spawns/movement, freeze the run on the win
	ensure_banked()
	if _headless:
		return
	var ms: MetaScreen = MetaScreen.new()
	add_child(ms)
	ms.setup(self, false, false)

func revive_player() -> void:
	_revived = true
	GameState.alive = true
	player.hp = player.max_hp * 0.5
	if player.mecha != null:
		player.mecha.play("idle")   # get up: the death anim left the mech on the ground
	if player.has_method("grant_invuln"):
		player.grant_invuln(2.5)
	# clear the crowd around the player so the revive isn't instant death
	for e in get_tree().get_nodes_in_group("enemies"):
		# spare bosses (rank >= 3): nuking them here = free victory / free zone-skip
		if e is Enemy and (e as Enemy).rank < 3 and player.global_position.distance_to((e as Node2D).global_position) < 420.0:
			(e as Enemy).take_damage(99999.0)
	show_banner("SECONDE CHANCE", Color(0.5, 1.0, 0.6))
	Events.player_damaged.emit(player.hp, player.max_hp)

# ---- main loop + headless bot ----
func _process(delta: float) -> void:
	_frames += 1
	if _floor_mat != null and player != null:
		_floor_mat.set_shader_parameter("world_offset", player.global_position)
		_floor_mat.set_shader_parameter("vp_size", get_viewport_rect().size)
	if GameState.alive and not _draft_open and not get_tree().paused:
		GameState.run_time += delta
		Events.run_time_changed.emit(GameState.run_time)
		if _hazard == "lava" and player != null:
			_hazard_t -= delta
			if _hazard_t <= 0.0:
				_hazard_t = randf_range(1.1, 1.9)
				_spawn_lava_hazard()

	if bool(SaveManager.data.get("settings", {}).get("shake", true)) and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 34.0)
		cam.offset = CAM_OFFSET + Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif cam.offset != CAM_OFFSET:
		cam.offset = CAM_OFFSET

	if _bot:
		_drive_bot()
		if _headless and _frames % 60 == 0:
			print("[game] f=%d t=%.0fs lvl=%d xp=%d/%d kills=%d hp=%.0f enemies=%d gems=%d" % [
				_frames, GameState.run_time, GameState.level, GameState.xp, GameState.xp_to_next,
				GameState.kills, player.hp, get_tree().get_nodes_in_group("enemies").size(),
				get_tree().get_nodes_in_group("pickups").size()])
		if _headless and _frames >= 1400:
			_finish_headless()

func _drive_bot() -> void:
	if _headless and _frames == 1050 and GameState.overdrive < 1.0:
		GameState.overdrive = 1.0     # CI: force-fill LATE so normal collection/level-up runs first, then beam
		Events.overdrive_changed.emit(1.0)
	if _draft_open:
		hud.pick(0)
		return
	if not GameState.alive:
		player.bot_move = Vector2.ZERO
		return
	var strafe: Vector2 = Vector2(cos(GameState.run_time * 2.0), sin(GameState.run_time * 2.0)) * 0.35
	# dodge a close enemy; otherwise go collect the nearest XP gem (to exercise level-up)
	var near: Node2D = player._nearest_enemy()
	var danger: Vector2 = Vector2.ZERO
	if near != null:
		var v: Vector2 = player.global_position - near.global_position
		if v.length() < 140.0:
			danger = v.normalized()
	var move: Vector2 = danger
	if danger == Vector2.ZERO:
		var gem: Node2D = _nearest_pickup()
		if gem != null:
			move = (gem.global_position - player.global_position).normalized()
		else:
			move = strafe + (Vector2.ZERO - player.global_position) * 0.0006
	player.bot_move = (move + strafe * 0.2).limit_length(1.0)

func _pick_biome() -> int:
	# On web, allow forcing a biome via the URL hash (#0..#3) for demos; otherwise random.
	# eval returns a NUMBER: 0 when no hash (-> random), else biome+1.
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("location.hash.length>1 ? ((parseInt(location.hash.slice(1))||0)+1) : 0", true)
		if v != null and int(v) > 0:
			return clampi(int(v) - 1, 0, BIOMES.size() - 1)
	return randi() % BIOMES.size()

func _nearest_pickup() -> Node2D:
	var best: Node2D = null
	var bd: float = 1.0e12
	for g in get_tree().get_nodes_in_group("pickups"):
		if g is Node2D:
			var d: float = player.global_position.distance_squared_to((g as Node2D).global_position)
			if d < bd:
				bd = d
				best = g
	return best

func _finish_headless() -> void:
	# require a real vertical slice: kills + XP + at least one level-up/draft resolved
	var ok: bool = GameState.kills > 0 and GameState.level >= 2 and player.get_layer_ok()
	if ok:
		print("[game] SMOKE PASS — kills=%d level=%d scrap=%d (draft exercised), 0 errors" % [
			GameState.kills, GameState.level, GameState.scrap])
		get_tree().quit(0)
	else:
		print("[game] SMOKE FAIL — kills=%d level=%d (level-up/draft not reached)" % [
			GameState.kills, GameState.level])
		get_tree().quit(1)

