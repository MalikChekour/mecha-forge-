"""Diagnostic: understand bluestrike arm-bone axes + find the pose that puts
arms FORWARD (not backward). Renders a comparison grid, prints rest orientation."""
import bpy, os, math, mathutils
from PIL import Image

GLB = os.path.abspath("meshy_in/nice_mech/rigged.glb")
OUT = os.path.abspath("cine/_show/diag_arms.png")
RES = 220
EL = 40.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 8
sc.cycles.use_denoising = True
sc.render.resolution_x = RES; sc.render.resolution_y = RES
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes.get("Background")
bg.inputs["Color"].default_value = (0.10, 0.11, 0.15, 1.0); bg.inputs["Strength"].default_value = 0.55
def sun(name, e, rot, col=(1,1,1)):
    d = bpy.data.lights.new(name, type="SUN"); d.energy = e; d.color = col; d.angle = math.radians(5)
    o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
    o.rotation_euler = tuple(math.radians(a) for a in rot)
sun("key", 4.5, (52, 8, -34), (1.0,0.95,0.88)); sun("fill", 1.8, (66,-6,46), (0.75,0.85,1.0)); sun("rim", 4.0, (-38,0,160), (0.7,0.95,1.0))

arm = next(o for o in sc.objects if o.type == "ARMATURE")
meshes = [o for o in sc.objects if o.type == "MESH"]
pb = arm.pose.bones

# --- print rest orientation of arm bones ---
print("=== ARMATURE BONES (arm-related) ===")
for name in ["Spine","Spine02","LeftArm","RightArm","LeftForeArm","RightForeArm","LeftShoulder","RightShoulder"]:
    if name in pb:
        b = arm.data.bones[name]
        head = arm.matrix_world @ b.head_local
        tail = arm.matrix_world @ b.tail_local
        d = (tail-head).normalized()
        print(f"  {name:14s} head={tuple(round(x,2) for x in head)} dir(world)={tuple(round(x,2) for x in d)}")
print("  all bones:", [b.name for b in arm.data.bones])

def reset():
    for p in pb:
        p.rotation_mode="XYZ"; p.rotation_euler=(0,0,0); p.location=(0,0,0); p.scale=(1,1,1)

def frame_bounds():
    mn=mathutils.Vector((1e9,)*3); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            wv=oe.matrix_world @ mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn,mx

reset(); mn0,mx0=frame_bounds(); center0=(mn0+mx0)*0.5
size=max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4.0
def aim(center,az):
    a=math.radians(az)
    cam.location=(center.x+dist*math.cos(e)*math.sin(a), center.y-dist*math.cos(e)*math.cos(a), center.z+dist*math.sin(e))
    look=center-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()

tmp=os.path.abspath("cine/_show/_diagtmp.png")
def shot(az):
    mn,mx=frame_bounds(); cen=(mn+mx)*0.5; cen.z=center0.z; aim(cen,az)
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    return Image.open(tmp).convert("RGBA").copy()

def set_arms(ax, fx, ay=16, az=12):
    """ax=upper-arm pitch deg, fx=forearm pitch deg, ay/az=shoulder spread"""
    reset()
    if "LeftArm" in pb:  pb["LeftArm"].rotation_euler=(math.radians(ax),math.radians(ay),math.radians(-az))
    if "RightArm" in pb: pb["RightArm"].rotation_euler=(math.radians(ax),math.radians(-ay),math.radians(az))
    if "LeftForeArm" in pb:  pb["LeftForeArm"].rotation_euler=(math.radians(fx),math.radians(8),0)
    if "RightForeArm" in pb: pb["RightForeArm"].rotation_euler=(math.radians(fx),math.radians(-8),0)

# Candidate poses: (label, upper-arm x, forearm x)
CANDS=[("CURRENT +28/+52", 28, 52),
       ("FLIP -28/-52", -28, -52),
       ("DOWN -55/-25", -55, -25),
       ("DOWN2 -70/-15", -70, -15)]

rows=[]
for label,ax,fx in CANDS:
    set_arms(ax,fx)
    fr=shot(0); sd=shot(90)
    rows.append((label,fr,sd))
    print("rendered:",label)

# compose grid: 4 rows x 2 cols
pad=6; cell=RES
W=cell*2+pad*3; H=(cell+22)*len(rows)+pad
canvas=Image.new("RGB",(W,H),(22,24,30))
from PIL import ImageDraw
dr=ImageDraw.Draw(canvas)
y=pad
for label,fr,sd in rows:
    dr.text((pad,y),label,fill=(230,230,240))
    for k,im in enumerate((fr,sd)):
        b=Image.new("RGBA",im.size,(28,30,38,255)); b.alpha_composite(im)
        canvas.paste(b.convert("RGB"),(pad+k*(cell+pad),y+18))
    y+=cell+22
canvas.save(OUT)
if os.path.exists(tmp): os.remove(tmp)
print("SAVED", OUT)
