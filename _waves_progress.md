# Vagues par tranche de temps + montee de difficulte (v12.20) - progression
Tag de retour : pre_waves_20261105 (HEAD a4211d4, v12.19)
Ne pas toucher : stash "nov2 non-antikite". Pas de Meshy. Pas de refonte Armored Warrior.

## Etapes
- [x] 1. Tag pre_waves_20261105 + ce fichier
- [x] 2. Recherche (Vampire Survivors, Survivor.io, Brotato, Halls of Torment, HoloCure) -> voir section Recherche
- [x] 3. Audit EnemySpawner (voir section Audit)
- [x] 4. Implementation WaveSchedule.gd (table Ch1 a la main, Ch2-18 generes) + rampe + surge pre-boss + accalmie
- [x] 5. Banc wv1 (Ch1, 960 s, x6) : voir section Banc
- [~] 6. Commit, v12.20, push itch (html5 + android), captures /workspace/qa_waves/

## Recherche (principes)
1. Table minute par minute (VS Mad Forest) : roster par minute, minimum d'ennemis vivants, intervalle. https://vampire.survivors.wiki/w/Mad_Forest https://teemo.dev/game-design/vampire-survivors/systems/spawn-director/
2. Timeline fixe Survivor.io Ch1 (tireurs 1:00, chiens 1:30, horde 2:00, elite 3:00, boss 5/10/15, blindes apres boss). https://www.levelwinner.com/survivor-io-guide-tips-tricks-strategies-to-slay-hordes-of-zombies-and-save-the-city/
3. Fenetres de vie par type (HoloCure Stage 1). https://holocure.wiki.gg/wiki/Stage_1_-_Grassy_Plains
4. Pics de pression (hordes/murs/anneaux) juste avant elites et boss.
5. Rampe lineaire PV/degats, vitesse fixe (Brotato). https://teemo.dev/game-design/brotato/systems/enemy-scaling-danger-and-endless/
6. Elites plus tot avec la difficulte, elite precoce affaiblie (Brotato). https://brotato.wiki.spellsandguns.com/Danger_Levels
7. Elite juste avant chaque boss, rang = +PV surtout (Halls of Torment). https://hot.fandom.com/wiki/Haunted_Caverns https://hot.fandom.com/wiki/Torment
8. PV des boss selon la minute d'apparition (HoloCure). https://holocure.wiki.gg/wiki/Enemy

## Audit (EnemySpawner.gd v12.19)
- Roster par biome (BIOME_POOL) : base mechNN (role selon PROFILES : tir/charge/mine...), _swarm (rapide, ruee), _shield (blinde), _sniper, _elite ; PHASE2_DEFS : _kami, _summoner (desactives dans PHASE2_EXTRA).
- Deblocage actuel par 'unlock' : base 0 s, shield/elite 35 s, swarm 0 s, sniper 50 s -> tout est la avant 1 min (probleme vise).
- Elite scriptee a 25 s, escouades (elite+essaim+bouclier+sniper) des 40 s, hordes toutes les 50 s des 38 s, Mark 2 des 1:30, intermediaires des 2:00.
- TIER_EVENTS : mini 3:00/8:00/12:00, boss1 5:00, boss2 10:00, boss final 15:00. PV : +12 %/min (1+0,002 t), degats +4,8 %/min, vitesse +1 %/min.

## Implementation (etape 4)
- game/systems/WaveSchedule.gd : table CH1 (11 tranches), hordes chronometrees, elites 3:00 + 15 s avant chaque boss, rampe PV +8 %/min, degats +4 %/min,
  montee pre-boss 90 s (+25 % PV, +40 % densite, bandeau SIGNAL HOSTILE DETECTE), accalmie 25 s (densite x0,3) apres mini-boss, PV boss +3 %/min d'apparition.
  build(tier) genere Ch2-18 (introductions resserrees jusqu'a x0,7, densite +1,2 %/chapitre, Mark 2 +1,5 %/chapitre, 2 types des le depart au Ch4+).
- EnemySpawner.gd : _wv_* (pick, substitution d'escouade, tick), nouveau type mechNN_melee (base riggee en melee), kami/invocateur reactives via la table.
  -- --no-waves = temoin v12.19. Zone PUBG / grande carte / anti-fuite / multiplicateurs de difficulte inchanges.
- _bal_ch1.gd : ligne CH1 VAGUES (ordre d'introduction).

## Banc wv1 (etape 5)
Ordre d'introduction (8/8 runs identique) : melee@0 > swarm@90-92 > elite@180 > tir@180 > shield@241-247 > kami@361-365 > sniper@450-451 > summoner@541-559
- Facile : 4/4 vivants a 960 s (pv_min 53-83 %). Boss 5:00 tue en 21-103 s, boss 10:00 en 10-91 s.
- Normal : 1 vivant a 960 s (s1, pv_min 33 %) ; morts a 526 s (s3, tireur), 668 s (s4), 896 s (s2, sniper, juste avant le boss final). Aucune mort avant 8:00
  (v12.19 Normal : 273 / 301 / >740 / 340 s). Pas de reglage supplementaire : « difficile mais gagnable ».
- Captures : qa_waves/1_debut_fantassins_seuls.png (0:28, 6 fantassins seuls), 2_signal_hostile_pre_boss.png (3:31, bandeau), 2b_montee_pre_boss.png, 3_fin_melange_blinde.png (11:54, 9 types).
- Correctif apres captures : le bandeau show_horde_warning n'apparait pas a l'ecran -> le signal passe aussi par show_banner (visible).
