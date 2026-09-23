# -*- coding: utf-8 -*-
"""Chassis jambes + module-haut STATIQUE, orientation corrigee (90,0,180 = avant),
descendu pour COUVRIR le creux de decoupe. Teste plusieurs hauteurs (UP)."""
import bpy, os, sys, math, mathutils, bmesh
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

TOP = os.path.abspath("meshy_in/parts/topturret/model.glb")
OUT = os.path.abspath("cine/_show/attach_top.png")
TARGET = 1.15; ROT = (90, 0, 180); FWD = -0.03
FRAMES = 8; EL = 40.0
UPPER = ["Spine","Spine01","Spine02","LeftShoulder","LeftArm","LeftForeArm","LeftHand",
         "RightShoulder","RightArm","RightForeArm","RightHand","neck","Head","head_end","headfront"]

sc = BE.setup()
# fill light supplementaire (sous-face du module pas noire)
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
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
d=top.dimensions; s=TARGET/max(d.x,d.y,d.z,1e-4); top.scale=(s,s,s); bpy.ops.object.transform_apply(scale=True)

# hauteur du haut des jambes (le creux a couvrir)
def body_top_z():
    dg=bpy.context.evaluated_depsgraph_get(); top_z=-1e9
    for o in body:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            top_z=max(top_z,(oe.matrix_world@mathutils.Vector(c)).z)
    return top_z
BE.pose_walk(arm,0,FRAMES); bpy.context.view_layer.update()
legs_top = body_top_z()
half = top.dimensions.z*0.5
print("legs_top", round(legs_top,3), "turret half-h", round(half,3))

CUR_UP=[0.0]
def place():
    H=arm.matrix_world@arm.pose.bones["Hips"].head
    top.location=(H.x, H.y+FWD, CUR_UP[0])
meshes=body+[top]
def fb():
    mn=mathutils.Vector((1e9,)*3); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            wv=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn,mx
# ancrage cadre sur la version la plus haute
CUR_UP[0]=legs_top+half*0.55; BE.pose_walk(arm,0,FRAMES); place(); bpy.context.view_layer.update()
mn0,mx0=fb(); c0=(mn0+mx0)*0.5; size=max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4.0
def aim(cen):
    cam.location=(cen.x,cen.y-dist*math.cos(e),cen.z+dist*math.sin(e))
    look=cen-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
# overlap: turret bottom = legs_top - overlap  -> center = legs_top - overlap + half
CAND=[("90,0,0",(90,0,0)),("90,0,180",(90,0,180)),("-90,0,180",(-90,0,180))]
seat = legs_top - half*0.15
tmp=os.path.abspath("cine/_show/_toptmp.png"); RES=260
canvas=Image.new("RGB",(RES*3+40,RES+40),(22,24,30)); dr=ImageDraw.Draw(canvas)
for i,(lab,rot) in enumerate(CAND):
    top.rotation_mode='XYZ'; top.rotation_euler=tuple(math.radians(a) for a in rot)
    CUR_UP[0]=seat; BE.pose_walk(arm,0,FRAMES); place(); bpy.context.view_layer.update()
    mn,mx=fb(); cen=(mn+mx)*0.5; cen.z=c0.z; aim(cen)
    sc.render.resolution_x=RES; sc.render.resolution_y=RES
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    im=Image.open(tmp).convert("RGBA"); b=Image.new("RGBA",im.size,(28,30,38,255)); b.alpha_composite(im)
    x=10+i*(RES+10); canvas.paste(b.convert("RGB"),(x,26)); dr.text((x,6),lab,fill=(235,235,245))
canvas.save(OUT)
if os.path.exists(tmp): os.remove(tmp)
print("SAVED",OUT)
