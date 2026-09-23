"""Bake bluestrike as an ENEMY walk cycle with CORRECTED arms (down/forward, not
backward). Writes 4-dir sheets to game/assets/enemies/bluestrike_walk_<dir>.png
(SEPARATE from the player sheets in assets/mecha/ -> zero player regression).
Also writes a front-view preview GIF to cine/_show/ for verification."""
import bpy, os, math, mathutils
from PIL import Image

GLB_IN = os.path.abspath("meshy_in/nice_mech/rigged.glb")
OUT_DIR = os.path.abspath("game/assets/enemies")
PREVIEW = os.path.abspath("cine/_show/bluestrike_enemy_preview.gif")
CHASSIS = "bluestrike"
RES = 256; FRAMES = 8; SAMPLES = 16; EL = 40.0
os.makedirs(OUT_DIR, exist_ok=True)

def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB_IN)
    sc = bpy.context.scene
    sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=SAMPLES
    sc.cycles.use_denoising=True
    sc.render.resolution_x=RES; sc.render.resolution_y=RES
    sc.render.film_transparent=True
    sc.render.image_settings.file_format="PNG"; sc.render.image_settings.color_mode="RGBA"
    w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
    bg=w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value=(0.08,0.09,0.13,1.0); bg.inputs["Strength"].default_value=0.45
    def sun(n,e,rot,col=(1,1,1)):
        d=bpy.data.lights.new(n,type="SUN"); d.energy=e; d.color=col; d.angle=math.radians(5)
        o=bpy.data.objects.new(n,d); sc.collection.objects.link(o)
        o.rotation_euler=tuple(math.radians(a) for a in rot)
    sun("key",4.5,(52,8,-34),(1.0,0.95,0.88)); sun("fill",1.8,(66,-6,46),(0.75,0.85,1.0)); sun("rim",4.0,(-38,0,160),(0.7,0.95,1.0))
    return sc

def get_arm():
    return next(o for o in bpy.context.scene.objects if o.type=="ARMATURE")
def get_meshes():
    return [o for o in bpy.context.scene.objects if o.type=="MESH"]
def reset(arm):
    for p in arm.pose.bones:
        p.rotation_mode="XYZ"; p.rotation_euler=(0,0,0); p.location=(0,0,0); p.scale=(1,1,1)

def base_pose(arm):
    """CORRECTED: arms hang DOWN & slightly forward (rig axis is inverted vs the
    old +X 'guard' which swung elbows up/back)."""
    pb=arm.pose.bones
    if "Spine" in pb:   pb["Spine"].rotation_euler.x=math.radians(-3)
    if "Spine01" in pb: pb["Spine01"].rotation_euler.x=math.radians(2)
    if "Spine02" in pb: pb["Spine02"].rotation_euler.x=math.radians(2)
    if "LeftArm" in pb:     pb["LeftArm"].rotation_euler=(math.radians(-55),math.radians(12),math.radians(-8))
    if "RightArm" in pb:    pb["RightArm"].rotation_euler=(math.radians(-55),math.radians(-12),math.radians(8))
    if "LeftForeArm" in pb: pb["LeftForeArm"].rotation_euler=(math.radians(-25),math.radians(8),0)
    if "RightForeArm" in pb:pb["RightForeArm"].rotation_euler=(math.radians(-25),math.radians(-8),0)

def pose_walk(arm,f,total=8):
    reset(arm); base_pose(arm)
    pb=arm.pose.bones; t=f/total; p=2*math.pi*t
    bob=-0.04*abs(math.sin(p))+0.018; sway=0.045*math.sin(p)
    if "Hips" in pb: pb["Hips"].location.z=bob; pb["Hips"].rotation_euler.z=sway
    l_pitch=math.radians(28)*math.sin(p); r_pitch=math.radians(28)*math.sin(p+math.pi)
    l_knee=math.radians(45)*max(0.0,-math.sin(p-0.25)); r_knee=math.radians(45)*max(0.0,-math.sin(p+math.pi-0.25))
    l_ankle=-l_pitch*0.65; r_ankle=-r_pitch*0.65
    if "LeftUpLeg" in pb:  pb["LeftUpLeg"].rotation_euler.x=l_pitch
    if "RightUpLeg" in pb: pb["RightUpLeg"].rotation_euler.x=r_pitch
    if "LeftLeg" in pb:  pb["LeftLeg"].rotation_euler.x=l_knee
    if "RightLeg" in pb: pb["RightLeg"].rotation_euler.x=r_knee
    if "LeftFoot" in pb:  pb["LeftFoot"].rotation_euler.x=l_ankle
    if "RightFoot" in pb: pb["RightFoot"].rotation_euler.x=r_ankle
    if "Spine01" in pb: pb["Spine01"].rotation_euler.y=-0.03*math.sin(p)
    if "Spine02" in pb: pb["Spine02"].rotation_euler.z=-sway*0.7
    # arm swing on top of the down base (natural counter-swing)
    if "LeftArm" in pb:  pb["LeftArm"].rotation_euler.x+=-math.radians(14)*math.sin(p)
    if "RightArm" in pb: pb["RightArm"].rotation_euler.x+=math.radians(14)*math.sin(p)
    if "LeftForeArm" in pb:  pb["LeftForeArm"].rotation_euler.x+=math.radians(8)*math.sin(p)
    if "RightForeArm" in pb: pb["RightForeArm"].rotation_euler.x+=-math.radians(8)*math.sin(p)

def frame_bounds(meshes):
    mn=mathutils.Vector((1e9,)*3); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            wv=oe.matrix_world @ mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn,mx

def main():
    sc=setup(); arm=get_arm(); meshes=get_meshes()
    pose_walk(arm,0,FRAMES); mn0,mx0=frame_bounds(meshes); center0=(mn0+mx0)*0.5
    size=max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
    cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
    cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
    e=math.radians(EL); dist=size*4.0
    def aim(center,az):
        a=math.radians(az)
        cam.location=(center.x+dist*math.cos(e)*math.sin(a),center.y-dist*math.cos(e)*math.cos(a),center.z+dist*math.sin(e))
        look=center-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
    tmp=os.path.abspath("cine/_show/_bstmp.png")
    DIRS=[("front",0),("back",180),("left",90),("right",-90)]
    prev=[]
    for dname,az in DIRS:
        tiles=[]
        for f in range(FRAMES):
            pose_walk(arm,f,FRAMES); mn,mx=frame_bounds(meshes); cen=(mn+mx)*0.5; cen.z=center0.z; aim(cen,az)
            sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
            im=Image.open(tmp).convert("RGBA").copy(); tiles.append(im)
            if dname=="front": prev.append(im.copy())
        sheet=Image.new("RGBA",(RES*FRAMES,RES),(0,0,0,0))
        for k,im in enumerate(tiles): sheet.paste(im,(RES*k,0),im)
        outp=os.path.join(OUT_DIR,f"{CHASSIS}_walk_{dname}.png"); sheet.save(outp)
        print("SHEET",outp)
    # preview gif (front) on dark bg
    fr=[]
    for im in prev:
        b=Image.new("RGBA",im.size,(26,28,34,255)); b.alpha_composite(im); fr.append(b.convert("RGB"))
    fr[0].save(PREVIEW,save_all=True,append_images=fr[1:],duration=110,loop=0)
    print("PREVIEW",PREVIEW)
    if os.path.exists(tmp): os.remove(tmp)

if __name__=="__main__": main()
