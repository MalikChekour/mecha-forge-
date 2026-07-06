#!/usr/bin/env python3
"""
mecha-forge — bake a textured GLB into a top-down 2D game sprite (headless bpy,
Cycles CPU, no GPU). Works on Meshy GLBs (or any GLB). Keeps the model's own PBR
textures; a studio 3-point + cyan rim reveals them and grounds them in-theme.

  python bake_meshy.py  <in.glb>  <out.png>  [--res 384] [--el 40] [--yaw 0]
                        [--dirs 1|8] [--samples 40]

--dirs 8 renders an 8-direction set out_0..out_7.png (orbits the camera).
--yaw rotates the model so its front faces the camera (Meshy front is usually +Z).
"""
import bpy, sys, os, math, mathutils

def arg(flag, default, cast=float):
    a = sys.argv
    return cast(a[a.index(flag) + 1]) if flag in a else default

GLB = sys.argv[1]
OUT = sys.argv[2]
RES = int(arg("--res", 384))
EL = arg("--el", 40.0)
YAW = arg("--yaw", 0.0)
DIRS = int(arg("--dirs", 1))
SAMPLES = int(arg("--samples", 40))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path):
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no mesh in GLB")
    # optional yaw so the model faces the camera (about world Z through origin)
    if YAW:
        for o in meshes:
            if o.parent is None:
                o.rotation_euler.z += math.radians(YAW)
    bpy.context.view_layer.update()
    return meshes


def world_bounds(meshes):
    mn = mathutils.Vector((1e9, 1e9, 1e9))
    mx = mathutils.Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i]); mx[i] = max(mx[i], w[i])
    center = (mn + mx) * 0.5
    size = max((mx - mn).x, (mx - mn).y, (mx - mn).z)
    return center, max(size, 1e-3)


def setup(center, size):
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
    world = bpy.data.worlds.new("w"); sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.08, 0.09, 0.13, 1.0)
    bg.inputs["Strength"].default_value = 0.45

    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"
    cam_d.ortho_scale = size * 1.25
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam

    def sun(name, energy, rot, color=(1, 1, 1)):
        d = bpy.data.lights.new(name, type="SUN"); d.energy = energy; d.color = color
        d.angle = math.radians(5)
        o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
    sun("key", 4.2, (52, 8, -34), color=(1.0, 0.97, 0.9))
    sun("fill", 1.4, (66, -6, 46), color=(0.75, 0.85, 1.0))
    sun("rim", 4.0, (-38, 0, 160), color=(0.7, 0.95, 1.0))
    return cam


def aim(cam, center, az, el, dist):
    e, a = math.radians(el), math.radians(az)
    cam.location = (center.x + dist * math.cos(e) * math.sin(a),
                    center.y - dist * math.cos(e) * math.cos(a),
                    center.z + dist * math.sin(e))
    look = center - mathutils.Vector(cam.location)
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    reset()
    meshes = import_glb(GLB)
    center, size = world_bounds(meshes)
    cam = setup(center, size)
    dist = size * 4.0
    if DIRS <= 1:
        aim(cam, center, 0.0, EL, dist)
        render(OUT)
        print("BAKED", OUT, "size=%.2f" % size, os.path.exists(OUT))
    else:
        stem, ext = os.path.splitext(OUT)
        for i in range(DIRS):
            aim(cam, center, i * (360.0 / DIRS), EL, dist)
            render("%s_%d%s" % (stem, i, ext))
        print("BAKED %d dirs -> %s_0..%d%s" % (DIRS, stem, DIRS - 1, ext))


if __name__ == "__main__":
    main()
