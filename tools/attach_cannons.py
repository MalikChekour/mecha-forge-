# -*- coding: utf-8 -*-
"""Blue Strike (torse+tete+jambes GARDES) - BRAS remplaces par 2 canons MODELISES
en Blender (barillets construits pointant -Y = AVANT, orientation garantie) + yeux rouges.
Rend FRONT d'abord (verif), puis 4 DIRS."""
import bpy, os, sys, math, mathutils, bmesh
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

OUTDIR = os.path.abspath("cine/_show/cannons4"); os.makedirs(OUTDIR, exist_ok=True)
OUT = os.path.abspath("cine/_show/cannons_test.png")
ARM_BONES = ["LeftArm","LeftForeArm","LeftHand","RightArm","RightForeArm","RightHand"]
CAN_OFF = (0.02, -0.02, -0.05)   # mount depuis l'epaule
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

# --- materials ---
def emissive(col,strength):
    m=bpy.data.materials.new("e"); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    e=nt.nodes.new("ShaderNodeEmission"); e.inputs["Color"].default_value=(*col,1); e.inputs["Strength"].default_value=strength
    o=nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(e.outputs["Emission"],o.inputs["Surface"]); return m
def darkmetal():
    m=bpy.data.materials.new("dm"); m.use_nodes=True; b=m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value=(0.05,0.055,0.07,1); b.inputs["Roughness"].default_value=0.42
    if "Metallic" in b.inputs: b.inputs["Metallic"].default_value=0.8
    return m
DARK=darkmetal(); GLOW=emissive((0.1,0.9,1.0),2.4); eyemat=emissive((1,0,1),1.3)

def cube(scale,mat,loc=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0); o=bpy.context.active_object; o.scale=scale; o.location=loc; o.data.materials.append(mat); return o
def cyl(r,depth,mat,loc=(0,0,0),rot=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r,depth=depth,vertices=18); o=bpy.context.active_object
    o.location=loc; o.rotation_euler=tuple(math.radians(a) for a in rot); o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth=True
    return o

eyeL=cube(BE.EYE_SCALE,eyemat); eyeR=cube(BE.EYE_SCALE,eyemat)

def build_cannon():
    """Construit un canon bi-barillet a l'origine, barillets pointant -Y (avant)."""
    parts=[]
    parts.append(cube((0.13,0.17,0.13),DARK,(0,-0.03,0)))          # housing
    parts.append(cyl(0.065,0.11,DARK,(0,0.03,0.11),(0,0,0)))        # ammo drum (sur le dessus, axe Z)
    for bx in (0.05,-0.05):                                          # 2 barillets -> -Y (PLUS LONGS)
        parts.append(cyl(0.042,0.70,DARK,(bx,-0.46,0.0),(90,0,0)))   # barillet long
        parts.append(cyl(0.03,0.30,DARK,(bx,-0.30,0.055),(90,0,0)))  # rail/gaine dessus (detail)
        parts.append(cyl(0.055,0.06,DARK,(bx,-0.78,0.0),(90,0,0)))   # frein de bouche
        parts.append(cyl(0.032,0.035,GLOW,(bx,-0.82,0.0),(90,0,0)))  # lueur bouche
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
    c=bpy.context.view_layer.objects.active
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
    return c
canL=build_cannon(); canR=build_cannon()

def place():
    hL=arm.matrix_world@arm.pose.bones["Head"].head
    eyeL.location=(hL.x-BE.XSEP, hL.y+BE.EYE_OFF[1], hL.z+BE.EYE_OFF[2])
    eyeR.location=(hL.x+BE.XSEP, hL.y+BE.EYE_OFF[1], hL.z+BE.EYE_OFF[2])
    L=arm.matrix_world@arm.pose.bones["LeftArm"].head; R=arm.matrix_world@arm.pose.bones["RightArm"].head
    canL.location=(L.x+CAN_OFF[0], L.y+CAN_OFF[1], L.z+CAN_OFF[2])
    canR.location=(R.x-CAN_OFF[0], R.y+CAN_OFF[1], R.z+CAN_OFF[2])
meshes=body+[canL,canR,eyeL,eyeR]
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
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4.0
def aim(cen,az):
    a=math.radians(az)
    cam.location=(cen.x+dist*math.cos(e)*math.sin(a), cen.y-dist*math.cos(e)*math.cos(a), cen.z+dist*math.sin(e))
    look=cen-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
tmp=os.path.abspath("cine/_show/_cntmp.png")
sc.render.resolution_x=300; sc.render.resolution_y=300
if MODE in ("sheet","bake"):
    RES=256; sc.render.resolution_x=RES; sc.render.resolution_y=RES
    cam_d.ortho_scale=size*1.30   # marge pour les canons qui dépassent en vue de profil
    dirs = DIRS if MODE=="bake" else [("front",0)]
    for dname,az in dirs:
        tiles=[]
        for f in range(FRAMES):
            BE.pose_walk(arm,f,FRAMES); place(); bpy.context.view_layer.update()
            aim(c0,az)   # centre FIXE -> pas de derive
            sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(tmp).convert("RGBA").copy())
        sheet=Image.new("RGBA",(RES*FRAMES,RES),(0,0,0,0))
        for k,im in enumerate(tiles): sheet.paste(im,(k*RES,0),im)
        nm = "front_sheet.png" if MODE=="sheet" else f"raw_{dname}.png"
        sheet.save(os.path.join(OUTDIR,nm)); print("BAKE",dname)
    if os.path.exists(tmp): os.remove(tmp)
elif MODE=="4dir":
    for dname,az in DIRS:
        BE.pose_walk(arm,2,FRAMES); place(); bpy.context.view_layer.update()
        mn,mx=fb(); cen=(mn+mx)*0.5; cen.z=c0.z; aim(cen,az)
        sc.render.filepath=os.path.join(OUTDIR,f"{dname}.png"); bpy.ops.render.render(write_still=True); print("DIR",dname)
else:
    BE.pose_walk(arm,2,FRAMES); place(); bpy.context.view_layer.update()
    mn,mx=fb(); cen=(mn+mx)*0.5; cen.z=c0.z; aim(cen,0)
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    im=Image.open(tmp).convert("RGBA"); b=Image.new("RGBA",im.size,(24,26,32,255)); b.alpha_composite(im); b.convert("RGB").save(OUT)
    if os.path.exists(tmp): os.remove(tmp)
print("SAVED" if MODE!="4dir" else "DONE")
