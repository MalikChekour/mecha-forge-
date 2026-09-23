# Design — armes & économie de récompenses (recherché, à paramétrer)

Basé sur Vampire Survivors, Survivor.io, Brotato (les références du genre). Objectif : donner à
MECHA-FORGE la **vraie** boucle survivor-like, pas 4 armes qui tirent tout droit.

## LES 3 LOIS DU GENRE (ce que la recherche confirme)
1. **La variété vient de la FORME, pas des stats.** Une arme = une *silhouette de jeu* : tir droit,
   tête chercheuse, ligne perçante, zone, orbite, aura, piège au sol, arc de mêlée. Deux armes qui
   "font 20 dégâts tout droit" ne sont PAS de la variété.
2. **6 emplacements d'armes max** (VS = 6, Survivor.io = 6). La tension = choisir, pas tout prendre.
3. **L'évolution est le hook.** Arme au max **+** passif requis **+** coffre lâché par un élite/boss
   → l'arme se transforme en version "qui remplit l'écran". Survivor.io : niv.5 + passif + coffre
   doré de boss. VS : niv.8 + passif + coffre après 10 min. **On a déjà les élites (3/12 min) et les
   boss (5/10/15 min)** → il suffit de leur faire lâcher un **coffre**.

---

## 1. ROSTER D'ARMES proposé (on passe de 4 → 9 FORMES distinctes)

On a déjà 4 tirs droits + aura + drone codés. On promeut aura/drone en vraies armes et on ajoute
3 formes manquantes.

| # | Arme | Forme (unique) | On a ? |
|---|------|----------------|--------|
| 1 | **Autocanon** | tir droit rapide, faible | ✅ |
| 2 | **Missiles** | têtes chercheuses | ✅ |
| 3 | **Railgun** | ligne perçante | ✅ |
| 4 | **Plasma** | explosion de zone | ✅ |
| 5 | **Aura** | champ de dégâts autour de soi | ✅ (draftable → arme) |
| 6 | **Drones** | satellites qui orbitent + tirent | ✅ (draftable → arme) |
| 7 | **Sabre** | arc de mêlée qui balaie (on a le VFX slash !) | 🆕 |
| 8 | **Mines** | pièges au sol qui explosent au contact | 🆕 |
| 9 | **Boomerang** | projectile qui part et revient | 🆕 (option) |

**Paramétrage par arme** (grille survivor-like) : chaque arme monte **niveau 1→8**. À chaque niveau
on améliore UN axe (dégâts / cadence / nombre de projectiles / zone / durée). Barème type :
- niv 1 : base · niv 2-3 : +cadence · niv 4-5 : +projectiles/zone · niv 6-7 : +dégâts · niv 8 : MAX (débloque l'évolution).

## 2. PASSIFS (supports) — ce qui débloque les évolutions
On a : dégâts, vitesse, PV, hâte, crit, armure, aimant. On ajoute les passifs "génériques" du genre :
- **Zone** (+taille des effets), **Durée** (+persistance), **Nombre** (+1 projectile), **Vitesse projectile**.

## 3. ÉVOLUTIONS (arme MAX niv.8 + passif + coffre d'élite/boss)
On a déjà 4 recettes. On complète pour couvrir les 9 armes :
| Arme (max) | + Passif | → Évolution |
|---|---|---|
| Autocanon | Hâte | **Vulcan** (barrage) ✅ |
| Missiles | Crit | **Hydra** (essaim) ✅ |
| Railgun | Dégâts | **Annihilateur** ✅ |
| Plasma | Aimant | **Singularité** ✅ |
| Aura | Armure | **Forge ardente** (aura brûlante géante) 🆕 |
| Drones | Nombre | **Essaim orbital** 🆕 |
| Sabre | Vitesse | **Lames fantômes** 🆕 |
| Mines | Zone | **Champ de mines** 🆕 |

---

## 4. ÉCONOMIE DE RÉCOMPENSES (tes objets, enfin fonctionnels)

| Objet | Fonction | Source | État |
|---|---|---|---|
| 💎 **Gemme XP** | monte le niveau (tiers vert<bleu<or selon valeur) | tout ennemi | ✅ |
| 🍗 **Kit de soin** | rend **+30 PV** | caisse, ennemi intermédiaire | ✅ (posé) |
| ⚡ **Cellule overdrive** | **+30 %** de jauge directement | caisse | ✅ (posé) |
| 🎯 **Orbe de compétence** | **CHOIX de 3 cartes** (pas aléatoire !) | caisse dorée | 🔧 à améliorer (actuellement random) |
| 🧲 **Aimant** | aspire **toutes** les gemmes de l'écran | rare | 🆕 |
| 💣 **Bombe** | dégâts sur **tout l'écran** (bouffée d'air quand submergé) | rare | 🆕 |
| 📦 **Coffre** | **évolution garantie** (ou gros lot) | **élite / boss** | 🆕 = le hook d'évolution |

**Le changement clé** : l'orbe de compétence doit ouvrir un **choix de 3** (comme le level-up),
pas donner une compétence au hasard. C'est la décision qui rend le joueur acteur.

---

## 5. DÉCOR (placement cohérent — point secondaire)
Règle actuelle : nature partout ✅, man-made par biome ✅. Ce qui manque = le man-made est jeté
**au hasard**. Fix : le poser en **petits amas thématiques** (un dépôt = 2-3 caisses+baril groupés ;
un poste = tourelle+antenne+générateur) au lieu d'objets isolés éparpillés.

---

## ORDRE D'IMPLÉMENTATION conseillé
1. **Coffre d'élite/boss → évolution** (le hook manquant #1) + orbe de compétence = **choix de 3**
2. **3 armes-formes manquantes** (sabre, mines, boomerang) + promotion aura/drone en armes
3. **Passifs génériques** (zone/durée/nombre) + 4 nouvelles évolutions
4. **Aimant + bombe** (pickups rares)
5. Décor en amas thématiques
