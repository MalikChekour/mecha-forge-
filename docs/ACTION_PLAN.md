# Plan d'action — guide stratégique ↔ état du code (2026-07-11)

Confrontation du guide de recherche F2P avec le code réel de mecha-forge.

## ✅ Déjà en place (ne pas refaire)
- **Armes découplées des sprites 4-dir** : le mecha joue une pose générique, les armes = sprites montés + projectiles rotatifs Godot (WeaponSystem/Projectile). Le goulot d'étranglement est déjà évité.
- **Flash blanc sur ennemi touché** : shader `hit_flash.gdshader` actif.
- **8 biomes**, draft 3 cartes, jauge Overdrive+transfo, archétypes mêlée/ranged, VFX armes, boucliers d'énergie.
- **Palette FX de base** : projectiles joueur froids (cyan), impacts colorés.

## ⚡ Quick wins (fort impact / faible effort — vérifiables en jeu aujourd'hui)
1. **Renderer → Compatibility (GLES3)** : non fixé dans project.godot (défaut Forward+/Vulkan) → poser `rendering_method="gl_compatibility"` (Android/vieux Snapdragon).
2. **Caméra déportée** : le joueur est centré → le pouce cache le sud. Décaler la caméra pour placer le héros à ~60 % vers le bas.
3. **Tirs ennemis en palette CHAUDE** : actuellement spitter=vert, drone=cyan (VIOLE la règle « froid=joueur / chaud=ennemi ») → repasser tous les bolts ennemis en rouge/orange/magenta pour la lisibilité.
4. **Auto-aim sur l'ennemi le plus proche par défaut** : aim manuel actuellement → viser auto le + proche, le joueur ne fait que diriger (override manuel gardé).
5. **Hit-stop 40-50 ms** sur crit + mort de boss uniquement.

## 🔨 Moyens (fort impact / effort moyen)
6. **Object pooling** projectiles + bolts + ennemis (zéro `queue_free`/`new` en boucle chaude) → tenir 60 FPS à 200+ ennemis.
7. **Biomes fonctionnels** : modificateurs de spawn/terrain par biome (glace = ennemis -20 % vitesse, lave = zones de dégâts au sol, etc.). Rend les 8 biomes gameplay, pas cosmétiques.
8. **Structure de run 15 min + boss timés** (5/10/15 min) au lieu du ramp infini.
9. **Overdrive = moissonneuse** : invincibilité + vitesse ×2 + aimant à XP pendant 5-8 s (pic de dopamine), pas juste un beam.
10. **Économie data-driven** : sortir stats armes/ennemis/prix dans des `Resource`/JSON (tuner sans recompiler).

## 🏗️ Gros chantiers (à planifier)
- **Shipping Android** : export AAB, keystore (⚠️ sauvegarder ×3 clouds), Play Console, Data Safety, renderer Compatibility. ⚠️ nécessite le template Android + SDK sur la machine — à valider (peut ne pas être faisable headless ici).
- **Méta-progression** : arbre de talents (plafond +30 %), rang d'armes (fusion doublons), quêtes.
- **Monétisation** : revive rewarded, reroll/skip rewarded, interstitiel fin de run, starter pack, remove-ads, SDK AdMob/AppLovin + UMP/CMP.
- **Rétention/LiveOps** : daily streak 7j, push H+24, énergie douce, events JSON.

## Sprints proposés
- **Sprint 1 (aujourd'hui, tout vérifiable en jeu)** : quick wins 1→5.
- **Sprint 2** : biomes fonctionnels (7) + pooling (6).
- **Sprint 3** : boucle 15 min + boss (8) + Overdrive moissonneuse (9).
- **Sprint 4+** : data-driven éco (10), puis méta / monétisation / shipping.
