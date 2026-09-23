"""Tune the position of an emissive VISOR/EYES element on the mech head.
Renders the front view with the eye bar at several forward/height offsets so we
can pick the one that lands on the face. Uses a KEY color (magenta) absent from
the mech so 2D recolor can find it and force red glow, biome-independent."""
import bpy, os, math, mathutils
from PIL import Image, ImageDraw

GLB=os.path.abspath("meshy_in/nice_mech/rigged.glb")
OUT=os.path.abspath("cine/_show/eye_tune.png")
RES=240; EL=40.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=10; sc.cycles.use_denoising=True
sc.render.resolution_x=RES; sc.render.resolution_y=RES; sc.render.film_transparent=True
sc.render.image_settings.file_format="PNG"; sc.render.image_settings.color_mode="RGBA"
w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
bg=w.node_tree.nodes.get("Background"); bg.inputs["Color"].default_value=(0.08,0.09,0.13,1.0); bg.inputs["Strength"].default_value=0.5
def sun(n,e,rot,col=(1,1,1)):
    d=bpy.data.lights.new(n,type="SUN"); d.energy=e; d.color=col; d.angle=math.radians(5)
    o=bpy.data.objects.new(n,d); sc.collection.objects.link(o); o.rotation_euler=tuple(math.radians(a) for a in rot)
sun("key",4.5,(52,8,-34)); sun("fill",1.8,(66,-6,46),(0.75,0.85,1.0)); sun("rim",4.0,(-38,0,160),(0.7,0.95,1.0))

arm=next(o for o in sc.objects if o.type=="ARMATURE")
meshes=[o for o in sc.objects if o.type=="MESH"]
pb=arm.pose.bones
for p in pb:
    p.rotation_mode="XYZ"; p.rotation_euler=(0,0,0); p.location=(0,0,0)
# arms down base so head is clear
def base():
    if "LeftArm" in pb: pb["LeftArm"].rotation_euler=(math.radians(-55),math.radians(12),math.radians(-8))
    if "RightArm" in pb: pb["RightArm"].rotation_euler=(math.radians(-55),math.radians(-12),math.radians(8))
base()

# head bone geometry
hb=arm.pose.bones["Head"]
head_w=arm.matrix_world @ hb.head
tail_w=arm.matrix_world @ hb.tail
print("Head head_w",tuple(round(x,3) for x in head_w),"tail_w",tuple(round(x,3) for x in tail_w))
center=(head_w+tail_w)*0.5

# emissive magenta eye bar (key color)
mat=bpy.data.materials.new("eyekey"); mat.use_nodes=True
nt=mat.node_tree; nt.nodes.clear()
em=nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value=(1,0,1,1); em.inputs["Strength"].default_value=6.0
out=nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(em.outputs["Emission"],out.inputs["Surface"])

def make_eye(pos):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    e=bpy.context.active_object; e.scale=(0.11,0.05,0.028)  # wide thin bar
    e.data.materials.append(mat)
    return e

def frame_bounds():
    mn=mathutils.Vector((1e9,)*3); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            wv=oe.matrix_world @ mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    return mn,mx
mn0,mx0=frame_bounds(); c0=(mn0+mx0)*0.5
size=max((mx0-mn0).x,(mx0-mn0).y,(mx0-mn0).z,1e-3)
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4.0
def aim(center,az):
    a=math.radians(az)
    cam.location=(center.x+dist*math.cos(e)*math.sin(a),center.y-dist*math.cos(e)*math.cos(a),center.z+dist*math.sin(e))
    look=center-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()

tmp=os.path.abspath("cine/_show/_eyetmp.png")
def shot(az):
    cen=c0.copy(); cen.z=c0.z; aim(cen,az)
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    return Image.open(tmp).convert("RGBA").copy()

# anchor on head BONE HEAD (tail is bogus on this rig). Sweep vertically to find the face.
mnb,mxb=frame_bounds()
print("MECH z-range", round(mnb.z,3), "->", round(mxb.z,3), " head_w.z", round(head_w.z,3))
hx,hy,hz=head_w.x, head_w.y, head_w.z
# locked placement candidates around the head, shown front + side
PLACE=[("z+.44",(hx, hy-0.15, hz+0.44)),
       ("z+.50",(hx, hy-0.15, hz+0.50))]
views=[("front",0),("left",90)]
cell=RES; canvas=Image.new("RGB",(cell*4+10*5,cell+30),(22,24,30)); dr=ImageDraw.Draw(canvas)
col=0
for lab,pos in PLACE:
    eye=make_eye(mathutils.Vector(pos))
    for vlab,az in views:
        im=shot(az)
        b=Image.new("RGBA",im.size,(28,30,38,255)); b.alpha_composite(im)
        canvas.paste(b.convert("RGB"),(10+col*(cell+10),24)); dr.text((10+col*(cell+10),6),f"{lab} {vlab}",fill=(235,235,245))
        col+=1
    bpy.data.objects.remove(eye, do_unlink=True)
canvas.save(OUT)
if os.path.exists(tmp): os.remove(tmp)
print("SAVED",OUT)
