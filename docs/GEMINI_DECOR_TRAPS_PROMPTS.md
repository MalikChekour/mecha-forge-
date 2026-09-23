# Prompts Gemini (Nano Banana) — Décor & Pièges MECHA-FORGE (série 2)

**But** : une boîte à outils de prompts prêts à l'emploi pour générer de nouveaux sprites,
**qualitativement au niveau de la première série** (g20–g36, encore en jeu). Deux usages :
**décorer** les biomes (remplacer la variété supprimée) et **poser des pièges** câblés sur les
mécaniques déjà codées (rayon traversant, balise à ennemis, explosion, tourelle, geyser).

## Mode d'emploi (identique à la série 1)
1. Génère **une image carrée** (1:1, 1024² ou plus) par prompt dans Nano Banana.
2. Dépose les PNG dans `mecha-forge/refs/decor_gemini/` nommés par le **code** (`T1.png`, `D_ice1.png`…).
3. Je détoure le fond uni, recadre, importe, et câble (semis par biome ou fonction de piège).

## Consigne de STYLE — À COLLER À LA FIN DE CHAQUE PROMPT
> *vue de dessus 3/4 (caméra ~55° au-dessus de l'horizon), asset de jeu sci-fi stylisé-réaliste,
> éclairage clé zénithal dramatique + léger contour cyan, surfaces dures nettes et détaillées,
> UN SEUL objet centré et isolé, sur un fond UNI plat d'une seule couleur nette bien contrastée
> (ni dégradé, ni sol, ni ombre portée sur le fond, ni décor autour), pas de texte, haute
> définition, cohérent avec un jeu de mecha survivor sombre.*

> ⚠️ Pour les **pièges**, garde la couleur d'accent lisible et **distincte des tirs du joueur
> (cyan/violet) et des ennemis (orange/rouge)** : privilégie le **magenta**, le **jaune électrique**
> ou le **vert-acide** pour l'énergie hostile-neutre, afin qu'on repère le danger dans la mêlée.

---

## A. PIÈGES ACTIFS (câblés sur une mécanique de jeu)

**T1 — Capaciteur à rayon** *(mécanique : balaye un rayon traversant, dégâts aux deux camps)*
> Un capaciteur d'arène sci-fi menaçant, haute bobine Tesla trapue cerclée d'anneaux conducteurs, arcs de foudre **magenta** crépitant en haut, base blindée lourde boulonnée au sol, deux émetteurs latéraux prêts à décharger. [+ consigne de STYLE]

**T2 — Balise d'invocation** *(mécanique : crache des ennemis jusqu'à destruction)*
> Une balise de ralliement ennemie sci-fi, mât noir hérissé d'antennes, halo **rouge** pulsant au sommet, sas d'éjection ouvert d'où sort une lueur menaçante, feux rouges clignotants, socle industriel sale. [+ consigne de STYLE]

**T3 — Pylône à arc électrique** *(mécanique : foudroie les ennemis proches, EMP si détruit)*
> Un pylône électrique sci-fi haute tension, isolateurs en céramique, sphère plasma **jaune électrique** au sommet, câbles épais qui pendent, arcs qui sautent vers le sol, structure en treillis métallique. [+ consigne de STYLE]

**T4 — Émetteur de champ de ralentissement** *(mécanique : zone qui englue joueur et ennemis)*
> Un émetteur de champ gravitationnel sci-fi, disque parabolique tourné vers le ciel, cœur **violet** ondulant, trois pieds hydrauliques, ondes de distorsion visibles autour de l'antenne. [+ consigne de STYLE]

**T5 — Mine de proximité** *(mécanique : s'arme quand tu ralentis près, puis explose)*
> Une mine de proximité sci-fi posée au sol, dôme métallique bas hérissé de capteurs, diode d'armement **rouge** clignotante au centre, picots de contact, aspect trapu et discret. [+ consigne de STYLE]

**T6 — Réservoir explosif** *(mécanique : explose au contact, dégâts de zone)*
> Un réservoir de carburant volatile sci-fi bombé, cuve métallique bosselée avec bandes d'avertissement **jaunes et noires**, jauge de pression dans le rouge, valves fuyantes, une étincelle près du bouchon. [+ consigne de STYLE]

**T7 — Tourelle hostile lourde** *(mécanique : tire dans son cône)*
> Une tourelle de défense automatisée sci-fi encore en ligne, double canon gatling, plaque de blindage frontale ébréchée, œil-capteur **rouge** allumé, socle rotatif boulonné, munitions apparentes. [+ consigne de STYLE]

**T8 — Geyser d'énergie** *(mécanique : éruptions verticales télégraphiées)*
> Une bouche d'éruption sci-fi encastrée dans le sol, anneau de buses métalliques, lueur **orange** montant des profondeurs, vapeur et braises qui s'échappent des fentes, cerne de roche brûlée. [+ consigne de STYLE]

**T9 — Lame rotative** *(mécanique : lame qui tourne sur un rayon fixe, dégâts au contact)*
> Un piège à lame circulaire sci-fi, disque-scie cranté **acier bleuté** monté sur un moyeu central bas, traînée lumineuse **cyan** sur le tranchant, ancrage industriel au sol, aspect mécanique brutal. [+ consigne de STYLE]

**T10 — Diffuseur de spores toxiques** *(mécanique : nuage qui masque et blesse dans un rayon)*
> Un diffuseur alien organique-métallique, bulbe charnu **vert-acide** translucide qui pulse, évents crachant une brume verte lumineuse, tiges tendineuses ancrées au sol, veines phosphorescentes. [+ consigne de STYLE]

---

## B. ENRICHISSEURS DE BIOME (remplacent la variété supprimée)

**D_earth1 — Rocher fissuré (Friche)**
> Un gros rocher gris fracturé aux arêtes vives, veine de minerai sombre, éclats de pierre au pied, mousse rare dans les fissures. [+ consigne de STYLE]

**D_earth2 — Souche calcinée (Friche)**
> Une grosse souche d'arbre alien calcinée, bois noirci craquelé, racines noueuses exposées, quelques braises éteintes. [+ consigne de STYLE]

**D_ice1 — Bloc de glace fracturé (Glace)**
> Un bloc de glace bleu-blanc translucide fracturé en biseaux nets, reflets givrés, éclats gelés à la base, cœur légèrement lumineux. [+ consigne de STYLE]

**D_ice2 — Épave gelée (Glace)**
> Une carcasse de machine sci-fi prise dans la glace, plaques d'armure givrées, stalactites de glace pendantes, une diode faible encore bleue sous le givre. [+ consigne de STYLE]

**D_jungle1 — Champignon géant (Jungle/Marais)**
> Un grand champignon alien, chapeau charnu **turquoise lumineux** veiné, pied épais tacheté, spores en suspension, lueur douce sous le chapeau. [+ consigne de STYLE]

**D_jungle2 — Fougère bioluminescente (Jungle)**
> Une touffe de fougères aliens denses, frondes vert sombre aux nervures **cyan lumineuses**, gouttes de sève phosphorescente, base humide. [+ consigne de STYLE]

**D_swamp1 — Souche à mangrove (Marais)**
> Un enchevêtrement de racines de mangrove alien émergeant d'une boue noire luisante, écorce humide, petits feux follets **verts** entre les racines. [+ consigne de STYLE]

**D_volcanic1 — Cheminée de basalte (Volcan)**
> Une cheminée de roche basaltique noire en colonnes hexagonales, fissures rougeoyantes de lave **orange**, croûte craquelée, chaleur ondulante. [+ consigne de STYLE]

**D_desert1 — Mesa érodée (Désert)**
> Un piton de grès ocre stratifié sculpté par le vent, strates nettes, sable accumulé au pied, silhouette solide et compacte. [+ consigne de STYLE]

**D_tech1 — Bloc serveur (Tech/Vaisseau)**
> Une baie de serveurs sci-fi compacte, rangées de diodes **cyan** clignotantes derrière une grille sombre, câbles ordonnés, panneaux hard-surface, boîtier industriel. [+ consigne de STYLE]

**D_tech2 — Conduit d'énergie coudé (Tech/Vaisseau)**
> Un gros conduit d'énergie sci-fi coudé au sol, tuyaux métalliques épais avec veine d'énergie **cyan** qui court à l'intérieur, brides boulonnées, vapeur d'échappement. [+ consigne de STYLE]

---

## C. MURS & GRANDES FORMATIONS (bordure d'arène bornée)

> L'arène est désormais **fermée par un anneau d'éléments naturels**. Ces gros props servent de
> mur de bordure : massifs, hauts, opaques, sans ouverture qu'on voit à travers.

**F1 — Falaise rocheuse (bordure Friche/Désert)**
> Un pan de falaise rocheuse imposant et massif, blocs empilés multi-facettes, arêtes tranchantes, ombres profondes, aucun trou, échelle monumentale, base d'éboulis. [+ consigne de STYLE]

**F2 — Crête de glace (bordure Glace)**
> Une haute crête de glace compacte bleu-blanc, pics serrés soudés en un mur continu, reflets givrés, aucune transparence traversante, base neigeuse. [+ consigne de STYLE]

**F3 — Rempart de ruines robotiques (bordure Ruines/Tech)**
> Un rempart de débris de guerre robotique entassés, carcasses de machines empilées et soudées par la rouille, plaques d'armure tordues formant un mur plein, quelques diodes mortes. [+ consigne de STYLE]

**F4 — Mur de basalte volcanique (bordure Volcan)**
> Un mur de roche volcanique noire massive, colonnes de basalte serrées, veines de lave **orange** dans les fissures, croûte fumante, silhouette continue et infranchissable. [+ consigne de STYLE]

---

## D. OBJECTIFS & BONUS (structures à interagir)

**O1 — Pylône de surcharge** *(mécanique possible : buff de cadence dans un rayon)*
> Un pylône d'amplification sci-fi bienveillant, colonne élancée couronnée d'un anneau d'énergie **cyan** stable, glyphes lumineux qui montent le long du fût, socle propre et high-tech. [+ consigne de STYLE]

**O2 — Cache blindée** *(mécanique possible : coffre à casser pour une grosse récompense)*
> Un coffre-fort d'armement sci-fi trapu, blindage épais rivé, serrure à diodes **dorées**, poignée renforcée, marquages de cargaison précieuse, aspect « à forcer ». [+ consigne de STYLE]

**O3 — Capsule de stase** *(mécanique possible : libère un allié/gardien à l'ouverture)*
> Une capsule cryogénique sci-fi verticale, vitre givrée laissant deviner une silhouette dormante, halo **cyan** froid, tubes et jauges sur les flancs, base lourde. [+ consigne de STYLE]

---

### Astuce qualité (série 1, toujours valable)
- **Même fond uni** sur toutes les générations → détourage homogène.
- Si trop « photo réaliste » → ajoute *« style jeu vidéo stylisé, pas photoréaliste »*.
- Génère **2 variantes** des rochers/cristaux/glace → casse la répétition en jeu.
- **1024² minimum**, je réduis ensuite.
- Pour un **piège**, pense à sa lecture en mêlée : silhouette claire + accent de couleur réservé.
