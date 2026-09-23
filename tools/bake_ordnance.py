# -*- coding: utf-8 -*-
"""Modelise + rend des PROJECTILES d'ordnance 3D (bpy Cycles CPU), assortis aux mechs :
- OGIVE (missile a tete explosive) pour le tir lourd du boss
- OBUS (obus d'artillerie) pour le canon lourd du gunner
Rendus pointant vers +X (droite) en vue 3/4 top-down -> tourne proprement en jeu (rotation=dir.angle()).
Sorties : game/assets/weapons/ogive.png, obus.png (+ montage catalogue)."""
import bpy, os, math, mathutils
from PIL import Image, ImageDraw

OUTW = os.path.abspath("game/assets/weapons"); os.makedirs(OUTW, exist_ok=True)
SHOW = os.path.abspath("cine/_show"); RES = 200

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 28; sc.cycles.use_denoising = True
    sc.render.resolution_x = RES; sc.render.resolution_y = RES; sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"; sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes.get("Background"); bg.inputs["Color"].default_value = (0.16, 0.17, 0.2, 1); bg.inputs["Strength"].default_value = 0.55
    def sun(e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new("s", type="SUN"); d.energy = e; d.color = col; d.angle = math.radians(7)
        o = bpy.data.objects.new("s", d); sc.collection.objects.link(o); o.rotation_euler = tuple(math.radians(a) for a in rot)
    sun(4.2, (52, 8, -28)); sun(1.8, (60, -12, 60), (0.82, 0.88, 1)); sun(2.4, (-42, 0, 150), (0.85, 0.9, 1))
    return sc

def mat(name, rgb, metal=1.0, rough=0.42, emit=None, estr=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = estr
    return m

def cyl(r, d, loc, rotY=True, mat_=None, verts=28):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d, vertices=verts, location=loc)
    o = bpy.context.active_object
    if rotY: o.rotation_euler = (0, math.radians(90), 0)   # axe -> X
    if mat_: o.data.materials.append(mat_)
    return o

def cone(r1, r2, d, loc, mat_=None):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=d, vertices=28, location=loc)
    o = bpy.context.active_object; o.rotation_euler = (0, math.radians(90), 0)
    if mat_: o.data.materials.append(mat_)
    return o

def render(name, montage_dr=None, mi=0):
    sc = bpy.context.scene
    objs = [o for o in sc.objects if o.type == "MESH"]
    mn = mathutils.Vector((1e9,) * 3); mx = -mn; dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            wv = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3): mn[i] = min(mn[i], wv[i]); mx[i] = max(mx[i], wv[i])
    cen = (mn + mx) * 0.5; size = max((mx - mn).x, (mx - mn).y, (mx - mn).z, 1e-3)
    cam_d = bpy.data.cameras.new("c"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.25
    cam = bpy.data.objects.new("c", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    e = math.radians(60); dist = size * 4     # vue 3/4 top-down depuis -Y
    cam.location = (cen.x, cen.y - dist * math.cos(e), cen.z + dist * math.sin(e))
    look = cen - mathutils.Vector(cam.location); cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    tmp = os.path.join(SHOW, "_ordtmp.png")
    sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
    im = Image.open(tmp).convert("RGBA")
    # trim + save carre
    bb = im.getbbox()
    if bb: im = im.crop(bb)
    sq = max(im.size); canvas = Image.new("RGBA", (sq, sq), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((sq - im.width) // 2, (sq - im.height) // 2))
    canvas = canvas.resize((128, 128), Image.LANCZOS)
    canvas.save(os.path.join(OUTW, "%s.png" % name))
    if montage_dr is not None:
        bg = Image.new("RGBA", (200, 200), (26, 28, 34, 255)); disp = canvas.resize((150, 150))
        bg.alpha_composite(disp, (25, 25)); montage_dr[0].paste(bg.convert("RGB"), (mi * 210 + 10, 30))
        montage_dr[1].text((mi * 210 + 14, 8), name.upper(), fill=(235, 235, 245))
    print("RENDERED", name)

# ---------------- OGIVE (missile a tete explosive) ----------------
reset()
STEEL = mat("steel", (0.34, 0.36, 0.4), 1.0, 0.36)
DARK = mat("dark", (0.12, 0.13, 0.15), 1.0, 0.5)
WARHEAD = mat("warhead", (0.62, 0.10, 0.06), 0.4, 0.4, emit=(1.0, 0.24, 0.12), estr=1.2)   # tete rouge (leger glow chaud)
NOZZLE = mat("nozzle", (0.9, 0.5, 0.16), 0.2, 0.55, emit=(1.0, 0.55, 0.18), estr=2.4)
cyl(0.12, 0.66, (0, 0, 0), mat_=STEEL)                         # corps
cone(0.12, 0.005, 0.30, (0.48, 0, 0), mat_=WARHEAD)            # ogive rouge (nez +X)
band = cyl(0.128, 0.05, (0.14, 0, 0), mat_=DARK)              # anneau sombre
cyl(0.10, 0.06, (-0.35, 0, 0), mat_=NOZZLE)                    # tuyere arriere
# ailettes (3) a l'arriere
for k in range(3):
    a = math.radians(90 + k * 120)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-0.28, 0, 0))
    f = bpy.context.active_object; f.scale = (0.11, 0.015, 0.13)
    f.rotation_euler = (a, 0, 0)
    f.data.materials.append(DARK)
render("ogive")

# ---------------- OBUS (obus d'artillerie lourd) ----------------
reset()
BRASS = mat("brass", (0.72, 0.52, 0.18), 1.0, 0.3)
OLIVE = mat("olive", (0.28, 0.30, 0.16), 0.85, 0.45)
STEEL2 = mat("steel2", (0.4, 0.42, 0.46), 1.0, 0.34)
REDTIP = mat("redtip", (0.7, 0.12, 0.08), 0.4, 0.4, emit=(1.0, 0.28, 0.14), estr=1.0)
cyl(0.16, 0.36, (-0.18, 0, 0), mat_=BRASS)                    # douille laiton (arriere)
cyl(0.168, 0.05, (0.02, 0, 0), mat_=STEEL2)                   # ceinture
cyl(0.16, 0.30, (0.14, 0, 0), mat_=OLIVE)                     # corps obus (olive)
cone(0.16, 0.02, 0.30, (0.44, 0, 0), mat_=OLIVE)              # ogive olive
cone(0.05, 0.005, 0.09, (0.60, 0, 0), mat_=REDTIP)           # pointe rouge
render("obus")

# ---------------- montage catalogue ----------------
canvas = Image.new("RGB", (2 * 210 + 20, 240), (20, 22, 28)); dr = ImageDraw.Draw(canvas)
reset(); STEEL = mat("s", (0.34, 0.36, 0.4)); DARK = mat("d", (0.12, 0.13, 0.15), rough=0.5)
WARHEAD = mat("w", (0.62, 0.10, 0.06), 0.4, 0.4, emit=(1, 0.24, 0.12), estr=1.2); NOZZLE = mat("n", (0.9, 0.5, 0.16), 0.2, 0.55, emit=(1, 0.55, 0.18), estr=2.4)
cyl(0.12, 0.66, (0, 0, 0), mat_=STEEL); cone(0.12, 0.005, 0.30, (0.48, 0, 0), mat_=WARHEAD); cyl(0.128, 0.05, (0.14, 0, 0), mat_=DARK); cyl(0.10, 0.06, (-0.35, 0, 0), mat_=NOZZLE)
for k in range(3):
    a = math.radians(90 + k * 120); bpy.ops.mesh.primitive_cube_add(size=1, location=(-0.28, 0, 0)); f = bpy.context.active_object; f.scale = (0.11, 0.015, 0.13); f.rotation_euler = (a, 0, 0); f.data.materials.append(DARK)
render("ogive", (canvas, dr), 0)
reset(); BRASS = mat("b", (0.72, 0.52, 0.18)); OLIVE = mat("o", (0.28, 0.30, 0.16), 0.85, 0.45); STEEL2 = mat("s2", (0.4, 0.42, 0.46)); REDTIP = mat("r", (0.7, 0.12, 0.08), 0.4, 0.4, emit=(1, 0.28, 0.14), estr=1.0)
cyl(0.16, 0.36, (-0.18, 0, 0), mat_=BRASS); cyl(0.168, 0.05, (0.02, 0, 0), mat_=STEEL2); cyl(0.16, 0.30, (0.14, 0, 0), mat_=OLIVE); cone(0.16, 0.02, 0.30, (0.44, 0, 0), mat_=OLIVE); cone(0.05, 0.005, 0.09, (0.60, 0, 0), mat_=REDTIP)
render("obus", (canvas, dr), 1)
canvas.save(os.path.join(SHOW, "ordnance_catalog.png"))
print("DONE")
