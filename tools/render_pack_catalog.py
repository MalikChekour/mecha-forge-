#!/usr/bin/env python3
"""
Batch-render every glTF in a folder to a preview PNG, IN ONE Blender session (amortises the
~3s bpy startup). Models that carry an animation get a short FRAME SEQUENCE rendered instead of
a single still, which a post-step turns into a looping GIF.

  blender/py:  python render_pack_catalog.py <in_dir> <out_dir> [res] [samples] [anim_frames]
Static model  -> <out_dir>/<name>.png
Animated model-> <out_dir>/<name>__f00.png .. __fNN.png   (assemble to GIF afterwards)
"""
import bpy, sys, os, math, glob, mathutils

IN = sys.argv[1]; OUT = sys.argv[2]
RES = int(sys.argv[3]) if len(sys.argv) > 3 else 200
SAMPLES = int(sys.argv[4]) if len(sys.argv) > 4 else 12
AF = int(sys.argv[5]) if len(sys.argv) > 5 else 10
os.makedirs(OUT, exist_ok=True)

sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = SAMPLES
sc.render.resolution_x = sc.render.resolution_y = RES
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.view_layers[0].cycles.use_denoising = True

# world: soft ambient so textures read (a bit brighter than the default bake)
world = bpy.data.worlds.new("w"); sc.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.28, 0.30, 0.34, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.9

# camera (orthographic, 3/4 top-down)
cam_d = bpy.data.cameras.new("c"); cam_d.type = "ORTHO"
cam = bpy.data.objects.new("c", cam_d); sc.collection.objects.link(cam); sc.camera = cam
el = math.radians(38); az = math.radians(28)

# key + fill lights
for name, e, rot, pw in [("key", (1.2, -1.5, 2.2), 0, 900), ("fill", (-1.5, -1.0, 1.2), 0, 300),
                          ("rim", (0.5, 1.6, 1.4), 0, 400)]:
    ld = bpy.data.lights.new(name, "AREA"); ld.energy = pw; ld.size = 6
    lo = bpy.data.objects.new(name, ld); lo.location = e; sc.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(50), 0, math.radians(30))

def clear_imported():
    for o in list(bpy.data.objects):
        if o.type in ("MESH", "ARMATURE", "EMPTY"):
            bpy.data.objects.remove(o, do_unlink=True)

def fit_and_render(name, animated, frange):
    # bbox of all meshes
    mins = mathutils.Vector((1e9,)*3); maxs = mathutils.Vector((-1e9,)*3)
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mins[i] = min(mins[i], w[i]); maxs[i] = max(maxs[i], w[i])
    center = (mins + maxs) / 2
    size = max((maxs - mins).x, (maxs - mins).y, (maxs - mins).z, 0.1)
    cam.data.ortho_scale = size * 1.5
    d = size * 3
    cam.location = center + mathutils.Vector((math.sin(az)*math.cos(el), -math.cos(az)*math.cos(el), math.sin(el))) * d
    dir = (center - cam.location).normalized()
    cam.rotation_euler = dir.to_track_quat("-Z", "Y").to_euler()
    if animated and frange:
        f0, f1 = int(frange[0]), int(frange[1])
        for i in range(AF):
            fr = f0 + round((f1 - f0) * i / max(1, AF - 1))
            sc.frame_set(fr)
            sc.render.filepath = os.path.join(OUT, f"{name}__f{i:02d}.png")
            bpy.ops.render.render(write_still=True)
    else:
        sc.render.filepath = os.path.join(OUT, f"{name}.png")
        bpy.ops.render.render(write_still=True)

# os.walk (not glob): the pack path contains "[Standard]" and glob treats [..] as a char class.
files = []
for root, _, fs in os.walk(IN):
    for fn in fs:
        if fn.lower().endswith((".gltf", ".glb")):
            files.append(os.path.join(root, fn))
files = sorted(files)
print(f"CATALOG: {len(files)} models -> {OUT}")
for i, f in enumerate(files):
    name = os.path.splitext(os.path.basename(f))[0]
    clear_imported()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    try:
        bpy.ops.import_scene.gltf(filepath=f)
    except Exception as e:
        print(f"  [skip] {name}: {e}"); continue
    frange = None
    animated = len(bpy.data.actions) > 0
    if animated:
        fr = bpy.data.actions[0].frame_range
        frange = (fr[0], fr[1])
        if frange[1] - frange[0] < 2:
            animated = False
    fit_and_render(name, animated, frange)
    print(f"  [{i+1}/{len(files)}] {name} {'ANIM' if animated else 'static'}")
print("DONE")
