import bpy, sys, os
F=os.path.abspath(sys.argv[1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=F)
ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
imgs=[i for i in bpy.data.images if i.name not in ('Render Result','Viewer Node')]
mats=set()
for o in ms:
    for s in o.material_slots:
        if s.material: mats.add(s.material.name)
print("FBXCHECK", os.path.basename(F), "meshes", len(ms), "verts", sum(len(o.data.vertices) for o in ms),
      "materials", len(mats), "images", len(imgs), [i.size[0] for i in imgs][:4])
