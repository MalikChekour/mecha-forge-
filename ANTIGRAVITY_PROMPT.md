# Prompt pour Antigravity — générer un mecha 2D animé (toutes directions) pour MECHA-FORGE

Copie-colle tout ce qui suit à Antigravity.

---

Tu travailles dans le projet de jeu **MECHA-FORGE**, situé dans `C:\Users\Administrator\mecha-forge`.
Ta mission : **générer un personnage mecha détaillé avec un jeu d'animations complet, en sprites 2D, prêt à intégrer dans le jeu**. Avant de commencer, **installe toi-même TOUTE extension / serveur MCP qui peut t'aider** (par ex. *Blender MCP* `blender-mcp`, un MCP d'animation/rigging, un MCP de génération d'assets 3D, etc.) et utilise le **GPU** de ta machine si tu en as un.

## 1. Le jeu (contexte)
- Moteur : **Godot 4.5** (le projet Godot est dans le sous-dossier `game/`).
- Genre : **survivor-like / bullet-heaven mobile Android** (type Survivor.io / Vampire Survivors).
- Vue : **top-down 3/4** (caméra vue de dessus légèrement inclinée, ~38-40° d'élévation). Écran **paysage 1280×720**.
- Le joueur est un **mecha** qui se déplace dans 4 directions et tire automatiquement sur les ennemis.
- Rendu : renderer **gl_compatibility** (compatible web/mobile), filtre de texture **NEAREST** → les sprites doivent être **nets** (pas de flou).

## 2. Le look voulu
- Un **mecha de combat détaillé et cohérent** : armure acier bleu-nuit, **accents orange**, **cœur/réacteur cyan lumineux** sur le torse, **deux antennes**, grosses épaules.
- Fichier de référence du look (à respecter) : `cine/pixel/hi_1.png`.
- Un **modèle 3D déjà généré et riggé** existe (squelette Mixamo standard : Hips, Spine/Spine01/Spine02, LeftUpLeg/LeftLeg/LeftFoot, LeftArm/LeftForeArm/LeftHand, etc.) :
  - `meshy_in/nice_mech/model.glb` (modèle texturé)
  - `meshy_in/nice_mech/rigged.glb` (riggé)
  - `meshy_in/nice_mech/anim_walk.glb` (une marche — **MAIS elle est VOÛTÉE/penchée en avant**, un mauvais retarget d'une marche humaine sur ce mecha massif : à NE PAS réutiliser telle quelle).
- Tu peux **réutiliser ce modèle 3D** (le rigger proprement / lui poser une **marche redressée et articulée**, à la main dans Blender de préférence), **ou** repartir de zéro depuis `hi_1.png` — au choix, du moment que le résultat est **détaillé, articulé, upright (pas voûté) et cohérent frame-à-frame (aucun scintillement)**.

## 3. Ce que je NE veux PAS (déjà essayé, échecs)
- ❌ Image→vidéo (Kling) depuis une image debout → **balancement, jamais articulé**.
- ❌ Génération IA image frame-par-frame → **le perso "bout"/scintille**.
- ❌ Découpe 2D "cut-out" simple (lever de jambes) → **marche sur place, trop raide**.
- ❌ Pixel-art procédural basique → **trop simple / moche**.
- ❌ Auto-rig Meshy + marche humaine retargetée → **posture voûtée de gorille**.
➡️ La seule voie qui donne **détaillé + articulé + cohérent** est un **vrai rig 3D avec une animation upright**, rendu en sprites 2D — c'est ça qu'on veut, mais **avec une bonne posture**.

## 4. FORMAT DE SORTIE EXACT (indispensable pour l'intégration)
Le jeu charge les sprites via `game/actors/DirectionalMecha.gd` selon cette convention **stricte** :

```
game/assets/mecha/<chassis>_<anim>_<dir>.png
```
- `<chassis>` : un nom (ex. `hero`). Dis-moi lequel tu choisis.
- `<dir>` ∈ { `front`, `back`, `left`, `right` }  (front = face à la caméra / vers le bas de l'écran ; back = de dos ; left/right = profils).
- `<anim>` ∈ { `idle`, `walk`, `run`, `attack`, `hit`, `die` }.
- **Chaque PNG = une planche horizontale de N frames de largeur ÉGALE** (une seule ligne). Recommandé : **8 frames** pour idle/walk/run, 6 pour attack, etc. — **dis-moi le nombre de frames par anim** (je le règle dans le code).
- **Fond transparent (RGBA)**, mecha **centré horizontalement** dans chaque frame, **pieds sur une ligne de sol constante** (le perso ne doit pas "sauter" verticalement d'une frame à l'autre — ancre la hauteur sur la frame 0).
- **Toutes les planches d'un même chassis doivent partager la même taille de frame** (même largeur ET hauteur de cellule) → l'échelle reste constante en jeu.
- Résolution de cellule ~**256×256** (ou plus), bords **nets** (pas d'anti-alias baveux sur la silhouette).
- Vue **3/4 top-down** cohérente entre les 4 directions (même caméra, juste l'azimut qui tourne : front=0°, back=180°, left=90°, right=-90°).

Barème de frames conseillé (principes d'animation de jeu) : idle 4-8, marche 6-12, course 4-8, attaque 3-6, hit 2-4, mort 8-16.

## 5. Livrable attendu (2 options, au choix)
- **Option A (idéale)** : produis directement les planches `game/assets/mecha/<chassis>_<anim>_<dir>.png` au format ci-dessus.
- **Option B** : produis les **GLB animés riggés** (idle/walk/run/attack/hit/die, **upright**) dans `meshy_in/<chassis>/`, et je les rends en sprites moi-même avec l'outil existant :
  `python tools/bake_anim.py <in.glb> game/assets/mecha/<chassis>_<anim>.png --frames 8 --res 256 --dirs 4`
  (⚠️ cet outil rend avec bpy **Cycles CPU** — EEVEE échoue en headless ici, pas de GPU côté serveur. Si TOI tu as un GPU, rends comme tu veux, tant que la sortie respecte la §4.)

## 6. Outils déjà présents dans le repo (réutilisables)
- `tools/bake_anim.py` : rend un GLB animé → planche 2D (option `--dirs 4` pour les 4 directions ; `--el` = élévation caméra, défaut 40 ; ancre déjà la hauteur sur frame 0 pour tuer le jitter).
- `tools/meshy_client.py` : client Meshy (image→3D, rig, animate) — clé dans `.meshy_key` (var d'env `MESHY_KEY`), il reste ~180 crédits.
- Blender **bpy 5.0.1** dispo (Cycles CPU).

## 7. Contraintes / notes
- **Ne casse pas** le projet Godot ni les autres assets. Ajoute un **nouveau chassis** (ne pas écraser `lourd`/`valiant` existants) pour que je puisse comparer et brancher.
- Windows, chemins absolus recommandés pour bpy (`os.path.abspath`).
- Quand tu as fini, **liste précisément** : le nom du chassis, le nombre de frames par anim, et les chemins des fichiers produits. Je m'occupe de brancher le mecha dans `game/actors/Player.gd`, d'exporter et de tester en jeu.

Objectif final : un mecha **beau ET qui marche/court/tire de façon vraiment articulée et fluide**, dans les 4 directions, intégrable tel quel. Installe les extensions qu'il te faut et vas-y.
