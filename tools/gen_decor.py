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

# --- GEOMETRY ---

def make_rock(size, seed):
    random.seed(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=size)
    obj = bpy.context.active_object
    
    tex = bpy.data.textures.new(f"rk_{random.randint(0,9999)}", type='VORONOI')
    tex.noise_scale = random.uniform(0.5, 0.9)
    
    d = obj.modifiers.new("disp", 'DISPLACE')
    d.texture = tex
    d.strength = size * random.uniform(0.35, 0.55)
    d.mid_level = 0.0
    
    dec = obj.modifiers.new("dec", 'DECIMATE')
    dec.decimate_type = 'DISSOLVE'
    dec.angle_limit = math.radians(random.uniform(12, 22))
    
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="disp")
    bpy.ops.object.modifier_apply(modifier="dec")
    bpy.ops.object.shade_flat()
    
    obj.scale = (random.uniform(0.7, 1.3), random.uniform(0.7, 1.3), random.uniform(0.7, 1.3))
    obj.rotation_euler = (random.uniform(0, 3.14), random.uniform(0, 3.14), random.uniform(0, 3.14))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj

def make_crystal(h, r):
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=r, radius2=r*0.12, depth=h)
    obj = bpy.context.active_object
    bpy.ops.object.shade_flat()
    return obj

def make_cube_part(name, size, location, rotation, bevel_width=0.04):
    bpy.ops.mesh.primitive_cube_add(size=size, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    
    m = obj.modifiers.new("Bevel", type='BEVEL')
    m.width = bevel_width
    m.segments = 2
    
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_flat()
    return obj

def make_cylinder_part(name, radius, depth, location, rotation, bevel_width=0.04, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    
    m = obj.modifiers.new("Bevel", type='BEVEL')
    m.width = bevel_width
    m.segments = 2
    
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_flat()
    return obj

# --- MATERIALS ---

def create_material_rock(seed):
    mat = bpy.data.materials.new("Mat_Rock")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    nodes, links = nt.nodes, nt.links
    
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    geo = nodes.new("ShaderNodeNewGeometry")
    ao_ramp = nodes.new("ShaderNodeValToRGB")
    ao_mix = nodes.new("ShaderNodeMixRGB")
    bump_noise = nodes.new("ShaderNodeTexNoise")
    bump = nodes.new("ShaderNodeBump")

    random.seed(seed)
    bump_noise.inputs["Scale"].default_value = random.uniform(14.0, 22.0)

    bsdf.inputs["Base Color"].default_value = (0.42, 0.42, 0.46, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9

    ao_ramp.color_ramp.elements[0].position = 0.42
    ao_ramp.color_ramp.elements[0].color = (0.25, 0.25, 0.28, 1.0)
    ao_ramp.color_ramp.elements[1].position = 0.55
    ao_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    
    ao_mix.blend_type = 'MULTIPLY'
    ao_mix.inputs["Fac"].default_value = 0.9

    bump.inputs["Strength"].default_value = 0.3

    links.new(geo.outputs["Pointiness"], ao_ramp.inputs["Fac"])
    links.new(ao_ramp.outputs["Color"], ao_mix.inputs["Color2"])
    c = nodes.new("ShaderNodeRGB")
    c.outputs["Color"].default_value = (0.42, 0.42, 0.46, 1.0)
    links.new(c.outputs["Color"], ao_mix.inputs["Color1"])
    
    links.new(ao_mix.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bump_noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

def create_material_crystal(color=(0.1, 0.8, 1.0)):
    mat = bpy.data.materials.new("Mat_Crystal")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    nodes, links = nt.nodes, nt.links
    
    out = nodes.new("ShaderNodeOutputMaterial")
    mix = nodes.new("ShaderNodeMixShader")
    glass = nodes.new("ShaderNodeBsdfPrincipled")
    emit = nodes.new("ShaderNodeEmission")
    fres = nodes.new("ShaderNodeLayerWeight")

    glass.inputs["Transmission Weight"].default_value = 0.6
    glass.inputs["Roughness"].default_value = 0.05
    glass.inputs["Base Color"].default_value = (color[0]*0.5, color[1]*0.5, color[2]*0.5, 1.0)
    
    emit.inputs["Color"].default_value = (*color, 1.0)
    emit.inputs["Strength"].default_value = 4.0
    
    fres.inputs["Blend"].default_value = 0.2

    links.new(fres.outputs["Facing"], mix.inputs["Fac"])
    links.new(glass.outputs["BSDF"], mix.inputs[1])
    links.new(emit.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])

def create_material_metal(seed):
    mat = bpy.data.materials.new("Mat_Metal")
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
    vor.inputs["Scale"].default_value = random.uniform(1.0, 1.8)   # few large panels, not a dense net

    panel.inputs["Base Color"].default_value = (0.09, 0.10, 0.13, 1.0)
    panel.inputs["Roughness"].default_value = 0.4
    panel.inputs["Metallic"].default_value = 0.8
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

def create_material_plant(seed):
    mat = bpy.data.materials.new("Mat_Plant")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    nodes, links = nt.nodes, nt.links
    
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    moss_ramp = nodes.new("ShaderNodeValToRGB")
    mixc = nodes.new("ShaderNodeMixRGB")

    random.seed(seed)
    moss_ramp.color_ramp.elements[0].position = 0.4
    moss_ramp.color_ramp.elements[1].position = 0.6

    mixc.inputs["Color1"].default_value = (0.12, 0.08, 0.05, 1.0) # dry bark
    mixc.inputs["Color2"].default_value = (0.15, 0.35, 0.1, 1.0)  # moss / leaves
    bsdf.inputs["Roughness"].default_value = 0.95

    links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    links.new(sep.outputs["Z"], moss_ramp.inputs["Fac"])
    links.new(moss_ramp.outputs["Color"], mixc.inputs["Fac"])
    links.new(mixc.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

def create_material_mesa(seed):
    mat = bpy.data.materials.new("Mat_Mesa")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    nodes, links = nt.nodes, nt.links
    
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    top_ramp = nodes.new("ShaderNodeValToRGB")
    mixc = nodes.new("ShaderNodeMixRGB")
    ao_ramp = nodes.new("ShaderNodeValToRGB")
    ao_mix = nodes.new("ShaderNodeMixRGB")
    bump_noise = nodes.new("ShaderNodeTexNoise")
    bump = nodes.new("ShaderNodeBump")

    random.seed(seed)
    bump_noise.inputs["Scale"].default_value = random.uniform(12.0, 18.0)

    top_ramp.color_ramp.elements[0].position = 0.6
    top_ramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
    top_ramp.color_ramp.elements[1].position = 0.85
    top_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)

    mixc.inputs["Color1"].default_value = (0.42, 0.42, 0.46, 1.0) # grey rock
    mixc.inputs["Color2"].default_value = (0.2, 0.35, 0.1, 1.0)   # moss top

    ao_ramp.color_ramp.elements[0].position = 0.42
    ao_ramp.color_ramp.elements[0].color = (0.3, 0.3, 0.33, 1.0)
    ao_ramp.color_ramp.elements[1].position = 0.55
    ao_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    
    ao_mix.blend_type = 'MULTIPLY'
    ao_mix.inputs["Fac"].default_value = 0.9
    bump.inputs["Strength"].default_value = 0.25

    links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    links.new(sep.outputs["Z"], top_ramp.inputs["Fac"])
    links.new(top_ramp.outputs["Color"], mixc.inputs["Fac"])
    links.new(mixc.outputs["Color"], ao_mix.inputs["Color1"])
    links.new(geo.outputs["Pointiness"], ao_ramp.inputs["Fac"])
    links.new(ao_ramp.outputs["Color"], ao_mix.inputs["Color2"])
    links.new(ao_mix.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bump_noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

# --- BUILDERS ---

def build_boulder(seed):
    random.seed(seed)
    obj = make_rock(1.2, seed)
    create_material_rock(seed)
    obj.data.materials.append(bpy.data.materials["Mat_Rock"])
    return [obj]

def build_rock_cluster(seed):
    random.seed(seed)
    parts = []
    for i in range(random.randint(4, 6)):
        r = random.uniform(0.5, 1.0)
        rock = make_rock(r, seed + i)
        rock.location = (random.uniform(-1.0, 1.0), random.uniform(-1.0, 1.0), random.uniform(0.1, 0.5))
        parts.append(rock)
    create_material_rock(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Rock"])
    return parts

def build_crystal(seed):
    random.seed(seed)
    parts = []
    for i in range(random.randint(3, 5)):
        h = random.uniform(1.2, 2.0)
        r = random.uniform(0.2, 0.35)
        c = make_crystal(h, r)
        c.location = (random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), 0)
        c.rotation_euler = (random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), random.uniform(0, 3.14))
        parts.append(c)
    create_material_crystal(color=(0.1, 0.8, 1.0))
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Crystal"])
    return parts

def build_crystal_cluster(seed):
    random.seed(seed)
    parts = []
    for i in range(random.randint(7, 10)):
        h = random.uniform(1.5, 3.5)
        r = random.uniform(0.2, 0.45)
        c = make_crystal(h, r)
        c.location = (random.uniform(-0.8, 0.8), random.uniform(-0.8, 0.8), 0)
        c.rotation_euler = (random.uniform(-0.35, 0.35), random.uniform(-0.35, 0.35), random.uniform(0, 3.14))
        parts.append(c)
    create_material_crystal(color=(0.7, 0.2, 1.0))
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Crystal"])
    return parts

def build_pillar(seed):
    random.seed(seed)
    parts = []
    p1 = make_cylinder_part("pillar_base", 0.6, 2.0, (0, 0, 1.0), (0, 0, 0))
    p2 = make_cylinder_part("pillar_top", 0.7, 0.4, (0, 0, 2.2), (0, 0, 0))
    p3 = make_cylinder_part("pillar_break", 0.65, 0.6, (0, 0, 1.8), (random.uniform(-0.1, 0.1), random.uniform(-0.1, 0.1), 0))
    parts.extend([p1, p2, p3])
    
    for i in range(3):
        r = random.uniform(0.3, 0.5)
        rock = make_rock(r, seed + i)
        rock.location = (random.uniform(-1.0, 1.0), random.uniform(-1.0, 1.0), random.uniform(0, 0.2))
        parts.append(rock)
        
    create_material_rock(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Rock"])
    return parts

def build_container(seed):
    random.seed(seed)
    parts = []
    # main body
    p1 = make_cube_part("container_base", 2.0, (0, 0, 1.0), (0, 0, random.uniform(-0.1, 0.1)))
    p1.scale = (1.2, 0.8, 0.8)
    bpy.ops.object.transform_apply(scale=True)
    parts.append(p1)
    
    # panel details
    for i in range(4):
        x = 1.1 if i % 2 == 0 else -1.1
        y = (0.45 if i < 2 else -0.45)
        p = make_cube_part(f"panel_{i}", 0.8, (x, y, 1.0), (0, 0, 0), bevel_width=0.02)
        p.scale = (0.02, 0.4, 0.5)
        bpy.ops.object.transform_apply(scale=True)
        parts.append(p)
        
    create_material_metal(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Metal"])
    return parts

def build_pylon(seed):
    random.seed(seed)
    parts = []
    z = 0.0
    for i in range(random.randint(3, 4)):
        s = 1.5 - i * 0.3
        p = make_cube_part(f"pylon_{i}", s, (0, 0, z + s/2), (0, 0, random.uniform(-0.1, 0.1)))
        p.scale = (1.0, 1.0, 0.3)
        bpy.ops.object.transform_apply(scale=True)
        parts.append(p)
        z += s * 0.3 + 0.1
        
    mast = make_cylinder_part("mast", 0.05, 1.5, (0, 0, z + 0.75), (0, 0, 0), bevel_width=0.01, verts=6)
    parts.append(mast)
    
    create_material_metal(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Metal"])
    return parts

def build_bush(seed):
    random.seed(seed)
    parts = []
    for i in range(random.randint(4, 7)):
        h = random.uniform(0.8, 1.5)
        r = random.uniform(0.4, 0.7)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r, radius2=r*0.1, depth=h)
        c = bpy.context.active_object
        c.location = (random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), h/2)
        c.rotation_euler = (random.uniform(-0.2, 0.2), random.uniform(-0.2, 0.2), random.uniform(0, 3.14))
        bpy.ops.object.shade_flat()
        parts.append(c)
        
    create_material_plant(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Plant"])
    return parts

def build_deadtree(seed):
    random.seed(seed)
    parts = []
    # trunk
    trunk = make_cylinder_part("trunk", 0.15, 2.5, (0, 0, 1.25), (0, 0, 0), bevel_width=0.02, verts=8)
    parts.append(trunk)
    
    # branches
    for i in range(random.randint(3, 5)):
        h = random.uniform(1.0, 2.0)
        r = random.uniform(0.04, 0.08)
        branch = make_cylinder_part(f"branch_{i}", r, h, (0, 0, 0), (0, 0, 0), bevel_width=0.01, verts=6)
        branch.location = (0, 0, 1.8 + random.uniform(-0.4, 0.4))
        branch.rotation_euler = (random.uniform(0.5, 1.2), random.uniform(0.5, 1.2), random.uniform(0, 3.14))
        parts.append(branch)

    # bare BROWN dead wood (not the green plant material)
    wood = bpy.data.materials.new("Mat_Wood")
    wood.use_nodes = True
    wb = wood.node_tree.nodes.get("Principled BSDF")
    wb.inputs["Base Color"].default_value = (0.19, 0.13, 0.08, 1.0)
    wb.inputs["Roughness"].default_value = 0.92
    for p in parts:
        p.data.materials.append(wood)
    return parts

def build_debris(seed):
    random.seed(seed)
    parts = []
    for i in range(random.randint(4, 7)):
        size = random.uniform(0.2, 0.5)
        p = make_cube_part(f"debris_{i}", size, (0,0,0), (0,0,0), bevel_width=0.015)
        p.location = (random.uniform(-0.6, 0.6), random.uniform(-0.6, 0.6), random.uniform(0.1, 0.3))
        p.rotation_euler = (random.uniform(0, 3.14), random.uniform(0, 3.14), random.uniform(0, 3.14))
        parts.append(p)
        
    create_material_metal(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Metal"])
    return parts

def build_mesa(seed):
    random.seed(seed)
    parts = []
    # wide flat base rock
    base = make_rock(2.5, seed)
    base.scale = (1.4, 1.4, 0.6)
    bpy.ops.object.transform_apply(scale=True)
    parts.append(base)
    
    for i in range(random.randint(4, 6)):
        r = random.uniform(0.8, 1.2)
        rock = make_rock(r, seed + i)
        rock.location = (random.uniform(-1.5, 1.5), random.uniform(-1.5, 1.5), random.uniform(0.2, 0.6))
        parts.append(rock)
        
    create_material_mesa(seed)
    for p in parts:
        p.data.materials.append(bpy.data.materials["Mat_Mesa"])
    return parts

# --- HELPERS & RENDER ---

def normalize_z(parts):
    min_z = 10000
    for p in parts:
        for v in p.data.vertices:
            wv = p.matrix_world @ v.co
            if wv.z < min_z:
                min_z = wv.z
    if min_z != 10000:
        for p in parts:
            p.location.z -= min_z

def update_camera_fit(cam, sc, el):
    deps = bpy.context.evaluated_depsgraph_get()
    mesh_obs = [o for o in sc.objects if o.type == 'MESH']
    if not mesh_obs:
        return 0
        
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
        print("Usage: gen_decor.py <name> <out.png> [--res 384] [--seed 1] [--el 30] [--samples 40]")
        sys.exit(1)
        
    name = argv[0].lower()
    out_png = os.path.abspath(argv[1])   # Blender needs an absolute render path

    res = 384
    seed = 1
    el = 30
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
    
    builders = {
        "boulder": build_boulder,
        "rock_cluster": build_rock_cluster,
        "crystal": build_crystal,
        "crystal_cluster": build_crystal_cluster,
        "pillar": build_pillar,
        "container": build_container,
        "pylon": build_pylon,
        "bush": build_bush,
        "deadtree": build_deadtree,
        "debris": build_debris,
        "mesa": build_mesa,
    }
    
    if name not in builders:
        print(f"Unknown item: {name}")
        sys.exit(1)
        
    parts = builders[name](seed)
    normalize_z(parts)
    
    size = update_camera_fit(cam, sc, el)
    
    sc.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    
    print(f"BAKED {out_png} size={size:.4f}")

if __name__ == "__main__":
    main()
