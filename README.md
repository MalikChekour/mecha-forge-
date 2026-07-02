# MECHA-FORGE — fresh mecha survivor-like (Godot 4.3)

A **from-scratch** build of the customizable-mecha bullet-heaven, running in parallel
to the reference prototype in `../mecha-survivor` (IRONVEIL), which is left untouched.
This version's first pillar is **art & animation** done the scalable way.

## The core idea: a layered, procedurally-animated mecha rig

The reference project renders each mecha as a **monolithic** pre-rendered sprite (body +
weapons baked together, one walk-sheet per chassis). That does not scale to a *customizable*
mecha with *visible* weapon hardpoints — every chassis×weapon combo would need its own bake.

Here the mecha is assembled from **separately-rendered rigid parts**
(`torso`, `leg_left`, `leg_right`, `head`, `core`) composited live, and each equipped weapon
is a **visible hardpoint** sprite mounted at a shoulder anchor that aims and recoils. Motion
is **fully procedural** in-engine (leg stomp + weight-bob + torso rock + core pulse + hardpoint
aim/recoil), so any loadout animates with **zero extra baking**.

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

Foundation: layered mecha rig + procedural walk/aim/fire, validated headless. Art is a chunky
hard-surface base (bpy primitives) — riggable and consistent; a FLUX/higher-fidelity skin pass
can replace the part textures without touching the rig. Gameplay (spawner, weapons firing real
projectiles, XP/draft, meta, Android/monetization) is intentionally **not** built yet — the
brief's gate is to prove the differentiating art/animation on one entity first.

Layout: `game/` = Godot project · `tools/` = bpy + preview pipeline · `docs/` = proof artifacts.
