#!/usr/bin/env python3
import bpy
import sys
import os
import math
import random
import mathutils

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    return sc

def setup_render_settings(sc, res, samples):
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"

def setup_world_and_lights(sc):
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.08, 0.09, 0.13, 1.0)
    bg.inputs["Strength"].default_value = 0.4

    def sun(name, e, rot, col):
        d = bpy.data.lights.new(name, type="SUN")
        d.energy = e
        d.color = col
        d.angle = math.radians(5)
        o = bpy.data.objects.new(name, d)
        sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)

    sun("key", 4.0, (52, 8, -34), (1.0, 0.96, 0.9))
    sun("fill", 1.4, (66, -6, 46), (0.75, 0.85, 1.0))
    sun("rim", 4.0, (-38, 0, 160), (0.6, 0.95, 1.0))

def setup_camera(sc):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = 'ORTHO'
    cam = bpy.data.objects.new("Cam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam

def create_rock(name, base_radius, location, scale, rotation, tex_type='VORONOI', noise_scale=1.0, strength_mult=0.35):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=base_radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    
    obj.scale = scale
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    for poly in obj.data.polygons:
        poly.use_smooth = False

    tex = bpy.data.textures.new(f"Tex_{name}", type=tex_type)
    if hasattr(tex, 'noise_scale'):
        tex.noise_scale = noise_scale
    elif hasattr(tex, 'noise_basis'):
        tex.noise_basis = 'VORONOI_F2'
        
    mod = obj.modifiers.new("Displace", type='DISPLACE')
    mod.texture = tex
    mod.strength = base_radius * strength_mult
    mod.mid_level = 0.5
    
    return obj

def create_cube_part(name, size, location, rotation):
    bpy.ops.mesh.primitive_cube_add(size=size, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    
    m = obj.modifiers.new("Bevel", type='BEVEL')
    m.width = 0.05
    m.segments = 3
    return obj

def create_material_earth(seed):
    mat = bpy.data.materials.new("Mat_Earth")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    nodes, links = nt.nodes, nt.links
    
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    moss_ramp = nodes.new("ShaderNodeValToRGB")   # up-facing -> moss mask
    stone_noise = nodes.new("ShaderNodeTexNoise")
    stone_ramp = nodes.new("ShaderNodeValToRGB")  # brown stone variation
    mixc = nodes.new("ShaderNodeMixRGB")          # stone <-> moss
    ao_ramp = nodes.new("ShaderNodeValToRGB")     # crevice AO
    ao_mix = nodes.new("ShaderNodeMixRGB")
    bump_noise = nodes.new("ShaderNodeTexNoise")
    bump = nodes.new("ShaderNodeBump")

    random.seed(seed)
    stone_noise.inputs["Scale"].default_value = random.uniform(2.5, 4.5)
    bump_noise.inputs["Scale"].default_value = random.uniform(14.0, 22.0)

    # moss only on upward-facing surfaces (world normal Z)
    moss_ramp.color_ramp.elements[0].position = 0.38
    moss_ramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
    moss_ramp.color_ramp.elements[1].position = 0.74
    moss_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)

    stone_ramp.color_ramp.elements[0].color = (0.20, 0.14, 0.09, 1.0)  # dark brown stone
    stone_ramp.color_ramp.elements[1].color = (0.34, 0.26, 0.17, 1.0)  # light brown stone

    mixc.blend_type = 'MIX'
    mixc.inputs["Color2"].default_value = (0.13, 0.30, 0.08, 1.0)       # moss green

    ao_ramp.color_ramp.elements[0].position = 0.42
    ao_ramp.color_ramp.elements[0].color = (0.32, 0.32, 0.32, 1.0)      # crevice darken
    ao_ramp.color_ramp.elements[1].position = 0.55
    ao_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    ao_mix.blend_type = 'MULTIPLY'
    ao_mix.inputs["Fac"].default_value = 0.85

    bump.inputs["Strength"].default_value = 0.22
    bsdf.inputs["Roughness"].default_value = 0.88

    links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    links.new(sep.outputs["Z"], moss_ramp.inputs["Fac"])
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
    vor = nodes.new("ShaderNodeTexVoronoi")       # sparse crack network
    cr_ramp = nodes.new("ShaderNodeValToRGB")
    bump_noise = nodes.new("ShaderNodeTexNoise")
    bump = nodes.new("ShaderNodeBump")

    random.seed(seed)
    # Voronoi "distance to edge" ~0 on cell borders -> thin sparse glowing lava veins
    vor.feature = 'DISTANCE_TO_EDGE'
    vor.inputs["Scale"].default_value = random.uniform(1.8, 2.6)
    bump_noise.inputs["Scale"].default_value = random.uniform(12.0, 20.0)

    cr_ramp.color_ramp.elements[0].position = 0.0
    cr_ramp.color_ramp.elements[0].color = (1.0, 1.0, 1.0, 1.0)   # ON the crack -> lava
    cr_ramp.color_ramp.elements[1].position = 0.028                # thin crack
    cr_ramp.color_ramp.elements[1].color = (0.0, 0.0, 0.0, 1.0)   # rock

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
    vor = nodes.new("ShaderNodeTexVoronoi")     # panel seam lines
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
    ramp.color_ramp.elements[0].color = (1.0, 1.0, 1.0, 1.0)   # seam glow
    ramp.color_ramp.elements[1].position = 0.025
    ramp.color_ramp.elements[1].color = (0.0, 0.0, 0.0, 1.0)   # panel

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
    vor = nodes.new("ShaderNodeTexVoronoi")     # glowing trim lines
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
    ramp.color_ramp.elements[0].color = (1.0, 1.0, 1.0, 1.0)   # trim glow
    ramp.color_ramp.elements[1].position = 0.03
    ramp.color_ramp.elements[1].color = (0.0, 0.0, 0.0, 1.0)   # metal

    links.new(vor.outputs["Distance"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    links.new(metal.outputs["BSDF"], mix.inputs[1])
    links.new(trim.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])

def build_earth(seed):
    random.seed(seed)
    parts = []
    # Wide flat base rock
    parts.append(create_rock("Earth_Base", 1.5, (0, 0, 0), (1.4, 1.4, 0.6), (0, 0, 0), tex_type='DISTORTED_NOISE', noise_scale=0.8, strength_mult=0.15))
    # Surrounding rocks
    for i in range(random.randint(4, 6)):
        r = random.uniform(0.5, 0.9)
        x = (random.random() - 0.5) * 2.0
        y = (random.random() - 0.5) * 2.0
        z = random.uniform(0.2, 0.8)
        s = (random.uniform(0.6, 1.2), random.uniform(0.6, 1.2), random.uniform(0.5, 0.9))
        rot = (random.uniform(0, 3.14), random.uniform(0, 3.14), random.uniform(0, 3.14))
        parts.append(create_rock(f"Earth_Rock_{i}", r, (x, y, z), s, rot, tex_type='VORONOI', noise_scale=1.0, strength_mult=0.4))
    
    create_material_earth(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Earth"])
    return parts

def build_volcanic(seed):
    random.seed(seed)
    parts = []
    num_rocks = random.randint(5, 7)
    for i in range(num_rocks):
        r = random.uniform(0.7, 1.1)
        x = (random.random() - 0.5) * 1.5
        y = (random.random() - 0.5) * 1.5
        z = random.uniform(0.2, 0.9)
        s = (random.uniform(0.6, 1.0), random.uniform(0.6, 1.0), random.uniform(1.0, 1.4)) # taller jagged spikes
        rot = (random.uniform(0, 3.14), random.uniform(0, 3.14), random.uniform(0, 3.14))
        parts.append(create_rock(f"Volc_Rock_{i}", r, (x, y, z), s, rot, tex_type='VORONOI', noise_scale=1.2, strength_mult=0.5))
        
    create_material_volcanic(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Volcanic"])
    return parts

def build_spaceship(seed):
    random.seed(seed)
    parts = []
    num_panels = random.randint(3, 5)
    for i in range(num_panels):
        size = random.uniform(1.5, 2.5) - i*0.25
        x = (random.random() - 0.5) * 0.5
        y = (random.random() - 0.5) * 0.5
        z = i * random.uniform(0.3, 0.5)
        rot = (0, 0, random.uniform(-0.2, 0.2))
        parts.append(create_cube_part(f"ShipPart_{i}", size, (x, y, z), rot))
        
    create_material_spaceship(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Spaceship"])
    return parts

def build_tech(seed):
    random.seed(seed)
    parts = []
    num_panels = random.randint(3, 5)
    for i in range(num_panels):
        size = random.uniform(1.2, 2.0) - i*0.2
        x = (random.random() - 0.5) * 0.6
        y = (random.random() - 0.5) * 0.6
        z = i * random.uniform(0.4, 0.6)
        rot = (0, 0, random.uniform(-0.15, 0.15))
        parts.append(create_cube_part(f"TechPart_{i}", size, (x, y, z), rot))
        
    create_material_tech(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Tech"])
    return parts

def update_camera_fit(cam, sc, el):
    deps = bpy.context.evaluated_depsgraph_get()
    mesh_obs = [o for o in sc.objects if o.type == 'MESH']
    if not mesh_obs:
        return
        
    min_co = mathutils.Vector(( 10000,  10000,  10000))
    max_co = mathutils.Vector((-10000, -10000, -10000))
    for o in mesh_obs:
        eo = o.evaluated_get(deps)
        for v in eo.data.vertices:
            wv = eo.matrix_world @ v.co
            if wv.x < min_co.x: min_co.x = wv.x
            if wv.y < min_co.y: min_co.y = wv.y
            if wv.z < min_co.z: min_co.z = wv.z
            if wv.x > max_co.x: max_co.x = wv.x
            if wv.y > max_co.y: max_co.y = wv.y
            if wv.z > max_co.z: max_co.z = wv.z
            
    center = (min_co + max_co) / 2.0
    size = max(max_co.x - min_co.x, max_co.y - min_co.y, max_co.z - min_co.z)
    
    az = 0.0
    el_r = math.radians(el)
    dist = size * 4.0
    cx = center.x - math.sin(az) * math.cos(el_r) * dist
    cy = center.y - math.cos(az) * math.cos(el_r) * dist
    cz = center.z + math.sin(el_r) * dist
    cam.location = (cx, cy, cz)
    cam.data.ortho_scale = size * 1.2
    
    look = center - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    return size

def main():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]

    if len(argv) < 2:
        print("Usage: gen_landscape.py <biome> <out.png> [--res 384] [--seed 1] [--el 34] [--samples 40]")
        sys.exit(1)
        
    biome = argv[0].lower()
    out_png = os.path.abspath(argv[1])   # Blender needs an absolute render path

    res = 384
    seed = 1
    el = 34
    samples = 40
    
    i = 2
    while i < len(argv):
        if argv[i] == "--res":
            res = int(argv[i+1]); i += 2
        elif argv[i] == "--seed":
            seed = int(argv[i+1]); i += 2
        elif argv[i] == "--el":
            el = float(argv[i+1]); i += 2
        elif argv[i] == "--samples":
            samples = int(argv[i+1]); i += 2
        else:
            i += 1
            
    sc = clear_scene()
    setup_render_settings(sc, res, samples)
    setup_world_and_lights(sc)
    cam = setup_camera(sc)
    
    if biome == "earth":
        build_earth(seed)
    elif biome == "volcanic":
        build_volcanic(seed)
    elif biome == "spaceship":
        build_spaceship(seed)
    elif biome == "tech":
        build_tech(seed)
    else:
        print(f"Unknown biome: {biome}")
        sys.exit(1)
        
    size = update_camera_fit(cam, sc, el)
    
    sc.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    
    print(f"BAKED {out_png} size={size:.4f}")

if __name__ == "__main__":
    main()
