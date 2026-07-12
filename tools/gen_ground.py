#!/usr/bin/env python3
import bpy
import sys
import os
import math
import random
import mathutils

# ====================================================================
# REUSED: Render Setup, Lighting, and Biome Material Functions
# ====================================================================

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    return sc

def setup_render_settings(sc, res, samples):
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    # OPAQUE output: film_transparent is False
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"

def setup_world_and_lights(sc):
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.08, 0.09, 0.13, 1.0)
    # World BG strength ~0.5
    bg.inputs["Strength"].default_value = 0.5

    def sun(name, e, rot, col):
        d = bpy.data.lights.new(name, type="SUN")
        d.energy = e
        d.color = col
        d.angle = math.radians(5)
        o = bpy.data.objects.new(name, d)
        sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)

    # Key sun at ~40 deg elevation (rot X ~ 50.0)
    sun("key", 4.0, (50, 8, -34), (1.0, 0.96, 0.9))
    # Softer fill from above
    sun("fill", 1.4, (66, -6, 46), (0.75, 0.85, 1.0))
    sun("rim", 4.0, (-38, 0, 160), (0.6, 0.95, 1.0))

def create_material_earth(seed):
    mat = bpy.data.materials.new("Mat_Earth")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    nodes, links = nt.nodes, nt.links
    
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    geo = nodes.new("ShaderNodeNewGeometry")
    moss_noise = nodes.new("ShaderNodeTexNoise")   # moss PATCHES (noise, works on flat ground)
    moss_ramp = nodes.new("ShaderNodeValToRGB")
    stone_noise = nodes.new("ShaderNodeTexNoise")
    stone_ramp = nodes.new("ShaderNodeValToRGB")
    mixc = nodes.new("ShaderNodeMixRGB")
    ao_ramp = nodes.new("ShaderNodeValToRGB")
    ao_mix = nodes.new("ShaderNodeMixRGB")
    bump_noise = nodes.new("ShaderNodeTexNoise")
    bump = nodes.new("ShaderNodeBump")

    random.seed(seed)
    moss_noise.inputs["Scale"].default_value = random.uniform(1.4, 2.4)
    stone_noise.inputs["Scale"].default_value = random.uniform(3.0, 5.0)
    bump_noise.inputs["Scale"].default_value = random.uniform(18.0, 30.0)

    # moss appears only where the moss noise is high -> organic green patches on brown soil
    moss_ramp.color_ramp.elements[0].position = 0.50
    moss_ramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
    moss_ramp.color_ramp.elements[1].position = 0.64
    moss_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)

    stone_ramp.color_ramp.elements[0].color = (0.18, 0.12, 0.07, 1.0)   # dark soil
    stone_ramp.color_ramp.elements[1].color = (0.37, 0.28, 0.17, 1.0)   # light dirt

    mixc.blend_type = 'MIX'
    mixc.inputs["Color2"].default_value = (0.14, 0.28, 0.09, 1.0)       # moss green

    ao_ramp.color_ramp.elements[0].position = 0.40
    ao_ramp.color_ramp.elements[0].color = (0.42, 0.42, 0.42, 1.0)
    ao_ramp.color_ramp.elements[1].position = 0.55
    ao_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    ao_mix.blend_type = 'MULTIPLY'
    ao_mix.inputs["Fac"].default_value = 0.7

    bump.inputs["Strength"].default_value = 0.35
    bsdf.inputs["Roughness"].default_value = 0.9

    links.new(moss_noise.outputs["Fac"], moss_ramp.inputs["Fac"])
    links.new(stone_noise.outputs["Fac"], stone_ramp.inputs["Fac"])
    links.new(stone_ramp.outputs["Color"], mixc.inputs["Color1"])
    links.new(moss_ramp.outputs["Color"], mixc.inputs["Fac"])
    links.new(mixc.outputs["Color"], ao_mix.inputs["Color1"])
    links.new(geo.outputs["Pointiness"], ao_ramp.inputs["Fac"])
    links.new(ao_ramp.outputs["Color"], ao_mix.inputs["Color2"])
    links.new(ao_mix.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bump_noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

def create_material_volcanic(seed):
    mat = bpy.data.materials.new("Mat_Volcanic")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    nodes, links = nt.nodes, nt.links
    
    out = nodes.new("ShaderNodeOutputMaterial")
    mix = nodes.new("ShaderNodeMixShader")
    rock = nodes.new("ShaderNodeBsdfPrincipled")
    lava = nodes.new("ShaderNodeEmission")
    vor = nodes.new("ShaderNodeTexVoronoi")
    cr_ramp = nodes.new("ShaderNodeValToRGB")
    bump_noise = nodes.new("ShaderNodeTexNoise")
    bump = nodes.new("ShaderNodeBump")

    random.seed(seed)
    vor.feature = 'DISTANCE_TO_EDGE'
    vor.inputs["Scale"].default_value = random.uniform(1.8, 2.6)
    bump_noise.inputs["Scale"].default_value = random.uniform(12.0, 20.0)

    cr_ramp.color_ramp.elements[0].position = 0.0
    cr_ramp.color_ramp.elements[0].color = (1.0, 1.0, 1.0, 1.0)
    cr_ramp.color_ramp.elements[1].position = 0.028
    cr_ramp.color_ramp.elements[1].color = (0.0, 0.0, 0.0, 1.0)

    rock.inputs["Base Color"].default_value = (0.035, 0.03, 0.028, 1.0)
    rock.inputs["Roughness"].default_value = 0.92
    lava.inputs["Color"].default_value = (1.0, 0.28, 0.03, 1.0)
    lava.inputs["Strength"].default_value = 16.0
    bump.inputs["Strength"].default_value = 0.28

    links.new(vor.outputs["Distance"], cr_ramp.inputs["Fac"])
    links.new(cr_ramp.outputs["Color"], mix.inputs["Fac"])
    links.new(rock.outputs["BSDF"], mix.inputs[1])
    links.new(lava.outputs["Emission"], mix.inputs[2])
    links.new(bump_noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], rock.inputs["Normal"])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])

def create_material_spaceship(seed):
    mat = bpy.data.materials.new("Mat_Spaceship")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    nodes, links = nt.nodes, nt.links
    
    out = nodes.new("ShaderNodeOutputMaterial")
    mix = nodes.new("ShaderNodeMixShader")
    panel = nodes.new("ShaderNodeBsdfPrincipled")
    seam = nodes.new("ShaderNodeEmission")
    vor = nodes.new("ShaderNodeTexVoronoi")
    ramp = nodes.new("ShaderNodeValToRGB")

    random.seed(seed)
    vor.feature = 'DISTANCE_TO_EDGE'
    vor.inputs["Scale"].default_value = random.uniform(3.5, 5.5)

    panel.inputs["Base Color"].default_value = (0.78, 0.81, 0.85, 1.0)
    panel.inputs["Roughness"].default_value = 0.25
    panel.inputs["Metallic"].default_value = 0.7
    seam.inputs["Color"].default_value = (0.1, 0.85, 1.0, 1.0)
    seam.inputs["Strength"].default_value = 8.0

    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (1.0, 1.0, 1.0, 1.0)
    ramp.color_ramp.elements[1].position = 0.025
    ramp.color_ramp.elements[1].color = (0.0, 0.0, 0.0, 1.0)

    links.new(vor.outputs["Distance"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    links.new(panel.outputs["BSDF"], mix.inputs[1])
    links.new(seam.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])

def create_material_tech(seed):
    mat = bpy.data.materials.new("Mat_Tech")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    nodes, links = nt.nodes, nt.links
    
    out = nodes.new("ShaderNodeOutputMaterial")
    mix = nodes.new("ShaderNodeMixShader")
    metal = nodes.new("ShaderNodeBsdfPrincipled")
    trim = nodes.new("ShaderNodeEmission")
    vor = nodes.new("ShaderNodeTexVoronoi")
    ramp = nodes.new("ShaderNodeValToRGB")

    random.seed(seed)
    vor.feature = 'DISTANCE_TO_EDGE'
    vor.inputs["Scale"].default_value = random.uniform(3.0, 4.5)

    metal.inputs["Base Color"].default_value = (0.03, 0.045, 0.13, 1.0)
    metal.inputs["Roughness"].default_value = 0.4
    metal.inputs["Metallic"].default_value = 0.8
    trim.inputs["Color"].default_value = (1.0, 0.42, 0.05, 1.0)
    trim.inputs["Strength"].default_value = 7.0

    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (1.0, 1.0, 1.0, 1.0)
    ramp.color_ramp.elements[1].position = 0.03
    ramp.color_ramp.elements[1].color = (0.0, 0.0, 0.0, 1.0)

    links.new(vor.outputs["Distance"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    links.new(metal.outputs["BSDF"], mix.inputs[1])
    links.new(trim.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])

# ====================================================================
# GROUND PLANE SETUP & CAMERA LOGIC
# ====================================================================

PLANE_SIZE = 24.0

def setup_camera_topdown(sc):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = 'ORTHO'
    # Fill the frame edge-to-edge
    cam_data.ortho_scale = PLANE_SIZE
    cam = bpy.data.objects.new("Cam", cam_data)
    sc.collection.objects.link(cam)
    # Top-down orientation (-Z points down)
    cam.location = (0, 0, PLANE_SIZE * 2.0)
    cam.rotation_euler = (0, 0, 0)
    sc.camera = cam
    return cam

def build_ground_plane(seed):
    random.seed(seed)
    
    # Base flat 24x24 plane
    bpy.ops.mesh.primitive_plane_add(size=PLANE_SIZE, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = "GroundPlane"
    
    # Heavy subdivision
    mod_sub = obj.modifiers.new("Subdivision", type='SUBSURF')
    mod_sub.subdivision_type = 'SIMPLE'
    mod_sub.levels = 7
    mod_sub.render_levels = 7
    
    # Displacement texture for gentle relief
    tex = bpy.data.textures.new("GroundTex", type='CLOUDS')
    tex.noise_scale = 1.5
    
    mod_disp = obj.modifiers.new("Displace", type='DISPLACE')
    mod_disp.texture = tex
    # GENTLE strength: ~0.35
    mod_disp.strength = 0.35
    mod_disp.mid_level = 0.5
    
    # Apply modifiers headlessly to lock geometry for displacement normals
    bpy.ops.object.modifier_apply(modifier="Subdivision")
    bpy.ops.object.modifier_apply(modifier="Displace")
    
    # Shade smooth so gentle rolling terrain renders nicely
    bpy.ops.object.shade_smooth()
    
    return obj

def apply_biome_material(biome, obj, seed):
    if biome == "earth":
        create_material_earth(seed)
        obj.data.materials.append(bpy.data.materials["Mat_Earth"])
    elif biome == "volcanic":
        create_material_volcanic(seed)
        obj.data.materials.append(bpy.data.materials["Mat_Volcanic"])
    elif biome == "spaceship":
        create_material_spaceship(seed)
        obj.data.materials.append(bpy.data.materials["Mat_Spaceship"])
    elif biome == "tech":
        create_material_tech(seed)
        obj.data.materials.append(bpy.data.materials["Mat_Tech"])
    else:
        raise ValueError(f"Unknown biome: {biome}")

def main():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]

    if len(argv) < 2:
        print("Usage: gen_ground.py <biome> <out.png> [--res 1792] [--seed 1] [--samples 26]")
        sys.exit(1)
        
    biome = argv[0].lower()
    out_png = os.path.abspath(argv[1])

    res = 1792
    seed = 1
    samples = 26
    
    i = 2
    while i < len(argv):
        if argv[i] == "--res":
            res = int(argv[i+1]); i += 2
        elif argv[i] == "--seed":
            seed = int(argv[i+1]); i += 2
        elif argv[i] == "--samples":
            samples = int(argv[i+1]); i += 2
        else:
            i += 1
            
    sc = clear_scene()
    setup_render_settings(sc, res, samples)
    setup_world_and_lights(sc)
    
    cam = setup_camera_topdown(sc)
    
    plane = build_ground_plane(seed)
    apply_biome_material(biome, plane, seed)
    
    sc.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    
    print(f"BAKED {out_png}")

if __name__ == "__main__":
    main()
