# Prompt #3 pour Antigravity — générer un mecha COMPLET (toutes anims) pour un survivor-like top-down 3/4

Copie-colle tout ce qui suit à Antigravity.

---

Génère un **nouveau mecha joueur COMPLET** pour le jeu MECHA-FORGE (`C:\Users\Administrator\mecha-forge`), avec **l'ensemble des animations nécessaires** à ce type de jeu. Lis `PROJECT_HANDOFF.md` pour le contexte global. Installe les extensions/MCP qui t'aident.

## 1. Type de jeu & VUE (à respecter au rendu)
- **Survivor-like / bullet-heaven** (façon Survivor.io / Vampire Survivors), mobile Android, Godot 4.5.
- **Vue TOP-DOWN 3/4** : caméra au-dessus **inclinée à ~40° d'élévation** (on voit le dessus ET la face du mecha). PAS de l'isométrique, PAS du top-down pur vertical. Rends les 4 directions avec cette même caméra, seul l'azimut change : `front`=0°, `back`=180°, `left`=90°, `right`=-90°.
- Le tir est **automatique à 360°** et l'arme est un **overlay séparé qui tourne vers la cible** (géré par `WeaponSystem`). Donc le mecha n'a PAS besoin de pointer précisément : il lui faut une **posture de combat crédible, bras/mains prêts** (une arme sera montée à la main via `grip_anchor`). Garde les **mains libres / en garde** (pas d'arme moulée dans le mesh, sauf si tu gères les ancres).

## 2. ENSEMBLE COMPLET DES ANIMATIONS (le strict nécessaire pour ce genre)
7 animations, **chacune en 4 directions**, **8 frames** par planche :
1. **idle** — debout, posture de combat, respiration + micro-balancement. (bras en garde, pas ballants)
2. **walk** — déplacement, foulée articulée nette (genoux qui plient, pieds qui se posent), bras en garde.
3. **run** — sprint (course penchée avant, foulée ample) — utilisé en mode Overdrive.
4. **attack** — **pose de tir** : stance de combat + léger recul/kick + flash du réacteur, en **boucle propre** (jouée en continu pendant le tir auto).
5. **hit** — flinch d'impact (recul du torse, absorption genoux, retour).
6. **die** — mort (effondrement/affaissement au sol).
7. **melee** — **coup de sabre** : fente avant + grand balayage de bras/lame en arc (le jeu a une attaque de mêlée au corps-à-corps).

## 3. ⚠️ CRITIQUE — TAILLE / CADRAGE (l'erreur à NE PAS refaire)
Ton `new_mecha`/DARKSTAR précédent était **CASSÉ** : le mecha ne faisait que **~11 px** dans une cellule de 256 (**4%**), il apparaît comme un point invisible en jeu. **INACCEPTABLE.**
- Le mecha DOIT **remplir ~50-55% de la hauteur de la cellule**, comme `bluestrike` (**~137 px sur 256**). Vérifie-le en mesurant l'alpha du sprite bakké.
- **Cause probable de ton bug** : tu n'as pas généré de vrai modèle 3D et/ou le cadrage caméra était faux. **Utilise `tools/bake_anim.py`** qui dimensionne la caméra ortho sur les bornes du modèle (le mecha remplit alors le cadre correctement). Ne fabrique PAS des sprites procéduraux minuscules.

## 4. PIPELINE OBLIGATOIRE (celui qui a marché pour bluestrike)
Fais du **vrai 3D détaillé**, pas du placeholder :
1. **Concept** : génère une belle image de mecha (FLUX/ton générateur), OU réutilise/varie `cine/pixel/hi_1.png`. Style : mecha de combat détaillé, armure sombre premium, accents lumineux, cœur/réacteur. (DARKSTAR = « canon lourd & armure sombre » si tu gardes ce thème.)
2. **Image→3D** : `python tools/meshy_client.py image <concept.png> --name <chassis>` (Meshy, clé dans `.meshy_key`/`MESHY_KEY`, ~180 crédits) → `meshy_in/<chassis>/model.glb` + `rigged.glb`.
3. **Rig + animations** : `riganim`/`animate` (rig humanoïde Meshy) OU **keyframe les poses UPRIGHT à la main dans Blender bpy** (c'est ce qui a rendu bluestrike droit et pas voûté — l'auto-retarget Meshy voûte le mecha). ANIM_IDS Meshy : idle 0, Casual_Walk 30, run 16, attack 4, hit 178, die 8.
4. **Bake 4-dir** : `python tools/bake_anim.py meshy_in/<chassis>/<anim>.glb game/assets/mecha/<chassis>_<anim>.png --frames 8 --res 256 --dirs 4` (bpy **Cycles CPU**). → produit `<chassis>_<anim>_{front,back,left,right}.png`.

## 5. FORMAT DE SORTIE EXACT
- Chemin : `game/assets/mecha/<chassis>_<anim>_<dir>.png`. Choisis un nom de chassis (ex. `darkstar` — et **corrige** l'entrée `new_mecha` existante, ou remplace-la).
- Chaque PNG : **2048×256** (8 cellules de 256×256), **RGBA transparent**, mecha **centré**, **pieds ancrés sur la hauteur de frame 0** (pas de saut vertical), **même taille de cellule pour TOUTES les planches**, bords **nets**, mecha à **~50-55% de la cellule**.
- Posture **upright** (droite, héroïque), bras en **garde de combat** (jamais ballants).

## 6. VALIDATION (impérative — sois honnête)
⚠️ Tes « validations navigateur » précédentes étaient **fausses** : tu capturais la **cinématique de boot** (« UN MONDE EN CENDRES ») en croyant tester le jeu. **Cette fois :**
- Rends un **GIF de contrôle de CHAQUE animation** dans `meshy_in/previews/` et **regarde-les** avant de baker les 28 planches. Surtout : vérifie que le mecha **remplit bien la cellule** (pas 11px !).
- Test navigateur RÉEL : va **jusqu'au gameplay** (PASSER la cinématique en cliquant le bouton `PASSER` en haut-droite ~1195,45 → `JOUER` ~640,578 → `NORMAL` ~640,288 → attends → capture le mecha en jeu). Une capture à 10s = c'est le menu, PAS le jeu.
- Import Godot **4.5** sans erreur : `C:\Users\Administrator\tools\godot45\Godot_v4.5-stable_win64_console.exe --headless --path game --import`.

## 7. CONTRAINTES
- **NE CASSE PAS** `bluestrike` (le mecha de référence qui marche) ni `lourd`/`valiant`/`george`/etc. Crée un **nouveau chassis** propre.
- Ne branche PAS forcément ce mecha comme joueur par défaut ; ajoute-le au garage (`GameState.MECHS`) proprement (avec un aperçu qui n'est PAS un point de 11px).
- Sécurité : jamais de clé API en dur/commit (elles sont dans `.meshy_key`/env). Pas de tunnel public. Cycles CPU (pas de GPU serveur).
- À la fin : liste le nom du chassis, les 7 anims × 4 dir produites, **le % de remplissage mesuré** (preuve que ce n'est pas 11px), et les chemins.

Objectif : un mecha **beau, détaillé, upright, articulé, à la bonne taille**, avec **les 7 animations en 4 directions**, drop-in dans le jeu. Le patron juge sur le **rendu en jeu réel**.
