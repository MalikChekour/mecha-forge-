#!/usr/bin/env python3
"""
mecha-forge — hard-surface mecha PART renderer (headless bpy, Cycles CPU, no GPU).

Builds a chunky hard-surface mecha as SEPARATE RIGID PARTS (torso, head, core,
two legs) plus separate weapon hardpoints, and renders each part to its own
transparent RGBA layer from ONE shared camera so the layers stack pixel-aligned
in Godot. Also writes rig.json with pixel-space anchors (shoulders, muzzles,
feet) computed by projecting world points through the camera.

Why parts, not a monolithic sprite: the mecha is CUSTOMIZABLE with VISIBLE
weapon hardpoints. Rendering rigid parts and animating them procedurally in the
engine avoids the two documented dead-ends (mesh segmentation SIGSEGV, hard-
surface auto-rig skinning tears) and scales to any chassis x weapon combo with
zero extra baking.

Usage:
  python build_mecha.py            # render all parts + weapons + rig.json
  python build_mecha.py torso      # render only one part (fast look-dev preview)
"""
import bpy, os, sys, json, math, mathutils
from bpy_extras.object_utils import world_to_camera_view

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MECHA = os.path.join(ROOT, "game", "assets", "mecha")
WEAP = os.path.join(ROOT, "game", "assets", "weapons")
os.makedirs(MECHA, exist_ok=True)
os.makedirs(WEAP, exist_ok=True)

RES = 384
SAMPLES = 40
CAM_AZ = 0.0            # camera due -Y, looking +Y  => world +X == screen +X
CAM_EL = 58.0          # elevation: high 3/4 top-down, reads as a floor
CAM_TARGET = mathutils.Vector((0.0, 0.0, 1.0))   # frame center = mecha mid-height
ORTHO = 3.1

# ---- palette (hero chassis: steel + cyan energy) ----
STEEL = (0.34, 0.40, 0.52)
STEEL_DK = (0.17, 0.21, 0.30)
ACCENT = (0.10, 0.55, 0.95)
CYAN = (0.10, 0.85, 1.00)
GUNMETAL = (0.14, 0.15, 0.19)

part_objs = {}   # name -> [obj,...]


def _mat_metal(name, color, rough=0.42, metal=1.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
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


def box(part, size, loc, rot=(0, 0, 0), mat=None, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    if bevel > 0:
        bm = o.modifiers.new("bev", 'BEVEL'); bm.width = bevel; bm.segments = 2
    if mat:
        o.data.materials.append(mat)
    part_objs.setdefault(part, []).append(o)
    return o


def cyl(part, r, depth, loc, rot=(0, 0, 0), mat=None):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=20, location=loc)
    o = bpy.context.active_object
    o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    bpy.ops.object.shade_smooth()
    if mat:
        o.data.materials.append(mat)
    part_objs.setdefault(part, []).append(o)
    return o


# ---------- build the mecha ----------
# Convention: +Z up, -Y = toward camera = FRONT (cockpit/core/feet face here).
def build():
    steel = _mat_metal("steel", STEEL)
    steel_dk = _mat_metal("steel_dk", STEEL_DK, rough=0.5)
    accent = _mat_metal("accent", ACCENT, rough=0.3)
    gun = _mat_metal("gun", GUNMETAL, rough=0.5)
    core_e = _mat_emit("core_e", CYAN, 9.0)
    visor_e = _mat_emit("visor_e", CYAN, 6.0)

    # TORSO group (chest + collar + shoulders/pauldrons + backpack thrusters)
    box("torso", (1.00, 0.62, 0.80), (0, 0, 1.28), mat=steel)              # chest
    box("torso", (0.70, 0.48, 0.16), (0, 0.02, 1.66), mat=steel_dk)        # collar
    box("torso", (0.34, 0.34, 0.24), (0, -0.32, 1.30), mat=accent, bevel=0.02)  # chest plate front
    box("torso", (0.34, 0.42, 0.40), (-0.58, 0.0, 1.50), mat=steel_dk)     # shoulder joint L
    box("torso", (0.34, 0.42, 0.40), (0.58, 0.0, 1.50), mat=steel_dk)      # shoulder joint R
    box("torso", (0.42, 0.48, 0.48), (-0.78, 0.0, 1.54), rot=(0, -16, 0), mat=steel)  # pauldron L
    box("torso", (0.42, 0.48, 0.48), (0.78, 0.0, 1.54), rot=(0, 16, 0), mat=steel)    # pauldron R
    box("torso", (0.56, 0.34, 0.52), (0, 0.44, 1.36), mat=gun)             # backpack
    cyl("torso", 0.09, 0.30, (-0.20, 0.62, 1.58), rot=(90, 0, 0), mat=accent)  # thruster L
    cyl("torso", 0.09, 0.30, (0.20, 0.62, 1.58), rot=(90, 0, 0), mat=accent)   # thruster R

    # CORE (emissive chest reactor) — separate layer so it can pulse. Small + calm.
    cyl("core", 0.10, 0.08, (0, -0.36, 1.32), rot=(90, 0, 0), mat=core_e)

    # HEAD (cockpit + visor) — separate layer for idle bob
    box("head", (0.34, 0.40, 0.30), (0, -0.10, 1.80), mat=steel)
    box("head", (0.30, 0.10, 0.10), (0, -0.30, 1.82), mat=visor_e, bevel=0.01)  # visor

    # LEGS (thigh + shin + foot) — separate layers, animated (walk cycle)
    for side, sx in (("leg_left", -0.36), ("leg_right", 0.36)):
        box(side, (0.30, 0.34, 0.52), (sx, 0.0, 0.80), mat=steel)          # thigh
        box(side, (0.26, 0.30, 0.50), (sx, -0.06, 0.36), mat=steel_dk)     # shin
        box(side, (0.30, 0.50, 0.18), (sx, -0.14, 0.09), mat=gun)          # foot
        box(side, (0.14, 0.14, 0.20), (sx, 0.10, 0.58), mat=accent, bevel=0.02)  # knee accent

    # WEAPONS: built around mount at CAM_TARGET, barrel pointing +X (screen right).
    wm = CAM_TARGET
    # autocannon
    box("w_autocannon", (0.30, 0.22, 0.22), (wm.x + 0.14, wm.y, wm.z), mat=gun)      # breech
    cyl("w_autocannon", 0.06, 0.60, (wm.x + 0.55, wm.y, wm.z), rot=(0, 90, 0), mat=steel_dk)  # barrel
    cyl("w_autocannon", 0.08, 0.10, (wm.x + 0.86, wm.y, wm.z), rot=(0, 90, 0), mat=accent)    # muzzle brake
    # missile pod
    box("w_missilepod", (0.34, 0.40, 0.34), (wm.x + 0.24, wm.y, wm.z), mat=gun)      # pod box
    for oy in (-0.11, 0.11):
        for oz in (-0.10, 0.10):
            cyl("w_missilepod", 0.05, 0.30, (wm.x + 0.42, wm.y + oy, wm.z + oz), rot=(0, 90, 0), mat=accent)  # tubes


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
    # gentle cool ambient
    world = bpy.data.worlds.new("w"); sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.05, 0.06, 0.10, 1.0)
    bg.inputs["Strength"].default_value = 0.25

    cam_d = bpy.data.cameras.new("cam"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = ORTHO
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    az, el, dist = math.radians(CAM_AZ), math.radians(CAM_EL), 14.0
    cam.location = (CAM_TARGET.x + dist*math.cos(el)*math.sin(az),
                    CAM_TARGET.y - dist*math.cos(el)*math.cos(az),
                    CAM_TARGET.z + dist*math.sin(el))
    look = CAM_TARGET - mathutils.Vector(cam.location)
    cam.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()

    def sun(name, energy, rot, color=(1, 1, 1)):
        d = bpy.data.lights.new(name, type='SUN'); d.energy = energy; d.color = color
        o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        return o
    sun("key", 4.2, (52, 8, -34))                       # key: front-top-right
    sun("fill", 1.6, (66, -6, 46), color=(0.75, 0.85, 1.0))  # cool fill front-left
    sun("rim", 3.0, (-58, 0, 150), color=(0.6, 0.9, 1.0))    # cyan rim from back
    return cam


def render_only(name, path):
    for objs in part_objs.values():
        for o in objs:
            o.hide_render = True
    for o in part_objs.get(name, []):
        o.hide_render = False
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def px(cam, world_pt):
    """world point -> (dx,dy) pixel offset from frame center (Godot: +y down)."""
    sc = bpy.context.scene
    co = world_to_camera_view(sc, cam, mathutils.Vector(world_pt))
    x = co.x * RES
    y = (1.0 - co.y) * RES
    return [round(x - RES / 2.0, 1), round(y - RES / 2.0, 1)]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build()
    cam = setup_camera_lights()

    only = sys.argv[1] if len(sys.argv) > 1 else None
    chassis = ["leg_left", "leg_right", "torso", "core", "head"]
    weapons = ["w_autocannon", "w_missilepod"]

    if only:
        p = os.path.join(MECHA if not only.startswith("w_") else WEAP, only + ".png")
        render_only(only, p)
        print("PREVIEW", only, "->", p, os.path.exists(p))
        return

    for name in chassis:
        render_only(name, os.path.join(MECHA, name + ".png"))
        print("ok mecha/%s" % name, flush=True)
    for name in weapons:
        render_only(name, os.path.join(WEAP, name.replace("w_", "") + ".png"))
        print("ok weapons/%s" % name.replace("w_", ""), flush=True)

    wm = CAM_TARGET
    rig = {
        "frame": RES,
        "z_order": {"leg_left": 0, "leg_right": 0, "torso": 2, "core": 3, "head": 3},
        "shoulders": {"left": px(cam, (-0.74, 0.0, 1.54)), "right": px(cam, (0.74, 0.0, 1.54))},
        "feet": {"left": px(cam, (-0.36, -0.14, 0.02)), "right": px(cam, (0.36, -0.14, 0.02))},
        "center": px(cam, (0, 0, 1.0)),
        "weapons": {
            "autocannon": {"muzzle": px(cam, (wm.x + 0.95, wm.y, wm.z))},
            "missilepod": {"muzzle": px(cam, (wm.x + 0.60, wm.y, wm.z))},
        },
    }
    with open(os.path.join(MECHA, "rig.json"), "w") as f:
        json.dump(rig, f, indent=2)
    print("RIG", json.dumps(rig), flush=True)
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
