# MISSION ANTIGRAVITY — Ennemis de base de MECHA-FORGE : variété d'attaque, défenses, formations (vérification EN JEU)

Projet : `C:\Users\Administrator\mecha-forge` (Godot 4.3, jeu dans `game/`). Réponds en FRANÇAIS. Ne colle jamais de clé (`.itch_key`, `.meshy_key`).

## Le problème (retour du patron)
« J'ai l'impression que rien n'a changé : ils ont tous la même attaque, et pas de système de défense. »
Le code est écrit et les tests headless passent, mais **personne n'a vu le résultat tourner dans le jeu Web**. Le dernier essai de capture a échoué : aucun ennemi visible en jeu, aucun message de debug reçu. Ta mission = **trouver pourquoi, corriger, et PROUVER par captures que chaque niveau a une attaque et une défense visibles et différentes.**

## État du code (commit `c1b4d2e`, tags `v11.87` / `v11.88` / `v11.89` pour revenir en arrière)
- `game/systems/EnemySpawner.gd` : bloc `>>> PROFILS DE NIVEAU` (généré par `tools/_patch_profils.py` depuis `tools/_profils_block.gd.txt` — **modifie le .txt puis relance le script**, sinon ta modif est écrasée). Contient `PROFILES` (18 niveaux : motif d'apparition, rôles principal/secondaire, formations), `_role_def`, `_def_for`, `_pattern_offset`, `_squad_tick`, `_spawn_squad`, `_player_style` (IA adaptée au mécha du joueur).
- `game/systems/Squad.gd` : 13 formations (ligne, colonne, coin, échelon, vagues, tenaille, encerclement, spirale, fer à cheval, feu et mouvement, tirailleurs, embuscade, leurre), chef de meute (or, ×12 % de taille, ≥2,1× PV) + lieutenants (bleu glace), promotion si le chef tombe.
- `game/actors/Enemy.gd` (patchs `tools/_patch_enemy_ia.py` et `_patch_enemy_ia2.py`) : visée réelle (`_aim_tick`, `aim_rate`, `aim_lead`, inclinaison du sprite), **styles de tir** (`tir_style` : rafale, éventail, sniper, guidé, anneau, orbe — voir `_STYLES`), **défenses** : `garde` (bouclier énergétique actif 2,2 s à ~12 % des dégâts, ralentit le porteur), `esquive` (saut latéral si un projectile du joueur arrive), « ordre du chef » (−25 % de dégâts subis tant que le chef vit à ≤380 px).
- Tests headless (tous verts) : `game/_test_escouades.tscn`, `_test_profils_niveaux.tscn`, `_test_chapters`, `_test_boss_chapitres`, `_test_kill_tracking`, `_test_all_18_chapters_gameplay`. Lancer : `C:\Users\Administrator\godot_ci\Godot_v4.3-stable_win64_console.exe --headless --path game res://_test_X.tscn`.

## Ce qu'il faut faire
### 1. Diagnostiquer pourquoi rien n'est visible en jeu Web (PRIORITÉ 1)
- Build Web de debug (dossier à part, ex. `web_dbg/`) : `Godot --headless --path game --export-release "Web" ../web_dbg/index.html`, servi par `python -m http.server <port>` ; Chrome headless + SwiftShader (voir `scratchpad\pw_v9.py` côté Claude : args `--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader --ignore-gpu-blocklist --enable-webgl --no-sandbox`, clics de menu `(1195,45)`, `(640,298)`, `(640,150)` après ~45 s de chargement).
- ⚠️ Sans GPU le jeu tourne ~4× plus lentement que le temps réel : à 70 s réelles la partie n'en est qu'à 00:18. Attendre 2–3 minutes réelles pour atteindre 00:40–01:00 de jeu.
- Constat de la dernière tentative : un hook temporaire `?pool=<biome>` (lisait l'URL via `JavaScriptBridge.eval` dans `_squad_tick`) n'a produit ni ennemis, ni `print`, ni bandeau `show_banner`. **Hypothèses à vérifier** : (a) `_squad_tick` n'est jamais atteint ou plante silencieusement en Web (erreur de script non remontée en release) ; (b) `current_biome` n'est pas une clé de `PROFILES` au démarrage réel d'un chapitre (le jeu le réassigne dans `Game.gd` lignes ~377, ~1356, ~2618) → `_def_for` rend la définition brute et `_pattern_offset` retombe sur l'ancien anneau ; (c) les ennemis existent mais leur sprite est invisible (regarder `_aim_tilt`, `self_modulate`) ; (d) le chapitre testé n'utilise pas le pool attendu.
- Méthode : mettre les lignes de debug marquées `#TMPDBG` (les SUPPRIMER toutes avant de finir : `grep -n TMPDBG` doit renvoyer 0), idéalement afficher à l'écran (bandeau) le biome courant, le nombre d'ennemis, les formations actives. Exporter en `script_export_mode` lisible si besoin pour voir les erreurs.

### 2. Rendre les différences VISIBLES, niveau par niveau (le vrai reproche du patron)
Pour chacun des 18 niveaux, obtenir en jeu une capture montrant : (a) la **formation** (+ bandeau « FORMATION : … ») ; (b) la **signature de tir** (couleur/forme/vitesse distinctes : rafale orange, éventail jaune-vert, sniper blanc avec charge rouge, guidé violet, anneau vert, orbe rouge énorme) ; (c) la **défense** (garde = teinte cyan + ondulation ; esquive = onde bleue ; chef = or + plus grand). Si une différence n'est pas immédiatement lisible à l'écran, **la renforcer** (halo/anneau/icône au-dessus de l'ennemi, trajectoire plus visible, télégraphe plus long). Attention : le joueur vient de dire qu'il ne voit RIEN de différent.
- Vérifier aussi que les niveaux 1–5 sont « normaux » (pas trop faciles) et que 11–18 restent jouables (jamais impossible : vitesse ennemie ≤ 80 % du joueur, brèche de 60° dans l'encerclement, plafond de rôles spéciaux `_special_cap`, ENEMY_CAP 220).
- Les ennemis (`mechNN`) partagent le même sprite par niveau : la différence doit venir du COMPORTEMENT et des EFFETS, pas d'un nouveau modèle 3D. Ne PAS utiliser Meshy.

### 3. Contraintes (à respecter)
- Pack Web < 200 Mo (actuellement 116 Mo pck / 122 Mo zip) — ne rien ajouter de lourd.
- Ne pas casser les tests existants. Relancer tous ceux listés plus haut + `_test_escouades.tscn` à la fin.
- Garder tout réversible : un commit par étape, pas de `git add -A` sur des dossiers temporaires (`web_dbg/`, profils Chrome, etc.).
- Version à incrémenter à la livraison : `game/project.godot` (`config/version`) ET `game/export_presets.cfg` (2 lignes `version/name`), actuellement 11.89 → 11.90.
- Si tu ajoutes une classe (`class_name`), lance une fois `Godot --headless --path game --import` pour rafraîchir le cache.

### 4. Livrable
1. Corrections commitées + tag `v11.90`.
2. Un tableau 18 lignes (niveau · formation · signature de tir · défense) **avec le chemin d'une capture réelle pour chacun**.
3. Build Web final `web/` + zip `build/mecha-forge-html5-v11.90.zip`.
4. Liste honnête de ce qui n'a PAS pu être vérifié.

## Point bloquant connu : envoi itch.io
L'envoi manuel du zip vers itch (page d'édition `https://itch.io/game/edit/4789137`, Chrome CDP port 9222, script `scratchpad\itch_full2.py`) a échoué 4 fois : l'onglet se ferme en plein téléversement (ou le téléversement ne se termine jamais, sans message). Les joueurs voient donc encore l'ANCIENNE version 11.87 — ce qui explique en partie « rien n'a changé ». Si tu peux, diagnostique (onglet en arrière-plan ? script de nettoyage d'onglets `nettoie_onglets.py` ? mémoire de Chrome ?) ; sinon, laisse le zip prêt et signale-le : le patron le déposera à la main (et doit cocher « embed » sur le nouveau fichier).
