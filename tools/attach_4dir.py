# -*- coding: utf-8 -*-
"""Assemblage chassis-jambes + module-haut statique, rendu dans les 4 DIRECTIONS
(front/left/back/right) -> catalogue. Le module est fixe (90,0,180), la CAMERA orbite."""
import bpy, os, sys, math, mathutils, bmesh
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

TOP = os.path.abspath("meshy_in/parts/bicanon/model.glb")
OUTDIR = os.path.abspath("cine/_show/top4dir"); os.makedirs(OUTDIR, exist_ok=True)
TARGET = 1.25; ROT = (42, 0, 0); FWD = -0.03   # bascule avant -> canons vers l'avant/bas
FRAMES = 8; EL = 40.0
DIRS = [("front", 0), ("left", 90), ("back", 180), ("right", -90)]
UPPER = ["Spine","Spine01","Spine02","LeftShoulder","LeftArm","LeftForeArm","LeftHand",
         "RightShoulder","RightArm","RightForeArm","RightHand","neck","Head","head_end","headfront"]

sc = BE.setup()
fl = bpy.data.lights.new("fill2", type="SUN"); fl.energy = 2.0; fl.color = (0.9, 0.92, 1.0)
flo = bpy.data.objects.new("fill2", fl); sc.collection.objects.link(flo); flo.rotation_euler = (math.radians(-58), 0, math.radians(20))
arm = next(o for o in sc.objects if o.type == "ARMATURE")
body = [o for o in sc.objects if o.type == "MESH"]
def strip(obj, bones, th=0.5):
    vg={g.name:g.index for g in obj.vertex_groups}; idx=[vg[b] for b in bones if b in vg]
    if not idx: return
    bm=bmesh.new(); bm.from_mesh(obj.data); dl=bm.verts.layers.deform.active
    if dl is None: bm.free(); return
    kill=[v for v in bm.verts if any(v[dl].get(i,0.0)>th for i in idx)]
    bmesh.ops.delete(bm,geom=kill,context='VERTS'); bm.to_mesh(obj.data); bm.free()
for m in body: strip(m, UPPER)

before=set(o.name for o in sc.objects)
bpy.ops.import_scene.gltf(filepath=TOP)
new=[o for o in sc.objects if o.name not in before]
pm=[o for o in new if o.type=="MESH"]
for o in new:
    if o.type!="MESH":
        try: bpy.data.objects.remove(o,do_unlink=True)
        except Exception: pass
bpy.ops.object.select_all(action='DESELECT')
for o in pm: o.select_set(True)
bpy.context.view_layer.objects.active=pm[0]
if len(pm)>1: bpy.ops.object.join()
top=bpy.context.view_layer.objects.active
bpy.ops.object.select_all(action='DESELECT'); top.select_set(True); bpy.context.view_layer.objects.active=top
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
d=top.dimensions; s=TARGET/max(d.x,d.y,d.z,1e-4); top.scale=(s,s,s)
bpy.ops.object.transform_apply(scale=True)
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
# rotation POSEE (pas apply -> fiable, independant de la selection). 90,0,180 = oeil rouge vers -Y (avant).
top.rotation_mode='XYZ'; top.rotation_euler=tuple(math.radians(a) for a in ROT)
bpy.context.view_layer.update()

def body_top_z():
    dg=bpy.context.evaluated_depsgraph_get(); tz=-1e9
    for o in body:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box: tz=max(tz,(oe.matrix_world@mathutils.Vector(c)).z)
    return tz
BE.pose_walk(arm,0,FRAMES); bpy.context.view_layer.update()
legs_top=body_top_z()
# mesurer le BAS reel du module (bbox monde apres rotation) pour le poser sur les jambes
H0=arm.matrix_world@arm.pose.bones["Hips"].head
top.location=(H0.x, H0.y+FWD, 0.0); bpy.context.view_layer.update()
dgz=bpy.context.evaluated_depsgraph_get(); oez=top.evaluated_get(dgz)
zs=[(oez.matrix_world@mathutils.Vector(c)).z for c in oez.bound_box]
bottom_off = min(zs) - top.location.z    # bas du module par rapport a son origine
OVERLAP = 0.32
SEAT = legs_top - OVERLAP - bottom_off   # bas du module = legs_top - OVERLAP (couvre la decoupe)
print("legs_top", round(legs_top,2), "SEAT", round(SEAT,2))
def place():
    H=arm.matrix_world@arm.pose.bones["Hips"].head
    top.location=(H.x, H.y+FWD, SEAT)
meshes=body+[top]
def fb():
    mn=mathutils.Vector((1e9,)*3); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            wv=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn,mx
BE.pose_walk(arm,2,FRAMES); place(); bpy.context.view_layer.update()
mn0,mx0=fb(); c0=(mn0+mx0)*0.5; size=max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.15
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4.0
def aim(cen,az):
    a=math.radians(az)
    cam.location=(cen.x+dist*math.cos(e)*math.sin(a), cen.y-dist*math.cos(e)*math.cos(a), cen.z+dist*math.sin(e))
    look=cen-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
sc.render.resolution_x=300; sc.render.resolution_y=300
for dname,az in DIRS:
    BE.pose_walk(arm,2,FRAMES); place(); bpy.context.view_layer.update()
    mn,mx=fb(); cen=(mn+mx)*0.5; cen.z=c0.z; aim(cen,az)
    sc.render.filepath=os.path.join(OUTDIR,f"{dname}.png"); bpy.ops.render.render(write_still=True)
    print("DIR",dname)
print("DONE")
