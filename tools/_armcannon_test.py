import bpy, math, mathutils, os
def R(d): return math.radians(d)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/vortex/rigged.glb"))
sc=bpy.context.scene; arm=[o for o in sc.objects if o.type=="ARMATURE"][0]; pb=arm.pose.bones
for b in pb: b.rotation_mode="XYZ"
# aim pose: right arm thrust FORWARD (toward camera/enemy)
for n,r in {"Spine":(R(-4),0,0),"RightArm":(R(-70),R(-6),R(4)),"RightForeArm":(R(-18),0,0),
            "LeftArm":(R(-30),R(14),R(-10)),"LeftForeArm":(R(-55),0,0)}.items():
    if n in pb: pb[n].rotation_euler=r
bpy.context.view_layer.update()
mech=[o for o in sc.objects if o.type=="MESH"]
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/w_plasma_cannon/model.glb"))
wobjs=[o for o in bpy.data.objects if o not in before and o.type=="MESH"]
emp=bpy.data.objects.new("cannon",None); sc.collection.objects.link(emp)
for o in wobjs: o.parent=emp
def bbox(objs):
    dg=bpy.context.evaluated_depsgraph_get(); mn=mathutils.Vector((1e9,)*3); mx=-mn
    for o in objs:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            w=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
    return mn,mx
bpy.context.view_layer.update()
mmn,mmx=bbox(mech); mh=mmx.z-mmn.z
hand=(arm.matrix_world@pb["RightHand"].head); fore=(arm.matrix_world@pb["RightForeArm"].head)
fwd=(hand-fore).normalized()  # forearm direction
# orient longest axis -> forearm forward direction
rmn,rmx=bbox(wobjs); dim=rmx-rmn; ax=max(range(3),key=lambda i:dim[i])
if ax==1: emp.rotation_euler=mathutils.Euler((0,0,R(-90)))
elif ax==2: emp.rotation_euler=mathutils.Euler((0,R(90),0))
bpy.context.view_layer.update()
# scale small (arm-cannon ~ 0.34 * mech height)
rmn,rmx=bbox(wobjs); dim=rmx-rmn; s=(0.34*mh)/max(dim.x,1e-3); emp.scale=(s,s,s)
bpy.context.view_layer.update()
# align barrel(+X) to point along fwd, then place breech at the wrist (covers the hand)
ang=math.atan2(fwd.x,-fwd.y)  # rough yaw so +X maps toward fwd in top view
emp.rotation_euler.z += ang
bpy.context.view_layer.update()
rmn,rmx=bbox(wobjs); dim=rmx-rmn; cen=(rmn+rmx)*0.5
breech=mathutils.Vector((rmn.x+0.12*dim.x,cen.y,cen.z))
emp.location += (hand-breech)
bpy.context.view_layer.update()
RES=440
sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=22
sc.render.resolution_x=RES; sc.render.resolution_y=RES; sc.render.film_transparent=True; sc.render.image_settings.color_mode="RGBA"
cen=(mmn+mmx)*0.5; msize=max((mmx-mmn).x,(mmx-mmn).y,mh)
cam_d=bpy.data.cameras.new("c"); cam_d.type="ORTHO"; cam_d.ortho_scale=msize*1.3
cam=bpy.data.objects.new("c",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=R(40); dist=msize*4
cam.location=(cen.x, cen.y-dist*math.cos(e), cen.z+dist*math.sin(e))
cam.rotation_euler=(cen-mathutils.Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True; w.node_tree.nodes.get("Background").inputs["Strength"].default_value=0.5
for nm,en,ro in [("k",4.5,(52,8,-34)),("f",1.8,(66,-6,46)),("r",4.0,(-38,0,160))]:
    d=bpy.data.lights.new(nm,"SUN"); d.energy=en; o=bpy.data.objects.new(nm,d); sc.collection.objects.link(o); o.rotation_euler=tuple(R(a) for a in ro)
sc.render.filepath=os.path.abspath("cine/_show/vortex_armcannon.png")
bpy.ops.render.render(write_still=True); print("rendered")
