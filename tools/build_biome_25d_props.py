#!/usr/bin/env python3
"""Builds high-fidelity 2.5D props for Desert, Jungle, Volcanic, and Swamp using Blender 5.0 (bpy)
and generated PBR textures, following the exact Level 1 (TechMaze) aesthetic standards.
"""
import os
import sys
import math
from PIL import Image
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "game", "assets", "decor")
TEX_DIR = os.path.join(OUT_DIR, "textures")
os.makedirs(TEX_DIR, exist_ok=True)

SRC_TEXTURES = {
    "desert": r"C:\Users\Administrator\.gemini\antigravity-ide\brain\57e87bbd-6285-4159-a061-1b83a072c5b4\desert_pbr_tex_1794342449349.jpg",
    "jungle": r"C:\Users\Administrator\.gemini\antigravity-ide\brain\57e87bbd-6285-4159-a061-1b83a072c5b4\jungle_pbr_tex_1794342466033.jpg",
    "volcanic": r"C:\Users\Administrator\.gemini\antigravity-ide\brain\57e87bbd-6285-4159-a061-1b83a072c5b4\volcanic_pbr_tex_1794342482721.jpg",
    "swamp": r"C:\Users\Administrator\.gemini\antigravity-ide\brain\57e87bbd-6285-4159-a061-1b83a072c5b4\swamp_pbr_tex_1794342497276.jpg"
}

TEX_PATHS = {
    "desert": os.path.join(TEX_DIR, "tex_desert_solar.png"),
    "jungle": os.path.join(TEX_DIR, "tex_jungle_ruin.png"),
    "volcanic": os.path.join(TEX_DIR, "tex_volcanic_foundry.png"),
    "swamp": os.path.join(TEX_DIR, "tex_swamp_steel.png")
}

def prepare_textures():
    print("[TEXTURES] Converting and installing PBR texture maps...")
    for k, src in SRC_TEXTURES.items():
        dst = TEX_PATHS[k]
        if os.path.exists(src):
            img = Image.open(src)
            img.save(dst, "PNG")
            print(f"  -> Saved {dst} ({img.size[0]}x{img.size[1]})")

def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def setup_lighting():
    # 1. Main Sun Light (Key) from top-front-left
    bpy.ops.object.light_add(type='SUN', location=(5, -8, 10), rotation=(math.radians(45), math.radians(10), math.radians(-30)))
    sun = bpy.context.active_object
    sun.data.energy = 5.2
    sun.data.color = (1.0, 0.98, 0.94)

    # 2. Fill light from front-right
    bpy.ops.object.light_add(type='SUN', location=(-5, -6, 8), rotation=(math.radians(35), math.radians(-10), math.radians(20)))
    fill = bpy.context.active_object
    fill.data.energy = 2.6
    fill.data.color = (0.7, 0.85, 1.0)

    # 3. Top rim light
    bpy.ops.object.light_add(type='POINT', location=(0, 2, 6))
    rim = bpy.context.active_object
    rim.data.energy = 110.0
    rim.data.color = (0.8, 0.95, 1.0)

def setup_camera_trackto(target_z=1.0, ortho_scale=3.8, cam_loc=(0, -7.0, 6.0)):
    scene = bpy.context.scene
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, target_z))
    target = bpy.context.active_object

    bpy.ops.object.camera_add(location=cam_loc)
    cam = bpy.context.active_object
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = ortho_scale
    scene.camera = cam

    tt = cam.constraints.new(type='TRACK_TO')
    tt.target = target
    tt.track_axis = 'TRACK_NEGATIVE_Z'
    tt.up_axis = 'UP_Y'

def create_pbr_material(name, tex_path, metallic=0.75, roughness=0.35, scale=(0.5, 0.5, 0.5)):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

    coord = nodes.new('ShaderNodeTexCoord')
    mapping = nodes.new('ShaderNodeMapping')
    mapping.inputs['Scale'].default_value = scale
    links.new(coord.outputs['Object'], mapping.inputs['Vector'])

    tex_node = nodes.new('ShaderNodeTexImage')
    if os.path.exists(tex_path):
        tex_node.image = bpy.data.images.load(tex_path)
    tex_node.projection = 'BOX'
    tex_node.projection_blend = 0.2
    links.new(mapping.outputs['Vector'], tex_node.inputs['Vector'])

    links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    return mat

def create_neon_material(name, color=(0.0, 0.95, 1.0), strength=4.5):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Emission Color'].default_value = (*color, 1.0)
    bsdf.inputs['Emission Strength'].default_value = strength
    return mat

def add_bevel(obj, width=0.04, segments=2):
    bev = obj.modifiers.new(name="B", type='BEVEL')
    bev.width = width
    bev.segments = segments
    return bev

# -------------------------------------------------------------
# BUILDER 1: DESERT OBELISQUE SOLAIRE
# -------------------------------------------------------------
def build_desert_obelisk():
    clean_scene()
    setup_lighting()
    mat_desert = create_pbr_material("MatDesert", TEX_PATHS["desert"], metallic=0.7, roughness=0.3)
    mat_solar = create_neon_material("MatSolarAmber", color=(1.0, 0.65, 0.1), strength=5.5)
    mat_cyan = create_neon_material("MatSolarCyan", color=(0.1, 0.9, 1.0), strength=4.5)

    # Stepped pedestal base
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.12))
    base1 = bpy.context.active_object
    base1.scale = (2.2, 1.6, 0.24)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(base1, 0.05)
    base1.data.materials.append(mat_desert)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.36))
    base2 = bpy.context.active_object
    base2.scale = (1.7, 1.2, 0.24)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(base2, 0.04)
    base2.data.materials.append(mat_desert)

    # Central Obelisk Monolith Tower (tapered)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.65, depth=2.0, location=(0, 0, 1.48))
    tower = bpy.context.active_object
    add_bevel(tower, 0.04)
    tower.data.materials.append(mat_desert)

    # 4 Solar Collector Wings
    for angle in [0, 90, 180, 270]:
        rad = math.radians(angle)
        x = math.cos(rad) * 0.72
        y = math.sin(rad) * 0.72
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, 1.5))
        fin = bpy.context.active_object
        fin.scale = (0.12, 0.28, 1.4)
        fin.rotation_euler = (0, 0, rad)
        bpy.ops.object.transform_apply(scale=True, rotation=True)
        add_bevel(fin, 0.02)
        fin.data.materials.append(mat_desert)

    # Glowing solar conduit ring
    bpy.ops.mesh.primitive_torus_add(major_radius=0.74, minor_radius=0.06, location=(0, 0, 1.8))
    ring = bpy.context.active_object
    ring.data.materials.append(mat_solar)

    # Glowing Pyramidal Apex Prism
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.55, depth=0.85, location=(0, 0, 2.8))
    apex = bpy.context.active_object
    apex.rotation_euler = (0, 0, math.radians(45))
    bpy.ops.object.transform_apply(rotation=True)
    apex.data.materials.append(mat_solar)

    setup_camera_trackto(target_z=1.35, ortho_scale=3.6)
    render_to_file("desert_obelisque_solaire.png")

# -------------------------------------------------------------
# BUILDER 2: JUNGLE PILIER DE RACINES
# -------------------------------------------------------------
def build_jungle_pillar():
    clean_scene()
    setup_lighting()
    mat_jungle = create_pbr_material("MatJungle", TEX_PATHS["jungle"], metallic=0.3, roughness=0.6)
    mat_emerald = create_neon_material("MatEmerald", color=(0.1, 1.0, 0.4), strength=5.2)

    # Stepped Temple Base
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.15))
    b1 = bpy.context.active_object
    b1.scale = (2.0, 1.8, 0.3)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(b1, 0.05)
    b1.data.materials.append(mat_jungle)

    # Carved cylindrical totem pillar
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.68, depth=2.1, location=(0, 0, 1.35))
    pil = bpy.context.active_object
    add_bevel(pil, 0.05)
    pil.data.materials.append(mat_jungle)

    # Overgrown coiled root bands
    for z_off, r_rot in [(0.7, 25), (1.3, -40), (1.9, 30)]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.75, minor_radius=0.10, location=(0, 0, z_off))
        root = bpy.context.active_object
        root.rotation_euler = (math.radians(12), math.radians(r_rot), 0)
        bpy.ops.object.transform_apply(rotation=True)
        root.data.materials.append(mat_jungle)

    # Bioluminescent Lotus Node / Bud on top
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.48, location=(0, 0, 2.65))
    node = bpy.context.active_object
    node.scale = (1.0, 0.9, 1.3)
    bpy.ops.object.transform_apply(scale=True)
    node.data.materials.append(mat_emerald)

    # Bio-conduit vines
    for a in [45, 165, 285]:
        rad = math.radians(a)
        x = math.cos(rad) * 0.70
        y = math.sin(rad) * 0.70
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=1.8, location=(x, y, 1.4))
        vine = bpy.context.active_object
        vine.data.materials.append(mat_emerald)

    setup_camera_trackto(target_z=1.35, ortho_scale=3.6)
    render_to_file("jungle_pilier_racines.png")

# -------------------------------------------------------------
# BUILDER 3: VOLCANIC FOURNEAU LOURD
# -------------------------------------------------------------
def build_volcanic_furnace():
    clean_scene()
    setup_lighting()
    mat_volc = create_pbr_material("MatVolcanic", TEX_PATHS["volcanic"], metallic=0.85, roughness=0.35)
    mat_magma = create_neon_material("MatMagmaCore", color=(1.0, 0.35, 0.02), strength=6.0)

    # Heavy cast-iron octagonal base
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=1.05, depth=0.4, location=(0, 0, 0.2))
    b1 = bpy.context.active_object
    add_bevel(b1, 0.06)
    b1.data.materials.append(mat_volc)

    # Blast Furnace Main Shaft (tapered stack)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.75, depth=1.9, location=(0, 0, 1.35))
    shaft = bpy.context.active_object
    add_bevel(shaft, 0.05)
    shaft.data.materials.append(mat_volc)

    # Molten slag outflow mouth (front slit)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.65, 0.85))
    slit = bpy.context.active_object
    slit.scale = (0.65, 0.3, 0.5)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(slit, 0.03)
    slit.data.materials.append(mat_volc)

    # Molten pool inside slit
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.68, 0.85))
    lava = bpy.context.active_object
    lava.scale = (0.50, 0.12, 0.35)
    bpy.ops.object.transform_apply(scale=True)
    lava.data.materials.append(mat_magma)

    # Industrial Smelting Top Rim Cap
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.92, depth=0.28, location=(0, 0, 2.4))
    rim = bpy.context.active_object
    add_bevel(rim, 0.04)
    rim.data.materials.append(mat_volc)

    # Top molten crucible core
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.6, depth=0.15, location=(0, 0, 2.52))
    top_magma = bpy.context.active_object
    top_magma.data.materials.append(mat_magma)

    # Lateral pressure exhaust pipes
    for x_side in [-0.85, 0.85]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=1.6, location=(x_side, 0, 1.4))
        pipe = bpy.context.active_object
        pipe.data.materials.append(mat_volc)

    setup_camera_trackto(target_z=1.35, ortho_scale=3.6)
    render_to_file("volcanic_fourneau_lourd.png")

# -------------------------------------------------------------
# BUILDER 4: SWAMP ARCHE SUBMERGEE
# -------------------------------------------------------------
def build_swamp_arch():
    clean_scene()
    setup_lighting()
    mat_swamp = create_pbr_material("MatSwamp", TEX_PATHS["swamp"], metallic=0.75, roughness=0.45)
    mat_teal = create_neon_material("MatTealWarn", color=(0.1, 0.85, 0.8), strength=4.5)
    mat_red = create_neon_material("MatRedWarn", color=(1.0, 0.15, 0.1), strength=5.0)

    # Twin submerged skyscraper pylons
    for x in [-0.85, 0.85]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, 0, 1.2))
        pylon = bpy.context.active_object
        pylon.scale = (0.55, 0.75, 2.4)
        bpy.ops.object.transform_apply(scale=True)
        add_bevel(pylon, 0.04)
        pylon.data.materials.append(mat_swamp)

        # Concrete foundation footings
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, 0, 0.15))
        foot = bpy.context.active_object
        foot.scale = (0.85, 1.05, 0.3)
        bpy.ops.object.transform_apply(scale=True)
        add_bevel(foot, 0.04)
        foot.data.materials.append(mat_swamp)

    # Massive rusted floodgate lintel crossbeam
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 2.25))
    lintel = bpy.context.active_object
    lintel.scale = (2.4, 0.85, 0.5)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(lintel, 0.05)
    lintel.data.materials.append(mat_swamp)

    # Warning beacon bar on top
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.44, 2.25))
    bar = bpy.context.active_object
    bar.scale = (1.8, 0.08, 0.12)
    bpy.ops.object.transform_apply(scale=True)
    bar.data.materials.append(mat_teal)

    # Red navigation signal light
    bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.2, location=(0, 0, 2.62))
    light = bpy.context.active_object
    light.data.materials.append(mat_red)

    setup_camera_trackto(target_z=1.35, ortho_scale=3.6)
    render_to_file("swamp_arche_submergee.png")

# -------------------------------------------------------------
# RENDER DISPATCHER
# -------------------------------------------------------------
def render_to_file(filename):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 14
    scene.render.film_transparent = True
    scene.render.resolution_x = 384
    scene.render.resolution_y = 384
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

    out_path = os.path.join(OUT_DIR, filename)
    scene.render.filepath = out_path
    print(f"[RENDER] Rendering 2.5D asset -> {out_path}")
    bpy.ops.render.render(write_still=True)
    print(f"  -> OK: {filename} written ({os.path.getsize(out_path)} bytes)")

def main():
    prepare_textures()
    print("\n--- 1. Building Desert Solar Obelisk (2.5D) ---")
    build_desert_obelisk()

    print("\n--- 2. Building Jungle Overgrown Pillar (2.5D) ---")
    build_jungle_pillar()

    print("\n--- 3. Building Volcanic Smelting Furnace (2.5D) ---")
    build_volcanic_furnace()

    print("\n--- 4. Building Swamp Submerged Floodgate Arch (2.5D) ---")
    build_swamp_arch()

    print("\n[SUCCESS] All 4 2.5D biome props successfully built and rendered!")

if __name__ == "__main__":
    main()
