# MECHA-FORGE — Dossier de passation complet (pour Antigravity)

Tu prends **l'entière responsabilité** du projet `C:\Users\Administrator\mecha-forge`. Ce document te donne le contexte, l'état réel, le problème prioritaire, les conventions, les workflows et les garde-fous. Tu as toute latitude pour **redessiner ce qu'il faut** tant que le jeu reste jouable et shippable.

---

## 0. PROBLÈME PRIORITAIRE À RÉSOUDRE (le patron est bloqué là-dessus)
Le mecha joueur **« vise en arrière »** / ne pointe pas ses armes vers ce qu'il tire. **Cause racine** : c'est un **survivor / bullet-heaven à visée automatique 360°** (l'arme tire sur l'ennemi le plus proche, dans N'IMPORTE quelle direction), MAIS le personnage est rendu en **sprites 2D pré-rendus à seulement 4 directions** (front/back/left/right). Un corps 4-directions + une pose « bras vers l'avant » **ne peut pas pointer précisément** une cible à 360° → ça paraît viser au mauvais endroit.

**Tu as carte blanche pour résoudre la cohérence de visée.** Pistes possibles (choisis/combine) :
- **Arme/canon en overlay qui tourne à 360°** vers la cible (Sprite2D séparé au-dessus du corps, `rotation = aim_dir.angle()`), le corps ne faisant que marcher. ⚠️ le patron avait fait masquer l'arme visible (`WeaponSystem.visuals_hidden = true`) car elle « flottait » — si tu la réactives, **règle l'ancrage** (voir `WeaponSystem.gd` / `DirectionalMecha.grip_anchor/gun_anchor`).
- **Sprites 8 directions** (ajouter les diagonales) pour une visée plus fine.
- Repenser entièrement le feedback de combat (muzzle/tracers orientés à la cible plutôt que le corps).
Le reste du mecha (posture upright, bras en garde, marche articulée) est **bon** — ne le casse pas, corrige la **visée/l'arme**.

---

## 1. LE JEU
- **MECHA-FORGE** : survivor-like / bullet-heaven **mobile Android** (type Survivor.io / Vampire Survivors). Le joueur = un **mecha** qui se déplace en 4 directions, tire **automatiquement** sur les ennemis, ramasse de l'XP, monte de niveau (draft de 3 cartes), affronte des vagues + boss, avec une méta (points de compétence, arsenal) et une **transformation "Overdrive"** (rayon d'énergie 15 s).
- **Moteur : Godot 4.5** (projet dans `game/`). Renderer **gl_compatibility** (web/mobile), filtre texture **NEAREST**.
- Écran **paysage 1280×720**, vue **top-down 3/4** (~40° d'élévation caméra).
- Cible finale : **APK Android** + build web (itch.io). Le web sert de preview jouable.

## 2. ÉTAT ACTUEL
- ✅ Boucle jouable complète (déplacement, tir auto, XP, level-up/draft, vagues, boss, méta, biomes, décor destructible + hazards, transformation, audio, VFX).
- ✅ Mecha joueur **`bluestrike`** : modèle 3D détaillé (Meshy depuis `cine/pixel/hi_1.png`), riggé, **animations upright** (idle/walk/run/attack/hit/die/melee) bakées en sprites 4-dir. **Posture, marche, bras en garde = OK.**
- ❌ **Visée incohérente** (cf. §0) = LE point à régler.
- Déployé sur **itch v3.9** (canal html5).

## 3. STRUCTURE DES DOSSIERS
```
mecha-forge/
├── game/                     ← LE PROJET GODOT 4.5 (ouvre celui-ci)
│   ├── project.godot         (config/version = à bumper à chaque build)
│   ├── actors/               Player.gd, DirectionalMecha.gd, WeaponSystem.gd, Enemy.gd,
│   │                         Projectile.gd, EnemyProjectile.gd, Pickup.gd, PropScatter.gd,
│   │                         SceneryScatter.gd, Ambient.gd, VfxSprite.gd, (MechaRig/HeroRig = anciens rigs)
│   ├── autoload/             GameState, SaveManager, Events, Audio, Ads, Palette, Tex
│   ├── scenes/               Boot, Game.gd (orchestrateur), MetaScreen (hub), Cutscene, ui/HUD
│   ├── systems/              EnemySpawner.gd
│   └── assets/               mecha/ enemies/ decor/ weapons/ audio/ vfx/ menu/ hero/ bullets/
├── tools/                    91 scripts (Python/bpy + PowerShell) — pipeline assets + build + test
│   ├── bake_anim.py          GLB animé → planche sprite 2D (--dirs 4, --el, ancre hauteur frame 0)
│   ├── meshy_client.py       Meshy image→3D / rig / animate (clé dans .meshy_key)
│   ├── build_bluestrike_anims.py  (TON script d'anims upright bluestrike)
│   ├── serve_web.py / tools/serve_web.py  serveur COOP/COEP pour le build web threadé
│   └── push_itch.ps1         déploiement itch (butler → whimora/mecha-forge:html5)
├── meshy_in/<name>/          modèles/anims GLB Meshy (nice_mech = source bluestrike, rigged.glb + anim_*.glb)
├── web/                      build web exporté (index.* servi ; NE PAS committer)
├── cine/                     rendus, previews, artifacts (hors jeu)
├── refs/                     références visuelles
├── .meshy_key .glm_key       CLÉS API (hors git) — voir §6 SÉCURITÉ
├── README.md MIXAMO_GUIDE.md ANTIGRAVITY_PROMPT*.md   docs
```

## 4. CONVENTIONS CLÉS (à respecter absolument)
### Sprites de personnage (`DirectionalMecha.gd`)
- Chemin : `game/assets/mecha/<chassis>_<anim>_<dir>.png`.
- `<dir>` ∈ {front, back, left, right} · `<anim>` ∈ {idle, walk, run, attack, hit, die, melee}.
- Chaque PNG = **1 planche horizontale de N frames égales** (bluestrike : 8 frames, 2048×256). Fond **RGBA transparent**, mecha centré, **pieds ancrés sur la hauteur frame 0**, même taille de cellule pour toutes les planches d'un chassis, bords nets.
- `DirectionalMecha` : `chassis`, `frame_count`, `display_height` ; `set_facing_from(vec)` choisit la dir (hystérésis anti-spin) ; dicts `LOOP`/`FPS` par anim ; `has_baked_weapon()`/`gun_anchor()`/`grip_anchor()`/`blade_anchor()` pour les armes ancrées.
- Player joueur : `game/actors/Player.gd` → `hero_id = "bluestrike"`, `frame_count = 8`, `display_height = 310`. **Ne casse pas** les chassis `lourd`, `valiant`, `george` (comparaison).
### Armes & tir (`WeaponSystem.gd` + Player)
- `WeaponSystem` = enfant du Player, gère les armes (autocannon/missilepod/railgun/plasma/sabre), le muzzle, l'ancrage. `visuals_hidden = true` actuellement (arme invisible → c'est une des causes de l'incohérence de visée).
- Player : `aim_dir` (vers l'ennemi le plus proche), `_firing_t` (fenêtre pose de tir), `_update_slash` (sabre corps-à-corps), logique d'anim dans `_physics_process` (walk/run si bouge, `attack` si tire à l'arrêt, `melee` sur slash).

## 5. WORKFLOWS (build / test / deploy)
- **Godot 4.5** : `C:\Users\Administrator\tools\godot45\Godot_v4.5-stable_win64_console.exe` (PAS la 4.3).
- **Import** : `<godot45> --headless --path game --import`
- **Smoke headless** (0 GPU) : `<godot45> --headless --path game --quit-after 2000 -- --autoplay` → doit finir sans erreur. ⚠️ le smoke NE joue PAS le parcours menu→partie humain ; pour vraiment voir le rendu, teste en navigateur.
- **Export web** : preset `"Web"` → `<godot45> --headless --path game --export-release "Web" <abs>/web/index.html` (bump `config/version` d'abord).
- **Servir le web** (threadé → COOP/COEP obligatoire) : `python tools/serve_web.py 8990` puis `http://127.0.0.1:8990/index.html`.
- **Test navigateur** : Playwright/Chromium à `C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe` (args swiftshader : `--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader`). ⚠️ `print()` Godot **n'est pas routé** vers la console navigateur → exposer via `JavaScriptBridge.eval("window.__x=…")` puis lire. Les clics/touches Playwright réels SONT trusted par Godot.
- **Déployer itch** : `pwsh tools/push_itch.ps1` (butler → `whimora/mecha-forge:html5`, lit `config/version`).
- **Baker un GLB animé → sprites 4-dir** : `python tools/bake_anim.py <in.glb> game/assets/mecha/<chassis>_<anim>.png --frames 8 --res 256 --dirs 4` (bpy **Cycles CPU**, EEVEE échoue en headless).

## 6. GARDE-FOUS (impératifs)
- **SÉCURITÉ CLÉS** : NE JAMAIS coder en dur / logger / committer les clés API. Elles vivent dans des fichiers hors-git (`.meshy_key`, `.glm_key`) et des variables d'environnement (`GOOGLE_API_KEY`, `REPLICATE_API_TOKEN`). Les scripts les lisent de là. `.gitignore` les protège — garde-le.
- **Pas d'exposition publique** : le patron veut du **localhost uniquement** pour les previews (pas de tunnel public type ngrok/cloudflared).
- **Commits** : ne commit/push que si le patron le demande explicitement.
- **Pas de GPU sur cette machine** : tout rendu Blender/bpy en **Cycles CPU**. (Si TOI tu as un GPU, sers-t'en, mais la sortie doit respecter §4.)
- **numpy 1.26.4 / pillow 12.0.0** (pins), Godot 4.5, bpy 5.0.1.
- Ne casse pas la boucle jouable ni les autres chassis/ennemis/décor.

## 7. TA MISSION
1. **Régler la visée** (§0) pour que le mecha pointe/tire de façon cohérente vers ses cibles (arme overlay 360° recommandée, ou 8-dir).
2. Polir le combat pour que ce soit lisible et satisfaisant (muzzle, arme, feedback).
3. Garder le mecha `bluestrike` (beau, upright, articulé) — corriger l'arme/visée, pas la posture.
4. Valider : import Godot 4.5 sans erreur → test navigateur (rendu réel) → si bon, bumper version + export + (si demandé) push itch.
5. À la fin : résume ce que tu as changé (fichiers, approche de visée retenue), et ce qui reste.

Prends le dossier en main. Installe les extensions/MCP qui t'aident. Le patron juge sur **le rendu en jeu**, pas sur un smoke headless.
