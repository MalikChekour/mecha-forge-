import bpy
import time

# Clean scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# Add a test cube
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 1))
cube = bpy.context.active_object

# Add a sun light
bpy.ops.object.light_add(type='SUN', location=(5, -5, 10))
light = bpy.context.active_object
light.data.energy = 4.0

# Add a camera (ortho 2.5D view)
bpy.ops.object.camera_add(location=(6, -6, 8), rotation=(1.047, 0, 0.785))
cam = bpy.context.active_object
scene.camera = cam
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 5.0

# Render settings
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'

# Test Cycles CPU
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 16
scene.render.filepath = r'C:\Users\Administrator\mecha-forge\game\assets\decor\tech_maze\test_render_cycles.png'

t0 = time.time()
bpy.ops.render.render(write_still=True)
print(f"Cycles render finished in {time.time() - t0:.2f}s")
