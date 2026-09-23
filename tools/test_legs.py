# -*- coding: utf-8 -*-
"""IDEE PATRON : garder le CHASSIS (jambes+bassin, anime) et virer tout le HAUT.
Etape 1 : ne garder que les jambes -> bake FRONT pour voir le walker nu."""
import bpy, os, sys, math, mathutils, bmesh
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

OUT = os.path.abspath("cine/_show/legs_test.png")
FRAMES = 8; EL = 40.0
# tout le haut du corps (garde Hips + jambes)
UPPER = ["Spine","Spine01","Spine02","LeftShoulder","LeftArm","LeftForeArm","LeftHand",
         "RightShoulder","RightArm","RightForeArm","RightHand","neck","Head","head_end","headfront"]

sc = BE.setup()
arm = next(o for o in sc.objects if o.type == "ARMATURE")
meshes = [o for o in sc.objects if o.type == "MESH"]

def strip(obj, bones, th=0.5):
    vg = {g.name: g.index for g in obj.vertex_groups}
    idx = [vg[b] for b in bones if b in vg]
    if not idx: return 0
    bm = bmesh.new(); bm.from_mesh(obj.data); dl = bm.verts.layers.deform.active
    if dl is None: bm.free(); return 0
    kill = [v for v in bm.verts if any(v[dl].get(i,0.0) > th for i in idx)]
    bmesh.ops.delete(bm, geom=kill, context='VERTS'); bm.to_mesh(obj.data); bm.free()
    return len(kill)
tot = sum(strip(m, UPPER) for m in meshes)
print("REMOVED", tot, "verts (haut du corps)")

def fb():
    mn = mathutils.Vector((1e9,)*3); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            wv=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn,mx
BE.pose_walk(arm,0,FRAMES); mn0,mx0=fb(); c0=(mn0+mx0)*0.5
size=max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.15
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4.0
def aim(cen):
    cam.location=(cen.x,cen.y-dist*math.cos(e),cen.z+dist*math.sin(e))
    look=cen-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
tmp=os.path.abspath("cine/_show/_legtmp.png"); tiles=[]
for f in [0,2,4,6]:
    BE.pose_walk(arm,f,FRAMES); mn,mx=fb(); cen=(mn+mx)*0.5; cen.z=c0.z; aim(cen)
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    tiles.append(Image.open(tmp).convert("RGBA").copy())
W=tiles[0].width
canvas=Image.new("RGB",(W*4,tiles[0].height),(24,26,32))
for k,im in enumerate(tiles):
    b=Image.new("RGBA",im.size,(24,26,32,255)); b.alpha_composite(im); canvas.paste(b.convert("RGB"),(k*W,0))
canvas.save(OUT)
if os.path.exists(tmp): os.remove(tmp)
print("SAVED",OUT)
