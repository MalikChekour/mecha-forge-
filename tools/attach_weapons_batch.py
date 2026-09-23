"""Attach each 3D weapon into VORTEX's right hand and render a front 'hold' preview (weapon rendered
WITH the mech -> truly held, not pasted). Barrel auto-oriented to point RIGHT (thin end -> +X).
Outputs cine/_show/vortex_hold_<weapon>.png for the validation catalog."""
import bpy, math, mathutils, os

def R(d):
    return math.radians(d)

WEAPONS = ["energy_rifle", "plasma_cannon", "laser_blaster", "gauss_rifle"]
LEN_FRAC = {"energy_rifle": 0.50, "plasma_cannon": 0.48, "laser_blaster": 0.40, "gauss_rifle": 0.54}
GRIP = {"energy_rifle": (0.60, 0.30), "plasma_cannon": (0.66, 0.34),
        "laser_blaster": (0.52, 0.34), "gauss_rifle": (0.60, 0.30)}


def bbox(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    mn = mathutils.Vector((1e9, 1e9, 1e9)); mx = -mn
    for o in objs:
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            w = oe.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i]); mx[i] = max(mx[i], w[i])
    return mn, mx


def half_z_extent(objs, take_min_x):
    """Z-thickness of the vertices on the min-X (barrel?) or max-X half — thinner half = the barrel."""
    dg = bpy.context.evaluated_depsgraph_get()
    mn, mx = bbox(objs); midx = (mn.x + mx.x) * 0.5
    zmin, zmax = 1e9, -1e9
    for o in objs:
        oe = o.evaluated_get(dg); m = oe.matrix_world
        for v in oe.data.vertices:
            w = m @ v.co
            if (w.x < midx) == take_min_x:
                zmin = min(zmin, w.z); zmax = max(zmax, w.z)
    return zmax - zmin


def setup_mech():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/vortex/rigged.glb"))
    sc = bpy.context.scene
    arm = [o for o in sc.objects if o.type == "ARMATURE"][0]
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    for n, r in {"Spine": (R(-4), 0, 0), "RightArm": (R(-46), R(-10), R(8)), "RightForeArm": (R(-58), 0, 0),
                 "LeftArm": (R(-34), R(12), R(-10)), "LeftForeArm": (R(-58), 0, 0)}.items():
        if n in pb:
            pb[n].rotation_euler = r
    bpy.context.view_layer.update()
    mech = [o for o in sc.objects if o.type == "MESH"]
    hand = (arm.matrix_world @ pb["RightHand"].head)
    mmn, mmx = bbox(mech); msize = max((mmx - mmn).x, (mmx - mmn).y, (mmx - mmn).z)
    cen = (mmn + mmx) * 0.5
    # camera front EL40
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 24
    sc.render.resolution_x = 460; sc.render.resolution_y = 460; sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"
    cam_d = bpy.data.cameras.new("c"); cam_d.type = "ORTHO"; cam_d.ortho_scale = msize * 1.3
    cam = bpy.data.objects.new("c", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    e = R(40); dist = msize * 4
    cam.location = (cen.x, cen.y - dist * math.cos(e), cen.z + dist * math.sin(e))
    cam.rotation_euler = (cen - mathutils.Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.5
    for nm, en, ro in [("k", 4.5, (52, 8, -34)), ("f", 1.8, (66, -6, 46)), ("r", 4.0, (-38, 0, 160))]:
        d = bpy.data.lights.new(nm, "SUN"); d.energy = en
        o = bpy.data.objects.new(nm, d); sc.collection.objects.link(o)
        o.rotation_euler = tuple(R(a) for a in ro)
    return sc, arm, hand, mmn, mmx


def do_weapon(sc, arm, hand, mmn, mmx, name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/w_%s/model.glb" % name))
    wobjs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    emp = bpy.data.objects.new("wr_%s" % name, None); sc.collection.objects.link(emp)
    for o in wobjs:
        o.parent = emp
    bpy.context.view_layer.update()
    # orient longest axis -> X
    mn, mx = bbox(wobjs); dim = mx - mn
    axis = max(range(3), key=lambda i: dim[i])
    if axis == 1:
        emp.rotation_euler = mathutils.Euler((0, 0, R(-90)))
    elif axis == 2:
        emp.rotation_euler = mathutils.Euler((0, R(90), 0))
    bpy.context.view_layer.update()
    # thin end should be at +X (barrel points right); flip 180 about Z if barrel is on -X side
    if half_z_extent(wobjs, take_min_x=True) < half_z_extent(wobjs, take_min_x=False):
        emp.rotation_euler.z += R(180)
        bpy.context.view_layer.update()
    # scale to target length (fraction of mech height)
    mn, mx = bbox(wobjs); dim = mx - mn
    s = (LEN_FRAC[name] * (mmx.z - mmn.z)) / max(dim.x, 1e-3)
    emp.scale = (s, s, s)
    bpy.context.view_layer.update()
    # grip -> hand, pull toward camera so it sits in front of the torso
    mn, mx = bbox(wobjs); dim = mx - mn; cen = (mn + mx) * 0.5
    gfx, gfy = GRIP[name]
    grip = mathutils.Vector((mx.x - gfx * dim.x, cen.y, mn.z + gfy * dim.z))
    off = hand - grip; off.y -= 0.14
    emp.location += off
    bpy.context.view_layer.update()
    sc.render.filepath = os.path.abspath("cine/_show/vortex_hold_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)
    # cleanup weapon
    for o in wobjs + [emp]:
        bpy.data.objects.remove(o, do_unlink=True)


sc, arm, hand, mmn, mmx = setup_mech()
for nm in WEAPONS:
    if os.path.exists(os.path.abspath("meshy_in/w_%s/model.glb" % nm)):
        do_weapon(sc, arm, hand, mmn, mmx, nm)
    else:
        print("SKIP (no model)", nm)
print("DONE")
