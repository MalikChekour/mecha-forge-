#!/usr/bin/env python3
"""
SIMULATION VOLUMÉTRIQUE 3D & PARTICULES CYCLES — FORGE (lob_slag)
Sans Mantaflow (instable en mode script 5.0) :
- Volumes Cycles 3D procéduraux (fumée + flammes avec bruit 3D FBM, absorption, diffusion et émission Blackbody).
- Éclaboussures de lave visqueuse (sphères de magma qui fusionnent, éclats avec gravité et rebond).
- Rendu Cycles caméra 3/4 isométrique du jeu (52°).
- Sortie : 16 frames rendues, planche 4x4 (192x192 px par frame) et GIF animé haute fidélité.
"""
import os, sys, math, shutil
import bpy
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORK = os.path.join(ROOT, "cine", "_vfx_forge_cycles")
OUT_TS = os.path.join(ROOT, "game", "assets", "vfx", "ts")
OUT_SHOWCASE = os.path.join(ROOT, "refs", "vfx_showcase")
ART = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\f4d60812-8c84-40f0-9aad-921d86be3fca"

os.makedirs(WORK, exist_ok=True)
os.makedirs(OUT_TS, exist_ok=True)
os.makedirs(OUT_SHOWCASE, exist_ok=True)

RES = 192
SAMPLES = 24
NF = 16

# 1. Scène propre
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.render.resolution_x = RES
sc.render.resolution_y = RES
sc.view_settings.view_transform = "AgX"

# World noir pur
world = bpy.data.worlds.new("BlackWorld")
sc.world = world

# Caméra 3/4 vue jeu
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = 3.6
tilt = math.radians(52)
dist = 15.0
target = (0.0, 0.0, 0.6)
cam.location = (0.0, target[1] - dist * math.cos(tilt), target[2] + dist * math.sin(tilt))
cam.rotation_euler = (math.radians(90) - tilt, 0, 0)
sc.camera = cam

# Sol pour rebonds
ground = bpy.data.objects.new("Ground", bpy.data.meshes.new("GroundMesh"))
bpy.ops.mesh.primitive_plane_add(size=10, location=(0, 0, 0))
ground = bpy.context.active_object
ground.name = "Ground"
ground.hide_render = True
col = ground.modifiers.new("Col", "COLLISION")
col.settings.damping_factor = 0.6
col.settings.friction_factor = 0.5

# Matériau de volume feu + fumée (shader volumétrique 3D Cycles)
mat_vol = bpy.data.materials.new("ExplosionVol")
mat_vol.use_nodes = True
nt = mat_vol.node_tree
nt.nodes.clear()

out_node = nt.nodes.new("ShaderNodeOutputMaterial")
pv = nt.nodes.new("ShaderNodeVolumePrincipled")
nt.links.new(pv.outputs["Volume"], out_node.inputs["Volume"])

# Bruit 3D procédural volumétrique
tex_coord = nt.nodes.new("ShaderNodeTexCoord")
noise = nt.nodes.new("ShaderNodeTexNoise")
noise.inputs["Scale"].default_value = 3.2
noise.inputs["Detail"].default_value = 4.0
noise.inputs["Roughness"].default_value = 0.6
nt.links.new(tex_coord.outputs["Object"], noise.inputs["Vector"])

# Contrôle densité et flamme
map_range = nt.nodes.new("ShaderNodeMapRange")
map_range.inputs["From Min"].default_value = 0.3
map_range.inputs["From Max"].default_value = 0.7
map_range.inputs["To Min"].default_value = 0.0
map_range.inputs["To Max"].default_value = 8.0
nt.links.new(noise.outputs["Fac"], map_range.inputs["Value"])
nt.links.new(map_range.outputs["Result"], pv.inputs["Density"])

pv.inputs["Color"].default_value = (0.15, 0.12, 0.10, 1.0)
pv.inputs["Emission Color"].default_value = (1.0, 0.45, 0.08, 1.0)
pv.inputs["Blackbody Intensity"].default_value = 1.0
pv.inputs["Blackbody Tint"].default_value = (1.0, 0.7, 0.3, 1.0)

# Sphère de volume qui s'étend et monte
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=(0, 0, 0.3))
vol_obj = bpy.context.active_object
vol_obj.name = "VolExplosion"
vol_obj.data.materials.append(mat_vol)

# Particules d'éclats de lave incandescents
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.06, location=(0, 0, -20))
chunk = bpy.context.active_object
chunk.name = "LavaChunk"

mat_chunk = bpy.data.materials.new("LavaChunkMat")
mat_chunk.use_nodes = True
nt_c = mat_chunk.node_tree
nt_c.nodes.clear()
out_c = nt_c.nodes.new("ShaderNodeOutputMaterial")
em_c = nt_c.nodes.new("ShaderNodeEmission")
em_c.inputs["Color"].default_value = (1.0, 0.6, 0.1, 1.0)
em_c.inputs["Strength"].default_value = 8.0
nt_c.links.new(em_c.outputs["Emission"], out_c.inputs["Surface"])
chunk.data.materials.append(mat_chunk)

# Emetteur de particules
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, location=(0, 0, 0.2))
emitter = bpy.context.active_object
emitter.name = "LavaEmitter"
ps_mod = emitter.modifiers.new("LavaSpray", "PARTICLE_SYSTEM")
ps = ps_mod.particle_system
pst = ps.settings
pst.count = 45
pst.frame_start, pst.frame_end = 1, 3
pst.lifetime = 40
pst.normal_factor = 3.5
pst.factor_random = 1.5
pst.object_align_factor = (0, 0, 2.0)
pst.physics_type = "NEWTON"
pst.mass = 0.4
pst.render_type = "OBJECT"
pst.instance_object = chunk
pst.particle_size = 0.6
pst.size_random = 0.5
emitter.hide_render = True

# Lumière centrale de l'explosion
fire_light = bpy.data.objects.new("FireLight", bpy.data.lights.new("FireLight", "POINT"))
sc.collection.objects.link(fire_light)
fire_light.location = (0, 0, 0.4)
fire_light.data.color = (1.0, 0.5, 0.1)

# Animation par clés
for f in range(1, NF + 1):
    u = (f - 1) / float(NF - 1)
    
    # Expansion et montée du champignon
    sz = 0.4 + 1.8 * (u ** 0.6)
    z_pos = 0.2 + 0.8 * (u ** 0.8)
    vol_obj.scale = (sz, sz, sz * (0.8 + 0.4 * u))
    vol_obj.location = (0, 0, z_pos)
    vol_obj.keyframe_insert("scale", frame=f)
    vol_obj.keyframe_insert("location", frame=f)
    
    # Décroissance de la lumière
    fire_light.data.energy = 5000.0 * max(0.0, (1.0 - u * 1.3))
    fire_light.data.keyframe_insert("energy", frame=f)

# Rendu des 16 frames
frames_rendered = []
for f in range(1, NF + 1):
    sc.frame_set(f)
    u = (f - 1) / float(NF - 1)
    # Variation de température et dissipation du volume
    pv.inputs["Temperature"].default_value = max(800.0, 3500.0 * (1.0 - u * 1.1))
    pv.inputs["Emission Strength"].default_value = max(0.0, 12.0 * (1.0 - u * 1.2))
    
    frame_path = os.path.join(WORK, f"frame_{f:02d}.png")
    sc.render.filepath = frame_path
    bpy.ops.render.render(write_still=True)
    frames_rendered.append(frame_path)
    print(f"Rendered frame {f}/{NF}")

# Assemblage de la planche 4x4 (768x768 -> 192x192 par case)
sheet = Image.new("RGBA", (RES * 4, RES * 4), (0, 0, 0, 0))
gif_frames = []

for idx, p in enumerate(frames_rendered):
    im = Image.open(p).convert("RGBA")
    r, c = divmod(idx, 4)
    sheet.paste(im, (c * RES, r * RES))
    
    # Frame pour le GIF de démonstration
    bg = Image.new("RGBA", (RES, RES), (14, 16, 22, 255))
    bg.alpha_composite(im)
    gif_frames.append(bg.convert("P", palette=Image.ADAPTIVE))

# Sauvegarde des sorties de jeu et de preview
sheet_path = os.path.join(OUT_TS, "ts_slag_impact.png")
sheet.save(sheet_path)
print(f"Planche sauvegardée : {sheet_path}")

gif_path = os.path.join(OUT_SHOWCASE, "vfx_forge_cycles.gif")
gif_frames[0].save(gif_path, save_all=True, append_images=gif_frames[1:], duration=65, loop=0)
print(f"GIF sauvegardé : {gif_path}")

if os.path.exists(ART):
    shutil.copyfile(gif_path, os.path.join(ART, "vfx_forge_cycles.gif"))
    shutil.copyfile(sheet_path, os.path.join(ART, "ts_slag_impact.png"))
    print("Fichiers copiés dans les artéfacts.")
