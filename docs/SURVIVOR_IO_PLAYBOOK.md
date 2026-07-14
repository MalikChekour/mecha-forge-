# SURVIVOR.IO — LA RECETTE DE SUCCÈS (playbook de réplication)

> Déconstruction exhaustive de **Survivor.io** (Habby) pour répliquer le succès dans **mecha-forge**.
> Source : recherche multi-agents (16 agents, ~520 recherches web : Fandom, Naavik, Gamesforum, Sensor Tower/AppMagic, sio-tools/danke007 datamine, Reddit, guides). Rédigé le 2026-07-12.
>
> ⚠️ **Règle d'or de lecture** : les chiffres marqués *(non vérifié)* / *(inféré)* / *(= Vampire Survivors, pas SIO)* ne sont PAS des constantes officielles de Survivor.io — utilise-les comme point de départ à re-calibrer, pas comme vérité.

---

## 0. TL;DR — la recette en une page

Survivor.io n'a **pas** réussi grâce à sa boucle de jeu (Vampire Survivors a inventé la boucle et monétise **10-20× moins** en restant non-prédateur). Il a réussi grâce à **l'imbrication de 3 machines** :

1. **Un core loop sans friction** (un pouce, tir auto, run ~15 min, draft de 3 à chaque niveau, évolution d'arme = pic de dopamine). → *mecha-forge a déjà ~80 % de ça.*
2. **Une méta-économie d'équipement quasi-infinie** (fusion 3-pour-1, raretés Normal→SS, gacha à pity, forge, pets, tech parts) qui est **LE vrai puits de dépense**. → *mecha-forge n'a quasiment RIEN de ça = le gros du travail.*
3. **Une machine d'acquisition TikTok** (~50 % du budget UA, créas natives + "fail ads", réinvestissement de ~80 % du revenu quotidien). → *hors périmètre code, mais dicte le game design (jeu "clipable").*

**Chiffres clés** : 75 M$ en 2 mois (37 M installs), 182 M$ en 2023, **>500 M$ IAP cumulés**, encore ~5-6 M$/mois 3 ans après. Rétention **modeste** (D1 44 % / D7 15 % / D30 4 %) mais **ARPU whale énorme** (Corée 15,50 $/install, Chine 9 $, US 4,90 $ ; Asie de l'Est = 75 % du revenu). Split **~65 % IAP / 35 % pub**.

**La leçon centrale** : *le jeu existe pour servir la monétisation*. On crée un **mur de difficulté** puis on **vend le soulagement**.

---

## 1. Architecture globale : DEUX économies strictement séparées

| | **Core Loop (en partie)** | **Metagame (hors partie)** |
|---|---|---|
| Objectif | Survivre 15 min à des vagues infinies | Monter les stats permanentes (ATK, PV) |
| Mécanique | Déplacement, collecte d'XP, draft d'améliorations | Gacha, **fusion d'équipement (merge)**, forge |
| Progression | Éphémère (reset chaque run) | Permanente (rareté Normal → SS) |
| Monétisation | Revive (pub/gemmes) | Battle Pass, packs, gemmes, abonnements |

> **À répliquer** : garde ces deux économies **hermétiques**. Le run donne le shot de dopamine gratuit ; l'équipement permanent donne la rétention long terme et le LTV. C'est ce cloisonnement qui rend la monétisation acceptable.

---

## 2. Core loop & game feel

**Boucle atomique en 3 temps répétés à l'infini : TUER → COLLECTER → AMÉLIORER.**

- **Contrôle un-pouce, tir 100 % auto.** Seul input = déplacement (joystick flottant, on glisse le doigt n'importe où). Le héros auto-tire sur l'ennemi le plus proche. Le skill du joueur = **positionnement + esquive + choix de build**, jamais l'exécution du tir. Promesse marketing : *"Clear the map with one-hand controls"*.
- **Astuce game-feel** : la **hitbox du perso est plus petite que le sprite** (esquive au millimètre). Les ennemis visent la **position actuelle** (pas de prédiction) → bouger est la défense de base.
- **Aspiration d'XP.** Ennemis tués → gemmes d'XP au sol, aspirées à proximité. Barre pleine = level-up = **pause + 3 compétences**. 3 tiers de gemmes : **vertes** (communs) < **bleues** (coriaces) < **dorées** (élites). L'**Aimant** ramassé attire tous les drops d'un coup.
- **Draft de niveau (variable reward, façon machine à sous)** : 3 skills aléatoires, **pas de skip**, **pas d'abandon** d'un skill déjà pris. Reprendre une arme la monte d'un niveau. **1er reroll gratuit** par chapitre, suivants payants (hook de monétisation soft).
- **Structure de run** : timer visible ~15 min (variante 8 min), **boss toutes les ~5 min** (5/10/15), élites/mini-boss (aura rouge) entre, qui lâchent un coffre (**1, 3 ou 5 objets** + or). Après chaque boss, la piétaille devient plus tanky = 3 marches de difficulté nettes.
- **Rythme pression/soulagement** : densité qui monte + **nouveaux types** d'ennemis introduits (rapides, distance, tanky, volants), ponctué de pics (boss) et de répits courts. La vraie variable de fin de run = **le DPS** (course entre ta courbe de puissance et celle de la difficulté).
- **Power fantasy TRÈS tôt** ("all-powerful experience very early") : maximise viralité/conversion early ; contrepartie = essoufflement en 1-2 semaines (D30 4 %).
- **Steamroll Mode** (débloqué après Ch.20) : quand on sur-stat un stage, run **compressée** (15 min→5 min, 8 min→2 min), build choisi/reroll au max dès le départ. Anti-grind de fin de vie.

**Fin de run à double issue** : *clear* (survivre + tuer boss final → récompenses) ou *mort* → **REVIVE** monétisé (pub OU gemmes) juste avant de perdre les récompenses = point de conversion à haute intention.

---

## 3. Armes, skills & ÉVOLUTIONS — le moteur d'engagement #1

**Le système le plus important à répliquer.** Tout est reset chaque run.

- **6 slots d'armes actives + 6 slots de passifs**, max simultané. Armes montent **1★→5★ puis EVO** (niv. 6). Passifs plafonnent à **niv. 5**.
- **Recette d'évolution standard** : **arme au 5★ + le passif-catalyseur dédié possédé** → en ouvrant un **coffre doré de boss**, l'arme se transforme en version évoluée (dégâts ×, mécaniques changées). **Chaque arme a UN passif-catalyseur unique** → tension de draft = sécuriser le bon passif avant le niv. 5. **Astuce** : laisser le coffre de boss au sol jusqu'à avoir arme 5★ + passif garantit l'évo.
- **3 familles d'évolution** (profondeur) :
  1. **Arme + passif** (classique).
  2. **Combination Skills** : deux armes actives fusionnent et **libèrent un slot** (choix cornélien d'en occuper 2 avant fusion). Ex. *Modular Mine + Molotov → Inferno Bomb*, *Drone-A + Drone-B → Destroyer*.
  3. **Armes premium S/SS** (issues de l'équipement, au-dessus des armes de base).

**Recettes canoniques (17 classiques)** — la STRUCTURE compte plus que les noms :
| Arme (5★) | + Passif | = Évolution |
|---|---|---|
| Kunai | Koga Ninja Scroll | Spirit Shuriken |
| Baseball Bat | Fitness Guide | Lucille |
| Lightning Emitter | Energy Cube | Supercell |
| Forcefield | Energy Drink | Force Barrier |
| Molotov | Oil Bond | Fuel Barrel |
| Guardian | Exo-Bracer | Defender |
| Drill Shot | Ammo Thruster | Whistling Arrow |
| Laser Launcher | Energy Cube | Death Ray |
| Revolver | Hi-Power Bullet | Reaper |
| Shotgun | Hi-Power Bullet | Gatling |
| RPG | HE Fuel | Sharkmaw Gun |
| Boomerang | Hi-Power Magnet | Magnetic Rebounder |
| Durian | HE Fuel | Caltrops |
| Brick | Fitness Guide | 1-ton Iron |
| Soccer Ball | Sports Shoes | Quantum Ball |
| Katana | Ronin Oyoroi | Demon Blade |
| Moonshade Slash | Ronin Oyoroi | Moonhalo Slash |

- **Multiplicateur par étoile ("Skill Mult")** : chaque arme a une table. Ex. **Kunai** : 1★=1.5 / 2★=2 / 3★=3 / 4★=4 / 5★=5.5 / EVO=5.5 (+1 kunai par étoile dès la 2e). **Molotov** : 0.6/0.8/0.9/1.1/1.2 (+1 projectile/étoile). **DPS d'arme = mult × nb projectiles × cadence.**
- **Double nature** : chaque arme est AUSSI un **équipement permanent** forgé hors-run (rareté Normal→Legendary→Relic + Astral Forge). Le forge booste la version in-run et peut **lever la contrainte du passif** (hook whale — ex. Kunai "Ninja Master" au 3★ forge). → *c'est le pont entre le run et la méta payante.*
- **Meta 2026** : quelques armes S/SS surclassent tout (**Starforged Havoc SS**, Void Power, Sword of Disorder, Lightchaser). La chasse à l'arme meta crée l'aspiration à dépenser. Garde ≥1 arme évoluée viable en F2P (rôle Lightchaser/Kunai).

---

## 4. Système de DÉGÂTS & de stats — le noyau de tuning (datamine réel)

> Extrait par décompilation du calculateur communautaire de référence **sio-tools** — c'est la vraie formule, pas le marketing.

**Les dégâts par coup sont un PRODUIT de ~20 buckets multiplicatifs.** Chaque bucket = `K(x) = 1 + x/100`, où `x` = **somme additive** de toutes les sources de cette catégorie. → **Additif DANS une catégorie, multiplicatif ENTRE catégories.** C'est ce qui rend l'empilement de gear "satisfaisant" sans explosion linéaire.

```
ATK_total = (ATK_base + ATK_equip·(1+equip%) + ATK_hero·(1+hero%)) · (1+ATK%) + ATK_flat
Dégât = ATK_total · critAvg · K(SkillDmg) · K(Vulnerability) · K(ShieldDmg·uptime)
        · K(ToPoisoned·up + ToWeakened·up + ToChilled·up + Exposed)  ← élémentaires partagent 1 bucket
        · K(Laceration·up + DivineFire·up) · K(DamageBoss) · … (≈20 buckets)
```

- **Crit** = facteur séparé (pas un bucket) : `critAvg = clamp(critRate,0,1)·max(critDmg,2) + (1−clamp)`.
  - **Crit rate bridé à 100 %** (les builds affichent 220 % → 100 % effectif → tout excédent gaspillé).
  - **Crit damage plancher ×2.0**.
  - **Bascule de tuning nette** : empiler crit rate jusqu'à saturation (~40-60 %), PUIS tout en crit damage. Optimal = `(1−CritRate)/(MultCritDmg−1)`.
- **Survie = PV uniquement. AUCUNE armure, AUCUNE esquive côté joueur** (vérifié dans le code : "dodge"/"armor" n'existent pas comme stats). "Défense" (tech parts, sets) = **PV plats**. `PV = PV_plats · (1 + ΣHP%)` + système de **revives**.
- **Défense ennemie / réduction de dégâts** : **NON dataminée**. Le calc de référence l'ignore (multiplicateur relatif). *(Un fan-model invente `defMult = ATK/(ATK+15×niveau_ennemi)` — à traiter comme hypothèse, pas donnée.)* En endgame, les ennemis ont **d'énormes PV** = pur **DPS-check**, pas une courbe de mitigation. Alternative propre pour un clone : des **paliers de "malédiction"** à seuils de score (ex. −15 % skill/−10 % crit à 3960 pts, … jusqu'à −100 %).
- **Tech Parts** (stats de fond) : +ATK plat `25/50/80/120/200/300/450/700/950/1200/1500` ; +HP plat `100/200/320/480/800/1200/1800/2800/3800/4800/6000`.
- **Méta versée en petits % account-wide** (+3/+4/+5 % ATK/HP/Crit par niveau de perso/collection) qui remplissent les buckets additifs → progression longue durée sans casser l'équilibrage par coup.

> **À répliquer** : implémenter les dégâts en buckets multiplicatifs ; brider crit rate à 100 % + plancher ×2 ; survie = pool de PV + revives (pas d'armure) ; exposer un **écran "Detailed Stats"** (la communauté a bâti des calculateurs autour → rétention theorycraft).

---

## 5. Spawn Director & scaling de difficulté

**Ce n'est PAS une IA de budget runtime — c'est une TIMELINE d'événements scriptée par chapitre**, posée sur un spawner façon Vampire Survivors. **Insight de réplication #1.**

- **Modèle** : `événements = [{t_start, t_end, type: swap_base | horde | elite | boss, enemy_id, rate/count}]`. Une piétaille de base spawn en continu ; toutes les ~30-60 s un événement scripté (a) change l'ennemi de base, (b) injecte une **horde** d'un type précis (les pics de pression), (c) lâche un **élite/mini-boss**, ou (d) déclenche un **boss** nommé.
- **Timeline Chapitre 1** (Wild Streets, 15 min, corroborée par 2 guides) : `1:00` 3 tireurs → `1:30` chiens → `2:00-2:30` **horde** de zombies → `3:00` pic + mini-boss "ouvrier" → `4:00-4:30` **horde** de chiens → `5:00` **BOSS Bouncebloom** (la piétaille devient blindée) → `8:00-9:00` horde chiens + élite slug → `10:00` **BOSS The Devourer** → `12:00` élite → `14:00` chiens (softener) → `15:00` **BOSS FINAL Steelgnasher**.
- **FORMAT de map = levier de difficulté principal** (bundle durée + boss + géométrie) :
  - **Open** : 15 min / 3 boss (5-10-15) / budget ~30-48k ennemis / spawn tous côtés.
  - **Enclosed** : 8 min / **5 boss** (cadence ~1 boss/1.5-2 min) / budget ~10-34k / arène murée.
  - **Linear** (couloir/entonnoir) : 15 min / 3 boss / budget **~32-141k** (2-4× l'Open !).
- **Budget total d'ennemis authored** par chapitre : Ch1=35k (~39/s), Ch3=10k (~21/s), **Ch7=141k (~157/s !)**, Ch10=95k. → **spawn rate de base = budget / durée**, hordes = +rate sur des fenêtres de 30-90 s. Le budget dépend du **format**, pas du numéro de chapitre.
- **Boss/élites ignorent le cap d'ennemis** et **ne despawn jamais** (téléportent) → pacing garanti.
- **Cap d'ennemis à l'écran** : *(non publié pour SIO ; marketing "1000+")*. **Référence Vampire Survivors** : cap **300 vivants** → le spawn périodique se met en pause (boss/events exemptés) ; piétaille spawn juste hors-écran + despawn à distance. → tune vers le haut selon la cible hardware.
- **Scaling par chapitre** : surtout via une **DEF ennemie** qui rogne ton output (armor curve liée au "level" ennemi), + croissance modérée des PV. *(non dataminé — communauté : niveau 100 ≈ −50 % dégâts.)*
- **Coût en énergie apparaît à Ch10+** (17 énergie) ; Ch1-9 gratuits (onboarding sans friction).

---

## 6. Bestiaire & boss

**Roster de boss PETIT et RÉUTILISÉ** sur ~30 chapitres avec PV croissants + 1 mécanique ajoutée par palier (pas 30 boss uniques = économie de prod majeure). **Chaque attaque est TÉLÉGRAPHIÉE** (ligne rouge avant charge, trajectoire visible, aura de contact) → maîtrise = esquive positionnelle pure.

**6 archétypes canoniques** (à couvrir) :
1. **Charger/rusher** (Nasher/Gnasher/Devourer/Bull) : pause → télégraphe → dash en ligne. Contre : perpendiculaire/opposé, punir la récupération.
2. **Flyer-ranged** (Papillon/Bird) : projectiles en dérivant ; tiers hauts = homing + spawn d'adds.
3. **Splitter-projectile bug** (Stinger) : tire des projectiles qui **se fragmentent** en sous-projectiles plus rapides.
4. **Humanoïde lanceur/beam** (Manager→Director→Chairman→Zombie Chief) : escalade projectile simple → rebondissant → saut+explosion AoE → beam continu → bullet-hell.
5. **Laser-charger hybride** (Corpsehound/Laser Hound) : dog rapide qui coince + laser d'yeux.
6. **Zone-hazard/poison** (Bouncebloom/Purple Blob/Toxinator) : laisse du sol dégâts (poison/gaz) ou projectiles rebondissants.

+ un **summoner/deployer** (lâche des objets qui explosent) et **1 vrai boss multi-phases** (Rushgnasher : lasers → lance sa propre tête qui tire aussi) pour un pic mid-game. Capstone : **boss "fusion"** tardif (Queen Papillon = rush + spray + adds + homing) = test final.

- **Trash-mob hook** : ennemis qui laissent une **flaque de gaz à leur mort** (papillons) → forcent le mouvement au lieu de facetank.
- **Boucle Élite → Inspire** : tuer un élite/boss avec le bon gear = buff (Army Uniform = heal-over-time ; Army Nameplate = **+20 % dégâts, perdu au premier coup reçu** → récompense l'esquive parfaite ET vend le gear défensif). Lie le bestiaire à l'économie de gear.
- **Pas de valeur PV/dégâts de boss publiée** (scale par chapitre/difficulté). ~16 boss nommés suffisent pour couvrir Ch1-20 ; les chapitres profonds sont des **reskins** (Désert/Volcan/Forêt) + bumps de stats.

---

## 7. Système d'effets de statut (DEBUFFS) — moteur d'endgame

**Pas un système de DoT-DPS, mais un moteur "collectionne les multiplicateurs".** 4 tags de debuff canoniques : **Poisoned, Weakened, Chilled, Lacerated (Bleed)**. Chacun débloque un stat offensif **"Damage to [state]"** qu'on investit sur le gear.

- **Chaque "Damage to [state]" = un bucket MULTIPLICATIF séparé.** Infliger Weakened ×ET× Chilled ×ET× Poisoned ×ET× Bleed ×ET× Vulnerability **multiplie** `(1+ToWeak)·(1+ToChill)·(1+ToPois)·(1+ToLac)·(1+Vuln)` → les builds "inflige tout" **explosent**. C'est l'insight #1.
- **Uptime-gated** : bonus réel = `magnitude × uptime` (fraction du temps où l'ennemi porte le debuff). → lève une **2e monnaie** : *"Over-time effect duration"* (+10..50 %) pour acheter de l'uptime.
- **Magnitudes vérifiées** : Weaken = −10 % ATK ennemi ; **Vulnerability = +10 % dégâts subis, 10 s, ne stack pas** (le mieux spécifié) ; Void Fissure = +10 %→+20 % (scale au forge) ; Deep Wounds = +10 % sur brûlés.
- **Fire/Burn n'a PAS de bucket "To Burning"** → routé via **Deep Wounds** (+10 % dégâts subis). Réserve 2-3 debuffs "+X % dégâts subis" comme effets premium/tier-arme.
- **Anti-synergies volontaires** : le feu/laser **efface les flaques de poison** au sol → feu et poison se disputent la map (vrais choix de build).
- **Tick DPS / durée / % de slow exacts NON publiés** → fixe les tiens (ne copie PAS Soulstone Survivors).
- **Productisation** : concentre le moteur dans **1 set-phare** (SS Starforged Havoc) qui applique Weaken + Void Fissure + Vulnerability + amps → transforme "applique chaque debuff" en **objet aspirationnel unique**.

---

## 8. MÉTA permanente : équipement & économie de FUSION (le vrai puits de dépense)

- **6 slots portés** : Arme, Armure, Collier, Ceinture, Gants, Bottes.
- **~15 crans de rareté** : Normal(gris) → Good(vert) → Better(bleu) → Excellent(+0/+1/+2) → Epic(+0/+1/+2/+3) → Legend(+0/+1/+2/+3/+4) → **S-grade** → **SS/Relic**.
- **Fusion 100 % par copies identiques, AUCUNE montée par XP** (c'est ce qui force la dépendance au gacha) :
  - `3× Normal = 1 Good` ; `3× Good = Better` ; `3× Better = Excellent` ; `Excellent+2 = fusions` ; `Epic = 2× Excellent+2` ; `Legend = 2× Epic` ; Legend+1..+4 = +1 Legend chacun ; **Relic = uniquement via Cosmic Cast**.
  - Coût **géométrique doux au début (3), explosif au sommet** (~108 pièces Normal pour 1 Legend de base ; bien plus pour Legend+4).
- **Chaque montée de grade débloque une "Grade Skill"** (pas un simple +stat) → sauts de puissance ressentis qui justifient chaque fusion.
- **PAS de set-bonus RPG classique** : pièces autonomes dont les compétences se complètent. Les "sets" (Eternal 6★ → Voidwaker 7★ → Chaos 8★) sont des **lignées thématiques** = **power-creep vertical par générations** (chaque nouvelle lignée relance le grind sans re-designer le système).
- **Astral Forge** (enchantement par-dessus le merge) : effets 1-5★, **double le plafond de dépense**, alimenté par le **salvage des doublons** (Cores/Cubes) → les whales n'ont jamais "fini".
- **Cosmic Cast → SS/Relic** : consomme des devises de **2 lignées** (ex. **50 Eternal Cores + 50 Voidwaker Cores + 2000 Cubes** par pièce) → gate endgame obligeant à investir dans plusieurs sets.
- **Boucle fermée par salvage** : aucun doublon perdu (recyclé en devises de forge) → réduit la frustration tout en canalisant vers plus de progression.

---

## 9. Gacha, pity, pets, tech parts, personnages, monnaies

- **Empiler PLUSIEURS gacha à pity COURT (10)** plutôt qu'un seul à pity long. Chaque système (gear, pets, tech, xeno) a son coffre + sa monnaie de fusion → multiplie les points de conversion.
- **Gacha gear "S Grade Supplies"** : **300 gemmes/tirage**, **2680 gemmes le ×10** (économie 320 = ancrage "achat malin"). **Excellent garanti tous les 10** (reset si sorti avant). *(S garanti à 50 = 1 seule source, non vérifié.)*
- **Pity transparent** ("Excellent garanti tous les 10") + **vrai jackpot en longue traîne probabiliste** par-dessus → rassure tout en gardant la chasse.
- **Pets** : 1 pet actif (dégâts) + 2 assists (buffs). ~9-10 de base (Croaky souvent #1, Whaley = seul S). Couche endgame **Xeno Pets** (exige d'avoir max 4 pets → relance la dépense des avancés). Assists à viser : Resonance/Attack%/Crit Damage.
- **Tech Parts** : 6 slots (3 ATK + 3 DEF), 7 grades → Eternal, chaque part **modifie une arme précise** (synergies). Fusion 3-pour-1.
- **Personnages** : distribués **simultanément** par shards (80), Battle Pass, ET cash → F2P unlock lent, payeur court-circuite ; **crossovers en event** (SpongeBob, TMNT) = pics d'acquisition + FOMO.
- **Monnaies** : **Gemmes** (premium, gacha) / **Gold** (fusion, upgrades — échange gemmes→gold à taux **punitif** pour que le cash finance le gacha) / **Énergie** (cap 30, **5/run**, refill pub/gemmes) rythmeur de sessions.

---

## 10. Monétisation (catalogue IAP + psychologie)

**Split ~65 % IAP / 35 % pub. Monétisation PROGRESSIVE** : aucune boutique au niveau 1, les systèmes payants se débloquent **un par un** après que le fun a accroché.

**Catalogue IAP réel (App Store US, $)** :
| Produit | Prix | Mécanique psychologique |
|---|---|---|
| Some Gems | 0,99 $ | entrée |
| **Small Piggy Bank** | 0,99 $ | **effet de dotation** (payer pour "réclamer" les gemmes déjà accumulées) |
| Daily Pack 1 / 2 | 0,99 / 1,99 $ | habitude de check-in (refresh countdown) |
| **Chapter Pack 1/2/3** | 1,99 / 2,99 / 2,99 $ | **gated par completion, affichés à ~600 % de valeur** au moment du mur |
| Pile of Gems | 4,99 $ | |
| **Growth Fund** | 6,99 $ | verse par paliers à mesure qu'on progresse (rétention) |
| **Month Card** | 9,99 $/mois | gemmes/jour + cap énergie → 50 (**LTV récurrent**) |
| **Survivor Pass** (battle pass) | ~19,99 $ | 30 paliers, **3000 gemmes** dans le premium vs 2500 en boutique au même prix = **ancrage "meilleure affaire"** ; débloque le perso de saison |

- **"Créer la difficulté, vendre le soulagement"** : mur (Trials Ch.6, cap d'énergie, pity incomplet) → l'offre pertinente (pack ~600 %, S Supply) apparaît **juste à ce moment**.
- **3 biais exploités** : actualisation hyperbolique (Quick Patrol time-skip), effet de dotation (Piggy Bank), **coût irrécupérable** (finir un pity gacha entamé).
- **Revive** : 1 pub gratuite OU gemmes ; **ne pas revive = perdre les récompenses du niveau** (forte pression).
- **Pub récompensée = subvention d'onboarding**, pas revenu principal : revive, +énergie (3 pubs), Quick Patrol 300 min, double loot offline — caps généreux early puis bascule vers l'IAP.

---

## 11. LiveOps, événements, rétention, modes & contenu

- **Campagne = rail infini extensible** : ~290 chapitres (oct. 2025) → ~335 (mi-2026), **+~5 chapitres/patch**. Les chapitres sont un **gate de puissance**, pas "le contenu".
- **Mode-drip (gating par seuil de chapitre)** : **Ch2** → Trials/défis ; **Ch3** → Clans ; **stage 10** → Co-op local (2 joueurs) ; **Ch20** → Steamroll.
- **Ender's Echo** (endgame phare) : **DPS-check contre un boss INVINCIBLE** (score = dégâts + survie), **saisons 28 j**, **4 boss en rotation hebdo**, tiers **Novice/Elite/Ace** avec promotion/relégation, 2 essais gratuits/jour, récompenses postées selon le rang. → pull compétitif récurrent avec **quasi zéro art nouveau par saison**.
- **Mega Challenge** (**gear-agnostique**, stats désactivées, skill pur) = **soupape d'équité** F2P (le gear des whales n'aide pas ici).
- **Daily Challenge** (6 min, 3 boss, cap 2 essais) = principal **robinet de Tech Parts** ; **Gold Mine** (3 min, no energy) = farm d'or. **Patrol AFK** (cap 24h → force 2 connexions/jour).
- **Server Launch Challenge** : event **7 jours réservé aux nouveaux** (one-shot, **disparaît à jamais**) : 700 pts → armure S, 1500 pts → arme S. Booste la power curve early + FOMO + ouvre la fenêtre de conversion J1-J7.
- **Collabs IP grand public** (récurrentes, boutique-à-points, double monnaie) : **Nickelodeon (SpongeBob, TMNT)** — PAS de niche gaming. Coquilles réutilisables amortissent la licence.
- **Social léger & asynchrone** : Clan (20 membres, création 500 gemmes), **Clan Expedition** PvE (24h prép, phases, classement). **AUCUN PvP temps réel** (choix délibéré — zéro netcode).
- **Rétention modeste assumée** (D30 4 %) **compensée par LiveOps agressif sur les whales** : pipeline de contenu live **obligatoire**, pas un lancement one-shot.

---

## 12. Onboarding / FTUE (première session)

- **Zéro friction** : en jeu dès le 1er tap, un doigt, tir/visée auto. **Pas de création de perso, pas de wall de texte** — apprentissage par le faire.
- **Congruence pub ↔ FTUE** : le hook des pubs TikTok ("1 héros vs 1 million", écran qui se remplit) doit être **vécu dans les 30 premières secondes** (sinon dissonance → churn).
- **1er "moment WOW" garanti en MILIEU de 1re run** (pas en fin) : la **première évolution d'arme** qui remplit l'écran (passage de "je survis" à "je domine").
- **Générosité d'accueil** : coffres + gold gratuits immédiats (endowment), **1 coffre/pull gratuit quotidien** (ancre le check-in).
- **Déverrouillage UN PAR UN** (drip-feed anti-overwhelm) : énergie/pub → Quick Patrol → Piggy Bank → daily packs. Les **packs early sont les plus achetés**.
- **Hook Model (Nir Eyal)** mappé : **Trigger** (pub/notif/énergie/Patrol prêt) → **Action** (1 tap) → **Reward variable** (draft 3, évos, coffres) → **Investment** (merge/upgrade/event 7j). Chaque boucle nourrit la suivante.

---

## 13. Acquisition & marketing (UA) — le nerf de la guerre

- **TikTok = canal n°1 (~50 % du budget)**, reste sur IronSource/Google/Unity/Vungle/Facebook/AppLovin.
- **Flywheel** : réinvestir **jusqu'à ~80 % du revenu quotidien** en UA tant que le ROAS tient (fenêtre CPI bas + boost de classement store = canal organique gratuit). Faisable car double moteur **IAP + IAA** remonte le cash vite.
- **Créas NATIVES (pas de pub)** : screen-recording de gameplay **réel mais dopé** (hordes démesurées "1 héros vs 1 million") + voix-off + texte overlay + **angle "découverte sociale"** ("j'ai vu quelqu'un jouer, son choix d'arme m'a scandalisé"). L'utilisateur ne réalise que c'est une pub qu'à la fin.
- **"Fail ads"** : jouer **mal exprès** dans les 5-10 premières secondes (effets rouges, panneau "fail", fin non résolue) → déclenche le **correctional impulse** ("je ferais mieux"). ~26 % des top créas du secteur.
- **Micro-influenceurs** (parasocial/authenticité) > méga-créateurs : fausse interview de rue, angle "mom/family".
- **Géo** : enchérir haut sur **Asie T1** (Corée 15,50 $/DL, Chine 9 $/DL) pour le LTV, **Occident** (US, Brésil, Vietnam) pour le volume + CPI bas.
- **ASO** : nom avec ponctuation d'urgence ("Survivor**!**.io"), screenshots CTA rouge/action, video preview différenciée (portrait combat iOS / paysage préparation Play), in-app events.
- **Conséquence design** : le jeu doit être **visuellement lisible & clipable** dès le game design (2D épuré, hordes, feedback satisfaisant), sinon la machine TikTok ne s'amorce pas.

---

## 14. Engineering / performance — rendre des centaines/milliers d'entités à 60 fps

> Survivor.io ne publie pas ses internes ; c'est **Unity IL2CPP** (SDK Unity Ads/AdMob/FAN, APK ~1,54 Go). Les chiffres ci-dessous = **recette d'ingénierie bullet-heaven** (benchmarks tiers), à valider au profiler.

- **Bon dimensionnement** : viser **quelques centaines à ~1000 entités** à 60 fps sur un tel de classe Mali-400, PAS les milliers PC de Vampire Survivors. Atteignable avec **pooling + grille uniforme + rendu instancié**, **sans DOTS**.
- **Budget frame = 16,6 ms** (CPU 8-10 / GPU 8-10 / 2-3 de marge thermique). Ennemi du 60 fps = **overdraw** (VFX transparents empilés) et **draw calls**, PAS le polycount. Budget draw calls low-end : **50-120/frame**.
- **Rendu** : tuer le GameObject par entité → positions en arrays plats + `DrawMeshInstanced` (**cap 1023/batch**) = **1 draw call par essaim**. + **SRP Batcher** + **1 atlas par couche** (mesuré : 3800 → 47 draw calls). Textures **ASTC**.
- **Pooling zéro-alloc** : jamais Instantiate/Destroy en run (les spikes GC = hitches). Le pool = **le point d'application du cap**. Pas de LINQ/`new List` dans la hot loop (retirer LINQ = ~3× plus rapide).
- **Partition spatiale = grille uniforme** (bat les quadtrees pour des essaims dynamiques). `cell = floor(pos/cellSize)`, `cellSize ≈ rayon d'interaction`. Ne re-bucketer qu'au **changement de cellule**. Toujours comparer les **distances au carré**. Mesuré : collision brute 100 ms → grille 1 ms.
- **Le système le PLUS cher = la SÉPARATION ennemi-ennemi** (pousser la horde pour qu'elle ne s'empile pas). Gather les voisins **1 fois/tick** depuis la grille et **réutiliser la liste** pour séparation + collision + ciblage (**shared neighbor list** = mesuré −59 %). Ne considérer que **K voisins** (4-8).
- **Auto-aim à l'échelle** : ne PAS `FindObjectsOfType` + O(n)/frame. Query la cellule du joueur + anneau, distances², et **throttle** la ré-acquisition à la cadence de tir.
- **Animation de horde** : Animator/SkinnedMesh meurt ~1000 → **flipbook shader** (2-4 frames) ou **Vertex Animation Texture** (sampled en vertex shader), grouper par état d'anim = 1 batch instancié. *(→ explique le style d'anim minimaliste de SIO.)*
- **Despawn/recyclage** : recycler la piétaille hors-caméra vers un **anneau de spawn** juste hors-écran (réutiliser l'instance). Boss ne despawn jamais.
- **Fixed-timestep** (accumulateur, DT=0.0166667) + interpolation au rendu → DPS/spawn cohérents entre appareils + base pour anti-cheat.

---

## 15. KPIs & benchmarks (cibles réalistes)

- **Revenus** : 75 M$ en 2 mois (37 M installs), 311 M$ an 1, 182 M$ en 2023, **>500 M$ cumulés** mi-2024, ~5-6 M$/mois en 2025 (→ ~2 M$/mois début 2026). Revenu/DL cumulé early ≈ **2,09 $**.
- **Installs** : rampe 11k→100k→400k/jour, **pic 843k/jour**. ~69 M an 1, ~80 M+ mi-2025.
- **Rétention** : **D1 44 % / D7 15 % / D30 4 %** (vs Archero 49/23/11). → viser D1 ~44 %, **ne pas sur-optimiser la rétention au détriment de la conversion précoce**.
- **Géo** : Chine 24,2 % / Corée 21,2 % / US 21,2 % du revenu. **Asie de l'Est = 75 %+**.
- **Contexte** : Habby (Singapour, ex-Cheetah Mobile) = **n°1 mondial hybrid-casual**, 2 Md$+ de dépenses cumulées (SIO ≈ 40 %). **Vampire Survivors** (premium ~5 $, non-prédateur) = ~10 M copies mais **10-20× moins** de revenu → **preuve que la monétisation vient de la surcouche hybrid-casual + l'UA, pas de la boucle.**
- **Pourquoi le genre a explosé** : boucle dopamine-dense, input minimal (1 main), power fantasy, runs ~15 min (session mobile idéale), **hyper-clipable** (viral TikTok).
- **Pourquoi les clones échouent** : copient la surface **sans la méta hybrid-casual profonde**, prod low-cost, pas d'UA TikTok industrialisée, mauvais ciblage géo (visent US au lieu de l'Asie). **La barrière réelle est financière (UA) + contenu (méta/LiveOps), pas technique.**

---

## 16. MAPPING sur mecha-forge — ce qu'on a / ce qui manque / priorités

### ✅ Déjà en place (le core loop est solide, ~80 % du genre)
- Contrôle 1-pouce + **auto-aim** + tir auto ; hitbox < sprite (à vérifier) ; pooling projectiles/pickups.
- Boucle **tuer → XP gems → draft 3 cartes** (reroll + banish) ; **crit** ; passifs draftables.
- **Armes + évolutions** (4 base + 4 évoluées via passif possédé), **multishot**.
- **Boss timés** (5/10/15) + barre de vie ; **biomes/maps** + changement de map ; **hordes/vagues massives**.
- **Modes de difficulté** (Facile→Vétéran) + **score/grade + record local** (base leaderboard).
- **Méta-progression** (5 talents) ; **garage de mechs** (achat en ferraille) ; **aura/drones** ; audio.

### ❌ Ce qui manque (= là où est l'argent — presque toute la couche méta/monétisation)
| Système SIO | mecha-forge | Priorité |
|---|---|---|
| **Économie d'équipement + fusion 3-pour-1** (raretés, grade skills) | absent | 🔴 **#1** (le puits de dépense) |
| **Gacha à pity court** (coffres, monnaie premium) | absent | 🔴 #1 |
| **Système de dégâts en buckets multiplicatifs** + écran Detailed Stats | multiplicateurs simples | 🟠 #2 |
| **Debuffs "Damage to [state]"** (poison/gel/saignement) multiplicatifs | absent | 🟠 #2 |
| **Énergie** (rythmeur de sessions) | absent | 🟠 #2 |
| **Battle Pass + Month Card + packs "600 %"** | absent | 🔴 #1 (monétisation) |
| **Spawn director = timeline scriptée** par map | spawner par rate/rank | 🟠 #2 (on a les briques) |
| **Roster de ~10 boss réutilisés + télégraphes** | 2 boss (mid/end) | 🟡 #3 |
| **Tech parts / pets** (multiplicateurs de build) | drones seulement | 🟡 #3 |
| **Ender's Echo (DPS-check ranked) + Daily/Trials/Mega** | run unique | 🟡 #3 |
| **FTUE scriptée + Server Launch Challenge 7j** | écran difficulté direct | 🟠 #2 (rétention J1-J7) |
| **Classement en ligne + clans** | score local | 🟡 différé (ton choix) |
| **Perf hordes** (grille + instancing + flipbook) | Godot 2D, ~190 ennemis | 🟢 valider au playtest |

### Ordre de bataille recommandé (pour mecha-forge)
1. **Boucler la boucle roguelite** (déjà fait) → s'assurer que le **1er "moment wow"** (évolution/aura qui remplit l'écran) arrive en milieu de 1re run.
2. **Poser la méta d'équipement + fusion + gacha à pity** = le moteur de rétention/LTV. Sans ça, on est Vampire Survivors (fun mais ne monétise pas).
3. **Refondre les dégâts en buckets multiplicatifs** + **debuffs multiplicatifs** + **écran Detailed Stats** (profondeur de build + theorycraft).
4. **Monétisation** : énergie + revive (déjà pub) + Battle Pass + packs gated par mur + Month Card.
5. **FTUE + event 7 jours nouveaux** (rétention early) ; **spawn director scripté** par map (timeline d'events).
6. **Endgame** : un mode **DPS-check ranked** (Ender's Echo-like) + daily challenge (robinet de matériaux).
7. **LiveOps** : pipeline de contenu (maps/boss reskins) + events récurrents.

---

## 17. Avertissements (à ne pas oublier)

- **Chiffres non officiels** : cap d'ennemis à l'écran, courbe de DEF ennemie, tick DPS des DoT, % de slow, PV de boss — **NON publiés pour SIO**. Fixe les tiens et valide au playtest.
- **Ne copie pas** les valeurs de DoT de Soulstone Survivors/Megabonk (autres jeux).
- **Légal/IP** : lois de divulgation des taux de loot-box (Chine/Corée/Belgique/Pays-Bas), classification gambling du gacha, **risque de litige clone** (Vampire Survivors), coût des licences crossover. À anticiper.
- **La vraie barrière = financière (UA) + contenu (LiveOps)**, pas le code. Un excellent clone sans budget UA TikTok ni pipeline de contenu **ne perce pas**.

---
*Fin du playbook. Recherche : 16 agents, ~520 recherches web, sources croisées. Voir aussi `RESEARCH_PROMPT.md`, `ACTION_PLAN.md`, `REPOS_EVAL.md`.*
