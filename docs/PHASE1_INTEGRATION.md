# Phase 1 — Quick wins (Mecha-Forge)

Pack à copier dans `C:\Users\Administrator\mecha-forge`. Les scripts de `game/` sont le snapshot d’audit **plus** les quatre changements. Godot 4.3, GDScript typé, mêmes autoloads (`GameState`, `Audio`, `Events`).

`Audio.gd` et `Events.gd` ne sont pas modifiés : `Audio.sfx(nom, pitch_var)` fait déjà `pitch_scale = 1 ± pitch_var`, et `Events.screen_shake` reste un signal à un seul `float`.

## Copier

Les chemins exacts sont ceux déjà enregistrés dans le projet (recherche `class_name Pickup` / section `[autoload]` de `project.godot`). Le préload `res://actors/StackPips.gd` indique que les acteurs vivent en général dans `actors/`.

| Fichier de ce dépôt | Écraser dans mecha-forge |
| --- | --- |
| `game/Pickup.gd` | script `class_name Pickup` |
| `game/Player.gd` | script `class_name Player` |
| `game/Enemy.gd` | script `class_name Enemy` |
| `game/EnemySpawner.gd` | script `class_name EnemySpawner` |
| `game/GameState.gd` | script de l’autoload `GameState` |

Aucun nouvel autoload. Aucun asset obligatoire : `Tex.get_tex("res://assets/pickups/bombe.png", …)` et `aimant.png` retombent sur une texture générée si le PNG n’existe pas, comme les autres kinds.

`Player.gd` du snapshot est en fins de ligne CRLF ; les quatre autres scripts sont en LF. La copie intégrale conserve ça.

### Patch, si l’arbre local est encore ce snapshot

Depuis le dossier qui contient les cinq scripts (souvent `actors/`, et le dossier de l’autoload pour `GameState.gd` — dans ce cas, copier le patch à côté ou ajuster les chemins) :

```
patch -p1 --binary --dry-run < docs\phase1.patch
patch -p1 --binary < docs\phase1.patch
```

`--binary` est nécessaire : le hunk de `Player.gd` est en CRLF, le reste en LF. Vérifié sur le snapshot d’audit. Si un hunk refuse parce que le fichier a divergé, garder la copie intégrale du script livré, ou reporter à la main les fonctions listées plus bas.

## 1. Pickup bombe

**Kinds** : `"bombe"` (alias accepté à l’init : `"bomb"`).

Au ramassage (`Pickup._physics_process`, distance &lt; 30), `GameState.detonate_bomb(player.global_position, game)` puis `reclaim_pickup` comme les autres drops.

| Cible | Effet | API réelle |
| --- | --- | --- |
| `rank < 3` (pietaille, élite, mini-boss) | `hp_max * 0.35` | `Enemy.take_damage(montant, "", "bombe")` |
| `rank >= 3` (boss) | `hp_max * 0.08`, puis stun 1,2 s | `Enemy.apply_stun(1.2)` |
| boss sans `apply_stun` | même dégâts réduits + vélocité 1400 px/s vers l’extérieur | `velocity` (repli, l’API existe dans ce snapshot) |

Rayon **420**. Bouclier et garde passent par `take_damage` : ils absorbent comme un coup normal. Un kill porte `_last_weapon_id = "bombe"` et **ne relance pas** le tirage de drop (pas de chaîne bombe → bombe). Les gemmes d’XP habituelles (`spawn_xp`) tombent quand même.

VFX : `game.spawn_vfx("shockwave", …)` et `"aaa_shockwave"` si la méthode existe, `Events.screen_shake.emit(11.0)` (un coup subi du joueur est à 6), `Audio.sfx("explosion", 0.06)`, flash plein écran (CanvasLayer 80, ~0,18 s, libéré par tween).

## 2. Pickup aimant

**Kinds** : `"aimant"` (alias : `"magnet"`).

`GameState.activate_magnet_vacuum()` pose `magnet_vacuum = true` pendant **2,5 s** (`MAGNET_VACUUM_DUR`). `Player._physics_process` appelle `GameState.tick_magnet_vacuum(delta)` chaque frame, y compris pendant Overdrive.

Le vacuum existant est inchangé dans son mécanisme, avec un troisième terme :

```gdscript
if d < mrange or GameState.overdrive_active or GameState.magnet_vacuum:
    _homing = true
```

L’aimant n’écrit pas `overdrive_active`, ne lance pas `_transform_on`, ne donne pas d’iframe. Overdrive (invulnérabilité, vitesse ×2, faisceau, cooldown 16 s) reste seul maître de son flag. Les deux peuvent être vrais en même temps : le vacuum continue, l’invulnérabilité non.

SFX : `Audio.sfx("powerup", 0.04)` (`powerup` est déjà un alias de `levelup`). VFX : `spawn_vfx("energy", …)` cyan.

## 3. Hitconfirm sabre

Dans `Player._update_slash`, quand le contact est un **ennemi** (le décor garde seulement le VFX `slash`) :

- hitstop : `Engine.time_scale = 0.05` pendant **40 ms d’horloge murale** (`Time.get_ticks_msec`). Le delta de jeu est lui-même ralenti ; un timer en `delta` durerait ~0,8 s réelles. Restauré par `_tick_hitstop` en tête de `_physics_process`, et aussi si le joueur meurt, si l’arbre se met en pause, ou si le nœud sort de l’arbre.
- shake : `Events.screen_shake.emit(1.6)` via `_emit_hit_shake`. Le signal du projet est scalaire (tous les appels existants sont `emit(float)`) : pas de vecteur axial ajouté, pour ne pas casser `Events.gd`. 1,6 est léger (faisceau Overdrive = 0,5, dégâts subis = 6).
- un seul shake par frame physique. Le crépitement du faisceau (`_process_beam`, ancien `emit(0.5)`) passe par le même garde-fou. Le sabre est évalué avant le faisceau dans `_physics_process` : si les deux tombent la même frame, seul le shake du sabre part.
- SFX : `Audio.sfx("w_sabre", 0.04)` soit ±4 %. Le throttle de `w_sabre` est 0,13 s, le cooldown de lame 0,24 s.

`_update_slash` ne fait toujours pas de dégâts (le commentaire d’origine tient : les dégâts de contact restent ceux de l’ennemi).

## 4. Murs soft 3:00 et 8:00

Horloge : `GameState.run_time` (la même que les boss, les élites scriptées et les phases). Fenêtres **[180, 200)** et **[480, 500)** secondes.

`pressure_floor` du cahier des charges est la variable `floor_pop`. Le ×1,6 est appliqué **après** la ligne de grâce existante :

```gdscript
floor_pop = clampi(mini(floor_pop, 2 + int(3.0 * grace)), 2, 24)
floor_pop = _apply_soft_wall_pressure(floor_pop)
```

`_soft_wall_key` renvoie -1 tant que `run_time < 18` **ou** `EnemySpawner._t < 18`. Une fenêtre déplacée sur l’ouverture ne peut pas ignorer la grâce. Le plafond 24 n’est pas levé.

Conséquence chiffrée, sans réécrire la grâce : une fois `grace == 1` (`_t >= 18`), `mini(floor_pop, 5)` laisse le plancher à **5**. Le mur le passe à `ceil(5 * 1.6) = 8` pendant 20 s. La formule `5 + int(_t / 22)` est déjà écrasée par ce `mini` dans le snapshot ; ce pack ne la « corrige » pas. Si elle est un jour remplacée par un plancher qui grandit vraiment, le ×1,6 suivra le `floor_pop` déjà calculé.

Une escouade : `_pulse_soft_wall_squad` appelle `_spawn_squad(true, "tenaille")` **une fois par fenêtre** (nouvel argument optionnel `formation`, les appels existants `_spawn_squad()` et `_spawn_squad(true)` restent valides). `force` contourne le plafond d’escouades, pas `ENEMY_CAP`. Tant que le spawn échoue (cap), la fenêtre réessaie ; dès qu’il réussit, elle se tait. `"tenaille"` est déjà une formation de `PROFILES` (désert, ether, quantum, ozone, steampunk, colosseum) et de `Squad`. L’annonce existante `FORMATION : …` couvre le bandeau.

À 3:00 le jeu a déjà l’élite scriptée (`ELITE_SCHEDULE` t = 180) et la phase « MENACE D'ELITE ». À 8:00, `TIER_EVENTS` pose déjà un mini-boss (t = 480). Le mur s’ajoute à ces beats, il ne les remplace pas.

## Drop rare — hook exact

Le butin de mort est dans `Enemy._die`, pas dans le spawner. Chaîne :

1. **Marque élite**
   - `EnemySpawner._maybe_elite` : pose déjà `grade = "elite"` et `drops_bonus`. Ajout : `set_meta("phase1_elite", true)`.
   - `EnemySpawner._spawn_elite` : `set_meta("phase1_elite", true)` seulement. `drops_bonus` n’est pas forcé (pas de soin/scrap garanti en plus sur l’élite scriptée).
2. **Tirage** — fin du bloc `if game != null` de `Enemy._die`, après le plan de forge : `GameState.roll_phase1_drop(self)`.
3. **Spawn** — `GameState._spawn_phase1_pickup`, dans cet ordre :
   1. `game.spawn_phase1_pickup(pos, kind)` si la méthode existe ;
   2. sinon `game.spawn_pickup(pos, kind, 1)` si elle existe ;
   3. sinon `Pickup.new()`, parenté au nœud `game`, `pickup.game` et `player` renseignés. Au ramassage, `reclaim_pickup` reprend le nœud si `game` l’expose, sinon `queue_free`.

| Situation | Bombe | Aimant |
| --- | ---: | ---: |
| `run_time < 18` | 0 | 0 |
| piétaille | 0,7 % | 1,6 % |
| élite (`grade == "elite"` ou meta `phase1_elite`) | 8 % | 12 % |
| boss `rank >= 3` | 0 | 10 % |
| tueur = arme `"bombe"` | 0 | 0 |

Les constantes sont en tête de `GameState.gd` (`PHASE1_BOMB_P_*`, `PHASE1_MAGNET_P_*`).

### Brancher le pool (recommandé)

Le fallback marche sans toucher `Game.gd`. Pour rester dans le même pool que `spawn_xp` / `spawn_bonus` et le bon calque, ajouter sur `Game` la méthode que le spawner cherche en premier. Dupliquer le corps de `spawn_xp` (emprunt du pool, `pickup.game = self`) et passer le kind tel quel — ne pas appeler `spawn_xp`, qui force `"xp"` :

```gdscript
func spawn_phase1_pickup(pos: Vector2, kind: String) -> void:
	var p: Pickup = _prendre_dans_le_pool()  # le même appel que spawn_xp
	p.game = self
	p.setup(pos, kind, 1, player)
```

Dès qu’elle existe, `GameState._spawn_phase1_pickup` n’instancie plus à la main.

Test sans attendre le tirage, depuis le débogueur ou une ligne temporaire :

```gdscript
GameState.debug_drop_phase1("bombe", global_position + Vector2(90, 0), game, self)
GameState.debug_drop_phase1("aimant", global_position + Vector2(-90, 0), game, self)
```

(`self` = le joueur, `game` = le nœud Game déjà tenu par `Player.game`.)

## Checklist en run

1. **Bombe** — `debug_drop_phase1("bombe", …)`, marcher dessus. Flash clair, secousse forte, son `explosion`. Un ennemi plein passe vers ~65 % de ses PV max (moins si un bouclier ou une garde encaisse). Un boss s’arrête ~1,2 s (le stun existant coupe mouvement et tirs, flash cyan de `apply_stun`) et ne perd qu’une fraction de barre. Le joueur n’est pas blessé par sa bombe. Pas de seconde bombe spawnée par les morts de la première.
2. **Aimant** — drop `aimant`. Les gemmes loin du joueur partent vers lui pendant ~2,5 s, puis seules celles dans `magnet_range` (165) continuent d’être aspirées à neuf. Encaisser un coup pendant l’aimant : les dégâts passent (pas d’iframe).
3. **Overdrive intact** — jauge pleine, Espace (ou le bouton HUD). Invulnérable, vitesse ×2, vacuum global, faisceau. À la fin : `overdrive_active` repasse à false, cooldown ~16 s, l’aimant ne rallume pas l’invulnérabilité. Enchaîner aimant puis Overdrive : les deux vacuums se superposent, un seul donne l’invulnérabilité.
4. **Sabre** — coller un ennemi. Le VFX `slash` part, le temps « accroche » une fraction de seconde, la caméra tremble légèrement **une** fois, le son `w_sabre` n’est pas toujours à la même hauteur. Coller un décor : VFX seulement, pas de hitstop. En Overdrive, une frame où le faisceau crépite en même temps que le sabre ne double pas la secousse.
5. **Murs** — pour ne pas attendre 8 minutes, remplacer temporairement dans `EnemySpawner.gd` :

   ```gdscript
   const SOFT_WALLS: Array[Vector2] = [Vector2(20.0, 40.0), Vector2(50.0, 70.0)]
   ```

   La première fenêtre commence après la grâce (18 s). Entre 20 et 40 s : le rattrapage de population vise 8 ennemis au lieu de 5, et **un** bandeau `FORMATION :` tenaille. Avant 18 s : pas de tenaille forcée, plancher toujours adouci par la grâce (2 → 5). Remettre `[180, 200)` et `[480, 500)` après le test. En run réelle, 3:00 et 8:00 empilent ce mur sur l’élite scriptée (3:00) et le mini-boss de hiérarchie (8:00).
6. **Régression pool** — ramasser une gemme XP, un scrap, un soin : le son et le `reclaim_pickup` sont ceux d’avant. Relancer une partie : `GameState.reset()` coupe `magnet_vacuum` (pas d’aspiration fantôme au run suivant).
