import bpy
m = bpy.data.materials.new("t"); m.use_nodes = True
b = m.node_tree.nodes.get("Principled BSDF")
for i in b.inputs:
    print("SOCK", repr(i.name), i.type)
