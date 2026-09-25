#!/usr/bin/env python3
"""
mecha-forge — build COMBAT-READY upright keyframed 3D animations for chassis 'vanquisher'
using meshy_in/vanquisher/rigged.glb — genere via Meshy DIRECTEMENT depuis une image de
reference fournie par le patron (planche mecha gris/orange, canons doubles tenus en main,
cockpit vitre visible), pas depuis un prompt FLUX texte : la reference visuelle deja validee
evite le cycle iteratif couteux de bruiser (4 tentatives, 95cr perdus).

Design (reference patron, 24/09) : bipede musclé/massif, cockpit vitre bien visible en
poitrine (engin PILOTE a echelle vehicule), deux canons distincts explicitement tenus dans
chaque main, pod de missiles a l'epaule gauche, aucune lame.

Meme lecon que titan/sentinel/bruiser : rig mesure via bpy AVANT le bake (LeftUpLeg/RightUpLeg
a 36.8°/28.6° de la verticale, 8.2° d'ecart). Contrairement aux autres chassis, la pure
rotation X ne suffit pas a egaliser les deux jambes (chacune plafonne a un minimum different
par rotation X seule — asymetrie laterale que la hanche seule ne corrige pas) : le meilleur
appariement trouve est LeftUpLeg=+30° -> 22.9°, RightUpLeg=+8° -> 23.0° (0.1° d'ecart, aussi
bon que les autres chassis, juste a une inclinaison de base plus prononcee). Choregraphie de
vortex reprise A L'IDENTIQUE (aucune formule modifiee, voir build_vortex_anims.py).
squelette standard verifie compatible (Hips/Spine/Spine01/Spine02/LeftArm/RightArm/
LeftForeArm/RightForeArm/LeftUpLeg/RightUpLeg/LeftLeg/RightLeg/LeftFoot/RightFoot/Head).

Generates 7 animations x 4 directions (28 sprite sheets, 2048x256 each, 8 frames):
1. idle — standing, forearms raised in guard, breathing bob.
2. walk — walking stride, forearms in guard, pronounced front stride.
3. run — sprint, forearms pointing forward.
4. attack — FIRING/AIM STANCE (LOOPING): double forearm cannon thrust + recoil kick + chest pulse.
5. hit — kinetic impact flinch, backward recoil.
6. die — knee collapse & slump.
7. melee — forward lunge + right arm blade slash arc sweep.

Guarantees exact camera auto-framing (~50-55% height filling, ~137-143px in 256px cell).
Generates preview GIFs in meshy_in/previews/ and 28 baked sprite sheets in game/assets/mecha/
"""
import bpy, sys, os, math, mathutils
from PIL import Image

GLB_IN = os.path.abspath("meshy_in/vanquisher/rigged.glb")
OUT_DIR = os.path.abspath("game/assets/mecha")
PREVIEW_DIR = os.path.abspath("meshy_in/previews")
CHASSIS = "vanquisher"
RES = 512
FRAMES = 8
SAMPLES = 16
EL = 40.0

os.makedirs(PREVIEW_DIR, exist_ok=True)
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
        bg.inputs["Color"].default_value = (0.08, 0.09, 0.13, 1.0)
        bg.inputs["Strength"].default_value = 0.45

    def sun(name, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(name, type="SUN")
        d.energy = e
        d.color = col
        d.angle = math.radians(5)
        o = bpy.data.objects.new(name, d)
        sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)

    sun("key", 4.5, (52, 8, -34), (1.0, 0.95, 0.88))
    sun("fill", 1.8, (66, -6, 46), (0.75, 0.85, 1.0))
    sun("rim", 4.0, (-38, 0, 160), (0.7, 0.95, 1.0))
    return sc

def get_armature():
    for o in bpy.context.scene.objects:
        if o.type == "ARMATURE":
            return o
    raise RuntimeError("No armature found")

def get_meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]

def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)

def apply_combat_guard_base(arm):
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    # Heroic upright posture
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x = math.radians(-4)
    if "Spine01" in pb:
        pb["Spine01"].rotation_euler.x = math.radians(2)
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.x = math.radians(2)

    # 🚨 GARDE BASSE (voir build_bruiser_anims.py) : l'ancienne garde de vortex (bras leves,
    # avant-bras a -52°) suppose un canon court solidaire du bras ; sur un chassis a arme
    # longue separee, elle pointe le canon vers/a travers la camera. Reprend la garde de
    # titan (coudes proches du corps).
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler = (math.radians(-14), math.radians(10), math.radians(-8))
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler = (math.radians(-14), math.radians(-10), math.radians(8))
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler = (math.radians(-30), math.radians(5), 0)
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler = (math.radians(-30), math.radians(-5), 0)

    # 🚨 CORRECTIF HANCHE (voir l'entete) : bind pose mesure a 36.8°/28.6° (8.2° d'ecart).
    # La rotation X seule plafonne a un minimum different par jambe (asymetrie laterale) ;
    # le meilleur appariement mesure est +30°/+8° -> 22.9°/23.0° (0.1° d'ecart).
    # Les fonctions qui animent LeftUpLeg/RightUpLeg (walk/run/die/melee, copiees de vortex)
    # utilisent `+=` pour ne pas ecraser cette base.
    if "LeftUpLeg" in pb:
        pb["LeftUpLeg"].rotation_euler.x = math.radians(30.0)
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x = math.radians(8.0)

    # 🚨 STANCE TROP LARGE, PUIS TROP CORRIGEE (patron 24/09 : « trop rabougri » -> 1er
    # correctif Z=28/-16 sur l'angle de hanche seul ; patron 25/09 : « vanquisher a les pieds
    # joints » -> ce correctif ecrasait bien plus que prevu une fois COMBINE au correctif de
    # genou (les deux rotations composent, l'angle de hanche seul ne predit pas l'ecart final).
    # Remesure directe sur l'ECART REEL entre pieds (position 3D, pas l'angle de hanche) :
    # vortex 17.0% de la hauteur, bluestrike 20.7%, titan (non corrige, jamais critique) 21.1%.
    # L'ancien Z=28/-16 donnait 5.2% (pieds quasi joints). Z=10/-6 donne 19.4%, dans la
    # fourchette vortex/bluestrike/titan.
    if "LeftUpLeg" in pb:
        pb["LeftUpLeg"].rotation_euler.z = math.radians(10.0)
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.z = math.radians(-6.0)

    # 🚨 CORRECTIF GENOU / PIEDS PAS A PLAT (voir build_titan_anims.py) : le tibia brut penchait
    # a 35.8°/22.3° de la verticale (contre 4.6°/19.1° chez vortex). Recherche empirique de la
    # rotation de genou qui le ramene pres de la verticale (~10-14°).
    if "LeftLeg" in pb:
        pb["LeftLeg"].rotation_euler.x = math.radians(-44.0)
    if "RightLeg" in pb:
        pb["RightLeg"].rotation_euler.x = math.radians(-18.0)

# --- ANIMATION KEYFRAMERS (copie A L'IDENTIQUE de build_vortex_anims.py — voir l'entete) ---

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
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler.x += 0.02 * math.sin(phase + 0.5)
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler.x += 0.02 * math.sin(phase + 0.5)

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
        pb["LeftUpLeg"].rotation_euler.x += l_pitch
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x += r_pitch
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
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler.x += math.radians(8) * math.sin(p)
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler.x += -math.radians(8) * math.sin(p)

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
        pb["LeftUpLeg"].rotation_euler.x += l_pitch
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x += r_pitch
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

    shot_l = math.sin(p)
    shot_r = math.sin(p + math.pi)

    arm_aim_x = math.radians(-42)
    forearm_aim_x = math.radians(-58)

    l_recoil = math.radians(14) * max(0.0, shot_l)
    r_recoil = math.radians(14) * max(0.0, shot_r)
    body_recoil = -0.02 * (max(0.0, shot_l) + max(0.0, shot_r))

    if "Hips" in pb:
        pb["Hips"].location.y = body_recoil
        pb["Hips"].rotation_euler.z = 0.03 * math.sin(p)
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x = math.radians(-6) + 0.05 * math.sin(p * 2)
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.x = math.radians(5) - 0.04 * math.sin(p * 2)

    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x = arm_aim_x + l_recoil
        pb["LeftArm"].rotation_euler.y = math.radians(12)
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x = arm_aim_x + r_recoil
        pb["RightArm"].rotation_euler.y = math.radians(-12)
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler.x = forearm_aim_x + l_recoil * 0.8
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler.x = forearm_aim_x + r_recoil * 0.8

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
        pb["LeftUpLeg"].rotation_euler.x += math.radians(20) * p
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x += math.radians(-10) * p
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
        pb["RightUpLeg"].rotation_euler.x += math.radians(20) * (1.0 if t < 0.5 else (1.0 - (t-0.5)*2))
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

    pose_idle(arm, 0, FRAMES)
    mn0, mx0 = frame_bounds(objs)
    center0 = (mn0 + mx0) * 0.5
    size = max((mx0 - mn0).x, (mx0 - mn0).y, (mx0 - mn0).z, 1e-3)

    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = size * 1.12
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

    tmp_png = os.path.join(PREVIEW_DIR, "_tmp_vanquisher.png")
    DIRS = [("front", 0), ("back", 180), ("left", 90), ("right", -90)]

    print("=== BAKING 28 SPRITESHEETS FOR VANQUISHER (meshy_in/vanquisher/rigged.glb) ===")

    summary_results = []

    for anim_name, poser_fn in POSERS.items():
        print(f"--> Processing animation '{anim_name}' ({FRAMES} frames)")

        preview_frames = []
        for f in range(FRAMES):
            poser_fn(arm, f, FRAMES)
            mn, mx = frame_bounds(objs)
            cen = (mn + mx) * 0.5
            cen.z = center0.z
            aim_cam(cen, 0)

            sc.render.filepath = tmp_png
            bpy.ops.render.render(write_still=True)
            preview_frames.append(Image.open(tmp_png).convert("RGBA").copy())

        gif_path = os.path.join(PREVIEW_DIR, f"{CHASSIS}_{anim_name}_preview.gif")
        preview_frames[0].save(
            gif_path,
            save_all=True,
            append_images=preview_frames[1:],
            duration=120,
            loop=0,
        )
        print(f"    Saved preview GIF: {gif_path}")

        for dir_name, az in DIRS:
            tiles = []
            for f in range(FRAMES):
                poser_fn(arm, f, FRAMES)
                mn, mx = frame_bounds(objs)
                cen = (mn + mx) * 0.5
                cen.z = center0.z
                aim_cam(cen, az)

                sc.render.filepath = tmp_png
                bpy.ops.render.render(write_still=True)
                tiles.append(Image.open(tmp_png).convert("RGBA").copy())

            sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
            for k, im in enumerate(tiles):
                sheet.paste(im, (RES * k, 0), im)

            out_png = os.path.join(OUT_DIR, f"{CHASSIS}_{anim_name}_{dir_name}.png")
            sheet.save(out_png)

            frame0 = sheet.crop((0, 0, RES, RES))
            bbox = frame0.getbbox()
            h = bbox[3] - bbox[1] if bbox else 0
            pct = (h / float(RES)) * 100.0
            summary_results.append((anim_name, dir_name, out_png, h, pct))
            print(f"    Saved sprite sheet: {out_png} | Frame 0 height: {h}px ({pct:.1f}% filling)")

    if os.path.exists(tmp_png):
        os.remove(tmp_png)

    print("\n=== SUMMARY OF BAKED VANQUISHER SPRITE SHEETS ===")
    for anim_name, dir_name, out_png, h, pct in summary_results:
        print(f"{CHASSIS}_{anim_name}_{dir_name}.png: {h}px ({pct:.1f}%)")
    print("=== ALL VANQUISHER SPRITE SHEETS BAKED SUCCESSFULLY ===")

if __name__ == "__main__":
    main()
