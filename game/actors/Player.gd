extends CharacterBody2D
class_name Player
## Top-down player with an "Overdrive" transformation, continuous energy beam, and melee saber.

var game: Node
var mecha   # the mech visual (DirectionalMecha baked sheets OR HeroRig 2D cut-out rig)
var base_speed: float = 320.0
var move_mult: float = 1.0   # biome modifier on movement (e.g. swamp slows, low-g speeds up)
var field_slow: float = 1.0  # transient: a slow-field prop dampens this each frame you're inside
var hp: float = 100.0
var max_hp: float = 70.0   # smaller base -> the health bar starts modest and GROWS only via the
# VITALITE competence (+25/pick), the mech's base hp, gear and meta_hp. Early game is meant to bite.
var damage: float = 12.0
# passive-driven combat stats (raised by draft cards)
var crit_chance: float = 0.05
var crit_mult: float = 2.0
var armor: float = 0.0            # incoming damage reduction, 0..~0.6
var cooldown_mult: float = 1.0    # haste: <1 = faster weapons
# --- passifs facon Survivor.io ---
var size_mult: float = 1.0        # HE Fuel : taille/portee des projectiles + rayons d'effets (cap ~1.7)
var proj_speed_mult: float = 1.0  # Ammo Thruster : vitesse des projectiles (cap ~1.6)
var hp_regen: float = 0.0         # Energy Drink : PV regeneres par seconde
var magnet_range: float = 165.0  # pickup vacuum radius.
# 🚨 MESURE DU TESTEUR EQUILIBRAGE : a 50 px (le rayon de ramassage est deja de 30) il fallait
# marcher SUR les gemmes. Or la seule strategie viable est de fuir (joueur 320 px/s contre
# 150-250 px/s). Resultat mesure : mort a 01:20 avec 51 ennemis tues et TOUJOURS NIVEAU 1 —
# survivre et progresser s'excluaient. 165 px laisse le ramassage naturel en jouant serre,
# sans supprimer l'interet de la competence AIMANT (+105 px par prise).
# --- helper systems (drafted, entity/VFX-based -- NEVER modeled on the mech sprite) ---
var aura_level: int = 0            # damaging shield ring around the mech; radius grows per pick
var aura_radius: float = 0.0
var aura_dmg: float = 7.0
var _aura_spr: Sprite2D = null     # bright rim of the shield bubble
var _aura_dome: Sprite2D = null    # filled body of the bubble -> ENVELOPS the mech, not a bare ring
var _aura_t: float = 0.0
var _aura_flash: float = 0.0       # brief brighten when the shield DISCHARGES (damage tick)
var _drones: Array = []            # orbiting companion drones that auto-fire
var _blades: Array = []            # orbiting energy blades (contact damage)
var _blade_tick: float = 0.0
var _orbs: Array = []              # orbiting charge/discharge plasma orbs (AoE burst)
var _arc_lv: int = 0              # ARC TESLA : chaine d'eclairs (role Lightning, identite maison)
var _arc_t: float = 0.0
var _pool_lv: int = 0             # BRASIER : mare de plasma au sol (role Molotov, identite maison)
var _pool_t: float = 0.0
var arena: Rect2 = Rect2(-1000000, -1000000, 2000000, 2000000)   # set by Game to the bounded arena
var arena_half: float = 0.0:                                      # Game sets this; 0 = unbounded
	set(v):
		arena_half = v
		if v > 0.0:
			arena = Rect2(-v, -v, v * 2.0, v * 2.0)

var bot_active: bool = false
var auto_aim: bool = false          # player opt-in (settings menu): aim locks onto the nearest foe
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
var _laser_eye: Sprite2D      # red glow at the head/eye where the targeting laser originates
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
var _beam_core: Line2D       # razor white-hot centre of the overdrive lance
var _beam_dot: Sprite2D
var _beam_light: Sprite2D           # additive glow, not a dynamic light (see _ready)
var _beam_muzzle_light: Sprite2D
var _beam_t: float = 0.0     # drives the crackle + width pulse
var _beam_fx_t: float = 0.0  # throttles the muzzle/impact bursts along the beam
const BEAM_PTS: int = 20     # polyline resolution of the crackle
const BEAM_JITTER: float = 16.0
const BEAM_ARCS: int = 4     # branching discharges forking off the lance
var _beam_arc_list: Array = []
var _beam_arc_t: float = 0.0

var _od_aura: Sprite2D       # overdrive/transform aura around the mech
var _mark: Sprite2D = null       # anneau au sol « c'est toi » (lisibilite en combat dense)
var _mark_in: Sprite2D = null    # second anneau, plus serre
var _mark_top: Sprite2D = null   # chevron au-dessus du chassis
var _hurt_t: float = 0.0         # minuterie du flash rouge quand on encaisse

## --- ESQUIVE ------------------------------------------------------------------------------
## 🚨 Reproche le plus dur du testeur equilibrage : « une erreur ne se paie pas, elle se
## punit ». Deux ennemis colles vident la barre en quelques secondes et le joueur n'a AUCUNE
## sortie — la seule action manuelle du jeu est la SURCHARGE, qui se merite. L'esquive donne
## une porte de sortie sans toucher aux degats ni aux PV, donc sans regler des nombres a
## l'aveugle (ce que je refuse de faire depuis une machine sans GPU).
## Declenchement : un COUP DE POUCE sec sur le stick de deplacement (idee reprise d'un clone
## Survivor.io) — aucun bouton en plus, ce qui compte sur un ecran deja charge. Au clavier :
## MAJ. L'origine du glissement est re-ancree en continu tant que le doigt bouge lentement,
## sinon un long deplacement normal serait pris pour un coup de pouce.
## 🚨 REGLAGE ISSU DE LA MESURE, pas d'une intuition. Le banc a 3 bras (72 parties) a montre
## que le COUT de la ruee est le pilotage verrouille : dans un champ dense, plus le bot esquive
## plus vite il meurt (DIFFICILE, aucun survivant donc aucune censure : 70 s sans esquive,
## 56 s en reactif, 38 s en anticipe). On raccourcit donc le temps AVEUGLE de 22 % en
## compensant par la vitesse : distance quasi identique (188 px contre 196), mais on reprend
## la main plus tot. L'invulnerabilite couvre toujours la ruee entiere plus une marge.
const DASH_DUR: float = 0.14      # duree de la ruee (etait 0,18 : trop long a l'aveugle)
const DASH_MULT: float = 4.2      # ~188 px parcourus : de quoi sortir d'un corps a corps
const DASH_CD: float = 2.2        # temps de rechargement
const DASH_IFRAME: float = 0.28   # invulnerabilite : la ruee TRAVERSE, sinon elle ne sert a rien
const FLICK_PX: float = 105.0     # distance minimale du coup de pouce
const FLICK_MS: int = 260         # ... parcourue en moins de ce temps
var _dash_t: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _flick_from: Vector2 = Vector2.ZERO
var _flick_ms: int = 0
var _shift_was: bool = false
## Le chassis du joueur est legerement SUR-EXPOSE en permanence.
## 🚨 « les ennemis sont meme PLUS colores (liseres magenta ou cyan vifs) que le heros
## (acier sombre a liseres orange discrets) » — testeur sensations. Un heros plus clair que
## la foule se retrouve d'un coup d'oeil sans toucher a l'art.
const BASE_TINT: Color = Color(1.16, 1.14, 1.10)

func get_layer_ok() -> bool:
	return mecha != null

func _ready() -> void:
	add_to_group("player")
	# equipped mech (garage) + persistent meta talents + EQUIPPED GEAR, applied together
	var mech: Dictionary = GameState.mech_def(SaveManager.equipped_mech())
	var gear: Dictionary = SaveManager.gear_totals()
	max_hp += GameState.meta_hp + float(mech.get("hp", 0.0)) + float(gear.get("hp", 0.0))
	damage *= (1.0 + GameState.meta_dmg) * float(mech.get("dmg", 1.0)) * (1.0 + float(gear.get("damage_pct", 0.0)))
	base_speed *= (1.0 + GameState.meta_speed) * float(mech.get("speed", 1.0)) * (1.0 + float(gear.get("speed_pct", 0.0))) * Protocols.player_speed
	crit_chance += float(mech.get("crit", 0.0)) + float(gear.get("crit", 0.0))
	hp = max_hp
	# VISUAL: the equipped mech's baked 4-direction ANIMATED sheets (idle/walk/run/attack/hit/die,
	# 8 frames each). The garage 'id' IS the DirectionalMecha chassis, so picking a mech changes
	# look AND playstyle. Facing follows the aim vector (manual aim, no auto-aim).
	var hero_id: String = SaveManager.equipped_mech()
	if not GameState.mech_def(hero_id):
		hero_id = "vortex"
	var dmech: DirectionalMecha = DirectionalMecha.new()
	dmech.chassis = hero_id
	dmech.frame_count = 8       # baked animated sheets: 8 frames per anim per facing
	dmech.display_height = 360.0   # bigger, imposing mecha (VORTEX fills ~46% of the cell -> bump)
	mecha = dmech
	add_child(mecha)
	base_chassis = hero_id
	if mecha.has_method("set_tint"):
		mecha.set_tint(BASE_TINT)   # heros legerement plus clair que la pietaille (voir BASE_TINT)

	# --- MARQUEUR DU JOUEUR ---------------------------------------------------------------
	# 🚨 Point n°1 du testeur « sensations » : a 01:29, 22 ennemis a l'ecran, « j'ai ete
	# incapable de dire ou etait mon mecha » — meme silhouette, meme taille, et les ennemis
	# sont PLUS colores que le heros. Il notait aussi que le joueur redevient trouvable des
	# qu'il ramasse le bouclier a impulsions : c'est son grand anneau cyan qui le designe.
	# On rend donc cet anneau PERMANENT et gratuit, au lieu de dependre d'une carte optionnelle.
	# 🚨 COULEUR : un premier essai en CYAN a ete verifie en capture de jeu — il se noyait
	# dans le sol du secteur TECH, qui est justement bleu-turquoise. On prend un AMBRE chaud :
	# il tranche avec le sol (froid), avec les ennemis (violet/magenta) et avec les ramassages
	# (cyan/vert), et il prolonge les liseres orange du heros.
	# 🚨 GEOMETRIE MESUREE A L'ECRAN, pas deduite de display_height.
	# Premiere version posee a y=+118 avec une ellipse de 228 px : verifiee en capture, elle
	# flottait ~130 px SOUS les pieds et faisait 2,4x la largeur du mecha. La raison :
	# `display_height = 360` decrit la CELLULE de la planche (256 px), or l'art du mecha n'en
	# occupe qu'environ un quart. Mesure faite sur capture 1280x720 (le joueur est toujours au
	# centre de l'ecran) : tete a -27, pieds a +67, largeur ~90 px. Les valeurs ci-dessous en
	# decoulent. Toute retouche du chassis ou de display_height doit refaire cette mesure.
	_mark = Sprite2D.new()
	_mark.texture = Tex.ring(Color(1.0, 0.78, 0.38), 128)
	_mark.material = Tex.add_mat()
	_mark.position = Vector2(0, 62)       # l'ellipse enjambe les pieds (mesures : pieds a +67)
	_mark.scale = Vector2(1.02, 0.36)     # ~130 px de large : un peu plus que le mecha (90 px)
	_mark.z_index = -2                    # sous le mecha, au-dessus du decor
	_mark.modulate = Color(1, 1, 1, 0.85)
	add_child(_mark)
	# second anneau, plus serre : donne du poids au marqueur sur un sol charge
	_mark_in = Sprite2D.new()
	_mark_in.texture = Tex.ring(Color(1.0, 0.92, 0.66), 128)
	_mark_in.material = Tex.add_mat()
	_mark_in.position = Vector2(0, 62)
	_mark_in.scale = Vector2(0.62, 0.23)
	_mark_in.z_index = -2
	_mark_in.modulate = Color(1, 1, 1, 0.55)
	add_child(_mark_in)
	# chevron au-dessus de la tete : lisible meme quand le sol est encombre
	_mark_top = Sprite2D.new()
	_mark_top.texture = Tex.glow(Color(1.0, 0.84, 0.48), 48)
	_mark_top.material = Tex.add_mat()
	_mark_top.position = Vector2(0, -48)   # juste au-dessus de la tete (mesuree a -27)
	_mark_top.scale = Vector2(0.82, 0.40)
	_mark_top.z_index = 6
	_mark_top.modulate = Color(1, 1, 1, 0.9)
	add_child(_mark_top)

	_weapons = WeaponSystem.new()
	add_child(_weapons)
	# Starting weapon is the player's CHOICE (hub arsenal), overriding the mech's default loadout.
	# ARME DE DEPART : le choix du joueur (ecran ARSENAL) n'est retenu que s'il appartient a la
	# gamme du chassis equipe. Sinon on retombe sur la SIGNATURE du chassis — sans quoi on
	# pourrait demarrer avec une arme que ce mecha ne sait pas manier, et qu'il ne booste pas.
	var sig: String = GameState.mech_signature(SaveManager.equipped_mech())
	var gamme: Array = GameState.mech_arsenal(SaveManager.equipped_mech())
	var start_w: String = SaveManager.start_weapon()
	if not (SaveManager.weapon_unlocked(start_w) and gamme.has(start_w)):
		start_w = sig
	var loadout: Array = [start_w]
	_weapons.setup(self, loadout)   # chosen starter weapon
	_weapons.visuals_hidden = true   # NO held-gun sprite (it read as badly grafted on the body). The mech
	# AIMS with its arm and fires a beam/muzzle from the hand toward the target ("Buzz Lightyear" style):
	# the attack pose points the arm forward, the body turns to the target, and the laser+muzzle emit from
	# the grip. Firing/muzzle math still runs (see WeaponSystem, show_wp=false but muzzle_global is computed).
	_weapons.fired.connect(_on_weapon_fired)
	# AUTO-VISEE : on lit le REGLAGE du joueur (defaut ON, facon Survivor.io -> le mecha vise
	# l'ennemi le plus proche, le corps tourne vers lui et s'anime).
	# 🚨 il y avait ici « auto_aim = true   # TEST » : la bascule du menu s'appliquait a chaud
	# puis la partie suivante repartait FORCEE sur ON, sans rien dire. Le reglage est desormais
	# reellement respecte au demarrage de chaque partie.
	auto_aim = bool(SaveManager.setting("auto_aim", true))

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

	# TERMINATOR targeting sight — DISCREET: a thin cyan thread from the eye that FADES OUT with distance
	# (gradient), so it hints the aim without a glaring full-screen line. A small soft dot marks the target.
	# 🚨 il etait ROUGE et large de 1 px : « quasi invisible, et le rouge est la couleur du
	# danger : on croit un instant a un tir ennemi » (testeur sensations). Passe en cyan —
	# la famille de couleur du joueur — et epaissi pour etre lu sans crier.
	_laser = Line2D.new()
	_laser.width = 2.6
	var lc: Color = Color(0.55, 0.93, 1.0)
	_laser.default_color = Color(lc.r, lc.g, lc.b, 1.0)
	var lg: Gradient = Gradient.new()
	lg.set_color(0, Color(lc.r, lc.g, lc.b, 0.62))   # faint at the eye
	lg.set_color(1, Color(lc.r, lc.g, lc.b, 0.0))    # gone by the far end
	lg.add_point(0.32, Color(lc.r, lc.g, lc.b, 0.20))  # most of the fade happens early -> short visible thread
	_laser.gradient = lg
	var lm: CanvasItemMaterial = CanvasItemMaterial.new()
	lm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_laser.material = lm
	_laser.z_index = 8
	_laser.add_point(Vector2.ZERO)
	_laser.add_point(Vector2.ZERO)
	add_child(_laser)

	_laser_dot = Sprite2D.new()
	_laser_dot.texture = Tex.glow(Color(0.62, 0.95, 1.0), 26)   # cyan, comme le fil (voir plus haut)
	var dm: CanvasItemMaterial = CanvasItemMaterial.new()
	dm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_laser_dot.material = dm
	_laser_dot.modulate = Color(1, 1, 1, 0.5)
	_laser_dot.z_index = 8
	add_child(_laser_dot)

	# the emitting EYE: a small glow at the head where the sight starts (cyan, pas rouge)
	_laser_eye = Sprite2D.new()
	_laser_eye.texture = Tex.glow(Color(0.58, 0.94, 1.0), 20)
	var em: CanvasItemMaterial = CanvasItemMaterial.new()
	em.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_laser_eye.material = em
	_laser_eye.modulate = Color(1, 1, 1, 0.8)
	_laser_eye.z_index = 9
	_laser_eye.visible = false
	add_child(_laser_eye)

	# OVERDRIVE BEAM — dark-premium: a CRACKLING lance, not a flat line. Three stacked additive
	# layers (wide halo / cyan body / razor white-hot core) all tracing the SAME jittered polyline,
	# so the beam reads as living energy. Built with BEAM_PTS points; _process_beam animates them.
	_beam_glow = _mk_beam_line(42.0, Color(0.10, 0.45, 1.0, 0.26), 2)   # deep blue halo
	_beam = _mk_beam_line(13.0, Color(0.25, 0.80, 1.0, 0.75), 3)        # cyan body
	_beam_core = _mk_beam_line(3.5, Color(0.85, 0.99, 1.0, 1.0), 4)     # thin white filament
	for i in BEAM_ARCS:
		_beam_arc_list.append(_mk_beam_arc())

	_beam_dot = Sprite2D.new()
	_beam_dot.texture = Tex.glow(Color(0.5, 0.9, 1.0), 80)
	var bdm: CanvasItemMaterial = CanvasItemMaterial.new()
	bdm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam_dot.material = bdm
	_beam_dot.z_index = 3
	_beam_dot.visible = false
	add_child(_beam_dot)

	# Both beam glows are additive sprites, not Light2D. They are only two nodes, but they burn
	# during Overdrive — precisely the moment the screen is already saturated with effects, which
	# is when the stutter was reported.
	_beam_light = Sprite2D.new()
	_beam_light.texture = Tex.glow(Color(0.7, 0.97, 1.0), 128)
	_beam_light.material = Tex.add_mat()
	_beam_light.modulate = Color(0.6, 0.95, 1.0, 0.62)
	_beam_light.scale = Vector2.ONE * 1.5
	_beam_light.visible = false
	add_child(_beam_light)

	# the emitter end glows too — without this the lance looks like it starts from nothing
	_beam_muzzle_light = Sprite2D.new()
	_beam_muzzle_light.texture = Tex.glow(Color(0.75, 0.98, 1.0), 128)
	_beam_muzzle_light.material = Tex.add_mat()
	_beam_muzzle_light.modulate = Color(0.6, 0.95, 1.0, 0.75)
	_beam_muzzle_light.scale = Vector2.ONE * 1.1
	_beam_muzzle_light.visible = false
	add_child(_beam_muzzle_light)

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
	_update_marker(delta)
	var alive_now: bool = GameState.alive
	if not alive_now:
		_laser.visible = false
		_laser_dot.visible = false
		if _laser_eye != null:
			_laser_eye.visible = false
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
		GameState.overdrive_time += delta   # diagnostic: invincible uptime must stay a small fraction
		if _tf_t <= 0.0:
			_transform_off()
	else:
		GameState.tick_overdrive_cd(delta)

	_iframe = maxf(0.0, _iframe - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	field_slow = minf(1.0, field_slow + delta * 2.5)   # recover when out of a slow field
	# MAJ = esquive au clavier (l'espace sert deja a la SURCHARGE)
	var sh: bool = Input.is_key_pressed(KEY_SHIFT)
	if sh and not _shift_was:
		dash(_move_input())
	_shift_was = sh
	var mv: Vector2 = _move_input()
	if _dash_t > 0.0:
		_dash_t -= delta
		# pendant la ruee on ignore l'entree : la direction est verrouillee au declenchement,
		# sinon on pourrait s'arreter en plein elan et l'esquive ne vaudrait rien.
		velocity = _dash_dir * base_speed * DASH_MULT * field_slow
	else:
		velocity = mv * base_speed * move_mult * field_slow * (2.0 if transformed else 1.0)   # Overdrive = x2 speed
	move_and_slide()
	global_position.x = clampf(global_position.x, arena.position.x, arena.end.x)
	global_position.y = clampf(global_position.y, arena.position.y, arena.end.y)

	_firing_t = maxf(0.0, _firing_t - delta)
	_melee_t = maxf(0.0, _melee_t - delta)
	if mv.length() > 0.1:
		# MOVING always walks/runs — movement wins so the mech never freezes mid-stride. The walk
		# sheet now carries a raised combat guard (arms/cannons up), so strafing already reads as
		# "fighting while on the move".
		_thruster.emitting = true
		_thruster.direction = -mv
		# run is reserved for Overdrive; a fixed 360 threshold on an ever-growing base_speed
		# makes the walk sheet unreachable after ~2 speed upgrades, so gate on transform.
		var want: String = "run" if transformed else "walk"
		if _melee_t <= 0.0 and mecha.current_anim() != want:
			mecha.play(want)
	else:
		# STANDING: play the AIM/shoot pose (cannons thrust forward) WHILE FIRING, else calm idle.
		# The new bluestrike 'attack' bake is a clean LOOPING aim cycle (not the old self-moving
		# lunge), so it reads as "trained on the enemy" the whole time the guns are live.
		_thruster.emitting = false
		if _melee_t <= 0.0:
			var wa: String = "attack" if _firing_t > 0.0 else "idle"
			if mecha.current_anim() != wa:
				mecha.play(wa)

	_update_aim()
	# BODY faces the TARGET whenever it is FIRING (which is almost always, thanks to auto-fire) so it
	# never "shoots from its back" while strafing — it turns to face what it shoots (twin-stick / Buzz
	# Lightyear feel). Only when NOT firing does it face its movement direction. The 4-dir hysteresis in
	# set_facing_from keeps this from jittering between two equidistant foes.
	# while the Overdrive beam is out, the arm IS attacking -> face the aim too (so the beam
	# leaves the cannon tip pointed at the target, never from the back).
	mecha.set_facing_from(aim_dir if (_firing_t > 0.0 or transformed) else mv)
	# NO body tilt: a mech stays PLANTED on its feet — it faces the target in 4 dir and the head-laser
	# shows the exact aim; it does not rock/pitch toward the aim (that read as a "dancer", not a mech).
	if mecha.has_method("set_lean_target"):
		mecha.set_lean_target(0.0)
	_update_helpers(delta)
	_update_slash(delta)

	if transformed:
		if _od_aura != null:
			var ta: float = Time.get_ticks_msec() / 1000.0
			_od_aura.scale = Vector2.ONE * (2.3 + 0.3 * sin(ta * 6.0))
			_od_aura.modulate = Color(1, 1, 1, 0.55 + 0.2 * sin(ta * 6.0))
		_weapons.set_active(false)
		_laser.visible = false
		_laser_dot.visible = false
		if _laser_eye != null:
			_laser_eye.visible = false
		_process_beam(delta)
	else:
		_hide_beam()
		_weapons.set_active(true)
		if _weapons != null:
			# SYNC: the red targeting laser is drawn from the GUN MUZZLE — the exact spot and
			# direction the bullets leave — so the shot rides along the visible beam. It used to
			# emit from the HEAD, so bullets travelled parallel-but-offset from the sight (looked
			# out of sync). The head keeps a red "eye" glow (Terminator look), just not as the origin.
			var origin: Vector2 = to_local(_weapons.muzzle_global)
			_laser.set_point_position(0, origin)
			_laser.set_point_position(1, origin + aim_dir * 900.0)   # thread fades out with distance (gradient)
			if _laser_eye != null:
				if mecha != null and mecha.has_method("head_anchor") and mecha.has_head_anchor():
					_laser_eye.position = mecha.head_anchor()
				else:
					_laser_eye.position = origin
				_laser_eye.visible = true
			_laser.visible = true
			# a faint reticle painted on the actual target enemy, not a floating dot in empty space
			var tgt: Node2D = _nearest_enemy()
			if tgt != null and is_instance_valid(tgt):
				_laser_dot.position = to_local(tgt.global_position)
				_laser_dot.visible = true
			else:
				_laser_dot.visible = false

func add_weapon(id: String) -> void:
	if _weapons != null:
		_weapons.add_weapon(id)

func weapons() -> WeaponSystem:
	return _weapons

func _on_weapon_fired(_muzzle: Vector2) -> void:
	_firing_t = 0.36   # standing shoot-pose window
	if mecha != null and mecha.has_method("recoil"):
		mecha.recoil()
	# The MUZZLE/CAST effect is spawned PER WEAPON in WeaponSystem._do_fire (each weapon has its
	# own dark-premium effect + accent colour) -> no shared flash here anymore.

# --- Damaging shield aura (draftable, radius grows each time it's chosen) ---
func add_aura() -> void:
	aura_level += 1
	if aura_level == 1:
		aura_radius = 92.0        # sensible first size (reaches just past the mech), not huge
	else:
		aura_radius += 40.0       # gentle growth per extra pick
	aura_dmg += 2.0
	if _aura_spr == null:
		# DOME: a filled energy sphere that ENVELOPS the mech (not a bare circle) — low-alpha
		# additive fill under the mech, bright rim over it, so the two together read as a bubble.
		_aura_dome = Sprite2D.new()
		_aura_dome.texture = preload("res://assets/vfx/shield_bubble.png")
		_aura_dome.modulate = Color(0.5, 0.9, 1.0)
		_aura_dome.material = Tex.add_mat()
		_aura_dome.z_index = -1
		add_child(_aura_dome)
		_aura_spr = Sprite2D.new()
		_aura_spr.texture = preload("res://assets/vfx/shield_bubble.png")   # bulle fresnel (membrane)
		_aura_spr.modulate = Color(0.6, 0.97, 1.0)
		_aura_spr.material = Tex.add_mat()
		_aura_spr.z_index = 3                                        # rim OVER the mech = enveloping
		add_child(_aura_spr)

# --- Companion drone (draftable, stackable): orbits and auto-fires at foes ---
func add_drone() -> void:
	# VISUEL PREMIUM (comme les missiles) : vrai sprite de drone genere (gunmetal + reacteur cyan)
	# au lieu du blob neon. Il s'oriente vers sa cible (canon a droite du sprite).
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = preload("res://assets/equip/drone.png")
	spr.scale = Vector2(0.46, 0.46)
	spr.z_index = 3
	add_child(spr)
	_drones.append({"spr": spr, "ang": randf() * TAU, "cd": randf_range(0.0, 0.6), "face": 0.0})

# --- Lame orbitale (draftable, stackable) : tourne autour du mecha, tranche au CONTACT (facon Bible/VS) ---
func add_blade() -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = preload("res://assets/equip/blade.png")
	spr.scale = Vector2(0.62, 0.62)
	spr.z_index = 3
	add_child(spr)
	_blades.append({"spr": spr, "ang": randf() * TAU})

# --- Orbe plasma charge/decharge (draftable, stackable) : orbite, se CHARGE (grossit/brille), puis
#     DECHARGE une onde AoE sur les ennemis proches (ton mecanisme charge/decharge facon Survivor.io) ---
func add_orb() -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = preload("res://assets/equip/orb.png")
	spr.scale = Vector2(0.5, 0.5)
	spr.z_index = 3
	add_child(spr)
	_orbs.append({"spr": spr, "ang": randf() * TAU, "t": 1.4})   # t = temps avant decharge

# --- ARC TESLA (active, stackable) : eclair qui saute d'ennemi en ennemi (role Lightning, maison) ---
func add_arc() -> void:
	_arc_lv += 1

func _cast_arc() -> void:
	var start: Node2D = _nearest_enemy()
	if start == null:
		_arc_t = 0.25
		return
	var jumps: int = 2 + _arc_lv                 # +1 saut par niveau
	var jump_r2: float = 300.0 * 300.0
	var hit: Array = [start]
	var cur: Node2D = start
	var prev_pos: Vector2 = global_position
	for j in jumps:
		var isc: bool = randf() < crit_chance
		var dm: float = damage * 0.7 * (crit_mult if isc else 1.0)
		(cur as Enemy).take_damage(dm)
		if isc:
			Events.damage_dealt.emit(cur.global_position, int(dm), true)
		_zap(prev_pos, cur.global_position)
		prev_pos = cur.global_position
		var nxt: Node2D = null
		var bd: float = jump_r2
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and (e as Enemy).alive and not hit.has(e):
				var dd: float = cur.global_position.distance_squared_to((e as Node2D).global_position)
				if dd < bd:
					bd = dd; nxt = e as Node2D
		if nxt == null:
			break
		hit.append(nxt); cur = nxt

func _zap(a: Vector2, b: Vector2) -> void:
	if game == null:
		return
	# Un eclair, ce n'est pas UN trait : c'est un halo large, un corps, et un coeur blanc
	# surimposes, plus une decharge aux deux extremites. Trois couches pour ~rien en cout.
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 7
	for k in n + 1:
		var p: Vector2 = a.lerp(b, float(k) / float(n))
		if k > 0 and k < n:
			p += Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
		pts.append(p)
	var layers: Array = [
		[16.0, Color(0.25, 0.65, 1.0, 0.30)],   # halo diffus
		[7.0,  Color(0.65, 0.95, 1.0, 0.85)],   # corps
		[2.4,  Color(1.0, 1.0, 1.0, 1.0)],      # coeur blanc
	]
	for L in layers:
		var ln: Line2D = Line2D.new()
		ln.top_level = true
		ln.z_index = 8
		ln.material = Tex.add_mat()
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.width = float(L[0])
		ln.default_color = Color(L[1])
		ln.points = pts
		game.add_child(ln)
		var tw: Tween = ln.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ln, "modulate:a", 0.0, 0.20)
		tw.tween_property(ln, "width", ln.width * 0.35, 0.20)
		tw.set_parallel(false)
		tw.tween_callback(ln.queue_free)
	# decharge aux deux bouts : le depart claque, l'arrivee encaisse
	if game.has_method("spawn_vfx"):
		game.spawn_vfx("elec_beam", a, (b - a).angle(), 0.22, Color(0.7, 0.95, 1.0))
		game.spawn_vfx("aaa_impact", b, 0.0, 0.34, Color(0.6, 0.92, 1.0))

# --- BRASIER (active, stackable) : lache une mare de plasma au sol (role Molotov, maison) ---
func add_pool() -> void:
	_pool_lv += 1

func _cast_pool() -> void:
	if game == null:
		return
	var tgt: Node2D = _nearest_enemy()
	var pos: Vector2 = tgt.global_position if tgt != null else global_position + aim_dir * 150.0
	var pool: PlasmaPool = PlasmaPool.new()
	pool.radius = (86.0 + 8.0 * float(_pool_lv)) * size_mult
	pool.dmg = damage * 0.45
	pool.life = 3.0 + 0.3 * float(_pool_lv)
	pool.color = Color(0.45, 0.9, 1.0)
	pool.crit_chance = crit_chance; pool.crit_mult = crit_mult
	if "enemy_layer" in game and game.enemy_layer != null:
		game.enemy_layer.add_child(pool)
	else:
		game.add_child(pool)
	pool.global_position = pos

func _update_helpers(delta: float) -> void:
	# REGEN PV (Energy Drink)
	if hp_regen > 0.0 and hp < max_hp and GameState.alive:
		hp = minf(max_hp, hp + hp_regen * delta)
		Events.player_damaged.emit(hp, max_hp)
	# SHIELD BUBBLE — charges then discharges instead of sitting there permanently. The dome dims
	# right after a pulse (recharging) and brightens/swells as the next discharge nears (charging),
	# then flares with an expanding shockwave on the damage tick.
	if aura_level > 0 and _aura_spr != null:
		const AURA_CYCLE: float = 0.7
		var diam: float = aura_radius * 2.0
		var p: float = 1.0 - clampf(_aura_t / AURA_CYCLE, 0.0, 1.0)   # 0 just after a pulse -> 1 about to fire
		var breathe: float = 0.95 + 0.05 * sin(Time.get_ticks_msec() / 170.0)
		_aura_flash = maxf(0.0, _aura_flash - delta * 3.0)
		# TAILLE = reglages patron (editeur, x0.60), basee sur la taille du MECHA (pas le rayon de degats)
		var mbase: float = 360.0
		if mecha != null and "display_height" in mecha:
			mbase = float(mecha.display_height)
		var aw: float = mbase * 1.194                       # 1.99 x 0.60
		var ah: float = mbase * 1.20                        # 2.00 x 0.60
		var apos: Vector2 = Vector2(mbase * -0.006, mbase * -0.012)   # ox/oy x 0.60
		var at: Color = Color("6ad0ff")
		# dome (couche fond) : faible en recharge, gonfle+brille en charge, eclate a la decharge
		_aura_dome.scale = Vector2(aw, ah) / 1024.0 * breathe * (0.9 + 0.1 * p)
		_aura_dome.position = apos
		_aura_dome.modulate = Color(at.r, at.g, at.b, 0.4 * (0.55 + 0.45 * p) + _aura_flash * 0.5)
		# membrane (couche avant) qui tourne, un peu plus grande (ecart 1.06)
		_aura_spr.scale = Vector2(aw, ah) / 1024.0 * 1.06 * (1.0 + 0.04 * p)
		_aura_spr.position = apos
		_aura_spr.rotation += delta * 0.6
		_aura_spr.modulate = Color(at.r, at.g, at.b, 0.55 * (0.6 + 0.4 * p) + _aura_flash * 0.6)
		_aura_t -= delta
		if _aura_t <= 0.0:
			_aura_t = AURA_CYCLE
			_aura_flash = 1.0   # discharge
			if game != null and game.has_method("aura_discharge_fx"):
				game.aura_discharge_fx(global_position, aura_radius, Color(0.6, 0.97, 1.0))
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
		# orientation : face la derniere cible visee, sinon tangent a l'orbite (sens de deplacement)
		sp.rotation = float(d.get("face", 0.0)) if float(d.get("face", 0.0)) != 0.0 else float(d["ang"]) + PI * 0.5
		d["cd"] = float(d["cd"]) - delta
		if float(d["cd"]) <= 0.0:
			var tgt: Node2D = _nearest_enemy()
			if tgt != null and game != null and game.has_method("spawn_shot"):
				d["cd"] = 0.7
				var mw: Vector2 = global_position + sp.position
				var dir: Vector2 = (tgt.global_position - mw).normalized()
				d["face"] = dir.angle()   # le drone reste tourne vers sa derniere cible
				game.spawn_shot(mw, dir, {"dmg": damage * 0.5, "speed": 760.0,
					"color": Color(0.5, 0.95, 1.0), "impact": "drone",
					"crit_chance": crit_chance, "crit_mult": crit_mult})
	# --- LAMES orbitales : tournent vite autour du mecha, degats de CONTACT (tick periodique) ---
	if not _blades.is_empty():
		_blade_tick = maxf(0.0, _blade_tick - delta)
		var do_hit: bool = _blade_tick <= 0.0
		if do_hit:
			_blade_tick = 0.18
		var bdmg: float = damage * 0.85
		var brad2: float = pow(46.0 * size_mult, 2.0)   # HE Fuel agrandit la lame
		for i in _blades.size():
			var b: Dictionary = _blades[i]
			b["ang"] = float(b["ang"]) + delta * 3.4                # spin rapide
			var br: float = 130.0 + float(i % 3) * 22.0
			var bs: Sprite2D = b["spr"]
			var bang: float = float(b["ang"])
			bs.position = Vector2(cos(bang), sin(bang)) * br
			bs.rotation = bang + PI * 0.5                           # tranchant vers l'exterieur
			if do_hit:
				var bw: Vector2 = global_position + bs.position
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Enemy and e.alive and bw.distance_squared_to((e as Node2D).global_position) <= brad2:
						var bc: bool = randf() < crit_chance
						var bd: float = bdmg * (crit_mult if bc else 1.0)
						(e as Enemy).take_damage(bd)
						if bc: Events.damage_dealt.emit((e as Node2D).global_position, int(bd), true)
	# --- ORBES charge/decharge : orbitent, CHARGENT (grossit/brille), puis DECHARGE une onde AoE ---
	if not _orbs.is_empty():
		var orb_cycle: float = 1.6
		var orad: float = 150.0 * size_mult   # HE Fuel agrandit l'onde de l'orbe
		var odmg: float = damage * 1.7
		for i in _orbs.size():
			var o: Dictionary = _orbs[i]
			o["ang"] = float(o["ang"]) + delta * 0.9
			var osp: Sprite2D = o["spr"]
			osp.position = Vector2(cos(o["ang"]), sin(o["ang"])) * (176.0 + float(i % 3) * 20.0)
			osp.rotation += delta * 2.0
			o["t"] = float(o["t"]) - delta
			var op: float = 1.0 - clampf(float(o["t"]) / orb_cycle, 0.0, 1.0)   # 0->1 = charge
			osp.scale = Vector2.ONE * (0.42 + 0.30 * op)                        # grossit en chargeant
			osp.modulate = Color(1, 1, 1, 0.72 + 0.28 * op)
			if float(o["t"]) <= 0.0:
				o["t"] = orb_cycle
				var ow: Vector2 = global_position + osp.position
				if game != null and game.has_method("aura_discharge_fx"):
					game.aura_discharge_fx(ow, orad, Color(0.4, 0.9, 1.0))
				var or2: float = orad * orad
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Enemy and e.alive and ow.distance_squared_to((e as Node2D).global_position) <= or2:
						var oc: bool = randf() < crit_chance
						var od: float = odmg * (crit_mult if oc else 1.0)
						(e as Enemy).take_damage(od)
						if oc: Events.damage_dealt.emit((e as Node2D).global_position, int(od), true)
	# --- ARC TESLA : chaine d'eclairs periodique ---
	if _arc_lv > 0:
		_arc_t -= delta
		if _arc_t <= 0.0:
			_arc_t = maxf(0.55, 1.35 - 0.09 * float(_arc_lv))   # cadence monte avec le niveau
			_cast_arc()
	# --- BRASIER : mare de plasma periodique ---
	if _pool_lv > 0:
		_pool_t -= delta
		if _pool_t <= 0.0:
			_pool_t = maxf(0.85, 1.9 - 0.12 * float(_pool_lv))
			_cast_pool()

# --- Melee saber flare: the mech's blade sparks wherever it touches something solid, be it a
# foe or a piece of decor. Purely a read (no damage): contact damage stays the enemy's job.
# Throttled so grinding against a crowd flares at a readable cadence instead of every frame.
const _SLASH_CD: float = 0.24
const _SLASH_PAD: float = 16.0
const _BODY_R: float = 26.0
var _slash_cd: float = 0.0
var _melee_t: float = 0.0   # >0 locks the body to the one-shot melee swing (so walk/idle/attack don't override it)

func _update_slash(delta: float) -> void:
	_slash_cd = maxf(0.0, _slash_cd - delta)
	if _slash_cd > 0.0 or game == null or not game.has_method("spawn_vfx"):
		return
	var target: Vector2 = Vector2.ZERO
	var found: bool = false
	var e: Node2D = _nearest_enemy()
	if e != null and is_instance_valid(e) and "_body_radius" in e and "alive" in e and e.alive:
		if global_position.distance_to(e.global_position) < _BODY_R + float(e._body_radius) + _SLASH_PAD:
			target = e.global_position
			found = true
	if not found and "cover_list" in game:
		for c in game.cover_list:
			if not is_instance_valid(c):
				continue
			var cn: Node2D = c as Node2D
			if global_position.distance_to(cn.global_position) < _BODY_R + float(c.block_r) + _SLASH_PAD:
				target = cn.global_position
				found = true
				break
	if not found:
		return
	_slash_cd = _SLASH_CD
	var dir: Vector2 = (target - global_position).normalized()
	if dir == Vector2.ZERO:
		return
	# play the melee swing pose (arm/blade arc) and lock the body to it for the swing's duration
	if mecha != null:
		mecha.set_facing_from(dir)
		mecha.play("melee")
		_melee_t = 0.34
	game.spawn_vfx("slash", global_position + dir * 42.0, dir.angle() + PI * 0.5, 0.8,
		Color(0.75, 1.0, 1.0))

## Additive Line2D used as one layer of the overdrive lance. A uniform-width, single-colour
## line reads as a flat streak — so every layer gets a WIDTH CURVE (bulges at the emitter,
## tapers to the tip) and a GRADIENT (white-hot at the muzzle -> accent cyan at range).
func _mk_beam_line(w: float, col: Color, z: int) -> Line2D:
	var l: Line2D = Line2D.new()
	l.width = w
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = m
	l.z_index = z
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	var wc: Curve = Curve.new()
	wc.add_point(Vector2(0.0, 1.1))
	wc.add_point(Vector2(0.4, 1.0))
	wc.add_point(Vector2(1.0, 0.5))     # tapers to a point at range
	l.width_curve = wc
	# Each layer keeps ITS OWN hue for the whole run and only fades toward the tip. Only the
	# thin core is white — if the halo and body were white too, the three additive layers
	# would stack into one blown-out white band (which is exactly the flat streak we're fixing).
	var g: Gradient = Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, col.a * 0.55))
	l.gradient = g
	for i in BEAM_PTS:
		l.add_point(Vector2.ZERO)
	l.visible = false
	add_child(l)
	return l

## Short branching discharges that fork off the lance — the real "crackling" tell.
func _mk_beam_arc() -> Line2D:
	var l: Line2D = Line2D.new()
	l.width = 3.0
	l.default_color = Color(0.85, 1.0, 1.0, 0.9)
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = m
	l.z_index = 4
	for i in 4:
		l.add_point(Vector2.ZERO)
	l.visible = false
	add_child(l)
	return l

func _process_beam(delta: float) -> void:
	_beam_t += delta
	# start the overdrive lance from the arm-cannon TIP (same anchor as the normal laser/muzzle),
	# not the mech centre — WeaponSystem keeps muzzle_global fresh every frame even when inactive.
	var start: Vector2 = aim_dir * 46.0
	if _weapons != null and _weapons.muzzle_global != Vector2.ZERO:
		start = to_local(_weapons.muzzle_global)
	var end: Vector2 = start + aim_dir * BEAM_LEN
	var perp: Vector2 = aim_dir.orthogonal()

	# Trace one jittered polyline; every layer follows it so the crackle is coherent.
	# Jitter tapers to zero at both ends (anchored at the emitter and at the tip).
	for i in BEAM_PTS:
		var t: float = float(i) / float(BEAM_PTS - 1)
		var taper: float = sin(t * PI)                       # anchored at emitter and tip
		var base: Vector2 = start.lerp(end, t)
		# body: fast high-frequency crackle
		var n: float = sin(t * 34.0 + _beam_t * 30.0) * 0.55 + sin(t * 13.0 - _beam_t * 19.0) * 0.45
		_beam.set_point_position(i, base + perp * (n * BEAM_JITTER * taper))
		# halo: slower, wider wander -> the glow doesn't lock to the body
		var ng: float = sin(t * 9.0 - _beam_t * 11.0)
		_beam_glow.set_point_position(i, base + perp * (ng * BEAM_JITTER * 0.4 * taper))
		# core: PHASE-OFFSET so the white-hot centre weaves inside the body instead of
		# tracing it exactly — that counter-motion is what makes it read as live energy.
		var nc: float = sin(t * 34.0 + _beam_t * 30.0 + 2.1) * 0.6 + sin(t * 21.0 + _beam_t * 26.0) * 0.4
		_beam_core.set_point_position(i, base + perp * (nc * BEAM_JITTER * 0.55 * taper))

	# width pulse — the lance breathes instead of sitting at a dead constant
	var pulse: float = 1.0 + 0.14 * sin(_beam_t * 30.0)
	_beam_glow.width = 38.0 * (1.0 + 0.10 * sin(_beam_t * 18.0 + 1.1))
	_beam.width = 15.0 * pulse
	_beam_core.width = 4.5 * (1.0 + 0.22 * sin(_beam_t * 42.0))
	_beam_glow.visible = true
	_beam.visible = true
	_beam_core.visible = true

	_beam_dot.position = end
	_beam_dot.scale = Vector2.ONE * (1.0 + 0.18 * sin(_beam_t * 26.0))
	_beam_dot.visible = true

	# the crackle pulse now rides alpha instead of Light2D.energy (same read, no dynamic light)
	_beam_light.position = end
	_beam_light.modulate.a = 0.52 + 0.13 * sin(_beam_t * 22.0)
	_beam_light.visible = true

	_beam_muzzle_light.position = start
	_beam_muzzle_light.modulate.a = 0.62 + 0.13 * sin(_beam_t * 28.0)
	_beam_muzzle_light.visible = true

	# branching discharges: every few frames each arc re-snaps to a random spot along the
	# lance and forks out perpendicular. Re-rolled (not tweened) so they read as electric.
	_beam_arc_t -= delta
	var reroll: bool = _beam_arc_t <= 0.0
	if reroll:
		_beam_arc_t = 0.055
	for a in _beam_arc_list:
		var arc: Line2D = a as Line2D
		if reroll:
			var t0: float = randf_range(0.08, 0.92)
			var root: Vector2 = start.lerp(end, t0)
			var side: float = 1.0 if randf() < 0.5 else -1.0
			var run: Vector2 = root
			arc.set_point_position(0, run)
			for k in range(1, 4):
				run += aim_dir * randf_range(10.0, 26.0) + perp * side * randf_range(9.0, 22.0)
				side *= -1.0                       # zig-zag
				arc.set_point_position(k, run)
			arc.visible = randf() < 0.75           # flicker: not every arc every beat
		if arc.visible:
			arc.modulate = Color(1, 1, 1, randf_range(0.45, 1.0))

	# periodic discharge bursts at the emitter — the AAA sprites do the heavy lifting
	_beam_fx_t -= delta
	if _beam_fx_t <= 0.0 and game != null and game.has_method("spawn_vfx"):
		_beam_fx_t = 0.085
		game.spawn_vfx("aaa_muzzle", global_position + start, aim_dir.angle(), 0.34,
			Color(0.75, 1.5, 1.9))
		Events.screen_shake.emit(0.5)

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
					# the lance BURNS where it lands: bloomed impact + sparks, not a flat pixel
					if randf() < 0.22 and game != null and game.has_method("spawn_vfx"):
						game.spawn_vfx("aaa_impact", ep, 0.0, 0.3, Color(0.8, 1.6, 2.0))
					elif randf() < 0.3:
						Events.hit_spark.emit(ep, Color(0.6, 0.95, 1.0))

func _hide_beam() -> void:
	if _beam != null:
		_beam.visible = false
	if _beam_glow != null:
		_beam_glow.visible = false
	if _beam_core != null:
		_beam_core.visible = false
	for a in _beam_arc_list:
		(a as Line2D).visible = false
	if _beam_dot != null:
		_beam_dot.visible = false
	if _beam_light != null:
		_beam_light.visible = false
	if _beam_muzzle_light != null:
		_beam_muzzle_light.visible = false

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
	GameState.overdrive_count += 1
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
	GameState.overdrive_cd = GameState.OVERDRIVE_COOLDOWN   # vulnerable stretch before the next spike
	if mecha.has_method("set_tint"):
		mecha.set_tint(BASE_TINT)   # on revient a la teinte du heros, pas au blanc neutre
	if _od_aura != null:
		_od_aura.visible = false
	if game != null and game.has_method("transform_fx"):
		game.transform_fx(global_position, false)
	Events.player_transformed.emit(false)

func _update_aim() -> void:
	# AUTO-AIM (player opt-in via settings, or the CI bot) has ABSOLUTE priority — checked first so
	# it keeps locking the nearest foe WHILE YOU MOVE. Before, the aim-stick check ran first, so a
	# stray finger on the aim side (common while thumbing the move stick) silently cancelled it.
	if auto_aim or bot_active:
		var t: Node2D = _nearest_enemy()
		if t != null:
			aim_dir = (t.global_position - global_position).normalized()
		else:
			var amv: Vector2 = _move_input()   # no foe on the map -> face where we move
			if amv.length() > 0.1:
				aim_dir = amv.normalized()
		if aim_dir == Vector2.ZERO:
			aim_dir = Vector2.DOWN
		return
	# MANUAL (default, no auto-aim): the right aim-stick (touch) or a held mouse button aims freely;
	# otherwise the mech shoots where it moves. Keep the last dir when idle so it doesn't spin.
	if _aim_stick_id != -1:
		return   # aim_dir already set from the aim-stick drag in _unhandled_input
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var m: Vector2 = (get_global_mouse_position() - global_position).normalized()
		if m != Vector2.ZERO:
			aim_dir = m
		return
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
		# QWERTY (WASD) *et* AZERTY (ZQSD) : le testeur a mesure 0,00 de deplacement sur 5 s
		# avec z/q, seules les fleches et WASD repondaient.
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q): kb.x -= 1.0
		if Input.is_key_pressed(KEY_D): kb.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z): kb.y -= 1.0
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
			_flick_from = e.position
			_flick_ms = Time.get_ticks_msec()
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
			# COUP DE POUCE : on mesure depuis une origine RE-ANCREE en continu. Sans ce
			# re-ancrage, n'importe quel deplacement long finirait par depasser le seuil et
			# declencherait une esquive involontaire.
			var ms: int = Time.get_ticks_msec()
			if _flick_from.distance_to(e.position) >= FLICK_PX and (ms - _flick_ms) <= FLICK_MS:
				dash(e.position - _flick_from)
				_flick_from = e.position
				_flick_ms = ms
			elif (ms - _flick_ms) > FLICK_MS:
				_flick_from = e.position
				_flick_ms = ms
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

## Marqueur du joueur + FLASH ROUGE a l'encaissement.
## 🚨 L'animation « hit » existante n'etait jouee QUE si le joueur etait immobile (pour ne pas
## hacher le cycle de marche) — dans un survivor-like on bouge en permanence, donc elle ne se
## declenchait JAMAIS. Et l'onde de blessure est CYAN, la couleur de nos propres tirs. Resultat
## mesure : « 8 % de vie ressemble a 100 % ». Ici le chassis vire au rouge vif, en mouvement compris.
func _update_marker(delta: float) -> void:
	var pulse: float = sin(Time.get_ticks_msec() / 380.0)
	if _mark != null:
		_mark.modulate.a = 0.74 + 0.16 * pulse
		_mark.visible = GameState.alive
	if _mark_in != null:
		_mark_in.modulate.a = 0.46 + 0.14 * pulse
		_mark_in.visible = GameState.alive
	if _mark_top != null:
		_mark_top.modulate.a = 0.76 + 0.18 * pulse
		_mark_top.visible = GameState.alive
	if _hurt_t > 0.0 and not transformed:
		_hurt_t = maxf(0.0, _hurt_t - delta)
		if mecha != null and mecha.has_method("set_tint"):
			var f: float = _hurt_t / 0.30
			mecha.set_tint(BASE_TINT.lerp(Color(2.6, 0.48, 0.40), clampf(f, 0.0, 1.0)))

## Ruee dans `dir` (ou dans la visee si le joueur est a l'arret). Invulnerable pendant la
## ruee : une esquive qui ne traverse pas ne sort de rien.
func dash(dir: Vector2) -> void:
	# `-- --no-dash` : banc de mesure uniquement, pour comparer le jeu AVEC et SANS esquive
	# dans des conditions par ailleurs identiques.
	if OS.get_cmdline_user_args().has("--no-dash"):
		return
	if _dash_cd > 0.0 or _dash_t > 0.0 or not GameState.alive or transformed:
		return
	var d: Vector2 = dir
	if d.length() < 0.15:
		d = aim_dir if aim_dir != Vector2.ZERO else Vector2.RIGHT
	_dash_dir = d.normalized()
	_dash_t = DASH_DUR
	_dash_cd = DASH_CD
	grant_invuln(DASH_IFRAME)
	Audio.sfx("overdrive", 0.18)   # souffle de propulseur : il n'y a pas de son « dash » dedie
	if mecha != null and mecha.has_method("set_facing_from"):
		mecha.set_facing_from(_dash_dir)
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("shockwave", global_position, 0.0, 0.5, Color(0.65, 0.95, 1.0))
	if game != null and game.has_method("dash_trail"):
		game.dash_trail(global_position, _dash_dir)

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
	_hurt_t = 0.30   # flash rouge du chassis — visible AUSSI en mouvement (voir _update_marker)
	Audio.sfx("hurt", 0.1)
	Events.player_damaged.emit(hp, max_hp)
	Events.screen_shake.emit(6.0)
	if game != null and game.has_method("shield_ripple"):
		# 🚨 etait CYAN (0.5,0.8,1.0) : exactement la couleur de nos propres tirs et de l'aura,
		# donc « je prends un coup » ressemblait a « je tire ». Le rouge est sans ambiguite.
		game.shield_ripple(global_position, 130.0, Color(1.0, 0.32, 0.26))
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
