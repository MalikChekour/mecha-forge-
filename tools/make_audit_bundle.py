"""Build a single self-contained text bundle of MECHA-FORGE for external LLM auditors.

External APIs cannot browse a filesystem — they only see text. So a real audit needs the
actual source, not a description of it. This concatenates the design docs + every gameplay
script into one prompt-ready document.

Output: scratchpad/audit_bundle.md
"""
import os

ROOT = r"C:\Users\Administrator\mecha-forge"
OUT = (r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude"
       r"\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad\audit_bundle.md")

DOCS = ["README.md", "docs/SURVIVOR_IO_PLAYBOOK.md",
        "docs/DESIGN_WEAPONS_ECONOMY.md", "docs/ACTION_PLAN.md"]

# design/economy-critical first, so a truncating model still sees what matters most
PRIORITY = [
    "game/autoload/GameState.gd",      # difficulties, talents, chassis — all balance data
    "game/autoload/SaveManager.gd",    # economy, gear, dailies, ad caps
    "game/systems/EnemySpawner.gd",    # bestiary + run structure
    "game/actors/WeaponSystem.gd",     # weapons + evolutions
    "game/scenes/MetaScreen.gd",       # every meta screen
    "game/autoload/Ads.gd",            # rewarded-ad plumbing
    "game/actors/Player.gd",
    "game/scenes/Game.gd",
]

def read(path):
    full = os.path.join(ROOT, path.replace("/", os.sep))
    if not os.path.exists(full):
        return None
    with open(full, encoding="utf-8", errors="replace") as f:
        return f.read()

parts = []
parts.append("# MECHA-FORGE — CODE SOURCE ET DOCUMENTS COMPLETS\n")
parts.append("Survivor-like mecha mobile F2P, Godot 4.3. Tout le projet est ci-dessous.\n")

parts.append("\n\n" + "=" * 78 + "\n# PARTIE 1 — DOCUMENTS DE CONCEPTION\n" + "=" * 78 + "\n")
for d in DOCS:
    c = read(d)
    if c:
        parts.append(f"\n\n----- FICHIER: {d} -----\n\n{c}")

parts.append("\n\n" + "=" * 78 + "\n# PARTIE 2 — CODE (equilibrage et economie d'abord)\n" + "=" * 78 + "\n")
seen = set()
for p in PRIORITY:
    c = read(p)
    if c:
        seen.add(p)
        parts.append(f"\n\n----- FICHIER: {p} ({len(c.splitlines())} lignes) -----\n\n```gdscript\n{c}\n```")

parts.append("\n\n" + "=" * 78 + "\n# PARTIE 3 — RESTE DU CODE\n" + "=" * 78 + "\n")
for dirpath, _, files in os.walk(os.path.join(ROOT, "game")):
    for fn in sorted(files):
        if not fn.endswith(".gd") or fn.startswith("_test"):
            continue
        rel = os.path.relpath(os.path.join(dirpath, fn), ROOT).replace(os.sep, "/")
        if rel in seen:
            continue
        c = read(rel)
        if c:
            parts.append(f"\n\n----- FICHIER: {rel} ({len(c.splitlines())} lignes) -----\n\n```gdscript\n{c}\n```")

doc = "".join(parts)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(doc)

print(f"bundle ecrit : {OUT}")
print(f"  {len(doc):,} caracteres  (~{len(doc)//4//1000}k tokens)")
print(f"  {doc.count('----- FICHIER:')} fichiers inclus")
