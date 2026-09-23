# -*- coding: utf-8 -*-
"""Bake un ennemi SPECIAL = Blue Strike dont les MAINS sont remplacees par un
appendice de fonction. Reutilise l'eyebase (yeux jumeaux magenta) + ajoute :
  kamikaze   -> sphere sombre + coeur emissif (bombe)
  invocateur -> boitier sombre + fentes emissives (pod lance-drones)
Les parties SOMBRES -> gunmetal, les parties EMISSIVES CYAN -> accent (via recolor).
Bake FRONT (catalogue). Sortie: meshy_in/bluestrike_eyebase/special_<kind>_front.png"""
import bpy, os, sys, math, mathutils
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

KIND = sys.argv[-1] if len(sys.argv) > 1 else "kamikaze"
OUTDIR = os.path.abspath("meshy_in/bluestrike_eyebase")
RES = 256; FRAMES = 8; EL = 40.0

sc = BE.setup()
sc.view_settings.view_transform = "Standard"   # garder magenta/cyan non desatures (keying)
arm = next(o for o in sc.objects if o.type == "ARMATURE")
meshes = [o for o in sc.objects if o.type == "MESH"]

# --- materials ---
def emissive(name, col, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs["Color"].default_value = (*col, 1); e.inputs["Strength"].default_value = strength
    o = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(e.outputs["Emission"], o.inputs["Surface"]); return m
def dark_metal(name):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.055, 0.06, 0.075, 1)
    b.inputs["Roughness"].default_value = 0.48
    if "Metallic" in b.inputs: b.inputs["Metallic"].default_value = 0.7
    return m

eyemat = emissive("eyekey", (1, 0, 1), 1.3)     # magenta key -> yeux rouges
cyanmat = emissive("appcyan", (0.10, 0.90, 1.0), 2.2)  # cyan -> capte par le masque 'energy' -> accent
darkmat = dark_metal("appdark")

def cube(scale, mat, smooth=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0); o = bpy.context.active_object; o.scale = scale; o.data.materials.append(mat); return o
def sphere(r, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=18, ring_count=10); o = bpy.context.active_object
    o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = True
    return o

# twin eyes
eyeL = cube(BE.EYE_SCALE, eyemat); eyeR = cube(BE.EYE_SCALE, eyemat)

# --- function appendages : list of (obj, side, world_offset) ---
apps = []
for side in ("L", "R"):
    if KIND == "kamikaze":
        body = sphere(0.19, darkmat)          # big warhead orb replacing the hand
        core = sphere(0.11, cyanmat)          # bright volatile core
        apps += [(body, side, mathutils.Vector((0, -0.07, -0.03))),
                 (core, side, mathutils.Vector((0, -0.15, -0.03)))]
    else:  # invocateur : gros pod lance-drones
        body = cube((0.17, 0.24, 0.17), darkmat)
        apps.append((body, side, mathutils.Vector((0, -0.08, -0.02))))
        for k in range(3):
            slot = cube((0.045, 0.028, 0.045), cyanmat)   # fentes/bays lumineuses
            apps.append((slot, side, mathutils.Vector((0, -0.205, -0.075 + 0.075 * k))))

def place_extras():
    hbL = arm.matrix_world @ arm.pose.bones["Head"].head
    eyeL.location = (hbL.x - BE.XSEP, hbL.y + BE.EYE_OFF[1], hbL.z + BE.EYE_OFF[2])
    eyeR.location = (hbL.x + BE.XSEP, hbL.y + BE.EYE_OFF[1], hbL.z + BE.EYE_OFF[2])
    for name, bone in (("L", "LeftHand"), ("R", "RightHand")):
        hw = arm.matrix_world @ arm.pose.bones[bone].head
        for obj, side, off in apps:
            if side == name:
                obj.location = (hw.x + off.x, hw.y + off.y, hw.z + off.z)

def frame_bounds():
    mn = mathutils.Vector((1e9,) * 3); mx = -mn; dg = bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            wv = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3): mn[i] = min(mn[i], wv[i]); mx[i] = max(mx[i], wv[i])
    return mn, mx

BE.pose_walk(arm, 0, FRAMES); place_extras()
mn0, mx0 = frame_bounds(); c0 = (mn0 + mx0) * 0.5
size = max((mx0 - mn0).x, (mx0 - mn0).y, (mx0 - mn0).z, 1e-3)
cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.12
cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
e = math.radians(EL); dist = size * 4.0
def aim(center, az):
    a = math.radians(az)
    cam.location = (center.x + dist * math.cos(e) * math.sin(a), center.y - dist * math.cos(e) * math.cos(a), center.z + dist * math.sin(e))
    look = center - mathutils.Vector(cam.location); cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

tmp = os.path.join(OUTDIR, "_sptmp.png")
tiles = []
for f in range(FRAMES):
    BE.pose_walk(arm, f, FRAMES); place_extras()
    mn, mx = frame_bounds(); cen = (mn + mx) * 0.5; cen.z = c0.z; aim(cen, 0)
    sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
    tiles.append(Image.open(tmp).convert("RGBA").copy())
sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
for k, im in enumerate(tiles): sheet.paste(im, (RES * k, 0), im)
sheet.save(os.path.join(OUTDIR, f"special_{KIND}_front.png"))
if os.path.exists(tmp): os.remove(tmp)
print("SPECIAL", KIND, "done")
