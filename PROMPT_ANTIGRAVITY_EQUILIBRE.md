# MISSION ANTIGRAVITY — Équilibrer MECHA-FORGE : mécha joueur vs ennemis, difficulté croissante, hiérarchie d'ennemis

Projet : `C:\Users\Administrator\mecha-forge` (Godot 4.3, jeu dans `game/`). Réponds en FRANÇAIS. Ne colle jamais de clé (`.itch_key`, `.meshy_key`). Départ : dernier commit de la branche courante (message « feat(hierarchie): ordre d'apparition scripté… »). Retours possibles : tags `v11.96` (dernière version publiée), `v11.88`.

## 1. Objectif (demande du patron)
Trouver l'équilibre entre **la montée en puissance du mécha du joueur** et **la difficulté croissante des ennemis** sur les **18 niveaux** : de plus en plus dur d'un niveau à l'autre, **jamais impossible**. Les niveaux 1–5 doivent être « normaux » (pas trop faciles). Recalculer aussi **la vitesse mécha joueur vs ennemis**. Intégrer la hiérarchie d'ennemis **base → Mark 2 → intermédiaire → mini-boss → boss**.

## 2. Ordre d'apparition (décidé — source : `docs/SURVIVOR_IO_PLAYBOOK.md` §5, timeline scriptée)
Pour chaque niveau (déjà codé : `TIER_EVENTS`, `_tier_tick`, `_mk2_share`) :

| Temps | Événement |
|---|---|
| 0:00 | **Ennemi de base** (continu) |
| 1:30 | **Mark 2** introduits (0→35 % des apparitions) |
| 2:00 | **Intermédiaire** (puis 1 / 90 s, 2 vivants max) |
| 3:00 | **Mini-boss** (puis 8:00 et 12:00) |
| 5:00 | **Boss 1** (rang 3, ne change pas de zone) — la base devient surtout Mark 2 (60 %) |
| 10:00 | **Boss 2** — Mark 2 à 80 % |
| 15:00 | **Boss final** — sa mort = victoire |

Pendant un boss : apparitions ×0,6 et une escouade invoquée toutes les 22 s. Les rangs réutilisent le sprite de l'ennemi du niveau (teinte, taille, PV, armement, défenses différents ; pas de nouveau modèle 3D, **ne pas utiliser Meshy**). Si le patron demande un autre ordre, adapter `TIER_EVENTS`.

## 3. Outil de mesure (à utiliser — c'est le cœur de la mission)
Le vrai jeu en headless avec le bot joueur intégré, un chapitre, durée accélérée :
```
C:\Users\Administrator\godot_ci\Godot_v4.3-stable_win64_console.exe --headless --path game res://_bal_run.tscn -- --ch=8 --secs=900 --scale=6
```
Sortie (toutes les 60 s, puis 20 s après 4:40) : niveau, PV, ennemis vivants, kills, vitesses joueur/ennemis, rangs vivants avec PV (`[mini 424/616][boss1 399/509]`). ≈ 15 s de mur par minute de partie ; s'arrête à la mort du bot. Lancer les 18 chapitres en 3 groupes parallèles, puis `python tools/bal_resume.py <fichier>` donne le tableau. Mes séries historiques : `tools/bal_resultats/bal_all*.txt`.
⚠️ Le bot est **naïf** (1re carte du draft, n'esquive pas) = plancher de puissance. ⚠️ **Forte variance** : faire **≥ 3 passes par niveau** avant de conclure.

## 4. Ce qui est mesuré
- Au départ : niveaux 6/9/10/12/14 mortels en 25–50 s ; beaucoup d'autres niveaux tenaient 900 s avec 50–85 % de PV mini → trop faciles et **aucune tendance croissante avec le niveau**.
- Causes traitées : tireurs en foule (budget de tir global), boucliers/garde/protecteur dès t=0, escouades trop grosses au début, dégâts par coup trop forts (mines, kamikaze, sniper), **vitesse ennemie à 0,64× le joueur → rushes mortels niveaux 10–16 en < 90 s** (la vitesse est le réglage le plus sensible ; actuellement 0,50→0,53× du joueur de référence 336 px/s).
- **Reste ouvert** : ≈ 25 % de **morts précoces aléatoires** (26–170 s) aux niveaux hauts (9, 10, 12, 13, 15, 16, 18). Dernier correctif NON mesuré : pas de charge/kamikaze/mine avant 1:00, 1re escouade à 40 s, débit de tir ×0,6→1 sur la 1re minute.
- **Boss 1 niveau 1** : tombe en ~170 s (reste à 55 PV pendant ~80 s) → trop long, à investiguer (garde 12 %, kiting hors de portée, invocations…). J'ai retiré l'esquive des boss. **Boss final niveau 7** avait tué le bot (PV/dégâts baissés depuis, non remesuré). Mini-boss ~20–60 s OK, intermédiaires OK.

## 5. À faire
1. **Supprimer les morts précoces** : ajouter au banc un **journal des sources de dégâts** (rôle/style de tir/mine/kamikaze/contact) pour identifier QUELLE combinaison tue, au lieu de deviner ; corriger.
2. **Courbe de difficulté cible** (bot naïf, méta nulle, ≥ 3 passes × 18 niveaux) : **aucune mort avant 3:00** ; survie médiane **décroissante** : niv. 1–3 ≈ 900 s, 4–9 ≈ 600–900 s, 10–15 ≈ 450–700 s, 16–18 ≈ 300–550 s ; un humain (méta + bonnes cartes) doit pouvoir gagner chaque niveau.
3. **Hiérarchie** : mini-boss 20–60 s à tuer, boss 1/2 ≈ 60–120 s, boss final ≈ 60–120 s pour un bot niveau ~17 ; attaques télégraphiées lisibles. Vérifier en jeu (banc + captures Web) que les rangs sont visuellement distincts (teintes `TIERS`, bandeaux « MARK 2 / INTERMEDIAIRE / MINI-BOSS / BOSS »), que la **victoire** se déclenche à la mort du boss final (`is_final`, `Events.run_won`), que le mode SANS FIN (`GameState.endless`) ne casse pas, que `_boss_up()` ralentit bien les apparitions.
4. **Courbe de puissance du joueur** : `GameState.add_xp` fait `xp_to_next ×1,35+2` (exponentiel) alors que survivor-td (`github.com/xarlord/survivor-td`, GAME_SPEC.md §6) utilise 5+3N (linéaire) ; PV ennemis +12 %/min. Évaluer si le joueur cale en fin de partie, comparer avec survivor-td et opensurvivor (`Kalaith/opensurvivor`, `game/systems/spawning.py`), proposer **et mesurer** les réglages (courbe d'XP, effet des cartes, `GameState.META` plafonnée ≈ +30 %). **Annoncer au patron tout changement de l'économie de méta.**
5. **Vitesses** : mesurer le ratio ennemi/joueur (le banc affiche `vit_joueur` / `vit_ennemis_moy` ; le joueur monte à 376–472 px/s avec les cartes), régler par rôle (rush, charge, kamikaze, tireur, mineur, boss), vérifier que la fuite reste possible et que le kiting n'est pas gratuit.
6. **Performance** (le patron se plaint des saccades en foule) : ne pas dégrader. Le budget de tir global (`Enemy._fire_ok`, `fire_rate`) et la séparation échelonnée sont là pour ça ; coût logique ≈ 18 ms/image à 200 ennemis en headless — ne pas le faire remonter.

## 6. Où est le code
- `game/systems/EnemySpawner.gd` — bloc `>>> PROFILS DE NIVEAU` **généré** par `tools/_patch_profils.py` depuis **`tools/_profils_block.gd.txt` : modifier le .txt puis relancer le script, sinon l'édition est écrasée**. Contient `PROFILES` (18 niveaux : motif d'apparition, rôles, formations, `tier`), `PHASES`, `TIERS` + `TIER_EVENTS`, `_role_def` (vitesse, cadence, dégâts), `_def_for` (montée en charge 2 premières minutes), `_scale_enemy` (PV ×(1+0,04×(tier−1))×(1+0,002×t), dégâts ×(1+0,0008×t), pas de dégâts par niveau).
- `game/systems/Squad.gd` (13 formations, chef/lieutenants), `game/actors/Enemy.gd` (visée, styles de tir, garde, esquive, protecteur, budget de tir global, LOD).
- Joueur : `game/actors/Player.gd` (base_speed 320 × mécha 1,05), `game/autoload/GameState.gd` (XP, `META`), `game/scenes/Game.gd` (`UPGRADES`, `_apply_upgrade`, `_drive_bot`).
- Plafonds de sécurité à conserver : vitesse ennemie ≤ 80 % de celle du joueur, ENEMY_CAP 220, brèche de 60° dans l'encerclement.

## 7. Contraintes
- Pack Web < 200 Mo (116 Mo). Tests à garder verts : `_test_escouades`, `_test_profils_niveaux`, `_test_chapters`, `_test_boss_chapitres`, `_test_kill_tracking`, `_test_all_18_chapters_gameplay` ; en ajouter pour ce que tu crées (budget de tir, montée en charge, calendrier des rangs, victoire boss).
- Un commit par étape ; pas de `git add -A` (dossiers temporaires `web_dbg/`, profils Chrome). Version : `game/project.godot` + 2 lignes `version/name` de `game/export_presets.cfg` (11.96 → 11.97). Nouvelle `class_name` → `Godot --headless --path game --import` une fois.
- Publication : build `--export-release "Web" ../web/index.html` puis `butler push web whimora/mecha-forge:html5 --userversion X` (clé lue dans `C:\Users\Administrator\.itch_key`, jamais affichée). Le canal met 10–20 min à traiter et refuse un push tant que le précédent n'est pas traité. L'upload manuel par navigateur échoue : ne pas s'y acharner.

## 8. Livrable
1. Corrections commitées + tag + build Web + push butler.
2. **Tableau 18 niveaux** avant/après : survie médiane (≥ 3 passes), niveau atteint, PV min %, rangs rencontrés, temps pour tuer mini-boss/boss.
3. Liste des réglages modifiés, chacun avec la mesure qui le justifie.
4. Liste honnête de ce qui n'a PAS pu être vérifié (le bot n'est pas un humain ; aucune capture Web des rangs n'a été vue côté Claude).
