# PLAN D'OPTIMISATION — mecha-forge vs Survivor.io

> Audit croisé **ancré dans le code réel** (9 agents ont lu chaque système + le playbook, + 1 lead a synthétisé). Produit le 2026-07-12.
> Compagnon de `SURVIVOR_IO_PLAYBOOK.md` (le modèle) — ici, **quoi faire chez nous, dans quel ordre**.

---

## Diagnostic en une phrase

mecha-forge est un survivor-like **techniquement solide sur le RUN** (draft, évolutions, Overdrive, boss timés, garage/talents, aura/drones, VFX) mais il lui manque **les deux moteurs qui font vivre Survivor.io** :
1. **Une économie d'équipement infinie** (fusion 3-pour-1 + gacha + monnaie premium) — aujourd'hui le puits de dépense est **FINI** (~3865 ferraille pour tout avoir, puis monnaie morte = *problème Vampire Survivors*).
2. **Un modèle de dégâts en BUCKETS** qui donne du sens à cet équipement.

Et **3 bugs/manques tuent déjà le feel** : l'**Overdrive** (le moment WOW central) est **injouable au doigt** (touche ESPACE seulement), l'**évolution de l'autocanon est impossible** (mech de départ → jamais de Vulcan), et le jeu **ne peut techniquement encaisser aucun paiement** (`gradle_build=false`).

---

## ⚠️ La dépendance qui commande tout l'ordre

> **NE JAMAIS** construire l'économie d'équipement / gacha / debuffs **AVANT** d'avoir posé le **StatBlock à buckets** ET converti l'armure joueur → PV.

Aujourd'hui tout se replie dans un seul scalaire `player.damage` (et les cartes +25 % s'empilent en `1.25ⁿ` = multiplicatif au lieu d'additif). Sans agrégateur central **additif-intra-catégorie / multiplicatif-inter-catégorie**, chaque futur objet d'équipement ne fera que gonfler ce scalaire → explosion linéaire illisible + refactor douloureux. **Le StatBlock est la fondation ; tout s'y accroche.**

---

## PHASE 0 — QUICK WINS (quelques jours, zéro dépendance)

À faire **en premier** : débloque le 1er WOW mobile, corrige des bugs qui cassent le feel, et prépare le terrain.

| # | Action | Fichiers |
|---|---|---|
| 0.1 | **🔴 Déclencheur TACTILE de l'Overdrive** : bouton HUD qui pulse quand la jauge est pleine + double-tap zone droite → `_transform_on()` (déjà écrit). Remplacer le libellé « OVERDRIVE — ESPACE » par une icône. | `ui/HUD.gd:67-73`, `Player.gd:189-194` |
| 0.2 | **Clés save forward-compatibles** : ajouter `parts:[]`, `equipped:{}`, `crystals:0`, `cores:0`, `last_played`, `first_run` au dict par défaut. `load_data` merge par-clé → zéro casse des vieux saves, tous les chantiers suivants deviennent branchables. | `SaveManager.gd:7-16` |
| 0.3 | **Bug : scaling PV des boss** — `_spawn_boss` n'applique que `d.hp`, il ignore `(1+run_time·0.0011)·(1+difficulty_bonus)` que reçoit tout le trash → le 2e midboss = même PV que le 1er, l'endboss sous-tuné s'effondre en secondes. Appliquer le même facteur que `_scale_enemy`. | `EnemySpawner.gd:84-99` |
| 0.4 | **Bug : drafts volés sur multi-level-up** — gagner 2 niveaux d'un coup jette des cartes (garde booléen `_draft_open`). Mettre le draft **en FILE** (compter les level-ups en attente, 1 draft par niveau). | `Game.gd:696-704,753-757`, `GameState.gd:104-108` |
| 0.5 | **Bug : double-comptage meta des drones** — dégât drone = `damage·0.5·(1+meta_dmg)` alors que `player.damage` inclut **déjà** `(1+meta_dmg)` → meta au carré. + **universaliser le crit** (faire crit-er splash/beam/aura par le même roll que `Projectile._on_hit`). | `Player.gd:296-363`, `Projectile.gd:145-153` |
| 0.6 | **Bug : revive « pub » mensonger** — le bouton REVIVRE (pub) ne joue **aucune pub**, il appelle `revive_player()` direct. Le relabéliser en attendant `Ads.gd` (0.1 de la Vague 1), ou brancher un stub. | `MetaScreen.gd:61-72` |
| 0.7 | Micro-fixes gratuits : `_phase_timer=0.5` dans `Enemy.setup()` (sinon le **1er dash du dasher n'a aucun télégraphe**) ; **3 tiers de couleur** pour les gemmes XP (vert/bleu/doré) ; afficher le **niveau d'arme** sur les cartes de draft ; unifier le cap ennemis (`170` codé en dur vs `ENEMY_CAP=190`) ; supprimer le champ mort `equipped_chassis`. | `Enemy.gd`, `Pickup.gd`, `HUD.gd`, `EnemySpawner.gd:18,132`, `SaveManager.gd:11` |

---

## VAGUE 1 — P0 : le socle qui MONÉTISE et RETIENT (~2-4 semaines)

### 1A. Fondation dégâts (à faire AVANT tout gear)
- **StatBlock à buckets** (nouvel autoload) = source de vérité UNIQUE des dégâts.
  `atk_total = (base + flat_gear)·K(atk%)` puis `× critAvg × K(skill_dmg) × K(vuln) × K(boss) × Π K(state·uptime)`, avec `K(x)=1+x/100`. Lu par `Projectile._on_hit`, `_do_splash`, le beam, l'aura ET les drones. Migrer les cartes « +25 % Dégâts » de `×1.25` empilé → `+25` additif dans le bucket `skill_dmg`.
  *(fichiers : nouveau `autoload/StatBlock.gd` ; `Player.gd:63-69,325-329` ; `WeaponSystem.gd:295-309` ; `Projectile.gd:130-153` ; `Game.gd:769-778` ; `GameState.gd:85-98`)*
- **Survie = PV seuls** : retirer `armor` côté joueur (SIO n'a ni armure ni esquive), convertir la carte « +8 % Armure » en « +PV max » (bucket HP%). *(`Player.gd:15,478` ; `Game.gd:67,777` ; `GameState.gd:57-63`)*

### 1B. Économie d'équipement permanent (le puits de dépense #1)
- **`Parts.gd`** (schéma data, calque de `GameState.META`) : `def_id → {name, slot, generation, base_stats, grade_skills}` pour **6 slots thématisés sur les hardpoints VISIBLES du rig en calques** — *le différenciateur unique du projet* : **ARME** (core d'arme), **BLINDAGE** (HP), **RÉACTEUR** (dmg%/énergie), **SERVOS** (vitesse/haste), **OPTIQUE** (crit), **CHASSIS-MOD** (mixte). Instances persistées `SaveManager.data['parts']=[{uid,def_id,rarity,plus,enchant,locked}]` + `['equipped']={slot→uid}`. ~8 crans de rareté colorés.
- **Fusion 3-pour-1 par copies identiques + salvage** : `fuse(uids[3])` (même `def_id` + même `(rarity,plus)` → 1 cran au-dessus), `salvage(uid)` → crédite des `cores`. Courbe géométrique douce (3) puis explosive au sommet. **Jamais de montée par XP** (c'est ça qui crée la dépendance au gacha).
- **Agrégateur `Stats.gd`** : somme les rolls des 6 pièces + talents + mech dans les buckets, compose multiplicativement. Remplace la chaîne en dur de `Player._ready`.

### 1C. Plomberie de monétisation (bloqueur RACINE, parallélisable)
- **`gradle_build=true`** sur le preset Android + plugin **AdMob** (pub récompensée) + **Google Play Billing** (IAP). *Sans ça, aucune ligne de monétisation ne peut fonctionner.* *(`export_presets.cfg:70,107`)*
- **Hard currency « Noyaux/Cristaux »** distincte de la ferraille + **`Ads.gd`** (`show_rewarded(cb)` : stub instantané desktop/web, réel AdMob Android → garde le smoke-test headless vert) + **gacha à pity court (10)** (`Gacha.roll` garantit un cran haut tous les 10, ×10 ancré « achat malin »).
- **Réparer le revive** sur `Ads.show_rewarded` + ajouter **« DOUBLER LA FERRAILLE (pub) »** sur l'écran résultat (~35 % du revenu SIO vient de la pub récompensée, c'est l'outil le plus éthique).

### 1D. Rétention gratuite
- **Daily reward + login streak** : `last_claim`/`streak` dans SaveManager, écran de récupération au démarrage, récompense escaladante (ferraille + Noyaux + pull gratuit). *Le robinet de rétention le moins cher (soutient D1/D7).*

**Fin de Vague 1 = le jeu MONÉTISE (pub+IAP techniquement possibles), RETIENT (daily + gear infini), et le 1er WOW est jouable au doigt.**

---

## VAGUE 2 — P1 : profondeur de combat + méta lisible (~4-8 semaines, 2 pistes //)

### Piste A — COMBAT (dépend surtout du StatBlock)
- **Axe crit damage** + crit rate jusqu'à 100 % (plancher ×2) : carte/talent `crit_mult` (+0.25), `critAvg = clamp(rate,0,1)·max(mult,2)+(1−clamp)` pour l'affichage. *Levier de build #1 de SIO, aujourd'hui absent (`crit_mult` figé à 2.0).*
- **Garantir la 1re ÉVOLUTION en milieu de 1re run (WOW #2)** : donner un chemin de montée à l'autocanon (carte `w_autocannon` ou auto-level de l'arme de départ) + accélérer le niv.5. *Corrige le bug `is_max('autocannon')` jamais vrai → Vulcan inatteignable pour AEGIS/NEMESIS.*
- **Catalyseurs d'évolution UNIQUES + lisibilité** : rendre les 4 passifs-catalyseurs dédiés (cartes nommées, découplées de dmg/crit/haste/magnet), afficher le catalyseur requis + niveau/étoile de l'arme sur les cartes, + mini-HUD des armes/niveaux possédés. *Aujourd'hui les évos sont quasi gratuites → la mécanique-signature perd son enjeu.*
- **Fusion d'armes = 2e famille d'évolution** : `FUSION_RULES {armeA+armeB→fusion}`, 2 armes fusionnent et **libèrent un slot** (arbitrage cornélien).
- **Escalade visuelle** : nombre de projectiles qui scale avec le niveau (+1 par étoile) au lieu d'un MULTISHOT constant → le « l'écran se remplit » (dopamine + clipabilité TikTok).
- **Boss avec vrais patterns télégraphiés** : factoriser `_spawn_lava_hazard` en `telegraph_ring()`/`telegraph_line()` réutilisables ; behavior `boss` avec mini-FSM : midboss = charge-dash télégraphiée (réutilise la FSM dasher), endboss = walk + salve radiale (`spawn_enemy_bolt`) + summon d'adds. **Coût art NUL** (mêmes sheets).
- **Spawn Director piloté par DONNÉES** : `MAP_DEFS` + par map une `timeline:[{t_start,t_end,type:swap_base|horde|elite|boss,enemy_id,rate|count}]` ; système de **FORMAT** (Open 15min/3boss, Enclosed 8min/5boss, Linear budget ×2-4) qui dérive `BOSS_SCHEDULE`. *Insight de réplication #1 du playbook.*
- **Couche Élite → Inspire** + **flaques de mort** (trash hook qui punit le facetank) + **variété ranged** (champ `shot: single|burst3|spread|homing|split`).

### Piste B — MÉTA / UX (dépend de Parts/fusion de la Vague 1)
- **MetaScreen en ONGLETS** (TALENTS / ÉQUIPEMENT / FORGE / GACHA / GARAGE) : grille des 6 slots + inventaire filtrable (équiper/fusionner/salvage/verrouiller). *L'UI actuelle ne sait afficher que talents+garage.*
- **Grade skills** par cran de rareté (une **compétence**, pas un +stat plat → « moments wow » de fusion) + **Banc de Forge** (enchant 1-5★ alimenté par cores, double le plafond whale) + champ **`generation`** (Mk.I→II→III, power-creep LiveOps le moins cher).
- **Écran « Stats détaillées »** (ATK total, ATK%, Skill Dmg%, crit rate clampée, crit dmg, DPS estimé) → hook theorycraft.
- **Battle Pass saisonnier** (piste gratuite+premium, quêtes sur score/kills/run_time déjà trackés) + **Starter/Growth Pack** (IAP one-time, forte valeur, zéro hasard = le plus éthique) + **revive dual-path** (« REVIVRE (N Noyaux) » à côté de la pub).
- **FTUE sans friction + Hub persistant + Event 7 jours** : au 1er lancement, sauter la modale difficulté → direct dans Ch1 + 2-3 coach-marks (« GLISSE POUR TE DÉPLACER — tir auto »). Créer une **scène HUB** (le `Boot.gd` actuel est orphelin) où vivent JOUER/chapitres/modes/shop. **Server-Launch Challenge 7j** one-shot (fenêtre de conversion J1-J7).

---

## VAGUE 3 — P2 : le rail LiveOps infini (continu)

- **Moteur de STATUTS/debuffs « Damage to [state] » (buckets MULTIPLICATIFS)** : états `{weakened,chilled,poisoned,bleed,vulnerable}` avec durée/uptime sur Enemy ; buckets multiplicatifs entre eux ; les builds « inflige tout » explosent. *2e moteur d'endgame de SIO — DÉPEND du StatBlock, donc après.*
- **Élargir l'arsenal** → 6 armes de base à rôles distincts (cinétique/explosif/perçant/énergie/mêlée/orbital) + évos ; cap armes 4→6 ; 6 slots de passifs plafonnés niv.5 (cout d'opportunité).
- **Armes = équipement forgeable** (double nature : version permanente qui boost la version in-run) — pont run↔méta payante.
- **2e gacha PETS/TECH-PARTS** (multiplicateurs de build persistants).
- **Renforcer le DPS-check** : DEF ennemie OU paliers de « malédiction » par seuil de score (le coeff temps `0.0011/s` est quasi inerte) + scaler les PV boss par map.
- **Perf : grille spatiale uniforme** partagée (aim/beam/drones/séparation) + re-acquisition throttlée à la cadence de tir. **NE PAS monter le cap d'ennemis avant ça** (l'auto-aim O(n)/frame plafonne déjà à 190). Puis **MultiMeshInstance2D** pour la horde (1-2 draw calls au lieu de 400+ Sprite2D) + retirer les PointLight2D par projectile.
- **Plus d'archetypes de boss** (beam-sweeper/splitter/summoner/zone-hazard) → ~6-10 + endboss capstone.
- **`next_map` = vraie frontière de CHAPITRE** (recharge timeline/format + ré-arme l'horloge du director) + **énergie ÉTHIQUE différée** (cap généreux, uniquement contenu profond) + **gains offline / Patrol AFK**.
- **Mode DPS-check ranked (Ender's Echo-like)** : endboss invincible, score cumulé, saison 28j, tiers Novice/Elite/Ace (réutilise `best_scores`).

---

## Séquencement recommandé

- **PHASE 0** (quelques jours, 0 dépendance) : les quick wins ci-dessus + clés save forward-compatibles. Débloque le 1er WOW mobile, assainit le terrain.
- **PHASE 1** (2-4 sem) : **StatBlock → armure→PV** (fondation) ; **EN PARALLÈLE** la chaîne technique gradle+AdMob+Billing (indépendante). Puis Parts + fusion/salvage + hard currency/gacha/Ads + revive réparé + daily.
- **PHASE 2** (4-8 sem, 2 pistes //) : (A) combat (crit dmg, évo garantie, catalyseurs uniques, fusion d'armes, boss télégraphiés, spawn director) ; (B) méta/UX (onglets, grade skills, enchant, générations, Stats détaillées, Battle Pass, FTUE+hub+event 7j).
- **PHASE 3** (continu) : statuts multiplicatifs, arsenal élargi, armes forgeables, 2e gacha, DEF/malédiction, grille spatiale (débloque le cap horde), archetypes de boss, chapitres+énergie+offline.

---

## 🚧 Pièges à éviter (les 3 règles)

1. **ORDRE OBLIGATOIRE** : jamais d'économie/gacha/debuffs avant le **StatBlock à buckets** + conversion armure→PV. Sinon chaque pièce gonfle un scalaire = explosion linéaire + refactor douloureux.
2. **Monétisation ÉTHIQUE et PROGRESSIVE** (le patron vise un lancement solo éthique, cf. [[branding-internal-vs-public]]) : d'abord la rétention **gratuite** (daily, WOW Overdrive, pass à valeur claire, packs one-time) ; **ne différer l'énergie** qu'après avoir prouvé la rétention gratuite, avec cap généreux. Le save client-only JSON en clair est trivial à falsifier → OK pour un MVP hors-ligne, mais pas d'IAP/classement online « sérieux » sans backend de validation. Le bouton revive « pub » actuel est mensonger → à réparer/relabéliser en priorité.
3. **Ne pas empiler du contenu neuf sur des fondations cassées** : réparer d'abord les bugs qui tuent le feel (Overdrive injouable mobile, drafts volés, évo autocanon impossible, boss sous-tunés). Et **ne pas monter le cap d'ennemis** (le « screen fills up » clipable) avant la grille spatiale.

---

## Tableau récap par dimension

| Dimension | État mecha-forge | Écart principal vs SIO | Priorité |
|---|---|---|---|
| Core loop & game-feel | ✅ solide (draft, Overdrive, juice) | Overdrive injouable au doigt ; drafts volés | P0 (quick fix) |
| Armes/passifs/évos | 🟡 famille 1 seule, 4+4 armes | Pas de fusion d'armes ; catalyseurs génériques ; pas de scaling projectiles | P1 |
| Maths de dégâts | 🔴 scalaire unique | Pas de buckets ; pas de crit dmg ; armure divergente | **P0/P1 (fondation)** |
| Spawn director | 🟡 rampe procédurale | Pas de timeline scriptée ni de format de map | P1 |
| Ennemis & boss | 🔴 2 boss « rush » | Pas de télégraphes ni de patterns ; boss sous-tunés | P0 (fix) + P1/P2 |
| **Méta & économie** | 🔴 sink FINI (~3865) | **Pas d'équipement/fusion/gacha = le puits #1** | **P0** |
| Monétisation | 🔴 rien (gradle off) | Pas d'IAP/pub/currency/pass/daily | **P0** |
| FTUE & contenu/modes | 🔴 run unique, pas de hub | Pas de hub/chapitres/daily/event 7j | P0/P1 |
| Performance | 🟡 O(n)/frame, cap 190 | Pas de grille spatiale ni d'instancing | P2 |

---
*Audit : 10 agents (9 dimensions + synthèse), ~850k tokens, ancré dans le code réel. Voir `SURVIVOR_IO_PLAYBOOK.md` pour le modèle détaillé.*
