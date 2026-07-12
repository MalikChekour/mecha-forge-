# Plan d'action mecha-forge — synthèse des 6 repos de référence

## A) Ce qu'on a déjà (confirmé en avance)
Les 6 clones confirment qu'on est **au-dessus du panier** sur le cœur gameplay : draft 3 cartes, auto-aim, pooling projectiles/pickups, WeaponSystem paramétré 4 armes, boss **timés à barre de vie**, 8 biomes à modificateurs, méta-progression 5 talents + save JSON inspectable, Overdrive. Aucun repo n'a d'évolutions, de synergies, ni d'arbre profond — nos manques sont donc des manques **du genre**, pas des retards. Les seuls domaines où plusieurs repos nous battent réellement : **le SON** (murparreira, sh-cho) et la **plomberie stats/options** (murparreira).

## B) À REPRENDRE — priorisé par IMPACT

| # | Quoi | POURQUOI (feel/rétention) | COMMENT dans notre archi | Effort | Repo source |
|---|------|---------------------------|--------------------------|--------|-------------|
| 1 | **ÉVOLUTIONS d'armes** (arme MAX + passif requis → arme évoluée) | Le pic de dopamine signature du genre ; objectif de build qui structure toute la run. On ne l'a pas du tout. | Dans le draft/pool : quand `WeaponSystem` marque une arme `is_max` ET que le passif requis est présent, `pool.remove(base)` + `pool.add(evolution)` (offre une carte "ÉVOLUTION" dorée). Table `EVO_RULES = {autocannon+passif_cadence: "vulcan", ...}`. Le passif MAX ne doit PAS être retiré silencieusement mais **déclencher** l'éligibilité. | **M** | sh-cho (chaînage `update_upgrade_pool`), murparreira (`max_quantity`→pool à détourner) |
| 2 | **SON/MUSIQUE/SFX** — le trou #1 | Zéro son = démo, pas jeu. Impact feel/rétention massif pour effort modéré. | Autoload `MusicDirector` qui swap par état (menu/run/boss/overdrive) avec crossfade ; bus `Master>Music/SFX` (`default_bus_layout.tres`) ; composant SFX qui pioche dans un `Array[AudioStream]` anti-répétition, **branché sur nos signaux existants** (impact par arme, muzzle, level-up, pickup, hit-stop, mort boss). Assets CC0 Kenney. | **M** | murparreira (stack complète), sh-cho (autoload music + bouton son) |
| 3 | **Passifs comme cartes draftables séparées** | Prérequis technique des évolutions (#1) ET double la profondeur de build sans nouvel art. | Ajouter des `WeaponUpgradeCard`/`PassiveCard` (dégâts, cadence, nb projectiles, armor, lifesteal) dans le draft de 3, distinctes des armes, avec table de valeurs par niveau ("Lv X → X+1"). | **S/M** | matthias (`UpgradeableValues`, passifs = abilités draftables), murparreira |
| 4 | **Banish / Reroll de cartes** | Agentivité sur le build, standard moderne du genre (VS, Brotato). Pur UI + logique de pool. | Boutons sur l'écran de draft : `reroll()` retire une main et repioche dans la `WeightedTable` ; `banish(card)` la sort du pool pour la run. Budget de charges gagnable via méta-talent. | **S** | Aucun repo ne l'a — reprendre notre draft + `WeightedTable`, brique maison |
| 5 | **Crit-strike sur les armes** | Variance de dégâts = texture de feel + support de build (passif crit). Trivial. | Ajouter `crit_chance`/`crit_mult` aux params `WeaponSystem` ; roll à l'impact, VFX + damage-text distinct (jaune/gros). | **S** | Gatreh (crit dans `WEAPON_STATS`) |
| 6 | **Spawn director data-driven (keyframes)** | Remplace nos seuils codés en dur ; courbe de difficulté lisse qui se marie aux modificateurs de biome ; base de la variété d'ennemis. | Resource `SpawnTable` (`Curve`/tableaux : `spawnRate`, `spawnChance` pondéré par ennemi, `hpMultiplier` interpolés dans le temps), lue par notre spawn director. | **M** | matthias (`MonsterSpawnTable`), murparreira (paliers temporels) |
| 7 | **HurtBox à modes** (cooldown / hit-once / disable) | Fiabilise le **railgun perçant** (hit-once par cible) et remplace le tick-damage ad hoc lava/beam Overdrive par 1 composant propre. | 1 script `Area2D` + enum `match` (0=cooldown 0.5s, 1=once, 2=disable-hitbox). Migrer les collisions armes/hazards dessus. | **S** | schak04 (HurtBox mode `match`) |
| 8 | **Stats persistées + Achievements** | Fondation directe des achievements (qu'on n'a pas) = rétention long terme. | Dict `stats` dans `SaveManager` JSON (kills, dégâts totaux, wins/losses, plays/perso, temps survécu). Achievements = règles lues sur ce dict. | **S** | murparreira (save stats complètes) |
| 9 | **Options + sliders volume par bus** | Attendu sur mobile ; vient gratuitement avec l'audio (#2). | Écran options : sliders Master/Music/SFX → `AudioServer.set_bus_volume_db`. | **S** | murparreira, sh-cho |
| 10 | **Motifs de spawn géométriques + DSL de vagues** | Mise en scène (anneaux/colonnes/vagues scriptées) que nos archétypes n'exploitent pas ; lisibilité du scripting boss/biome. | Lib de motifs (arcs de cercle, lignes par bord, FILL) + helpers `AtTime/BetweenTime/AfterTime` au-dessus du spawn director. Raycast anti-mur (rayon ~375px) pour biomes à hazards. | **S/M** | Gatreh (DSL + motifs), sh-cho/murparreira (raycast) |
| 11 | **Pooling ennemis + damage-text** | On pool déjà projectiles/pickups ; l'étendre aux ennemis/nombres réduit les hitches GC sur mobile en fin de run. | Étendre notre pool aux scènes ennemis et aux labels de dégâts flottants. | **S** | matthias, murparreira |
| 12 | **Sauvegarde/reprise de run en cours** | Confort mobile (app tuée en fond) ; aucun repo ne l'a mais fort pour la plateforme. | Sérialiser l'état de run (temps, XP/niveau, armes+niveaux, position, seed) dans un slot JSON à part ; reprendre au relancement. | **M/L** | Brique maison (extension `SaveManager`) |
| 13 | **Localisation CSV** | Portée mobile / stores multi-langues (on est déjà bilingue FR/EN sur d'autres projets). | `Translation`/CSV Godot, clés sur les textes UI/cartes. | **S** | matthias (EN/中文) |

## C) À IGNORER (on fait mieux, ou hors-scope)
- **Save binaire** `store_var` (sh-cho, Gatreh, murparreira) → notre JSON inspectable est supérieur.
- **Boss = ennemi générique boosté** (murparreira) → nos boss timés à barre + écran victoire sont au-dessus.
- **Spawner mono-paramètre / intervalle fixe sans scaling** (sh-cho, quillraven) → inférieur à notre spawn timé + boss.
- **Draft de 2 cartes** (sh-cho, murparreira) → on est déjà à 3.
- **Pas de pooling / tout en `new`** (quillraven) → déjà pooled.
- **Composants hitbox/health/velocity façon GDQuest** (murparreira, matthias) au-delà du HurtBox #7 → refonte inutile, notre WeaponSystem paramétré suffit.
- **quillraven en entier** et **schak04 (hors HurtBox)** : valeur quasi nulle, références pédagogiques.
- **Code SFX LibGDX** (quillraven) : concept oui, code non transférable.

## D) 3 repos à cloner/ouvrir en priorité
1. **murparreira** (`vampire-survivors-clone-godot-4`) — **la référence audio complète en Godot 4** (bus layout, 3 music players contextuels, SFX anti-répétition) + save stats + raycast anti-mur. Débloque #2, #8, #9, #10 d'un coup. Notre priorité de lecture.
2. **matthias** (`VampireSurvivorsClone`) — le plus riche côté data-driven : **spawn director keyframes** (#6), **passifs draftables** (#3, prérequis des évolutions), pooling ennemis + damage-text, localisation. Modèle d'architecture data.
3. **sh-cho** (`godot-survivor-tutorial`) — le plus proche de notre stack (Godot 4 GDScript pur, jouable) ; **chaînage de pool d'upgrades** = squelette direct des ÉVOLUTIONS (#1), + autoload audio simple. Bon point de départ lisible pour prototyper l'évolution.

## E) Prochain sprint recommandé (meilleur ratio impact/effort)
1. **SON/SFX (#2 + #9)** — M — impact feel maximal, branché sur nos signaux existants, débloque les options. **Faire en premier.**
2. **Passifs draftables (#3)** — S/M — double la profondeur de build ET pose le prérequis technique de l'évolution.
3. **ÉVOLUTIONS d'armes (#1)** — M — dès que #3 est là ; le pic de dopamine signature, plus grosse valeur rétention.
4. **Banish/Reroll (#4) + Crit (#5)** — S+S — deux quick-wins d'agentivité et de feel pour finir le sprint.

*Fondations à enchaîner au sprint suivant : spawn director keyframes (#6) + stats/achievements (#8) + HurtBox à modes (#7).*