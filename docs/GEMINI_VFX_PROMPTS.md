# Prompts Gemini — effets spéciaux pour le jeu (+ vérité technique)

## ⚠️ À lire d'abord — ce que Gemini peut et ne peut pas
Gemini/Nano Banana génère des **images fixes**, pas des animations. Pour un VFX de jeu il faut une
**séquence de frames cohérente** — ce qu'un modèle texte→image ne garantit pas (chaque frame est
tirée indépendamment → ça scintille).

**Deux usages réalistes de Gemini ici :**
1. **Planche de sprites tentée en une image** (une bande horizontale de N vignettes). Nano Banana 3
   sait parfois le faire proprement, mais c'est un **pari** : si les frames ne s'enchaînent pas,
   c'est inutilisable.
2. **Une belle image "héro" fixe** d'un effet (splash art, texture de particule) → utile comme
   référence ou comme texture unique.

**La voie fiable, gratuite, déjà prouvée** = **procédural** (`tools/vfx_showcase.py`, 20 effets
générés). Si une planche Gemini rate, je refais l'effet en procédural à l'identique de l'intention.

---

## Modèle de prompt "planche de sprites" (à réutiliser pour CHAQUE effet)

```
A horizontal sprite sheet animation strip of <EFFET>, exactly <N> frames in a single row, left to
right, showing the full life cycle from birth to fade-out. Each frame the same size, evenly spaced,
same centered position. Pure solid BLACK background (for additive blending in-game). Bright glowing
<COULEUR> effect, no character, no object, no text, no grid lines, no numbers, no border.
Consistent style across all frames, smooth progression between frames. Game VFX, top-down view.
```
Remplace `<EFFET>`, `<N>` (8 à 16), `<COULEUR>`. **Contrôle** : les frames doivent se suivre (une
grossit/s'estompe régulièrement) ; sinon → régénère, ou je le fais en procédural.

---

## La longue liste d'effets (par usage dans le jeu)

### 🔫 Tir & armes
- Flash de bouche (autocanon) — jaune-blanc, court, dirigé
- Flash de bouche (plasma) — cyan, plus rond
- Départ de railgun — trait blanc + onde de recul
- Traçante / balle en vol — étirée, cœur blanc
- Tir chargé qui se libère — orbe qui gonfle puis éclate
- Éjection de douille + fumée au canon
- Onde de tir de gros calibre — anneau au canon

### 💥 Impacts & mort
- Impact de balle sur blindage — étincelle sèche
- Impact critique — éclat vif + rayons
- Impact perçant (railgun) — lance de lumière traversante
- Explosion d'ennemi (petit) — bouffée + débris
- Explosion d'ennemi (lourd) — boule de feu + fumée
- Explosion de boss — nova + onde de choc + éclats
- Désintégration énergétique — pixels/particules qui s'envolent
- Éclaboussure d'énergie sur bouclier — ondulation hexagonale

### ⚡ Élémentaire
- Éclair en chaîne — arcs dentelés qui sautent
- Décharge électrique de zone — dôme crépitant
- Explosion de givre — pics cristallins + éclats bleus
- Sol gelé — plaque de glace qui se forme
- Traînée de feu / mur de flammes — nappe ondulante
- Coulée de lave / éruption — jet orange (déjà un hazard volcan)
- Nuage toxique / poison — volute verte bouillonnante
- Tempête de sable — voile ocre en mouvement

### 🔮 Magie & pouvoirs
- Cercle runique d'invocation — anneau + graduations en rotation
- Portail qui s'ouvre — spirale + flash
- Aura de puissance (overdrive) — flammes d'énergie montantes
- Bouclier qui se lève — dôme translucide qui apparaît
- Bouclier qui casse — éclats de verre énergétique
- Onde de choc de saut / dash — anneau au sol
- Champ de ralentissement — grille pulsée au sol
- Marque de mort / cible verrouillée — réticule qui se resserre

### ✨ Ramassage & récompense (déjà partiellement en jeu)
- Gemme d'XP qui scintille — pulsation
- Absorption de gemme (aimant) — traînée vers le joueur
- Soin — croix vertes montantes + halo
- Cellule d'overdrive — étincelle ambre
- Montée de niveau — explosion dorée + étoiles montantes
- Ouverture de coffre — rayons + éclat
- Emoji rigolo qui pop — déjà fait (sprites emoji)

### 🌍 Ambiance & décor
- Poussière au sol quand le mecha marche
- Étincelles de propulseur (jet arrière)
- Fumée de décombres (caisse cassée)
- Geyser de vapeur — colonne blanche
- Nuée de particules flottantes (ambiance biome)
- Reflet/scintillement sur la glace

### 🖥️ Digital / UI
- Glitch holographique — scanlines + décalage RVB
- Téléportation (intro de vague) — dématérialisation
- Verrouillage de ciblage — carré qui s'anime
- Alerte "boss" — bandeau qui pulse

---

## Recommandation
Pour une **longue liste** comme celle-ci, le procédural est bien plus rentable : je peux en fabriquer
**10-20 d'un coup**, gratuits, cohérents, paramétrables, exactement au format du jeu — c'est ce que
le showcase a démontré. Utilise les prompts Gemini surtout si tu veux un **look peint très
spécifique** sur un effet précis (et accepte le pari de la cohérence des frames).

Livraison des planches Gemini : `refs/vfx_gemini/<nom>.png`. Je découpe (largeur/hauteur = N frames)
et j'importe. Sinon, dis-moi les effets voulus et je les sors en procédural.
