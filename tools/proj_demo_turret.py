# -*- coding: utf-8 -*-
"""Proof-of-concept: camera-project a Gemini decor painting onto a rough Blender proxy so it
becomes a real 3D object (reacts to light, casts shadow). Renders the turret (g27) from the
paint angle under a side key light + a second light angle to show the relief reacting.
Usage: python tools/proj_demo_turret.py <g27.png> <out_dir>"""
import bpy, sys, os, math
from mathutils import Vector

img_path = os.path.abspath(sys.argv[1])
out_dir = os.path.abspath(sys.argv[2]); os.makedirs(out_dir, exist_ok=True)
AZ = math.radians(-48.0); EL = math.radians(33.0)   # iso angle the painting implies

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def cyl(name, r, h, z, verts=8, r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=(r if r2 is None else r2), depth=h, location=(0, 0, z))
    o = bpy.context.active_object; o.name = name; return o

def box(name, sx, sy, sz, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = (sx, sy, sz); o.rotation_euler = rot; return o

# --- rough turret proxy (silhouette ~ matches g27) ---
base_low = cyl("base_low", 1.05, 0.34, 0.17, 8, 0.95)     # wide octagon pedestal
base_top = cyl("base_top", 0.86, 0.16, 0.42, 8, 0.78)     # tapered top of pedestal
ring = cyl("ring", 0.62, 0.12, 0.56, 12)                  # rotating ring
body = box("body", 1.15, 0.95, 0.72, (0.05, 0.02, 0.98), (0, 0, math.radians(6)))  # turret housing
mantlet = cyl("mantlet", 0.42, 0.5, 0.98, 12); mantlet.rotation_euler = (0, math.radians(90), 0)
for i, dx in enumerate((-0.16, 0.16)):                    # twin barrels, angled down-left
    b = cyl("barrel%d" % i, 0.055, 1.15, 0.0, 10)
    b.rotation_euler = (math.radians(90), 0, 0)
    b.location = (-0.75 + dx * 0.4, -0.55, 0.86)
    b.rotation_euler = (math.radians(72), 0, math.radians(20))

meshes = [o for o in scene.objects if o.type == 'MESH']
# join into one for simple projection
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
turret = bpy.context.active_object
bpy.ops.object.shade_smooth();
for p in turret.data.polygons:
    p.use_smooth = False   # hard-surface flat facets take the projection cleaner

# bbox center for framing
mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
for c in turret.bound_box:
    w = turret.matrix_world @ Vector(c)
    mn = Vector((min(mn[i], w[i]) for i in range(3))); mx = Vector((max(mx[i], w[i]) for i in range(3)))
center = (mn + mx) * 0.5; R = max((mx-mn).x, (mx-mn).y, (mx-mn).z)*0.5

# --- projector camera at the paint angle ---
proj_d = bpy.data.cameras.new("Proj"); proj_d.type = 'ORTHO'; proj_d.ortho_scale = R*2.15
proj = bpy.data.objects.new("Proj", proj_d); scene.collection.objects.link(proj)
d = Vector((math.sin(AZ)*math.cos(EL), -math.cos(AZ)*math.cos(EL), math.sin(EL)))
proj.location = center + d*(R*8); proj.rotation_euler = (center-proj.location).to_track_quat('-Z', 'Y').to_euler()

# --- UV Project modifier: project the painting from the projector cam ---
uvl = turret.data.uv_layers.new(name="proj")
mod = turret.modifiers.new("UVProj", 'UV_PROJECT'); mod.uv_layer = "proj"
mod.projector_count = 1; mod.projectors[0].object = proj
mod.aspect_x = 1.0; mod.aspect_y = 1.0

# --- material: painting as base colour ---
img = bpy.data.images.load(img_path)
mat = bpy.data.materials.new("Skin"); mat.use_nodes = True; turret.data.materials.append(mat)
nt = mat.node_tree; bsdf = nt.nodes.get("Principled BSDF")
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.extension = 'CLIP'
uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = "proj"
nt.links.new(uvn.outputs["UV"], tex.inputs["Vector"])
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
bsdf.inputs["Roughness"].default_value = 0.62
bsdf.inputs["Metallic"].default_value = 0.15
mat.blend_method = 'CLIP'

scene.render.engine = 'CYCLES'; scene.cycles.device = 'CPU'; scene.cycles.samples = 48
scene.render.film_transparent = True
scene.render.resolution_x = 384; scene.render.resolution_y = 384
scene.render.image_settings.file_format = 'PNG'; scene.render.image_settings.color_mode = 'RGBA'
scene.camera = proj   # render from the paint angle so the skin aligns

world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg: bg.inputs[0].default_value = (0.06,0.07,0.09,1); bg.inputs[1].default_value = 0.5

def sun(az, el, energy):
    sd = bpy.data.lights.new("S", 'SUN'); sd.energy = energy; sd.angle = math.radians(3)
    s = bpy.data.objects.new("S", sd); scene.collection.objects.link(s)
    s.rotation_euler = (math.radians(90-el), 0, math.radians(az)); return s

# render under 3 light directions -> shows the geometry reacting (the "3D" proof)
for i, (az, el) in enumerate([(-60, 55), (30, 40), (120, 50)]):
    for s in [o for o in scene.objects if o.type == 'LIGHT']:
        bpy.data.objects.remove(s, do_unlink=True)
    sun(az, el, 3.6); sun(az+150, 25, 1.1)
    scene.render.filepath = os.path.join(out_dir, "turret3d_%d.png" % i)
    bpy.ops.render.render(write_still=True)
    print("RENDER light", i)
print("DONE")
