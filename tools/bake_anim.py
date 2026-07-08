#!/usr/bin/env python3
"""
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

GLB = sys.argv[1]
OUT = sys.argv[2]
FRAMES = int(argval("--frames", 8))
RES = int(argval("--res", 256))
EL = argval("--el", 40.0)
YAW = argval("--yaw", 0.0)
SAMPLES = int(argval("--samples", 24))
TMP = os.path.join(os.path.dirname(OUT) or ".", "_animframe.png")


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

    def sun(name, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(name, type="SUN"); d.energy = e; d.color = col
        d.angle = math.radians(5)
        o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
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


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    objs = meshes()
    if not objs:
        raise RuntimeError("no mesh in GLB")
    if YAW:
        for o in bpy.context.scene.objects:
            if o.parent is None:
                o.rotation_euler.z += math.radians(YAW)
    sc = bpy.context.scene
    f0, f1 = sc.frame_start, sc.frame_end
    if f1 <= f0:
        f1 = f0 + 24
    frames = [int(round(f0 + (f1 - f0) * i / FRAMES)) for i in range(FRAMES)]
    setup_render()

    # fixed camera: union bounds over the sampled frames (stable, no jitter)
    umn = mathutils.Vector((1e9, 1e9, 1e9)); umx = -umn
    for f in frames:
        sc.frame_set(f)
        mn, mx = frame_bounds(objs)
        for i in range(3):
            umn[i] = min(umn[i], mn[i]); umx[i] = max(umx[i], mx[i])
    center = (umn + umx) * 0.5
    size = max((umx - umn).x, (umx - umn).y, (umx - umn).z, 1e-3)

    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.3
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    e = math.radians(EL); dist = size * 4.0
    cam.location = (center.x, center.y - dist * math.cos(e), center.z + dist * math.sin(e))
    look = center - mathutils.Vector(cam.location)
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

    tiles = []
    for k, f in enumerate(frames):
        sc.frame_set(f)
        sc.render.filepath = TMP
        bpy.ops.render.render(write_still=True)
        tiles.append(Image.open(TMP).convert("RGBA").copy())
    sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
    for k, im in enumerate(tiles):
        sheet.paste(im, (RES * k, 0), im)
    sheet.save(OUT)
    if os.path.exists(TMP):
        os.remove(TMP)
    print("SHEET", OUT, "%dx%d" % (RES * FRAMES, RES), "frames", FRAMES,
          "range", f0, f1, os.path.exists(OUT))


if __name__ == "__main__":
    main()
