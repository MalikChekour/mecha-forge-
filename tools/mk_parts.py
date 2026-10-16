"""Pieces 3D PROCEDURALES des versions MK II / III / IV de VORTEX et BLUESTRIKE (16/10 - Revision Qualite Visuelle).
Meme rig que le jeu (bones Mixamo de meshy_in/<base>/rigged.glb) : chaque piece est SUIVIE sur un os et recalculee a chaque
pose -> elle est dans chaque image cuite, comme le canon de bras de build_vortex_gun_anims.py.
Modelisation hard-surface avancee : chanfreins, bords biseautes (Bevel), carters sculptes, frettes lumineuses,
canons usines, tuyeres avec flamme dual-layer, et materiaux calibres (orange sature non-beige, noirs mats profonds).
Le personnage regarde -Y, sa gauche = +X, hauteur ~1,8 m. L'armature porte une echelle 0,01.
"""
import bpy, math
from mathutils import Vector, Matrix

R = math.radians
FWD = Vector((0, -1, 0))


def mat(name, base, metal=0.8, rough=0.4, emit=None, estr=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*base, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = estr
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else "HASHED"
    return m


class Kit:
    def __init__(self, base):
        self.base = base
        if base == "vortex":
            # Noir mat furtif de haute precision
            self.armor = mat("v_armor", (0.04, 0.045, 0.06), metal=0.25, rough=0.36)
            # Mecanismes et carters internes gris anthracite sombre
            self.dark = mat("v_dark", (0.015, 0.016, 0.022), metal=0.88, rough=0.45)
            # Lueur neon cyan electrique intense
            self.glow = mat("v_glow", (0.05, 0.65, 0.95), metal=0.0, rough=0.2, emit=(0.1, 0.88, 1.0), estr=3.6)
            # Coeur / accents orange braise
            self.hot = mat("v_hot", (0.95, 0.22, 0.01), metal=0.0, rough=0.25, emit=(1.0, 0.35, 0.02), estr=3.2)
            # Finitions or poli
            self.trim = mat("v_trim", (0.85, 0.70, 0.28), metal=0.96, rough=0.18)
            # Finitions chrome
            self.chrome = mat("v_chrome", (0.90, 0.92, 0.95), metal=0.98, rough=0.12)
        else: # bluestrike
            # ORANGE VIF SATURÉ (dielectrique metal=0.05, albedo rouge-orange pur -> ne vire jamais au beige)
            self.armor = mat("b_armor", (0.96, 0.13, 0.005), metal=0.06, rough=0.28)
            # Gris gunmetal / graphite contraste
            self.dark = mat("b_dark", (0.12, 0.13, 0.16), metal=0.78, rough=0.40)
            # Lueur cyan visiere et conduits d'energie
            self.glow = mat("b_glow", (0.05, 0.70, 0.98), metal=0.0, rough=0.2, emit=(0.1, 0.90, 1.0), estr=3.6)
            # Lueur flamme propulseur / bouches d'armes orange vif
            self.hot = mat("b_hot", (0.98, 0.15, 0.01), metal=0.0, rough=0.25, emit=(1.0, 0.28, 0.01), estr=3.0)
            # Visiere magenta
            self.magenta = mat("b_mag", (0.85, 0.04, 0.65), metal=0.0, rough=0.2, emit=(1.0, 0.12, 0.78), estr=3.5)
            # Finitions blanc / argent
            self.trim = mat("b_trim", (0.92, 0.92, 0.94), metal=0.85, rough=0.22)
            # Finitions or
            self.gold = mat("b_gold", (0.88, 0.72, 0.30), metal=0.95, rough=0.20)
        # Ailes d'energie translucides cyan (Bluestrike Mk IV)
        self.wing = mat("mk_wing", (0.15, 0.85, 1.0), metal=0.0, rough=0.1, emit=(0.2, 0.90, 1.0), estr=3.5, alpha=0.62)


def _add(kind, loc, size, rot=None, aim=None, m=None, name="part", bevel=0.012):
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=1.0, vertices=28, location=loc)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(radius1=1.0, radius2=0.0, depth=1.0, vertices=24, location=loc)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.1, location=loc)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=24, ring_count=16, location=loc)
    else:
        raise ValueError(kind)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    if aim is not None:
        o.rotation_euler = Vector((0, 0, 1)).rotation_difference(Vector(aim).normalized()).to_euler()
    elif rot is not None:
        o.rotation_euler = tuple(R(a) for a in rot)
    if m is not None:
        o.data.materials.append(m)
    # Bords biseautes hard-surface (chanfreins pour attraper la lumiere et eviter les blocs bruts)
    if bevel > 0.0 and kind in ("box", "cyl"):
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
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

    # ------------------------------------------------------------------ outils d'attache
    def attach(self, obj, bone):
        bpy.context.view_layer.update()
        local = self.rest[bone].inverted() @ obj.matrix_world
        self.items.append((obj, bone, local))
        return obj

    def box(self, bone, loc, size, rot=None, m=None, aim=None, bevel=0.012):
        return self.attach(_add("box", loc, size, rot=rot, aim=aim, m=m, bevel=bevel), bone)

    def cyl(self, bone, loc, r, length, aim, m=None, bevel=0.0):
        return self.attach(_add("cyl", loc, (r, r, length), aim=aim, m=m, bevel=bevel), bone)

    def cone(self, bone, loc, r, length, aim, m=None):
        return self.attach(_add("cone", loc, (r, r, length), aim=aim, m=m, bevel=0.0), bone)

    def ring(self, bone, loc, r, aim, m=None, thick=1.0):
        return self.attach(_add("torus", loc, (r, r, r * thick), aim=aim, m=m, bevel=0.0), bone)

    def sph(self, bone, loc, r, m=None):
        return self.attach(_add("sphere", loc, (r, r, r), m=m, bevel=0.0), bone)

    def update(self):
        arm = self.arm
        for o, bone, local in self.items:
            o.matrix_world = (arm.matrix_world @ arm.pose.bones[bone].matrix) @ local

    # ------------------------------------------------------------------ EPAULIERES VORTEX
    def pauldron_vortex(self, s, big=1.0, plates=2, trim_gold=False):
        k = self.kit
        arm_bone = "LeftArm" if s > 0 else "RightArm"
        h = self.H[arm_bone]
        # 1. Sous-chassis mecanique articule
        self.box(arm_bone, (h.x + s * 0.05, h.y, h.z + 0.06), (0.16 * big, 0.22 * big, 0.04), rot=(0, s * -14, 0), m=k.dark)
        # 2. Plaques superposees profilees et biseautees
        for i in range(plates):
            px = h.x + s * (0.075 + 0.026 * i)
            pz = h.z + 0.075 + 0.05 * i
            sz_x = (0.21 - 0.025 * i) * big
            sz_y = (0.28 - 0.03 * i) * big
            # Plaque d'armure principale
            self.box(arm_bone, (px, h.y, pz), (sz_x, sz_y, 0.036), rot=(0, s * -16, 0), m=k.armor, bevel=0.015)
            # Lisere neon cyan le long de la bordure exterieure
            self.box(arm_bone, (px + s * (sz_x * 0.48), h.y - 0.005, pz + 0.002), (0.014, sz_y * 0.94, 0.018), rot=(0, s * -16, 0), m=k.glow)
        # 3. Events de refroidissement sous l'armure
        for j in range(3):
            vy = h.y - 0.09 + 0.07 * j
            self.box(arm_bone, (h.x + s * 0.10, vy, h.z + 0.12), (0.11, 0.022, 0.014), rot=(0, s * -16, 0), m=k.dark)
        # 4. Bordure or d'elite si Mk IV
        if trim_gold:
            self.box(arm_bone, (h.x + s * 0.15 * big, h.y, h.z + 0.08 + 0.05 * plates), (0.02, 0.26 * big, 0.015), rot=(0, s * -16, 0), m=k.trim)

    # ------------------------------------------------------------------ EPAULIERES BLUESTRIKE
    def pauldron_bluestrike(self, s, big=1.0, plates=2, vents=True, elite=False):
        k = self.kit
        arm_bone = "LeftArm" if s > 0 else "RightArm"
        h = self.H[arm_bone]
        # Grosses épaulières rondes caractéristiques de Bluestrike (Dôme sphérique hard-surface)
        c = Vector((h.x + s * 0.11 * big, h.y, h.z + 0.08 * big))
        # 1. Coque spherique orange vif principale
        self.attach(_add("sphere", c, (0.16 * big, 0.16 * big, 0.15 * big), m=k.armor), arm_bone)
        # 2. Anneau equateur mecanique sombre
        self.ring(arm_bone, c, 0.162 * big, Vector((s * 0.3, 0, 1)), m=k.dark, thick=1.2)
        # 3. Coiffe superieure renforcee (plaque d'assaut)
        self.box(arm_bone, c + Vector((0, 0, 0.11 * big)), (0.17 * big, 0.22 * big, 0.038), rot=(0, s * -12, 0), m=k.armor, bevel=0.014)
        if plates > 2:
            self.box(arm_bone, c + Vector((s * 0.02, 0, 0.15 * big)), (0.13 * big, 0.18 * big, 0.032), rot=(0, s * -15, 0), m=k.dark, bevel=0.012)
        # 4. Fentes d'aeration / évents avec fond lumineux chaud
        if vents:
            for j in range(3):
                vy = c.y - 0.06 + 0.06 * j
                self.box(arm_bone, Vector((c.x + s * (0.11 * big), vy, c.z + 0.02)), (0.02, 0.035, 0.012), m=k.dark)
                self.box(arm_bone, Vector((c.x + s * (0.115 * big), vy, c.z + 0.02)), (0.008, 0.025, 0.008), m=k.hot)
        # 5. Anneaux or et blanc d'elite pour Mk IV
        if elite:
            self.ring(arm_bone, c + Vector((0, 0, 0.06 * big)), 0.165 * big, Vector((0, 0, 1)), m=k.gold, thick=0.8)
            self.box(arm_bone, c + Vector((s * 0.14 * big, 0, 0.04)), (0.018, 0.16 * big, 0.04), rot=(0, s * -12, 0), m=k.trim)

    # ------------------------------------------------------------------ ARMES D'AVANT-BRAS (CANNONS & GATLINGS)
    def forearm_cannon(self, s, length=0.55, r=0.055, barrels=1, glow_col=None, housing=True, is_gatling=False):
        k = self.kit
        fa = "LeftForeArm" if s > 0 else "RightForeArm"
        hd = "LeftHand" if s > 0 else "RightHand"
        d = (self.H[hd] - self.H[fa]).normalized()
        o = self.H[fa] + d * 0.03
        tip = o + d * length
        glow_mat = glow_col or k.glow

        # 1. Culasse / Boitier arriere (repose sur l'avant-bras pres du coude)
        culasse_pos = o + d * 0.09
        self.box(fa, culasse_pos, (0.13, 0.14, 0.18), aim=d, m=k.dark, bevel=0.014)
        # Cables d'alimentation tresses reliant le coude a la culasse
        perp1 = d.cross(Vector((0, 0, 1))).normalized() if abs(d.z) < 0.9 else d.cross(Vector((1, 0, 0))).normalized()
        for c_idx in (-1, 1):
            c_off = perp1 * (c_idx * 0.065) + Vector((0, 0, -0.04))
            self.cyl(fa, o + c_off, 0.014, 0.16, d, m=k.dark)

        # 2. Carter d'armure / frette superieure profilee
        if housing:
            mid = o + d * 0.22
            # Carter exterieur chanfreine couleur armure
            self.box(fa, mid + Vector((0, 0, 0.025)), (0.14, 0.15, 0.32), aim=d, m=k.armor, bevel=0.016)
            # Events de dissipation lateraux
            for v_i in range(2):
                v_pos = mid + d * (float(v_i) * 0.09 - 0.045)
                self.box(fa, v_pos + perp1 * 0.075, (0.015, 0.02, 0.06), aim=d, m=k.dark)
                self.box(fa, v_pos - perp1 * 0.075, (0.015, 0.02, 0.06), aim=d, m=k.dark)
            # Ligne d'energie sur le carter
            self.box(fa, mid + Vector((0, 0, 0.105)), (0.022, 0.015, 0.26), aim=d, m=glow_mat)

        # 3. Barils / Canons usines (simple, jumeaux ou gatling)
        if barrels == 1:
            # Canon simple : manchon arriere lourd + tube usine avant + frette lumineuse + bouche
            c_rear = o + d * (length * 0.40)
            self.cyl(fa, c_rear, r * 1.15, length * 0.45, d, m=k.dark, bevel=0.008)
            c_front = o + d * (length * 0.72)
            self.cyl(fa, c_front, r * 0.90, length * 0.50, d, m=k.dark, bevel=0.006)
            # Frette / bobine electromagnetique lumineuse
            fret_pos = o + d * (length * 0.82)
            self.ring(fa, fret_pos, r * 1.30, d, m=glow_mat, thick=1.1)
            # Bouche d'arme / frein de bouche
            muzzle_pos = o + d * length
            self.cyl(fa, muzzle_pos, r * 1.05, 0.05, d, m=k.dark, bevel=0.008)
            self.cyl(fa, muzzle_pos + d * 0.015, r * 0.65, 0.035, d, m=glow_mat)
        elif barrels in (2, 3, 6):
            # Configuration multi-canons (jumeaux ou gatling rotative)
            hub_len = length * (0.65 if is_gatling else 0.55)
            self.cyl(fa, o + d * (hub_len * 0.5), r * 0.8, hub_len, d, m=k.dark)
            # Colliers de maintien rotor
            if is_gatling:
                self.ring(fa, o + d * (length * 0.45), r * 1.6, d, m=k.trim if k.base == "vortex" else k.dark, thick=1.2)
                self.ring(fa, o + d * (length * 0.85), r * 1.5, d, m=k.trim if k.base == "vortex" else k.dark, thick=1.2)

            rr = r * (0.42 if barrels == 2 else 0.35 if barrels == 3 else 0.28)
            orbit_r = r * (1.1 if barrels == 2 else 1.25 if barrels == 3 else 1.35)
            perp2 = d.cross(perp1).normalized()
            for b in range(barrels):
                ang = 2.0 * math.pi * float(b) / float(barrels)
                off = (perp1 * math.cos(ang) + perp2 * math.sin(ang)) * orbit_r
                b_center = o + d * (length * 0.55) + off
                self.cyl(fa, b_center, rr, length * 0.75, d, m=k.dark, bevel=0.005)
                # Bague lumineuse sur chaque canon
                self.ring(fa, o + d * (length * 0.84) + off, rr * 1.25, d, m=glow_mat, thick=0.9)
                # Bouche de canon
                self.cyl(fa, o + d * length + off, rr * 0.75, 0.035, d, m=glow_mat)

        return tip

    # ------------------------------------------------------------------ BLASTERS DE MAIN & EMETTEURS
    def hand_blaster(self, s, length=0.28, r=0.08):
        # Blaster de dispersion de Bluestrike Mk II : bouche evasee conique, boitier de culasse sur la main
        k = self.kit
        hd = "LeftHand" if s > 0 else "RightHand"
        fa = "LeftForeArm" if s > 0 else "RightForeArm"
        d = (self.H[hd] - self.H[fa]).normalized()
        base_pt = self.H[hd] + d * 0.04
        # Boitier de tir dorsal sur le poignet
        self.box(hd, base_pt, (0.13, 0.12, 0.14), aim=d, m=k.dark, bevel=0.012)
        # Bague de jonction orange
        self.cyl(hd, base_pt + d * 0.07, r * 1.05, 0.04, d, m=k.armor, bevel=0.006)
        # Canon court lourd
        self.cyl(hd, base_pt + d * 0.13, r * 0.95, 0.10, d, m=k.dark, bevel=0.006)
        # Bouche évasée conique (corne de dispersion) orange à intérieur incandescent
        mouth_pos = base_pt + d * (length * 0.92)
        self.cone(hd, mouth_pos, r * 1.25, 0.08, d, m=k.armor)
        # Coeur de tir / lueur orange chaude
        self.cyl(hd, mouth_pos + d * 0.02, r * 0.72, 0.03, d, m=k.hot)
        self.ring(hd, mouth_pos - d * 0.03, r * 1.15, d, m=k.hot, thick=1.0)

    def palm_emitter(self, s, r=0.055, elite=False):
        # Émetteur d'énergie intégré au creux de la paume
        k = self.kit
        hd = "LeftHand" if s > 0 else "RightHand"
        fa = "LeftForeArm" if s > 0 else "RightForeArm"
        d = (self.H[hd] - self.H[fa]).normalized()
        c = self.H[hd] + d * 0.08
        # Coupelle d'encastrement sombre
        self.cyl(hd, c, r * 1.35, 0.04, d, m=k.dark, bevel=0.008)
        # Anneau de focalisation
        self.ring(hd, c + d * 0.01, r * 1.25, d, m=k.trim if elite else k.dark, thick=0.9)
        # Lentille emissive concentree
        glow_m = k.magenta if (k.base == "bluestrike" and elite) else k.glow
        self.cyl(hd, c + d * 0.025, r * 0.95, 0.025, d, m=glow_m)

    # ------------------------------------------------------------------ CRETE DE CASQUE & HALOS
    def helmet_crest(self, big=1.0, is_vortex=True):
        k = self.kit
        h = self.H["Head"]
        if is_vortex:
            # Crête angulaire élancée avec doubles cornes de chasseur
            top = Vector((h.x, h.y + 0.02, h.z + 0.23))
            self.box("Head", top + Vector((0, -0.02, 0.06 * big)), (0.04, 0.10 * big, 0.13 * big), rot=(16, 0, 0), m=k.armor, bevel=0.012)
            self.box("Head", top + Vector((0, -0.045, 0.06 * big)), (0.016, 0.02, 0.12 * big), rot=(16, 0, 0), m=k.glow)
            # Antennes latérales acérées
            for s in (-1, 1):
                self.attach(_add("cone", Vector((h.x + s * 0.075, h.y + 0.04, h.z + 0.25)), (0.013, 0.013, 0.30 * big), aim=Vector((s * 0.12, 0.08, 1)), m=k.dark), "Head")
        else:
            # Visière / crête éclaireur pour Bluestrike
            self.box("Head", Vector((h.x, h.y - 0.07, h.z + 0.16)), (0.11 * big, 0.05, 0.035), rot=(-14, 0, 0), m=k.armor, bevel=0.01)
            self.box("Head", Vector((h.x, h.y - 0.09, h.z + 0.16)), (0.09 * big, 0.015, 0.022), rot=(-14, 0, 0), m=k.magenta)

    def halo(self, big=1.0, col=None):
        k = self.kit
        h = self.H["Head"]
        halo_m = col or k.glow
        # Halo holographique d'élite flottant au-dessus du casque
        c = Vector((h.x, h.y + 0.02, h.z + 0.32 * big))
        self.ring("Head", c, 0.17 * big, Vector((0, 0, 1)), m=halo_m, thick=0.85)
        # Micro-projecteur à la base
        self.cyl("Head", c + Vector((0, 0.06, -0.05)), 0.022, 0.06, Vector((0, 0, 1)), m=k.dark)

    # ------------------------------------------------------------------ PLASTRONS (CHEST PLATES)
    def chest_plate_vortex(self, big=1.0, trim_gold=False):
        k = self.kit
        sp = self.H["Spine02"]
        # Plastron angulaire profile en V compose de plaques pectorales biseautees
        for s in (-1, 1):
            # Plaque pectorale inclinee
            p_loc = (sp.x + s * 0.082 * big, sp.y - 0.16, sp.z + 0.315)
            self.box("Spine02", p_loc, (0.15 * big, 0.055, 0.19 * big), rot=(-10, s * -14, s * 8), m=k.armor, bevel=0.015)
            # Bandeau chevron neon cyan le long de l'arete formant le V vers le reacteur
            b_loc = (sp.x + s * 0.076 * big, sp.y - 0.192, sp.z + 0.305)
            self.box("Spine02", b_loc, (0.13 * big, 0.014, 0.024), rot=(-10, s * -14, s * 16), m=k.glow)
            # Event lateral de dissipation
            self.box("Spine02", (sp.x + s * 0.145 * big, sp.y - 0.165, sp.z + 0.33), (0.045, 0.02, 0.035), rot=(-10, s * -14, 0), m=k.dark)
            if trim_gold:
                self.box("Spine02", (sp.x + s * 0.08 * big, sp.y - 0.192, sp.z + 0.375), (0.13 * big, 0.012, 0.016), rot=(-10, s * -14, s * 8), m=k.trim)

    def chest_plate_bluestrike(self, big=1.0, dual_ports=False, elite=False):
        k = self.kit
        sp = self.H["Spine02"]
        # Gorgerin d'armure lourde orange vif cadrant le cou et la poitrine
        self.box("Spine02", (sp.x, sp.y - 0.16, sp.z + 0.31), (0.34 * big, 0.075, 0.22 * big), rot=(-8, 0, 0), m=k.armor, bevel=0.018)
        # Sous-plastron central sombre avec fentes
        self.box("Spine02", (sp.x, sp.y - 0.185, sp.z + 0.26), (0.16 * big, 0.03, 0.10 * big), rot=(-8, 0, 0), m=k.dark, bevel=0.012)
        # Double ports de capteurs / réacteurs pectoraux
        if dual_ports:
            for s in (-1, 1):
                port_c = Vector((sp.x + s * 0.10 * big, sp.y - 0.198, sp.z + 0.32))
                self.cyl("Spine02", port_c, 0.036, 0.025, Vector((0, -1, 0)), m=k.dark, bevel=0.005)
                self.cyl("Spine02", port_c + Vector((0, -0.014, 0)), 0.024, 0.015, Vector((0, -1, 0)), m=k.hot if not elite else k.magenta)
        if elite:
            self.box("Spine02", (sp.x, sp.y - 0.196, sp.z + 0.37), (0.26 * big, 0.012, 0.016), rot=(-8, 0, 0), m=k.gold)

    # ------------------------------------------------------------------ GENOUILLERES (KNEE PLATES)
    def knee_plates(self, big=1.0, is_vortex=True):
        k = self.kit
        for s, lg in ((1, "LeftLeg"), (-1, "RightLeg")):
            h = self.H[lg]
            # Bouclier de genou biseauté avançant sur l'articulation
            self.box(lg, (h.x, h.y - 0.08, h.z + 0.025), (0.14 * big, 0.065, 0.16 * big), m=k.armor, bevel=0.014)
            # Fente d'énergie néon centrale
            glow_m = k.glow if is_vortex else k.hot
            self.box(lg, (h.x, h.y - 0.115, h.z + 0.025), (0.028, 0.015, 0.12 * big), m=glow_m)
            # Charnière latérale mécanique sombre
            self.box(lg, (h.x + s * 0.065 * big, h.y - 0.07, h.z + 0.01), (0.022, 0.05, 0.06), m=k.dark)

    # ------------------------------------------------------------------ PROPULSEURS DORSAUX (THRUSTERS)
    def thruster_pack(self, flame=None, big=1.0, is_quad=False):
        k = self.kit
        sp = self.H["Spine02"]
        flame_m = flame or k.glow
        # Module d'attache dorsal principal
        self.box("Spine02", (sp.x, sp.y + 0.17, sp.z + 0.32), (0.28 * big, 0.08, 0.18 * big), m=k.dark, bevel=0.012)
        # Tuyères de propulsion
        offsets = [(-1, 0.12), (1, 0.12)] if not is_quad else [(-1, 0.09), (1, 0.09), (-1, 0.18), (1, 0.18)]
        for s, dx in offsets:
            c = Vector((sp.x + s * dx, sp.y + 0.22, sp.z + 0.31))
            # Corps de tuyère usiné
            self.cyl("Spine02", c, 0.068 * big, 0.28 * big, Vector((0, 0.25, -1)), m=k.dark, bevel=0.008)
            # Bague de tuyère métallique / or
            self.ring("Spine02", c + Vector((0, 0.04, -0.09 * big)), 0.072 * big, Vector((0, 0.25, -1)), m=k.trim if k.base == "vortex" else k.dark, thick=1.0)
            # Flamme de tuyère à double couche (noyau blanc + panache)
            self.cyl("Spine02", c + Vector((0, 0.08, -0.16 * big)), 0.052 * big, 0.045, Vector((0, 0.25, -1)), m=flame_m)
            self.cone("Spine02", c + Vector((0, 0.11, -0.28 * big)), 0.046 * big, 0.19 * big, Vector((0, -0.25, 1)), m=flame_m)

    # ------------------------------------------------------------------ PLAQUES FLOTTANTES (VORTEX MK IV)
    def floating_plate(self, s, halo=True):
        k = self.kit
        sp = self.H["Spine02"]
        # Plaque d'armure flottante angulaire détachée à côté des épaules
        c = Vector((sp.x + s * 0.44, sp.y + 0.02, sp.z + 0.42))
        self.attach(_add("box", c, (0.16, 0.28, 0.038), rot=(0, s * -24, 0), m=k.armor, bevel=0.015), "Spine02")
        # Bordure or et chrome
        self.attach(_add("box", c + Vector((s * 0.025, 0, 0.032)), (0.045, 0.22, 0.014), rot=(0, s * -24, 0), m=k.trim), "Spine02")
        self.attach(_add("box", c + Vector((-s * 0.03, 0, -0.01)), (0.02, 0.18, 0.012), rot=(0, s * -24, 0), m=k.chrome), "Spine02")
        # Halo holographique cyan en orbite derrière la plaque
        if halo:
            self.ring("Spine02", c + Vector((0, 0, -0.10)), 0.125, Vector((0, 0, 1)), m=k.glow, thick=1.1)

    # ------------------------------------------------------------------ AILES D'ÉNERGIE (BLUESTRIKE MK IV)
    def energy_wings(self):
        k = self.kit
        sp = self.H["Spine02"]
        # 3 ailerons de lumière cyan translucides par côté
        for s in (-1, 1):
            # Embase de pylône d'aile
            pylon = Vector((sp.x + s * 0.16, sp.y + 0.20, sp.z + 0.38))
            self.box("Spine02", pylon, (0.06, 0.08, 0.12), m=k.dark, bevel=0.01)
            for j, (ln, ang, z_off) in enumerate(((0.60, 32, 0.0), (0.46, 16, -0.06), (0.34, 0, -0.12))):
                c = Vector((sp.x + s * (0.24 + 0.16 * ln), sp.y + 0.24, sp.z + 0.45 + z_off))
                self.attach(_add("box", c, (ln, 0.012, 0.085), rot=(0, 0, s * (62 - ang)), m=k.wing), "Spine02")

    # ------------------------------------------------------------------ CONDUITS & BANDES DE FINITIONS
    def conduits_bluestrike(self):
        k = self.kit
        # Conduits d'énergie lumineux le long des avant-bras et des tibias pour Bluestrike Mk III
        for s, fa in ((1, "LeftForeArm"), (-1, "RightForeArm")):
            h = self.H[fa]
            hd = self.H["LeftHand" if s > 0 else "RightHand"]
            d = (hd - h).normalized()
            self.cyl(fa, h + d * 0.12 + Vector((s * 0.04, 0, 0.03)), 0.014, 0.22, d, m=k.hot)
        for s, lg in ((1, "LeftLeg"), (-1, "RightLeg")):
            h = self.H[lg]
            self.cyl(lg, h + Vector((s * 0.045, -0.03, -0.10)), 0.015, 0.24, Vector((0, 0, -1)), m=k.hot)

    def trim_bands(self, is_vortex=True):
        k = self.kit
        m_trim = k.trim if is_vortex else k.gold
        for s, fa in ((1, "LeftForeArm"), (-1, "RightForeArm")):
            h = self.H[fa]
            hd = self.H["LeftHand" if s > 0 else "RightHand"]
            d = (hd - h).normalized()
            self.ring(fa, h + d * 0.06, 0.075, d, m=m_trim, thick=0.7)


def build(arm, base, mk):
    p = Parts(arm, base, mk)
    if base == "vortex":
        if mk == 2:
            # VORTEX MK II (Renforcé)
            p.pauldron_vortex(1, big=1.0, plates=2)
            p.pauldron_vortex(-1, big=1.0, plates=2)
            p.helmet_crest(1.0, is_vortex=True)
            p.forearm_cannon(-1, length=0.64, r=0.055, barrels=1, housing=True)
            p.palm_emitter(1, r=0.052)
            p.knee_plates(1.0, is_vortex=True)
        elif mk == 3:
            # VORTEX MK III (Spécialisé)
            p.pauldron_vortex(1, big=1.16, plates=3)
            p.pauldron_vortex(-1, big=1.16, plates=3)
            p.helmet_crest(1.25, is_vortex=True)
            p.chest_plate_vortex(big=1.05)
            p.forearm_cannon(-1, length=0.65, r=0.055, barrels=1, housing=True)
            p.forearm_cannon(1, length=0.65, r=0.055, barrels=1, housing=True)
            p.thruster_pack(flame=p.kit.glow, big=1.05)
            p.knee_plates(1.18, is_vortex=True)
        elif mk == 4:
            # VORTEX MK IV (Élite)
            p.pauldron_vortex(1, big=1.22, plates=3, trim_gold=True)
            p.pauldron_vortex(-1, big=1.22, plates=3, trim_gold=True)
            p.helmet_crest(1.40, is_vortex=True)
            p.chest_plate_vortex(big=1.15, trim_gold=True)
            p.forearm_cannon(-1, length=0.68, r=0.072, barrels=3, housing=True, is_gatling=True)
            p.palm_emitter(1, r=0.065, elite=True)
            p.floating_plate(1, halo=True)
            p.floating_plate(-1, halo=True)
            p.knee_plates(1.25, is_vortex=True)
            p.halo(1.05, col=p.kit.glow)
            p.trim_bands(is_vortex=True)
            p.thruster_pack(flame=p.kit.glow, big=1.15, is_quad=True)
    else: # bluestrike
        if mk == 2:
            # BLUESTRIKE MK II (Renforcé)
            p.pauldron_bluestrike(1, big=1.05, plates=2, vents=True)
            p.pauldron_bluestrike(-1, big=1.05, plates=2, vents=True)
            p.hand_blaster(1, length=0.28, r=0.08)
            p.hand_blaster(-1, length=0.28, r=0.08)
            p.chest_plate_bluestrike(big=1.0, dual_ports=False)
            p.knee_plates(1.0, is_vortex=False)
            p.helmet_crest(1.0, is_vortex=False)
        elif mk == 3:
            # BLUESTRIKE MK III (Assaut)
            p.pauldron_bluestrike(1, big=1.12, plates=2, vents=True)
            p.pauldron_bluestrike(-1, big=1.12, plates=2, vents=True)
            p.forearm_cannon(1, length=0.52, r=0.068, barrels=2, glow_col=p.kit.hot, housing=True)
            p.forearm_cannon(-1, length=0.52, r=0.068, barrels=2, glow_col=p.kit.hot, housing=True)
            p.chest_plate_bluestrike(big=1.1, dual_ports=True)
            p.conduits_bluestrike()
            p.thruster_pack(flame=p.kit.hot, big=1.1)
            p.knee_plates(1.18, is_vortex=False)
            p.helmet_crest(1.15, is_vortex=False)
        elif mk == 4:
            # BLUESTRIKE MK IV (Élite)
            p.pauldron_bluestrike(1, big=1.20, plates=3, vents=True, elite=True)
            p.pauldron_bluestrike(-1, big=1.20, plates=3, vents=True, elite=True)
            p.forearm_cannon(-1, length=0.64, r=0.082, barrels=6, glow_col=p.kit.hot, housing=True, is_gatling=True)
            p.palm_emitter(1, r=0.068, elite=True)
            p.chest_plate_bluestrike(big=1.18, dual_ports=True, elite=True)
            p.energy_wings()
            p.halo(1.05, col=p.kit.glow)
            p.knee_plates(1.25, is_vortex=False)
            p.trim_bands(is_vortex=False)
            p.thruster_pack(flame=p.kit.hot, big=1.2, is_quad=True)
            p.helmet_crest(1.25, is_vortex=False)
    p.update()
    return p
