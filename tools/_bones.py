import bpy, sys
path = sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
for ob in bpy.data.objects:
    if ob.type == 'ARMATURE':
        print("ARMATURE:", ob.name, "bones:", len(ob.data.bones))
        for b in ob.data.bones:
            print("  ", b.name)
        break
