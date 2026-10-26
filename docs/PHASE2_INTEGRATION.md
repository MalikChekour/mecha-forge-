# Phase 2 — Resserrement (kami, invocateur, télégraphes, ObjectPool)

Branche `cursor/phase1-quick-wins-7b4f`. La Phase 1 (bombe, aimant, hitconfirm sabre, murs soft, `roll_phase1_drop`) n'est pas réécrite. Les drops Phase 1 passent désormais par `Game.spawn_phase1_pickup` → le pool de pickups.

Copie miroir : `game/actors|autoload|systems|scenes` → `res://actors|autoload|systems|scenes`.

## Où c'est branché

| Besoin | Fichier | Hook |
| --- | --- | --- |
| Archétypes | `game/systems/EnemySpawner.gd` | `_ensure_phase2()` remplit `PHASE2_DEFS` / `PHASE2_EXTRA`. **BIOME_POOL reste à 5 slots** (base, swarm, shield, sniper, elite). |
| Tirage | `_weighted_pick` | Après le pool du biome, ajoute `mechNN_kami` (poids 3, dès 40 s) et `mechNN_summoner` (poids 2, dès 70 s). Les vagues `fodder_only` gardent le kami et excluent l'invocateur. |
| Stats | `_def_for` | Les ids `*_kami` / `*_summoner` ne passent pas par la fusion de rôle. σ HP = ×0,70 (kami) et ×1,60 (summoner) sur les PV de la base du biome, puis le petit bonus de palier déjà utilisé pour les spécialistes. |
| Kami | `game/actors/Enemy.gd` `behavior == "kami"` | Rush ×1,35. À ≤ 110 px : anneau `spawn_ground_zone` **0,6 s**, vitesse ×0,25, puis explosion et `take_damage` (XP + drop Phase 1 inchangés). Le rôle `kamikaze` (mèche shader, zone 0,05 s) est intact. |
| Invocateur | `behavior == "summoner"` | Toutes les 8 s, 3 drones `pool[1]` (swarm) tant qu'il en a moins de 6 vivants et sous `ENEMY_CAP`. |
| Bande élite | `Enemy._telegraph_band` | Elite, `rank >= 1` ou meta `phase1_elite`. Bande `shape = "line"` 0,5–0,9 s + pulse circulaire. Un tir sur 1,2 s. Appelé depuis le tir ranged, le canon lourd et l'ogive. |
| Boss 50 % / 20 % | `Enemy._check_boss_phase` | Palette chaude sur le sprite à 50 % PV. À 20 %, `spawner.spawn_spiral_squad()` → `_spawn_squad(true, "spirale")`. Les phases existantes (`_phase_ranged_ogive`, crusher, bélier, biomes) restent devant. |
| Pool | `game/systems/ObjectPool.gd` | `setup` / `prewarm` / `acquire` / `release` → `reset()` ou `deactivate()`. Jamais `queue_free`. |
| Branchement pool | `game/scenes/Game.gd` `_ensure_pools` | 128 `Projectile`, 64 `EnemyProjectile`, 32 `GroundZone` cercle, 64 `VfxSprite`, 48 `Pickup`. |

`spawn_shot`, `reclaim_proj`, `spawn_enemy_bolt`, `recycle_enemy_bolt`, `spawn_vfx`, `reclaim_vfx`, `spawn_ground_zone`, `reclaim_ground_zone`, `_spawn_pickup`, `reclaim_pickup` gardent leurs noms.

Les zones `shape == "line"` ne sont pas poolées : le visuel est construit une fois dans `_ready`. Le chemin chaud (mines, ogives, anneau kami) reste circulaire et poolé.

## Checklist run

1. Lancer un chapitre tech (ou n'importe quel biome à pool non vide).
2. Avant 40 s : pas de kami. Avant 70 s : pas d'invocateur. Rush / blindé / sniper / élite d'escouade inchangés (slots 0–4).
3. Après 40 s : un `mechNN_kami` fonce, l'anneau orange tient ~0,6 s, puis explose. Il meurt dans la zone.
4. Après 70 s : un invocateur tient la distance et lâche 3 drones fragiles. Une bombe Phase 1 au milieu du groupe les efface (AoE 420).
5. Tuer un élite ou un rang ≥ 1 : une bande rouge précède le tir.
6. Boss à 50 % PV : teinte rose. À 20 % : bannière d'escouade spirale si le plafond d'ennemis le permet.
7. Murs soft 3:00 / 8:00 toujours via `SOFT_WALLS` (plancher ×1,6 plafonné à 24, grace 18 s).
8. Les projectiles / étincelles / gemmes ne doivent plus `queue_free` en boucle. Vérifier dans le débogueur que les nœuds `Projectile` restent enfants de `projectile_layer`.

## Hooks optionnels

- Forcer un archétype : `spawner.spawn_at(player.global_position + Vector2(400, 0), "mech01_kami")` (après le premier `_process`, `_ensure_phase2` a tourné). Idem `mech01_summoner`.
- Monter le poids : `PHASE2_DEFS["mech01_kami"]["w"] = 30` et `unlock = 0`.
- Désactiver la spirale : ne pas appeler `spawn_spiral_squad` (garder `_phase2_palette`).
- Le cap de bolts ennemis reste `ENEMY_BOLT_CAP` (150 vivants), compté par `_ebolt_live`.

## Risques

Pas d'éditeur Godot dans cet environnement : syntaxe validée avec `gdparse` seulement.

- Les lambdas de préchauffage allouent 128 projectiles au boot. Sur mobile faible, baisser `prewarm` sans toucher au cap.
- L'overflow du pool ne libère pas les nœuds. Un pic au-dessus du cap les parque hors écran.
- `GroundZone` circulaire préchauffé a un missile (rayon 110). `arm()` le cache si le rayon passe sous 100.
- L'invocateur + `ENEMY_CAP` 220 peut rater une vague de drones. C'est voulu.
- Le kami peut être promu élite par `_maybe_elite` (id `mech…`). Il reste fragile (×0,70 avant l'élite).
