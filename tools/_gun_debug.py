import bpy, math, mathutils, os, sys
sys.argv=[sys.argv[0]]  # avoid --test in the imported module logic
# reuse functions by exec'ing the build module's defs is messy; inline minimal:
def R(d): return math.radians(d)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/vortex/rigged.glb"))
sc=bpy.context.scene; arm=[o for o in sc.objects if o.type=="ARMATURE"][0]; pb=arm.pose.bones
for b in pb: b.rotation_mode="XYZ"
# attack pose
for n,r in {"Spine":(R(-6),0,0),"RightArm":(R(-70),R(-6),R(4)),"RightForeArm":(R(-16),0,0)}.items():
    if n in pb: pb[n].rotation_euler=r
bpy.context.view_layer.update()
mech=[o for o in sc.objects if o.type=="MESH"]
def wbb(objs):
    dg=bpy.context.evaluated_depsgraph_get(); mn=mathutils.Vector((1e9,)*3); mx=-mn
    for o in objs:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            w=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
    return mn,mx
mmn,mmx=wbb(mech); print("MECH bbox",tuple(round(v,2) for v in mmn),tuple(round(v,2) for v in mmx))
bone=pb["RightForeArm"]
head=(arm.matrix_world@bone.matrix)@mathutils.Vector((0,0,0))
tail=(arm.matrix_world@bone.matrix)@mathutils.Vector((0,bone.length,0))
print("FOREARM head",tuple(round(v,2) for v in head),"tail(wrist)",tuple(round(v,2) for v in tail),"len",round(bone.length,3))
# import gun
before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/w_plasma_cannon/model.glb"))
g=[o for o in bpy.data.objects if o not in before and o.type=="MESH"]
print("gun meshes",len(g),"parents",[o.parent.name if o.parent else None for o in g])
gmn,gmx=wbb(g); print("GUN import bbox",tuple(round(v,2) for v in gmn),tuple(round(v,2) for v in gmx))
