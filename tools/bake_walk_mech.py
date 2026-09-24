#!/usr/bin/env python3
"""
mecha-forge — remplace la planche WALK (uniquement) de titan/bruiser/vanquisher par la
demarche de la bibliotheque d'animations Meshy « Carry Heavy Cannon Forward » (action_id 610,
variante in-place — sans root motion), au lieu de la choregraphie main (copiee de vortex).

🚨 POURQUOI (patron, 24/09) : « passe par meshy pour donner une demarche de mecha robot a
titan, vanquisher, et bruiser ». Contrairement aux poses precedentes (bpy, formules main —
cf. build_titan_anims.py, build_bruiser_anims.py, build_vanquisher_anims.py), ceci echantillonne
une VRAIE animation de la bibliotheque Meshy (capture de mouvement humaine retargetee sur le
rig), pas une formule trigonometrique ecrite a la main. Recherche via l'endpoint gratuit
GET /v1/animations/library?search=... : aucune animation "mech"/"robot"/"armor" nommee
explicitement, mais « Carry Heavy Cannon Forward » (WalkAndRun/Walking) porte une arme en
avant — coherent avec les 3 chassis, qui tiennent tous une arme lourde.

Seule la planche WALK change. idle/run/attack/hit/die/melee restent la choregraphie vortex
(build_<nom>_anims.py) — non touchees par ce script.

Usage : python bake_walk_mech.py <chassis>   (attend meshy_in/<chassis>/anim_walk_mech.glb,
deja telecharge par meshy_client.py animate <rig_task_id> 610 --name <chassis> --label walk_mech)
"""
import bpy, sys, os, math, mathutils
from PIL import Image

CHASSIS = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[-1]
GLB_IN = os.path.abspath("meshy_in/%s/anim_walk_mech.glb" % CHASSIS)
OUT_DIR = os.path.abspath("game/assets/mecha")
RES = 512
FRAMES = 8
SAMPLES = 16
EL = 40.0

def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB_IN)
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
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.08, 0.09, 0.13, 1.0)
        bg.inputs["Strength"].default_value = 0.45
    def sun(name, e, rot, col=(1, 1, 1)):
        d = bpy.data.lights.new(name, type="SUN")
        d.energy = e; d.color = col; d.angle = math.radians(5)
        o = bpy.data.objects.new(name, d)
        sc.collection.objects.link(o)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
    sun("key", 4.5, (52, 8, -34), (1.0, 0.95, 0.88))
    sun("fill", 1.8, (66, -6, 46), (0.75, 0.85, 1.0))
    sun("rim", 4.0, (-38, 0, 160), (0.7, 0.95, 1.0))
    return sc

def get_armature():
    for o in bpy.context.scene.objects:
        if o.type == "ARMATURE":
            return o
    raise RuntimeError("No armature found")

def get_meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]

def frame_bounds(objs):
    mn = mathutils.Vector((1e9, 1e9, 1e9))
    mx = -mn
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            w = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i])
                mx[i] = max(mx[i], w[i])
    return mn, mx

def main():
    sc = setup_scene()
    arm = get_armature()
    objs = get_meshes()

    act = arm.animation_data.action if arm.animation_data else None
    if act is None:
        raise RuntimeError("no animation action found in %s" % GLB_IN)
    f0, f1 = act.frame_range
    print("action:", act.name, "frame_range:", f0, f1)

    def set_frame(t):  # t in [0,1)
        sc.frame_set(int(round(f0 + (f1 - f0) * t)))

    set_frame(0.0)
    bpy.context.view_layer.update()
    mn0, mx0 = frame_bounds(objs)
    center0 = (mn0 + mx0) * 0.5
    size = max((mx0 - mn0).x, (mx0 - mn0).y, (mx0 - mn0).z, 1e-3)

    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = size * 1.12
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    e = math.radians(EL)
    dist = size * 4.0

    def aim_cam(center, az_deg):
        a = math.radians(az_deg)
        cam.location = (
            center.x + dist * math.cos(e) * math.sin(a),
            center.y - dist * math.cos(e) * math.cos(a),
            center.z + dist * math.sin(e),
        )
        look = center - mathutils.Vector(cam.location)
        cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

    tmp_png = os.path.join(OUT_DIR, "_tmp_walkmech.png")
    DIRS = [("front", 0), ("back", 180), ("left", 90), ("right", -90)]

    print("=== BAKING WALK (Meshy Carry_Heavy_Cannon_Forward) FOR %s ===" % CHASSIS.upper())
    for dir_name, az in DIRS:
        tiles = []
        for f in range(FRAMES):
            set_frame(f / FRAMES)
            bpy.context.view_layer.update()
            mn, mx = frame_bounds(objs)
            cen = (mn + mx) * 0.5
            cen.z = center0.z
            aim_cam(cen, az)
            sc.render.filepath = tmp_png
            bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(tmp_png).convert("RGBA").copy())
        sheet = Image.new("RGBA", (RES * FRAMES, RES), (0, 0, 0, 0))
        for k, im in enumerate(tiles):
            sheet.paste(im, (RES * k, 0), im)
        out_png = os.path.join(OUT_DIR, "%s_walk_%s.png" % (CHASSIS, dir_name))
        sheet.save(out_png)
        frame0 = sheet.crop((0, 0, RES, RES))
        bbox = frame0.getbbox()
        h = bbox[3] - bbox[1] if bbox else 0
        print("  %s: %dpx (%.1f%%)" % (out_png, h, h / float(RES) * 100.0))

    if os.path.exists(tmp_png):
        os.remove(tmp_png)
    print("=== DONE %s ===" % CHASSIS)

if __name__ == "__main__":
    main()
