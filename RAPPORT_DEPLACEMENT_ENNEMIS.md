# Rapport — déplacement des ennemis, 18 niveaux (audit du 24/10, build 12.01)

## Méthode
Audit headless `game/_audit_deplacement.tscn` (script `_audit_deplacement.gd`, données brutes `tools/audit_deplacement_corrige.json`). Pour **chacun des 18 niveaux**, au temps de jeu 6:40 (rôles secondaires, Mark 2 et escouades déjà actifs) : 24 ennemis de base tirés par le spawner réel (`_spawn`, donc rôles et styles de tir du niveau) + 1 Mark 2, 1 intermédiaire, 1 mini-boss, 1 boss + 2 escouades (chef, lieutenants). Chaque ennemi est observé **20 s de jeu** avec le vrai code `Enemy._physics_process`, dans deux scénarios : **joueur immobile** (`fixe`) et **joueur en mouvement** (`mobile`, cercle de 320 px à ~0,9 rad/s). Mesures par groupe : vitesse moyenne réelle (px/s), % du temps quasi immobile (< 1,3 px/s), demi-tours par minute (inversion de direction > 90°), distance gagnée vers le joueur en 20 s, nombre de directions de regard utilisées (sur 8).
Référence : le joueur de référence va à 336 px/s.

## Verdict

- **Les ennemis de tous les niveaux se déplacent** : avec un joueur en mouvement, moins de 3 % du temps immobile pour TOUS les niveaux (0,3–2,6 %), vitesse moyenne 91–122 px/s (≈ 0,27–0,36 × la vitesse du joueur : moyenne qui inclut le strafe et le maintien à distance des tireurs), 370–515 px gagnés vers le joueur en 20 s.
- **Les 8 directions fonctionnent** partout : 7,5–8 directions de regard utilisées sur 8 (7–7,9 quand le joueur est immobile).
- **Pas d'instabilité** : 19–65 demi-tours par minute et par ennemi (≈ 1 toutes les 1–3 s : le strafe des tireurs, pas du tremblement). Plus haut aux niveaux 4 (56, mineurs) et 14 (65, snipers) avec joueur immobile.
- **Points à surveiller** (voir §Anomalies) : escouades en formation qui restent plantées quand le joueur ne bouge pas, quelques groupes lents.

## Par type d'ennemi (tous niveaux confondus)

| Groupe | Joueur | n | Vitesse px/s | Immobile % | Demi-tours/min | Approche px (20 s) | Directions |
|---|---|---|---|---|---|---|---|
| dasher | fixe | 64 | 109 | 11.4 | 33 | 539 | 8.0 |
| dasher | mobile | 65 | 124 | 0.4 | 34 | 520 | 8.0 |
| grade_chef | fixe | 34 | 74 | 24.7 | 34 | 399 | 6.7 |
| grade_chef | mobile | 33 | 92 | 2.2 | 22 | 377 | 8.0 |
| grade_elite | fixe | 67 | 113 | 3.8 | 31 | 425 | 8.0 |
| grade_elite | mobile | 75 | 122 | 0.2 | 27 | 402 | 8.0 |
| grade_lieutenant | fixe | 38 | 66 | 29.3 | 32 | 391 | 7.1 |
| grade_lieutenant | mobile | 37 | 88 | 3.3 | 21 | 340 | 8.0 |
| miner | fixe | 61 | 82 | 6.2 | 51 | 514 | 8.0 |
| miner | mobile | 64 | 95 | 1.2 | 28 | 533 | 8.0 |
| rang_boss | fixe | 18 | 88 | 7.0 | 29 | 463 | 4.6 |
| rang_boss | mobile | 18 | 99 | 3.9 | 28 | 465 | 8.0 |
| rang_inter | fixe | 16 | 103 | 0.7 | 39 | 500 | 6.3 |
| rang_inter | mobile | 16 | 106 | 0.3 | 34 | 496 | 8.0 |
| rang_mini | fixe | 16 | 109 | 0.7 | 34 | 560 | 6.7 |
| rang_mini | mobile | 16 | 112 | 0.3 | 28 | 536 | 8.0 |
| rang_mk2 | fixe | 16 | 108 | 0.2 | 34 | 505 | 6.4 |
| rang_mk2 | mobile | 16 | 112 | 0.1 | 32 | 495 | 7.9 |
| ranged | fixe | 172 | 95 | 10.7 | 29 | 379 | 8.0 |
| ranged | mobile | 166 | 105 | 1.3 | 26 | 387 | 8.0 |
| ranged+anneau | fixe | 36 | 89 | 12.0 | 25 | 403 | 8.0 |
| ranged+anneau | mobile | 33 | 101 | 0.5 | 31 | 425 | 8.0 |
| ranged+eventail | fixe | 47 | 94 | 10.7 | 34 | 379 | 8.0 |
| ranged+eventail | mobile | 49 | 102 | 1.5 | 22 | 374 | 8.0 |
| ranged+guide | fixe | 27 | 89 | 11.1 | 28 | 344 | 8.0 |
| ranged+guide | mobile | 23 | 97 | 2.9 | 24 | 330 | 8.0 |
| ranged+orbe | fixe | 8 | 107 | 1.4 | 26 | 402 | 8.0 |
| ranged+orbe | mobile | 6 | 107 | 0.9 | 26 | 374 | 8.0 |
| ranged+rafale | fixe | 31 | 108 | 1.7 | 32 | 420 | 7.9 |
| ranged+rafale | mobile | 34 | 111 | 0.6 | 26 | 395 | 8.0 |
| ranged+sniper | fixe | 30 | 90 | 4.8 | 45 | 411 | 8.0 |
| ranged+sniper | mobile | 34 | 100 | 0.6 | 33 | 405 | 8.0 |
| rush | fixe | 8 | 24 | 76.6 | 16 | 681 | 8.0 |
| rush | mobile | 5 | 177 | 0.2 | 23 | 395 | 8.0 |

## Par niveau (joueur en mouvement ; entre parenthèses : joueur immobile)

| Niv. | Biome | n | Vitesse px/s | Immobile % | Demi-tours/min | Approche px | Dir. | Remarques |
|---|---|---|---|---|---|---|---|---|
| 1 | tech | 36 | 112 (109) | 0.5 (1.4) | 30 (31) | 400 (401) | 8.0 |  |
| 2 | desert | 36 | 120 (115) | 0.5 (6.7) | 30 (33) | 483 (500) | 8.0 | figés si joueur immobile : grade_elite |
| 3 | jungle | 38 | 122 (92) | 0.5 (16.3) | 26 (27) | 392 (416) | 8.0 | figés si joueur immobile : rush, grade_chef |
| 4 | volcanic | 38 | 95 (82) | 0.9 (7.2) | 24 (56) | 439 (446) | 8.0 | figés si joueur immobile : grade_chef |
| 5 | swamp | 38 | 102 (92) | 0.4 (10.0) | 27 (28) | 384 (382) | 8.0 | figés si joueur immobile : grade_chef |
| 6 | cryo | 40 | 106 (97) | 0.8 (4.5) | 33 (34) | 430 (444) | 8.0 | figés si joueur immobile : dasher |
| 7 | reacteur | 13 | 110 (105) | 1.5 (5.8) | 29 (29) | 438 (420) | 8.0 | figés si joueur immobile : grade_chef |
| 8 | ruche | 40 | 117 (97) | 0.7 (12.4) | 24 (30) | 378 (469) | 8.0 | figés si joueur immobile : rush, grade_chef |
| 9 | citadelle | 42 | 101 (72) | 2.5 (21.9) | 30 (33) | 404 (352) | 8.0 | figés si joueur immobile : ranged, grade_chef, grade_lieutenant |
| 10 | abyss | 42 | 98 (87) | 2.1 (14.0) | 25 (27) | 372 (375) | 8.0 | figés si joueur immobile : dasher, grade_chef, grade_lieutenant |
| 11 | ether | 42 | 116 (112) | 0.4 (10.1) | 30 (30) | 373 (407) | 8.0 | figés si joueur immobile : grade_elite |
| 12 | titans | 44 | 101 (95) | 2.0 (2.2) | 29 (41) | 509 (513) | 8.0 |  |
| 13 | orbit | 44 | 104 (92) | 2.5 (17.8) | 20 (24) | 394 (425) | 8.0 | figés si joueur immobile : dasher, ranged, grade_chef, grade_lieutenant |
| 14 | quantum | 19 | 91 (70) | 0.4 (14.2) | 28 (65) | 378 (398) | 8.0 | figés si joueur immobile : ranged+sniper, grade_lieutenant |
| 15 | ozone | 46 | 120 (108) | 0.5 (7.4) | 32 (32) | 515 (519) | 8.0 |  |
| 16 | prism | 46 | 94 (93) | 2.6 (9.0) | 19 (38) | 373 (387) | 8.0 | figés si joueur immobile : grade_chef, grade_lieutenant |
| 17 | steampunk | 46 | 99 (86) | 1.3 (13.7) | 27 (35) | 497 (464) | 8.0 | figés si joueur immobile : ranged, grade_chef, grade_lieutenant |
| 18 | colosseum | 40 | 100 (81) | 0.3 (16.1) | 30 (25) | 415 (402) | 8.0 | figés si joueur immobile : grade_chef, grade_lieutenant |

## Anomalies et pistes
1. **Chefs de meute et lieutenants figés à 22–30 % du temps quand le joueur ne bouge pas** (niveaux 9, 13, 16, 17, 18 surtout ; aussi 3, 4, 5). Cause probable : ils tiennent leur emplacement de formation (embuscade, feu et mouvement, fer à cheval) tant que l'escouade n'est pas « engagée ». Avec un joueur en mouvement le phénomène disparaît (0,3–3 %). **Reco** : faire engager l'escouade (poids de formation → 0) dès qu'elle est à portée de tir ou après N secondes, quel que soit le joueur.
2. **Snipers du niveau 14** : 14 % immobiles avec joueur fixe (charge de 0,6 s + budget de tir) — attendu pour un tireur d'élite, à garder si c'est voulu comme moment de télégraphe.
3. **Ennemis de mêlée « rush » avec joueur immobile** : 77 % immobiles, mais ils sont arrivés sur le joueur (681 px parcourus) et s'y tiennent : comportement normal.
4. **Mineurs** (niveaux 4, 12, 17) : 51 demi-tours/min avec joueur fixe → strafe nerveux ; vitesse correcte avec joueur mobile. À regarder en jeu si ça paraît saccadé.
5. **Vitesse moyenne basse (≈ 0,3 × joueur)** : c'est volontaire (ratio 0,50–0,53 × joueur de référence, tireurs qui se maintiennent à distance) ; les charges (dasher) et kamikazes montent à ≈ 109 px/s en moyenne avec leurs phases d'armement.

## Limites (honnêteté)
- **Simulation logique, pas le rendu** : aucune capture Web ; le « fluide » ressenti dépend aussi des animations et du framerate.
- **Pas de décor/obstacles** dans ce banc (aucun solide : `cover_list` vide) ni de plafond d'ennemis réel ; **faux joueur** (pas de collisions ni de dégâts).
- ⚠️ **Découverte importante sur le banc d'équilibre** : à `--scale=6`, Godot passe un **pas physique de 0,1 s** (`get_physics_process_delta_time` = 0,1 au lieu de 0,0167). Mes vitesses ont été corrigées en conséquence, mais **les parties du banc d'équilibre `_bal_run` faites à ×6 utilisent des pas de 0,1 s** (collisions et balles moins précises). Leurs tendances restent utiles mais les chiffres de survie sont à **revérifier à `--scale=2` ou 3**.

---

# Audit n°2 (après corrections) — 24/10

## Ce qui a été corrigé
1. **Escouades** (`Squad.gd`) : une escouade s'engage maintenant dès qu'un membre est à moins de 320 px du joueur ou après 12 s (avant : emplacements tenus tant que le joueur ne bougeait pas). Embuscade : déclenchement à 5 s au lieu de 8 s.
2. **Mineurs** (`Enemy.gd`) : strafe plus posé (changement de sens toutes les 2,6–4,6 s au lieu de 1,2–2,6 s, vitesse de strafe 0,55 au lieu de 0,65).
3. **Banc et audit** : pas physique corrigé (`Engine.physics_ticks_per_second = 60 × accélération`, donc delta = 1/60 quelle que soit l'accélération). `_bal_run.gd` est corrigé aussi : **les futures mesures d'équilibre sont à pas physique normal** (les anciennes, faites à ×6 avec un pas de 0,1 s, sont à refaire pour les chiffres de survie).
4. Essai écarté : lissage de la poussée de séparation entre ennemis → aucun effet mesurable (251 vs 256), **retiré**.

## Résultats (≈ 700 ennemis observés par scénario, 18 niveaux, 20 s de jeu)
| Mesure | Audit 1 (joueur immobile) | Audit 2 (joueur immobile) | Audit 1 (joueur mobile) | Audit 2 (joueur mobile) |
|---|---|---|---|---|
| Temps immobile | 10,7 % | **3,4 %** | 1,2 % | **0,4 %** |
| Groupes > 15 % immobiles | **29** | **5** | – | – |
| Chefs de meute immobiles | 24,7 % | **8,3 %** | 2,2 % | 1,8 % |
| Lieutenants immobiles | 29,3 % | **3,9 %** | 3,3 % | 0,9 % |
| Directions de regard (sur 8) | 7,7 | 7,3 | 8,0 | 8,0 |
| Distance gagnée vers le joueur en 20 s | 431 px | 435 px | 422 px | 332 px* |

\* l'audit 1 faisait tourner le joueur 6 fois trop vite (pas de 0,1 s) ; la valeur de l'audit 2 est la bonne.
Vitesse moyenne réelle (joueur mobile) : **134 px/s** (≈ 0,4 × le joueur de référence ; charges et kamikazes plus rapides : ≈ 190 px/s pour les kamikazes).

## Par niveau — joueur en mouvement | joueur immobile
(vitesse px/s · % immobile · distance gagnée px · directions)
Tous les niveaux : 116–163 px/s, 0,1–2,9 % immobile (mobile) ; 82–105 px/s, 1,2–10,2 % immobile (fixe). Détail dans `tools/audit_deplacement.json`.

## Restent > 15 % immobiles (joueur fixe) — jugés normaux
- niv. 3 (chef 26 %, élite 16 %) et niv. 6 (chef 40 %) : escouade en embuscade/ligne qui attend son déclenchement ;
- niv. 8 « rush » (44 %) : ils sont **arrivés au contact** du joueur immobile et s'y tiennent ;
- niv. 10 dasher (18 %) : phases d'armement de la charge.

## Correction d'une erreur de mesure
Ma mesure des « demi-tours » compte des **échantillons**, pas des événements : un demi-tour (≈ 0,25 s) en fait ≈ 15. Le chiffre brut de l'audit 2 (≈ 250 avec joueur fixe, ≈ 60 avec joueur mobile) correspond donc à **≈ 17 demi-tours/min (un toutes les 3,5 s) et ≈ 4/min** : c'est le strafe normal des tireurs, **pas du tremblement**. Contre-vérification : trace d'un tireur isolé = inversion propre toutes les 1–2,5 s (rampe d'accélération de 0,3 s, aucune oscillation).

## Limites
Simulation logique sans décor ni collisions, faux joueur, pas de rendu. Aucune capture Web regardée. Corrections commitées mais **non publiées** (la publication de versions est gérée avec Antigravity).
