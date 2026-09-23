import re
p = "game/systems/EnemySpawner.gd"
s = open(p, encoding="utf-8").read()

NEW_DEFS = '''const DEFS: Dictionary = {
\t# behavior: rush | ranged | dasher.  "chassis" = baked art reuse (10 chassis). "name" = affichage.
\t# La CORRUPTION par biome (teinte) est appliquee au spawn (enemy_tint), pas ici.
\t# ---------- UNIVERSELS (pool de CHAQUE biome ; cles brute/drone conservees = refs carcasse/beacon) ----------
\t"brute":     {"name": "Rodeur", "chassis": "brute", "hp": 14.0, "speed": 224.0, "dmg": 6.0, "radius": 30.0, "size": 124.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "unlock": 0.0},
\t"drone":     {"name": "Guepe", "chassis": "drone", "hp": 10.0, "speed": 300.0, "dmg": 3.0, "radius": 18.0, "size": 78.0, "motion": "hover", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 4.0, "attack_cd": 1.9, "prefer_dist": 280.0, "unlock": 40.0},
\t"quadshell": {"name": "Belier", "chassis": "quadshell", "hp": 18.0, "speed": 214.0, "dmg": 9.0, "radius": 26.0, "size": 122.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "dasher", "unlock": 55.0},
\t# ---------- SPECIALISTES par biome (cles neuves, chassis reutilise) ----------
\t"sentinelle": {"name": "Sentinelle", "chassis": "shielded", "hp": 26.0, "speed": 196.0, "dmg": 8.0, "radius": 32.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "rush", "shield": 16.0, "unlock": 25.0},
\t"tourelle":   {"name": "Tourelle", "chassis": "warden", "hp": 72.0, "speed": 168.0, "dmg": 12.0, "radius": 34.0, "size": 146.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "ranged", "attack_dmg": 14.0, "attack_cd": 1.7, "prefer_dist": 360.0, "drops_bonus": true, "unlock": 120.0},
\t"charognard": {"name": "Charognard", "chassis": "elite", "hp": 16.0, "speed": 250.0, "dmg": 7.0, "radius": 28.0, "size": 130.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
\t"broyeur":    {"name": "Broyeur", "chassis": "crusher", "hp": 80.0, "speed": 170.0, "dmg": 17.0, "radius": 36.0, "size": 156.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "rush", "drops_bonus": true, "unlock": 120.0},
\t"voltigeur":  {"name": "Voltigeur", "chassis": "quadshell", "hp": 16.0, "speed": 242.0, "dmg": 8.0, "radius": 26.0, "size": 118.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "dasher", "unlock": 0.0},
\t"essaim":     {"name": "Essaim", "chassis": "eyedrone", "hp": 13.0, "speed": 180.0, "dmg": 5.0, "radius": 20.0, "size": 96.0, "motion": "hover", "rank": 1, "w": 1, "behavior": "ranged", "attack_dmg": 9.0, "attack_cd": 1.4, "prefer_dist": 320.0, "drops_bonus": true, "unlock": 90.0},
\t"lancefeu":   {"name": "Lance-feu", "chassis": "warden", "hp": 70.0, "speed": 172.0, "dmg": 11.0, "radius": 32.0, "size": 142.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "attack_dmg": 11.0, "attack_cd": 1.6, "prefer_dist": 330.0, "unlock": 30.0},
\t"fondeur":    {"name": "Fondeur", "chassis": "crusher", "hp": 90.0, "speed": 168.0, "dmg": 18.0, "radius": 36.0, "size": 158.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "rush", "drops_bonus": true, "unlock": 120.0},
\t"pillard":    {"name": "Pillard", "chassis": "elite", "hp": 15.0, "speed": 268.0, "dmg": 7.0, "radius": 28.0, "size": 128.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
\t"foreuse":    {"name": "Foreuse", "chassis": "quadshell", "hp": 68.0, "speed": 196.0, "dmg": 16.0, "radius": 30.0, "size": 140.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "dasher", "drops_bonus": true, "unlock": 120.0},
\t"eclat":      {"name": "Eclat", "chassis": "shielded", "hp": 24.0, "speed": 188.0, "dmg": 8.0, "radius": 32.0, "size": 134.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "rush", "shield": 12.0, "unlock": 25.0},
\t"givre":      {"name": "Givre", "chassis": "crusher", "hp": 86.0, "speed": 150.0, "dmg": 16.0, "radius": 36.0, "size": 158.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "rush", "drops_bonus": true, "unlock": 120.0},
\t"fourmi":     {"name": "Fourmi", "chassis": "brute", "hp": 11.0, "speed": 244.0, "dmg": 5.0, "radius": 26.0, "size": 110.0, "motion": "walk", "rank": 0, "w": 5, "behavior": "rush", "unlock": 0.0},
\t"cracheur":   {"name": "Cracheur", "chassis": "warden", "hp": 70.0, "speed": 170.0, "dmg": 11.0, "radius": 32.0, "size": 142.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "ranged", "attack_dmg": 12.0, "attack_cd": 1.6, "prefer_dist": 340.0, "drops_bonus": true, "unlock": 120.0},
\t"rampant":    {"name": "Rampant", "chassis": "shielded", "hp": 28.0, "speed": 180.0, "dmg": 8.0, "radius": 32.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "rush", "shield": 14.0, "unlock": 25.0},
\t"sangsue":    {"name": "Sangsue", "chassis": "crusher", "hp": 84.0, "speed": 160.0, "dmg": 15.0, "radius": 36.0, "size": 156.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "rush", "drops_bonus": true, "unlock": 120.0},
\t"garde":      {"name": "Garde d assaut", "chassis": "elite", "hp": 20.0, "speed": 228.0, "dmg": 9.0, "radius": 30.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "rush", "unlock": 0.0},
\t"artilleur":  {"name": "Artilleur", "chassis": "warden", "hp": 74.0, "speed": 166.0, "dmg": 12.0, "radius": 34.0, "size": 146.0, "motion": "walk", "rank": 1, "w": 1, "behavior": "ranged", "attack_dmg": 15.0, "attack_cd": 1.8, "prefer_dist": 370.0, "drops_bonus": true, "unlock": 120.0},
\t# ---------- BOSS (w:0 -> planifies, hors pick ; cles conservees) ----------
\t"midboss": {"name": "Colosse", "chassis": "midboss", "hp": 850.0, "speed": 256.0, "dmg": 24.0, "radius": 58.0, "size": 300.0, "motion": "quad_walk", "rank": 3, "w": 0, "behavior": "rush", "shield": 200.0},
\t"endboss": {"name": "Souverain", "chassis": "endboss", "hp": 2800.0, "speed": 240.0, "dmg": 32.0, "radius": 78.0, "size": 380.0, "motion": "boss_idle", "rank": 4, "w": 0, "behavior": "rush", "shield": 400.0, "final": true},
}

# Pool PAR BIOME : 3 universels (brute/drone/quadshell) + 2 specialistes. Le pick est filtre dessus.
const BIOME_POOL: Dictionary = {
\t"tech":      ["brute", "drone", "quadshell", "sentinelle", "tourelle"],
\t"earth":     ["brute", "drone", "quadshell", "charognard", "broyeur"],
\t"spaceship": ["brute", "drone", "quadshell", "voltigeur", "essaim"],
\t"volcanic":  ["brute", "drone", "quadshell", "lancefeu", "fondeur"],
\t"desert":    ["brute", "drone", "quadshell", "pillard", "foreuse"],
\t"ice":       ["brute", "drone", "quadshell", "eclat", "givre"],
\t"jungle":    ["brute", "drone", "quadshell", "fourmi", "cracheur"],
\t"swamp":     ["brute", "drone", "quadshell", "rampant", "sangsue"],
\t"ruines":    ["brute", "drone", "quadshell", "garde", "artilleur"],
}

# CORRUPTION visuelle par biome : teinte multiplicative sur CHAQUE ennemi (self_modulate). Subtile.
const BIOME_TINT: Dictionary = {
\t"tech":      Color(0.82, 0.92, 1.10),
\t"earth":     Color(1.10, 0.92, 0.70),
\t"spaceship": Color(0.90, 0.88, 1.14),
\t"volcanic":  Color(1.30, 0.72, 0.54),
\t"desert":    Color(1.16, 1.00, 0.68),
\t"ice":       Color(0.74, 0.94, 1.18),
\t"jungle":    Color(0.76, 1.14, 0.74),
\t"swamp":     Color(0.86, 1.04, 0.68),
\t"ruines":    Color(1.08, 0.90, 0.78),
}'''

m = re.search(r"const DEFS: Dictionary = \{.*?\n\}\n", s, flags=re.S)
assert m, "DEFS block not found"
s = s[:m.start()] + NEW_DEFS + "\n" + s[m.end():]

anchor = 'var difficulty_bonus: float = 0.0   # permanent step-up per cleared zone (set by Game.next_map)'
assert anchor in s, "difficulty_bonus anchor not found"
s = s.replace(anchor, anchor
    + '\nvar current_biome: String = "tech"   # set by Game per zone -> filtre le pool d ennemis'
    + '\nvar enemy_tint: Color = Color(1, 1, 1)   # corruption visuelle du biome, appliquee a chaque ennemi', 1)

open(p, "w", encoding="utf-8").write(s)
print("OK: DEFS + BIOME_POOL + BIOME_TINT + vars patched;", len(DEFS_KEYS := re.findall(r'\n\t"(\w+)":', NEW_DEFS)), "entries")
