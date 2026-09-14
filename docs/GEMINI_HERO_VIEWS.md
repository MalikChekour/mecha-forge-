# Vues directionnelles des héros — prompts Gemini (Nano Banana 2 / 3)

Objectif : pour CHAQUE héros (H1..H4), obtenir les **3 vues cohérentes** nécessaires au moteur 4-directions :
**FACE (front)**, **CÔTÉ droit (right)**, **DOS (back)**. Le côté gauche = miroir automatique du droit.
Le corps se tournera vers l'ennemi visé → l'arme pointe la cible (mode combat).

## Règles communes (à respecter dans chaque gen)
1. **ATTACHER l'image de référence existante** (`refs/hero_gemini/hero_hX.png`) → « même robot, même design, mêmes couleurs, mêmes proportions ».
2. **Une seule planche horizontale** : 3 poses côte à côte, **même échelle, même éclairage, même hauteur de pieds** (tous debout sur la même ligne de sol).
3. **Corps entier, pieds visibles**, pose **combat-ready** (arme tenue prête à tirer, tournée vers l'avant du personnage).
4. **Fond MAGENTA UNI `#FF00FF`** (aucune ombre portée sur le fond, aucun texte, aucun cadre) → indispensable pour la découpe automatique.
5. Vue **orthographique légèrement plongeante (~top-down 30°)**, cohérente pour un jeu vu de dessus.
6. Style **identique au sprite existant** (rendu 3D peint, net, contrasté).

Ordre des 3 poses dans la planche, de gauche à droite : **[FACE] [CÔTÉ DROIT] [DOS]**.

---

## H1 — POLYVALENT (mech blanc/bleu type Gundam, fusil bleu lumineux)
```
Character turnaround sprite sheet of THE EXACT SAME robot as the attached reference image:
a white and light-grey humanoid mecha with blue glowing visor and blue energy accents,
holding its blue-glowing rifle. Three full-body poses in one horizontal row, all at the
same scale and standing on the same ground line, slight top-down 30-degree view, combat-ready
stance with the rifle raised forward:
1) FRONT view (facing the camera, rifle aimed forward-down),
2) RIGHT SIDE view (profile facing right, rifle pointing right),
3) BACK view (seen from behind, rifle forward away from camera).
Identical design, colors and proportions in all three. Flat solid magenta #FF00FF background,
no shadow on the background, no text, no frame, crisp painted 3D render.
```

## H2 — AGILE (mech orange/gris, fusil sniper, silhouette élancée)
```
Character turnaround sprite sheet of THE EXACT SAME robot as the attached reference image:
a slim agile orange-and-grey humanoid mecha with a long sniper rifle. Three full-body poses
in one horizontal row, same scale, standing on the same ground line, slight top-down 30-degree
view, combat-ready stance with the sniper rifle held forward:
1) FRONT view (facing camera, rifle across the body pointing forward),
2) RIGHT SIDE view (profile facing right, rifle aimed right),
3) BACK view (from behind, rifle forward away from camera).
Identical design, colors and proportions in all three. Flat solid magenta #FF00FF background,
no shadow, no text, no frame, crisp painted 3D render.
```

## H3 — LOURD (gros mecha blindé gris, néons jaunes, canons d'épaule)
```
Character turnaround sprite sheet of THE EXACT SAME robot as the attached reference image:
a heavy bulky armored grey mecha with glowing yellow vents and blocky armor plates. Give it a
clear heavy arm-cannon / twin shoulder cannons as its weapon. Three full-body poses in one
horizontal row, same scale, standing on the same ground line, slight top-down 30-degree view,
heavy combat stance, cannons pointing forward:
1) FRONT view (facing camera, cannons forward),
2) RIGHT SIDE view (profile facing right, cannons aimed right),
3) BACK view (from behind, big backpack/thrusters visible).
Identical design, colors and proportions in all three. Flat solid magenta #FF00FF background,
no shadow, no text, no frame, crisp painted 3D render.
```

## H4 — ASSASSIN (ninja-robot violet, deux épées d'énergie)
```
Character turnaround sprite sheet of THE EXACT SAME robot as the attached reference image:
a sleek purple ninja-style robot with glowing magenta energy blades in both hands. Three
full-body poses in one horizontal row, same scale, standing on the same ground line, slight
top-down 30-degree view, agile combat stance, blades held ready pointing forward:
1) FRONT view (facing camera, blades forward),
2) RIGHT SIDE view (profile facing right, blades toward the right),
3) BACK view (from behind, blades forward away from camera).
Identical design, colors and proportions in all three. Flat solid magenta #FF00FF background,
no shadow, no text, no frame, crisp painted 3D render.
```

---

## Livraison
Déposer les 4 planches dans `refs/hero_gemini/` sous les noms :
`views_h1.png`, `views_h2.png`, `views_h3.png`, `views_h4.png`

Puis je lance `tools/slice_hero_views.py` → découpe FACE/CÔTÉ/DOS, détoure le magenta,
génère `game/assets/mecha/<hero>_idle_{front,back,left,right}.png` et branche le héros
comme chassis jouable avec visée directionnelle.

### Repli si une planche est incohérente
Si Gemini fait dériver le design entre les 3 vues, génère chaque vue **séparément** (3 gens),
toujours avec l'image de référence attachée, fond magenta, même cadrage. Noms :
`h1_front.png`, `h1_right.png`, `h1_back.png`, etc. Le slicer accepte les deux formats.
