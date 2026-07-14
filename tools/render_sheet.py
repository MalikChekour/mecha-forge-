# -*- coding: utf-8 -*-
"""Render an animated glTF into the game's 4-direction spritesheets via bpy Cycles CPU (no GPU).
Output: <out_dir>/<chassis>_<game_anim>_<dir>.png  — each an 8-frame horizontal strip.
Directions map to the game (DirectionalMecha): front=faces camera(+y screen), back, left(-x), right(+x).
We yaw the whole mech (fixed tilted top-down camera) so every sprite is seen from ONE camera angle,
exactly like the top-down game.

Usage:
  python tools/render_sheet.py <model.gltf> <out_dir> <chassis> [only_anim] [only_dir]
"""
import bpy, sys, os, math, shutil
import numpy as np
from mathutils import Vector

model = os.path.abspath(sys.argv[1])
out_dir = os.path.abspath(sys.argv[2])   # bpy resolves relative render paths oddly -> force absolute
chassis = sys.argv[3]
only_anim = sys.argv[4] if len(sys.argv) > 4 else ""
only_dir = sys.argv[5] if len(sys.argv) > 5 else ""
face_offset = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0   # deg, pre-rotate a mis-oriented model
os.makedirs(out_dir, exist_ok=True)

FRAMES = 8            # frames per sheet (game expects hframes=8)
RES = 192            # px per frame
SAMPLES = 28
ELEV = 56.0          # camera elevation (deg) — 3/4 top-down
# game anim -> glTF action name (fallbacks handled below)
ANIM_MAP = [("idle", "Idle"), ("walk", "Walk"), ("run", "Run"),
            ("attack", "Shoot"), ("hit", "HitRecieve_1"), ("die", "Death")]
# direction -> mech yaw about Z (front faces the camera which sits toward -Y)
DIRS = [("front", 0.0), ("right", 90.0), ("back", 180.0), ("left", -90.0)]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=model)

arms = [o for o in scene.objects if o.type == 'ARMATURE']
meshes = [o for o in scene.objects if o.type == 'MESH']
arm = arms[0] if arms else None

# parent all top-level objects to a Root empty at origin so one yaw rotates the whole mech
root = bpy.data.objects.new("Root", None)
scene.collection.objects.link(root)
for o in list(scene.objects):
    if o is not root and o.parent is None:
        o.parent = root

# bbox (rest) for framing/lights/center
mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mn = Vector((min(mn[i], w[i]) for i in range(3)))
        mx = Vector((max(mx[i], w[i]) for i in range(3)))
center = (mn + mx) * 0.5
R = max((mx - mn).x, (mx - mn).y, (mx - mn).z) * 0.5 or 1.0

# --- Frame the camera on the ANIMATED extent, not just the rest pose. The old code sized
# ortho_scale from the rest bbox only, so wide poses (Run kick, Death fall-over) clipped out
# of frame. Walk every anim's sampled frames through the depsgraph, take the max vertex
# distance from `center` (a yaw+tilt-invariant bounding-sphere radius) PER ANIM.
# Loco/combat poses (idle/walk/run/attack/hit) share ONE tight frame so the live mech never
# changes size on screen; DEATH (a terminal fall-over) gets its own wider frame so it doesn't
# clip -- the tiny scale change at the moment of death is hidden by the game-over transition.
GAMEPLAY = {"idle", "walk", "run", "attack", "hit"}
_acts = {a.name: a for a in bpy.data.actions}
def _set_act_for_bounds(name):
    a = _acts.get(name)
    if a is None or arm is None:
        return None
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = a
    return a
cen = np.array(center, dtype=np.float32)
rs_anim = {}   # game_anim -> bounding-sphere radius over its sampled frames
for _ganim, _gname in ANIM_MAP:
    a = _set_act_for_bounds(_gname) or _set_act_for_bounds("Idle")
    if a is None:
        continue
    f0, f1 = a.frame_range
    span = max(1.0, f1 - f0)
    rs = float(R)   # never shrink below the rest half-extent
    for i in range(FRAMES):
        scene.frame_set(int(round(f0 + i * span / FRAMES)))
        dg = bpy.context.evaluated_depsgraph_get()
        for o in meshes:
            oe = o.evaluated_get(dg)
            me = oe.to_mesh()
            n = len(me.vertices)
            if n:
                co = np.empty(n * 3, dtype=np.float32); me.vertices.foreach_get("co", co)
                co = co.reshape(-1, 3)
                mw = np.array(oe.matrix_world, dtype=np.float32)
                wco = co @ mw[:3, :3].T + mw[:3, 3]
                rs = max(rs, float(np.linalg.norm(wco - cen, axis=1).max()))
            oe.to_mesh_clear()
    rs_anim[_ganim] = rs
scene.frame_set(1)
rs_play = max([rs_anim[k] for k in rs_anim if k in GAMEPLAY] or [float(R)])
def ortho_for(game_anim):
    r = rs_play if game_anim in GAMEPLAY else rs_anim.get(game_anim, rs_play)
    return 2.0 * r * 1.06
print("FRAMING rs_play=%.3f rs_anim=%s" % (rs_play, {k: round(v, 2) for k, v in rs_anim.items()}))

# camera: ortho, tilted top-down from -Y. ortho_scale is set PER ANIM in the render loop.
cam_d = bpy.data.cameras.new("Cam"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = ortho_for("idle")
cam = bpy.data.objects.new("Cam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
el = math.radians(ELEV)
d = Vector((0.0, -math.cos(el), math.sin(el)))
cam.location = center + d * (R * 6.0)
cam.rotation_euler = (center - cam.location).to_track_quat('-Z', 'Y').to_euler()

# lighting
sun_d = bpy.data.lights.new("Sun", 'SUN'); sun_d.energy = 3.4; sun_d.angle = math.radians(4)
sun = bpy.data.objects.new("Sun", sun_d); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(52), math.radians(10), math.radians(-32))
fill_d = bpy.data.lights.new("Fill", 'AREA'); fill_d.energy = R * R * 120.0; fill_d.size = R * 4
fill = bpy.data.objects.new("Fill", fill_d); scene.collection.objects.link(fill)
fill.location = center + Vector((-R*3, R*3, R*4)); fill.rotation_euler = (math.radians(45), 0, math.radians(45))
world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.06, 0.065, 0.08, 1.0); bg.inputs[1].default_value = 0.35

scene.render.engine = 'CYCLES'; scene.cycles.device = 'CPU'; scene.cycles.samples = SAMPLES
scene.render.film_transparent = True
scene.render.resolution_x = RES; scene.render.resolution_y = RES
scene.render.image_settings.file_format = 'PNG'; scene.render.image_settings.color_mode = 'RGBA'

actions = {a.name: a for a in bpy.data.actions}

def set_action(name):
    if arm is None:
        return None
    act = actions.get(name)
    if act is None:
        return None
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    return act

def composite(frame_paths, out_path):
    from PIL import Image
    imgs = [Image.open(p).convert("RGBA") for p in frame_paths]
    w, h = imgs[0].size
    sheet = Image.new("RGBA", (w * len(imgs), h), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        sheet.paste(im, (i * w, 0))
    sheet.save(out_path)

tmp = os.path.join(out_dir, "_tmp"); os.makedirs(tmp, exist_ok=True)
done = 0
for game_anim, gltf_name in ANIM_MAP:
    if only_anim and game_anim != only_anim:
        continue
    act = set_action(gltf_name)
    if act is None:
        # fallback: idle for missing
        act = set_action("Idle")
        if act is None:
            continue
    cam_d.ortho_scale = ortho_for(game_anim)   # gameplay poses share a tight frame; die gets its own
    f0, f1 = act.frame_range
    span = max(1.0, f1 - f0)
    frames = [int(round(f0 + i * span / FRAMES)) for i in range(FRAMES)]  # 8 frames over one cycle
    for dname, yaw in DIRS:
        if only_dir and dname != only_dir:
            continue
        root.rotation_euler = (0.0, 0.0, math.radians(yaw + face_offset))
        fps = []
        for k, fr in enumerate(frames):
            scene.frame_set(fr)
            fp = os.path.join(tmp, "f%d.png" % k)
            scene.render.filepath = fp
            bpy.ops.render.render(write_still=True)
            fps.append(fp)
        out = os.path.join(out_dir, "%s_%s_%s.png" % (chassis, game_anim, dname))
        composite(fps, out)
        done += 1
        print("SHEET", out)
shutil.rmtree(tmp, ignore_errors=True)   # drop the per-frame temp strip (parity with bake_anim.py)
print("DONE sheets=%d chassis=%s ortho_play=%.3f ortho_die=%.3f" % (done, chassis, ortho_for("idle"), ortho_for("die")))
