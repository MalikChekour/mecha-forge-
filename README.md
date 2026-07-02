# MECHA-FORGE — fresh mecha survivor-like (Godot 4.3)

A **from-scratch** build of the customizable-mecha bullet-heaven, running in parallel
to the reference prototype in `../mecha-survivor` (IRONVEIL), which is left untouched.
This version's first pillar is **art & animation** done the scalable way.

## The core idea: a layered, procedurally-animated mecha rig

The reference project renders each mecha as a **monolithic** pre-rendered sprite (body +
weapons baked together, one walk-sheet per chassis). That does not scale to a *customizable*
mecha with *visible* weapon hardpoints — every chassis×weapon combo would need its own bake.

Here the mecha is assembled from **separately-rendered rigid parts**
(`torso`, `thigh_left/right`, `shin_left/right`, `head`, `core`) composited live, and each
equipped weapon is a **visible hardpoint** sprite mounted at a shoulder anchor that aims and
recoils. Motion is **fully procedural** in-engine — two-segment FK legs in antiphase (visible
knee bend, foot plant + squash), torso weight (bob on footfalls, lateral shift, pelvis rock),
core pulse, hardpoint aim/recoil with torso counter-rock — so any loadout animates with
**zero extra baking**. Animation constants live in `rig.json` (single source of truth for
both the Python preview and `MechaRig.gd`).

This deliberately sidesteps the documented dead-ends: no mesh segmentation (SIGSEGV), no
hard-surface auto-rig (smooth-skin tears) — the parts are separate rigid objects, animated by
moving sprites, not by skinning a mesh.

## Pipeline (no-GPU, all local)

```
tools/build_mecha.py   # headless Blender (Cycles CPU): builds a hard-surface mecha from
                       #   primitives as SEPARATE parts, renders each to a transparent
                       #   aligned layer, and writes rig.json (pixel anchors: shoulders,
                       #   muzzles, feet) via camera projection.
tools/preview_gif.py   # composites the layers with the SAME procedural animation model as
                       #   MechaRig.gd into docs/mecha_walk.gif  (the visible proof)
```

`game/actors/MechaRig.gd` is the runtime twin of `preview_gif.py` — identical animation math.

## Run / validate

```
# import once (generates .godot cache so load() works headless), then smoke-test the rig:
"C:\Users\Administrator\tools\godot\Godot_v4.3-stable_win64_console.exe" --headless --path game --import
"C:\Users\Administrator\tools\godot\Godot_v4.3-stable_win64_console.exe" --headless --path game --quit-after 300 -- --autoplay
```

Desktop sandbox (arrow keys to drive; auto-demo otherwise):
```
"C:\Users\Administrator\tools\godot\Godot_v4.3-stable_win64.exe" --path game
```

## Status

v2 (fidelity pass after an adversarial art+code review): two-segment legs with a walk that
actually reads at phone scale, zoned materials (tintable armor / near-black joints / bright
trim with procedural edge-wear) + cyan rim light, weapon archetypes (rotary autocannon,
6-tube missile pod with hot tips), designed chest reactor, heroic proportions, real smoke-test
assertions (exit 1 on failure). Gameplay (spawner, projectiles, XP/draft, meta,
Android/monetization) is intentionally **not** built yet — the brief's gate is to prove the
differentiating art/animation on one entity first.

Layout: `game/` = Godot project · `tools/` = bpy + preview pipeline · `docs/` = proof artifacts.
