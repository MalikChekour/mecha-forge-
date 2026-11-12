# MECHA-FORGE : développement dans le cloud

Depuis le 12/11/2026, le jeu se développe **depuis ce dépôt GitHub** (sessions cloud : Claude Code sur le web, Cursor, Codespaces). Ce dépôt est la source de vérité. La copie locale sur le serveur Windows n'est plus qu'une sauvegarde.

## Le jeu
Survivor-like / bullet-heaven mobile (Android + web) : un mecha à tir automatique, des vagues, une montée de niveau par draft de 3 cartes, des boss, une méta. 18 chapitres et biomes.
- Moteur : **Godot 4.3** (`game/project.godot`, `config/features` = 4.3, rendu GL Compatibility). Paysage 1280×720, vue top-down 3/4.
- Version du jeu : `config/version` dans `game/project.godot`. **On l'incrémente à chaque build.**
- Contexte détaillé : `PROJECT_HANDOFF.md`, puis `docs/` (plans, design armes/économie, prompts d'assets).

## Arborescence utile
- `game/` : le projet Godot (`actors/`, `autoload/`, `scenes/`, `systems/`, `shaders/`, `assets/`).
- `tools/` : pipeline d'assets (Python, bpy pour Blender, PowerShell). Ces scripts ont été écrits sous Windows : certains chemins sont codés en dur sur `C:\Users\Administrator\...`.
- `.github/workflows/android.yml` : build APK debug dans GitHub Actions (Godot 4.3 + SDK Android, non testé à ce jour).
- `.agents/skills/` : skills d'agent (export Godot, smoke-check, QA…).

## Ce qui N'EST PAS dans git (et où le trouver)
Les gros fichiers sources, qui ne sont pas chargés par le jeu, sont dans la **Release GitHub `assets-2026-11-12`** de ce dépôt : un tar.gz découpé en parties de 1,9 Go.
- `meshy_in/` (5,1 Go) : GLB Meshy riggés/animés, sources des sprites.
- `cine/` (1,1 Go) : rendus, essais pixel, cinématiques.
- `refs/`, `assets_src/*.zip` (kits Quaternius), captures QA, packs de mechas générés.

Récupération (seulement si on doit re-baker des sprites depuis les GLB) :
```bash
gh release download assets-2026-11-12 -p 'mecha-forge-assets.tar.gz.part*'
cat mecha-forge-assets.tar.gz.part* | tar -xzf -
```

Jamais dans git ni dans la Release : les profils Chrome d'automatisation (`.chrome_meshy/`, `.chrome_mixamo/`) et les clés (`.meshy_key`, `.glm_key`, `.itch_key`, `.env`). Dans le cloud, les clés passent par des **secrets** (GitHub Secrets, variables d'environnement de la session).

## Règles de travail
- Avant de committer, vérifier la **taille** de l'index (`git status`). Un `git add -A` a déjà failli embarquer 746 Mo de profils Chrome. Aucun fichier de plus de 50 Mo dans git (GitHub refuse au-delà de 100 Mo).
- Les builds (`web/`, `build*/`, `game/.godot/`) sont jetables et ignorés.
- **Tester en jeu** avant de déclarer une fonctionnalité finie. Pour un smoke test sans écran : `godot --headless --path game`. Chercher `USER ERROR` dans la sortie, pas seulement `^ERROR`.
- Après chaque ajout : vérifier l'équilibrage, l'UX et les systèmes touchés.

## Branches
- `main` : ligne principale (= l'ancienne branche locale `feat/gemini-decor-vfx-ruines-hero`, v12.42).
- `master` : ancienne branche principale locale, en retard de 190 commits. À conserver comme archive.
- `cursor/phase1-quick-wins-7b4f` : travail d'un agent Cursor (bombe, aimant, kami, invocateur…), parti du commit initial **vide**. Il n'est pas fusionnable tel quel : il faut le porter à la main sur `main`.
