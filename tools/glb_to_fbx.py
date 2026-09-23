"""GLB -> FBX for Mixamo upload (headless bpy). Centers + scales to ~human height so Mixamo auto-rig behaves."""
import bpy, sys, os, math, mathutils
GLB=os.path.abspath(sys.argv[1]); OUT=os.path.abspath(sys.argv[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc=bpy.context.scene
# bounds
dg=bpy.context.evaluated_depsgraph_get(); mn=mathutils.Vector((1e9,)*3); mx=-mn
for o in sc.objects:
    if o.type=="MESH":
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            w=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
h=(mx.z-mn.z) or 1.0
s=1.8/h  # ~1.8 m tall
cen=(mn+mx)*0.5
for o in sc.objects:
    if o.parent is None:
        o.scale=(o.scale[0]*s,o.scale[1]*s,o.scale[2]*s)
        o.location=(o.location[0]-cen.x*s, o.location[1]-cen.y*s, o.location[2]-mn.z*s)  # feet at z=0
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, path_mode="COPY", embed_textures=True,
    axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE")
print("FBX ->", OUT, os.path.getsize(OUT)//1024, "KB")
