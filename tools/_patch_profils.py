"""Profils de niveau : apparition + combat des 18 ennemis de base. Idempotent (bloc entre marqueurs)."""
import os
p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "systems", "EnemySpawner.gd")
raw = open(p, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
s = raw.replace("\r", "")
A, B = "## >>> PROFILS DE NIVEAU", "## <<< PROFILS DE NIVEAU\n"
if A in s:
    i = s.index(A)
    j = s.index(B) + len(B)
    s = s[:i] + s[j:].lstrip("\n")
BLOCK = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "_profils_block.gd.txt"), encoding="utf-8").read()
anchor = "func _spawn() -> void:"
assert anchor in s
s = s.replace(anchor, BLOCK + "\n" + anchor, 1)
old = "	var spos: Vector2 = player.global_position + _spawn_offset()\n	if arena_half > 0.0:"
if old in s:
    s = s.replace(old, "	var spos: Vector2 = player.global_position + _pattern_offset()\n	if arena_half > 0.0:", 1)
old = "	game.enemy_layer.add_child(e)\n	e.setup(kind, DEFS[kind], player, game)\n	_scale_enemy(e)\n\n## Spawn one enemy at a fixed world point"
if old in s:
    s = s.replace(old, old.replace("DEFS[kind]", "_def_for(kind)"), 1)
old = "		e.global_position = player.global_position + Vector2(cos(w[\"ang\"]), sin(w[\"ang\"])) * float(w[\"dist\"])\n		game.enemy_layer.add_child(e)\n		e.setup(kind, DEFS[kind], player, game)"
if old in s:
    s = s.replace(old, old.replace("DEFS[kind]", "_def_for(kind)"), 1)
old = "		_spawn_t = rate / maxf(0.2, eff_mult)\n"
if old in s:
    s = s.replace(old, "		_spawn_t = rate / maxf(0.2, eff_mult * (1.0 + 0.02 * float(int((PROFILES.get(current_biome, {}) as Dictionary).get(\"tier\", 1)) - 1)))\n", 1)
old = "	_drain_wave()   # spread a queued horde over frames (no spawn hitch)\n"
if old in s and "_squad_tick(delta)" not in s:
    s = s.replace(old, old + "	_squad_tick(delta)\n", 1)
old = "eff_mult * (1.0 + 0.02 * float(int((PROFILES.get(current_biome, {}) as Dictionary).get(\"tier\", 1)) - 1))"
if old in s:
    s = s.replace(old, "eff_mult * (1.25 + 0.025 * float(int((PROFILES.get(current_biome, {}) as Dictionary).get(\"tier\", 1)) - 1))", 1)
if crlf:
    s = s.replace("\n", "\r\n")
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok")
