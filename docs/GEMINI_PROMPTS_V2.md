# Prompts Gemini (Nano Banana 2) — V2 : héros à choisir + map "Ville en ruines" + décor

## Consigne de STYLE commune (déjà incluse à la fin de chaque prompt d'OBJET)
> *vue de dessus 3/4 (caméra ~55° au-dessus de l'horizon), asset de jeu sci-fi stylisé-réaliste
> peint à la main (pas photoréaliste), éclairage clé zénithal + léger contour cyan, surfaces
> nettes et détaillées, UN SEUL objet centré et isolé, sur un fond UNI plat d'une seule couleur
> nette bien contrastée (ni dégradé, ni sol, ni ombre portée, ni décor autour), pas de texte,
> haute définition, cohérent avec un jeu de mecha survivor sombre et post-apocalyptique.*

Dépose les objets dans `refs/decor_gemini/` en `dNN.png` (numéro), et le sol dans `refs/`.

---

# A. HÉROS — génère 3-4 designs, tu choisiras

Reprends le prompt de base (`GEMINI_HERO_PROMPT.md` : pose écartée, membres séparés, fond uni) et
change **juste la silhouette/couleur** pour obtenir des variantes à comparer :

- **h1 — Polyvalent** : *« armure bleu-acier et blanc, cœur réacteur cyan, proportions héroïques équilibrées »*
- **h2 — Agile/éclaireur** : *« mecha fin et léger, lignes aérodynamiques, orange et gris foncé, visière fine »*
- **h3 — Lourd/bruiser** : *« mecha massif et trapu, épaules énormes, blindage épais gris-bronze, cœur orange »*
- **h4 — Assassin/ninja** : *« mecha élancé noir mat et néon violet, silhouette furtive, lame d'énergie »*

→ Nomme-les `hero_h1.png` … `hero_h4.png` dans `refs/hero_gemini/`. Je découpe + rig celui que tu choisis.

---

# B. NOUVELLE MAP — "VILLE EN RUINES" (après la guerre des robots)

## B.1 — Le SOL (à mettre dans `refs/sol_ruines.png`)
> Texture de SOL vue **strictement de dessus** (plan zénithal), **carrelable sans couture (seamless
> tileable)**, d'une **rue de ville détruite après une guerre de robots** : asphalte et béton fissurés,
> marquages routiers effacés, plaques d'égout, **gravats et débris épars**, **traces de brûlure et de
> suie**, petites flaques sombres, éclats de verre, teinte gris-charbon froide avec quelques reflets
> orangés de rouille. Style jeu vidéo peint, sombre, haute définition, **PAS d'objet en relief, PAS de
> bâtiment** (juste le sol), sans texte, sans bordure, motif homogène qui se répète.

## B.2 — Le DÉCOR de la map (objets, `refs/decor_gemini/`)

**d37 — Immeuble détruit**
> Section d'un gratte-ciel sci-fi effondré, étages éventrés, poutres d'acier tordues, façade arrachée exposant l'intérieur, quelques vitres brisées, béton noirci. [+ STYLE]

**d38 — Pan de mur effondré**
> Un grand pan de mur de béton effondré avec des fers à béton (armatures) tordus qui dépassent, impacts de tir, gravats à la base. [+ STYLE]

**d39 — Vaisseau écrasé**
> Une navette/dropship militaire sci-fi écrasée au sol, à moitié enfoncée, coque déchirée, aile brisée, fumée éteinte, feux morts. [+ STYLE]

**d40 — Véhicule épave**
> Une voiture volante (hovercar) sci-fi carbonisée et retournée, carrosserie brûlée, vitres éclatées, rouille. [+ STYLE]

**d41 — Tas de gravats**
> Un gros tas de gravats de guerre : blocs de béton, ferraille, morceaux de mur, poussière, quelques câbles qui pendent. [+ STYLE]

**d42 — Pylône tordu**
> Un lampadaire / pylône électrique urbain tordu et penché, câbles arrachés qui pendent, une lumière cassée qui grésille faiblement. [+ STYLE]

**d43 — Panneau publicitaire ruiné**
> Un grand panneau d'affichage néon de ville à moitié détruit, écran fissuré et éteint, structure métallique tordue, quelques néons cyan qui clignotent encore. [+ STYLE]

**d44 — Barricade de guerre**
> Une barricade militaire de rue : sacs de sable empilés, plaques de blindage, herse anti-véhicule, marquages d'avertissement usés. [+ STYLE]

**d45 — Carcasse de robot de guerre**
> La carcasse d'un énorme robot de guerre abattu, à demi effondré sur le flanc, armure éventrée, membres arrachés, cœur réacteur éteint. [+ STYLE]

**d46 — Cratère d'explosion**
> Un cratère d'obus au sol vu de dessus, terre/béton retournés et noircis, débris projetés en étoile autour, braises mourantes. [+ STYLE]

---

# C. DÉCOR EN PLUS pour les maps existantes

**d47 — Geyser de lave (Volcan)**
> Une fissure volcanique crachant un jet de lave incandescente, roche basaltique noire craquelée autour, lueur orange intense. [+ STYLE]

**d48 — Champignon géant bioluminescent (Jungle)**
> Un grand champignon alien bioluminescent, chapeau turquoise lumineux veiné, pied épais, spores flottantes. [+ STYLE]

**d49 — Campement abandonné (Désert)**
> Un petit campement de survie abandonné : tente en toile déchirée battue par le vent, caisses, feu éteint, planté dans le sable ocre. [+ STYLE]

**d50 — Épave gelée (Glace)**
> Une épave de véhicule sci-fi recouverte de glace et de givre, stalactites de glace, coque bleutée figée. [+ STYLE]

**d51 — Baie de serveurs (Tech)**
> Une armoire/baie de serveurs sci-fi, rangées de diodes cyan clignotantes, câbles, panneaux ventilés, métal sombre. [+ STYLE]

**d52 — Capsule de sauvetage (Vaisseau)**
> Une capsule de sauvetage spatiale ouverte, hublot lumineux cyan, coque blanche et acier, trappe béante. [+ STYLE]

---

### Rappels
- **Même fond uni** partout (gris moyen ou magenta) → détourage régulier.
- Génère **2 variantes** des objets fréquents (gravats, immeuble, épave) pour éviter la répétition.
- 1024² ou plus. Dépose et dis-moi « ok » — je détoure, j'importe, j'ajoute la map "ruines" au jeu
  (nouveau biome + semis de décor cohérent) et je re-teste.
