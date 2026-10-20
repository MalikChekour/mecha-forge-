"""Ajoute dans EnemySpawner.gd les 18 ennemis de base (un par chapitre) : DEFS + BIOME_POOL. Idempotent."""
import os, re
p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "systems", "EnemySpawner.gd")
raw = open(p, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
s = raw.replace("\r", "")
CH_ALL = [
 ("tech", "en01_tech", "Walker d'assemblage", 124.0),
 ("desert", "en02_desert", "Rodeur des dunes", 128.0),
 ("jungle", "en03_jungle", "Broyeur forestier", 132.0),
 ("volcanic", "en04_volcanic", "Fondeur de magma", 128.0),
 ("swamp", "en05_swamp", "Excavateur de vase", 126.0),
 ("cryo", "en06_cryo", "Foreur glaciaire", 130.0),
 ("reacteur", "en07_reacteur", "Noyau irradie", 122.0),
 ("ruche", "en08_ruche", "Brise-ruche", 128.0),
 ("citadelle", "en09_citadelle", "Bastion orbital", 134.0),
 ("abyss", "en10_abyss", "Nautilus", 132.0),
 ("ether", "en11_ether", "Marcheur de spores", 130.0),
 ("titans", "en12_titans", "Relique titan", 142.0),
 ("orbit", "en13_orbit", "Astro-vecteur", 128.0),
 ("quantum", "en14_quantum", "Cipher-byte", 126.0),
 ("ozone", "en15_ozone", "Sauteur de foudre", 128.0),
 ("prism", "en16_prism", "Spectra-mecha", 130.0),
 ("steampunk", "en17_steampunk", "Terreur a vapeur", 132.0),
 ("colosseum", "en18_colosseum", "Gladiateur", 134.0),
]
CH = list(CH_ALL)   # 20/10 : les 18 chapitres
lines = []
for i, (biome, chassis, name, size) in [(CH_ALL.index(c) + 1, c) for c in CH]:
    hp = 26.0 + 2.5 * i
    spd = 168.0 + (i % 4) * 4.0
    dmg = 7.0 + 0.4 * i
    ad = 4.0 + 0.35 * i
    lines.append('\t"mech%02d": {"name": "%s", "chassis": "%s", "hp": %.1f, "speed": %.1f, "dmg": %.1f, "radius": 44.0, "size": %.1f, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": %.1f, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},' % (i, name, chassis, hp, spd, dmg, size, ad))
# 1) DEFS : remplace les lignes mechNN existantes puis les reecrit
s = re.sub(r'\t"mech\d\d": \{[^\n]*\},\n', "", s)
anchor = '	# "cryoboss":'
i = s.index(anchor)
s = s[:i] + "\n".join(lines) + "\n" + s[i:]
# 2) pools
for i, (biome, chassis, name, size) in [(CH_ALL.index(c) + 1, c) for c in CH]:
    pool = '\t"%s": ["mech%02d", "brute", "quadshell"],' % (biome, i)
    s, n = re.subn(r'\t"%s": \[[^\]]*\],' % biome, pool.replace("\\", "\\\\"), s, count=1)
    if n == 0:
        print("pool absent :", biome)
if crlf:
    s = s.replace("\n", "\r\n")
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok")
