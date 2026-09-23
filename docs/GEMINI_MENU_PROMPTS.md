# Prompts Gemini — Menu, Splash & Cinématique MECHA-FORGE

Key art **plein cadre** (pas des objets isolés). But : splash de chargement, fond de menu, emblème,
et les 6 panneaux de cinématique — **cohérents entre eux** et avec le héros déjà validé.

## 🔑 Astuce cohérence du héros (À FAIRE)
Pour que le mecha soit **le même partout** : dans Nano Banana, **joins l'image de référence du héros**
(`cine/hero_hq.png`) et ajoute à la fin de chaque prompt *« le mecha correspond à l'image de
référence »*. Sinon Gemini réinvente le mecha à chaque image.

## Consigne de STYLE — À COLLER À LA FIN DE CHAQUE PROMPT KEY ART
> *vue cinématique, jeu de mecha survivor sci-fi sombre, étalonnage cyan-et-orange (cyan froid sur
> le mecha et son énergie, orange chaud UNIQUEMENT dans le décor qui brûle), rendu stylisé-réaliste
> type concept art AAA, éclairage dramatique volumétrique, contraste élevé, grain de film, ultra
> détaillé, sans aucun texte.*

---

## 1 — SPLASH / écran de chargement  (format PORTRAIT 9:16)
> Un mecha de combat humanoïde solitaire, armure sombre balafrée par la guerre, cœur-réacteur cyan
> lumineux encastré dans la poitrine et visière cyan, se dresse au centre, imposant, sur un champ de
> bataille en ruine ; fumée épaisse et braises orange, rais de lumière perçant la brume, une horde
> de machines ennemies en silhouette au loin. Composition verticale héroïque, le mecha centré, avec
> de l'espace sombre dégagé en bas pour l'interface. [+ consigne de STYLE] — **format portrait 9:16**

## 2 — FOND DE MENU  (format PORTRAIT 9:16, plus calme)
> Le même mecha de combat au repos, vu de trois quarts sur le côté, dans une forge de mechas en
> ruine baignée d'une lueur cyan douce, quelques braises orange éparses, atmosphère posée et
> premium. Composition verticale avec un **tiers inférieur nettement plus sombre et dégagé** (pour
> poser les boutons du menu), peu d'éléments distrayants, profondeur de champ. [+ consigne de STYLE]
> — **format portrait 9:16**

## 3 — EMBLÈME de titre  (format CARRÉ, fond uni pour détourage)
> Un emblème métallique de faction « forge de mechas » : une enclume stylisée croisée d'un éclair
> d'énergie cyan, cerclée d'un anneau d'acier gravé, aspect insigne martelé et usé, légère lueur
> cyan. UN SEUL emblème centré, sur un fond UNI plat magenta vif (#FF00FF), sans dégradé ni ombre
> portée, sans texte. [+ consigne de STYLE] — **format carré 1:1**
>
> ⚠️ NE demande PAS le mot « MECHA-FORGE » à l'IA (elle déforme le texte). Le titre en lettres, je
> le poserai en police stylisée par-dessus l'emblème, dans le moteur.

---

## CINÉMATIQUE — 6 panneaux  (format PAYSAGE 16:9)

**4 — La guerre sans fin**
> Plan large. Une armée sans fin de machines de guerre et de robots hostiles avance à travers un
> monde dévasté vers l'horizon, ciel saturé de fumée orange, explosions lointaines, silhouettes de
> mechas ennemis jusqu'à l'horizon, échelle épique et menaçante. [+ consigne de STYLE] — **16:9**

**5 — La forge oubliée**
> Intérieur d'une forge de mechas en ruine, abandonnée et silencieuse ; un unique châssis de mecha
> humanoïde dormant, affaissé sous la poussière, câbles brisés qui pendent, faible lumière froide
> par un plafond effondré, braises d'un four éteint, ambiance mélancolique. [+ consigne de STYLE] — **16:9**

**6 — Le dernier pilote**
> Un pilote humain solitaire en combinaison usée se tient, tout petit, devant le mecha dormant
> imposant dans la forge en ruine, tendant la main vers le cockpit sombre ; contre-jour dramatique,
> poussière dans les rais de lumière, espoir et détermination. [+ consigne de STYLE] — **16:9**

**7 — Le réveil du noyau**
> Plan rapproché. Le cœur-réacteur du mecha se rallume d'une intense énergie cyan, la lumière jaillit
> par les jointures de l'armure, gerbe d'étincelles et de braises orange, l'énergie parcourt les
> conduits lumineux, bloom dramatique, instant de réveil puissant. [+ consigne de STYLE] — **16:9**

**8 — Seul contre la horde**
> Le mecha de combat, debout et prêt, cœur cyan rayonnant, sur un champ de bataille en ruine ; une
> énorme horde de machines ennemies en silhouette au loin dans la fumée, feux orange épars, posture
> héroïque déterminée. [+ consigne de STYLE] — **16:9**

**9 — La charge (final + titre)**
> Contre-plongée basse. Le mecha de combat charge en avant au sol (marcheur, pas de propulsion),
> cœur cyan éclatant, éclairs de bouche orange de son canon de bras droit, une horde de machines
> ennemies droit devant en silhouette, poussière et braises, apogée héroïque. [+ consigne de STYLE] — **16:9**

---

### Réglages Gemini
- Génère chaque image au **format indiqué** (9:16 splash/menu, 1:1 emblème, 16:9 cinématique).
- **Joins `cine/hero_hq.png` en référence** sur les images où le mecha apparaît (1, 2, 5→9).
- Dépose les résultats dans `mecha-forge/refs/menu/` nommés `splash.png`, `menu_bg.png`,
  `emblem.png`, `cine1.png`…`cine6.png` — je détoure/intègre ensuite.
- Si trop « photo réaliste » → ajoute *« style jeu vidéo stylisé, pas photoréaliste »*.
