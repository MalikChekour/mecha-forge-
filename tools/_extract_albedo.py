import bpy, sys, os
GLB=os.path.abspath(sys.argv[1]); OUT=os.path.abspath(sys.argv[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
best=None
for m in bpy.data.materials:
    if not m.use_nodes: continue
    for n in m.node_tree.nodes:
        if n.type=="BSDF_PRINCIPLED":
            bc=n.inputs["Base Color"]
            if bc.is_linked and bc.links[0].from_node.type=="TEX_IMAGE":
                img=bc.links[0].from_node.image
                if img and img.has_data: best=img
if best is None:
    # fallback: any image with data
    for img in bpy.data.images:
        if img.has_data and img.size[0]>1: best=img; break
if best is None: print("NO IMAGE"); sys.exit(1)
best.filepath_raw=OUT; best.file_format="PNG"; best.save()
print("ALBEDO ->", OUT, best.size[:])
