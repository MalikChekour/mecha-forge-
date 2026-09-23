# -*- coding: utf-8 -*-
"""Rendu de la tourelle SEULE (fond clair, bien eclairee) a plusieurs orientations
pour trouver 'avant vers la camera + debout'. Camera = -Y."""
import bpy, os, sys, math, mathutils
from PIL import Image, ImageDraw

PART = os.path.abspath(sys.argv[1] if len(sys.argv)>1 else "meshy_in/parts/topturret/model.glb")
OUT = os.path.abspath("cine/_show/turret_solo.png")
ROTS = [("0,0,0",(0,0,0)),("90,0,0",(90,0,0)),("-90,0,0",(-90,0,0)),
        ("180,0,0",(180,0,0)),("90,0,180",(90,0,180)),("-90,0,180",(-90,0,180))]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=12; sc.cycles.use_denoising=True
sc.render.film_transparent=True; sc.render.image_settings.color_mode="RGBA"
w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
bg=w.node_tree.nodes.get("Background"); bg.inputs["Color"].default_value=(0.2,0.21,0.24,1); bg.inputs["Strength"].default_value=0.8
def sun(e,rot,col=(1,1,1)):
    d=bpy.data.lights.new("s",type="SUN"); d.energy=e; d.color=col; d.angle=math.radians(6)
    o=bpy.data.objects.new("s",d); sc.collection.objects.link(o); o.rotation_euler=tuple(math.radians(a) for a in rot)
sun(4,(55,10,-30)); sun(2.2,(60,-10,50),(0.8,0.85,1)); sun(3,(-40,0,150),(0.8,0.9,1))
bpy.ops.import_scene.gltf(filepath=PART)
pm=[o for o in sc.objects if o.type=="MESH"]
bpy.ops.object.select_all(action='DESELECT')
for o in pm: o.select_set(True)
bpy.context.view_layer.objects.active=pm[0]
if len(pm)>1: bpy.ops.object.join()
part=bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
part.location=(0,0,0)
mxdim=max(part.dimensions)
cam_d=bpy.data.cameras.new("c"); cam_d.type="ORTHO"; cam_d.ortho_scale=mxdim*1.5
cam=bpy.data.objects.new("c",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(38); dist=mxdim*4
cen=mathutils.Vector((0,0,0))
cam.location=(0,-dist*math.cos(e),dist*math.sin(e))
look=cen-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
tmp=os.path.abspath("cine/_show/_tstmp.png"); RES=230
canvas=Image.new("RGB",(RES*3+40,RES*2+50),(22,24,30)); dr=ImageDraw.Draw(canvas)
for i,(lab,rot) in enumerate(ROTS):
    part.rotation_mode='XYZ'; part.rotation_euler=tuple(math.radians(a) for a in rot)
    bpy.context.view_layer.update()
    sc.render.resolution_x=RES; sc.render.resolution_y=RES
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    im=Image.open(tmp).convert("RGBA"); b=Image.new("RGBA",im.size,(30,32,40,255)); b.alpha_composite(im)
    x=10+(i%3)*(RES+10); y=28+(i//3)*(RES+22)
    canvas.paste(b.convert("RGB"),(x,y)); dr.text((x,y-16),lab,fill=(235,235,245))
canvas.save(OUT)
if os.path.exists(tmp): os.remove(tmp)
print("SAVED",OUT)
