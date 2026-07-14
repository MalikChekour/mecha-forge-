# -*- coding: utf-8 -*-
"""Render a glTF/GLB model to a top-down 3/4 sprite via bpy Cycles CPU (no-GPU server).
Usage: python tools/render_quaternius.py <model.gltf> <out.png> [azimuth_deg] [frame]
Imports into a fresh scene, frames the model with an ORTHO camera tilted ~55deg (survivor
top-down look), lights it (sun key + area fill + soft ambient), transparent film, 512px RGBA."""
import bpy, sys, math
from mathutils import Vector

model_path = sys.argv[1]
out_path = sys.argv[2]
az_deg = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
frame = int(sys.argv[4]) if len(sys.argv) > 4 else 1

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# import (glTF/GLB)
if model_path.lower().endswith((".gltf", ".glb")):
    bpy.ops.import_scene.gltf(filepath=model_path)
elif model_path.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=model_path)
elif model_path.lower().endswith(".obj"):
    bpy.ops.wm.obj_import(filepath=model_path)

meshes = [o for o in scene.objects if o.type == 'MESH']
mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
        mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
center = (mn + mx) * 0.5
size = (mx - mn)
R = max(size.x, size.y, size.z) * 0.5 or 1.0

# ORTHO camera, tilted top-down 3/4
cam_data = bpy.data.cameras.new("Cam"); cam_data.type = 'ORTHO'
cam_data.ortho_scale = R * 2.5
cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
scene.camera = cam
el = math.radians(55.0); az = math.radians(az_deg)
d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
cam.location = center + d * (R * 6.0)
cam.rotation_euler = (center - cam.location).to_track_quat('-Z', 'Y').to_euler()

# lighting
sun_d = bpy.data.lights.new("Sun", 'SUN'); sun_d.energy = 3.2; sun_d.angle = math.radians(3)
sun = bpy.data.objects.new("Sun", sun_d); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(52), math.radians(12), math.radians(-35))
fill_d = bpy.data.lights.new("Fill", 'AREA'); fill_d.energy = R * R * 120.0; fill_d.size = R * 4
fill = bpy.data.objects.new("Fill", fill_d); scene.collection.objects.link(fill)
fill.location = center + Vector((-R * 3, R * 3, R * 4))
fill.rotation_euler = (math.radians(45), 0, math.radians(45))
world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.05, 0.055, 0.07, 1.0)
    bg.inputs[1].default_value = 0.35

scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 96
scene.render.film_transparent = True
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.filepath = out_path
try:
    scene.frame_set(frame)
except Exception:
    pass
bpy.ops.render.render(write_still=True)
print("RENDERED", out_path, "R=%.2f" % R, "meshes=%d" % len(meshes))
