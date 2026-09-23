#!/usr/bin/env python3
import bpy, bmesh, sys, os, math, mathutils
from PIL import Image

GLB_IN = os.path.abspath("meshy_in/vanguard2/rigged.glb")
PREVIEW_DIR = os.path.abspath("meshy_in/previews")
CHASSIS = "new_mecha"
RES = 384  # slightly higher res for preview
FRAMES = 8
SAMPLES = 24
EL = 40.0

os.makedirs(PREVIEW_DIR, exist_ok=True)

def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB_IN)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = RES
    sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.05, 0.06, 0.08, 1.0)
        bg.inputs["Strength"].default_value = 0.5

    def sun(name, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(name, type="SUN")
        d.energy = e
        d.color = col
        d.angle = math.radians(5)
        o = bpy.data.objects.new(name, d)
        sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        
    sun("key", 6.0, (52, 15, -40), (1.0, 0.9, 0.8))
    sun("fill", 2.5, (66, -10, 46), (0.7, 0.8, 1.0))
    sun("rim", 5.0, (-38, 0, 160), (0.6, 0.9, 1.0))
    return sc

def get_armature():
    for o in bpy.context.scene.objects:
        if o.type == "ARMATURE":
            return o
    raise RuntimeError("No armature found")

def get_meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]

def apply_stylish_shader(objs):
    """Replaces the default shader with a highly stylish procedural dark metal + cyan emission"""
    mat = bpy.data.materials.new(name="StylishMecha")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Base Color"].default_value = (0.02, 0.025, 0.03, 1.0)
    
    # Edge detect for emissive lines
    geom = nodes.new("ShaderNodeNewGeometry")
    cr = nodes.new("ShaderNodeValToRGB")
    cr.color_ramp.elements[0].position = 0.45
    cr.color_ramp.elements[0].color = (0, 0, 0, 1)
    cr.color_ramp.elements[1].position = 0.55
    cr.color_ramp.elements[1].color = (1, 1, 1, 1)
    
    mix = nodes.new("ShaderNodeMixRGB")
    mix.inputs["Color1"].default_value = (0,0,0,1)
    mix.inputs["Color2"].default_value = (0.1, 0.8, 1.0, 1.0) # Cyan emission
    
    links.new(geom.outputs["Pointiness"], cr.inputs["Fac"])
    links.new(cr.outputs["Color"], mix.inputs["Fac"])
    links.new(mix.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 3.0
    
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    
    for obj in objs:
        obj.data.materials.clear()
        obj.data.materials.append(mat)

def build_heavy_weapon(armature):
    """Builds a geometric heavy weapon and parents it to the RightForeArm bone"""
    bpy.ops.mesh.primitive_cylinder_add(radius=0.15, depth=1.2, location=(0, 0, 0))
    barrel = bpy.context.active_object
    barrel.name = "HeavyCannon"
    
    # Add a glowing core
    mat = bpy.data.materials.new(name="WeaponGlow")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (1.0, 0.4, 0.1, 1.0) # Orange glow
    mat.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 10.0
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.1, 0.1, 0.1, 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 1.0
    
    barrel.data.materials.append(mat)
    
    # Add some blocky details to the weapon
    bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0, 0, -0.4))
    base = bpy.context.active_object
    base.data.materials.append(bpy.data.materials["StylishMecha"])
    
    # Join them
    with bpy.context.temp_override(active_object=barrel, selected_editable_objects=[base, barrel]):
        bpy.ops.object.join()
    
    # Position and orient relative to RightForeArm
    barrel.rotation_euler = (math.radians(90), 0, 0)
    
    # Parent to bone
    barrel.parent = armature
    barrel.parent_type = 'BONE'
    barrel.parent_bone = "RightForeArm"
    # Offset so it sits on the arm
    barrel.location = (0, 0.25, 0.2)
    return barrel

def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)

def apply_combat_guard_base(arm):
    pb = arm.pose.bones
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x = math.radians(-4)
    if "Spine01" in pb:
        pb["Spine01"].rotation_euler.x = math.radians(2)
        
    # COMBAT READY GUARD POSTURE: Forearms raised
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler = (math.radians(28), math.radians(16), math.radians(-12))
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler = (math.radians(28), math.radians(-16), math.radians(12))
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler = (math.radians(52), math.radians(8), 0)
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler = (math.radians(52), math.radians(-8), 0)

def pose_attack(arm, f, total_frames=8):
    """FIRING / AIM STANCE (LOOPING)"""
    reset_pose(arm)
    apply_combat_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    p = 2 * math.pi * t
    
    shot_r = math.sin(p * 2) # double tap
    
    arm_aim_x = math.radians(45)
    forearm_aim_x = math.radians(65)
    
    r_recoil = math.radians(-18) * max(0.0, shot_r)
    body_recoil = -0.02 * max(0.0, shot_r)
    
    if "Hips" in pb:
        pb["Hips"].location.y = body_recoil
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x = math.radians(-6) + 0.05 * max(0.0, shot_r)
        
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x = arm_aim_x + r_recoil
        pb["RightArm"].rotation_euler.y = math.radians(-12)
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler.x = forearm_aim_x + r_recoil * 0.8
    # Left arm balances
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x = arm_aim_x
        pb["LeftArm"].rotation_euler.y = math.radians(12)
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler.x = forearm_aim_x

def frame_bounds(objs):
    mn = mathutils.Vector((1e9, 1e9, 1e9))
    mx = -mn
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            w = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i])
                mx[i] = max(mx[i], w[i])
    return mn, mx

def main():
    sc = setup_scene()
    arm = get_armature()
    objs = get_meshes()
    
    apply_stylish_shader(objs)
    weapon = build_heavy_weapon(arm)
    objs.append(weapon)

    # Anchor on frame 0
    pose_attack(arm, 0, FRAMES)
    mn0, mx0 = frame_bounds(objs)
    center0 = (mn0 + mx0) * 0.5
    size = max((mx0 - mn0).x, (mx0 - mn0).y, (mx0 - mn0).z, 1e-3)
    
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = size * 1.2
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    
    e = math.radians(EL)
    dist = size * 4.0
    
    def aim_cam(center, az_deg):
        a = math.radians(az_deg)
        cam.location = (
            center.x + dist * math.cos(e) * math.sin(a),
            center.y - dist * math.cos(e) * math.cos(a),
            center.z + dist * math.sin(e),
        )
        look = center - mathutils.Vector(cam.location)
        cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

    tmp_png = os.path.join(PREVIEW_DIR, "_tmp.png")
    
    print(f"=== RENDERING STYLISH MECHA PREVIEW ===")
    
    # We will just render the attack animation (firing stance) for the preview GIF
    preview_frames = []
    # Camera rotates slowly around to show it off
    for f in range(FRAMES * 2): # 16 frames for a nice rotation
        pose_attack(arm, f % FRAMES, FRAMES)
        mn, mx = frame_bounds(objs)
        cen = (mn + mx) * 0.5
        cen.z = center0.z
        
        # Azimuth rotates from 0 to 90 degrees
        az = -45 + (f / (FRAMES * 2 - 1)) * 90 
        aim_cam(cen, az)
        
        sc.render.filepath = tmp_png
        bpy.ops.render.render(write_still=True)
        preview_frames.append(Image.open(tmp_png).convert("RGBA").copy())
        
    gif_path = os.path.join(PREVIEW_DIR, f"{CHASSIS}_preview.gif")
    preview_frames[0].save(
        gif_path,
        save_all=True,
        append_images=preview_frames[1:],
        duration=100,
        loop=0,
    )
    print(f"    Saved preview GIF: {gif_path}")

    if os.path.exists(tmp_png):
        os.remove(tmp_png)
        
if __name__ == "__main__":
    main()
