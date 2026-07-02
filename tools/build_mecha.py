#!/usr/bin/env python3
"""
mecha-forge — hard-surface mecha PART renderer v2 (headless bpy, Cycles CPU, no GPU).

v2 after the art-director review pass:
- legs are TWO segments per side (thigh + shin/foot) rendered as separate layers,
  so the engine can bend a visible knee — the walk must READ at phone scale.
- brighter mid-value armor + hot cyan rim light + zoned materials (primary armor /
  near-black joints / bright metal trim / emissives) so the silhouette carves off a
  dark battlefield instead of vanishing dark-on-dark.
- weapons redesigned as legible ARCHETYPES: rotary autocannon (visible barrel
  cluster) and boxy missile pod (grid of tubes with hot orange tips).
- the chest reactor is a designed element (trim frame + hot core + saturated halo),
  not a blank panel.
- longer legs / bigger feet (heroic proportions), camera at 40° elevation so the
  lower body doesn't compress.
- rig.json now carries hips/knees/feet anchors AND the shared animation constants,
  making it the single source of truth for preview_gif.py and MechaRig.gd.

Parts are rendered from ONE shared ortho camera so all layers stack pixel-aligned.
Anchors are world points projected through the camera (world_to_camera_view).

Usage:
  python build_mecha.py            # render all parts + weapons + rig.json
  python build_mecha.py torso      # render one part (fast look-dev)
  python build_mecha.py --preview  # single composite render of EVERYTHING (look-dev)
"""
import bpy, os, sys, json, math, mathutils
from bpy_extras.object_utils import world_to_camera_view

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MECHA = os.path.join(ROOT, "game", "assets", "mecha")
WEAP = os.path.join(ROOT, "game", "assets", "weapons")
os.makedirs(MECHA, exist_ok=True)
os.makedirs(WEAP, exist_ok=True)

RES = 384
SAMPLES = 48
CAM_EL = 40.0                                    # 3/4 top-down: legs read, shoulder tops visible
CAM_TARGET = mathutils.Vector((0.0, 0.0, 1.20))  # frame center ~ mecha mid-height
ORTHO = 3.65

# ---- zoned palette (readability pass: mid-value armor, near-black joints, hot trim) ----
PRIMARY = (0.42, 0.50, 0.64)      # tintable armor — mid value so paint reads
PRIMARY_DK = (0.22, 0.27, 0.38)   # secondary plates
JOINT = (0.045, 0.050, 0.065)     # near-black mechanical/rubber joints
TRIM = (0.72, 0.76, 0.85)         # bright metal trim — catches spec streaks
GUNMETAL = (0.15, 0.16, 0.21)
CYAN = (0.20, 0.90, 1.00)
ORANGE = (1.00, 0.42, 0.10)

# ---- SHARED animation constants (fractions of frame / radians / Hz) ----
# Written into rig.json — preview_gif.py and MechaRig.gd both read them from there.
ANIM = {
    "step_freq": 1.0,        # leg cycles/sec at reference speed
    "thigh_rot": 0.10,       # thigh swing about hip (rad)
    "shin_rot": 0.22,        # knee bend during swing (rad) — makes the knee READ
    "lift_thigh": 0.020,     # vertical foot lift, thigh share (frac of frame)
    "lift_shin": 0.024,      # extra lift on the shin/foot layer
    "stride": 0.014,         # fore/aft slide
    "squash": 0.055,         # foot-plant squash on the shin layer (scale)
    "bob": 0.020,            # torso weight-bob (2 beats/cycle)
    "lat": 0.010,            # torso lateral shift toward planted foot
    "rock": 0.045,           # torso rock (rad)
    "head_bob": 0.008,
    "core_pulse_hz": 1.2,
    "recoil": 0.06,          # weapon kick along -aim (frac of frame)
    "recoil_rock": 0.05,     # torso counter-rock impulse on fire (rad)
}

part_objs = {}   # layer name -> [obj,...]


# ---------- materials ----------
def _edge_wear_metal(name, color, rough=0.42, metal=1.0, wear=0.55):
    """PBR metal with procedural edge-wear: bright TRIM metal bleeds through on
    edges (Bevel-node normal difference mask) + noise roughness variation.
    Sells 'battle-worn plates' without any texture/GPU work."""
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
    # subtle roughness breakup
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


# ---------- skeleton reference points (world, +Z up, -Y = front/camera) ----------
# Heroic proportions: legs lengthened (hip at 1.14), bigger feet.
HIP = {"left": (-0.36, 0.0, 1.14), "right": (0.36, 0.0, 1.14)}
KNEE = {"left": (-0.36, -0.02, 0.62), "right": (0.36, -0.02, 0.62)}
FOOT = {"left": (-0.36, -0.14, 0.02), "right": (0.36, -0.14, 0.02)}
SHOULDER = {"left": (-0.80, 0.0, 1.86), "right": (0.82, 0.0, 1.88)}
WM = mathutils.Vector((0.0, 0.0, 1.20))   # weapon build origin = frame center


def build():
    primary = _edge_wear_metal("primary", PRIMARY, rough=0.40)
    primary_dk = _edge_wear_metal("primary_dk", PRIMARY_DK, rough=0.46)
    joint = _edge_wear_metal("joint", JOINT, rough=0.85, metal=0.0, wear=0.0)
    trim = _edge_wear_metal("trim", TRIM, rough=0.22, wear=0.0)
    gun = _edge_wear_metal("gun", GUNMETAL, rough=0.48, wear=0.35)
    core_hot = _mat_emit("core_hot", (0.85, 1.0, 1.0), 16.0)
    core_halo = _mat_emit("core_halo", CYAN, 10.0)
    visor_e = _mat_emit("visor_e", CYAN, 10.0)
    sensor_e = _mat_emit("sensor_e", CYAN, 6.0)
    tip_e = _mat_emit("tip_e", ORANGE, 6.0)

    # ---- TORSO (chest + pelvis + shoulders + backpack; one rigid layer) ----
    box("torso", (1.04, 0.60, 0.72), (0, 0, 1.50), mat=primary)                 # chest
    box("torso", (0.52, 0.44, 0.16), (0, 0, 1.14), mat=joint, bevel=0.02)       # abdomen joint (dark break)
    box("torso", (0.78, 0.54, 0.24), (0, -0.02, 1.00), mat=primary_dk)          # pelvis
    box("torso", (0.72, 0.46, 0.13), (0, 0.02, 1.90), mat=primary_dk)           # collar
    box("torso", (0.40, 0.10, 0.34), (0, -0.325, 1.50), mat=trim, bevel=0.02)   # reactor frame
    for sx in (-0.30, 0.30):                                                    # chest panel lines
        box("torso", (0.05, 0.045, 0.52), (sx, -0.305, 1.50), mat=gun, bevel=0.01)
    box("torso", (0.30, 0.40, 0.38), (-0.58, 0, 1.72), mat=joint, bevel=0.02)   # shoulder joint L
    box("torso", (0.30, 0.40, 0.38), (0.58, 0, 1.72), mat=joint, bevel=0.02)    # shoulder joint R
    # pauldrons — asymmetric silhouette: right is bigger with a trim lip
    box("torso", (0.44, 0.50, 0.36), (-0.80, 0, 1.86), rot=(0, -12, 0), mat=primary)
    for k in range(3):                                                          # vents on top of L pauldron
        box("torso", (0.30, 0.07, 0.035), (-0.80, -0.14 + 0.14 * k, 2.035), rot=(0, -12, 0), mat=gun, bevel=0.008)
    box("torso", (0.50, 0.56, 0.44), (0.82, 0, 1.88), rot=(0, 14, 0), mat=primary)
    box("torso", (0.52, 0.12, 0.07), (0.82, -0.24, 2.07), rot=(0, 14, 0), mat=trim, bevel=0.015)  # trim lip
    cyl("torso", 0.045, 0.03, (0.70, -0.285, 1.80), rot=(90, 0, 0), mat=sensor_e)  # sensor light
    box("torso", (0.56, 0.30, 0.48), (0, 0.42, 1.60), mat=gun)                  # backpack
    cyl("torso", 0.09, 0.30, (-0.20, 0.60, 1.80), rot=(90, 0, 0), mat=trim)     # thruster L
    cyl("torso", 0.09, 0.30, (0.20, 0.60, 1.80), rot=(90, 0, 0), mat=trim)      # thruster R

    # ---- CORE (separate layer so it can pulse): hot center + saturated halo ----
    cyl("core", 0.16, 0.05, (0, -0.345, 1.50), rot=(90, 0, 0), mat=core_halo)
    cyl("core", 0.085, 0.08, (0, -0.360, 1.50), rot=(90, 0, 0), mat=core_hot)

    # ---- HEAD (cockpit + visor + crest fins + antenna) ----
    box("head", (0.34, 0.36, 0.26), (0, -0.06, 2.14), mat=primary)
    box("head", (0.28, 0.10, 0.11), (0, -0.26, 2.14), mat=visor_e, bevel=0.01)
    box("head", (0.05, 0.24, 0.34), (-0.10, 0.04, 2.34), rot=(-10, 0, 0), mat=primary_dk)  # crest fin L
    box("head", (0.05, 0.24, 0.34), (0.10, 0.04, 2.34), rot=(-10, 0, 0), mat=primary_dk)   # crest fin R
    cyl("head", 0.015, 0.30, (0.20, 0.05, 2.36), mat=trim, verts=10)                       # antenna

    # ---- LEGS: 2 rigid segments per side (knee can bend in-engine) ----
    for side, sx in (("left", -0.36), ("right", 0.36)):
        t = "thigh_%s" % side
        cyl(t, 0.105, 0.30, (sx, 0.0, 1.14), rot=(0, 90, 0), mat=joint)        # hip joint
        box(t, (0.28, 0.34, 0.52), (sx, 0.0, 0.88), mat=primary)               # thigh
        box(t, (0.20, 0.14, 0.18), (sx, -0.14, 0.64), mat=trim, bevel=0.02)    # knee guard
        s = "shin_%s" % side
        box(s, (0.24, 0.28, 0.44), (sx, -0.04, 0.38), mat=primary_dk)          # shin
        cyl(s, 0.08, 0.22, (sx, -0.05, 0.155), rot=(0, 90, 0), mat=joint)      # ankle
        box(s, (0.36, 0.54, 0.16), (sx, -0.14, 0.075), mat=gun)                # foot (mass!)
        box(s, (0.34, 0.14, 0.19), (sx, -0.40, 0.10), mat=trim, bevel=0.02)    # toe guard
        box(s, (0.30, 0.12, 0.14), (sx, 0.12, 0.075), mat=gun)                 # heel

    # ---- WEAPONS: mount at frame center, barrel points +X (screen right) ----
    # ROTARY AUTOCANNON — the barrel cluster IS the archetype
    box("w_autocannon", (0.34, 0.26, 0.26), (WM.x + 0.10, WM.y, WM.z), mat=gun)
    cyl("w_autocannon", 0.115, 0.30, (WM.x + 0.36, WM.y, WM.z), rot=(0, 90, 0), mat=primary_dk)  # shroud
    for (oy, oz) in ((0.055, 0), (-0.055, 0), (0, 0.055), (0, -0.055)):
        cyl("w_autocannon", 0.034, 0.58, (WM.x + 0.72, WM.y + oy, WM.z + oz), rot=(0, 90, 0), mat=trim, verts=14)
    cyl("w_autocannon", 0.095, 0.06, (WM.x + 1.00, WM.y, WM.z), rot=(0, 90, 0), mat=trim)        # muzzle ring
    # MISSILE POD — boxy pod, 6 visible tubes with hot orange tips
    box("w_missilepod", (0.44, 0.34, 0.40), (WM.x + 0.22, WM.y, WM.z), mat=gun)
    box("w_missilepod", (0.06, 0.30, 0.36), (WM.x + 0.46, WM.y, WM.z), mat=primary_dk, bevel=0.02)
    for oy in (-0.09, 0.0, 0.09):
        for oz in (-0.09, 0.09):
            cyl("w_missilepod", 0.052, 0.10, (WM.x + 0.52, WM.y + oy, WM.z + oz), rot=(0, 90, 0), mat=joint, verts=14)
            cyl("w_missilepod", 0.036, 0.02, (WM.x + 0.575, WM.y + oy, WM.z + oz), rot=(0, 90, 0), mat=tip_e, verts=12)


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
    cam.location = (CAM_TARGET.x,
                    CAM_TARGET.y - dist * math.cos(el),
                    CAM_TARGET.z + dist * math.sin(el))
    look = CAM_TARGET - mathutils.Vector(cam.location)
    cam.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()

    def sun(name, energy, rot, color=(1, 1, 1)):
        d = bpy.data.lights.new(name, type='SUN'); d.energy = energy; d.color = color
        d.angle = math.radians(4)
        o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        return o
    sun("key", 5.0, (52, 8, -34), color=(1.0, 0.97, 0.90))      # warm key, front-top-right
    sun("fill", 1.1, (66, -6, 46), color=(0.70, 0.82, 1.0))     # cool low fill, front-left
    # cyan rim from the back, LOW angle so it grazes edges instead of flooding top faces
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
    """world point -> (dx,dy) pixel offset from frame center (screen: +y down)."""
    sc = bpy.context.scene
    co = world_to_camera_view(sc, cam, mathutils.Vector(world_pt))
    x = co.x * RES
    y = (1.0 - co.y) * RES
    return [round(x - RES / 2.0, 1), round(y - RES / 2.0, 1)]


CHASSIS = ["thigh_left", "thigh_right", "shin_left", "shin_right", "torso", "core", "head"]
WEAPONS = ["w_autocannon", "w_missilepod"]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build()
    cam = setup_camera_lights()

    arg = sys.argv[1] if len(sys.argv) > 1 else None
    if arg == "--preview":
        p = os.path.join(ROOT, "docs", "lookdev_all.png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        render_only(CHASSIS + WEAPONS, p)
        print("PREVIEW ->", p)
        return
    if arg:
        folder = WEAP if arg.startswith("w_") else MECHA
        p = os.path.join(folder, arg.replace("w_", "") + ".png")
        render_only(arg, p)
        print("PREVIEW", arg, "->", p, os.path.exists(p))
        return

    for name in CHASSIS:
        render_only(name, os.path.join(MECHA, name + ".png"))
        print("ok mecha/%s" % name, flush=True)
    for name in WEAPONS:
        render_only(name, os.path.join(WEAP, name.replace("w_", "") + ".png"))
        print("ok weapons/%s" % name.replace("w_", ""), flush=True)

    rig = {
        "frame": RES,
        "z_order": {"thigh_left": 0, "thigh_right": 0, "shin_left": 1, "shin_right": 1,
                    "torso": 3, "core": 4, "head": 5},
        "anim": ANIM,
        "hips": {k: px(cam, v) for k, v in HIP.items()},
        "knees": {k: px(cam, v) for k, v in KNEE.items()},
        "feet": {k: px(cam, v) for k, v in FOOT.items()},
        "shoulders": {k: px(cam, v) for k, v in SHOULDER.items()},
        "center": px(cam, (0, 0, 1.20)),
        "weapons": {
            "autocannon": {"muzzle": px(cam, (WM.x + 1.04, WM.y, WM.z))},
            "missilepod": {"muzzle": px(cam, (WM.x + 0.60, WM.y, WM.z))},
        },
    }
    with open(os.path.join(MECHA, "rig.json"), "w") as f:
        json.dump(rig, f, indent=2)
    print("RIG", json.dumps(rig), flush=True)
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
