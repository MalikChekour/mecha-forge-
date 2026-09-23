"""Static 4-dir bake: rotate the CAMERA around the model at EL elevation (front/back/left/right),
bright lighting for dark hard-surface mechs. Outputs <out>_<dir>.png (256, RGBA transparent)."""
import bpy, sys, os, math, mathutils
from PIL import Image
GLB=os.path.abspath(sys.argv[1]); OUTBASE=os.path.abspath(sys.argv[2])
RES=int(sys.argv[3]) if len(sys.argv)>3 else 256
EL=40.0; FILL=float(os.environ.get("FILL","1.0"))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=28; sc.cycles.use_denoising=True
sc.render.resolution_x=RES; sc.render.resolution_y=RES; sc.render.film_transparent=True
sc.render.image_settings.file_format="PNG"; sc.render.image_settings.color_mode="RGBA"
w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
bg=w.node_tree.nodes.get("Background"); bg.inputs["Color"].default_value=(0.12,0.13,0.16,1); bg.inputs["Strength"].default_value=0.9
def sun(e,rot,col=(1,1,1)):
    d=bpy.data.lights.new("s",type="SUN"); d.energy=e; d.color=col; d.angle=math.radians(6)
    o=bpy.data.objects.new("s",d); sc.collection.objects.link(o); o.rotation_euler=tuple(math.radians(a) for a in rot)
sun(6.0,(52,10,-40),(1,.97,.92)); sun(3.0,(64,-6,50),(.8,.88,1)); sun(5.0,(-40,0,150),(.75,.95,1)); sun(2.5,(75,0,0),(1,1,1))
def bbox():
    dg=bpy.context.evaluated_depsgraph_get(); mn=mathutils.Vector((1e9,)*3); mx=-mn
    for o in sc.objects:
        if o.type=="MESH":
            oe=o.evaluated_get(dg)
            for c in oe.bound_box:
                v=oe.matrix_world@mathutils.Vector(c)
                for i in range(3): mn[i]=min(mn[i],v[i]); mx[i]=max(mx[i],v[i])
    return mn,mx
mn,mx=bbox(); cen=(mn+mx)*0.5; cen.z=(mn.z+mx.z)*0.5; size=max((mx-mn).x,(mx-mn).y,(mx-mn).z,1e-3)
cam_d=bpy.data.cameras.new("c"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.15
cam=bpy.data.objects.new("c",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(EL); dist=size*4
for name,az in [("front",0),("right",-90),("back",180),("left",90)]:
    a=math.radians(az)
    cam.location=(cen.x+dist*math.cos(e)*math.sin(a),cen.y-dist*math.cos(e)*math.cos(a),cen.z+dist*math.sin(e))
    cam.rotation_euler=(cen-mathutils.Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
    p="%s_%s.png"%(OUTBASE,name); sc.render.filepath=p; bpy.ops.render.render(write_still=True)
    print("saved",p)
