# -*- coding: utf-8 -*-
"""PREUVE etape 1 : couper les bras de Blue Strike (supprimer les sommets peses
sur les os de bras) -> moignon d'epaule propre. Bake FRONT pour voir."""
import bpy, os, sys, math, mathutils, bmesh
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

OUT = os.path.abspath("cine/_show/armless_test.png")
FRAMES = 8; EL = 40.0
ARM_BONES = ["LeftArm","LeftForeArm","LeftHand","RightArm","RightForeArm","RightHand"]

sc = BE.setup()
arm = next(o for o in sc.objects if o.type == "ARMATURE")
meshes = [o for o in sc.objects if o.type == "MESH"]

# print vertex groups of the first mesh (diagnostic)
print("VGROUPS:", [g.name for g in meshes[0].vertex_groups])

def strip_arms(obj, thresh=0.35):
    vg = {g.name: g.index for g in obj.vertex_groups}
    idx = [vg[b] for b in ARM_BONES if b in vg]
    if not idx:
        print("  (no arm groups on", obj.name, ")"); return 0
    bm = bmesh.new(); bm.from_mesh(obj.data)
    dl = bm.verts.layers.deform.active
    if dl is None:
        bm.free(); return 0
    kill = []
    for v in bm.verts:
        w = v[dl]
        if any(w.get(i, 0.0) > thresh for i in idx):
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context='VERTS')
    bm.to_mesh(obj.data); bm.free()
    return len(kill)

total = 0
for m in meshes:
    total += strip_arms(m)
print("REMOVED", total, "verts")

# pose arms-down base (no arms now, but pose the rest) + render
pb = arm.pose.bones
def frame_bounds():
    mn = mathutils.Vector((1e9,)*3); mx = -mn; dg = bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            wv = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn, mx

BE.pose_walk(arm, 0, FRAMES)
mn0, mx0 = frame_bounds(); c0 = (mn0+mx0)*0.5
size = max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
cam_d = bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
cam = bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e = math.radians(EL); dist = size*4.0
def aim(center, az):
    a=math.radians(az)
    cam.location=(center.x+dist*math.cos(e)*math.sin(a), center.y-dist*math.cos(e)*math.cos(a), center.z+dist*math.sin(e))
    look=center-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()

tmp = os.path.abspath("cine/_show/_altmp.png")
tiles=[]
for f in [0,2,4]:
    BE.pose_walk(arm,f,FRAMES); mn,mx=frame_bounds(); cen=(mn+mx)*0.5; cen.z=c0.z; aim(cen,0)
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    tiles.append(Image.open(tmp).convert("RGBA").copy())
canvas=Image.new("RGB",(256*3,256),(24,26,32))
for k,im in enumerate(tiles):
    b=Image.new("RGBA",im.size,(24,26,32,255)); b.alpha_composite(im); canvas.paste(b.convert("RGB"),(k*256,0))
canvas.save(OUT)
if os.path.exists(tmp): os.remove(tmp)
print("SAVED", OUT)
