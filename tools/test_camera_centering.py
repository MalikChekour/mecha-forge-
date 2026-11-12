import bpy
import math
import os

OUT_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\decor\tech_maze"
TEX_DIR = os.path.join(OUT_DIR, "textures")
TEX_HAZARD = os.path.join(TEX_DIR, "tex_wall_hazard.png")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 16
scene.render.film_transparent = True
scene.render.resolution_x = 256
scene.render.resolution_y = 128
scene.render.filepath = os.path.join(OUT_DIR, "test_centered_wall.png")

# Lighting: Key Sun + Front Fill
bpy.ops.object.light_add(type='SUN', location=(4, -8, 8), rotation=(math.radians(45), math.radians(10), math.radians(-25)))
sun = bpy.context.active_object
sun.data.energy = 5.5
sun.data.color = (1.0, 0.98, 0.95)

bpy.ops.object.light_add(type='SUN', location=(-4, -8, 6), rotation=(math.radians(35), math.radians(-10), math.radians(25)))
fill = bpy.context.active_object
fill.data.energy = 3.0
fill.data.color = (0.7, 0.85, 1.0)

# Build a test horizontal wall
length = 4.0
depth = 0.95
height = 1.35
z_center = height / 2.0

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, z_center))
wall = bpy.context.active_object
wall.scale = (length, depth, height)
bpy.ops.object.transform_apply(scale=True)

# Add bevel
bev = wall.modifiers.new(name="Bevel", type='BEVEL')
bev.width = 0.05
bev.segments = 2

# Top cap
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, height + 0.08))
cap = bpy.context.active_object
cap.scale = (length, depth + 0.12, 0.18)
bpy.ops.object.transform_apply(scale=True)
bev2 = cap.modifiers.new(name="Bevel", type='BEVEL')
bev2.width = 0.03

# Material with box mapping
mat = bpy.data.materials.new(name="HazardMat")
nodes = mat.node_tree.nodes
links = mat.node_tree.links
nodes.clear()
output = nodes.new('ShaderNodeOutputMaterial')
bsdf = nodes.new('ShaderNodeBsdfPrincipled')
links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

coord = nodes.new('ShaderNodeTexCoord')
mapping = nodes.new('ShaderNodeMapping')
mapping.inputs['Scale'].default_value = (0.5, 0.5, 0.5)
links.new(coord.outputs['Object'], mapping.inputs['Vector'])

tex = nodes.new('ShaderNodeTexImage')
tex.image = bpy.data.images.load(TEX_HAZARD)
tex.projection = 'BOX'
tex.projection_blend = 0.15
links.new(mapping.outputs['Vector'], tex.inputs['Vector'])
links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
bsdf.inputs['Metallic'].default_value = 0.82
bsdf.inputs['Roughness'].default_value = 0.35

wall.data.materials.append(mat)
cap.data.materials.append(mat)

# Camera: Point directly at (0, 0, z_center)
pitch_deg = 58.0   # 2.5D angle
dist = 10.0
pitch_rad = math.radians(pitch_deg)

cam_y = -dist * math.cos(pitch_rad)
cam_z = z_center + dist * math.sin(pitch_rad)

bpy.ops.object.camera_add(location=(0, cam_y, cam_z), rotation=(pitch_rad, 0, 0))
cam = bpy.context.active_object
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 4.3
scene.camera = cam

bpy.ops.render.render(write_still=True)
print("Rendered test_centered_wall.png")
