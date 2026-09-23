#!/usr/bin/env python3
"""Bake an animated Mixamo FBX to a 4-dir spritesheet, but RE-TEXTURE the mesh with the
albedo from the original TRELLIS GLB (Mixamo's round-trip darkens/loses the color; the GLB
keeps the crimson, and Mixamo preserves UVs so it maps correctly).

  python bake_anim_recolor.py <anim.fbx> <albedo.glb> <out.png> [--frames 8] [--res 256] [--el 40] [--dirs 4]
"""
import bpy, sys, os, math, mathutils
from PIL import Image

def argval(flag, default, cast=float):
    a = sys.argv
    return cast(a[a.index(flag) + 1]) if flag in a else default

FBX = os.path.abspath(sys.argv[1])
GLB = os.path.abspath(sys.argv[2])
OUT = os.path.abspath(sys.argv[3])
FRAMES = int(argval("--frames", 8)); RES = int(argval("--res", 256))
EL = argval("--el", 40.0); SAMPLES = int(argval("--samples", 26))
TMP = os.path.join(os.path.dirname(OUT) or ".", "_animframe.png")


def grab_albedo_image():
    """Import the GLB, return its base-color image datablock, then delete GLB objects."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=GLB)
    img = None
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                bc = n.inputs["Base Color"]
                if bc.is_linked and bc.links[0].from_node.type == "TEX_IMAGE":
                    img = bc.links[0].from_node.image
    if img is None:  # fallback: largest image datablock
        cands = [i for i in bpy.data.images if i.size[0] > 1]
        if cands:
            img = max(cands, key=lambda i: i.size[0] * i.size[1])
    for o in list(set(bpy.data.objects) - before):  # remove GLB geometry, keep image
        bpy.data.objects.remove(o, do_unlink=True)
    return img


def apply_albedo(img):
    img.colorspace_settings.name = "sRGB"
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        for m in o.data.materials:
            if not m or not m.use_nodes:
                continue
            nt = m.node_tree
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if not bsdf:
                continue
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = img
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Metallic"].default_value = 0.0   # avoid the dark metal look
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.4


def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = RES; sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.11, 0.12, 0.16, 1.0)
    bg.inputs["Strength"].default_value = 0.9      # brighter ambient so the crimson reads
    def sun(name, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(name, type="SUN"); d.energy = e; d.color = col; d.angle = math.radians(6)
        o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
    sun("key", 5.6, (52, 8, -34), (1.0, 0.97, 0.92))
    sun("fill", 2.2, (66, -6, 46), (0.8, 0.88, 1.0))
    sun("rim", 4.5, (-38, 0, 160), (0.8, 0.95, 1.0))


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def frame_bounds(objs):
    mn = mathutils.Vector((1e9,)*3); mx = -mn
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            wv = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], wv[i]); mx[i] = max(mx[i], wv[i])
    return mn, mx


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    albedo = grab_albedo_image()
    bpy.ops.import_scene.fbx(filepath=FBX, automatic_bone_orientation=True)
    if albedo is not None:
        apply_albedo(albedo)
    else:
        print("WARN no albedo image found")
    setup_render()
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
    print("ACTION RANGE", f0, f1)
    # sample across [f0, f1) (exclusive end so the loop's last frame != first frame)
    frames = [int(round(f0 + (f1 - f0) * i / FRAMES)) for i in range(FRAMES)]
    sc.frame_set(frames[0])
    objs = meshes()
    mn0, mx0 = frame_bounds(objs); center0 = (mn0 + mx0) * 0.5
    size = max((mx0 - mn0).x, (mx0 - mn0).y, (mx0 - mn0).z, 1e-3)
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.12
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    e = math.radians(EL); dist = size * 4.0
    def aim(center, az):
        a = math.radians(az)
        cam.location = (center.x + dist * math.cos(e) * math.sin(a),
                        center.y - dist * math.cos(e) * math.cos(a),
                        center.z + dist * math.sin(e))
        look = center - mathutils.Vector(cam.location)
        cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    DIRS = {1: [("", 0)], 4: [("_front", 0), ("_back", 180), ("_left", 90), ("_right", -90)]}
    ndirs = int(argval("--dirs", 1))
    stem, ext = os.path.splitext(OUT)
    for suffix, az in DIRS.get(ndirs, DIRS[1]):
        tiles = []
        for f in frames:
            sc.frame_set(f)
            mn, mx = frame_bounds(objs); cen = (mn + mx) * 0.5; cen.z = center0.z
            aim(cen, az)
            sc.render.filepath = TMP
            bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(TMP).convert("RGBA").copy())
        sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
        for k, im in enumerate(tiles):
            sheet.paste(im, (RES * k, 0), im)
        sheet.save(stem + suffix + ext)
    if os.path.exists(TMP):
        os.remove(TMP)
    print("RECOLOR SHEET", OUT, "dirs", ndirs, "frames", FRAMES)


if __name__ == "__main__":
    main()
