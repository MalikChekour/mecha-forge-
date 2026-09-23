# -*- coding: utf-8 -*-
"""MINI-BOSS = mecha a OGIVES : Blue Strike (torse+tete+jambes) + 2 ogives (bombarm TRELLIS)
sur les epaules + yeux rouges. Bake 4-dir. MODE: front (verif) | bake (4 dir -> raw_<dir>.png)."""
import bpy, os, sys, math, mathutils, bmesh
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

PART = os.path.abspath("meshy_in/parts/bombarm/model.glb")
OUTDIR = os.path.abspath("cine/_show/boss"); os.makedirs(OUTDIR, exist_ok=True)
OUT1 = os.path.abspath("cine/_show/boss_test.png")
ARM_BONES = ["LeftArm","LeftForeArm","LeftHand","RightArm","RightForeArm","RightHand"]
TARGET = 1.02; ROT = (0, 0, 0); OFF = (0.09, -0.03, -0.28)
FRAMES = 8; EL = 40.0
DIRS = [("front",0),("left",90),("back",180),("right",-90)]
MODE = sys.argv[1] if len(sys.argv) > 1 else "front"

sc = BE.setup(); sc.view_settings.view_transform = "Standard"
arm = next(o for o in sc.objects if o.type == "ARMATURE")
body = [o for o in sc.objects if o.type == "MESH"]
def strip(obj, bones, th=0.35):
    vg={g.name:g.index for g in obj.vertex_groups}; idx=[vg[b] for b in bones if b in vg]
    if not idx: return
    bm=bmesh.new(); bm.from_mesh(obj.data); dl=bm.verts.layers.deform.active
    if dl is None: bm.free(); return
    kill=[v for v in bm.verts if any(v[dl].get(i,0.0)>th for i in idx)]
    bmesh.ops.delete(bm,geom=kill,context='VERTS'); bm.to_mesh(obj.data); bm.free()
for m in body: strip(m, ARM_BONES)

# yeux rouges (cle magenta)
eyemat=bpy.data.materials.new("eyekey"); eyemat.use_nodes=True; nt=eyemat.node_tree; nt.nodes.clear()
em=nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value=(1,0,1,1); em.inputs["Strength"].default_value=1.3
mo=nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(em.outputs["Emission"],mo.inputs["Surface"])
def cube(scale,mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0); o=bpy.context.active_object; o.scale=scale; o.data.materials.append(mat); return o
eyeL=cube(BE.EYE_SCALE,eyemat); eyeR=cube(BE.EYE_SCALE,eyemat)

def load_part():
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
    c=bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
    d=c.dimensions; s=TARGET/max(d.x,d.y,d.z,1e-4); c.scale=(s,s,s)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
    return c
partL=load_part()
partR=partL.copy(); partR.data=partL.data.copy(); sc.collection.objects.link(partR)
partL.rotation_mode='XYZ'; partR.rotation_mode='XYZ'
partL.rotation_euler=tuple(math.radians(a) for a in ROT); partR.rotation_euler=tuple(math.radians(a) for a in ROT)

def place():
    hL=arm.matrix_world@arm.pose.bones["Head"].head
    eyeL.location=(hL.x-BE.XSEP, hL.y+BE.EYE_OFF[1], hL.z+BE.EYE_OFF[2])
    eyeR.location=(hL.x+BE.XSEP, hL.y+BE.EYE_OFF[1], hL.z+BE.EYE_OFF[2])
    L=arm.matrix_world@arm.pose.bones["LeftArm"].head; R=arm.matrix_world@arm.pose.bones["RightArm"].head
    partL.location=(L.x+OFF[0], L.y+OFF[1], L.z+OFF[2])
    partR.location=(R.x-OFF[0], R.y+OFF[1], R.z+OFF[2])
meshes=body+[partL,partR,eyeL,eyeR]
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
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.16
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4.0
def aim(cen,az):
    a=math.radians(az)
    cam.location=(cen.x+dist*math.cos(e)*math.sin(a), cen.y-dist*math.cos(e)*math.cos(a), cen.z+dist*math.sin(e))
    look=cen-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
tmp=os.path.abspath("cine/_show/_btmp.png")
if MODE=="bake":
    RES=256; sc.render.resolution_x=RES; sc.render.resolution_y=RES
    for dname,az in DIRS:
        tiles=[]
        for f in range(FRAMES):
            BE.pose_walk(arm,f,FRAMES); place(); bpy.context.view_layer.update()
            aim(c0,az); sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(tmp).convert("RGBA").copy())
        sheet=Image.new("RGBA",(RES*FRAMES,RES),(0,0,0,0))
        for k,im in enumerate(tiles): sheet.paste(im,(k*RES,0),im)
        sheet.save(os.path.join(OUTDIR,f"raw_{dname}.png")); print("BAKE",dname)
else:
    sc.render.resolution_x=320; sc.render.resolution_y=320
    BE.pose_walk(arm,2,FRAMES); place(); bpy.context.view_layer.update()
    aim(c0,0); sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    im=Image.open(tmp).convert("RGBA"); b=Image.new("RGBA",im.size,(24,26,32,255)); b.alpha_composite(im); b.convert("RGB").save(OUT1)
if os.path.exists(tmp): os.remove(tmp)
print("DONE")
