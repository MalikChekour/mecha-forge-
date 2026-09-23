import bpy, sys, math, mathutils, os
from PIL import Image
GLB=sys.argv[-2]; OUT=sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(GLB))
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=28; sc.cycles.use_denoising=True
sc.render.resolution_x=560; sc.render.resolution_y=680; sc.render.film_transparent=True
sc.render.image_settings.file_format="PNG"; sc.render.image_settings.color_mode="RGBA"
w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
bg=w.node_tree.nodes.get("Background"); bg.inputs["Color"].default_value=(0.09,0.10,0.13,1); bg.inputs["Strength"].default_value=0.5
def sun(e,rot,col=(1,1,1)):
    d=bpy.data.lights.new("s",type="SUN"); d.energy=e; d.color=col; d.angle=math.radians(6)
    o=bpy.data.objects.new("s",d); sc.collection.objects.link(o); o.rotation_euler=tuple(math.radians(a) for a in rot)
sun(4.5,(52,10,-40),(1,.96,.9)); sun(1.9,(64,-6,50),(.75,.85,1)); sun(4.0,(-40,0,150),(.7,.95,1))
def bbox():
    dg=bpy.context.evaluated_depsgraph_get(); mn=mathutils.Vector((1e9,)*3); mx=-mn
    for o in sc.objects:
        if o.type=="MESH":
            oe=o.evaluated_get(dg)
            for c in oe.bound_box:
                v=oe.matrix_world@mathutils.Vector(c)
                for i in range(3): mn[i]=min(mn[i],v[i]); mx[i]=max(mx[i],v[i])
    return mn,mx
mn,mx=bbox(); cen=(mn+mx)*0.5; size=max((mx-mn).x,(mx-mn).y,(mx-mn).z,1e-3)
cam_d=bpy.data.cameras.new("c"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.25
cam=bpy.data.objects.new("c",cam_d); sc.collection.objects.link(cam); sc.camera=cam
tiles=[]
for az in (20,90):   # near-front 3/4 + side-ish
    e=math.radians(12); a=math.radians(az); dist=size*4
    cam.location=(cen.x+dist*math.cos(e)*math.sin(a),cen.y-dist*math.cos(e)*math.cos(a),cen.z+dist*math.sin(e))
    cam.rotation_euler=(cen-mathutils.Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
    tmp=os.path.abspath("cine/_show/_glbtmp.png"); sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    tiles.append(Image.open(tmp).convert("RGBA").copy())
strip=Image.new("RGB",(tiles[0].width*len(tiles),tiles[0].height),(26,28,36))
for i,t in enumerate(tiles): strip.paste(t,(t.width*i,0),t)
strip.save(os.path.abspath(OUT)); print("RENDERED",OUT)
