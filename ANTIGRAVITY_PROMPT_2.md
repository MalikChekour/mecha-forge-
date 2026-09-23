# Prompt #2 pour Antigravity — poses de COMBAT + animation de VISÉE/TIR (chassis bluestrike)

Copie-colle tout ce qui suit à Antigravity.

---

Le chassis mecha **`bluestrike`** que tu as généré est bon (posture droite, articulée, dans `game/assets/mecha/bluestrike_<anim>_<dir>.png`, 2048×256, 8 frames, 4 directions). **MAIS un problème de cohérence** : le mecha a **les bras le long du corps**, alors que dans le jeu il **tire en permanence** (survivor/bullet-heaven, tir auto). Résultat : il a l'air de tirer "à partir de rien", bras ballants. Il n'y a **aucune pose de visée**.

## Ce qu'il faut corriger
Le mecha doit **toujours avoir l'air prêt au combat**, avec des **canons montés sur les avant-bras** (arm-cannons) et les **bras relevés vers l'avant**, jamais ballants. Régénère le jeu d'animations `bluestrike` (même modèle 3D `meshy_in/nice_mech/rigged.glb`, même keyframing Blender upright) ainsi :

1. **`idle`** — debout, **avant-bras/canons relevés en garde vers l'avant**, léger balancement de respiration. (PAS les bras le long du corps.)
2. **`walk`** — marche upright, **avant-bras portés en garde** (canons prêts, coudes fléchis), jambes qui enjambent nettement (**foulée de FACE plus marquée qu'actuellement**, elle était trop discrète).
3. **`run`** — sprint, bras pompant mais canons vers l'avant.
4. **`attack`** = **LA POSE DE VISÉE/TIR** (la plus importante, manquante) : les **deux canons-bras se POUSSENT vers l'AVANT** (vers le haut de l'écran = direction "front"), avec un **kick de recul** répété et un **flash du réacteur cyan**. Elle sera jouée **en boucle pendant que le mecha tire** → fais-en un **cycle qui boucle proprement** (frame 8 → frame 1 sans saut), pas un one-shot.
5. **`hit`** — flinch (garde l'existant si bon).
6. **`die`** — effondrement (garde l'existant si bon).
7. **(BONUS si faisable)** une animation **`melee`** : fente en avant + **grand coup de bras/lame** en arc (le jeu a une attaque sabre au corps-à-corps). Si tu la produis, nomme-la `bluestrike_melee_<dir>.png`, je la brancherai.

## Contraintes (IDENTIQUES à avant — respecte-les strictement)
- Même chassis **`bluestrike`** → **écrase** les planches existantes `game/assets/mecha/bluestrike_<anim>_<dir>.png` (idle/walk/run/attack ; hit/die seulement si tu les améliores).
- Format **exact** : PNG **2048×256** = 8 cellules de 256×256, **fond transparent RGBA**, mecha **centré**, **pieds ancrés sur la hauteur de la frame 0** (pas de saut vertical), **même taille de cellule pour toutes les planches**, bords **nets**.
- 4 directions : `front` (0°, face caméra/vers le bas), `back` (180°), `left` (90°), `right` (-90°). Vue **3/4 top-down ~40° d'élévation**.
- Garde le **look détaillé de `hi_1`** (armure acier bleu, accents orange, cœur cyan). Ne casse pas `lourd`/`valiant`.
- **Vérifie CHAQUE animation en GIF AVANT de baker les 24 planches** — surtout `attack` (bras vers l'avant) et `walk` (foulée). Rends les previews dans `meshy_in/previews/`.
- Outils : `tools/bake_anim.py <in.glb> game/assets/mecha/bluestrike_<anim>.png --frames 8 --res 256 --dirs 4` (bpy Cycles CPU). Test Godot **4.5** : `C:\Users\Administrator\tools\godot45\Godot_v4.5-stable_win64_console.exe`.

## À la fin
Liste : quelles animations tu as (re)générées, si tu as ajouté `melee`, et confirme le format. **Ne touche pas à `Player.gd`** cette fois — c'est moi qui branche la logique (jouer la pose `attack`/visée pendant le tir). Renvoie-moi la main quand c'est baké.

Objectif : un mecha qui a **toujours l'air de viser/tirer** (bras/canons relevés vers l'avant), cohérent avec son tir permanent. Vas-y.
