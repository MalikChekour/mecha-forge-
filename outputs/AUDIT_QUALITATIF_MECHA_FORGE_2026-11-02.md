# Audit qualitatif et technique — MECHA-FORGE

Date : 2 novembre 2026  
Périmètre : architecture Godot, boucle de jeu, combat, ennemis, progression, économie, interface, zone de réduction, performance et QA.  
Méthode : lecture du code et des journaux présents dans le projet, sans modification du gameplay pendant l’audit.

## 1. Diagnostic exécutif

MECHA-FORGE possède déjà une base nettement supérieure à un prototype : plusieurs châssis, un arsenal différencié, des évolutions et fusions, des boss, des biomes, une progression méta, des quêtes quotidiennes, de l’équipement, un mode sans fin, un HUD, des effets et des tests dédiés. Le projet contient environ 4 100 fichiers d’assets pour environ 413 Mo, 39 scripts GDScript à la racine/structure principale et plusieurs milliers de lignes de gameplay.

Le risque principal n’est donc plus le manque de contenu. C’est la cohérence de l’expérience : le joueur doit comprendre ce qui est important, sentir une montée en puissance lisible, prendre des décisions significatives et toujours savoir pourquoi il est mort ou pourquoi une amélioration est bonne.

Ma recommandation centrale est de passer d’une logique « ajouter des systèmes » à une logique « renforcer trois piliers » :

1. **Combat lisible et satisfaisant** : viser, toucher, esquiver, choisir une cible et comprendre les dégâts.
2. **Décisions de build** : chaque niveau doit provoquer un vrai choix, avec des armes et châssis réellement différents.
3. **Pacing maîtrisé** : la pression doit monter régulièrement sans alternance entre écran vide et mur d’ennemis.

## 2. Forces actuelles à préserver

### Combat et build

- Le plafond de 6 actifs et 6 passifs est une bonne direction : il redonne de la valeur au draft.
- Les arsenaux propres à chaque châssis sont plus intéressants qu’un pool universel.
- Les évolutions et fusions donnent des objectifs à moyen terme.
- La visée automatique a déjà reçu une stabilisation, ce qui va dans le bon sens pour mobile.
- Les ennemis sont organisés par rôles et paliers plutôt que par simples sacs à PV.

### Pacing et performance

- Le spawner possède déjà un plancher de population et une protection contre les vagues trop brutales.
- Les vagues sont drainées sur plusieurs frames, ce qui évite le pic de création d’une horde entière en une frame.
- L’existence d’un object pool et de tests headless constitue une bonne base pour le Web et le mobile.
- La zone de confinement est maintenant planifiée sur quatre phases pour une run d’environ 15 minutes.

### Persistance

- `SaveManager` possède un schéma, une migration et des valeurs par défaut.
- Les monnaies sont séparées et les récompenses sont reliées à la durée/au score, ce qui limite le farm par suicide instantané.
- Les données importantes sont centralisées dans `GameState` plutôt que dispersées dans chaque scène.

## 3. Problèmes prioritaires

### P0 — Risque d’expérience : trop de systèmes visibles trop tôt

Le projet combine châssis, armes, passifs, évolutions, fusions, surcharge, aimant, équipement à quatre slots, raretés, noyaux, cristaux, compétences méta, chapitres, difficultés, quêtes, récompenses quotidiennes et mode sans fin. Individuellement, chaque système est défendable. Ensemble, ils peuvent rendre les premières parties illisibles.

**Solution proposée : parcours en trois actes.**

- Partie 1 : un châssis, trois cartes de niveau, aucune monnaie secondaire affichée.
- Partie 2 : présentation du second châssis et des évolutions.
- Partie 3 : déverrouillage progressif de l’équipement, des quêtes et du mode sans fin.

Le joueur doit toujours savoir : « quel est mon objectif maintenant ? », « quelle récompense vais-je obtenir ? » et « quelle décision change mon build ? ».

### P0 — Pacing encore fragile

Les propres commentaires de `EnemySpawner.gd` signalent une ancienne alternance entre écrans presque vides et murs d’ennemis. Le plancher de population améliore la situation, mais une formule de spawn seule ne garantit pas une bonne sensation.

**Solution proposée : piloter la pression par budget de menace.**

Définir pour chaque tranche de 10 secondes un budget : nombre d’ennemis, valeur de menace, nombre de rôles spéciaux et densité maximale à l’écran. Le spawner dépense ce budget au lieu de seulement réduire un délai de spawn.

Mesures à enregistrer :

- ennemis vivants par seconde ;
- dégâts reçus par tranche de 10 secondes ;
- temps sans ennemi à portée ;
- temps avec plus de 80 % du cap ennemi ;
- nombre d’apparitions à moins de 420 unités ;
- cause de mort et seconde exacte.

Cibles initiales à tester, pas à imposer définitivement : moins de 8 % du temps totalement vide et moins de 3 % au-dessus de 90 % du cap hors événement boss.

### P0 — Zone de réduction : bonne direction, mais décision stratégique insuffisante

L’`ArenaWall` affiche une zone, inflige des dégâts et se réduit en quatre phases. Toutefois, le centre se recentre vers le joueur pendant le début d’une phase. Cela protège la lisibilité, mais diminue le choix stratégique : le joueur n’a pas réellement à lire la carte et à se repositionner vers une nouvelle zone sûre.

**Amélioration recommandée en deux étapes :**

1. Conserver la version actuelle pour vérifier que les dégâts, la visibilité et le mobile sont corrects.
2. Ensuite, introduire un centre cible annoncé à l’avance : marqueur de destination, flèche de direction et compte à rebours de 20 à 30 secondes. Pendant la réduction, le centre se déplace vers cette destination, pas directement vers le joueur.

Éviter une téléportation ou un clamp instantané. Une courte tolérance de 1 à 2 secondes puis des dégâts progressifs sont plus justes qu’un déplacement forcé brutal.

### P0 — Mort et feedback

Le joueur dispose de nombreux effets, ennemis et sources de dégâts. Une mort doit cependant être explicable en moins de deux secondes.

À ajouter :

- source principale du dernier coup ;
- dégâts reçus dans les 3 dernières secondes ;
- indication claire « hors zone », « contact », « projectile », « surcharge » ou « boss » ;
- journal temporaire très court, activable dans les options ;
- écran de défaite qui propose une seule recommandation, pas une liste de statistiques.

## 4. Combat et sensations

### Visée

La stabilisation de cible automatique est pertinente. Il faut maintenant séparer clairement trois concepts : cible du réticule, cible du tir et cible de l’homing. Ils peuvent être proches mais ne doivent pas diverger sans indication visuelle.

Recommandation : afficher une petite différence visuelle entre verrouillage automatique et visée manuelle, puis appliquer une hystérésis commune aux trois systèmes. Le joueur doit comprendre pourquoi un missile choisit une cible différente d’un tir direct.

### Armes

Chaque arme doit répondre à une question différente :

- autocanon : pression constante et fiable ;
- railgun : alignement et pénétration ;
- plasma : contrôle de zone ;
- sabre : prise de risque à courte portée ;
- missiles : suivi et préparation ;
- faisceau : maintien de ligne et choix de direction.

Si deux armes ont le même résultat malgré des animations différentes, il faut revoir leur profil, pas seulement leur couleur ou leurs dégâts.

### Ennemis

Les rôles sont une bonne base. Chaque ennemi spécial doit avoir :

1. une silhouette reconnaissable ;
2. une intention lisible ;
3. un télégraphe avant l’attaque ;
4. une réponse possible pour le joueur ;
5. une récompense ou une raison de le prioriser.

Un ennemi qui ne change que les PV et la vitesse ne constitue pas un nouveau choix tactique.

## 5. Progression et draft

Le draft à trois cartes, les plafonds d’actifs/passifs et la garantie d’évolution sont de bonnes décisions. Le risque est que la garantie d’évolution transforme certains niveaux en résultat obligatoire.

Je recommande :

- garantir une évolution seulement lorsque ses conditions sont remplies depuis un certain temps, pas immédiatement au premier niveau suivant ;
- afficher « ce que vous perdez » lors d’une fusion ou d’un remplacement ;
- afficher le prochain palier sous forme de résultat concret : rayon, cadence, portée, nombre de cibles, pénétration ;
- conserver au moins une carte de secours réellement utile quand le joueur a déjà atteint les plafonds ;
- mesurer le taux de choix de chaque carte et le taux d’abandon de chaque arme.

Un bon draft ne cherche pas seulement à donner trois cartes valides. Il doit produire trois options raisonnables mais incompatibles à court terme.

## 6. Économie et rétention

L’économie comprend scrap, skill points, cristaux, noyaux, pièces, équipement, raretés, quotidien et publicité/IAP dans les commentaires de conception. Cela crée un risque de fragmentation de la valeur.

Priorité : réduire l’économie visible à deux monnaies pendant les premières heures :

- une monnaie de progression permanente ;
- une monnaie d’équipement avancé.

Les autres ressources peuvent exister en interne mais ne doivent pas toutes être présentées en même temps. Chaque monnaie doit avoir une source, un usage et un plafond compréhensibles.

La progression méta doit rester sous le plafond annoncé d’environ +30 %. Il faut le vérifier par simulation sur plusieurs builds, car une combinaison de vitalité, dégâts, vitesse, équipement et châssis peut dépasser largement ce plafond en pratique.

## 7. Architecture et dette technique

`Game.gd` est devenu un orchestrateur très volumineux. Il contient à la fois menu, lancement de run, biome, draft, upgrade, FX, HUD, score, debug et transitions. Cette centralisation aide au prototype mais augmente fortement le risque de régression.

Refactorisation recommandée, sans réécriture globale :

- `RunDirector` : durée, victoire, défaite, phases et transitions ;
- `SpawnDirector` : budget de menace, vagues, bosses ;
- `BuildDirector` : cartes, slots, évolutions, fusions ;
- `Telemetry` : métriques de partie et export JSON ;
- `PresentationBus` : bannières, sons, vibrations, flashes ;
- `SaveManager` : uniquement persistance et migration.

Commencer par extraire la télémétrie et le draft, qui sont des blocs relativement autonomes. Ne pas faire un grand refactor avant d’avoir des tests de non-régression.

Les fichiers de sauvegarde et backups présents dans l’arborescence doivent aussi être clairement exclus de l’export et du chargement runtime quand ils ne sont pas nécessaires.

## 8. Performance et plateforme

Le volume d’assets est élevé pour une cible Web/mobile. Il faut mesurer plutôt que supposer.

Plan de validation :

- profilage avec 20, 40, 60 et 90 ennemis ;
- test sur écran mobile étroit ;
- vérification de la mémoire après 15 minutes ;
- comparaison avec et sans particules/FX ;
- comptage des allocations par seconde ;
- test de reprise après pause et perte de focus ;
- test tactile avec pouces, orientation et safe areas.

Les appels répétés à `get_nodes_in_group()` dans les chemins chauds doivent être remplacés progressivement par des registres ou caches invalidés à la création/destruction. Le cache existant pour la cible proche est une bonne direction, mais il faut l’appliquer aux autres requêtes fréquentes.

## 9. QA indispensable

Les tests existants doivent évoluer d’une validation « le jeu démarre » vers des tests de scénarios reproductibles.

Créer des seeds fixes pour :

- départ sans upgrade ;
- build mêlée ;
- build à projectiles ;
- zone finale ;
- boss et transition ;
- mort hors zone ;
- fusion d’armes ;
- sauvegarde ancienne migrée ;
- reprise après pause ;
- mode sans fin.

Pour chaque seed, conserver : durée, niveau, kills, dégâts, choix de cartes, cause de mort, nombre d’ennemis maximum, FPS minimum et erreurs Godot.

## 10. Feuille de route recommandée

### Lot 1 — Qualité perçue et sécurité

1. Ajouter le résumé de cause de mort.
2. Stabiliser l’UI de zone : compte à rebours, distance, direction, danger.
3. Vérifier les dégâts et la réduction sur mobile.
4. Ajouter une télémétrie locale légère.
5. Corriger les régressions du script Player et valider dans Godot.

### Lot 2 — Pacing

1. Remplacer progressivement le délai de spawn par un budget de menace.
2. Ajuster les vagues à partir de métriques réelles.
3. Introduire des fenêtres de respiration volontaire après les boss.
4. Éviter les empilements simultanés zone + horde + projectile + boss sans télégraphe.

### Lot 3 — Décisions de build

1. Revoir les cartes les moins choisies.
2. Donner une identité mécanique forte aux armes proches.
3. Afficher les conséquences des évolutions et fusions.
4. Tester les plafonds actifs/passifs sur 20 seeds par difficulté.

### Lot 4 — Architecture

1. Extraire Telemetry.
2. Extraire BuildDirector.
3. Ajouter des tests de contrat pour SaveManager.
4. Réduire progressivement la taille de Game.gd.

## 11. Verdict

Le projet ne doit pas recevoir davantage de contenu avant d’avoir consolidé sa lisibilité et son pacing. La meilleure amélioration qualitative n’est pas d’ajouter dix armes, cinq biomes ou une nouvelle monnaie : c’est de rendre les 15 premières minutes parfaitement compréhensibles, tendues et rejouables.

Ordre de priorité final :

1. cause de mort et feedback ;
2. zone progressive réellement stratégique ;
3. pacing contrôlé par budget de menace ;
4. draft plus décisionnel ;
5. simplification de l’économie visible ;
6. télémétrie et tests reproductibles ;
7. refactorisation progressive de `Game.gd`.
