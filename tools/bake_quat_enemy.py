#!/usr/bin/env python3
"""
Bake a Quaternius animated enemy glTF into the game's FRONT-facing enemy sheets:
  game/assets/enemies/<kind>_<game_anim>.png   (N-frame horizontal strip, square frames)
The Enemy system reads these single-direction sheets and detects the frame count from width/height.

  python bake_quat_enemy.py <model.gltf> <kind> <yaw_deg> <anim_specs>
  anim_specs = "game_anim:ActionName:frames,game_anim:ActionName:frames,..."
"""
import bpy, sys, os, math
from mathutils import Vector

MODEL = os.path.abspath(sys.argv[1]); KIND = sys.argv[2]
YAW = math.radians(float(sys.argv[3]))
SPECS = [s.split(":") for s in sys.argv[4].split(",")]
OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "enemies"))
os.makedirs(OUT, exist_ok=True)
RES = 128

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=MODEL)
arm = next((o for o in sc.objects if o.type == "ARMATURE"), None)
meshes = [o for o in sc.objects if o.type == "MESH"]

root = bpy.data.objects.new("Root", None); sc.collection.objects.link(root)
for o in list(sc.objects):
    if o is not root and o.parent is None and o.type in ("ARMATURE", "MESH", "EMPTY"):
        o.parent = root
root.rotation_euler = (0, 0, YAW)          # pre-yaw a mis-oriented model to face the camera

mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mn = Vector((min(mn[i], w[i]) for i in range(3))); mx = Vector((max(mx[i], w[i]) for i in range(3)))
center = (mn + mx) * 0.5
R = max((mx - mn).x, (mx - mn).y, (mx - mn).z) * 0.5 or 1.0

sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 26
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = RES
sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
sc.view_layers[0].cycles.use_denoising = True

world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.3, 0.32, 0.36, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.85

cam_d = bpy.data.cameras.new("c"); cam_d.type = "ORTHO"; cam_d.ortho_scale = R * 2.5
cam = bpy.data.objects.new("c", cam_d); sc.collection.objects.link(cam); sc.camera = cam
el = math.radians(52)                       # 3/4 top-down, like the other enemies
cam.location = center + Vector((0, -math.cos(el), math.sin(el))) * R * 4
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
for nm, loc, e in [("k", (2, -2, 3), 1100), ("f", (-2, -1, 1.5), 380), ("r", (0, 2, 2), 500)]:
    ld = bpy.data.lights.new(nm, "AREA"); ld.energy = e; ld.size = 8
    lo = bpy.data.objects.new(nm, ld); lo.location = center + Vector(loc) * R; sc.collection.objects.link(lo)
    lo.rotation_euler = (center - lo.location).to_track_quat("-Z", "Y").to_euler()

acts = {a.name: a for a in bpy.data.actions}
from PIL import Image
tmp = os.path.join(OUT, "_tmp"); os.makedirs(tmp, exist_ok=True)
for game_anim, action, nframes in SPECS:
    nframes = int(nframes)
    a = acts.get(action)
    if a is None or arm is None:
        print(f"  [skip] {game_anim}: action '{action}' not found"); continue
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = a
    f0, f1 = int(a.frame_range[0]), int(a.frame_range[1])
    paths = []
    for i in range(nframes):
        fr = f0 + round((f1 - f0) * i / max(1, nframes))   # skip the last (loop) frame
        sc.frame_set(fr)
        p = os.path.join(tmp, f"{i}.png"); sc.render.filepath = p
        bpy.ops.render.render(write_still=True); paths.append(p)
    imgs = [Image.open(p).convert("RGBA") for p in paths]
    w, h = imgs[0].size
    sheet = Image.new("RGBA", (w * len(imgs), h), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        sheet.paste(im, (i * w, 0))
    sheet.save(os.path.join(OUT, f"{KIND}_{game_anim}.png"))
    print(f"  {KIND}_{game_anim}.png ({len(imgs)}f from {action})")
print("DONE", KIND)
