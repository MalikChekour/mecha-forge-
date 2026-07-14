# -*- coding: utf-8 -*-
"""Import an animated glTF and report armature + actions + frame ranges (to design the sheet harness)."""
import bpy, sys
model = sys.argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=model)
arms = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
print("ARMATURES:", [a.name for a in arms])
print("MESHES:", [m.name for m in meshes])
print("ACTIONS (%d):" % len(bpy.data.actions))
for a in bpy.data.actions:
    fr = a.frame_range
    print("  %-18s frames %.0f..%.0f" % (a.name, fr[0], fr[1]))
# forward axis hint: print armature/mesh dimensions
if meshes:
    import mathutils
    from mathutils import Vector
    mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector((min(mn[i], w[i]) for i in range(3)))
            mx = Vector((max(mx[i], w[i]) for i in range(3)))
    print("BBOX min", tuple(round(v,2) for v in mn), "max", tuple(round(v,2) for v in mx))
