"""Pieces 3D PROCEDURALES des versions MK II / III / IV de VORTEX et BLUESTRIKE (16/10).
Meme rig que le jeu (bones Mixamo de meshy_in/<base>/rigged.glb) : chaque piece est SUIVIE sur un os et recalculee a chaque
pose -> elle est dans chaque image cuite, comme le canon de bras de build_vortex_gun_anims.py.
Aucune generation IA : ce sont des primitives (boites, cylindres, cones, tores) + materiaux. Le personnage regarde -Y,
sa gauche = +X, hauteur 1,8 m. L'armature porte une echelle 0,01 : on compose toujours  monde_pose @ monde_repos^-1."""
import bpy, math
from mathutils import Vector, Matrix

R = math.radians
FWD = Vector((0, -1, 0))


def mat(name, base, metal=0.8, rough=0.4, emit=None, estr=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*base, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = estr
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
    return m


class Kit:
    def __init__(self, base):
        self.base = base
        if base == "vortex":
            self.armor = mat("mk_armor", (0.06, 0.07, 0.09), 0.8, 0.34)
            self.dark = mat("mk_dark", (0.012, 0.013, 0.018), 0.9, 0.5)
            self.glow = mat("mk_glow", (0.05, 0.4, 0.5), 0.0, 0.3, (0.1, 0.8, 1.0), 3.2)
            self.hot = mat("mk_hot", (0.6, 0.2, 0.02), 0.0, 0.3, (1.0, 0.22, 0.02), 2.6)
            self.trim = mat("mk_trim", (0.75, 0.62, 0.3), 1.0, 0.22)
        else:
            self.armor = mat("mk_armor", (0.85, 0.30, 0.04), 0.55, 0.38)
            self.dark = mat("mk_dark", (0.11, 0.12, 0.14), 0.85, 0.45)
            self.glow = mat("mk_glow", (0.05, 0.4, 0.5), 0.0, 0.3, (0.1, 0.8, 1.0), 3.2)
            self.hot = mat("mk_hot", (0.6, 0.2, 0.02), 0.0, 0.3, (1.0, 0.24, 0.02), 2.8)
            self.trim = mat("mk_trim", (0.85, 0.8, 0.7), 1.0, 0.25)
        self.wing = mat("mk_wing", (0.2, 0.8, 1.0), 0.0, 0.1, (0.2, 0.85, 1.0), 3.0, alpha=0.55)


def _add(kind, loc, size, rot=None, aim=None, m=None, name="part"):
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(radius=1, depth=1, vertices=28, location=loc)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(radius1=1, radius2=0.0, depth=1, vertices=24, location=loc)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=1, minor_radius=0.07, location=loc)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=loc)
    else:
        raise ValueError(kind)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    if aim is not None:          # l'axe Z local (cylindre/cone/tore) vise `aim`
        o.rotation_euler = Vector((0, 0, 1)).rotation_difference(Vector(aim).normalized()).to_euler()
    elif rot is not None:
        o.rotation_euler = tuple(R(a) for a in rot)
    if m is not None:
        o.data.materials.append(m)
    return o


class Parts:
    def __init__(self, arm, base, mk):
        self.arm = arm
        self.base = base
        self.mk = mk
        self.kit = Kit(base)
        self.items = []   # (obj, bone, local)
        bpy.context.view_layer.update()
        self.H = {b.name: arm.matrix_world @ b.head_local for b in arm.data.bones}
        self.rest = {b.name: arm.matrix_world @ b.matrix_local for b in arm.data.bones}

    # ------------------------------------------------------------------ outils
    def attach(self, obj, bone):
        bpy.context.view_layer.update()   # matrix_world doit refleter scale/rotation fraichement poses
        local = self.rest[bone].inverted() @ obj.matrix_world
        self.items.append((obj, bone, local))
        return obj

    def box(self, bone, loc, size, rot=None, m=None, aim=None):
        return self.attach(_add("box", loc, size, rot=rot, m=m), bone)

    def cyl(self, bone, loc, r, length, aim, m=None):
        return self.attach(_add("cyl", loc, (r, r, length), aim=aim, m=m), bone)

    def cone(self, bone, loc, r, length, aim, m=None):
        return self.attach(_add("cone", loc, (r, r, length), aim=aim, m=m), bone)

    def ring(self, bone, loc, r, aim, m=None, thick=1.0):
        return self.attach(_add("torus", loc, (r, r, r * thick), aim=aim, m=m), bone)

    def sph(self, bone, loc, r, m=None):
        return self.attach(_add("sphere", loc, (r, r, r), m=m), bone)

    def update(self):
        arm = self.arm
        for o, bone, local in self.items:
            o.matrix_world = (arm.matrix_world @ arm.pose.bones[bone].matrix) @ local

    # ------------------------------------------------------------------ gabarits
    def pauldron(self, s, big=1.0, plates=2, vents=False, edge=True):
        k = self.kit
        arm_bone = "LeftArm" if s > 0 else "RightArm"
        h = self.H[arm_bone]
        for i in range(plates):
            self.box(arm_bone, (h.x + s * (0.06 + 0.02 * i), h.y, h.z + 0.07 + 0.045 * i),
                     (0.20 * big - 0.025 * i, 0.27 * big - 0.03 * i, 0.035), rot=(0, s * -16, 0), m=k.armor)
        if edge:
            self.box(arm_bone, (h.x + s * (0.15 * big), h.y - 0.01, h.z + 0.07), (0.012, 0.25 * big, 0.02), rot=(0, s * -16, 0), m=k.glow)
        if vents:
            for j in range(3):
                self.box(arm_bone, (h.x + s * 0.09, h.y - 0.10 + 0.07 * j, h.z + 0.11), (0.10, 0.02, 0.012), rot=(0, s * -16, 0), m=k.dark)

    def forearm_cannon(self, s, length=0.46, r=0.052, barrels=1, glow=True, housing=True):
        k = self.kit
        fa = "LeftForeArm" if s > 0 else "RightForeArm"
        hd = "LeftHand" if s > 0 else "RightHand"
        d = (self.H[hd] - self.H[fa]).normalized()
        o = self.H[fa] + d * 0.02
        if housing:
            mid = o + d * 0.13
            self.attach(_add("box", mid, (0.12, 0.12, 0.26), aim=d, m=k.armor), fa)
            # la boite est creee avec Z=axe via aim ; on la recale en cylindre de carter pour l'epaisseur
        tip = o + d * length
        for b in range(barrels):
            off = Vector((0, 0, 0))
            if barrels > 1:
                a = 2 * math.pi * b / barrels
                perp1 = d.cross(Vector((1, 0, 0)))
                if perp1.length < 1e-3:
                    perp1 = d.cross(Vector((0, 0, 1)))
                perp1.normalize()
                perp2 = d.cross(perp1).normalized()
                off = (perp1 * math.cos(a) + perp2 * math.sin(a)) * r * 1.25
            rr = r if barrels == 1 else r * 0.45
            c = o + d * (length * 0.5) + off
            self.cyl(fa, c, rr, length, d, m=k.dark)
            if glow:
                self.ring(fa, o + d * (length * 0.86) + off, rr * 1.25, d, m=k.glow, thick=0.9)
            self.cyl(fa, o + d * length + off, rr * 0.7, 0.03, d, m=k.glow)
        return tip

    def palm_emitter(self, s, r=0.05):
        k = self.kit
        hd = "LeftHand" if s > 0 else "RightHand"
        fa = "LeftForeArm" if s > 0 else "RightForeArm"
        d = (self.H[hd] - self.H[fa]).normalized()
        c = self.H[hd] + d * 0.075
        self.cyl(hd, c, r * 1.3, 0.045, d, m=k.dark)
        self.cyl(hd, c + d * 0.027, r, 0.02, d, m=k.glow)

    def hand_blaster(self, s, length=0.26, r=0.075):
        k = self.kit
        hd = "LeftHand" if s > 0 else "RightHand"
        fa = "LeftForeArm" if s > 0 else "RightForeArm"
        d = (self.H[hd] - self.H[fa]).normalized()
        c = self.H[hd] + d * (length * 0.45)
        self.cyl(hd, c, r, length, d, m=k.dark)
        self.ring(hd, self.H[hd] + d * (length * 0.8), r * 1.15, d, m=k.hot, thick=0.9)
        self.cyl(hd, self.H[hd] + d * length, r * 0.8, 0.03, d, m=k.hot)

    def helmet_crest(self, big=1.0):
        k = self.kit
        h = self.H["Head"]
        top = Vector((h.x, h.y + 0.02, h.z + 0.22))
        self.attach(_add("cone", top + Vector((0, -0.02, 0.07 * big)), (0.035, 0.085 * big, 0.12 * big), aim=Vector((0, -0.25, 1)), m=k.armor), "Head")
        for s in (-1, 1):
            self.attach(_add("cone", Vector((h.x + s * 0.07, h.y + 0.04, h.z + 0.24)), (0.012, 0.012, 0.28 * big), aim=Vector((s * 0.12, 0.1, 1)), m=k.dark), "Head")

    def thruster_pack(self, flame=None, big=1.0):
        k = self.kit
        sp = self.H["Spine02"]
        for s in (-1, 1):
            c = Vector((sp.x + s * 0.12, sp.y + 0.21, sp.z + 0.30))
            self.cyl("Spine02", c, 0.07 * big, 0.26 * big, Vector((0, 0.25, -1)), m=k.dark)
            self.cyl("Spine02", c + Vector((0, 0.07, -0.15 * big)), 0.052 * big, 0.04, Vector((0, 0.25, -1)), m=flame or k.glow)
            self.cone("Spine02", c + Vector((0, 0.10, -0.26 * big)), 0.045 * big, 0.16 * big, Vector((0, -0.25, 1)), m=flame or k.glow)

    def floating_plate(self, s, halo=True):
        k = self.kit
        sp = self.H["Spine02"]
        c = Vector((sp.x + s * 0.42, sp.y + 0.02, sp.z + 0.40))
        self.attach(_add("box", c, (0.15, 0.26, 0.035), rot=(0, s * -25, 0), m=k.armor), "Spine02")
        self.attach(_add("box", c + Vector((s * 0.02, 0, 0.03)), (0.04, 0.20, 0.012), rot=(0, s * -25, 0), m=k.trim), "Spine02")
        if halo:
            self.ring("Spine02", c + Vector((0, 0, -0.09)), 0.11, Vector((0, 0, 1)), m=k.glow, thick=1.0)

    def knee_plates(self, big=1.0):
        k = self.kit
        for s, lg in ((1, "LeftLeg"), (-1, "RightLeg")):
            h = self.H[lg]
            self.box(lg, (h.x, h.y - 0.075, h.z + 0.02), (0.13 * big, 0.06, 0.15 * big), m=k.armor)
            self.box(lg, (h.x, h.y - 0.108, h.z + 0.02), (0.03, 0.012, 0.12 * big), m=k.glow)

    def chest_plate(self):
        k = self.kit
        sp = self.H["Spine02"]
        self.box("Spine02", (sp.x, sp.y - 0.15, sp.z + 0.30), (0.34, 0.07, 0.22), rot=(-8, 0, 0), m=k.armor)
        self.box("Spine02", (sp.x, sp.y - 0.19, sp.z + 0.30), (0.20, 0.012, 0.04), m=k.glow)

    def wings(self):
        k = self.kit
        sp = self.H["Spine02"]
        for s in (-1, 1):
            for j, (ln, ang) in enumerate(((0.55, 28), (0.42, 12), (0.32, -4))):
                c = Vector((sp.x + s * (0.22 + 0.16 * ln), sp.y + 0.22, sp.z + 0.45 - 0.05 * j))
                self.attach(_add("box", c, (ln, 0.012, 0.075), rot=(0, 0, s * (60 - ang)), m=k.wing), "Spine02")

    def halo(self):
        k = self.kit
        h = self.H["Head"]
        self.ring("Head", Vector((h.x, h.y + 0.03, h.z + 0.30)), 0.16, Vector((0, 0, 1)), m=k.glow, thick=0.7)

    def trim_bands(self):
        k = self.kit
        for s, fa in ((1, "LeftForeArm"), (-1, "RightForeArm")):
            h = self.H[fa]
            self.ring(fa, h + Vector((0, 0, -0.02)), 0.07, (self.H["LeftHand" if s > 0 else "RightHand"] - h).normalized(), m=k.trim, thick=0.5)


def build(arm, base, mk):
    p = Parts(arm, base, mk)
    if base == "vortex":
        if mk == 2:
            p.pauldron(1); p.pauldron(-1); p.helmet_crest(1.0)
            p.forearm_cannon(-1, length=0.63); p.palm_emitter(1); p.knee_plates()
        elif mk == 3:
            p.pauldron(1, 1.15, 3); p.pauldron(-1, 1.15, 3); p.helmet_crest(1.2); p.chest_plate()
            p.forearm_cannon(-1, length=0.63); p.forearm_cannon(1, length=0.63); p.thruster_pack(); p.knee_plates(1.15)
        elif mk == 4:
            p.pauldron(1, 1.2, 3); p.pauldron(-1, 1.2, 3); p.helmet_crest(1.35); p.chest_plate()
            p.forearm_cannon(-1, length=0.66, r=0.07, barrels=3); p.palm_emitter(1, 0.06)
            p.floating_plate(1); p.floating_plate(-1); p.knee_plates(1.2); p.halo(); p.trim_bands(); p.thruster_pack(big=1.1)
    else:
        if mk == 2:
            p.pauldron(1, 1.0, 2, vents=True); p.pauldron(-1, 1.0, 2, vents=True)
            p.hand_blaster(1); p.hand_blaster(-1); p.knee_plates(); p.chest_plate()
        elif mk == 3:
            p.pauldron(1, 1.1, 2, vents=True); p.pauldron(-1, 1.1, 2, vents=True)
            p.forearm_cannon(1, length=0.50, r=0.07, barrels=2, glow=True); p.forearm_cannon(-1, length=0.50, r=0.07, barrels=2, glow=True)
            p.thruster_pack(flame=p.kit.hot); p.knee_plates(1.15); p.chest_plate()
        elif mk == 4:
            p.pauldron(1, 1.15, 3, vents=True); p.pauldron(-1, 1.15, 3, vents=True)
            p.forearm_cannon(-1, length=0.62, r=0.08, barrels=6); p.palm_emitter(1, 0.065)
            p.wings(); p.halo(); p.knee_plates(1.2); p.chest_plate(); p.trim_bands()
    p.update()
    return p
