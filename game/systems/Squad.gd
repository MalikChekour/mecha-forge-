extends RefCounted
class_name Squad
## ESCOUADE TACTIQUE (21/10, patron : « des strategies militaires : formation en ligne, encerclement, etc. »).
## Une escouade = N ennemis qui se placent sur des EMPLACEMENTS calcules par la formation, puis se liberent au contact.
## L'escouade ne deplace pas les ennemis : elle ecrit `form_pos` / `form_w` (poids 0..1) sur chacun ; c'est Enemy qui
## melange ce guidage avec son comportement propre. Un membre tue = les rangs se resserrent (les index se recalculent).
## Inspire de la doctrine d'infanterie (ligne = feu frontal, coin = securite tous azimuts, echelon = flanc couvert,
## colonne = mouvement) et des manoeuvres classiques (tenaille, encerclement, feu et mouvement, embuscade, leurre).
## GARDE-FOUS « jamais impossible » : l'encerclement laisse une BRECHE de 60 deg qui tourne, la tenaille laisse l'arriere
## ouvert, le fer a cheval est ouvert d'un cote, les formations ne descendent jamais sous ~250 px du joueur, et chaque
## escouade se dissout (membres liberes) apres LIFE secondes.

var form: String = "ligne"
var members: Array = []
var c: Vector2 = Vector2.ZERO
var t: float = 0.0
var state: String = "advance"     # advance | engage
var base: float = 0.0              # angle joueur -> escouade a la creation
var done: bool = false
var life: float = 45.0
var _u: Vector2 = Vector2.RIGHT    # de c vers le joueur
var _ax: Vector2 = Vector2.RIGHT   # joueur -> escouade (fige)
var _p0: Vector2 = Vector2.ZERO    # position du joueur a la creation (embuscade / leurre)
var _hold: Array = []
var _decoy: Variant = null
var chef: Variant = null           # chef de meute (officier) ; promu parmi les survivants s'il tombe
var disorder: float = 0.0          # secondes d'hesitation apres la perte du chef
var chef_down: bool = false        # lu puis remis a faux par le spawner (bandeau)

const SP: float = 84.0
const ADVANCE_FORMS: Array = ["ligne", "colonne", "coin", "echelon", "vague"]
const GAP: float = 1.05            # breche de l'encerclement (rad) ~ 60 deg

static func all_forms() -> Array:
	return ["ligne", "colonne", "coin", "echelon", "vague", "tenaille", "encerclement", "spirale", "fer_a_cheval",
		"feu_et_mouvement", "tirailleurs", "embuscade", "leurre"]

static func label(f: String) -> String:
	match f:
		"ligne": return "LIGNE DE FEU"
		"colonne": return "COLONNE"
		"coin": return "FORMATION EN COIN"
		"echelon": return "ECHELON"
		"vague": return "VAGUES SUCCESSIVES"
		"tenaille": return "TENAILLE"
		"encerclement": return "ENCERCLEMENT"
		"spirale": return "ENCERCLEMENT TOURNANT"
		"fer_a_cheval": return "FER A CHEVAL"
		"feu_et_mouvement": return "FEU ET MOUVEMENT"
		"tirailleurs": return "TIRAILLEURS"
		"embuscade": return "EMBUSCADE"
		"leurre": return "LEURRE ET FRAPPE"
	return f.to_upper()

func setup(f: String, anchor: float, centre: Vector2, p: Vector2) -> void:
	form = f
	base = anchor
	c = centre
	_p0 = p
	_ax = (centre - p).normalized()
	_u = -_ax
	life = 45.0 if ADVANCE_FORMS.has(f) else (30.0 if f in ["feu_et_mouvement", "tirailleurs"] else 40.0)

## HIERARCHIE (patron : « comme dans une armee ») : 1 chef de meute (or, coriace, plus grand, butin), 2 lieutenants des
## 7 membres (bleu-glace, un peu plus resistants), le reste = soldats. Chef tue -> l'escouade hesite ~2,5 s (ordres brouilles)
## puis le meilleur gradé survivant prend le commandement (promotion de terrain).
static func mark(e: Variant, grade: String) -> void:
	e.grade = grade
	var col: Color = Color(1.0, 0.72, 0.28) if grade == "chef" else Color(0.55, 0.85, 1.25)
	e._spr.self_modulate = col
	if grade == "chef":
		e._spr.scale *= 1.12
		e.drops_bonus = true

func assign_ranks() -> void:
	var ms: Array = live()
	if ms.is_empty():
		return
	chef = ms[0]
	mark(chef, "chef")
	var ref: float = 0.0
	for m in ms:
		if m != chef:
			ref = maxf(ref, float(m.hp_max))
	chef.hp = maxf(chef.hp * 2.4, ref * 2.1)   # coriace meme si son role est fragile (kamikaze)
	chef.hp_max = chef.hp
	chef.contact_dmg *= 1.2
	if ms.size() >= 7:
		for j in [1, 2]:
			mark(ms[j], "lieutenant")
			ms[j].hp *= 1.4
			ms[j].hp_max = ms[j].hp

func _check_chef(ms: Array) -> void:
	if chef != null and is_instance_valid(chef) and chef.alive:
		return
	var nxt: Variant = null
	for m in ms:
		if m.grade == "lieutenant":
			nxt = m
			break
	if nxt == null:
		nxt = ms[0]
	if chef != null:      # le chef initial est tombe (pas la premiere affectation)
		chef_down = true
		disorder = 2.5
	chef = nxt
	mark(nxt, "chef")

func live() -> Array:
	members = members.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.alive)
	return members

func _engage_r() -> float:
	match form:
		"colonne": return 320.0
		"coin": return 330.0
		"echelon": return 360.0
	return 380.0

func _hold_pt(i: int, n: int) -> Vector2:
	if _hold.is_empty():
		var pp: Vector2 = Vector2(-_ax.y, _ax.x)
		for j in maxi(n, 1):
			if form == "leurre":
				var side: float = 1.0 if j % 2 == 0 else -1.0
				_hold.append(_p0 + Vector2.from_angle(base + side * 1.6 + float(j / 2) * 0.12 * side) * 480.0)
			else:
				_hold.append(c + pp * (float(j) - float(n - 1) * 0.5) * 70.0 - _ax * float(j % 2) * 50.0)
	return _hold[i % _hold.size()]

func slot(i: int, n: int, p: Vector2) -> Vector2:
	var u: Vector2 = _u
	var pp: Vector2 = Vector2(-u.y, u.x)
	var k: float = float(i) - float(n - 1) * 0.5
	var f: float = 0.5 if n <= 1 else float(i) / float(n - 1)
	match form:
		"ligne":
			return c + pp * k * SP
		"colonne":
			return c - u * float(i) * SP * 0.9 + pp * sin(t * 2.0 + float(i)) * 14.0
		"coin":
			var row: float = floorf(float(i + 1) * 0.5)
			var side: float = 0.0 if i == 0 else (1.0 if i % 2 == 1 else -1.0)
			return c - u * row * SP * 0.8 + pp * side * row * SP * 0.9
		"echelon":
			return c + pp * k * SP * 0.9 - u * k * SP * 0.8
		"vague":
			return c - u * float(i / 5) * 130.0 + pp * (float(i % 5) - 2.0) * SP
		"tenaille":
			var s2: float = 1.0 if i % 2 == 0 else -1.0
			var ap: Vector2 = Vector2(-_ax.y, _ax.x)
			var r: float = lerpf(520.0, 250.0, clampf(t / 11.0, 0.0, 1.0))
			return p + _ax * (140.0 + float(i / 2) * 70.0) + ap * s2 * r
		"encerclement":
			var a: float = base + t * 0.12 + f * (TAU - GAP)
			return p + Vector2.from_angle(a) * maxf(300.0, lerpf(620.0, 300.0, t / 16.0))
		"spirale":
			var a2: float = base + t * 0.35 + f * (TAU - GAP)
			return p + Vector2.from_angle(a2) * maxf(330.0, 470.0 + 140.0 * sin(t * 0.5))
		"fer_a_cheval":
			var a3: float = base + (f - 0.5) * 3.5
			return p + Vector2.from_angle(a3) * lerpf(500.0, 330.0, clampf(t / 10.0, 0.0, 1.0))
		"feu_et_mouvement":
			var phase: int = int(t / 4.0) % 2
			var r2: float = 330.0 if (i % 2) == phase else 260.0
			return p + Vector2.from_angle(base + k * 0.26) * r2
		"tirailleurs":
			var a4: float = base + float(i) * 2.4 + sin(t * 0.4 + float(i)) * 0.5
			return p + Vector2.from_angle(a4) * (340.0 + 60.0 * sin(t * 0.7 + float(i) * 1.7))
		"embuscade":
			return _hold_pt(i, n)
		"leurre":
			return p if i == 0 else _hold_pt(i, n)
	return c

func _release(ms: Array) -> void:
	for m in ms:
		m.form_w = 0.0
	done = true

func update(delta: float, p: Vector2, mspeed: float) -> void:
	t += delta
	var ms: Array = live()
	var n: int = ms.size()
	if n == 0:
		done = true
		return
	_check_chef(ms)
	disorder = maxf(0.0, disorder - delta)
	if t > life or n <= 1:
		_release(ms)
		return
	var to: Vector2 = p - c
	var d: float = to.length()
	_u = to / maxf(d, 1.0)
	if ADVANCE_FORMS.has(form):
		if state == "advance":
			c += _u * mspeed * 0.6 * delta
			if d < _engage_r():
				state = "engage"
		else:
			c += _u * mspeed * 0.25 * delta
	elif state == "advance":
		match form:
			"embuscade":
				if d < 360.0 or t > 14.0:
					state = "engage"
			"leurre":
				if _decoy == null:
					_decoy = ms[0]
				if t > 7.0 or not is_instance_valid(_decoy) or not _decoy.alive:
					state = "engage"
			"tenaille":
				if t > 11.0: state = "engage"
			"encerclement":
				if t > 16.0: state = "engage"
			"spirale":
				if t > 22.0: state = "engage"
			"fer_a_cheval":
				if t > 10.0: state = "engage"
	for i in n:
		var m: Variant = ms[i]
		m.form_pos = slot(i, n, p)
		m.chef_ref = chef
		var w: float = 1.0
		if form == "leurre" and m == _decoy:
			w = 0.0
		elif state == "engage":
			w = 0.0 if m.behavior in ["dasher", "kamikaze", "rush", "miner"] else 0.35
		m.form_w = w * (0.3 if disorder > 0.0 else 1.0)
