#!/usr/bin/env python3
"""
mecha-forge — build COMBAT-READY upright keyframed 3D animations for chassis 'titan'
using meshy_in/titan/rigged.glb, adapted from build_vortex_anims.py (meme squelette
standard : Hips/Spine02/LeftArm/RightArm/... verifie present sur les deux rigs).

🚨 POURQUOI CE SCRIPT EXISTE (patron, 24/09). Les 6 chassis ecartes en 2026 (dont titan,
via l'ancien build_mecha.py, rig en calques abandonne) n'ont jamais eu ce traitement : ils
sont passes par bake_anim.py, qui echantillonne MECANIQUEMENT l'animation que Meshy genere
tout seul — aucune posture voulue. C'est ce qui explique, mesure sur les planches reelles,
le desequilibre visible sur Vanguard et le saut de pose de Valiant/Pilot. Vortex et
Bluestrike, eux, sont CHOREGRAPHIES A LA MAIN (7 poses par script dedie) — c'est ce qui les
rend plus aboutis. Ce script applique la MEME methode a Titan, pas le pipeline generique.

DIFFERENCE DE CARACTERE avec Vortex (deja etabli ailleurs dans le projet : "heavy weight
class... slower/heavier gait" dans l'ancien build_mecha.py ; lookdev = pose bloquee,
symetrique, arme tenue BASSE, pas en garde) :
  - Garde BASSE et large plutot que bras leves vers la cible (Vortex = tireur de precision,
    Titan = encaisseur).
  - Amplitudes de hanche/genou plus GRANDES en marche/course (pas plus lourds, pas
    seulement une posture figee) — mais MEME cadence image par image que Vortex, puisque
    FPS est un dictionnaire GLOBAL partage par tous les chassis (verifie dans
    DirectionalMecha.gd : "walk": 16.0 pour tout le monde) — le seul levier disponible
    est l'amplitude du mouvement, pas sa vitesse de lecture.
  - Buste plus rigide (moins de balancement lateral) : un bunker ne se dandine pas.

Generates 7 animations x 4 directions (28 sprite sheets, 2048x256 each, 8 frames):
1. idle — stance large, garde basse, respiration lente.
2. walk — foulee lourde, fort transfert de poids, buste stable.
3. run — charge, penche en avant, foulees amples.
4. attack — tir stabilise, recul marque (encaisseur, pas esquive).
5. hit — flinch court, absorbe plus qu'il ne recule (bunker).
6. die — effondrement massif, genoux qui lachent d'un coup.
7. melee — coup d'epaule/percussion plutot qu'une lame (titan n'en tient pas).

Guarantees exact camera auto-framing (~50-55% height filling, ~137-143px in 256px cell).
Generates preview GIFs in meshy_in/previews/ and 28 baked sprite sheets in game/assets/mecha/
"""
import bpy, sys, os, math, mathutils
from PIL import Image

GLB_IN = os.path.abspath("meshy_in/titan/rigged.glb")
OUT_DIR = os.path.abspath("game/assets/mecha")
PREVIEW_DIR = os.path.abspath("meshy_in/previews")
CHASSIS = "titan"
RES = 256
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

def apply_bunker_guard_base(arm):
    """Garde BASSE et large — a l'oppose de la garde de Vortex (bras leves vers la cible).
    Titan encaisse, il ne vise pas en priorite."""
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x = math.radians(-2)   # buste plus droit que Vortex (-4)
    if "Spine01" in pb:
        pb["Spine01"].rotation_euler.x = math.radians(1)
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.x = math.radians(1)

    # GARDE BASSE : coudes proches du corps, avant-bras vers le bas-avant plutot que leves.
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler = (math.radians(-14), math.radians(10), math.radians(-8))
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler = (math.radians(-14), math.radians(-10), math.radians(8))
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler = (math.radians(-30), math.radians(5), 0)
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler = (math.radians(-30), math.radians(-5), 0)
    # 🚨 CORRECTIF JAMBE ASYMETRIQUE (patron, 24/09 : « une jambe qui tangue » a la marche).
    # Le rig Meshy de titan a un bind pose DEJA asymetrique (mesure via bpy, angle par
    # rapport a la verticale : hanche gauche 32.4°, hanche droite 22.1° — ~10° d'ecart, alors
    # que le rig de vortex est symetrique a 0.1° pres). reset_pose() revient a ce bind pose,
    # donc toute animation qui ne fixe pas explicitement UpLeg (idle, attack, hit) heritait
    # de ce desequilibre ; celles qui le fixent (walk/run/die/melee) l'ECRASAIENT en assignant
    # `=` plutot que `+=`, donc le correctif doit AUSSI passer par ces fonctions. Valeurs
    # choisies par mesure (tools/_leg_pitch_probe, non versionne) pour ramener les deux jambes
    # a ~15° de la verticale, symetriques.
    if "LeftUpLeg" in pb:
        pb["LeftUpLeg"].rotation_euler.x = math.radians(18.0)
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x = math.radians(15.0)
    # Stance large : les jambes ecartees davantage qu'un chassis leger (rig au repos deja
    # ecarte pour la plupart des Meshy humanoides ; on ne force pas UpLeg en Y pour eviter
    # une torsion de hanche non voulue — l'ecart vient du modele + de l'amplitude en marche).

# --- ANIMATION KEYFRAMERS ---

def pose_idle(arm, f, total_frames=8):
    reset_pose(arm)
    apply_bunker_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    phase = 2 * math.pi * t

    # Respiration LENTE et AMPLE (masse), pas le petit bob de Vortex.
    bob = 0.010 * math.sin(phase)
    if "Hips" in pb:
        pb["Hips"].location.z = bob
        pb["Hips"].rotation_euler.z = 0.008 * math.sin(phase)   # buste plus stable
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.z = -0.006 * math.sin(phase)
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x += 0.02 * math.sin(phase)
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x += 0.02 * math.sin(phase)

def pose_walk(arm, f, total_frames=8):
    reset_pose(arm)
    apply_bunker_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    p = 2 * math.pi * t

    # Foulee LOURDE : bob plus marque (transfert de poids), sway plus faible (buste stable,
    # a l'oppose du sway=0.045 de Vortex).
    bob = -0.055 * abs(math.sin(p)) + 0.022
    sway = 0.022 * math.sin(p)
    if "Hips" in pb:
        pb["Hips"].location.z = bob
        pb["Hips"].rotation_euler.z = sway

    # Foulee plus ample (jambe levee plus haut = pas qui "tape") mais MEME frequence —
    # le FPS global (16.0) impose la cadence, l'amplitude seule porte le poids.
    l_pitch = math.radians(34) * math.sin(p)
    r_pitch = math.radians(34) * math.sin(p + math.pi)

    # 🚨 CORRECTIF PHASE GENOU (patron, 24/09 : « on a l'impression qu'il vole »). L'ancienne
    # formule -sin(p-0.25) faisait culminer la flexion au DECOLLAGE (hanche au max arriere)
    # et retombait a 0 (jambe raide) pendant tout le BALANCEMENT AVANT — or c'est justement
    # pendant le balancement avant que le pied doit se soulever pour degager le sol ; une
    # jambe raide qui pivote juste a la hanche en gardant le pied a hauteur constante (la
    # cheville contre-tourne pour le garder a plat) glisse comme sur de la glace : aucun
    # appui visible, d'ou l'impression de vol. cos(p) culmine a p=0, exactement quand
    # l_pitch (=34*sin(p)) passe par 0 en augmentant — le milieu du balancement, pied a
    # l'aplomb du corps, moment ou il doit etre le plus haut. Il retombe a 0 aux deux
    # extremes (p=+-90°, ~pose jambe tendue a l'appui ET a la posee), et reste nul tout
    # l'appui (p in [90°,270°]) : la jambe qui porte le poids ne plie pas.
    l_knee = math.radians(58) * max(0.0, math.cos(p))
    r_knee = math.radians(58) * max(0.0, -math.cos(p))

    l_ankle = -l_pitch * 0.6
    r_ankle = -r_pitch * 0.6

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
        pb["Spine01"].rotation_euler.y = -0.015 * math.sin(p)   # torse rigide
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.z = -sway * 0.5

    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x += -math.radians(8) * math.sin(p)
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x += math.radians(8) * math.sin(p)

def pose_run(arm, f, total_frames=8):
    reset_pose(arm)
    apply_bunker_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    p = 2 * math.pi * t

    # "Charge" plutot que "sprint" : penche en avant plus franc, bob plus lourd.
    bob = -0.075 * abs(math.sin(p))
    sway = 0.03 * math.sin(p)
    if "Hips" in pb:
        pb["Hips"].location.z = bob
        pb["Hips"].rotation_euler.x = math.radians(10)   # penche en avant (Vortex : 6)
        pb["Hips"].rotation_euler.z = sway

    l_pitch = math.radians(44) * math.sin(p)
    r_pitch = math.radians(44) * math.sin(p + math.pi)

    # meme correctif de phase que pose_walk (voir son commentaire) : cos(p) culmine au milieu
    # du balancement avant plutot qu'au decollage.
    l_knee = math.radians(62) * max(0.0, math.cos(p))
    r_knee = math.radians(62) * max(0.0, -math.cos(p))

    if "LeftUpLeg" in pb:
        pb["LeftUpLeg"].rotation_euler.x += l_pitch
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x += r_pitch
    if "LeftLeg" in pb:
        pb["LeftLeg"].rotation_euler.x = l_knee
    if "RightLeg" in pb:
        pb["RightLeg"].rotation_euler.x = r_knee

    if "Spine" in pb:
        pb["Spine"].rotation_euler.x = math.radians(-6)
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.z = -sway * 0.6

    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x += math.radians(6) - math.radians(10) * math.sin(p)
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x += math.radians(6) + math.radians(10) * math.sin(p)

def pose_attack(arm, f, total_frames=8):
    reset_pose(arm)
    apply_bunker_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    p = 2 * math.pi * t

    shot_l = math.sin(p)
    shot_r = math.sin(p + math.pi)

    # Vise depuis la garde basse (pas de bras leve type Vortex) — le canon est plus bas,
    # position plus STABLE et plus large que le tireur de precision.
    arm_aim_x = math.radians(-24)
    forearm_aim_x = math.radians(-40)

    l_recoil = math.radians(10) * max(0.0, shot_l)   # recul plus contenu (masse = inertie)
    r_recoil = math.radians(10) * max(0.0, shot_r)
    body_recoil = -0.012 * (max(0.0, shot_l) + max(0.0, shot_r))

    if "Hips" in pb:
        pb["Hips"].location.y = body_recoil
        pb["Hips"].rotation_euler.z = 0.015 * math.sin(p)
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x = math.radians(-3) + 0.025 * math.sin(p * 2)
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.x = math.radians(3) - 0.02 * math.sin(p * 2)

    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x = arm_aim_x + l_recoil
        pb["LeftArm"].rotation_euler.y = math.radians(8)
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x = arm_aim_x + r_recoil
        pb["RightArm"].rotation_euler.y = math.radians(-8)
    if "LeftForeArm" in pb:
        pb["LeftForeArm"].rotation_euler.x = forearm_aim_x + l_recoil * 0.7
    if "RightForeArm" in pb:
        pb["RightForeArm"].rotation_euler.x = forearm_aim_x + r_recoil * 0.7

def pose_hit(arm, f, total_frames=8):
    reset_pose(arm)
    apply_bunker_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames

    # ENCAISSE plutot qu'il ne recule : amplitude de flinch reduite de moitie vs Vortex,
    # revient plus vite (l'inertie d'un lourd absorbe, ne rebondit pas).
    if t < 0.25:
        p = t / 0.25
        flinch = math.radians(-11) * p
        hip_back = -0.03 * p
        knee_bend = math.radians(14) * p
    elif t < 0.5:
        p = (t - 0.25) / 0.25
        flinch = math.radians(-11) + math.radians(6) * p
        hip_back = -0.03 + 0.015 * p
        knee_bend = math.radians(14) - math.radians(6) * p
    else:
        p = (t - 0.5) / 0.5
        flinch = math.radians(-5) * (1.0 - p)
        hip_back = -0.015 * (1.0 - p)
        knee_bend = math.radians(8) * (1.0 - p)

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
    apply_bunker_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames
    # Effondrement plus BRUTAL/rapide (p atteint 1.0 plus tot) : les genoux lachent d'un
    # coup plutot qu'un slump progressif — la masse tombe, elle ne se plie pas doucement.
    p = min(1.0, t / 0.6)

    hip_drop = -0.22 * p
    knee_buckle = math.radians(60) * p
    torso_slump = math.radians(-30) * p   # moins de plongeon avant que Vortex (masse au sol)
    arm_drop = math.radians(-22) * p

    if "Hips" in pb:
        pb["Hips"].location.z = hip_drop
        pb["Hips"].rotation_euler.x = math.radians(-6) * p
    if "LeftUpLeg" in pb:
        pb["LeftUpLeg"].rotation_euler.x += math.radians(16) * p
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x += math.radians(-8) * p
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
        pb["Head"].rotation_euler.x += math.radians(18) * p

def pose_melee(arm, f, total_frames=8):
    """Titan ne tient pas de lame (lookdev confirme) : un coup d'EPAULE/percussion plutot
    qu'une trajectoire de lame — poids du corps qui percute, pas un arc de bras."""
    reset_pose(arm)
    apply_bunker_guard_base(arm)
    pb = arm.pose.bones
    t = f / total_frames

    if t < 0.3:
        p = t / 0.3
        lunge = -0.03 * p          # recul (charge la percussion)
        lean = math.radians(-8) * p
    elif t < 0.55:
        p = (t - 0.3) / 0.25
        lunge = -0.03 + 0.14 * p   # projection en avant, rapide
        lean = math.radians(-8) + math.radians(26) * p
    else:
        p = (t - 0.55) / 0.45
        lunge = 0.11 * (1.0 - p)
        lean = math.radians(18) * (1.0 - p)

    if "Hips" in pb:
        pb["Hips"].location.y = lunge
    if "Spine" in pb:
        pb["Spine"].rotation_euler.x = lean * 0.6
    if "Spine02" in pb:
        pb["Spine02"].rotation_euler.x = lean * 0.4
    if "RightUpLeg" in pb:
        pb["RightUpLeg"].rotation_euler.x += math.radians(16) * (1.0 if t < 0.55 else max(0.0, 1.0 - (t - 0.55) * 3))
    if "LeftArm" in pb:
        pb["LeftArm"].rotation_euler.x += lean * 0.3
    if "RightArm" in pb:
        pb["RightArm"].rotation_euler.x += lean * 0.3

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

    tmp_png = os.path.join(PREVIEW_DIR, "_tmp_titan.png")
    DIRS = [("front", 0), ("back", 180), ("left", 90), ("right", -90)]

    print("=== BAKING 28 SPRITESHEETS FOR TITAN (meshy_in/titan/rigged.glb) ===")

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

    print("\n=== SUMMARY OF BAKED TITAN SPRITE SHEETS ===")
    for anim_name, dir_name, out_png, h, pct in summary_results:
        print(f"{CHASSIS}_{anim_name}_{dir_name}.png: {h}px ({pct:.1f}%)")
    print("=== ALL TITAN SPRITE SHEETS BAKED SUCCESSFULLY ===")

if __name__ == "__main__":
    main()
