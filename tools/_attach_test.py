import bpy, math, mathutils, os
def R(d): return math.radians(d)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/vortex/rigged.glb"))
sc=bpy.context.scene
arm=[o for o in sc.objects if o.type=="ARMATURE"][0]; pb=arm.pose.bones
for b in pb: b.rotation_mode="XYZ"
for n,r in {"Spine":(R(-4),0,0),"RightArm":(R(-46),R(-10),R(8)),"RightForeArm":(R(-58),0,0),
            "LeftArm":(R(-34),R(12),R(-10)),"LeftForeArm":(R(-58),0,0)}.items():
    if n in pb: pb[n].rotation_euler=r
bpy.context.view_layer.update()
mech_objs=[o for o in sc.objects if o.type=="MESH"]
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/w_energy_rifle/model.glb"))
rifle_objs=[o for o in bpy.data.objects if o not in before and o.type=="MESH"]
emp=bpy.data.objects.new("rifle_root",None); sc.collection.objects.link(emp)
for o in rifle_objs: o.parent=emp
def bbox(objs):
    dg=bpy.context.evaluated_depsgraph_get(); mn=mathutils.Vector((1e9,)*3); mx=-mn
    for o in objs:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            w=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
    return mn,mx
bpy.context.view_layer.update()
# mech metrics
mmn,mmx=bbox(mech_objs); msize=max((mmx-mmn).x,(mmx-mmn).y,(mmx-mmn).z)
hand=(arm.matrix_world@pb["RightHand"].head)
print("MECH size",round(msize,3),"HAND",tuple(round(v,3) for v in hand))
# scale rifle so its length ~ 0.85 * mech height
rmn,rmx=bbox(rifle_objs); rdim=rmx-rmn
s=(0.60*(mmx.z-mmn.z))/max(rdim.x,1e-3); emp.scale=(s,s,s)
bpy.context.view_layer.update()
rmn,rmx=bbox(rifle_objs); rdim=rmx-rmn; rcen=(rmn+rmx)*0.5
print("RIFLE after scale dim",tuple(round(d,3) for d in rdim))
# grip ~62% from muzzle (min X) along X, lower third
grip=mathutils.Vector((rmn.x+0.62*rdim.x, rcen.y, rmn.z+0.32*rdim.z))
# move so grip -> hand, and pull the rifle toward camera (-Y) so it sits in FRONT of the torso
off=hand-grip; off.y-=0.14
emp.location+=off
bpy.context.view_layer.update()
rmn,rmx=bbox(rifle_objs); print("RIFLE final X",round(rmn.x,2),round(rmx.x,2),"Z",round(rmn.z,2),round(rmx.z,2))
# render
RES=440
sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=22
sc.render.resolution_x=RES; sc.render.resolution_y=RES; sc.render.film_transparent=True; sc.render.image_settings.color_mode="RGBA"
cam_d=bpy.data.cameras.new("c"); cam_d.type="ORTHO"; cam_d.ortho_scale=msize*1.3
cam=bpy.data.objects.new("c",cam_d); sc.collection.objects.link(cam); sc.camera=cam
cen=(mmn+mmx)*0.5; e=R(40); dist=msize*4
cam.location=(cen.x, cen.y-dist*math.cos(e), cen.z+dist*math.sin(e))
cam.rotation_euler=(cen-mathutils.Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True; w.node_tree.nodes.get("Background").inputs["Strength"].default_value=0.5
for nm,en,ro in [("k",4.5,(52,8,-34)),("f",1.8,(66,-6,46)),("r",4.0,(-38,0,160))]:
    d=bpy.data.lights.new(nm,"SUN"); d.energy=en; o=bpy.data.objects.new(nm,d); sc.collection.objects.link(o); o.rotation_euler=tuple(R(a) for a in ro)
sc.render.filepath=os.path.abspath("cine/_show/vortex_rifle3d_front.png")
bpy.ops.render.render(write_still=True); print("rendered")
