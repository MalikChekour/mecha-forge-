extends Node
## Profils de niveau (21/10) : pour chacun des 18 biomes, 400 tirages de motif + de role.
## Verifie : distance mini d'apparition, roles attendus, durcissement monotone, plafond de roles speciaux.

class FakePlayer extends Node2D:
	var velocity: Vector2 = Vector2(260, 0)
	var base_speed: float = 300.0

var _fail: int = 0

func _check(ok: bool, msg: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + msg)
	if not ok:
		_fail += 1

func _ready() -> void:
	var sp: EnemySpawner = EnemySpawner.new()
	add_child(sp)
	var pl: FakePlayer = FakePlayer.new()
	add_child(pl)
	sp.player = pl
	sp.set_process(false)
	var prev_cd: float = 99.0
	var order: Array = []
	for b in EnemySpawner.PROFILES.keys():
		order.append([int(EnemySpawner.PROFILES[b]["tier"]), b])
	order.sort()
	_check(order.size() == 18, "18 profils (un par niveau), obtenu %d" % order.size())
	for pr in order:
		var biome: String = pr[1]
		var tier: int = pr[0]
		sp.current_biome = biome
		var pool: Array = EnemySpawner.BIOME_POOL[biome]
		var kind: String = String(pool[0])
		var dmin: float = 99999.0
		var dmax: float = 0.0
		var roles: Dictionary = {}
		for i in 400:
			var o: Vector2 = sp._pattern_offset()
			dmin = minf(dmin, o.length())
			dmax = maxf(dmax, o.length())
			var d: Dictionary = sp._def_for(kind)
			var k: String = String(d.get("behavior", "?")) + ("+S" if float(d.get("shield", 0.0)) > 0.0 else "") + ("+H" if bool(d.get("heavy", false)) else "") + ("+B" if bool(d.get("barrage", false)) else "")
			roles[k] = int(roles.get(k, 0)) + 1
		_check(dmin >= 380.0, "%-10s t%02d motif=%-8s dist %.0f..%.0f roles=%s" % [biome, tier, EnemySpawner.PROFILES[biome]["pat"], dmin, dmax, str(roles)])
		var cd: float = float(sp._role_def(kind, ["tir"], tier)["attack_cd"])
		_check(cd <= prev_cd + 0.0001, "%s : cadence de tir non decroissante (%.2f s)" % [biome, cd])
		prev_cd = cd
		_check(sp._special_cap(tier) >= 4 and sp._special_cap(tier) <= 8, "%s : plafond de speciaux %d dans [4,8]" % [biome, sp._special_cap(tier)])
	print("=== ", "OK" if _fail == 0 else "%d ECHEC(S)" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
