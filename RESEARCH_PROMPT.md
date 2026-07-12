# PROMPT DE RECHERCHE — Faire de « mecha-forge » un très bon survivor-like mobile

## A) RÔLE + OBJECTIF

Tu es un **consultant senior en game design et product F2P mobile**, spécialiste des survivor-like / bullet-heaven (Vampire Survivors, Survivor.io, Archero, 20 Minutes Till Dawn, Brotato, Halls of Torment). Tu combines expertise en **game feel, systèmes de progression, monétisation hybride ads+IAP, rétention/LiveOps, UX tactile et shipping technique Godot 4.x**.

**Objectif :** produire un **guide complet, chiffré et directement actionnable** pour transformer le MVP décrit ci-dessous en un survivor-like mobile Android F2P **shippable et rétentif**, réalisable par un **développeur solo / petite équipe à budget serré, sans GPU serveur**. Tout doit être hiérarchisé par **impact vs effort**, appuyé sur des **benchmarks vérifiés**, des **jeux décortiqués**, et se conclure par une **feuille de route priorisée**.

---

## B) CONTEXTE DU PROJET

- **Genre / plateforme :** survivor-like / bullet-heaven top-down, vue 3/4, **mobile Android d'abord, F2P**. Export web pour tests.
- **Moteur :** Godot 4.3, GDScript.
- **Pipeline d'art SANS GPU sur le serveur :** concepts via Gemini/FLUX → modèles 3D via Meshy.ai → rigs procéduraux Blender → animations procédurales → **sprites 4-directions bakés**. Contrainte forte : chaque nouvel ennemi/arme = coût sprite directionnel.
- **État actuel (MVP jouable) :** ennemis animés directionnels avec **archétypes (mêlée / ranged)** ; armes avec VFX ; boucliers d'énergie ; **8 biomes** ; XP/level-up avec **draft de 3 cartes** ; **jauge Overdrive + transformation**.
- **PAS ENCORE fait :** livraison Android (build, keystore, Play Console), monétisation (seulement de la prose), méta-progression profonde, live-ops.
- **Cible équipe :** dev solo/petite équipe, budget serré → privilégier **recombinaison procédurale d'assets**, systèmes **data-driven** (Godot `Resource` / JSON) et **object pooling**.

---

## C) DOMAINES DE RECHERCHE (plan logique, dédupliqué)

> Traite les 9 sections dans l'ordre. Pour chacune : réponds aux **questions précises**, valide/corrige les **benchmarks chiffrés**, cite les **références**, signale les **pièges**.

### 1. Marché, concurrents & KPIs (cadre stratégique)

**Questions précises**
- Quel **ARPDAU** viser en survivor-like hybridcasual Android, et quel **split ads/IAP** réaliste ?
- Quelles **rétentions D1/D7/D30** séparent un titre « shippable » d'un top-grossing ?
- Quel **run length** et combien de **runs/jour** maximisent la rétention D7 ?
- Quel **CPI cible** rend le LTV soutenable en soft-launch solo ? Faut-il privilégier scaling **organique/ASO** avant l'UA payante ?
- Où placer le **premier prompt IAP** dans le funnel FTUE ?

**Benchmarks à vérifier**
- Rétention hybridcasual : **D1 35-45 %, D7 10-18 %, D30 3-8 %**.
- ARPDAU : **0,05-0,15 $** (ads-heavy), top Survivor.io ~0,20 $+. Split **60-75 % pub / 25-40 % IAP**.
- CPI Android : **0,30-1,50 $** (Tier-3) à **2-4 $** (US). LTV:CPI **≥ 1,3**, payback < 6 mois.
- Watch-rate rewarded 15-30 % ; % payeurs 1,5-3 %.

**Références à décortiquer :** monétisation par titre — Survivor.io (IAP+pubs, offres limitées), Archero (energy-gate + gacha équipement), Vampire Survivors (premium 4,99 $ → F2P mobile ad-supported), 20MTD/Soul Knight (premium/hybride). Data : SensorTower/data.ai (revenus Survivor.io ~10 M$/mois au pic), GameAnalytics, Adjust/AppsFlyer hybridcasual reports, Deconstructor of Fun.

**Pièges :** copier la monétisation premium console de VS sur F2P mobile ; gates d'énergie trop tôt (churn D1) ; interstitiels avant le premier « aha » ; viser le top-grossing sans soft-launch chiffré ; ignorer le payback UA en solo.

### 2. Boucle de jeu & game feel (core loop, montée en puissance, difficulté, juice)

**Questions précises**
- **Durée de run optimale** sur mobile F2P et **à quelle minute** placer le pic de menace et le boss ?
- À quelle **fréquence** proposer une carte (début vs fin de run) pour éviter la fatigue décisionnelle ?
- Comment calibrer la **montée en puissance** pour que le joueur se sente « OP » à mi-run tout en gardant un risque de mort réel ?
- Quels effets de **juice** offrent le meilleur ratio **ressenti / coût perf** sur GPU mobile bas de gamme ?
- Boucle **Overdrive** : conditions de charge, fenêtre de défoulement, punition/récompense ?

**Benchmarks à vérifier**
- Run cible mobile : **12-18 min** avec **boss à mi-parcours** (VS ~30 min = trop long ; Survivor.io / 20MTD = 15-20 min).
- Level-up : **~1 toutes les 30-60 s** en début, espacement croissant ; **premier choix < 90 s**.
- **Hit-stop 40-80 ms** ; **screen-shake < 200 ms** ; **60 FPS stable = priorité absolue**.
- Pic de fin de run : joueur tue **> 100 ennemis/min**.

**Références :** Vampire Survivors, Survivor.io, 20MTD, Brotato (drafts), Halls of Torment ; Jan Willem Nijman « The Art of Screenshake » ; Steve Swink *Game Feel*.

**Pièges :** difficulté scalant sur le **temps seul** (ignore le build → murs injustes ou trivialité) ; trop de choix par run = paralysie ; **particules non poolées** → chutes de FPS (object pooling + GPUParticles2D limités).

### 3. Systèmes de progression (upgrades en run, évolutions/synergies, drafting, méta, prestige)

**Questions précises**
- Quelle **courbe XP** donne **~15-25 level-ups** sur une run de 15-30 min ?
- Combien d'**armes/passifs simultanés** (cap type 6+6 façon VS) pour rester lisible sur écran 6" ?
- Quel **% de builds** doit converger vers une **évolution « hero »** pour créer le « aha » sans frustrer ?
- **Reroll/banish/skip** : coût, nombre gratuit par run, banish permanent ou non ?
- Méta-progression : **quel % de puissance** vient du méta vs du skill in-run (éviter le pay-to-win perçu) ?

**Benchmarks à vérifier**
- 3-4 choix par level-up ; **cap conseillé 6 armes actives** (perf Godot + lisibilité).
- **8-12 armes évolutives** au lancement (pipeline art contraint), **4-6 évolutions**.
- Boost persistant du méta **plafonné à ~20-30 %**.

**Références :** VS (évolutions arme max + passif), Survivor.io (gear/gacha F2P), Brotato (boutique + économie), 20MTD (arbres talents), Halls of Torment (progression persistante douce).

**Pièges :** trop d'armes → explosion du pipeline sprites 4-directions ; **évolutions non télégraphiées** (montrer le chemin via icône combo) ; méta trop lourd = pay-to-win ; level-ups qui figent l'écran trop souvent ; synergies invisibles (documenter chaque combo dans l'UI).

### 4. Contenu & variété (ennemis, boss, pacing, biomes, armes, personnages)

**Questions précises**
- Combien d'**ennemis, armes, personnages, biomes AU MINIMUM** pour un lancement crédible (vs VS ~15+ armes / Brotato 44+44) réaliste en solo ?
- Cadence d'introduction de **nouveauté** sur une run (nouvel ennemi/élite toutes les X min ?).
- Combien d'**archétypes de base recombinables** suffisent ? Ratio « vrais nouveaux ennemis » vs variantes visuelles ?
- Cadence de **boss** idéale (mid-boss + boss final ?) et **scaling HP/DPS**.

**Benchmarks à vérifier**
- Boss/mini-boss **toutes les 3-5 min**.
- Densité : montée vers 300-800 ennemis « perçus » **mais viser ~150-250 sprites simultanés** via pooling sur mobile.
- Variété économe : **6-8 archétypes × 3-4 variantes = 20-30 ennemis perçus**.
- Lancement : **8-12 armes (4-6 évolutions), 6-10 persos, 4-6 biomes** (le MVP a déjà 8 biomes → question : les rendre gameplay-différenciants).

**Références :** VS (évolutions + arcanes), Brotato, Survivor.io, 20MTD (banish), Death Must Die / HoloCure (qualité perçue).

**Pièges :** trop de contenu unique fait-main (irréaliste solo) → **recombinaison procédurale** (les calques mecha du projet aident) ; biomes **cosmétiques sans impact** = variété illusoire → lier biome à des modificateurs de spawn ; pics de densité qui tuent le framerate ; absence de power spikes (évolutions) → run plate.

### 5. UX mobile & contrôles (tactile une main, auto-aim, lisibilité, FTUE, accessibilité, scaling)

**Questions précises**
- **Floating stick (still/dynamic) vs fixe** : lequel maximise la rétention D1 ?
- **Auto-aim par défaut ON ?** Quel algo de ciblage (plus proche / plus faible / dans le cône de déplacement) réduit la frustration sans trivialiser ?
- **Taille tactile minimale** des boutons et **rayon mort** du stick (dp / px @1080p / mm réels) ?
- Combien de secondes avant **première action / premier kill / premier level-up** ?
- Quelle **densité max d'entités** avant chute sous 60 FPS sur Android milieu de gamme (Snapdragon 6xx) ?

**Benchmarks à vérifier**
- Cible tactile **≥ 48 dp (~9 mm)** ; zone morte stick **~8-12 % du rayon**.
- **60 FPS stables, jamais < 30** ; budget frame < 16 ms ; **200-400 entités** via pooling/MultiMesh.
- FTUE : **action < 3 s, premier kill < 10 s, premier level-up < 60-90 s, tutoriel < 30 s**.
- Safe-area **≥ 24-48 px** ; UI critique dans les **2/3 inférieurs** (pouce).

**Références :** VS, Survivor.io, 20MTD, Archero (auto-fire à l'arrêt), Soul Knight (twin-stick) ; Godot `DisplayServer.get_display_safe_area()`, TouchScreenButton, viewport stretch `canvas_items`, `content_scale`.

**Pièges :** doigt qui masque le héros (déporter le héros vers le haut) ; texte < 14 dp ; VFX saturé qui noie les télégraphes ennemis ; twin-stick forcé ; UI en px absolus non responsive (ne pas tester qu'en 1080p).

### 6. Art, audio & feedback (clarté en chaos, telegraphing, palette, audio, haptique, style store)

**Questions précises**
- Quel **ratio de contraste** projectiles/ennemis vs fond garantit la lisibilité à 6" ?
- Combien de **particules simultanées** avant chute sous 60 FPS (Snapdragon 6-gen) ?
- **Durée idéale de windup** d'attaque ennemie (ms) ? Boss ?
- Faut-il **réserver le rouge exclusivement au danger** ? Combien de teintes sémantiques ?
- **Hitstop (ms)** qui améliore le juice sans casser le flow ?

**Benchmarks à vérifier**
- Budget VFX **~200-400 particules actives max** en milieu de gamme.
- Windup ennemi **300-600 ms** ; boss telegraph **700-1200 ms**.
- Hitstop **30-80 ms** ; screenshake **< 150 ms**, amplitude faible.
- Haptique **10-30 ms/tick, ≤ 2/s**. Sémantique couleur : **rouge = danger, cyan/blanc = joueur, < 3-4 teintes**.

**Références :** VS, Survivor.io, Brotato, 20MTD, HoloCure ; « damage number pooling », « enemy flash on hit », « screen-clear feedback » ; Nijman « Art of Screenshake » ; Godot `CanvasItemMaterial` additive, `Input.vibrate_handheld`.

**Pièges :** trop de bloom/additif → écran laiteux illisible en horde ; ennemis et sol de même valeur tonale ; sprites 4-directions à outline incohérent (rupture de style) ; audio sans priorité/ducking → bouillie à 200 ennemis ; icône store générique → 0 CTR.

### 7. Monétisation & économie F2P (ads, IAP, double-monnaie, gacha, battle pass, sinks/sources)

**Questions précises**
- Quel **eCPM rewarded réaliste** par géo et combien de rewarded/session **sans nuire à la rétention** ?
- **Placement revive** : 1 gratuit/run + payant, ou tout rewarded ? Impact ARPDAU ?
- **Prix optimal** du remove-ads et du starter pack pour un solo ? Battle pass **dès le lancement ou post-MVP** ?
- Quelle **profondeur de méta** finance les IAP **sans pay-to-win** qui tue la D30 ?

**Benchmarks à vérifier**
- ARPDAU hybride ~**0,02-0,15 $** ; rewarded eCPM Android **8-15 $ (Tier-1), 1-3 $ (Tier-3)**.
- Payeurs **2-5 %** ; whales (<1 %) = **40-60 % du revenu IAP**.
- Rewarded sain : **30-60 % DAU, 3-6 vues/session** ; interstitiel **toutes les 2-3 runs** (jamais en combat).
- Starter pack **0,99-2,99 $**, conversion first-purchase **1-3 %**.

**Références :** Survivor.io & Archero (Habby) — double-monnaie + gacha équipement ; GameAnalytics/Adjust/AppMagic ; SDK **AdMob / AppLovin MAX + médiation dès le début**.

**Pièges :** interstitiels en plein combat (rage-quit) ; gacha opaque (**odds à afficher**, risque légal UE loot box) ; pay-to-win précoce ; monétiser avant D1/D7 sains ; hard-gate d'énergie punitif ; **économie codée en dur** → utiliser des `Resource` Godot data-driven pour tuner sans rebuild.

### 8. Rétention & engagement / LiveOps (dailies, missions, events, push, design de session)

**Questions précises**
- Quels **D1/D7/D30** viser au lancement vs « bon » niveau ?
- **Durée de run** idéale et **sessions de combien de runs** ?
- Combien de **systèmes de progression parallèles** avant fatigue cognitive ?
- Quel **rythme de reward journalier** maximise la D7 sans griller l'économie ?
- **Push notifications** : lift de rétention réaliste ?

**Benchmarks à vérifier**
- Cible **D1 35-45 %, D7 12-18 %, D30 5-8 %**.
- Runs **8-15 min**, sessions de **2-4 runs**.
- **3-4 systèmes parallèles max** (méta-upgrades, déblocage persos/armes, collection, pass).
- Daily login streak 7 jours + récompense finale forte ; **~40-50 % des churners D1 récupérables** via 1 push calibré à H+24 ; push : **lift D7 +3 à +10 %** si opt-in propre.

**Références :** Survivor.io (event calendar, tech-parts), Archero (énergie + daily + push), VS/20MTD (déblocages en cascade / dopamine de collection), GameAnalytics/deltaDNA.

**Pièges :** énergie punitive qui bride le F2P solo ; trop de systèmes dès le D1 (onboarding progressif) ; dailies déconnectés du gameplay (donner des ressources **utiles à la méta**) ; push spam = uninstall (**1/jour max, contextualisé**) ; runs trop longues sur mobile (prévoir pause/reprise) ; **LiveOps data-driven réutilisables (config JSON)**, pas de contenu manuel lourd.

### 9. Technique & shipping (export Godot 4.3 Android, perf/pooling, APK, store, SDK, RGPD)

**Questions précises**
- Combien d'**entités animées simultanées** Godot 4.3 tient à 60 FPS sur mid-range 2021 (Snapdragon 6xx) ? **Seuil de bascule vers `MultiMeshInstance2D`** ?
- **`.aab` obligatoire ?** Taille max de download avant Play Asset Delivery ?
- Quel **plugin de médiation pub** a un binding Godot 4.3 **maintenu en 2026** (AdMob / AppLovin MAX / LevelPlay) ?
- Renderer **Mobile vs Compatibility** (Vulkan/GLES3) sur GPU bas de gamme ?

**Benchmarks à vérifier**
- 60 FPS avec **200-400 ennemis + 500+ projectiles** ; draw calls **< ~150**.
- APK/AAB **< 60-80 Mo** (limite psychologique d'install).
- Compression texture **ASTC/ETC2**, atlas de sprites 4-directions.

**Références :** docs Godot « Optimization using MultiMeshes », `visible_on_screen_notifier`, physics layers ; talks GodotCon perf mobile ; Play Console Data Safety ; Google UMP SDK ; ASO (fiches VS/Survivor.io/Archero).

**Pièges :** **keystore upload perdu = compte de publication mort** (sauvegarder + Play App Signing) ; target SDK non à jour → rejet ; formulaire Data Safety incohérent → suspension ; `queue_free`/instanciation non poolée → spikes GC/stutter (bannir en boucle chaude) ; interstitiels agressifs tuant la D1 ; pub sans **consentement UMP/CMP** = non-conformité RGPD.

---

## D) DEMANDES EXPLICITES

Pour l'ensemble, fournis obligatoirement :

1. **Benchmarks chiffrés** — valeurs par métrique (rétention, ARPDAU, eCPM, CPI, FPS, durées, counts de contenu), avec **fourchettes, source et date**, et distinction **Tier-1 / Tier-3** quand pertinent. Signale les chiffres que tu n'as pas pu vérifier.
2. **Jeux à décortiquer** — pour Vampire Survivors, Survivor.io, Archero, 20 Minutes Till Dawn, Brotato, Halls of Torment (+ Soul Knight / Death Must Die / HoloCure si utile) : **ce qu'ils font, pourquoi ça marche, et ce qui est transposable** au projet compte tenu des contraintes (solo, pipeline sprite 4-dir, Godot mobile).
3. **Recommandations concrètes classées par PRIORITÉ / IMPACT** — chaque reco = action précise + impact attendu (métrique visée) + **coût/effort estimé (S/M/L)** + **fit avec les contraintes** (pipeline sans GPU, data-driven Godot, dev solo). Marque explicitement les recos **spécifiques au MVP actuel** (ex : rendre les 8 biomes gameplay-différenciants, brancher Overdrive sur une boucle de récompense claire, ajouter archétypes tank/swarm/split par recombinaison, cap 6 armes, télégraphie des évolutions).
4. **FEUILLE DE ROUTE d'amélioration** en phases :
   - **Phase 0 – Ship** (build Android/keystore/Data Safety, pooling/perf 60 FPS, médiation pub minimale, FTUE 90 s).
   - **Phase 1 – Rétention** (méta ≤ 20-30 %, dailies utiles, déblocages en cascade, 1 push H+24).
   - **Phase 2 – Monétisation** (rewarded revive/double-loot, remove-ads, starter pack, économie data-driven).
   - **Phase 3 – Contenu & LiveOps** (armes évolutives, boss cadencés, events JSON réutilisables, soft-launch chiffré Tier-3 avant scaling UA/ASO).
   Pour chaque phase : objectifs, livrables, **KPI de sortie** (gate quantifié) et risques.

---

## E) FORMAT DE SORTIE ATTENDU

- **Markdown propre**, titres/sous-titres, listes à puces, **ton direct**, dense, **zéro remplissage**.
- **Une section par domaine** (ordre ci-dessus), chacune terminée par un encadré **« Reco prioritaires (Impact / Effort) »**.
- **Tableaux** pour : (a) benchmarks chiffrés par métrique et par jeu/géo ; (b) matrice de priorisation **Impact × Effort** de toutes les recos ; (c) budget de contenu minimum au lancement (ennemis/armes/persos/biomes/évolutions) ; (d) plan de monétisation (placements ads, IAP, prix).
- **Listes priorisées** (P0/P1/P2) et **feuille de route en phases** avec KPI-gates.
- **Sources citées** (SensorTower/data.ai, GameAnalytics, Adjust/AppsFlyer, Deconstructor of Fun, docs Godot/Play Console) avec date ; **distinguer clairement fait vérifié vs estimation**.
- Terminer par un **« TL;DR — 10 actions à plus fort impact »** exécutables par un dev solo dans les 90 prochains jours.