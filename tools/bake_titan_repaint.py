#!/usr/bin/env python3
"""Repaint the player mech: throw away Meshy's muddy olive albedo and give it a clean
premium PAINT job, then bake 4-dir animated sheets (Cycles CPU, no GPU).

The whole model is ONE image texture (body + warm visor/core baked in), so we repaint in
shader nodes:
  - BODY  -> the texture's LUMINANCE drives a steel gradient (dark gunmetal -> light steel,
             faint cool tint). This ditches the olive hue entirely and reads as painted metal
             with panel tonal variation. High metallic so the rim light rakes across it.
  - ACCENT-> warm/orange pixels (R dominant + bright) become EMISSIVE (visor, core), tinted to
             the chosen accent, and darkened in the diffuse so they read as glowing, not painted.
Lighting is pushed premium: strong key + vivid accent rim + cool fill; more samples for clean.

  python bake_titan_repaint.py <in.glb> <out_sheet.png> [--dirs 4] [--frames 8] [--res 256]
        [--samples 40] [--accent 0.30,0.9,1.0] [--steel_lo 0.09,0.11,0.14]
        [--steel_hi 0.60,0.65,0.73]
"""
import bpy, sys, os, math, mathutils
from PIL import Image


def argval(flag, default, cast=float):
    a = sys.argv
    return cast(a[a.index(flag) + 1]) if flag in a else default

def argvec(flag, default):
    a = sys.argv
    if flag in a:
        return tuple(float(x) for x in a[a.index(flag) + 1].split(","))
    return default

GLB = os.path.abspath(sys.argv[1])
OUT = os.path.abspath(sys.argv[2])
FRAMES = int(argval("--frames", 8))
RES = int(argval("--res", 256))
EL = argval("--el", 40.0)
YAW = argval("--yaw", 0.0)
SAMPLES = int(argval("--samples", 40))
NDIRS = int(argval("--dirs", 4))
ACCENT = argvec("--accent", (0.30, 0.9, 1.0))
STEEL_LO = argvec("--steel_lo", (0.09, 0.11, 0.14))
STEEL_HI = argvec("--steel_hi", (0.60, 0.65, 0.73))
TMP = os.path.join(os.path.dirname(OUT) or ".", "_repframe.png")


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
    sc.view_settings.view_transform = "Filmic"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.07, 0.08, 0.12, 1.0)
    bg.inputs["Strength"].default_value = 0.35

    def sun(name, e, rot, col=(1, 1, 1), ang=5):
        d = bpy.data.lights.new(name, type="SUN"); d.energy = e; d.color = col
        d.angle = math.radians(ang)
        o = bpy.data.objects.new(name, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
    sun("key",  5.4, (52, 8, -34), (1.0, 0.96, 0.88))          # strong warm key
    sun("fill", 1.3, (66, -6, 46), (0.72, 0.83, 1.0))          # cool fill
    # accent rim from behind -> a bright premium edge in the accent hue
    sun("rim",  6.5, (-34, 0, 158), (ACCENT[0]*0.7+0.3, ACCENT[1]*0.7+0.3, ACCENT[2]*0.7+0.3), ang=3)
    sun("rim2", 2.6, (-30, 0, -150), (1.0, 0.85, 0.6))         # opposite warm kicker


def repaint(objs):
    """Rewire the single Meshy material into a clean steel + emissive-accent paint."""
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if not m or not m.use_nodes:
                continue
            nt = m.node_tree
            img = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image), None)
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None:
                continue
            # ---- BODY: luminance of the albedo -> steel gradient ----
            if img is not None:
                lum = nt.nodes.new("ShaderNodeRGBToBW")
                nt.links.new(img.outputs["Color"], lum.inputs["Color"])
                ramp = nt.nodes.new("ShaderNodeValToRGB")
                ramp.color_ramp.elements[0].position = 0.12
                ramp.color_ramp.elements[0].color = (*STEEL_LO, 1.0)
                ramp.color_ramp.elements[1].position = 0.82
                ramp.color_ramp.elements[1].color = (*STEEL_HI, 1.0)
                nt.links.new(lum.outputs["Val"], ramp.inputs["Fac"])
                # ---- ACCENT mask: warm (R dominant) AND bright ----
                sep = nt.nodes.new("ShaderNodeSeparateColor")
                nt.links.new(img.outputs["Color"], sep.inputs["Color"])
                gb_max = nt.nodes.new("ShaderNodeMath"); gb_max.operation = "MAXIMUM"
                nt.links.new(sep.outputs["Green"], gb_max.inputs[0])
                nt.links.new(sep.outputs["Blue"], gb_max.inputs[1])
                warm = nt.nodes.new("ShaderNodeMath"); warm.operation = "SUBTRACT"
                nt.links.new(sep.outputs["Red"], warm.inputs[0])
                nt.links.new(gb_max.outputs["Value"], warm.inputs[1])
                gain = nt.nodes.new("ShaderNodeMath"); gain.operation = "MULTIPLY"
                gain.inputs[1].default_value = 6.0
                nt.links.new(warm.outputs["Value"], gain.inputs[0])
                bright = nt.nodes.new("ShaderNodeMath"); bright.operation = "MULTIPLY"
                nt.links.new(gain.outputs["Value"], bright.inputs[0])
                nt.links.new(sep.outputs["Red"], bright.inputs[1])   # only where actually lit
                mask = nt.nodes.new("ShaderNodeClamp")
                nt.links.new(bright.outputs["Value"], mask.inputs["Value"])
                # base color = steel, darkened where the accent glows
                dark = nt.nodes.new("ShaderNodeMix"); dark.data_type = "RGBA"
                dark.inputs["B"].default_value = (0.02, 0.02, 0.03, 1.0)
                nt.links.new(ramp.outputs["Color"], dark.inputs["A"])
                nt.links.new(mask.outputs["Result"], dark.inputs["Factor"])
                nt.links.new(dark.outputs["Result"], bsdf.inputs["Base Color"])
                # emission = accent where masked
                ecol = nt.nodes.new("ShaderNodeRGB"); ecol.outputs[0].default_value = (*ACCENT, 1.0)
                nt.links.new(ecol.outputs["Color"], bsdf.inputs["Emission Color"])
                estr = nt.nodes.new("ShaderNodeMath"); estr.operation = "MULTIPLY"
                estr.inputs[1].default_value = 7.0
                nt.links.new(mask.outputs["Result"], estr.inputs[0])
                nt.links.new(estr.outputs["Value"], bsdf.inputs["Emission Strength"])
                # roughness varies with luminance -> panels vs crevices
                rr = nt.nodes.new("ShaderNodeMapRange")
                rr.inputs["To Min"].default_value = 0.28
                rr.inputs["To Max"].default_value = 0.52
                nt.links.new(lum.outputs["Val"], rr.inputs["Value"])
                nt.links.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
            bsdf.inputs["Metallic"].default_value = 0.9


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
        raise RuntimeError("no mesh")
    if YAW:
        for o in bpy.context.scene.objects:
            if o.parent is None:
                o.rotation_euler.z += math.radians(YAW)
    setup_render()
    repaint(objs)
    sc = bpy.context.scene
    f0, f1 = sc.frame_start, sc.frame_end
    if f1 <= f0:
        f1 = f0 + 24
    frames = [int(round(f0 + (f1 - f0) * i / FRAMES)) for i in range(FRAMES)]
    sc.frame_set(frames[0])
    mn0, mx0 = frame_bounds(objs)
    center0 = (mn0 + mx0) * 0.5
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
    stem, ext = os.path.splitext(OUT)
    for suffix, az in DIRS.get(NDIRS, DIRS[1]):
        tiles = []
        for f in frames:
            sc.frame_set(f)
            mn, mx = frame_bounds(objs)
            cen = (mn + mx) * 0.5; cen.z = center0.z
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
    print("REPAINTED", OUT, "dirs", NDIRS, "frames", FRAMES)


if __name__ == "__main__":
    main()
