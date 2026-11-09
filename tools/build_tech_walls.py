import bpy
import math
import os
import time

BASE_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\decor\tech_maze"
TEX_DIR = os.path.join(BASE_DIR, "textures")
OUT_DIR = BASE_DIR
os.makedirs(OUT_DIR, exist_ok=True)

TEX_BASE = os.path.join(TEX_DIR, "tex_wall_base.png")
TEX_HAZARD = os.path.join(TEX_DIR, "tex_wall_hazard.png")
TEX_TERMINAL = os.path.join(TEX_DIR, "tex_wall_terminal.png")

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
    fill.data.energy = 2.8
    fill.data.color = (0.7, 0.85, 1.0)

    # 3. Top rim light
    bpy.ops.object.light_add(type='POINT', location=(0, 2, 6))
    rim = bpy.context.active_object
    rim.data.energy = 120.0
    rim.data.color = (0.8, 0.95, 1.0)

def setup_camera_trackto(target_z, ortho_scale, cam_loc=(0, -7.0, 6.0)):
    scene = bpy.context.scene
    # Empty target
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

def create_pbr_material(name, tex_path, metallic=0.85, roughness=0.35, scale=(0.5, 0.5, 0.5)):
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
    tex_node.projection_blend = 0.15
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

def add_bevel(obj, width=0.05, segments=2):
    bev = obj.modifiers.new(name="B", type='BEVEL')
    bev.width = width
    bev.segments = segments
    return bev

# ----------------- BUILDERS -----------------

def build_horizontal_wall(kind="base"):
    length = 4.0
    depth = 0.95
    height = 1.35
    z_base = height / 2.0

    # 1. Main wall
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, z_base))
    main_wall = bpy.context.active_object
    main_wall.scale = (length, depth, height)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(main_wall, width=0.05)

    # 2. Top roof cap
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, height + 0.08))
    top_cap = bpy.context.active_object
    top_cap.scale = (length, depth + 0.14, 0.18)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(top_cap, width=0.03)

    # 3. Base trim
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -depth * 0.45, 0.12))
    base_trim = bpy.context.active_object
    base_trim.scale = (length, 0.22, 0.24)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(base_trim, width=0.02)

    mat_base = create_pbr_material("MatBase", TEX_BASE, metallic=0.88, roughness=0.30)
    mat_haz = create_pbr_material("MatHazard", TEX_HAZARD, metallic=0.84, roughness=0.35)
    mat_term = create_pbr_material("MatTerm", TEX_TERMINAL, metallic=0.85, roughness=0.32)

    if kind == "base":
        main_wall.data.materials.append(mat_base)
        top_cap.data.materials.append(mat_base)
        base_trim.data.materials.append(mat_base)
        # Vertical support rib pillars every 1.3 units
        for x in [-1.3, 0.0, 1.3]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, -depth * 0.5 - 0.04, z_base))
            rib = bpy.context.active_object
            rib.scale = (0.28, 0.12, height)
            bpy.ops.object.transform_apply(scale=True)
            add_bevel(rib, width=0.03)
            rib.data.materials.append(mat_base)

    elif kind == "hazard":
        main_wall.data.materials.append(mat_haz)
        top_cap.data.materials.append(mat_base)
        base_trim.data.materials.append(mat_haz)
        # Struts
        for x in [-1.4, 1.4]:
            bpy.ops.mesh.primitive_cylinder_add(radius=0.10, depth=height * 1.05, location=(x, -depth * 0.52, z_base))
            strut = bpy.context.active_object
            add_bevel(strut, width=0.02)
            strut.data.materials.append(mat_base)
        # Amber beacon
        bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.22, location=(0, 0, height + 0.24))
        beacon = bpy.context.active_object
        mat_amber = create_neon_material("MatAmber", color=(1.0, 0.55, 0.0), strength=5.0)
        beacon.data.materials.append(mat_amber)

    elif kind == "conduit":
        main_wall.data.materials.append(mat_base)
        top_cap.data.materials.append(mat_base)
        base_trim.data.materials.append(mat_base)
        # Glowing cyan plasma conduit
        bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=length * 0.96, location=(0, -depth * 0.52, z_base + 0.15))
        p1 = bpy.context.active_object
        p1.rotation_euler = (0, math.radians(90), 0)
        p1.data.materials.append(create_neon_material("MatCyanP", color=(0.0, 0.95, 1.0), strength=5.5))
        # Orange conduit below
        bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=length * 0.94, location=(0, -depth * 0.52, z_base - 0.25))
        p2 = bpy.context.active_object
        p2.rotation_euler = (0, math.radians(90), 0)
        p2.data.materials.append(create_neon_material("MatOrangeP", color=(1.0, 0.45, 0.0), strength=4.5))

    elif kind == "terminal":
        main_wall.data.materials.append(mat_base)
        top_cap.data.materials.append(mat_base)
        base_trim.data.materials.append(mat_base)
        # Central console
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -depth * 0.52, z_base))
        con = bpy.context.active_object
        con.scale = (1.4, 0.24, height * 0.8)
        bpy.ops.object.transform_apply(scale=True)
        add_bevel(con, width=0.03)
        con.data.materials.append(mat_term)
        # Screen
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, -depth * 0.52 - 0.13, z_base + 0.15))
        screen = bpy.context.active_object
        screen.rotation_euler = (math.radians(-75), 0, 0)
        screen.scale = (0.75, 0.45, 1.0)
        screen.data.materials.append(create_neon_material("MatScreen", color=(0.0, 0.90, 0.95), strength=4.0))

    return z_base

def build_vertical_wall(kind="base"):
    length = 4.0
    depth = 0.95
    height = 1.35
    z_base = height / 2.0

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, z_base))
    main_wall = bpy.context.active_object
    main_wall.scale = (depth, length, height)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(main_wall, width=0.05)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, height + 0.08))
    top_cap = bpy.context.active_object
    top_cap.scale = (depth + 0.14, length, 0.18)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(top_cap, width=0.03)

    tex_choice = TEX_HAZARD if kind == "hazard" else (TEX_TERMINAL if kind == "conduit" else TEX_BASE)
    mat = create_pbr_material(f"MatV_{kind}", tex_choice, metallic=0.85, roughness=0.32)
    main_wall.data.materials.append(mat)
    top_cap.data.materials.append(mat)

    if kind == "conduit":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=length * 0.94, location=(-depth * 0.52, 0, z_base + 0.1))
        pipe = bpy.context.active_object
        pipe.rotation_euler = (math.radians(90), 0, 0)
        pipe.data.materials.append(create_neon_material("MatVNeon", color=(0.0, 0.95, 1.0), strength=5.0))
    elif kind == "hazard":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.2, location=(0, 0, height + 0.24))
        beacon = bpy.context.active_object
        beacon.data.materials.append(create_neon_material("MatVAmber", color=(1.0, 0.55, 0.0), strength=5.0))

    return z_base

def build_corner(quadrant="tl"):
    thick = 0.95
    arm = 2.2
    height = 1.35
    z_base = height / 2.0

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, z_base))
    corner_hub = bpy.context.active_object
    corner_hub.scale = (thick + 0.25, thick + 0.25, height + 0.12)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(corner_hub, width=0.06)

    dx = -arm/2.0 if "l" in quadrant else arm/2.0
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(dx, 0, z_base))
    arm_x = bpy.context.active_object
    arm_x.scale = (arm, thick, height)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(arm_x, width=0.04)

    dy = arm/2.0 if "t" in quadrant else -arm/2.0
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, dy, z_base))
    arm_y = bpy.context.active_object
    arm_y.scale = (thick, arm, height)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(arm_y, width=0.04)

    mat_base = create_pbr_material("MatCornerBase", TEX_BASE, metallic=0.88, roughness=0.30)
    mat_haz = create_pbr_material("MatCornerHaz", TEX_HAZARD, metallic=0.84, roughness=0.35)
    corner_hub.data.materials.append(mat_haz)
    arm_x.data.materials.append(mat_base)
    arm_y.data.materials.append(mat_base)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.18, location=(0, 0, height + 0.22))
    light = bpy.context.active_object
    light.data.materials.append(create_neon_material("MatCornerLight", color=(0.0, 0.95, 1.0), strength=4.5))

    return z_base

def build_pillar_reactor():
    radius = 1.0
    height = 2.1
    z_base = height / 2.0

    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=height, location=(0, 0, z_base))
    body = bpy.context.active_object
    add_bevel(body, width=0.06)
    body.data.materials.append(create_pbr_material("MatPillarBase", TEX_BASE, metallic=0.90, roughness=0.28))

    mat_core = create_neon_material("MatCoreRing", color=(0.0, 0.88, 1.0), strength=6.0)
    for z in [height * 0.35, height * 0.50, height * 0.65]:
        bpy.ops.mesh.primitive_torus_add(major_radius=radius + 0.05, minor_radius=0.07, location=(0, 0, z))
        ring = bpy.context.active_object
        ring.data.materials.append(mat_core)

    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius * 1.3, depth=0.24, location=(0, 0, 0.12))
    foot = bpy.context.active_object
    foot.data.materials.append(create_pbr_material("MatFootHaz", TEX_HAZARD, metallic=0.82, roughness=0.36))

    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius * 1.15, depth=0.28, location=(0, 0, height + 0.14))
    dome = bpy.context.active_object
    dome.data.materials.append(create_pbr_material("MatDome", TEX_BASE, metallic=0.88, roughness=0.30))

    return z_base

def build_pillar_vent():
    width = 1.6
    height = 1.9
    z_base = height / 2.0

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, z_base))
    col = bpy.context.active_object
    col.scale = (width, width, height)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(col, width=0.08)
    col.data.materials.append(create_pbr_material("MatVentTerm", TEX_TERMINAL, metallic=0.84, roughness=0.35))

    bpy.ops.mesh.primitive_cylinder_add(radius=width * 0.35, depth=0.15, location=(0, -width * 0.51, z_base))
    vent = bpy.context.active_object
    vent.rotation_euler = (math.radians(90), 0, 0)
    vent.data.materials.append(create_neon_material("MatVentOrange", color=(1.0, 0.40, 0.0), strength=4.5))

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, height - 0.18))
    band = bpy.context.active_object
    band.scale = (width + 0.08, width + 0.08, 0.28)
    bpy.ops.object.transform_apply(scale=True)
    band.data.materials.append(create_pbr_material("MatVentHaz", TEX_HAZARD, metallic=0.82, roughness=0.36))

    return z_base

def build_barrier_low():
    length = 2.6
    thick = 0.55
    height = 0.85
    z_base = height / 2.0

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, z_base))
    bar = bpy.context.active_object
    bar.scale = (length, thick, height)
    bpy.ops.object.transform_apply(scale=True)
    add_bevel(bar, width=0.06)
    bar.data.materials.append(create_pbr_material("MatBarHaz", TEX_HAZARD, metallic=0.85, roughness=0.32))

    bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=length * 0.92, location=(0, 0, height + 0.04))
    rail = bpy.context.active_object
    rail.rotation_euler = (0, math.radians(90), 0)
    rail.data.materials.append(create_neon_material("MatRailCyan", color=(0.0, 0.95, 1.0), strength=5.5))

    return z_base

# ----------------- CONFIGURATION TABLE -----------------

ASSETS = [
    # (filename, builder_func, kwargs, rx, ry, ortho_scale, cam_loc)
    ("wall_horiz_base.png", build_horizontal_wall, {"kind": "base"}, 256, 128, 4.4, (0, -7.0, 6.0)),
    ("wall_horiz_hazard.png", build_horizontal_wall, {"kind": "hazard"}, 256, 128, 4.4, (0, -7.0, 6.0)),
    ("wall_horiz_conduit.png", build_horizontal_wall, {"kind": "conduit"}, 256, 128, 4.4, (0, -7.0, 6.0)),
    ("wall_horiz_terminal.png", build_horizontal_wall, {"kind": "terminal"}, 256, 128, 4.4, (0, -7.0, 6.0)),

    ("wall_vert_base.png", build_vertical_wall, {"kind": "base"}, 128, 256, 4.4, (0, -7.0, 6.0)),
    ("wall_vert_hazard.png", build_vertical_wall, {"kind": "hazard"}, 128, 256, 4.4, (0, -7.0, 6.0)),
    ("wall_vert_conduit.png", build_vertical_wall, {"kind": "conduit"}, 128, 256, 4.4, (0, -7.0, 6.0)),

    ("corner_tl.png", build_corner, {"quadrant": "tl"}, 160, 160, 3.6, (0, -7.0, 6.0)),
    ("corner_tr.png", build_corner, {"quadrant": "tr"}, 160, 160, 3.6, (0, -7.0, 6.0)),
    ("corner_bl.png", build_corner, {"quadrant": "bl"}, 160, 160, 3.6, (0, -7.0, 6.0)),
    ("corner_br.png", build_corner, {"quadrant": "br"}, 160, 160, 3.6, (0, -7.0, 6.0)),

    ("pillar_reactor_core.png", build_pillar_reactor, {}, 160, 192, 3.2, (0, -6.5, 5.5)),
    ("pillar_vent_tower.png", build_pillar_vent, {}, 160, 192, 3.2, (0, -6.5, 5.5)),
    ("barrier_low_tech.png", build_barrier_low, {}, 160, 112, 3.0, (0, -6.0, 5.0)),
]

def render_all():
    print("Building Blender Tech Maze assets with TRACK_TO centering...")
    t_start = time.time()
    for idx, (filename, builder, kwargs, rx, ry, o_scale, cam_loc) in enumerate(ASSETS):
        t0 = time.time()
        clean_scene()
        scene = bpy.context.scene
        scene.render.engine = 'CYCLES'
        scene.cycles.device = 'CPU'
        scene.cycles.samples = 14
        scene.render.film_transparent = True
        scene.render.resolution_x = rx
        scene.render.resolution_y = ry
        scene.render.filepath = os.path.join(OUT_DIR, filename)

        setup_lighting()
        z_target = builder(**kwargs)
        setup_camera_trackto(target_z=z_target, ortho_scale=o_scale, cam_loc=cam_loc)

        bpy.ops.render.render(write_still=True)
        print(f"[{idx+1}/{len(ASSETS)}] Rendered {filename} in {time.time() - t0:.2f}s")
    print(f"Done! All {len(ASSETS)} assets rendered in {time.time() - t_start:.2f}s")

if __name__ == "__main__":
    render_all()
