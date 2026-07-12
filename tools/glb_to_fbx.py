#!/usr/bin/env python3
"""
mecha-forge — convert a static Meshy GLB into a Mixamo-ready FBX (single mesh,
transforms applied, textures embedded, Y-up standing A-pose). Mixamo only accepts
FBX/OBJ/ZIP and only auto-rigs bipeds, so this is the upload artifact for the
humanoid enemies whose Meshy credits ran out (raider, crusher).

  python glb_to_fbx.py <in.glb> <out.fbx>
"""
import bpy, sys, os

GLB = os.path.abspath(sys.argv[1])
OUT = os.path.abspath(sys.argv[2])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise RuntimeError("no mesh in GLB")
for o in bpy.context.scene.objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = meshes[0]
for o in meshes:
    o.select_set(True)
if len(meshes) > 1:
    bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# drop any stray non-mesh objects (cameras/lights/empties) so Mixamo sees a clean char
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)

for o in bpy.context.scene.objects:
    o.select_set(o.type == "MESH")
bpy.ops.export_scene.fbx(
    filepath=OUT,
    use_selection=True,
    object_types={"MESH"},
    embed_textures=True,
    path_mode="COPY",
    mesh_smooth_type="FACE",
    add_leaf_bones=False,
    bake_anim=False,
    axis_forward="-Z",
    axis_up="Y",
    global_scale=1.0,
    apply_unit_scale=True,
)
print("FBX", OUT, "%.1f KB" % (os.path.getsize(OUT) / 1024.0),
      "verts", len(mesh.data.vertices), "tris", len(mesh.data.polygons))
