# -*- coding: utf-8 -*-
"""Greffe le TORSE d'un boss Meshy sur les JAMBES animees de Blue Strike.
Coupe les jambes du modele Meshy (supprime les sommets sous la taille) -> garde le haut ->
le pose/echelle sur les jambes Blue Strike. MODE: front (verif) | bake (4-dir)."""
import bpy, os, sys, math, mathutils, bmesh
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
import bake_eyebase as BE

BOSS = sys.argv[1] if len(sys.argv) > 1 else "titan"
MODE = sys.argv[2] if len(sys.argv) > 2 else "front"
BOSS_GLB = os.path.abspath("meshy_in/%s/model.glb" % BOSS)
OUTDIR = os.path.abspath("cine/_show/bosstop"); os.makedirs(OUTDIR, exist_ok=True)
OUT1 = os.path.abspath("cine/_show/bosstop_%s.png" % BOSS)
UPPER = ["Spine","Spine01","Spine02","LeftShoulder","LeftArm","LeftForeArm","LeftHand",
         "RightShoulder","RightArm","RightForeArm","RightHand","neck","Head","head_end","headfront"]
# par boss : (waist_frac, overlap enfoncement, top_width largeur torse, leg_scale, y_shift torse recul)
PARAMS = {
    "titan":   (0.33, 0.52, 1.55, 1.00, 0.00),
    "crusher": (0.30, 0.78, 1.66, 1.00, 0.00),   # valide
    "midboss": (0.32, 0.70, 1.30, 1.00, 0.12),   # torse REDUIT (moins top-heavy) + recule (anti pench-avant)
    "endboss": (0.33, 0.56, 1.55, 1.00, 0.00),   # valide
}
WAIST_FRAC, OVERLAP, TOP_WIDTH, LEG_SCALE, Y_SHIFT = PARAMS.get(BOSS, (0.33, 0.52, 1.55, 1.00, 0.00))
FRAMES = 8; EL = 40.0
DIRS = [("front",0),("left",90),("back",180),("right",-90)]

sc = BE.setup(); sc.view_settings.view_transform = "Standard"
arm = next(o for o in sc.objects if o.type == "ARMATURE")
legs = [o for o in sc.objects if o.type == "MESH"]
if LEG_SCALE != 1.0:                    # agrandit tout le rig (armature + jambes enfants)
    arm.scale = (LEG_SCALE, LEG_SCALE, LEG_SCALE)
    bpy.context.view_layer.update()
def strip(obj, bones, th=0.5):
    vg={g.name:g.index for g in obj.vertex_groups}; idx=[vg[b] for b in bones if b in vg]
    if not idx: return
    bm=bmesh.new(); bm.from_mesh(obj.data); dl=bm.verts.layers.deform.active
    if dl is None: bm.free(); return
    kill=[v for v in bm.verts if any(v[dl].get(i,0.0)>th for i in idx)]
    bmesh.ops.delete(bm,geom=kill,context='VERTS'); bm.to_mesh(obj.data); bm.free()
for m in legs: strip(m, UPPER)

# --- import boss, join, applique transfo ---
before=set(o.name for o in sc.objects)
bpy.ops.import_scene.gltf(filepath=BOSS_GLB)
new=[o for o in sc.objects if o.name not in before]
bm_meshes=[o for o in new if o.type=="MESH"]
for o in new:
    if o.type!="MESH":
        try: bpy.data.objects.remove(o,do_unlink=True)
        except Exception: pass
bpy.ops.object.select_all(action='DESELECT')
for o in bm_meshes: o.select_set(True)
bpy.context.view_layer.objects.active=bm_meshes[0]
if len(bm_meshes)>1: bpy.ops.object.join()
top=bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)

# --- coupe les JAMBES : supprime les sommets sous waist_z (monde) ---
bb=[top.matrix_world@mathutils.Vector(c) for c in top.bound_box]
zmin=min(v.z for v in bb); zmax=max(v.z for v in bb)
waist_z=zmin+(zmax-zmin)*WAIST_FRAC
bm=bmesh.new(); bm.from_mesh(top.data)
kill=[v for v in bm.verts if (top.matrix_world@v.co).z < waist_z]
bmesh.ops.delete(bm,geom=kill,context='VERTS'); bm.to_mesh(top.data); bm.free()

# --- normalise le TOP : origine au centre-bas, echelle a TOP_WIDTH, oriente face -Y ---
bpy.ops.object.select_all(action='DESELECT'); top.select_set(True); bpy.context.view_layer.objects.active=top
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
d=top.dimensions; s=TOP_WIDTH/max(d.x,1e-4); top.scale=(s,s,s)
bpy.ops.object.transform_apply(scale=True)
# origine au BAS du torse (pour poser sur les jambes)
bb2=[top.matrix_world@mathutils.Vector(c) for c in top.bound_box]
bot=min(v.z for v in bb2)
top.location.z -= 0  # (origine deja bounds-center) ; on placera via legs_top

def legs_top_z():
    dg=bpy.context.evaluated_depsgraph_get(); tz=-1e9
    for o in legs:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box: tz=max(tz,(oe.matrix_world@mathutils.Vector(c)).z)
    return tz
def torso_bottom_z():
    dg=bpy.context.evaluated_depsgraph_get()
    oe=top.evaluated_get(dg)
    return min((oe.matrix_world@mathutils.Vector(c)).z for c in oe.bound_box)
# TORSE STATIQUE : les jambes marchent dessous, le torse ne bouge pas.
BE.pose_walk(arm,0,FRAMES); bpy.context.view_layer.update()
LT=legs_top_z()
H=arm.matrix_world@arm.pose.bones["Hips"].head
top.location=(H.x, H.y-0.02+Y_SHIFT, LT)  # placement provisoire (+Y_SHIFT = recul)
bpy.context.view_layer.update()
# snap : bas du torse a LT - 0.14 (chevauche la taille)
top.location.z += (LT - OVERLAP) - torso_bottom_z()
bpy.context.view_layer.update()
def place():  # no-op : le torse est fige
    pass
meshes=legs+[top]
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
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.14
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4.0
def aim(cen,az):
    a=math.radians(az)
    cam.location=(cen.x+dist*math.cos(e)*math.sin(a), cen.y-dist*math.cos(e)*math.cos(a), cen.z+dist*math.sin(e))
    look=cen-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
tmp=os.path.abspath("cine/_show/_bttmp.png")
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
        sheet.save(os.path.join(OUTDIR,f"{BOSS}_{dname}.png")); print("BAKE",dname)
else:
    sc.render.resolution_x=320; sc.render.resolution_y=320
    BE.pose_walk(arm,2,FRAMES); place(); bpy.context.view_layer.update()
    aim(c0,0); sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    im=Image.open(tmp).convert("RGBA"); b=Image.new("RGBA",im.size,(24,26,32,255)); b.alpha_composite(im); b.convert("RGB").save(OUT1)
if os.path.exists(tmp): os.remove(tmp)
print("DONE", BOSS)
