import bpy, sys, os
FBX=os.path.abspath(sys.argv[1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX, automatic_bone_orientation=True)
import numpy as np
for o in bpy.context.scene.objects:
    if o.type!="MESH": continue
    print("MESH", o.name, "mats:", len(o.data.materials))
    for m in o.data.materials:
        if not m: continue
        print("  MAT", m.name, "use_nodes", m.use_nodes)
        if not m.use_nodes: continue
        for n in m.node_tree.nodes:
            if n.type=="BSDF_PRINCIPLED":
                bc=n.inputs["Base Color"]
                print("    BSDF base_color default", tuple(round(x,3) for x in bc.default_value))
                if bc.is_linked:
                    src=bc.links[0].from_node
                    print("    -> linked from", src.type, getattr(src,'image',None))
                    if src.type=="TEX_IMAGE" and src.image:
                        img=src.image
                        print("    IMG", img.name, img.size[:], "haspix", img.has_data)
                        if img.has_data and img.size[0]>0:
                            px=np.array(img.pixels[:]).reshape(-1,4)
                            print("    IMG mean RGB", tuple(round(float(x),3) for x in px[:,:3].mean(0)))
            if n.type=="TEX_IMAGE" and n.image:
                print("    (any TEX_IMAGE)", n.image.name, n.image.size[:])
