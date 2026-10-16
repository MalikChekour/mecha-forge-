extends Node
## AUDIT DU PERIMETRE des decors interactifs (16/10) : pour chaque decor a rayon, mesure ce qui arrive au
## mecha (degats / ralentissement / poussee / soin) et au monde (zones, ennemis, effets) a 0,5 r, 0,9 r, 1,25 r
## et 2 r, compare le rayon declare au rayon VISIBLE (anneau) et a la taille du sprite.
##   godot --headless --path game res://_test_decor_perimetre.tscn
## Lettres : D degats  S ralenti  M pousse  H soin  Z zone creee  E ennemi/effet monde  V vfx  N ennemi touche/deplace  K butin attire  B balle ennemie  P inertie glace

class StubGame extends Node:
	var enemy_layer: Node2D
	var fx_layer: Node2D
	var projectile_layer: Node2D
	var arena: Rect2 = Rect2(-6000, -6000, 12000, 12000)
	var cover_list: Array = []
	var zones: Array = []
	var vfx: int = 0
	var pancartes: Array = []
	func _init() -> void:
		enemy_layer = Node2D.new(); add_child(enemy_layer)
		fx_layer = Node2D.new(); add_child(fx_layer)
		projectile_layer = Node2D.new(); add_child(projectile_layer)
	func spawn_ground_zone(p, r, _d, dmg, _c = Color.WHITE, _k = "decor_hit") -> void:
		zones.append([p, r, dmg])
	func spawn_vfx(_k, _p, _r = 0.0, _s = 1.0, _c = Color.WHITE) -> void: vfx += 1
	func spawn_signature_vfx(_n, _p, _r = 0.0, _s = 1.0, _d = 0.4, _c = Color.WHITE) -> void: vfx += 1
	func impact_fx(_p, _c, _k, _d = Vector2.ZERO, _s = 1.0) -> void: vfx += 1
	func pancarte_prop(kind: String, _tex, _prop = null) -> void:
		if not pancartes.has(kind): pancartes.append(kind)

class DummyPlayer extends Node2D:
	var field_slow: float = 1.0
	var _patch_inertia: float = 0.0
	var velocity: Vector2 = Vector2.ZERO
	var hp: float = 50.0
	var max_hp: float = 100.0
	var dmg_taken: float = 0.0
	var healed: float = 0.0
	func heal(a: float) -> void:
		healed += a
		hp = minf(max_hp, hp + a)
	func take_damage(a, _s = Vector2.ZERO) -> void:
		dmg_taken += float(a)
	func stun(_d) -> void:
		dmg_taken += 0.001
	func grant_invuln(_t) -> void: pass

class DummyMob extends Node2D:
	var hp: float = 100.0
	var dmg: float = 0.0
	var velocity: Vector2 = Vector2.ZERO
	var speed_mult: float = 1.0
	var slow: float = 1.0
	var active: bool = true
	var alive: bool = true
	func take_damage(a, _s = Vector2.ZERO, _x = null) -> void:
		dmg += float(a)
	func stun(_d) -> void:
		dmg += 0.001
	func apply_slow(_a = 0.5, _b = 1.0) -> void:
		dmg += 0.002

const RADIUS_KEYS: Array = ["arc_r", "slow_r", "aura_r", "push_r", "guard_r", "dwell_r", "spot_r", "conveyor_r", "console_r",
	"valve_r", "sinkhole_r", "mirage_r", "sandworm_r", "fumerolle_r", "mortar_r", "whip_r", "lasso_r", "firefly_r", "vent_r",
	"hammer_r", "quench_r", "magnet_r", "bellows_r", "flak_r", "drain_r", "mine_trigger_r", "searchlight_r", "jammer_r",
	"ice_patch_r", "cryo_jet_r", "fog_r", "defroster_r", "thermal_r", "ncannon_r", "condenser_r", "teleport_r", "cannon_r",
	"tesla_r", "control_rod_r", "containment_r", "toxic_r", "wind_r", "wind_console_r", "alt_zone_r", "acid_r", "vein_r",
	"bio_residue_r", "sticky_r", "spore_r", "light_plant_r", "launcher_r", "relay_r", "dome_r", "hook_r", "depress_r", "grav_r"]
const LEN_KEYS: Array = ["presser_len", "gantry_len", "crucible_len", "gate_len", "catapult_dist"]
## effets a declenchement : on les observe plus longtemps
const SLOW_KINDS: Array = ["terminal", "desert_collecteur_solaire"]

var _fail: int = 0
var _rows: Array = []

func _mk(g: Node, kind: String) -> PropScatter.Prop:
	var p: PropScatter.Prop = PropScatter.Prop.new()
	p.game = g; p.kind = kind; p.def = PropScatter.DECOR[kind]
	p.position = Vector2.ZERO; p.rand_scale = 1.0; p.skill_roll = 0.0; p.flip = false
	add_child(p)
	p.set_process(false)
	return p

func _radius_of(def: Dictionary) -> Array:
	for k in RADIUS_KEYS:
		if def.has(k):
			return [k, float(def[k])]
	for k in LEN_KEYS:
		if def.has(k):
			return [k, float(def[k])]
	return ["", 0.0]

## rayon (px) du plus grand disque visible rattache au decor : anneau lumineux / zone au sol
func _visible_radius(p: Node) -> float:
	var best: float = 0.0
	var stack: Array = [p]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is Sprite2D and (c as Sprite2D).texture != null and c != p._sprite:
				var s: Sprite2D = c
				var w: float = float(s.texture.get_width()) * absf(s.global_scale.x) * 0.5
				if s.visible and w > best and w < 900.0:
					best = w
	return best

func _measure(kind: String, dist: float, secs: float) -> String:
	var g: StubGame = StubGame.new()
	add_child(g)
	var plr: DummyPlayer = DummyPlayer.new()
	add_child(plr)
	plr.add_to_group("player")
	var p: PropScatter.Prop = _mk(g, kind)
	p._plr = plr
	plr.global_position = Vector2(dist, 0.0)
	var start: Vector2 = plr.global_position
	var mob: DummyMob = DummyMob.new(); add_child(mob); mob.add_to_group("enemies"); mob.global_position = Vector2(0.0, dist)
	var pick: DummyMob = DummyMob.new(); add_child(pick); pick.add_to_group("pickups"); pick.global_position = Vector2(-dist, 0.0)
	var bul: DummyMob = DummyMob.new(); add_child(bul); bul.add_to_group("enemy_bullets"); bul.global_position = Vector2(0.0, -dist); bul.velocity = Vector2(0, 100)
	var mob0: Vector2 = mob.global_position; var pick0: Vector2 = pick.global_position; var bul0: Vector2 = bul.global_position
	var slow_seen: bool = false
	var frames: int = int(secs * 30.0)
	for i in frames:
		plr.field_slow = 1.0
		PropScatter.Prop._enemy_cache_frame = -1
		p._process(1.0 / 30.0)
		if plr.field_slow < 0.999:
			slow_seen = true
	var out: String = ""
	if plr.dmg_taken > 0.0: out += "D"
	if slow_seen: out += "S"
	if plr.global_position.distance_to(start) > 1.0: out += "M"
	if plr.healed > 0.0: out += "H"
	if g.zones.size() > 0: out += "Z"
	if g.enemy_layer.get_child_count() > 0 or g.fx_layer.get_child_count() > 0 or g.projectile_layer.get_child_count() > 0: out += "E"
	if g.vfx > 0: out += "V"
	if mob.global_position.distance_to(mob0) > 1.0 or mob.dmg > 0.0: out += "N"
	if pick.global_position.distance_to(pick0) > 1.0 or pick.dmg > 0.0: out += "K"
	if not is_instance_valid(bul) or bul.global_position.distance_to(bul0) > 1.0 or bul.dmg > 0.0 or bul.velocity.distance_to(Vector2(0, 100)) > 1.0: out += "B"
	if plr._patch_inertia > 0.0: out += "P"
	for n in [mob, pick, bul]:
		if is_instance_valid(n): n.queue_free()
	p.queue_free(); plr.queue_free(); g.queue_free()
	return out if out != "" else "-"

func _ready() -> void:
	print("=== AUDIT PERIMETRE DECORS ===")
	GameState.reset()
	var kinds: Array = PropScatter.DECOR.keys()
	kinds.sort()
	for k in kinds:
		var def: Dictionary = PropScatter.DECOR[k]
		var rr: Array = _radius_of(def)
		var r: float = float(rr[1])
		if r <= 0.0:
			continue
		var secs: float = 7.0
		var res: Array = []
		for f in [0.5, 0.9, 1.25, 2.0]:
			res.append(_measure(k, r * float(f), secs))
		# rayon visible (anneau) et taille du sprite
		var g2: StubGame = StubGame.new(); add_child(g2)
		var pv: PropScatter.Prop = _mk(g2, k)
		var vis: float = _visible_radius(pv)
		pv.queue_free(); g2.queue_free()
		var sz: float = float(def.get("sz", 0.0))
		var line: String = "%-32s %-14s r=%4.0f sz=%4.0f anneau=%4.0f | 0.5r:%-4s 0.9r:%-4s 1.25r:%-4s 2r:%-4s" % [k, rr[0], r, sz, vis, res[0], res[1], res[2], res[3]]
		var flags: Array = []
		if res[0] == "-" and res[1] == "-":
			flags.append("INERTE")
		elif res[1] == "-" and res[0] != "-":
			flags.append("TROP COURT (rien a 0.9r)")
		if res[2] != "-" and res[2] == res[1] and res[3] != "-":
			flags.append("SANS LIMITE")
		elif res[2] != "-" and res[1] != "-" and res[3] == "-" and r < 120.0:
			flags.append("deborde 1.25r")
		if vis > 0.0 and absf(vis - r) / r > 0.35:
			flags.append("anneau %.0f != r" % vis)
		if sz > 0.0 and r < sz * 0.45:
			flags.append("r < sprite")
		print(line, "  <", ", ".join(flags), ">" if flags.size() > 0 else "")
		await get_tree().process_frame
	print("=== FIN (informatif) ===")
	get_tree().quit(0)
