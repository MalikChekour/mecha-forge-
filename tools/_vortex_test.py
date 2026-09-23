import bpy, math, mathutils, os
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/vortex/rigged.glb"))
sc=bpy.context.scene
arm=[o for o in sc.objects if o.type=="ARMATURE"][0]
print("BONES:", [b.name for b in arm.data.bones])
pb=arm.pose.bones
for b in pb: b.rotation_mode="XYZ"
# attack pose (both arms forward) - same angles as build script
def R(d): return math.radians(d)
for n,r in {"Spine":(R(-6),0,0),"LeftArm":(R(-42),R(12),0),"RightArm":(R(-42),R(-12),0),
            "LeftForeArm":(R(-58),0,0),"RightForeArm":(R(-58),0,0)}.items():
    if n in pb: pb[n].rotation_euler=r
bpy.context.view_layer.update()
# render front EL40
sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=14
sc.render.resolution_x=256; sc.render.resolution_y=256; sc.render.film_transparent=True
sc.render.image_settings.color_mode="RGBA"
objs=[o for o in sc.objects if o.type=="MESH"]
dg=bpy.context.evaluated_depsgraph_get(); mn=mathutils.Vector((1e9,)*3); mx=-mn
for o in objs:
    oe=o.evaluated_get(dg)
    for c in oe.bound_box:
        w=oe.matrix_world@mathutils.Vector(c)
        for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
size=max((mx-mn).x,(mx-mn).y,(mx-mn).z,1e-3); cen=(mn+mx)*0.5
cam_d=bpy.data.cameras.new("c"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.12
cam=bpy.data.objects.new("c",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(40); dist=size*4
cam.location=(cen.x, cen.y-dist*math.cos(e), cen.z+dist*math.sin(e))
cam.rotation_euler=(cen-mathutils.Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
bg=w.node_tree.nodes.get("Background"); bg.inputs["Strength"].default_value=0.5
for nm,en,rot in [("k",4.5,(52,8,-34)),("f",1.8,(66,-6,46))]:
    d=bpy.data.lights.new(nm,"SUN"); d.energy=en; o=bpy.data.objects.new(nm,d); sc.collection.objects.link(o); o.rotation_euler=tuple(math.radians(a) for a in rot)
sc.render.filepath=os.path.abspath("cine/_show/vortex_attack_test.png")
bpy.ops.render.render(write_still=True); print("rendered attack test")
