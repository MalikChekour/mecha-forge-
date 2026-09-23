# -*- coding: utf-8 -*-
"""PREUVE etape 2 : greffer la piece 3D generee (bras-ogive TRELLIS) sur le
Blue Strike SANS bras. Bake FRONT pour voir. Rotation/scale/offset en tete pour iterer."""
import bpy, os, sys, math, mathutils, bmesh
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

PART = os.path.abspath("meshy_in/parts/bombarm/model.glb")
OUT = os.path.abspath("cine/_show/attach_test.png")
TARGET = 0.98          # taille cible de la piece (unites)
ROT = (0, 0, 0)        # gltf up->Z, front->camera : pas de rotation
OFF = (0.07, -0.03, -0.30)  # offset depuis l'epaule (vers l'exterieur + bas)
FRAMES = 8; EL = 40.0
ARM_BONES = ["LeftArm","LeftForeArm","LeftHand","RightArm","RightForeArm","RightHand"]

sc = BE.setup()
arm = next(o for o in sc.objects if o.type == "ARMATURE")
body_meshes = [o for o in sc.objects if o.type == "MESH"]

# --- 1) couper les bras ---
def strip_arms(obj, thresh=0.35):
    vg = {g.name: g.index for g in obj.vertex_groups}
    idx = [vg[b] for b in ARM_BONES if b in vg]
    if not idx: return
    bm = bmesh.new(); bm.from_mesh(obj.data); dl = bm.verts.layers.deform.active
    if dl is None: bm.free(); return
    kill = [v for v in bm.verts if any(v[dl].get(i,0.0) > thresh for i in idx)]
    bmesh.ops.delete(bm, geom=kill, context='VERTS'); bm.to_mesh(obj.data); bm.free()
for m in body_meshes: strip_arms(m)

# --- 2) importer + normaliser la piece ---
before = set(o.name for o in sc.objects)
bpy.ops.import_scene.gltf(filepath=PART)
new = [o for o in sc.objects if o.name not in before]
pmesh = [o for o in new if o.type == "MESH"]
for o in new:
    if o.type != "MESH":
        try: bpy.data.objects.remove(o, do_unlink=True)
        except Exception: pass
bpy.ops.object.select_all(action='DESELECT')
for o in pmesh: o.select_set(True)
bpy.context.view_layer.objects.active = pmesh[0]
if len(pmesh) > 1: bpy.ops.object.join()
part = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
part.rotation_euler = tuple(math.radians(a) for a in ROT)
bpy.ops.object.transform_apply(rotation=True)
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
d = part.dimensions; mx = max(d.x, d.y, d.z, 1e-4)
s = TARGET / mx; part.scale = (s, s, s)
bpy.ops.object.transform_apply(scale=True)
partL = part
partR = part.copy(); partR.data = part.data.copy(); sc.collection.objects.link(partR)

def place():
    L = arm.matrix_world @ arm.pose.bones["LeftArm"].head
    R = arm.matrix_world @ arm.pose.bones["RightArm"].head
    partL.location = (L.x + OFF[0], L.y + OFF[1], L.z + OFF[2])
    partR.location = (R.x - OFF[0], R.y + OFF[1], R.z + OFF[2])

meshes = body_meshes + [partL, partR]
def frame_bounds():
    mn = mathutils.Vector((1e9,)*3); mx = -mn; dg = bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            wv = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn, mx

BE.pose_walk(arm, 0, FRAMES); place()
mn0, mx0 = frame_bounds(); c0 = (mn0+mx0)*0.5
size = max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
cam_d = bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
cam = bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e = math.radians(EL); dist = size*4.0
def aim(center, az):
    a=math.radians(az)
    cam.location=(center.x+dist*math.cos(e)*math.sin(a), center.y-dist*math.cos(e)*math.cos(a), center.z+dist*math.sin(e))
    look=center-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()

tmp = os.path.abspath("cine/_show/_attmp.png"); tiles=[]
for f in [0,3]:
    BE.pose_walk(arm,f,FRAMES); place(); mn,mx=frame_bounds(); cen=(mn+mx)*0.5; cen.z=c0.z; aim(cen,0)
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    tiles.append(Image.open(tmp).convert("RGBA").copy())
canvas=Image.new("RGB",(256*2,256),(24,26,32))
for k,im in enumerate(tiles):
    b=Image.new("RGBA",im.size,(24,26,32,255)); b.alpha_composite(im); canvas.paste(b.convert("RGB"),(k*256,0))
canvas.save(OUT)
if os.path.exists(tmp): os.remove(tmp)
print("SAVED", OUT)
