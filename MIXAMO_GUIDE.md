# Mixamo — mode d'emploi (raider + crusher)

Fichiers prêts (textures embarquées, format FBX que Mixamo lit) :
- `mixamo_out/raider.fbx`
- `mixamo_out/crusher.fbx`

## 1. Compte
[mixamo.com](https://www.mixamo.com) → connexion avec un compte **Adobe gratuit** (créer si besoin).

## 2. Upload du personnage
Bouton **« Upload Character »** (haut-droite) → glisser `raider.fbx`. Patienter.

## 3. Auto-Rigger (fenêtre auto)
- Le perso doit être **debout, face à toi** (sinon fais-le pivoter).
- Placer les **marqueurs** : menton · 2 poignets · 2 coudes · 2 genoux · aine.
- **Skeleton LOD** → choisir **« No Fingers »** (ces mechs n'ont pas de doigts → évite les erreurs).
- **Next** → Mixamo rig (~30 s). Vérifier l'aperçu animé.

## 4. Animations (chercher à gauche, appliquer, puis Download chacune)
- **Walk** : `walk` (un walk neutre, ou `Injured Walk` / `Zombie Walk` pour le côté menaçant)
- **Run** *(optionnel, pour le raider rapide)* : `run` / `fast run`
- **Attack** : `punch` / `mma kick` / `zombie attack` / `sword and shield slash`
- **Death** : `dying` / `falling back death`

## 5. Réglages de Download (POUR CHAQUE anim)
| Champ | Valeur |
|---|---|
| Format | **FBX Binary (.fbx)** |
| Skin | **With Skin** ⚠️ (indispensable : maillage + textures) |
| Frames per Second | **30** |
| Keyframe Reduction | **none** |

## 6. Nommage + dépôt
Renommer et déposer dans **`refs/mixamo/`** :
```
raider_walk.fbx   raider_attack.fbx   raider_death.fbx   raider_run.fbx (opt)
crusher_walk.fbx  crusher_attack.fbx  crusher_death.fbx
```

## 7. Puis
Me prévenir → je bake chaque FBX en spritesheet (8 frames, format du jeu) via
`tools/bake_anim.py` et j'intègre. Je gère le sens / l'échelle automatiquement.

---
**Répéter l'upload pour `crusher.fbx`.**
Si l'auto-rig se plaint (crusher massif) : bien repositionner les marqueurs aux
articulations visibles. Si l'aperçu est retourné : pas grave, je corrige au bake.
