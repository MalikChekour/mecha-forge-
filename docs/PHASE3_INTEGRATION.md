# Phase 3 — Méta F2P (sets, châssis, maîtrises)

Même branche que la Phase 1 / 2. Les chapitres existent déjà (`Game.CHAPTERS`, `SaveManager.chapters_cleared`). Cette phase ajoute les sets fabricant, le kit de châssis, et 3 défis par biome. Schéma de sauvegarde **2** (`user://mecha_forge_save.json`).

## Sets 2 pc / 4 pc

| Pièce | Fichier |
| --- | --- |
| Données | `SaveManager.MAKERS` = anahei, korr, voss, sena. Chaque pièce a `"maker"`. |
| Tirage / forge / fusion | `gear_pull`, `forge_from_plan`, `gear_merge` (la fusion garde le maker de la première pièce). |
| Migration | `_migrate_schema` : si `schema < 2`, maker = `MAKERS[uid % 4]`, `mastery = {}`, puis `schema = 2`. |
| Bonus | `gear_set_bonus()` compte les pièces **équipées**. |
| Affichage | `MetaScreen._build_gear` (`set_summary`) et `_part_text` (nom du fabricant). |

2 pièces : +8 % de la stat signature.

- Anahei : dégâts
- Korr : PV max (`hp_pct`)
- Voss : vitesse
- Sena : critique

4 pièces :

- Anahei : +1 charge Overdrive par run (`GameState.overdrive_free_casts`). À la fin du spike, `Player._transform_off` remplit la jauge et **ne** pose pas `overdrive_active`.
- Korr : +8 % armure
- Voss : aimant +60 px
- Sena : +8 % XP de run (`run_xp_mult`, assigné au refresh, pas empilé)

Application : `Player._apply_phase3_loadout()`, appelé par `refresh_equipped_chassis` et `_ready`, après `gear_totals()`.

## Passif + actif de châssis

`GameState.CHASSIS_KITS`, lu par `chassis_kit(id)` (passe par `chassis_family`, donc les MK vortex / bluestrike suivent la base).

| Famille | Passif | Actif (touche F) | CD |
| --- | --- | --- | --- |
| vortex | +6 % dégâts | Salve : `add_overdrive(0.35)` | 12 s |
| bluestrike | +5 % vitesse | Dash : ×1,45 vitesse pendant 0,45 s | 8 s |
| titan | +18 PV | Onde 180 px | 16 s |
| bruiser | +8 % dégâts | Choc | 14 s |
| vanquisher | +4 % crit | Rafale d'alignement | 11 s |
| pylone | +5 % dégâts | Impulsion | 15 s |
| cerclier | +4 % vitesse | Dash orbital | 9 s |
| autre | +4 % dégâts | Onde courte | 14 s |

Le garage (`MetaScreen._kit_line`) affiche passif, actif et cooldown. Le dash d'esquive bluestrike (quand on prend un coup) n'est pas cet actif.

Famille inconnue : le repli du tableau ci-dessus. Ajouter une ligne dans `CHASSIS_KITS` pour un nouveau châssis.

## Chapitres et défis

Les 18 chapitres de `Game.CHAPTERS` restent le découpage. À la victoire campagne (`Game._on_run_won`), `SaveManager.commit_run_mastery(biome, run_time, boss5_ok, melee_only)` :

| Id | Condition | Récompense (une fois par biome) |
| --- | --- | --- |
| `nohit` | Boss des 5:00 tué sans dégât **appliqué** pendant qu'il est en vie | 12 noyaux + plan rare (`maker` aléatoire, `source: mastery`) |
| `fast` | `run_time` < 720 s au moment de la victoire | idem |
| `melee` | Aucun `spawn_shot` (le sabre ne passe pas par là) | idem |

Marquage du boss 5:00 : `EnemySpawner._spawn_boss(kind, true)` sur le premier créneau de `BOSS_SCHEDULE`. Meta `mastery_boss5`. `Player.take_damage` ne sale le défi que si les PV baissent vraiment (iframe, bouclier, Overdrive ne comptent pas).

`record_mastery` refuse un second claim. Les flags de run sont remis à zéro dans `GameState.reset`.

## Checklist

1. Équiper 2 pièces du même maker : la ligne de set dans Équipement passe à `2/4 +8%`. Les stats du prochain run bougent (relancer : `refresh_equipped_chassis` ne tourne qu'au départ).
2. 4 Anahei : après un Overdrive, la jauge revient pleine **une** fois, puis le cooldown 16 s reprend.
3. Garage : chaque châssis affiche son passif et son actif. En run, F déclenche l'actif (cooldown `_kit_cd`).
4. Boss 5:00 sans se faire toucher, puis le tuer : à la victoire du chapitre, hint « no-hit 5:00 » et +12 noyaux si le biome ne l'avait pas.
5. Une partie 100 % sabre (aucun autre tir) valide `melee` à la victoire.
6. Recharger une sauvegarde ancienne : les pièces gagnent un maker stable, `schema` vaut 2, les maîtrises vides ne réinitialisent pas les noyaux.

## Hooks optionnels

- `SaveManager.record_mastery("tech", "nohit")` pour créditer sans finir un run (tests).
- `GameState.debug_drop_phase1` reste le hook Phase 1, indépendant.
- HUD : pas de pastille de cooldown d'actif. Brancher `player._kit_cd` / `_kit_cd_max` dans `HUD._process` si on veut l'afficher.

## Risques

Pas de run Godot ici. `gdparse` seulement.

- La victoire scriptée est à 15:00 (`BOSS_SCHEDULE`). Le défi « clear < 12 min » ne se valide en campagne normale qu'avec `--fast-bosses` (horloge des boss compressée) ou une victoire avant 720 s. Le code est en place ; la cadence Survivor le rend inatteignable sans ce drapeau.
- `melee-only` est sali par **tout** projectile joueur, y compris drones et armes automatiques. Le faisceau (`BEAM`) ne passe pas par `spawn_shot` : il ne casse pas le défi. À traiter à part si un châssis démarre sur un rayon.
- La migration retient un maker sur les pièces déjà possédées (`uid % 4`). Ce n'est pas le maker qu'un joueur aurait tiré.
- `_apply_phase3_loadout` réécrit `armor` et `magnet_range` au départ du run. Un bonus d'armure posé avant ce refresh serait écrasé ; au boot ils valent 0.
- `run_xp_mult` est assigné (pas multiplié) au refresh. L'amélioration de run `xpgain` (+0,15) arrive après et s'ajoute encore.
