# -*- coding: utf-8 -*-
"""Batch-render a list of glTF/GLB props to top-down 3/4 sprites (bpy Cycles CPU, no GPU).
ONE bpy process for the whole list (factory-reset between models). Transparent 192px RGBA.
Usage: python tools/render_props_batch.py <models_dir> <out_dir> <name1> <name2> ...
Each <name> -> <models_dir>/<name>.glb  ->  <out_dir>/<name>.png
"""
import bpy, sys, os, math
from mathutils import Vector

models_dir = os.path.abspath(sys.argv[1])
out_dir = os.path.abspath(sys.argv[2])
names = sys.argv[3:]
os.makedirs(out_dir, exist_ok=True)
RES = 192
SAMPLES = 64
ELEV = 55.0

def render_one(model_path, out_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=model_path)
    meshes = [o for o in scene.objects if o.type == 'MESH']
    if not meshes:
        return False
    mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector((min(mn[i], w[i]) for i in range(3)))
            mx = Vector((max(mx[i], w[i]) for i in range(3)))
    center = (mn + mx) * 0.5
    R = max((mx - mn).x, (mx - mn).y, (mx - mn).z) * 0.5 or 1.0
    cam_d = bpy.data.cameras.new("Cam"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = R * 2.3
    cam = bpy.data.objects.new("Cam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
    el = math.radians(ELEV)
    d = Vector((0.0, -math.cos(el), math.sin(el)))
    cam.location = center + d * (R * 6.0)
    cam.rotation_euler = (center - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sun_d = bpy.data.lights.new("Sun", 'SUN'); sun_d.energy = 3.4; sun_d.angle = math.radians(4)
    sun = bpy.data.objects.new("Sun", sun_d); scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), math.radians(12), math.radians(-35))
    fill_d = bpy.data.lights.new("Fill", 'AREA'); fill_d.energy = R * R * 140.0; fill_d.size = R * 4
    fill = bpy.data.objects.new("Fill", fill_d); scene.collection.objects.link(fill)
    fill.location = center + Vector((-R*3, R*3, R*4)); fill.rotation_euler = (math.radians(45), 0, math.radians(45))
    world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.06, 0.065, 0.08, 1.0); bg.inputs[1].default_value = 0.4
    scene.render.engine = 'CYCLES'; scene.cycles.device = 'CPU'; scene.cycles.samples = SAMPLES
    scene.render.film_transparent = True
    scene.render.resolution_x = RES; scene.render.resolution_y = RES
    scene.render.image_settings.file_format = 'PNG'; scene.render.image_settings.color_mode = 'RGBA'
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    return True

done = 0
for name in names:
    mp = os.path.join(models_dir, name + ".glb")
    if not os.path.exists(mp):
        print("MISSING", name); continue
    op = os.path.join(out_dir, name + ".png")
    if render_one(mp, op):
        done += 1
        print("PROP", name)
print("DONE props=%d" % done)
