#!/usr/bin/env python3
import bpy, bmesh, sys, os, math, mathutils
from PIL import Image

GLB_IN = os.path.abspath("meshy_in/vanguard2/rigged.glb")
OUT_DIR = os.path.abspath("game/assets/mecha")
CHASSIS = "new_mecha"
RES = 256
FRAMES = 8
SAMPLES = 16
EL = 40.0

os.makedirs(OUT_DIR, exist_ok=True)

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
    # Enhance existing materials instead of destroying them
    for obj in objs:
        for mat in obj.data.materials:
            if not mat or not mat.node_tree:
                continue
            nodes = mat.node_tree.nodes
            bsdf = None
            for n in nodes:
                if n.type == 'BSDF_PRINCIPLED':
                    bsdf = n
                    break
            if bsdf:
                # Make it look like polished dark armor but KEEP the textures
                if "Metallic" in bsdf.inputs:
                    bsdf.inputs["Metallic"].default_value = 0.8
                if "Roughness" in bsdf.inputs:
                    bsdf.inputs["Roughness"].default_value = 0.3
                # Boost emission if it has any
                if "Emission Strength" in bsdf.inputs:
                    bsdf.inputs["Emission Strength"].default_value = 5.0

def build_heavy_weapon(armature):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.15, depth=1.2, location=(0, 0, 0))
    barrel = bpy.context.active_object
    barrel.name = "HeavyCannon"
    
    mat = bpy.data.materials.new(name="WeaponGlow")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (1.0, 0.4, 0.1, 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 10.0
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.1, 0.1, 0.1, 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 1.0
    
    barrel.data.materials.append(mat)
    
    bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0, 0, -0.4))
    base = bpy.context.active_object
    mat_base = bpy.data.materials.new(name="WeaponBase")
    mat_base.use_nodes = True
    mat_base.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.1, 0.1, 0.1, 1.0)
    mat_base.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.8
    mat_base.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.3
    base.data.materials.append(mat_base)
    
    with bpy.context.temp_override(active_object=barrel, selected_editable_objects=[base, barrel]):
        bpy.ops.object.join()
    
    barrel.rotation_euler = (math.radians(90), 0, 0)
    
    barrel.parent = armature
    barrel.parent_type = 'BONE'
    barrel.parent_bone = "RightForeArm"
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
        
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler = (math.radians(28), math.radians(16), math.radians(-12))
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler = (math.radians(28), math.radians(-16), math.radians(12))
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler = (math.radians(52), math.radians(8), 0)
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler = (math.radians(52), math.radians(-8), 0)

# ANIMATIONS
def pose_idle(arm, f, total_frames=8):
    reset_pose(arm)
    apply_combat_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    phase = 2 * math.pi * t
    
    bob = 0.014 * math.sin(phase)
    if "Hips" in pb:
        pb["Hips"].location.z = bob
        pb["Hips"].rotation_euler.z = 0.015 * math.sin(phase)
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.z = -0.01 * math.sin(phase)
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x += 0.03 * math.sin(phase)
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x += 0.03 * math.sin(phase)

def pose_walk(arm, f, total_frames=8):
    reset_pose(arm)
    apply_combat_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    p = 2 * math.pi * t
    
    bob = -0.04 * abs(math.sin(p)) + 0.018
    sway = 0.045 * math.sin(p)
    if "Hips" in pb:
        pb["Hips"].location.z = bob
        pb["Hips"].rotation_euler.z = sway
        
    l_pitch = math.radians(28) * math.sin(p)
    r_pitch = math.radians(28) * math.sin(p + math.pi)
    
    l_knee = math.radians(45) * max(0.0, -math.sin(p - 0.25))
    r_knee = math.radians(45) * max(0.0, -math.sin(p + math.pi - 0.25))
    
    l_ankle = -l_pitch * 0.65
    r_ankle = -r_pitch * 0.65
    
    if "LeftUpLeg" in pb:
        pb["LeftUpLeg"].rotation_euler.x = l_pitch
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x = r_pitch
    if "LeftLeg" in pb:
        pb["LeftLeg"].rotation_euler.x = l_knee
    if "RightLeg" in pb:
        pb["RightLeg"].rotation_euler.x = r_knee
    if "LeftFoot" in pb:
        pb["LeftFoot"].rotation_euler.x = l_ankle
    if "RightFoot" in pb:
        pb["RightFoot"].rotation_euler.x = r_ankle
        
    if "Spine01" in pb:
        pb["Spine01"].rotation_euler.y = -0.03 * math.sin(p)
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.z = -sway * 0.7
        
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x += -math.radians(12) * math.sin(p)
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x += math.radians(12) * math.sin(p)

def pose_run(arm, f, total_frames=8):
    reset_pose(arm)
    apply_combat_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    p = 2 * math.pi * t
    
    bob = -0.065 * abs(math.sin(p))
    sway = 0.06 * math.sin(p)
    if "Hips" in pb:
        pb["Hips"].location.z = bob
        pb["Hips"].rotation_euler.x = math.radians(6)
        pb["Hips"].rotation_euler.z = sway
        
    l_pitch = math.radians(40) * math.sin(p)
    r_pitch = math.radians(40) * math.sin(p + math.pi)
    
    l_knee = math.radians(58) * max(0.0, -math.sin(p - 0.2))
    r_knee = math.radians(58) * max(0.0, -math.sin(p + math.pi - 0.2))
    
    if "LeftUpLeg" in pb:
        pb["LeftUpLeg"].rotation_euler.x = l_pitch
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x = r_pitch
    if "LeftLeg" in pb:
        pb["LeftLeg"].rotation_euler.x = l_knee
    if "RightLeg" in pb:
        pb["RightLeg"].rotation_euler.x = r_knee
        
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x = math.radians(-3)
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.z = -sway
        
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x += math.radians(10) - math.radians(18) * math.sin(p)
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x += math.radians(10) + math.radians(18) * math.sin(p)
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler.x = math.radians(45) + math.radians(12) * math.sin(p)
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler.x = math.radians(45) - math.radians(12) * math.sin(p)

def pose_attack(arm, f, total_frames=8):
    reset_pose(arm)
    apply_combat_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    p = 2 * math.pi * t
    
    shot_r = math.sin(p * 2) 
    
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
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x = arm_aim_x
        pb["LeftArm"].rotation_euler.y = math.radians(12)
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler.x = forearm_aim_x

def pose_hit(arm, f, total_frames=8):
    reset_pose(arm)
    apply_combat_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    
    if t < 0.3:
        p = t / 0.3
        flinch = math.radians(-24) * p
        hip_back = -0.07 * p
        knee_bend = math.radians(25) * p
    elif t < 0.6:
        p = (t - 0.3) / 0.3
        flinch = math.radians(-24) + math.radians(12) * p
        hip_back = -0.07 + 0.03 * p
        knee_bend = math.radians(25) - math.radians(10) * p
    else:
        p = (t - 0.6) / 0.4
        flinch = math.radians(-12) * (1.0 - p)
        hip_back = -0.04 * (1.0 - p)
        knee_bend = math.radians(15) * (1.0 - p)

    if "Hips" in pb:
        pb["Hips"].location.y = hip_back
        pb["Hips"].location.z = -hip_back * 0.5
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x += flinch * 0.5
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.x += flinch * 0.5
    if "LeftLeg" in pb:
        pb["LeftLeg"].rotation_euler.x += knee_bend
    if "RightLeg" in pb:
        pb["RightLeg"].rotation_euler.x += knee_bend
    if "Head" in pb:
        pb["Head"].rotation_euler.x += flinch * 0.4

def pose_die(arm, f, total_frames=8):
    reset_pose(arm)
    apply_combat_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    p = min(1.0, t / 0.85)
    
    hip_drop = -0.18 * p
    knee_buckle = math.radians(55) * p
    torso_slump = math.radians(-42) * p
    arm_drop = math.radians(-30) * p
    
    if "Hips" in pb:
        pb["Hips"].location.z = hip_drop
        pb["Hips"].rotation_euler.x = math.radians(-10) * p
    if "LeftUpLeg" in pb:
        pb["LeftUpLeg"].rotation_euler.x = math.radians(20) * p
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x = math.radians(-10) * p
    if "LeftLeg" in pb:
        pb["LeftLeg"].rotation_euler.x = knee_buckle
    if "RightLeg" in pb:
        pb["RightLeg"].rotation_euler.x = knee_buckle * 0.8
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x += torso_slump * 0.5
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.x += torso_slump * 0.5
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x += arm_drop
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x += arm_drop
    if "Head" in pb:
        pb["Head"].rotation_euler.x += math.radians(25) * p

def pose_melee(arm, f, total_frames=8):
    reset_pose(arm)
    apply_combat_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    
    if t < 0.25:
        p = t / 0.25
        lunge = -0.02 * p
        slash_yaw = math.radians(-35) * p
        slash_pitch = math.radians(20) * p
    elif t < 0.625:
        p = (t - 0.25) / 0.375
        lunge = -0.02 + 0.08 * p
        slash_yaw = math.radians(-35) + math.radians(95) * p
        slash_pitch = math.radians(20) + math.radians(25) * p
    else:
        p = (t - 0.625) / 0.375
        lunge = 0.06 * (1.0 - p)
        slash_yaw = math.radians(60) * (1.0 - p)
        slash_pitch = math.radians(45) * (1.0 - p)

    if "Hips" in pb:
        pb["Hips"].location.y = lunge
        pb["Hips"].rotation_euler.z = -slash_yaw * 0.3
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x = math.radians(20) * (1.0 if t < 0.5 else (1.0 - (t-0.5)*2))
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.z = slash_yaw * 0.5
        pb["Spine02"].rotation_euler.x = math.radians(-5) if t < 0.3 else math.radians(10)
        
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x = math.radians(40) + slash_pitch
        pb["RightArm"].rotation_euler.z = -slash_yaw
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler.x = math.radians(65)

POSERS = {
    "idle": pose_idle,
    "walk": pose_walk,
    "run": pose_run,
    "attack": pose_attack,
    "hit": pose_hit,
    "die": pose_die,
    "melee": pose_melee,
}

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

    pose_idle(arm, 0, FRAMES)
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

    tmp_png = os.path.join(OUT_DIR, "_tmp.png")
    DIRS = [("front", 0), ("back", 180), ("left", 90), ("right", -90)]
    
    print("=== BAKING 28 SPRITESHEETS FOR STYLISH MECHA ===")
    
    for anim_name, poser_fn in POSERS.items():
        print(f"--> Rendering '{anim_name}'...")
        for dir_name, az in DIRS:
            tiles = []
            for f in range(FRAMES):
                poser_fn(arm, f, FRAMES)
                mn, mx = frame_bounds(objs)
                cen = (mn + mx) * 0.5
                cen.z = center0.z  # anchor height on frame 0
                aim_cam(cen, az)
                
                sc.render.filepath = tmp_png
                bpy.ops.render.render(write_still=True)
                tiles.append(Image.open(tmp_png).convert("RGBA").copy())
                
            sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
            for k, im in enumerate(tiles):
                sheet.paste(im, (RES * k, 0), im)
                
            out_png = os.path.join(OUT_DIR, f"{CHASSIS}_{anim_name}_{dir_name}.png")
            sheet.save(out_png)
            print(f"    Saved {out_png}")

    if os.path.exists(tmp_png):
        os.remove(tmp_png)
        
if __name__ == "__main__":
    main()
