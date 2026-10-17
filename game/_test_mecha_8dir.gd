extends Node
## Mecha a 8 directions (14/10, patron : « 4 diagonales pour que le mecha semble faire un tour
## complet ») : secteurs de 45 deg, hysteresis, repli 4 directions si le chassis n'a pas ses
## diagonales, ancres des diagonales, repli de planche pour hit/die.
##   godot --headless --path game res://_test_mecha_8dir.tscn

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _mk(chassis: String) -> DirectionalMecha:
	var m: DirectionalMecha = DirectionalMecha.new()
	m.chassis = chassis
	add_child(m)
	return m

func _ready() -> void:
	print("=== TEST MECHA 8 DIRECTIONS ===")
	var have: Array = []
	for c in ["vortex", "bruiser", "titan", "vanquisher", "bluestrike"]:
		var m0: DirectionalMecha = _mk(c)
		var ok: bool = m0._has_diagonals()
		print("  info  %s : diagonales %s" % [c, "OUI" if ok else "non (4 directions)"])
		if ok:
			have.append(c)
		m0.queue_free()

	# --- chassis AVEC diagonales : le tour complet ---
	var c8: String = have[0] if not have.is_empty() else ""
	_ok(c8 != "", "au moins un chassis a ses 4 diagonales bakees", str(have))
	if c8 != "":
		var m: DirectionalMecha = _mk(c8)
		var cases: Array = [
			[Vector2(1, 0), "right"], [Vector2(1, 1), "front_right"], [Vector2(0, 1), "front"],
			[Vector2(-1, 1), "front_left"], [Vector2(-1, 0), "left"], [Vector2(-1, -1), "back_left"],
			[Vector2(0, -1), "back"], [Vector2(1, -1), "back_right"],
		]
		for cs in cases:
			m._dir = "front" if cs[1] != "front" else "right"   # part d'une autre direction
			m.set_facing_from((cs[0] as Vector2).normalized())
			_ok(m.facing() == String(cs[1]), "%s : %s -> %s" % [c8, str(cs[0]), cs[1]], "obtenu=%s" % m.facing())
		# diagonale : planche de marche DIAGONALE chargee (pas la cardinale)
		m._dir = "front_right"
		m._anim = "walk"
		var t_d: Texture2D = m._tex("walk", "front_right")
		var t_c: Texture2D = m._tex("walk", "right")
		_ok(t_d != null and t_d != t_c, "walk front_right : planche diagonale distincte de 'right'")
		# animation SANS planche diagonale (die) : repli sur la cardinale horizontale
		var t_die: Texture2D = m._tex("die", "front_right")
		var t_die_r: Texture2D = m._tex("die", "right")
		_ok(t_die != null and t_die == t_die_r, "die front_right : repli sur 'right'")
		# hysteresis : autour de 45 deg on ne papillonne pas
		m._dir = "front_right"
		var flips: int = 0
		var prev: String = m.facing()
		for deg in [40.0, 50.0, 38.0, 52.0, 44.0, 47.0, 36.0, 54.0]:
			m.set_facing_from(Vector2.RIGHT.rotated(deg_to_rad(deg)))
			if m.facing() != prev:
				flips += 1
				prev = m.facing()
		_ok(flips == 0, "hysteresis : 0 changement entre 36 et 54 deg", "changements=%d" % flips)
		# ancres : VORTEX a ses diagonales MESUREES ; un chassis sans mesure (bruiser) = moyenne des
		# deux cardinales voisines
		m._dir = "front_right"
		var mv: Vector2 = m.gun_anchor() / (m.display_height / 190.0)
		_ok(mv.distance_to(Vector2(36.6, -4.7)) < 0.01, "vortex front_right : bout de canon mesure", str(mv))
		var mb: DirectionalMecha = _mk("bruiser")
		mb._dir = "front"
		var a_f: Vector2 = mb.gun_anchor()
		mb._dir = "right"
		var a_r: Vector2 = mb.gun_anchor()
		mb._dir = "front_right"
		var a_d: Vector2 = mb.gun_anchor()
		_ok(a_d.distance_to((a_f + a_r) * 0.5) < 0.01, "bruiser gun_anchor front_right = moyenne(front, right)", "%s vs %s" % [str(a_d), str((a_f + a_r) * 0.5)])
		mb.queue_free()
		_ok(m.facing_vec().is_equal_approx(Vector2(0.70710678, 0.70710678)), "facing_vec front_right = diagonale unitaire")
		m.queue_free()

	# --- BLUESTRIKE : une seule planche (walk) sert a tout -> idle/run/attack diagonales = marche diagonale
	if have.has("bluestrike"):
		var mbs: DirectionalMecha = _mk("bluestrike")
		var tw: Texture2D = mbs._tex("walk", "front_right")
		_ok(mbs._tex("idle", "front_right") == tw, "bluestrike idle front_right = marche diagonale")
		_ok(mbs._tex("attack", "back_left") == mbs._tex("walk", "back_left"), "bluestrike attack back_left = marche diagonale")
		mbs.queue_free()

	# --- chassis SANS diagonales : comportement 4 directions d'origine ---
	var no8: String = ""
	for c in ["bluestrike", "vanquisher", "titan", "bruiser"]:
		if not have.has(c):
			no8 = c
			break
	if no8 != "":
		var m4: DirectionalMecha = _mk(no8)
		m4.set_facing_from(Vector2(1, 0.2))
		_ok(m4.facing() == "right", "%s sans diagonales : (1,0.2) -> right" % no8)
		m4.set_facing_from(Vector2(0.3, 1))
		_ok(m4.facing() == "front", "%s sans diagonales : (0.3,1) -> front" % no8)
		_ok(not m4.facing().contains("_"), "%s sans diagonales : jamais de direction diagonale" % no8)
		m4.queue_free()

	print("=== %s ===" % ("PASS" if _fail == 0 else "%d echec(s)" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)
