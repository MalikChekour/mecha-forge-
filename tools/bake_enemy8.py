#!/usr/bin/env python3
"""
(17/10 : variante 8 DIRECTIONS + --oneshot pour les ennemis ; voir tools/bake_enemy_all.py)
mecha-forge — bake an ANIMATED GLB (Meshy rig+animation) into a 2D spritesheet
(headless bpy, Cycles CPU, no GPU). Samples N frames evenly across the animation,
renders each from a fixed top-down 3/4 camera onto transparency, and tiles them
into a horizontal spritesheet ready for a Sprite2D (hframes=N) in Godot.

At this sprite scale the smooth-skin joint deformation that hard-surface armor
suffers from is invisible — which is exactly why baking Meshy's animation to 2D
is viable for a top-down survivor.

  python bake_anim.py <in.glb> <out_sheet.png> [--frames 8] [--res 256]
                      [--el 40] [--yaw 0] [--samples 24]
"""
import bpy, sys, os, math, mathutils
from PIL import Image


def argval(flag, default, cast=float):
    a = sys.argv
    return cast(a[a.index(flag) + 1]) if flag in a else default

GLB = os.path.abspath(sys.argv[1])
OUT = os.path.abspath(sys.argv[2])
FRAMES = int(argval("--frames", 8))
RES = int(argval("--res", 256))
EL = argval("--el", 40.0)
YAW = argval("--yaw", 0.0)
SAMPLES = int(argval("--samples", 24))
POSE = argval("--pose", "", str)   # "attack" : les BRAS du rig (LeftArm/RightArm...) sont animes a la main sur rigged.glb
TMP = os.path.join(os.path.dirname(OUT) or ".", "_animframe.png")


LIGHT_ROOT = None

def setup_render():
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
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.08, 0.09, 0.13, 1.0)
    bg.inputs["Strength"].default_value = 0.45

    global LIGHT_ROOT
    LIGHT_ROOT = bpy.data.objects.new("lightroot", None); sc.collection.objects.link(LIGHT_ROOT)
    def sun(name, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(name, type="SUN"); d.energy = e; d.color = col
        d.angle = math.radians(5)
        o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        o.parent = LIGHT_ROOT   # les lumieres tournent AVEC la camera : meme eclairage dans les 8 directions
    sun("key", 4.2, (52, 8, -34), (1.0, 0.97, 0.9))
    sun("fill", 1.4, (66, -6, 46), (0.75, 0.85, 1.0))
    sun("rim", 4.0, (-38, 0, 160), (0.7, 0.95, 1.0))


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def frame_bounds(objs):
    mn = mathutils.Vector((1e9, 1e9, 1e9)); mx = -mn
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            w = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i]); mx[i] = max(mx[i], w[i])
    return mn, mx



R = math.radians
def apply_pose(arm_obj, i, n):
    """Poses PROCEDURALES sur le rig Meshy (memes os que Vortex) : marche = celle de Vortex (jambes 28 deg, genoux 45, rebond du bassin,
    bras en garde puis tendu), attaque = bras tendus + recul, mort = effondrement (bassin, genoux, buste)."""
    pb = arm_obj.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"; b.rotation_euler = (0, 0, 0); b.location = (0, 0, 0)
    def S(name, e):
        if name in pb: pb[name].rotation_euler = e
    def L(name, loc):
        if name in pb: pb[name].location = loc
    if POSE == "walk":
        p = 2 * math.pi * i / n
        L("Hips", (0, 0, -0.04 * abs(math.sin(p)) + 0.018)); S("Hips", (0, 0, 0.024 * math.sin(p)))
        for side, ph in (("Left", 0.0), ("Right", math.pi)):
            pit = R(28) * math.sin(p + ph)
            kn = R(45) * max(0.0, -math.sin(p + ph - 0.25))
            S(side + "UpLeg", (pit, 0, 0)); S(side + "Leg", (kn, 0, 0)); S(side + "Foot", (-pit * 0.6, 0, 0))
        S("Spine", (R(-6), 0, 0)); S("Spine02", (R(2), 0, 0))
        # bras en garde, balancement oppose aux jambes (comme Vortex marche en tenant son arme)
        S("RightArm", (R(-70) + R(10) * math.sin(p), R(-6), R(4))); S("RightForeArm", (R(-16), 0, 0))
        S("LeftArm", (R(-30) - R(10) * math.sin(p), R(14), R(-10))); S("LeftForeArm", (R(-52), 0, 0))
    elif POSE == "attack":
        t = i / float(n)
        pulse = max(0.0, math.sin(2 * math.pi * t))
        up = 0.5 - 0.5 * math.cos(2 * math.pi * min(1.0, t * 1.6))
        S("RightArm", (R(-86) * up + R(7) * pulse, R(-2), R(2))); S("LeftArm", (R(-86) * up + R(5) * pulse, R(2), R(-2)))
        S("Spine", (R(-5) * up - R(3) * pulse, 0, 0)); S("Spine02", (R(-3) * up, 0, 0))
        L("Hips", (0, 0.012 * pulse, 0))
    elif POSE == "die":
        p = min(1.0, (i / float(max(1, n - 1))) / 0.85)
        L("Hips", (0, 0, -0.18 * p)); S("Hips", (R(-10) * p, 0, 0))
        for side in ("Left", "Right"):
            S(side + "Leg", (R(55) * p, 0, 0)); S(side + "UpLeg", (R(-20) * p, 0, 0))
        S("Spine", (R(-42) * 0.5 * p, 0, 0))
        S("RightArm", (R(20) * p, 0, 0)); S("LeftArm", (R(20) * p, 0, 0))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if GLB.lower().endswith(".fbx"):          # Mixamo returns animated FBX
        bpy.ops.import_scene.fbx(filepath=GLB, automatic_bone_orientation=True)
    else:
        bpy.ops.import_scene.gltf(filepath=GLB)
    objs = meshes()
    if not objs:
        raise RuntimeError("no mesh in GLB")
    if YAW:
        for o in bpy.context.scene.objects:
            if o.parent is None:
                o.rotation_euler.z += math.radians(YAW)
    sc = bpy.context.scene
    # FBX import does NOT set the scene frame range -> read it from the imported action(s),
    # else every sampled frame is the same pose (identical sheet cells = looks frozen in-game).
    fs, fe = 1e9, -1e9
    for o in bpy.context.scene.objects:
        ad = o.animation_data
        if ad and ad.action:
            r = ad.action.frame_range
            fs = min(fs, r[0]); fe = max(fe, r[1])
    if fe > fs:
        sc.frame_start = int(round(fs)); sc.frame_end = int(round(fe))
    f0, f1 = sc.frame_start, sc.frame_end
    if f1 <= f0:
        f1 = f0 + 24
    ONESHOT = "--oneshot" in sys.argv   # die : on va jusqu'a la derniere image (pas de boucle)
    frames = [int(round(f0 + (f1 - f0) * i / (FRAMES - 1 if ONESHOT else FRAMES))) for i in range(FRAMES)]
    setup_render()
    ARM = None
    if POSE:
        ARM = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
        frames = list(range(FRAMES))

    # Size the ortho frame from a representative pose (not the union — Meshy walks
    # carry root motion, so the union would shrink the character and it would drift).
    if POSE:
        # cadrage SERRE : union des bornes sur toutes les images de la pose (plus de pixels sur la creature, sans agrandir la planche)
        umn = mathutils.Vector((1e9, 1e9, 1e9)); umx = -umn
        for fi in range(FRAMES):
            apply_pose(ARM, fi, FRAMES); bpy.context.view_layer.update()
            a, b2 = frame_bounds(objs)
            for k in range(3):
                umn[k] = min(umn[k], a[k]); umx[k] = max(umx[k], b2[k])
        apply_pose(ARM, 0, FRAMES); bpy.context.view_layer.update()
        mn0, mx0 = umn, umx
    else:
        sc.frame_set(frames[0])
        mn0, mx0 = frame_bounds(objs)
    center0 = (mn0 + mx0) * 0.5
    size = max((mx0 - mn0).x, (mx0 - mn0).y, (mx0 - mn0).z, 1e-3)
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * (1.08 if POSE else 1.12)
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    e = math.radians(EL); dist = size * 4.0

    def aim(center, az):
        a = math.radians(az)
        cam.location = (center.x + dist * math.cos(e) * math.sin(a),
                        center.y - dist * math.cos(e) * math.cos(a),
                        center.z + dist * math.sin(e))
        if LIGHT_ROOT is not None:
            LIGHT_ROOT.rotation_euler = (0.0, 0.0, a)
        look = center - mathutils.Vector(cam.location)
        cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

    # facing: 1 view (front, + flip in-engine) or 4 cardinal directions.
    DIRS = {1: [("", 0)],
            4: [("_front", 0), ("_back", 180), ("_left", 90), ("_right", -90)],
            8: [("_front", 0), ("_back", 180), ("_left", 90), ("_right", -90),
                ("_front_right", -45), ("_front_left", 45), ("_back_right", -135), ("_back_left", 135)]}
    ndirs = int(argval("--dirs", 1))
    stem, ext = os.path.splitext(OUT)
    for suffix, az in DIRS.get(ndirs, DIRS[1]):
        tiles = []
        for f in frames:
            if POSE:
                apply_pose(ARM, f, FRAMES); bpy.context.view_layer.update()
            else:
                sc.frame_set(f)
            mn, mx = frame_bounds(objs)
            cen = (mn + mx) * 0.5
            cen.z = center0.z              # anchor vertical -> kill pose bob/jitter
            aim(cen, az)                   # track XY (root motion), stable height

            sc.render.filepath = TMP
            bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(TMP).convert("RGBA").copy())
        sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
        for k, im in enumerate(tiles):
            sheet.paste(im, (RES * k, 0), im)
        sheet.save(stem + suffix + ext)
    if os.path.exists(TMP):
        os.remove(TMP)
    print("SHEET", OUT, "dirs", ndirs, "%dx%d/dir" % (RES * FRAMES, RES), "frames", FRAMES)


if __name__ == "__main__":
    main()
