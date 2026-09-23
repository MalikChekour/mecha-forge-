#!/usr/bin/env python3
"""bake_anim.py + POSTURE CORRECTION: after each frame_set, add a local pitch to the spine bones
(un-hunch) and drop the arms, on top of the Meshy walk retarget. Tunable via args:
  --spine <deg per spine bone>  --arm <deg>  --neck <deg>
  python bake_anim_fix.py <in.glb> <out.png> [--frames 8][--res 256][--el 40][--dirs 4][--spine -12][--arm 18][--neck 6]"""
import bpy, sys, os, math, mathutils
from PIL import Image

def argval(flag, default, cast=float):
    a = sys.argv
    return cast(a[a.index(flag) + 1]) if flag in a else default

GLB = os.path.abspath(sys.argv[1]); OUT = os.path.abspath(sys.argv[2])
FRAMES=int(argval("--frames",8)); RES=int(argval("--res",256)); EL=argval("--el",40.0)
SAMPLES=int(argval("--samples",24)); NDIRS=int(argval("--dirs",4))
SPINE=argval("--spine",-12.0); ARM=argval("--arm",18.0); NECK=argval("--neck",6.0)
SAX=(sys.argv[sys.argv.index("--axis")+1] if "--axis" in sys.argv else "X")
TMP=os.path.join(os.path.dirname(OUT) or ".","_fixframe.png")

def setup_render():
    sc=bpy.context.scene; sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=SAMPLES
    sc.cycles.use_denoising=True; sc.render.resolution_x=RES; sc.render.resolution_y=RES
    sc.render.film_transparent=True; sc.render.image_settings.file_format="PNG"; sc.render.image_settings.color_mode="RGBA"
    w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True; bg=w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value=(0.08,0.09,0.13,1.0); bg.inputs["Strength"].default_value=0.45
    def sun(n,e,rot,col=(1,1,1)):
        d=bpy.data.lights.new(n,type="SUN"); d.energy=e; d.color=col; d.angle=math.radians(5)
        o=bpy.data.objects.new(n,d); sc.collection.objects.link(o); o.rotation_euler=tuple(math.radians(a) for a in rot)
    sun("key",4.2,(52,8,-34),(1.0,0.97,0.9)); sun("fill",1.4,(66,-6,46),(0.75,0.85,1.0)); sun("rim",4.0,(-38,0,160),(0.7,0.95,1.0))

def meshes(): return [o for o in bpy.context.scene.objects if o.type=="MESH"]
def frame_bounds(objs):
    mn=mathutils.Vector((1e9,1e9,1e9)); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
    for o in objs:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            wv=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn,mx

# corrective local rotations (degrees) added on top of the animation each frame
CORR = {"Spine":("X",SPINE),"Spine01":("X",SPINE),"Spine02":("X",SPINE),"neck":("X",NECK),
        "LeftArm":("Z",ARM),"RightArm":("Z",-ARM)}

def apply_fix(arm):
    for name,(ax,deg) in CORR.items():
        pb=arm.pose.bones.get(name)
        if pb is None or abs(deg)<1e-6: continue
        pb.rotation_mode='XYZ'
        i={"X":0,"Y":1,"Z":2}[ax]
        pb.rotation_euler[i]+=math.radians(deg)

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    objs=meshes(); arm=next((o for o in bpy.context.scene.objects if o.type=="ARMATURE"),None)
    sc=bpy.context.scene; f0,f1=sc.frame_start,sc.frame_end
    if f1<=f0: f1=f0+24
    frames=[int(round(f0+(f1-f0)*i/FRAMES)) for i in range(FRAMES)]
    setup_render()
    sc.frame_set(frames[0])
    if arm: apply_fix(arm)
    bpy.context.view_layer.update()
    mn0,mx0=frame_bounds(objs); center0=(mn0+mx0)*0.5
    size=max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
    cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
    cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
    e=math.radians(EL); dist=size*4.0
    def aim(center,az):
        a=math.radians(az)
        cam.location=(center.x+dist*math.cos(e)*math.sin(a),center.y-dist*math.cos(e)*math.cos(a),center.z+dist*math.sin(e))
        look=center-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
    DIRS={1:[("",0)],4:[("_front",0),("_back",180),("_left",90),("_right",-90)]}
    stem,ext=os.path.splitext(OUT)
    for suffix,az in DIRS.get(NDIRS,DIRS[1]):
        tiles=[]
        for f in frames:
            sc.frame_set(f)
            if arm: apply_fix(arm)
            bpy.context.view_layer.update()
            mn,mx=frame_bounds(objs); cen=(mn+mx)*0.5; cen.z=center0.z; aim(cen,az)
            sc.render.filepath=TMP; bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(TMP).convert("RGBA").copy())
        sheet=Image.new("RGBA",(RES*FRAMES,RES),(0,0,0,0))
        for k,im in enumerate(tiles): sheet.paste(im,(RES*k,0),im)
        sheet.save(stem+suffix+ext)
    if os.path.exists(TMP): os.remove(TMP)
    print("FIXED",OUT,"spine",SPINE,"arm",ARM,"neck",NECK)

main()
