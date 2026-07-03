#!/usr/bin/env python3
"""
mecha-forge — hard-surface mecha PART renderer v3 (headless bpy, Cycles CPU, no GPU).

v3 = CUSTOMIZATION PROOF: the builder is parameterized by a CHASSIS SPEC and
renders each chassis into its own assets/mecha/<id>/ folder with its own
rig.json (anchors + per-chassis animation constants). Weapons are shared,
chassis-independent hardpoints in assets/weapons/.

Chassis:
- vanguard : the blue/steel hero — balanced proportions, crest head.
- titan    : heavy weight class — wider torso, short legs, bunker head,
             olive/bronze armor, ORANGE core; slower/heavier gait constants.

Weapons (all built around the frame center, barrel pointing +X):
- autocannon  : rotary barrel cluster + muzzle ring
- missilepod  : boxy pod, 6 tubes with hot orange tips
- railgun     : twin rails + emissive accelerator coils (long reach)
- plasmacaster: fork prongs cradling a hot plasma orb

Everything renders from ONE shared ortho camera so layers stack pixel-aligned.

Usage:
  python build_mecha.py                    # render both chassis + all weapons
  python build_mecha.py vanguard           # one chassis only
  python build_mecha.py --preview titan    # single composite look-dev render
"""
import bpy, os, sys, json, math, mathutils
from bpy_extras.object_utils import world_to_camera_view

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MECHA = os.path.join(ROOT, "game", "assets", "mecha")
WEAP = os.path.join(ROOT, "game", "assets", "weapons")
DOCS = os.path.join(ROOT, "docs")

RES = 384
SAMPLES = 48
CAM_EL = 40.0
CAM_TARGET = mathutils.Vector((0.0, 0.0, 1.20))
ORTHO = 3.65

TRIM = (0.72, 0.76, 0.85)
CYAN = (0.20, 0.90, 1.00)
ORANGE = (1.00, 0.42, 0.10)

# ---- shared gait model; per-chassis overrides tune the weight class ----
ANIM_BASE = {
    "step_freq": 1.0, "thigh_rot": 0.10, "shin_rot": 0.22,
    "lift_thigh": 0.020, "lift_shin": 0.024, "stride": 0.014, "squash": 0.055,
    "bob": 0.020, "lat": 0.010, "rock": 0.045, "head_bob": 0.008,
    "core_pulse_hz": 1.2, "recoil": 0.06, "recoil_rock": 0.05,
}

CHASSIS_SPECS = {
    "vanguard": {
        "pal": {
            "primary": (0.42, 0.50, 0.64), "primary_dk": (0.22, 0.27, 0.38),
            "joint": (0.045, 0.050, 0.065), "gun": (0.15, 0.16, 0.21),
            "glow": CYAN, "core_hot": (0.85, 1.0, 1.0),
        },
        "hip_z": 1.14, "knee_z": 0.62, "leg_x": 0.36, "tw": 1.0,
        "head": "crest", "anim": {},
    },
    "titan": {
        "pal": {
            "primary": (0.46, 0.44, 0.30), "primary_dk": (0.27, 0.25, 0.17),
            "joint": (0.050, 0.046, 0.040), "gun": (0.17, 0.15, 0.12),
            "glow": ORANGE, "core_hot": (1.0, 0.85, 0.6),
        },
        "hip_z": 0.98, "knee_z": 0.54, "leg_x": 0.44, "tw": 1.18,
        "head": "bunker",
        "anim": {"step_freq": 0.82, "bob": 0.025, "rock": 0.055, "lift_shin": 0.020},
    },
}

part_objs = {}


def _edge_wear_metal(name, color, rough=0.42, metal=1.0, wear=0.55):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if wear <= 0.0:
        return m
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    bev = nt.nodes.new("ShaderNodeBevel"); bev.samples = 4
    bev.inputs["Radius"].default_value = 0.015
    dot = nt.nodes.new("ShaderNodeVectorMath"); dot.operation = 'DOT_PRODUCT'
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    nt.links.new(bev.outputs["Normal"], dot.inputs[1])
    inv = nt.nodes.new("ShaderNodeMath"); inv.operation = 'SUBTRACT'
    inv.inputs[0].default_value = 1.0
    nt.links.new(dot.outputs["Value"], inv.inputs[1])
    amp = nt.nodes.new("ShaderNodeMath"); amp.operation = 'MULTIPLY'
    amp.inputs[1].default_value = 14.0 * wear
    nt.links.new(inv.outputs["Value"], amp.inputs[0])
    clamp = nt.nodes.new("ShaderNodeClamp")
    nt.links.new(amp.outputs["Value"], clamp.inputs["Value"])
    mixc = nt.nodes.new("ShaderNodeMix"); mixc.data_type = 'RGBA'
    mixc.inputs["A"].default_value = (*color, 1.0)
    mixc.inputs["B"].default_value = (*TRIM, 1.0)
    nt.links.new(clamp.outputs["Result"], mixc.inputs["Factor"])
    nt.links.new(mixc.outputs["Result"], b.inputs["Base Color"])
    noise = nt.nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 9.0
    rmap = nt.nodes.new("ShaderNodeMapRange")
    rmap.inputs["To Min"].default_value = max(0.05, rough - 0.12)
    rmap.inputs["To Max"].default_value = min(0.95, rough + 0.12)
    nt.links.new(noise.outputs["Fac"], rmap.inputs["Value"])
    nt.links.new(rmap.outputs["Result"], b.inputs["Roughness"])
    return m


def _mat_emit(name, color, strength=7.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1.0)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def box(part, size, loc, rot=(0, 0, 0), mat=None, bevel=0.045):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = tuple(math.radians(a) for a in rot)
    if bevel > 0:
        bm = o.modifiers.new("bev", 'BEVEL'); bm.width = bevel; bm.segments = 2
    if mat:
        o.data.materials.append(mat)
    part_objs.setdefault(part, []).append(o)
    return o


def cyl(part, r, depth, loc, rot=(0, 0, 0), mat=None, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts, location=loc)
    o = bpy.context.active_object
    o.rotation_euler = tuple(math.radians(a) for a in rot)
    bpy.ops.object.shade_smooth()
    if mat:
        o.data.materials.append(mat)
    part_objs.setdefault(part, []).append(o)
    return o


def sph(part, r, loc, mat=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=20, ring_count=12)
    o = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    if mat:
        o.data.materials.append(mat)
    part_objs.setdefault(part, []).append(o)
    return o


def build_chassis(spec):
    """Build one chassis as separate rigid part layers. Returns its anchor dict."""
    pal = spec["pal"]
    tw = spec["tw"]
    dz = spec["hip_z"] - 1.14           # vertical shift vs the vanguard reference
    lx = spec["leg_x"]

    primary = _edge_wear_metal("primary", pal["primary"], rough=0.40)
    primary_dk = _edge_wear_metal("primary_dk", pal["primary_dk"], rough=0.46)
    joint = _edge_wear_metal("joint", pal["joint"], rough=0.85, metal=0.0, wear=0.0)
    trim = _edge_wear_metal("trim", TRIM, rough=0.22, wear=0.0)
    gun = _edge_wear_metal("gun", pal["gun"], rough=0.48, wear=0.35)
    core_hot = _mat_emit("core_hot", pal["core_hot"], 16.0)
    core_halo = _mat_emit("core_halo", pal["glow"], 10.0)
    visor_e = _mat_emit("visor_e", pal["glow"], 10.0)
    sensor_e = _mat_emit("sensor_e", pal["glow"], 6.0)

    def Z(z):
        return z + dz

    # ---- TORSO ----
    box("torso", (1.04 * tw, 0.60, 0.72), (0, 0, Z(1.50)), mat=primary)
    box("torso", (0.52 * tw, 0.44, 0.16), (0, 0, Z(1.14)), mat=joint, bevel=0.02)
    box("torso", (0.78 * tw, 0.54, 0.24), (0, -0.02, Z(1.00)), mat=primary_dk)
    box("torso", (0.72 * tw, 0.46, 0.13), (0, 0.02, Z(1.90)), mat=primary_dk)
    box("torso", (0.40, 0.10, 0.34), (0, -0.325, Z(1.50)), mat=trim, bevel=0.02)
    for sx in (-0.30 * tw, 0.30 * tw):
        box("torso", (0.05, 0.045, 0.52), (sx, -0.305, Z(1.50)), mat=gun, bevel=0.01)
    box("torso", (0.30, 0.40, 0.38), (-0.58 * tw, 0, Z(1.72)), mat=joint, bevel=0.02)
    box("torso", (0.30, 0.40, 0.38), (0.58 * tw, 0, Z(1.72)), mat=joint, bevel=0.02)
    box("torso", (0.44, 0.50, 0.36), (-0.80 * tw, 0, Z(1.86)), rot=(0, -12, 0), mat=primary)
    for k in range(3):
        box("torso", (0.30, 0.07, 0.035), (-0.80 * tw, -0.14 + 0.14 * k, Z(2.035)), rot=(0, -12, 0), mat=gun, bevel=0.008)
    box("torso", (0.50, 0.56, 0.44), (0.82 * tw, 0, Z(1.88)), rot=(0, 14, 0), mat=primary)
    box("torso", (0.52, 0.12, 0.07), (0.82 * tw, -0.24, Z(2.07)), rot=(0, 14, 0), mat=trim, bevel=0.015)
    cyl("torso", 0.045, 0.03, (0.70 * tw, -0.285, Z(1.80)), rot=(90, 0, 0), mat=sensor_e)
    box("torso", (0.56 * tw, 0.30, 0.48), (0, 0.42, Z(1.60)), mat=gun)
    cyl("torso", 0.09, 0.30, (-0.20 * tw, 0.60, Z(1.80)), rot=(90, 0, 0), mat=trim)
    cyl("torso", 0.09, 0.30, (0.20 * tw, 0.60, Z(1.80)), rot=(90, 0, 0), mat=trim)

    # ---- CORE ----
    cyl("core", 0.16, 0.05, (0, -0.345, Z(1.50)), rot=(90, 0, 0), mat=core_halo)
    cyl("core", 0.085, 0.08, (0, -0.360, Z(1.50)), rot=(90, 0, 0), mat=core_hot)

    # ---- HEAD (style per chassis) ----
    if spec["head"] == "crest":
        box("head", (0.34, 0.36, 0.26), (0, -0.06, Z(2.14)), mat=primary)
        box("head", (0.28, 0.10, 0.11), (0, -0.26, Z(2.14)), mat=visor_e, bevel=0.01)
        box("head", (0.05, 0.24, 0.34), (-0.10, 0.04, Z(2.34)), rot=(-10, 0, 0), mat=primary_dk)
        box("head", (0.05, 0.24, 0.34), (0.10, 0.04, Z(2.34)), rot=(-10, 0, 0), mat=primary_dk)
        cyl("head", 0.015, 0.30, (0.20, 0.05, Z(2.36)), mat=trim, verts=10)
    else:  # bunker: low, wide, slit visor, side intakes
        box("head", (0.46, 0.42, 0.20), (0, -0.04, Z(2.10)), mat=primary)
        box("head", (0.36, 0.10, 0.055), (0, -0.26, Z(2.10)), mat=visor_e, bevel=0.008)
        box("head", (0.10, 0.28, 0.14), (-0.30, 0.02, Z(2.10)), mat=gun, bevel=0.015)
        box("head", (0.10, 0.28, 0.14), (0.30, 0.02, Z(2.10)), mat=gun, bevel=0.015)
        box("head", (0.30, 0.24, 0.06), (0, 0.06, Z(2.235)), mat=primary_dk)

    # ---- LEGS ----
    knee_guard_z = spec["knee_z"] + 0.02
    thigh_c = (spec["hip_z"] + spec["knee_z"]) / 2.0 - 0.02
    thigh_h = spec["hip_z"] - spec["knee_z"] + 0.10
    shin_c = (spec["knee_z"] + 0.16) / 2.0
    shin_h = spec["knee_z"] - 0.16 + 0.14
    for side, sx in (("left", -lx), ("right", lx)):
        t = "thigh_%s" % side
        cyl(t, 0.105, 0.30, (sx, 0.0, spec["hip_z"]), rot=(0, 90, 0), mat=joint)
        box(t, (0.28, 0.34, thigh_h), (sx, 0.0, thigh_c), mat=primary)
        box(t, (0.20, 0.14, 0.18), (sx, -0.14, knee_guard_z), mat=trim, bevel=0.02)
        s = "shin_%s" % side
        box(s, (0.24, 0.28, shin_h), (sx, -0.04, shin_c), mat=primary_dk)
        cyl(s, 0.08, 0.22, (sx, -0.05, 0.155), rot=(0, 90, 0), mat=joint)
        box(s, (0.36, 0.54, 0.16), (sx, -0.14, 0.075), mat=gun)
        box(s, (0.34, 0.14, 0.19), (sx, -0.40, 0.10), mat=trim, bevel=0.02)
        box(s, (0.30, 0.12, 0.14), (sx, 0.12, 0.075), mat=gun)

    return {
        "hips": {"left": (-lx, 0.0, spec["hip_z"]), "right": (lx, 0.0, spec["hip_z"])},
        "knees": {"left": (-lx, -0.02, spec["knee_z"]), "right": (lx, -0.02, spec["knee_z"])},
        "feet": {"left": (-lx, -0.14, 0.02), "right": (lx, -0.14, 0.02)},
        "shoulders": {"left": (-0.80 * tw, 0.0, Z(1.86)), "right": (0.82 * tw, 0.0, Z(1.88))},
    }


def build_weapons():
    """Weapons are chassis-independent. Built at frame center, barrel +X.
    Returns {id: muzzle_x_world}."""
    joint = _edge_wear_metal("w_joint", (0.045, 0.050, 0.065), rough=0.85, metal=0.0, wear=0.0)
    trim = _edge_wear_metal("w_trim", TRIM, rough=0.22, wear=0.0)
    gun = _edge_wear_metal("w_gun", (0.15, 0.16, 0.21), rough=0.48, wear=0.35)
    steel_dk = _edge_wear_metal("w_steel_dk", (0.22, 0.27, 0.38), rough=0.46)
    coil_e = _mat_emit("coil_e", CYAN, 8.0)
    tip_e = _mat_emit("tip_e", ORANGE, 6.0)
    orb_e = _mat_emit("orb_e", ORANGE, 14.0)
    x, y, z = CAM_TARGET.x, CAM_TARGET.y, CAM_TARGET.z

    # rotary autocannon
    box("w_autocannon", (0.34, 0.26, 0.26), (x + 0.10, y, z), mat=gun)
    cyl("w_autocannon", 0.115, 0.30, (x + 0.36, y, z), rot=(0, 90, 0), mat=steel_dk)
    for (oy, oz) in ((0.055, 0), (-0.055, 0), (0, 0.055), (0, -0.055)):
        cyl("w_autocannon", 0.034, 0.58, (x + 0.72, y + oy, z + oz), rot=(0, 90, 0), mat=trim, verts=14)
    cyl("w_autocannon", 0.095, 0.06, (x + 1.00, y, z), rot=(0, 90, 0), mat=trim)
    # missile pod
    box("w_missilepod", (0.44, 0.34, 0.40), (x + 0.22, y, z), mat=gun)
    box("w_missilepod", (0.06, 0.30, 0.36), (x + 0.46, y, z), mat=steel_dk, bevel=0.02)
    for oy in (-0.09, 0.0, 0.09):
        for oz in (-0.09, 0.09):
            cyl("w_missilepod", 0.052, 0.10, (x + 0.52, y + oy, z + oz), rot=(0, 90, 0), mat=joint, verts=14)
            cyl("w_missilepod", 0.036, 0.02, (x + 0.575, y + oy, z + oz), rot=(0, 90, 0), mat=tip_e, verts=12)
    # railgun — twin rails + accelerator coils, LONG reach
    box("w_railgun", (0.30, 0.24, 0.24), (x + 0.06, y, z), mat=gun)              # receiver
    for oz in (0.045, -0.045):
        box("w_railgun", (1.10, 0.055, 0.045), (x + 0.72, y, z + oz), mat=steel_dk, bevel=0.012)  # rails
    for k in range(3):
        cyl("w_railgun", 0.085, 0.045, (x + 0.42 + 0.30 * k, y, z), rot=(0, 90, 0), mat=coil_e, verts=18)  # coils
    box("w_railgun", (0.10, 0.10, 0.16), (x + 1.28, y, z), mat=trim, bevel=0.015)  # muzzle block
    # plasmacaster — fork prongs cradling a hot orb
    box("w_plasmacaster", (0.36, 0.28, 0.30), (x + 0.10, y, z), mat=gun)
    for oz in (0.14, -0.14):
        box("w_plasmacaster", (0.44, 0.10, 0.07), (x + 0.44, y, z + oz), rot=(0, 0, 0), mat=steel_dk, bevel=0.015)
        box("w_plasmacaster", (0.10, 0.10, 0.05), (x + 0.64, y, z + oz * 0.75), mat=trim, bevel=0.01)
    sph("w_plasmacaster", 0.105, (x + 0.52, y, z), mat=orb_e)

    return {"autocannon": 1.04, "missilepod": 0.60, "railgun": 1.36, "plasmacaster": 0.70}


def setup_camera_lights():
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = SAMPLES
    sc.render.resolution_x = RES
    sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    world = bpy.data.worlds.new("w"); sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.06, 0.07, 0.11, 1.0)
    bg.inputs["Strength"].default_value = 0.35

    cam_d = bpy.data.cameras.new("cam"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = ORTHO
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    el, dist = math.radians(CAM_EL), 14.0
    cam.location = (CAM_TARGET.x, CAM_TARGET.y - dist * math.cos(el), CAM_TARGET.z + dist * math.sin(el))
    look = CAM_TARGET - mathutils.Vector(cam.location)
    cam.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()

    def sun(name, energy, rot, color=(1, 1, 1)):
        d = bpy.data.lights.new(name, type='SUN'); d.energy = energy; d.color = color
        d.angle = math.radians(4)
        o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        return o
    sun("key", 5.0, (52, 8, -34), color=(1.0, 0.97, 0.90))
    sun("fill", 1.1, (66, -6, 46), color=(0.70, 0.82, 1.0))
    sun("rim", 5.5, (-35, 0, 160), color=(0.70, 0.95, 1.0))
    return cam


def render_only(names, path):
    if isinstance(names, str):
        names = [names]
    for objs in part_objs.values():
        for o in objs:
            o.hide_render = True
    for n in names:
        for o in part_objs.get(n, []):
            o.hide_render = False
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def px(cam, world_pt):
    sc = bpy.context.scene
    co = world_to_camera_view(sc, cam, mathutils.Vector(world_pt))
    return [round(co.x * RES - RES / 2.0, 1), round((1.0 - co.y) * RES - RES / 2.0, 1)]


CHASSIS_PARTS = ["thigh_left", "thigh_right", "shin_left", "shin_right", "torso", "core", "head"]
WEAPON_IDS = ["autocannon", "missilepod", "railgun", "plasmacaster"]


def fresh_scene():
    global part_objs
    part_objs = {}
    bpy.ops.wm.read_factory_settings(use_empty=True)


def do_chassis(cid, render=True):
    spec = CHASSIS_SPECS[cid]
    fresh_scene()
    anchors_w = build_chassis(spec)
    muzzles = build_weapons()          # in-scene for --preview; hidden for part renders
    cam = setup_camera_lights()
    outdir = os.path.join(MECHA, cid)
    os.makedirs(outdir, exist_ok=True)
    if render:
        for name in CHASSIS_PARTS:
            render_only(name, os.path.join(outdir, name + ".png"))
            print("ok %s/%s" % (cid, name), flush=True)
    anim = dict(ANIM_BASE); anim.update(spec["anim"])
    rig = {
        "frame": RES,
        "z_order": {"thigh_left": 0, "thigh_right": 0, "shin_left": 1, "shin_right": 1,
                    "torso": 3, "core": 4, "head": 5},
        "anim": anim,
        "hips": {k: px(cam, v) for k, v in anchors_w["hips"].items()},
        "knees": {k: px(cam, v) for k, v in anchors_w["knees"].items()},
        "feet": {k: px(cam, v) for k, v in anchors_w["feet"].items()},
        "shoulders": {k: px(cam, v) for k, v in anchors_w["shoulders"].items()},
        "center": px(cam, tuple(CAM_TARGET)),
        "weapons": {wid: {"muzzle": px(cam, (CAM_TARGET.x + mx, CAM_TARGET.y, CAM_TARGET.z))}
                    for wid, mx in muzzles.items()},
    }
    with open(os.path.join(outdir, "rig.json"), "w") as f:
        json.dump(rig, f, indent=2)
    print("rig %s written" % cid, flush=True)


def do_weapons():
    fresh_scene()
    build_weapons()
    setup_camera_lights()
    os.makedirs(WEAP, exist_ok=True)
    for wid in WEAPON_IDS:
        render_only("w_" + wid, os.path.join(WEAP, wid + ".png"))
        print("ok weapons/%s" % wid, flush=True)


def main():
    args = sys.argv[1:]
    if args and args[0] == "--preview":
        cid = args[1] if len(args) > 1 else "vanguard"
        fresh_scene()
        build_chassis(CHASSIS_SPECS[cid])
        build_weapons()
        setup_camera_lights()
        os.makedirs(DOCS, exist_ok=True)
        p = os.path.join(DOCS, "lookdev_%s.png" % cid)
        render_only(CHASSIS_PARTS + ["w_" + w for w in WEAPON_IDS], p)
        print("PREVIEW ->", p)
        return
    targets = args if args else list(CHASSIS_SPECS.keys())
    for cid in targets:
        if cid in CHASSIS_SPECS:
            do_chassis(cid)
    if not args:
        do_weapons()
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
