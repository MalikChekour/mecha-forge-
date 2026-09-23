# -*- coding: utf-8 -*-
"""Mesure les ancrages d'EPAULE du vortex en projetant les os (Left/RightShoulder, Left/RightArm)
a travers la CAMERA DE BAKE EXACTE (repliquee depuis build_vortex_gun_anims.main), par direction,
sur la pose WALK frame 2. Sort l'ancrage en repere 190 (comme _GUN_ANCHORS) + l'offset px 256 (pour le mock)."""
import bpy, os, math, mathutils
from bpy_extras.object_utils import world_to_camera_view

src = open("tools/build_vortex_gun_anims.py").read().replace("\nmain()\n", "\n")
g = {"__name__": "bg"}
exec(compile(src, "bvg", "exec"), g)
RES = g["RES"]; EL = g["EL"]; FRAMES = g["FRAMES"]

sc = g["setup_scene"](); arm = g["get_armature"]()
sc.cycles.samples = 2; sc.cycles.use_denoising = False
mech = [o for o in sc.objects if o.type == "MESH"]   # comme main() : AVANT le gun
g["pose_idle"](arm, 0, FRAMES); bpy.context.view_layer.update()
mmn, mmx = g["bbox"](mech); center0 = (mmn + mmx) * 0.5
size = max((mmx - mmn).x, (mmx - mmn).y, (mmx - mmn).z, 1e-3)
cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.22
cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
sc.render.resolution_x = RES; sc.render.resolution_y = RES
e = math.radians(EL); dist = size * 4.0

def aim(center, az):
    a = math.radians(az)
    cam.location = (center.x + dist * math.cos(e) * math.sin(a),
                    center.y - dist * math.cos(e) * math.cos(a), center.z + dist * math.sin(e))
    cam.rotation_euler = (center - mathutils.Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()

def project(world_pos):
    co = world_to_camera_view(sc, cam, world_pos)
    px = co.x * RES; py = (1.0 - co.y) * RES
    return px, py

BONES = ["LeftShoulder", "LeftArm", "RightShoulder", "RightArm"]
DIRS = [("front", 0), ("back", 180), ("left", 90), ("right", -90)]
g["pose_walk"](arm, 2, FRAMES); bpy.context.view_layer.update()   # frame 2 (comme les sheets)

print("=== ANCRAGES EPAULE VORTEX (walk f2) ===")
res = {b: {} for b in BONES}
for dname, az in DIRS:
    g["pose_walk"](arm, 2, FRAMES); bpy.context.view_layer.update()
    mn, mx = g["bbox"](mech); cen = (mn + mx) * 0.5; cen.z = center0.z
    aim(cen, az)
    bpy.context.view_layer.update()   # IMPORTANT : recalcule la matrice camera avant projection
    for bname in BONES:
        pb = arm.pose.bones.get(bname)
        if pb is None: continue
        wp = arm.matrix_world @ pb.head
        px, py = project(wp)
        anx = (px - RES / 2) * (190.0 / RES); any_ = (py - RES / 2) * (190.0 / RES)
        res[bname][dname] = (anx, any_, px, py)

for bname in BONES:
    print('\n"%s":' % bname)
    for dname, _ in DIRS:
        if dname in res[bname]:
            anx, any_, px, py = res[bname][dname]
            off256 = ((px - RES / 2) * (256.0 / RES), (py - RES / 2) * (256.0 / RES))
            print('  "%s": Vector2(%.1f, %.1f),   # px256=(%.0f,%.0f)  mockoff=(%.0f,%.0f)'
                  % (dname, anx, any_, px * 256 / RES, py * 256 / RES, off256[0], off256[1]))
print("\nDONE")
