# Ennemis de base - cahier des charges 3D (Meshy)

Concepts 2D (FLUX gratuit) : `refs/enemies_meshy/planche_ennemis.png` (6 images, 2 variantes par ennemi).
Aucune generation Meshy n'a ete lancee (credits non depenses). Valider UNE variante par ennemi avant l'image-to-3D (~30 cr + 5 cr rig, non remboursables).

## Contraintes communes
- Camera du jeu : 3/4 aerien, 8 directions cuites en sprites 256x256 (8 images/anim). Le modele doit rester LISIBLE a ~120 px de haut.
- Identite : noir mat + plaques blanc os, optiques rouges lumineuses (ennemis = rouge/magenta ; le joueur = cyan/orange).
- Silhouette distincte des 3 (taille, forme de tete, posture) : on doit les reconnaitre en noir et blanc.
- Pas de socle, pas de texte, pose neutre, modele ferme (pas de pieces flottantes sauf Guepe : ailerons).
- Export GLB, PBR, ~15 000 triangles max, textures 1024.

## 1. RODEUR - `brute` (chassis `u_rodeur`)
| | |
|---|---|
| Role | Fantassin de corps-a-corps, le plus frequent (poids 6), des 0:00 |
| PV / vitesse / degats contact | 14 / 185 / 6 |
| Taille a l'ecran / rayon | 124 px / 30 |
| Comportement | `rush` : fonce droit sur le joueur, aucune arme a distance |
| Animations a cuire | walk (course penchee), attack (coup de lame), hit, die |
| Specificites visuelles | accroupi, penche vers l'avant ; lames-griffes aux deux avant-bras ; petite tete d'insecte, 2 yeux rouges ; legerement blinde, petit gabarit |
| Concept conseille | **v1** (bipede digitigrade, griffes) : seul compatible avec l'auto-rig humanoide de Meshy ; v2 (arachnide a 4 pattes) = pas d'auto-rig |

Prompt Meshy (image-to-3D, concept v1) : *"Lean predatory biped robot, digitigrade legs, forward-leaning crouch, long blade claws on both forearms, slim insectoid head with two red glowing eyes, matte black and bone-white armor, small, game-ready, symmetrical, A-pose"*.

## 2. GUEPE - `drone` (chassis `u_guepe`)
| | |
|---|---|
| Role | Tireur volant a distance, harcelement (poids 5), apparait a 0:40 |
| PV / vitesse / degats contact | 10 / 235 / 3 |
| Tir | 4 degats toutes les 1,9 s ; garde 280 u de distance |
| Taille a l'ecran / rayon | 78 px / 18 |
| Comportement | `ranged` + vol stationnaire (`hover`) : ne touche pas le sol, pas d'ombre au sol (ombre decollee) |
| Animations a cuire | hover (vibration d'ailerons, boucle), attack (recul du dard), hit, die (chute) |
| Specificites visuelles | corps ovale compact, 2 ailerons translucides, canon-dard sous le ventre pointant vers l'avant, capteur rouge ; AUCUNE patte |
| Concept conseille | **v1** (ailes + dard) ; v2 a des jambes : a ecarter |

Prompt Meshy : *"Small hovering wasp drone, compact oval armored body, two translucent hover wing fins, ventral stinger cannon pointing forward, single red glowing sensor, no legs, matte black and bone-white plates, game-ready"*.
Note : l'auto-rig Meshy est HUMANOIDE : pas applicable. Animer par script (vibration/oscillation) comme les autres volants.

## 3. BELIER - `quadshell` (chassis `u_belier`)
| | |
|---|---|
| Role | Charge en ligne droite (poids 4), apparait a 0:55 |
| PV / vitesse / degats contact | 18 / 178 / 9 (la charge est x1,15, brusque) |
| Taille a l'ecran / rayon | 122 px / 26 |
| Comportement | `dasher` : s'arrete (telegraphe), puis fonce ; ruee breve, pas permanente |
| Animations a cuire | walk (pas lourds), charge (tete baissee), hit, die |
| Specificites visuelles | quadrupede trapu, carapace en dome, grosse corne/tete de belier renforcee, pattes courtes et fortes, noyaux rouges a la poitrine |
| Concept conseille | **v1** (cornes + dome) ; v2 = bipede lourd, moins lisible |

Prompt Meshy : *"Stocky armored quadruped battering ram robot, domed plated carapace, massive reinforced ram horn head, short strong legs, glowing red chest cores, matte black and bone-white armor, symmetrical, game-ready"*.
Note : quadrupede = pas d'auto-rig Meshy humanoide : animation par script (balancement, recul) ou rig manuel.

## Pipeline (ne rien lancer sans validation)
1. Choix d'une variante par ennemi (concepts ci-dessus, a refaire a volonte : gratuit).
2. image-to-3D Meshy -> GLB (compte PAYANT requis : le plan gratuit bloque l'API, erreur 402 deja rencontree).
3. Rig seulement pour le Rodeur ; Guepe et Belier : animation procedurale.
4. Cuisson Blender 8 directions (comme `tools/build_mk_anims.py`), puis remplacement des planches `game/assets/enemies/u_*`.
5. Test en jeu + poids : l'export Web a ~25 Mo de marge (limite itch 200 Mo) : budget max +6 Mo pour les 3 ennemis.
