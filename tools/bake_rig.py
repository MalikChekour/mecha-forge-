#!/usr/bin/env python3
"""
mecha-forge — build a HEURISTIC skeleton on a static (un-rigged) humanoid GLB,
skin it (automatic weights), keyframe an articulated cycle (walk / attack), and
bake N frames to a spritesheet. For mech enemies Meshy could not auto-rig
(credits depleted / non-standard proportions). Reuses the proven bake_proc
render + camera + tiling; the ONLY new part is the procedural biped rig.

  python bake_rig.py <in.glb> <out_sheet.png> <cycle> [opts]
    cycle = walk | attack
  opts:
    --frames 8 --res 220 --el 40 --samples 22 --yaw 0
    --legamp 32 --kneeamp 46 --armamp 26 --bob 0.05   (degrees / frac of height)
    --swingaxis x     (world axis the limbs swing fwd/back about: x|y)
    --hipfrac 0.52 --kneefrac 0.26 --shoulderfrac 0.82 --elbowfrac 0.62
    --legsep 0.12 --armsep 0.26

Standing humanoid is Z-up after glTF import; it faces -Y (toward the camera).
Legs/arms swing fwd/back = rotation about world X. Amplitudes are generous
because at sprite scale subtle limb motion is invisible.
"""
import bpy, sys, os, math, mathutils
from PIL import Image


def argval(flag, default, cast=float):
    a = sys.argv
    return cast(a[a.index(flag) + 1]) if flag in a else default


GLB = os.path.abspath(sys.argv[1])
OUT = os.path.abspath(sys.argv[2])
CYCLE = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith("--") else "walk"
FRAMES = int(argval("--frames", 8))
RES = int(argval("--res", 220))
EL = argval("--el", 40.0)
YAW = argval("--yaw", 0.0)
SAMPLES = int(argval("--samples", 22))
LEGAMP = math.radians(argval("--legamp", 50.0))
KNEEAMP = math.radians(argval("--kneeamp", 70.0))
ARMAMP = math.radians(argval("--armamp", 40.0))
BOB = argval("--bob", 0.075)
AXIS = "x" if argval("--swingaxis", "x", str) == "x" else "y"
HIPF = argval("--hipfrac", 0.52)
KNEEF = argval("--kneefrac", 0.24)
SHF = argval("--shoulderfrac", 0.82)
ELF = argval("--elbowfrac", 0.60)
LEGSEP = argval("--legsep", 0.19)     # leg centres measured at ~0.20W on the raider mesh
ARMSEP = argval("--armsep", 0.30)
WEAPON = argval("--weapon", "none", str)   # none | sword (melee) | gun (ranged)
TMP = os.path.join(os.path.dirname(OUT) or ".", "_rigframe.png")
TAU = math.pi * 2


def bounds(objs, evaluated=False):
    mn = mathutils.Vector((1e9, 1e9, 1e9)); mx = -mn
    dg = bpy.context.evaluated_depsgraph_get() if evaluated else None
    for o in objs:
        oe = o.evaluated_get(dg) if evaluated else o
        for c in oe.bound_box:
            w = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i]); mx[i] = max(mx[i], w[i])
    return mn, mx


def swing(pb, ang):
    """Swing a bone fwd/back about the chosen world axis (added to current euler)."""
    if AXIS == "x":
        pb.rotation_euler.x += ang
    else:
        pb.rotation_euler.y += ang


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    if YAW:
        for o in bpy.context.scene.objects:
            if o.parent is None:
                o.rotation_euler.z += math.radians(YAW)
    sc = bpy.context.scene

    # --- join all meshes into one so automatic weights sees a single skin ---
    meshes = [o for o in sc.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no mesh in GLB")
    for o in sc.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:
        o.select_set(True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    mesh = bpy.context.view_layer.objects.active
    # bake object transform into the mesh so bone coords live in world space
    mesh.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    mn, mx = bounds([mesh])
    cx = (mn.x + mx.x) * 0.5
    cy = (mn.y + mx.y) * 0.5
    z0 = mn.z
    H = max(mx.z - mn.z, 1e-3)
    W = max(mx.x - mn.x, 1e-3)

    def P(xf, zf, yoff=0.0):
        return mathutils.Vector((cx + xf * W, cy + yoff, z0 + zf * H))

    # --- build the heuristic biped armature (edit bones) ---
    arm_data = bpy.data.armatures.new("rig")
    arm = bpy.data.objects.new("rig", arm_data)
    sc.collection.objects.link(arm)
    for o in sc.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def mk(name, head, tail, parent=None):
        b = eb.new(name); b.head = head; b.tail = tail
        if parent is not None:
            b.parent = parent
        return b

    pelvis = mk("pelvis", P(0.0, HIPF), P(0.0, HIPF + 0.08))
    spine = mk("spine", P(0.0, HIPF + 0.08), P(0.0, SHF), pelvis)
    mk("head", P(0.0, SHF), P(0.0, 0.99), spine)
    for s, sign in (("L", 1.0), ("R", -1.0)):
        th = mk("thigh." + s, P(sign * LEGSEP * 0.9, HIPF - 0.02),
                P(sign * LEGSEP, KNEEF), pelvis)
        mk("shin." + s, P(sign * LEGSEP, KNEEF), P(sign * LEGSEP, 0.02), th)
        ua = mk("uparm." + s, P(sign * ARMSEP * 0.78, SHF - 0.01),
                P(sign * ARMSEP, ELF), spine)
        mk("forearm." + s, P(sign * ARMSEP, ELF), P(sign * (ARMSEP + 0.03), HIPF), ua)
    bpy.ops.object.mode_set(mode="OBJECT")

    # --- optional held weapon: a glowing blade (melee) or a rifle (ranged), welded
    #     to the mesh at the right hand and weighted 100% to forearm.R so it swings
    #     with the arm. Its verts get appended last, so we tag them by index below. ---
    wpn_start = len(mesh.data.vertices)
    if WEAPON in ("sword", "gun"):
        hand = mathutils.Vector((cx - (ARMSEP + 0.03) * W, cy, z0 + HIPF * H))
        col = (0.15, 0.9, 1.0) if WEAPON == "sword" else (1.0, 0.5, 0.12)
        wm = bpy.data.materials.new("wpn"); wm.use_nodes = True
        bsdf = wm.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (col[0] * 0.4, col[1] * 0.4, col[2] * 0.4, 1.0)
        bsdf.inputs["Metallic"].default_value = 0.8
        bsdf.inputs["Roughness"].default_value = 0.3
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (col[0], col[1], col[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = 1.8
        if WEAPON == "sword":
            boxes = [(mathutils.Vector((hand.x, hand.y - 0.02 * W, hand.z - 0.26 * H)),
                      (0.055 * W, 0.028 * W, 0.58 * H)),     # blade, points down (vertical read)
                     (mathutils.Vector((hand.x, hand.y, hand.z + 0.01 * H)),
                      (0.15 * W, 0.04 * W, 0.035 * H))]      # crossguard
        else:
            # rifle held ACROSS, barrel out to the side (reads horizontal, unlike the
            # vertical sword) with a bright muzzle block at the far end.
            boxes = [(mathutils.Vector((hand.x - 0.14 * W, hand.y - 0.06 * H, hand.z)),
                      (0.34 * W, 0.06 * H, 0.06 * W)),       # rifle body (extends in X)
                     (mathutils.Vector((hand.x - 0.30 * W, hand.y - 0.06 * H, hand.z)),
                      (0.07 * W, 0.05 * H, 0.10 * W))]       # muzzle
        wobjs = []
        for bi, (c, dims) in enumerate(boxes):
            hx, hy, hz = dims[0] * 0.5, dims[1] * 0.5, dims[2] * 0.5
            vs = [(c.x - hx, c.y - hy, c.z - hz), (c.x + hx, c.y - hy, c.z - hz),
                  (c.x + hx, c.y + hy, c.z - hz), (c.x - hx, c.y + hy, c.z - hz),
                  (c.x - hx, c.y - hy, c.z + hz), (c.x + hx, c.y - hy, c.z + hz),
                  (c.x + hx, c.y + hy, c.z + hz), (c.x - hx, c.y + hy, c.z + hz)]
            fs = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1),
                  (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
            md = bpy.data.meshes.new("wpn%d" % bi); md.from_pydata(vs, [], fs); md.update()
            md.materials.append(wm)
            wobjs.append(bpy.data.objects.new("wpn%d" % bi, md))
            sc.collection.objects.link(wobjs[-1])
        for o in sc.objects:
            o.select_set(False)
        mesh.select_set(True)
        for o in wobjs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = mesh
        bpy.ops.object.join()

    # --- skin: EXPLICIT region weights (heat weighting is unreliable on
    #     hard-surface mech meshes with separated armour plates, so we bind
    #     each vertex to the anatomically-correct bone by its position, then
    #     smooth a few iterations so the joints don't tear). ---
    def bone_for(xr, zr):
        side = "L" if xr < 0.0 else "R"
        ax = abs(xr)
        if zr >= 0.85 and ax < 0.16:
            return "head"
        if ax > 0.24 and zr >= 0.52:                    # arms hang at the sides
            return ("uparm." + side) if zr >= 0.68 else ("forearm." + side)
        if zr < 0.48:                                   # lower body = legs...
            if ax < 0.10 and zr > 0.42:                 # ...except the central groin
                return "pelvis"
            return ("shin." + side) if zr < 0.24 else ("thigh." + side)
        return "spine" if zr >= 0.63 else "pelvis"      # torso

    groups = {}
    for b in arm_data.bones:
        groups[b.name] = mesh.vertex_groups.new(name=b.name)
    for v in mesh.data.vertices:
        if v.index >= wpn_start:                     # held weapon -> rides the right forearm
            groups["forearm.R"].add([v.index], 1.0, "REPLACE")
            continue
        xr = (v.co.x - cx) / W
        zr = (v.co.z - z0) / H
        groups[bone_for(xr, zr)].add([v.index], 1.0, "REPLACE")

    for o in sc.objects:
        o.select_set(False)
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_NAME")     # modifier only, keep our groups
    # blend the hard region seams so limb joints deform smoothly (needs the
    # mesh solely selected + active; guarded because the op polls the 3D ctx)
    for o in sc.objects:
        o.select_set(False)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    try:
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
        bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=6)
        bpy.ops.object.mode_set(mode="OBJECT")
    except RuntimeError as ex:
        print("SMOOTH skipped:", ex)
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"

    # --- render setup (identical recipe to bake_proc / bake_anim) ---
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = RES; sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bgn = w.node_tree.nodes.get("Background")
    bgn.inputs["Color"].default_value = (0.08, 0.09, 0.13, 1.0)
    bgn.inputs["Strength"].default_value = 0.45

    def sun(nm, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(nm, type="SUN"); d.energy = e; d.color = col
        d.angle = math.radians(5)
        ob = bpy.data.objects.new(nm, d); sc.collection.objects.link(ob)
        ob.rotation_euler = tuple(math.radians(a) for a in rot)
    sun("key", 4.2, (52, 8, -34), (1.0, 0.97, 0.9))
    sun("fill", 1.4, (66, -6, 46), (0.75, 0.85, 1.0))
    sun("rim", 4.0, (-38, 0, 160), (0.7, 0.95, 1.0))

    center = mathutils.Vector((cx, cy, z0 + H * 0.5))
    size = max(W, mx.y - mn.y, H, 1e-3)
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.35
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    e = math.radians(EL); dist = size * 4.0

    def aim(az):
        a = math.radians(az)
        cam.location = (center.x + dist * math.cos(e) * math.sin(a),
                        center.y - dist * math.cos(e) * math.cos(a),
                        center.z + dist * math.sin(e))
        look = center - mathutils.Vector(cam.location)
        cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

    pb = arm.pose.bones

    def reset():
        for b in pb:
            b.rotation_euler = (0.0, 0.0, 0.0)
            b.location = (0.0, 0.0, 0.0)

    def pose_walk(t):
        ph = TAU * t
        # legs alternate; arms counter-swing the opposite leg
        swing(pb["thigh.L"], LEGAMP * math.sin(ph))
        swing(pb["thigh.R"], LEGAMP * math.sin(ph + math.pi))
        # knee bends on the back/lift half of each leg's stride (always flexes one way)
        pb["shin.L"].rotation_euler.x += -KNEEAMP * max(0.0, math.sin(ph + 0.6))
        pb["shin.R"].rotation_euler.x += -KNEEAMP * max(0.0, math.sin(ph + math.pi + 0.6))
        swing(pb["uparm.L"], -ARMAMP * math.sin(ph))
        swing(pb["uparm.R"], -ARMAMP * math.sin(ph + math.pi))
        pb["forearm.L"].rotation_euler.x += math.radians(18)
        pb["forearm.R"].rotation_euler.x += math.radians(18)
        # body bob (two per cycle, one per footfall) + subtle weight-shift roll & yaw
        pb["pelvis"].location.y += BOB * H * abs(math.sin(ph))
        pb["pelvis"].rotation_euler.y += math.radians(4.0) * math.sin(ph)
        pb["spine"].rotation_euler.z += math.radians(5.0) * math.sin(ph)

    def pose_attack(t):
        # wind-up then strike with the right arm; step in
        s = math.sin(math.pi * t)          # 0..1..0 over the clip
        pb["uparm.R"].rotation_euler.x += -math.radians(70) * s
        pb["forearm.R"].rotation_euler.x += math.radians(40) * s
        pb["uparm.L"].rotation_euler.x += math.radians(25) * s
        swing(pb["thigh.R"], math.radians(18) * s)
        pb["spine"].rotation_euler.z += math.radians(22) * s
        pb["pelvis"].location.y += 0.03 * H * s

    poser = pose_attack if CYCLE == "attack" else pose_walk

    DIRS = {1: [("", 0.0)],
            4: [("_front", 0.0), ("_back", 180.0), ("_left", 90.0), ("_right", -90.0)]}
    ndirs = int(argval("--dirs", 1))
    stem, ext = os.path.splitext(OUT)
    for suffix, az in DIRS.get(ndirs, DIRS[1]):
        aim(az)
        tiles = []
        for i in range(FRAMES):
            reset()
            poser(i / FRAMES)
            bpy.context.view_layer.update()
            sc.render.filepath = TMP
            bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(TMP).convert("RGBA").copy())
        sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
        for k, im in enumerate(tiles):
            sheet.paste(im, (RES * k, 0), im)
        sheet.save(stem + suffix + ext)
    if os.path.exists(TMP):
        os.remove(TMP)
    print("RIG", CYCLE, OUT, "dirs", ndirs, "%dx%d" % (RES * FRAMES, RES), FRAMES, "frames", "axis", AXIS)


if __name__ == "__main__":
    main()
