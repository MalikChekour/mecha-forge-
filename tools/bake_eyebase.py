"""Bake bluestrike walk WITH a magenta-keyed VISOR/EYES element on the head.
Output = intermediate sheets in meshy_in/bluestrike_eyebase/ (NOT the live game
sheets). 2D recolor turns the magenta key into red glowing eyes + biome paint."""
import bpy, os, sys, math, mathutils
from PIL import Image

GLB=os.path.abspath("meshy_in/nice_mech/rigged.glb")
OUT=os.path.abspath("meshy_in/bluestrike_eyebase"); os.makedirs(OUT,exist_ok=True)
RES=256; FRAMES=8; SAMPLES=16; EL=40.0
EYE_OFF=(0.0,-0.15,0.44); EYE_SCALE=(0.058,0.05,0.034); XSEP=0.052  # TWIN eyes
DIRS=[("front",0),("back",180),("left",90),("right",-90)]
if len(sys.argv)>1 and sys.argv[-1]=="front": DIRS=[("front",0)]

def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    sc=bpy.context.scene
    sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=SAMPLES; sc.cycles.use_denoising=True
    sc.render.resolution_x=RES; sc.render.resolution_y=RES; sc.render.film_transparent=True
    sc.render.image_settings.file_format="PNG"; sc.render.image_settings.color_mode="RGBA"
    w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
    bg=w.node_tree.nodes.get("Background"); bg.inputs["Color"].default_value=(0.08,0.09,0.13,1.0); bg.inputs["Strength"].default_value=0.45
    def sun(n,e,rot,col=(1,1,1)):
        d=bpy.data.lights.new(n,type="SUN"); d.energy=e; d.color=col; d.angle=math.radians(5)
        o=bpy.data.objects.new(n,d); sc.collection.objects.link(o); o.rotation_euler=tuple(math.radians(a) for a in rot)
    sun("key",4.5,(52,8,-34),(1.0,0.95,0.88)); sun("fill",1.8,(66,-6,46),(0.75,0.85,1.0)); sun("rim",4.0,(-38,0,160),(0.7,0.95,1.0))
    return sc

def base_pose(pb):
    if "Spine" in pb: pb["Spine"].rotation_euler.x=math.radians(-3)
    if "LeftArm" in pb: pb["LeftArm"].rotation_euler=(math.radians(-55),math.radians(12),math.radians(-8))
    if "RightArm" in pb: pb["RightArm"].rotation_euler=(math.radians(-55),math.radians(-12),math.radians(8))
    if "LeftForeArm" in pb: pb["LeftForeArm"].rotation_euler=(math.radians(-25),math.radians(8),0)
    if "RightForeArm" in pb: pb["RightForeArm"].rotation_euler=(math.radians(-25),math.radians(-8),0)

def pose_walk(arm,f,total=8):
    pb=arm.pose.bones
    for p in pb: p.rotation_mode="XYZ"; p.rotation_euler=(0,0,0); p.location=(0,0,0); p.scale=(1,1,1)
    base_pose(pb)
    t=f/total; p=2*math.pi*t
    if "Hips" in pb: pb["Hips"].location.z=-0.04*abs(math.sin(p))+0.018; pb["Hips"].rotation_euler.z=0.045*math.sin(p)
    lp=math.radians(28)*math.sin(p); rp=math.radians(28)*math.sin(p+math.pi)
    lk=math.radians(45)*max(0.0,-math.sin(p-0.25)); rk=math.radians(45)*max(0.0,-math.sin(p+math.pi-0.25))
    if "LeftUpLeg" in pb: pb["LeftUpLeg"].rotation_euler.x=lp
    if "RightUpLeg" in pb: pb["RightUpLeg"].rotation_euler.x=rp
    if "LeftLeg" in pb: pb["LeftLeg"].rotation_euler.x=lk
    if "RightLeg" in pb: pb["RightLeg"].rotation_euler.x=rk
    if "LeftFoot" in pb: pb["LeftFoot"].rotation_euler.x=-lp*0.65
    if "RightFoot" in pb: pb["RightFoot"].rotation_euler.x=-rp*0.65
    if "LeftArm" in pb: pb["LeftArm"].rotation_euler.x+=-math.radians(14)*math.sin(p)
    if "RightArm" in pb: pb["RightArm"].rotation_euler.x+=math.radians(14)*math.sin(p)

def main():
    sc=setup()
    arm=next(o for o in sc.objects if o.type=="ARMATURE")
    meshes=[o for o in sc.objects if o.type=="MESH"]
    # emissive magenta eye bar (key)
    mat=bpy.data.materials.new("eyekey"); mat.use_nodes=True; nt=mat.node_tree; nt.nodes.clear()
    em=nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value=(1,0,1,1); em.inputs["Strength"].default_value=1.3
    sc.view_settings.view_transform="Standard"  # keep magenta key un-desaturated for 2D keying
    mo=nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(em.outputs["Emission"],mo.inputs["Surface"])
    bpy.ops.mesh.primitive_cube_add(size=1.0); eyeL=bpy.context.active_object
    eyeL.scale=EYE_SCALE; eyeL.data.materials.append(mat)
    bpy.ops.mesh.primitive_cube_add(size=1.0); eyeR=bpy.context.active_object
    eyeR.scale=EYE_SCALE; eyeR.data.materials.append(mat)

    def frame_bounds():
        mn=mathutils.Vector((1e9,)*3); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
        for o in meshes:
            oe=o.evaluated_get(dg)
            for c in oe.bound_box:
                wv=oe.matrix_world @ mathutils.Vector(c)
                for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
        return mn,mx

    def place_eye():
        hb=arm.pose.bones["Head"]; hw=arm.matrix_world @ hb.head
        eyeL.location=(hw.x-XSEP, hw.y+EYE_OFF[1], hw.z+EYE_OFF[2]); eyeL.rotation_euler=(0,0,0)
        eyeR.location=(hw.x+XSEP, hw.y+EYE_OFF[1], hw.z+EYE_OFF[2]); eyeR.rotation_euler=(0,0,0)

    pose_walk(arm,0,FRAMES); place_eye(); mn0,mx0=frame_bounds(); c0=(mn0+mx0)*0.5
    size=max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
    cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
    cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
    e=math.radians(EL); dist=size*4.0
    def aim(center,az):
        a=math.radians(az)
        cam.location=(center.x+dist*math.cos(e)*math.sin(a),center.y-dist*math.cos(e)*math.cos(a),center.z+dist*math.sin(e))
        look=center-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
    tmp=os.path.join(OUT,"_tmp.png")
    for dname,az in DIRS:
        tiles=[]
        for f in range(FRAMES):
            pose_walk(arm,f,FRAMES); place_eye()
            mn,mx=frame_bounds(); cen=(mn+mx)*0.5; cen.z=c0.z; aim(cen,az)
            sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(tmp).convert("RGBA").copy())
        sheet=Image.new("RGBA",(RES*FRAMES,RES),(0,0,0,0))
        for k,im in enumerate(tiles): sheet.paste(im,(RES*k,0),im)
        sheet.save(os.path.join(OUT,f"walk_{dname}.png")); print("SHEET",dname)
    if os.path.exists(tmp): os.remove(tmp)
    print("DONE")

if __name__=="__main__": main()
