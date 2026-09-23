# -*- coding: utf-8 -*-
"""Greffe une piece + teste plusieurs ORIENTATIONS (grille) sur Blue Strike sans bras.
Usage: python tools/graft_grid.py meshy_in/parts/<part>/model.glb"""
import bpy, os, sys, math, mathutils, bmesh
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

PART = sys.argv[1] if len(sys.argv) > 1 else "meshy_in/parts/cannonarm/model.glb"
PART = os.path.abspath(PART)
OUT = os.path.abspath("cine/_show/graft_grid.png")
TARGET = 0.86; OFF = (0.08, -0.03, -0.26); EL = 40.0
ROTS = [("Rz-90",(0,0,-90)), ("Rz90",(0,0,90)), ("Ry90",(0,90,0)),
        ("Ry-90",(0,-90,0)), ("Rz-90 Rx35",(35,0,-90)), ("Rz-90 Rx-35",(-35,0,-90))]
ARM_BONES = ["LeftArm","LeftForeArm","LeftHand","RightArm","RightForeArm","RightHand"]

sc = BE.setup()
arm = next(o for o in sc.objects if o.type == "ARMATURE")
body = [o for o in sc.objects if o.type == "MESH"]
def strip(obj, th=0.35):
    vg = {g.name: g.index for g in obj.vertex_groups}; idx=[vg[b] for b in ARM_BONES if b in vg]
    if not idx: return
    bm=bmesh.new(); bm.from_mesh(obj.data); dl=bm.verts.layers.deform.active
    if dl is None: bm.free(); return
    kill=[v for v in bm.verts if any(v[dl].get(i,0.0)>th for i in idx)]
    bmesh.ops.delete(bm,geom=kill,context='VERTS'); bm.to_mesh(obj.data); bm.free()
for m in body: strip(m)

before=set(o.name for o in sc.objects)
bpy.ops.import_scene.gltf(filepath=PART)
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
part=bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
d=part.dimensions; s=TARGET/max(d.x,d.y,d.z,1e-4); part.scale=(s,s,s)
bpy.ops.object.transform_apply(scale=True)
print("PART DIMS (x,y,z):", tuple(round(v,3) for v in part.dimensions))
partR=part.copy(); partR.data=part.data.copy(); sc.collection.objects.link(partR); partL=part

def place():
    L=arm.matrix_world@arm.pose.bones["LeftArm"].head; R=arm.matrix_world@arm.pose.bones["RightArm"].head
    partL.location=(L.x+OFF[0],L.y+OFF[1],L.z+OFF[2]); partR.location=(R.x-OFF[0],R.y+OFF[1],R.z+OFF[2])
meshes=body+[partL,partR]
def fb():
    mn=mathutils.Vector((1e9,)*3); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            wv=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn,mx
BE.pose_walk(arm,0,8); place(); mn0,mx0=fb(); c0=(mn0+mx0)*0.5
size=max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.2
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4.0
def aim(cen):
    cam.location=(cen.x,cen.y-dist*math.cos(e),cen.z+dist*math.sin(e))
    look=cen-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
tmp=os.path.abspath("cine/_show/_ggtmp.png"); RES=230
canvas=Image.new("RGB",(RES*3+40,RES*2+50),(22,24,30)); dr=ImageDraw.Draw(canvas)
for i,(lab,rot) in enumerate(ROTS):
    partL.rotation_mode='XYZ'; partR.rotation_mode='XYZ'
    partL.rotation_euler=tuple(math.radians(a) for a in rot); partR.rotation_euler=tuple(math.radians(a) for a in rot)
    BE.pose_walk(arm,0,8); place()
    bpy.context.view_layer.update()
    mn,mx=fb(); cen=(mn+mx)*0.5; cen.z=c0.z; aim(cen)
    sc.render.resolution_x=RES; sc.render.resolution_y=RES
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    im=Image.open(tmp).convert("RGBA"); b=Image.new("RGBA",im.size,(28,30,38,255)); b.alpha_composite(im)
    x=10+(i%3)*(RES+10); y=28+(i//3)*(RES+22)
    canvas.paste(b.convert("RGB"),(x,y)); dr.text((x,y-16),lab,fill=(235,235,245))
canvas.save(OUT)
if os.path.exists(tmp): os.remove(tmp)
print("SAVED",OUT)
