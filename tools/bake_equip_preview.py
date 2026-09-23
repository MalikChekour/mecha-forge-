# -*- coding: utf-8 -*-
"""Prototype 'fait maison' (Claude, pas de generateur d'image) : MODELISE un canon d'epaule en bpy,
l'ATTACHE a l'os d'epaule (LeftArm) du vortex, et le rend DANS la vraie perspective 3/4 (mech+canon
ensemble => occlusion + anim correctes). Sort un montage 4 directions pour validation.
  python bake_equip_preview.py
"""
import bpy, os, math, mathutils
from PIL import Image, ImageDraw

src = open("tools/build_vortex_gun_anims.py").read().replace("\nmain()\n", "\n")
g = {"__name__": "bg"}
exec(compile(src, "bvg", "exec"), g)
RES = g["RES"]; EL = g["EL"]; FRAMES = g["FRAMES"]

sc = g["setup_scene"](); arm = g["get_armature"]()
mech = [o for o in sc.objects if o.type == "MESH"]
g["pose_idle"](arm, 0, FRAMES); bpy.context.view_layer.update()
mmn, mmx = g["bbox"](mech); center0 = (mmn + mmx) * 0.5
mech_h = mmx.z - mmn.z
size = max((mmx - mmn).x, (mmx - mmn).y, (mmx - mmn).z, 1e-3)


def mat(name, rgb, metal=1.0, rough=0.4, emit=None, estr=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal; b.inputs["Roughness"].default_value = rough
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = estr
    return m


GUN = mat("eq_gun", (0.09, 0.10, 0.12), 1.0, 0.42)
STEEL = mat("eq_steel", (0.26, 0.28, 0.32), 1.0, 0.36)
CYAN = mat("eq_cyan", (0.1, 0.7, 0.85), 0.3, 0.3, emit=(0.15, 0.85, 1.0), estr=3.0)
MUZ = mat("eq_muz", (0.1, 0.1, 0.12), 1.0, 0.5, emit=(0.2, 0.9, 1.0), estr=2.0)


def _apply(o):
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)   # fige tout dans la geometrie


def cyl(r, d, loc, axis="Y", m=None, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d, vertices=verts, location=loc)
    o = bpy.context.active_object
    if axis == "Y": o.rotation_euler = (math.radians(90), 0, 0)
    elif axis == "X": o.rotation_euler = (0, math.radians(90), 0)
    if m: o.data.materials.append(m)
    _apply(o)
    return o


def box(sx, sy, sz, loc, m=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object; o.scale = (sx, sy, sz)
    if m: o.data.materials.append(m)
    _apply(o)
    return o


def build_cannon(scale):
    # canon d'epaule PROPRE facon gunner : metal sombre, barillet long -Y, petite lueur cyan a la bouche.
    parts = []
    L = 0.5 * scale     # barillet COURT (pod trapu) = lit pareil sous tous les angles
    r = 0.13 * scale
    parts.append(box(0.40 * scale, 0.40 * scale, 0.34 * scale, (0, 0.12 * scale, 0.0), GUN))   # housing trapu (sombre)
    parts.append(box(0.06 * scale, 0.02 * scale, 0.32 * scale, (0.205 * scale, 0.12 * scale, 0.0), CYAN))  # fine ligne cyan (cote)
    parts.append(box(0.06 * scale, 0.02 * scale, 0.32 * scale, (-0.205 * scale, 0.12 * scale, 0.0), CYAN))
    parts.append(cyl(r, L, (0, -L * 0.5, 0.0), "Y", GUN))                       # barillet court epais
    parts.append(cyl(r * 1.1, 0.10 * scale, (0, -L * 0.9, 0.0), "Y", GUN))      # frein de bouche
    parts.append(cyl(r * 0.55, 0.05 * scale, (0, -L - 0.02 * scale, 0.0), "Y", MUZ))  # lueur bouche discrete
    parts.append(cyl(r * 0.5, 0.05 * scale, (0, -0.02 * scale, 0.0), "Y", CYAN))  # bague cyan a la base
    parts.append(box(0.28 * scale, 0.24 * scale, 0.12 * scale, (0, 0.14 * scale, -0.2 * scale), STEEL))  # collier de fixation
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    return bpy.context.active_object


cannon = build_cannon(mech_h * 0.3)   # canon d'epaule (~30% hauteur mecha)

# --- place le canon SUR l'epaule gauche (pose walk f2), barrel vers l'avant (-Y) ---
g["pose_walk"](arm, 2, FRAMES); bpy.context.view_layer.update()
sh = arm.matrix_world @ arm.pose.bones["LeftArm"].head
cannon.location = (sh.x + mech_h * 0.05, sh.y - mech_h * 0.04, sh.z + mech_h * 0.09)
cannon.rotation_euler = (math.radians(-8), 0, math.radians(30))   # avant-exterieur modere
bpy.context.view_layer.update()

# --- camera bake exacte ---
cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.22
cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
sc.render.resolution_x = RES; sc.render.resolution_y = RES; sc.render.film_transparent = True
e = math.radians(EL); dist = size * 4.0
def aim(c, az):
    a = math.radians(az)
    cam.location = (c.x + dist * math.cos(e) * math.sin(a), c.y - dist * math.cos(e) * math.cos(a), c.z + dist * math.sin(e))
    cam.rotation_euler = (c - mathutils.Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()

DIRS = [("front", 0), ("back", 180), ("left", 90), ("right", -90)]
tiles = []
for dname, az in DIRS:
    g["pose_walk"](arm, 2, FRAMES); bpy.context.view_layer.update()
    mn, mx = g["bbox"](mech); cen = (mn + mx) * 0.5; cen.z = center0.z
    aim(cen, az)
    tmp = os.path.abspath("cine/_show/_eqp_%s.png" % dname)
    sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
    tiles.append((dname, Image.open(tmp).convert("RGBA").copy()))

out_img = Image.new("RGB", (RES * 4 + 20, RES + 20), (24, 26, 32)); dr = ImageDraw.Draw(out_img)
for i, (dname, im) in enumerate(tiles):
    bg = Image.new("RGBA", im.size, (30, 32, 40, 255)); bg.alpha_composite(im)
    out_img.paste(bg.convert("RGB"), (i * RES + 5, 18)); dr.text((i * RES + 8, 4), dname, fill=(235, 235, 245))
out_img.save("cine/_show/equip_3d.png"); print("SAVED equip_3d")
