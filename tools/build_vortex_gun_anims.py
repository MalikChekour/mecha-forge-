"""VORTEX with an integrated ARM-CANNON: attach a 3D weapon to the RightForeArm bone (so it follows
every pose) pointing along the forearm, and bake the 7 anims x 4 dir. The cannon is part of every
rendered frame -> truly integrated, free (reuses meshy_in/vortex + a weapon 3D already generated).

Usage: python build_vortex_gun_anims.py [--test]   (--test renders only front idle to tune placement)
"""
import bpy, sys, os, math, mathutils
from PIL import Image

TEST = "--test" in sys.argv
GLB_IN = os.path.abspath("meshy_in/vortex/rigged.glb")
GUN_GLB = os.path.abspath("meshy_in/w_gauss_rifle/model.glb")   # the arm-cannon (patron picked GAUSS)
OUT_DIR = os.path.abspath("game/assets/mecha")
PREVIEW_DIR = os.path.abspath("meshy_in/previews")
CHASSIS = "vortex"
RES = 256
FRAMES = 8
SAMPLES = 14 if TEST else 16
EL = 40.0
# --- arm-cannon placement (tunable) ---
GUN_LEN = 0.42        # cannon length as fraction of forearm-bone... set relative to mech below
GUN_ALONG = 0.02      # slide along the forearm (+ = toward muzzle) in bone-lengths
GUN_UP = 0.0          # perpendicular offset (bone local Z)
GUN_SIDE = 0.0        # perpendicular offset (bone local X)
GUN_SCALE_FRAC = 0.46 # cannon world length = this * mech height (chunky -> reads as an arm-cannon)

os.makedirs(PREVIEW_DIR, exist_ok=True)


def bbox(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    mn = mathutils.Vector((1e9, 1e9, 1e9)); mx = -mn
    for o in objs:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            w = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i]); mx[i] = max(mx[i], w[i])
    return mn, mx


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB_IN)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = RES; sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.08, 0.09, 0.13, 1.0); bg.inputs["Strength"].default_value = 0.45

    def sun(name, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(name, type="SUN"); d.energy = e; d.color = col; d.angle = math.radians(5)
        o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
    sun("key", 4.5, (52, 8, -34), (1.0, 0.95, 0.88)); sun("fill", 1.8, (66, -6, 46), (0.75, 0.85, 1.0))
    sun("rim", 4.0, (-38, 0, 160), (0.7, 0.95, 1.0))
    return sc


def get_armature():
    return [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]


def _mesh_bounds(gun):
    vs = [v.co for v in gun.data.vertices]
    mn = mathutils.Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = mathutils.Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return mn, mx, vs


def import_gun(sc, mech_h):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=GUN_GLB)
    gobjs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in gobjs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = gobjs[0]
    if len(gobjs) > 1:
        bpy.ops.object.join()
    gun = bpy.context.view_layer.objects.active
    # bake the import transform into the mesh data -> object transform becomes identity
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    M = gun.matrix_world.copy()
    for v in gun.data.vertices:
        v.co = M @ v.co
    gun.matrix_world = mathutils.Matrix.Identity(4)
    # orient longest axis (barrel) -> +Y
    mn, mx, _ = _mesh_bounds(gun); dim = mx - mn
    axis = max(range(3), key=lambda i: dim[i])
    if axis == 0:
        gun.data.transform(mathutils.Matrix.Rotation(math.radians(90), 4, "Z"))    # X->Y
    elif axis == 2:
        gun.data.transform(mathutils.Matrix.Rotation(math.radians(-90), 4, "X"))   # Z->Y
    # scale so length (Y) = GUN_SCALE_FRAC * mech height
    mn, mx, _ = _mesh_bounds(gun); dim = mx - mn
    gun.data.transform(mathutils.Matrix.Scale((GUN_SCALE_FRAC * mech_h) / max(dim.y, 1e-3), 4))
    # thin end (muzzle) must be at +Y: compare X/Z extent of the two halves; flip if muzzle at -Y
    mn, mx, vs = _mesh_bounds(gun); midy = (mn.y + mx.y) * 0.5
    def thick(pos):
        sel = [v for v in vs if (v.y > midy) == pos]
        if not sel:
            return 0.0
        return (max(v.x for v in sel) - min(v.x for v in sel)) + (max(v.z for v in sel) - min(v.z for v in sel))
    if thick(True) > thick(False):
        gun.data.transform(mathutils.Matrix.Rotation(math.radians(180), 4, "Z"))
    # breech (-Y end) to origin, centred in X/Z
    mn, mx, _ = _mesh_bounds(gun)
    gun.data.transform(mathutils.Matrix.Translation((-(mn.x + mx.x) * 0.5, -mn.y, -(mn.z + mx.z) * 0.5)))
    return gun


def place_gun(arm, gun, mech_h):
    # ARM-CANNON: mount along the FOREARM (elbow->wrist) so the cannon body sheathes the forearm and the
    # barrel extends past where the hand was -> the arm IS the weapon, not a hand holding a gun. Decompose
    # the forearm world matrix to position+rotation ONLY (the Meshy rig carries a huge armature scale that
    # would otherwise fling/shrink the gun). +Y of the forearm bone points to the wrist = the barrel axis.
    pb = arm.pose.bones
    bmat = arm.matrix_world @ pb["RightForeArm"].matrix
    loc, rot, _ = bmat.decompose()
    place = mathutils.Matrix.Translation(loc) @ rot.to_matrix().to_4x4()
    off = mathutils.Matrix.Translation((GUN_SIDE, -0.10 * mech_h + GUN_ALONG, GUN_UP))  # pull breech to the elbow
    gun.matrix_world = place @ off


# --- poser functions (copied from build_vortex_anims) ---
def R(d):
    return math.radians(d)


def guard(arm):
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    if "Spine" in pb: pb["Spine"].rotation_euler.x = R(-4)
    if "Spine01" in pb: pb["Spine01"].rotation_euler.x = R(2)
    if "Spine02" in pb: pb["Spine02"].rotation_euler.x = R(2)
    if "LeftArm" in pb: pb["LeftArm"].rotation_euler = (R(-28), R(16), R(-12))
    if "RightArm" in pb: pb["RightArm"].rotation_euler = (R(-30), R(-14), R(10))
    if "LeftForeArm" in pb: pb["LeftForeArm"].rotation_euler = (R(-52), R(8), 0)
    if "RightForeArm" in pb: pb["RightForeArm"].rotation_euler = (R(-46), R(-8), 0)


def reset(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)


def pose_idle(arm, f, n):
    reset(arm); guard(arm); pb = arm.pose.bones; p = 2 * math.pi * f / n
    if "Hips" in pb:
        pb["Hips"].location.z = 0.014 * math.sin(p); pb["Hips"].rotation_euler.z = 0.015 * math.sin(p)


def _legs(arm, p, amp_pitch, amp_knee):
    pb = arm.pose.bones
    for side, ph in (("Left", 0.0), ("Right", math.pi)):
        pit = R(amp_pitch) * math.sin(p + ph)
        kn = R(amp_knee) * max(0.0, -math.sin(p + ph - 0.25))
        if side + "UpLeg" in pb: pb[side + "UpLeg"].rotation_euler.x = pit
        if side + "Leg" in pb: pb[side + "Leg"].rotation_euler.x = kn
        if side + "Foot" in pb: pb[side + "Foot"].rotation_euler.x = -pit * 0.6


def aim_arm(pb):
    # RIGHT arm thrust FORWARD so the arm-cannon points straight ahead (at the target), matching the
    # attack pose the muzzle anchors were measured from. Used by walk/run so the cannon never reads as
    # "pointing to the side" (the old raised-guard pose) while run-and-gunning.
    if "RightArm" in pb: pb["RightArm"].rotation_euler = (R(-70), R(-6), R(4))
    if "RightForeArm" in pb: pb["RightForeArm"].rotation_euler = (R(-16), 0, 0)
    if "Spine" in pb: pb["Spine"].rotation_euler.x = R(-6)


def pose_walk(arm, f, n):
    reset(arm); guard(arm); pb = arm.pose.bones; p = 2 * math.pi * f / n
    if "Hips" in pb:
        pb["Hips"].location.z = -0.04 * abs(math.sin(p)) + 0.018; pb["Hips"].rotation_euler.z = 0.024 * math.sin(p)
    _legs(arm, p, 28, 45)
    aim_arm(pb)


def pose_run(arm, f, n):
    reset(arm); guard(arm); pb = arm.pose.bones; p = 2 * math.pi * f / n
    if "Hips" in pb:
        pb["Hips"].location.z = -0.06 * abs(math.sin(p)); pb["Hips"].rotation_euler.x = R(6); pb["Hips"].rotation_euler.z = 0.032 * math.sin(p)
    if "Spine" in pb: pb["Spine"].rotation_euler.x = R(-6)
    _legs(arm, p, 40, 58)
    aim_arm(pb)


def pose_attack(arm, f, n):
    reset(arm); pb = arm.pose.bones
    for b in pb: b.rotation_mode = "XYZ"
    if "Spine" in pb: pb["Spine"].rotation_euler.x = R(-6)
    # right arm THRUST FORWARD (the cannon aims), left arm braces
    if "RightArm" in pb: pb["RightArm"].rotation_euler = (R(-70), R(-6), R(4))
    if "RightForeArm" in pb: pb["RightForeArm"].rotation_euler = (R(-16), 0, 0)
    if "LeftArm" in pb: pb["LeftArm"].rotation_euler = (R(-30), R(14), R(-10))
    if "LeftForeArm" in pb: pb["LeftForeArm"].rotation_euler = (R(-52), 0, 0)
    rec = R(10) * max(0.0, math.sin(2 * math.pi * f / n))
    if "RightArm" in pb: pb["RightArm"].rotation_euler.x += rec


def pose_hit(arm, f, n):
    reset(arm); guard(arm); pb = arm.pose.bones; t = f / n
    fl = R(-22) * (t / 0.3 if t < 0.3 else max(0.0, 1 - (t - 0.3) / 0.7))
    if "Spine" in pb: pb["Spine"].rotation_euler.x += fl * 0.5
    if "Spine02" in pb: pb["Spine02"].rotation_euler.x += fl * 0.5


def pose_die(arm, f, n):
    reset(arm); guard(arm); pb = arm.pose.bones; p = min(1.0, (f / n) / 0.85)
    if "Hips" in pb: pb["Hips"].location.z = -0.18 * p; pb["Hips"].rotation_euler.x = R(-10) * p
    for s in ("Left", "Right"):
        if s + "Leg" in pb: pb[s + "Leg"].rotation_euler.x = R(55) * p
    if "Spine" in pb: pb["Spine"].rotation_euler.x += R(-42) * 0.5 * p


def pose_melee(arm, f, n):
    reset(arm); guard(arm); pb = arm.pose.bones; t = f / n
    sw = R(-35) + R(120) * min(1.0, t / 0.6)
    if "RightArm" in pb: pb["RightArm"].rotation_euler = (R(40), 0, -sw)
    if "RightForeArm" in pb: pb["RightForeArm"].rotation_euler.x = R(65)
    if "Hips" in pb: pb["Hips"].rotation_euler.z = -sw * 0.3


POSERS = {"idle": pose_idle, "walk": pose_walk, "run": pose_run, "attack": pose_attack,
          "hit": pose_hit, "die": pose_die, "melee": pose_melee}


def main():
    sc = setup_scene()
    arm = get_armature()
    mech = [o for o in sc.objects if o.type == "MESH"]
    pose_idle(arm, 0, FRAMES); bpy.context.view_layer.update()
    mmn, mmx = bbox(mech); mech_h = mmx.z - mmn.z
    gun = import_gun(sc, mech_h)
    # camera framed on the mech (idle f0), a touch wider for the cannon
    center0 = (mmn + mmx) * 0.5
    size = max((mmx - mmn).x, (mmx - mmn).y, (mmx - mmn).z, 1e-3)
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.22
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    e = math.radians(EL); dist = size * 4.0

    def aim(center, az):
        a = math.radians(az)
        cam.location = (center.x + dist * math.cos(e) * math.sin(a),
                        center.y - dist * math.cos(e) * math.cos(a), center.z + dist * math.sin(e))
        cam.rotation_euler = (center - mathutils.Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()

    tmp = os.path.join(PREVIEW_DIR, "_tmp_vgun.png")
    DIRS = [("front", 0), ("right", -90)] if TEST else [("front", 0), ("back", 180), ("left", 90), ("right", -90)]
    anims = ["attack"] if TEST else list(POSERS.keys())
    if "--anims" in sys.argv:                       # re-bake only the listed anims (e.g. walk,run)
        anims = sys.argv[sys.argv.index("--anims") + 1].split(",")

    for aname in anims:
        poser = POSERS[aname]
        for dname, az in DIRS:
            tiles = []
            for f in range(FRAMES):
                poser(arm, f, FRAMES)
                bpy.context.view_layer.update()
                place_gun(arm, gun, mech_h)
                bpy.context.view_layer.update()
                mn, mx = bbox(mech); cen = (mn + mx) * 0.5; cen.z = center0.z
                aim(cen, az)
                sc.render.filepath = tmp
                bpy.ops.render.render(write_still=True)
                tiles.append(Image.open(tmp).convert("RGBA").copy())
            if TEST:
                bg = Image.new("RGB", tiles[3].size, (30, 33, 42)); bg.paste(tiles[3], (0, 0), tiles[3])
                bg.save(os.path.abspath("cine/_show/vortex_gun_%s.png" % dname))
                print("TEST attack", dname, "-> cine/_show/vortex_gun_%s.png" % dname)
                continue
            sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
            for k, im in enumerate(tiles):
                sheet.paste(im, (RES * k, 0), im)
            sheet.save(os.path.join(OUT_DIR, "%s_%s_%s.png" % (CHASSIS, aname, dname)))
            f0 = sheet.crop((0, 0, RES, RES)).getbbox()
            print("BAKED %s_%s : %dpx" % (aname, dname, (f0[3] - f0[1]) if f0 else 0))
    print("DONE")


main()
