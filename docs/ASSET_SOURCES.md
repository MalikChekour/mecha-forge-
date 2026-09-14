# Sources d'assets qualitatifs — recherche 2026 (animations, ennemis, décors, VFX, 3D)

Cartographie pour MECHA-FORGE (Godot mobile, top-down, on cuit du 3D→sprites, on a FLUX + procédural).
⚠️ **Licences** : seul le **CC0** est sûr en commercial sans attribution. itch.io / OpenGameArt /
Sketchfab = licences **mixtes**, vérifier CHAQUE asset avant usage.

---

## 🥇 Les 3 découvertes qui changent notre pipeline

### 1. Mixamo — rig + animation GRATUITS de nos mechs (sans crédits Meshy)
https://www.mixamo.com — Adobe, gratuit. Upload d'un modèle humanoïde (FBX/OBJ) → **auto-rig +
bibliothèque d'animations** (marche/course/attaque/mort…) → export FBX.
**Impact énorme** : sur nos mechs FLUX/Meshy, Meshy sert juste à faire le **maillage** (image→3D) ;
le **rig et les animations peuvent venir de Mixamo gratuitement** au lieu de coûter des crédits.
Le mech est bipède humanoïde → compatible.

### 2. PixelLab — sprites animés DIRECTIONNELS depuis un prompt (le chaînon manquant)
https://www.pixellab.ai — génère des **personnages animés en sprite sheets**, avec **variantes 4 ou
8 directions automatiques** (marche/course/attaque). Navigateur ou plugin Aseprite, + une API.
**Impact** : c'est exactement ce que Gemini NE sait pas faire (l'animation cohérente frame à frame).
Candidat sérieux pour nos héros/ennemis 2D animés sans passer par la 3D.
Alternative pixel-art : **Retro Diffusion** (https://retrodiffusion.ai, modèle "rd-animation" entraîné
sur des sprite sheets → cohérence temporelle).

### 3. Tripo3D / AccuRIG — alternatives à Meshy
- **Tripo3D** (https://www.tripo3d.ai) : image/texte→3D avec **quota gratuit** + auto-rig. Concurrent
  direct de Meshy, à tester avant de racheter des crédits.
- **AccuRIG 2** (Reallusion, https://actorcore.reallusion.com/auto-rig) : auto-rig **gratuit**,
  gère les non-humanoïdes, + bibliothèque d'animations ActorCore. Meilleur que Mixamo pour les
  formes exotiques (quadrupèdes, boss).

---

## 📦 Assets prêts à l'emploi

### CC0 — sûrs en commercial, zéro attribution
| Source | Contenu | Note |
|---|---|---|
| **Kenney.nl** | 40 000+ assets 2D/3D/VFX/UI/audio | Déjà utilisé. **Particle Pack** (80 sprites : feu, fumée, magie, étincelles, électricité) = à re-télécharger (on avait perdu la source des VFX). https://kenney.nl/assets/particle-pack |
| **Quaternius** | 3D low-poly rigged+animés (persos, ennemis, véhicules, décors) | Déjà utilisé (George + ennemis). https://quaternius.com |
| **Poly Pizza** | Archive "Google Poly" + milliers de modèles low-poly | https://poly.pizza — décors/props 3D à cuire |
| **Icosa Gallery** | Suite open-source de Google Poly | https://icosa.gallery |
| **Poly Haven** | Textures PBR + HDRI (CC0) | https://polyhaven.com — pour les **sols/décors** photoréels |

### Licences mixtes — vérifier chaque asset
| Source | Contenu | Note |
|---|---|---|
| **itch.io** /game-assets | Ennemis, monstres, top-down 8-dir, kits | Filtrer `assets-cc0`. Ex. **"Top Down RPG Enemy (Animated 8 directions)"** de 10KStudios (idle/attaque/mort, usage commercial). https://itch.io/game-assets/assets-cc0 |
| **OpenGameArt.org** | Sprites, VFX, particules, tilesets | Licences variées (CC0/CC-BY/GPL). "Particle Pack 80 sprites", "Explosion effects". https://opengameart.org |
| **CraftPix.net** | Kits 2D top-down, persos, GUI (sous-ensemble gratuit) | Qualité solide. https://craftpix.net/freebies |
| **Sketchfab / BlendSwap** | Grosses bibliothèques 3D | Licences mixtes, filtrer "Downloadable + CC0". |

### Méta-listes
- **awesome-cc0** : https://github.com/madjin/awesome-cc0 (annuaire CC0 tenu à jour)
- Guides 2026 : [AssetHoard](https://assethoard.com/blog/where-to-find-free-game-assets-2026),
  [Cinevva](https://app.cinevva.com/guides/game-assets-guide),
  [Hackingtons](https://www.hackingtons.com/free-game-art.html)

---

## 🎬 Animations 3D (bibliothèques de mouvements)
- **Mixamo** — le standard, gratuit, humanoïde.
- **ActorCore** (Reallusion) — pack de mouvements, s'utilise avec AccuRIG.
- **DeepMotion Animate 3D** — vidéo→animation (mocap IA), quota gratuit.

---

## 🧭 Reco de priorité pour NOUS
1. **Mixamo** dès qu'on a un mech Meshy/Tripo : rig + anims gratuits → **on arrête de payer le rig**.
2. **Re-télécharger le Kenney Particle Pack** : rebouche notre trou VFX (on avait perdu la source).
3. **Tester Tripo3D** (gratuit) avant de racheter des crédits Meshy.
4. **PixelLab** si un jour on veut des héros/ennemis 2D animés directionnels sans la 3D.
5. **itch.io CC0 8-dir** pour compléter le bestiaire vite fait (vérifier licence).
6. **Poly Haven** pour de vrais sols de biome (on génère déjà via FLUX, mais utile en secours).
