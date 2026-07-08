#!/usr/bin/env python3
"""
mecha-forge — bake a PROCEDURAL animation onto a static (non-humanoid) Meshy GLB.
For flying/wheeled/insectoid enemies that Meshy can't auto-rig (humanoid-only),
we animate the whole model with simple rigid transforms (hover/spin/scuttle/idle)
and bake N frames to a spritesheet. In-engine this is done live on the Sprite2D;
this bake is a preview / fallback.

  python bake_proc.py <in.glb> <out_sheet.png> <motion> [--frames 8] [--res 192]
                      [--el 40] [--samples 22]
  motion = hover | spin | scuttle | idle
"""
import bpy, sys, os, math, mathutils
from PIL import Image


def argval(flag, default, cast=float):
    a = sys.argv
    return cast(a[a.index(flag) + 1]) if flag in a else default

GLB = os.path.abspath(sys.argv[1])
OUT = os.path.abspath(sys.argv[2])
MOTION = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith("--") else "hover"
FRAMES = int(argval("--frames", 8))
RES = int(argval("--res", 192))
EL = argval("--el", 40.0)
SAMPLES = int(argval("--samples", 22))
TMP = os.path.join(os.path.dirname(OUT), "_procframe.png")
TAU = math.pi * 2


def bounds(objs):
    mn = mathutils.Vector((1e9, 1e9, 1e9)); mx = -mn
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i]); mx[i] = max(mx[i], w[i])
    return mn, mx


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    roots = [o for o in bpy.context.scene.objects if o.parent is None and o.type in ("MESH", "EMPTY")]
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    mn, mx = bounds(meshes)
    center = (mn + mx) * 0.5
    size = max((mx - mn).x, (mx - mn).y, (mx - mn).z, 1e-3)

    root = bpy.data.objects.new("rig_root", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = center
    for o in roots:
        o.parent = root
        o.matrix_parent_inverse = root.matrix_world.inverted()

    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = RES; sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bgn = w.node_tree.nodes.get("Background")
    bgn.inputs["Color"].default_value = (0.08, 0.09, 0.13, 1.0); bgn.inputs["Strength"].default_value = 0.45

    def sun(nm, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(nm, type="SUN"); d.energy = e; d.color = col; d.angle = math.radians(5)
        ob = bpy.data.objects.new(nm, d); sc.collection.objects.link(ob)
        ob.rotation_euler = tuple(math.radians(a) for a in rot)
    sun("key", 4.2, (52, 8, -34), (1.0, 0.97, 0.9))
    sun("fill", 1.4, (66, -6, 46), (0.75, 0.85, 1.0))
    sun("rim", 4.0, (-38, 0, 160), (0.7, 0.95, 1.0))

    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.35
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    e = math.radians(EL); dist = size * 4.0
    cam.location = (center.x, center.y - dist * math.cos(e), center.z + dist * math.sin(e))
    look = center - mathutils.Vector(cam.location)
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

    def pose(t):
        root.location = center.copy()
        root.rotation_euler = (0.0, 0.0, 0.0)
        if MOTION == "hover":
            root.location.z += 0.07 * size * math.sin(TAU * t)
            root.rotation_euler.z = math.radians(10.0 * math.sin(TAU * t))
            root.rotation_euler.x = math.radians(4.0 * math.sin(TAU * t + 1.0))
        elif MOTION == "spin":
            root.rotation_euler.z = TAU * t
            root.location.z += 0.02 * size * math.sin(2 * TAU * t)
        elif MOTION == "scuttle":
            root.location.z += 0.035 * size * abs(math.sin(TAU * t * 2))
            root.rotation_euler.y = math.radians(5.0 * math.sin(TAU * t * 2))
            root.rotation_euler.z = math.radians(4.0 * math.sin(TAU * t))
        else:  # idle
            root.location.z += 0.02 * size * math.sin(TAU * t)
            root.rotation_euler.z = math.radians(3.0 * math.sin(TAU * t))
        bpy.context.view_layer.update()

    tiles = []
    for i in range(FRAMES):
        pose(i / FRAMES)
        sc.render.filepath = TMP
        bpy.ops.render.render(write_still=True)
        tiles.append(Image.open(TMP).convert("RGBA").copy())
    sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
    for k, im in enumerate(tiles):
        sheet.paste(im, (RES * k, 0), im)
    sheet.save(OUT)
    if os.path.exists(TMP):
        os.remove(TMP)
    print("PROC", MOTION, OUT, "%dx%d" % (RES * FRAMES, RES), FRAMES, "frames")


if __name__ == "__main__":
    main()
