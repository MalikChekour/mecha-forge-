# -*- coding: utf-8 -*-
"""Rendu des 4 modeles de boss Meshy (front) pour planifier la coupe du torse."""
import bpy, os, sys, math, mathutils
from PIL import Image, ImageDraw

MODELS = [("titan","meshy_in/titan/model.glb"),("crusher","meshy_in/crusher/model.glb"),
          ("midboss","meshy_in/midboss/model.glb"),("endboss","meshy_in/endboss/model.glb")]
OUT = os.path.abspath("cine/_show/bosses_raw.png")
RES = 260

def render_one(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    sc=bpy.context.scene
    sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=10; sc.cycles.use_denoising=True
    sc.render.resolution_x=RES; sc.render.resolution_y=RES; sc.render.film_transparent=True
    sc.render.image_settings.color_mode="RGBA"
    w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
    bg=w.node_tree.nodes.get("Background"); bg.inputs["Color"].default_value=(0.18,0.19,0.22,1); bg.inputs["Strength"].default_value=0.7
    def sun(e,rot,col=(1,1,1)):
        d=bpy.data.lights.new("s",type="SUN"); d.energy=e; d.color=col; d.angle=math.radians(6)
        o=bpy.data.objects.new("s",d); sc.collection.objects.link(o); o.rotation_euler=tuple(math.radians(a) for a in rot)
    sun(4,(55,10,-30)); sun(2,(60,-10,50),(0.8,0.85,1)); sun(2.5,(-40,0,150),(0.8,0.9,1))
    meshes=[o for o in sc.objects if o.type=="MESH"]
    mn=mathutils.Vector((1e9,)*3); mx=-mn; dg=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            wv=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
    cen=(mn+mx)*0.5; size=max((mx-mn).x,(mx-mn).y,(mx-mn).z,1e-3)
    cam_d=bpy.data.cameras.new("c"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.15
    cam=bpy.data.objects.new("c",cam_d); sc.collection.objects.link(cam); sc.camera=cam
    e=math.radians(18); dist=size*4
    cam.location=(cen.x, cen.y-dist*math.cos(e), cen.z+dist*math.sin(e))
    look=cen-mathutils.Vector(cam.location); cam.rotation_euler=look.to_track_quat("-Z","Y").to_euler()
    tmp=os.path.abspath("cine/_show/_brtmp.png")
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    return Image.open(tmp).convert("RGBA").copy(), round(size,2)

canvas=Image.new("RGB",(RES*4+50,RES+40),(22,24,30)); dr=ImageDraw.Draw(canvas)
for i,(name,path) in enumerate(MODELS):
    im,sz=render_one(path)
    b=Image.new("RGBA",im.size,(30,32,40,255)); b.alpha_composite(im)
    x=10+i*(RES+10); canvas.paste(b.convert("RGB"),(x,28)); dr.text((x,8),"%s (h~%s)"%(name,sz),fill=(235,235,245))
    print("rendered",name)
canvas.save(OUT); print("SAVED",OUT)
