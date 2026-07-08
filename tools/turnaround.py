#!/usr/bin/env python3
"""
mecha-forge — orthographic MODEL SHEET from a GLB (headless bpy, Cycles CPU).
Proves the 3D model carries every angle: renders the canonical engineering views
(front / rear / left / right / top / 3-quarter) at a shared scale and tiles them
into a labeled blueprint-style sheet.

  python turnaround.py <in.glb> <out.png> [--res 320] [--samples 26]
"""
import bpy, sys, os, math, mathutils
from PIL import Image, ImageDraw


def argval(flag, d, c=float):
    a = sys.argv
    return c(a[a.index(flag) + 1]) if flag in a else d

GLB = os.path.abspath(sys.argv[1])
OUT = os.path.abspath(sys.argv[2])
RES = int(argval("--res", 320))
SAMPLES = int(argval("--samples", 26))
TMP = os.path.join(os.path.dirname(OUT), "_turn.png")

# label, azimuth, elevation
VIEWS = [("VUE AVANT", 0, 6), ("VUE ARRIÈRE", 180, 6), ("PROFIL GAUCHE", 90, 6),
         ("PROFIL DROIT", -90, 6), ("VUE DE DESSUS", 0, 88), ("VUE 3/4", -35, 32)]


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
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    mn, mx = bounds(meshes)
    center = (mn + mx) * 0.5
    size = max((mx - mn).x, (mx - mn).y, (mx - mn).z, 1e-3)

    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = RES; sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bgn = w.node_tree.nodes.get("Background")
    bgn.inputs["Color"].default_value = (0.10, 0.12, 0.16, 1.0); bgn.inputs["Strength"].default_value = 0.6

    def sun(nm, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(nm, type="SUN"); d.energy = e; d.color = col; d.angle = math.radians(6)
        ob = bpy.data.objects.new(nm, d); sc.collection.objects.link(ob)
        ob.rotation_euler = tuple(math.radians(a) for a in rot)
    sun("key", 3.6, (52, 8, -34), (1.0, 0.98, 0.94))
    sun("fill", 1.8, (66, -6, 46), (0.8, 0.88, 1.0))
    sun("rim", 3.0, (-40, 0, 160), (0.7, 0.95, 1.0))

    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.18
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    dist = size * 4.0

    def aim(az, el):
        e, a = math.radians(el), math.radians(az)
        cam.location = (center.x + dist * math.cos(e) * math.sin(a),
                        center.y - dist * math.cos(e) * math.cos(a),
                        center.z + dist * math.sin(e))
        look = center - mathutils.Vector(cam.location)
        cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

    tiles = []
    for lab, az, el in VIEWS:
        aim(az, el)
        sc.render.filepath = TMP
        bpy.ops.render.render(write_still=True)
        tiles.append((lab, Image.open(TMP).convert("RGBA").copy()))
    if os.path.exists(TMP):
        os.remove(TMP)

    cols, rows = 3, 2
    pad, cap = 10, 26
    cw, ch = RES + pad * 2, RES + cap
    sheet = Image.new("RGB", (cw * cols, ch * rows), (13, 17, 26))
    d = ImageDraw.Draw(sheet)
    for i, (lab, im) in enumerate(tiles):
        cx, cy = (i % cols) * cw, (i // cols) * ch
        # blueprint grid
        for gx in range(cx, cx + cw, 24):
            d.line([(gx, cy), (gx, cy + ch)], fill=(24, 34, 52))
        for gy in range(cy, cy + ch, 24):
            d.line([(cx, gy), (cx + cw, gy)], fill=(24, 34, 52))
        bg = Image.new("RGBA", im.size, (0, 0, 0, 0)); bg.alpha_composite(im)
        sheet.paste(bg.convert("RGB"), (cx + pad, cy + 4), bg)
        d.rectangle([cx + 3, cy + 3, cx + cw - 3, cy + ch - 3], outline=(46, 66, 96))
        d.text((cx + 12, cy + ch - 19), lab, fill=(120, 200, 255))
    sheet.save(OUT)
    print("SHEET", OUT, sheet.size)


if __name__ == "__main__":
    main()
