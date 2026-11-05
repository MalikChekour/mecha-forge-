# Vagues par tranche de temps + montee de difficulte (v12.20) - progression
Tag de retour : pre_waves_20261105 (HEAD a4211d4, v12.19)
Ne pas toucher : stash "nov2 non-antikite". Pas de Meshy. Pas de refonte Armored Warrior.

## Etapes
- [x] 1. Tag pre_waves_20261105 + ce fichier
- [x] 2. Recherche (Vampire Survivors, Survivor.io, Brotato, Halls of Torment, HoloCure) -> voir section Recherche
- [x] 3. Audit EnemySpawner (voir section Audit)
- [ ] 4. Implementation WaveSchedule.gd (table Ch1 a la main, Ch2-18 generes) + rampe + surge pre-boss + accalmie
- [ ] 5. Banc Ch1 Facile + Normal, ordre d'introduction dans les logs, reglage
- [ ] 6. Commit, v12.20, push itch (html5 + android), captures /workspace/qa_waves/

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
