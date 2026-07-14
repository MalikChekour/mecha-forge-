# Mecha sprite credits & re-bake provenance

## Player + enemy mech sprites — Quaternius "Animated Mech Pack" (CC0)

The animated mech spritesheets in this folder (`george_*.png`) and the enemy mech sheets in
`../enemies/` are **rendered** from the free, public-domain **Quaternius Animated Mech Pack**.

- **Source:** https://quaternius.com/packs/animatedmech.html
- **License:** CC0 1.0 (public domain) — free for commercial use, **zero attribution required**.
  This credit is kept only for our own reproducibility, not out of obligation.
- **Variant used:** *Flat Colors* glTF (self-contained, base64-embedded textures, RobotArmature,
  20 animations: Idle / Walk / Run / Shoot / Death / HitRecieve_1 / … ).
- **Archived source in-repo:** `assets_src/quaternius_animated_mech/{George,Stan,Mike,Leela}.gltf`
  (committed because CC0 lets us — this is what makes the sheets re-bakable).

### chassis → model mapping
| game chassis | Quaternius model | role |
|--------------|------------------|------|
| `george`     | George.gltf      | **player mech** (AEGIS) |
| `brute`      | Stan.gltf        | enemy — brawler |
| `crusher`    | Mike.gltf        | enemy — heavy |
| `elite`      | Leela.gltf       | enemy — bladed |

## Re-baking the sheets (no GPU required)

Sheets are produced by `tools/render_sheet.py` (bpy 5.0.1 as a pip module, **Cycles CPU** —
the build server has no GPU, EEVEE fails). It renders each glTF into 4-direction, 8-frame
horizontal strips: `<chassis>_<anim>_<dir>.png` for anim ∈ {idle,walk,run,attack,hit,die},
dir ∈ {front,back,left,right}.

```
# player (George):
python tools/render_sheet.py assets_src/quaternius_animated_mech/George.gltf game/assets/mecha george
# enemies (into ../enemies/, mapping above):
python tools/render_sheet.py assets_src/quaternius_animated_mech/Stan.gltf  game/assets/enemies brute
python tools/render_sheet.py assets_src/quaternius_animated_mech/Mike.gltf  game/assets/enemies crusher
python tools/render_sheet.py assets_src/quaternius_animated_mech/Leela.gltf game/assets/enemies elite
```

Optional 6th arg `face_offset` (degrees) pre-rotates a mis-oriented model onto our
front=-Y convention. The camera frames each chassis on its **animated** extent (gameplay
poses share a tight frame; `die` gets its own wider frame so the fall-over never clips).
