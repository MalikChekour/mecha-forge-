#!/usr/bin/env python3
"""IMPACT DE LA FORGE (lob_slag) -- vraie simulation physique, pas de motif mathematique.

Blender 5.0 (module bpy) :
  * Mantaflow gaz (feu + fumee) : souffle d'explosion qui monte, se replie en champignon et se dissout ;
  * ~110 eclats de lave (particules Newton + gravite + rebond au sol) qui refroidissent du blanc au rouge sombre ;
  * eclairage : lueur orange du foyer qui decroit (eclaire le dessous de la fumee) + ciel froid tres faible.

Deux passes par image, comme dans les VFX de jeu :
  smoke -> fumee seule eclairee (melange NORMAL en jeu)   -> game/assets/vfx/ts/ts_slag_smoke.png
  emit  -> feu + eclats incandescents (melange ADDITIF)   -> game/assets/vfx/ts/ts_slag_impact.png
Planches 4x4 de 192 px (meme format que l'ancienne planche : la logique de TurretBurst ne change pas).

Usage : python tools/vfx_blender/forge_impact.py [--preview]
  --preview : 4 images en basse definition (~2 min) pour juger avant le rendu complet.
"""
import os, sys, math, shutil
import bpy
import numpy as np
from PIL import Image

PREVIEW = "--preview" in sys.argv
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORK = os.path.join(ROOT, "cine", "_vfx_forge")
CACHE = os.path.join(WORK, "cache")
OUT_TS = os.path.join(ROOT, "game", "assets", "vfx", "ts")
ART = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\f4d60812-8c84-40f0-9aad-921d86be3fca"

RES = 192 if PREVIEW else 384          # rendu, reduit ensuite a 192 px par case (net)
SAMPLES = 12 if PREVIEW else 28
SIM_RES = 56 if PREVIEW else 84
FRAMES = [3, 9, 15, 23] if PREVIEW else [2 + 2 * i for i in range(16)]
SIM_END = max(FRAMES)

shutil.rmtree(CACHE, ignore_errors=True)
os.makedirs(WORK, exist_ok=True)

# ----------------------------------------------------------------------------- scene vide
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.frame_start, sc.frame_end = 1, SIM_END
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.cycles.volume_bounces = 0
sc.cycles.max_bounces = 2
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = RES
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.view_settings.view_transform = "AgX"

world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.025, 0.035, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sc.world = world

def mesh_obj(name, op, **kw):
    op(**kw)
    o = bpy.context.active_object
    o.name = name
    return o

# ----------------------------------------------------------------------------- domaine de gaz
dom = mesh_obj("Domain", bpy.ops.mesh.primitive_cube_add, location=(0, 0, 1.7))
dom.scale = (2.3, 2.3, 1.85)
bpy.ops.object.transform_apply(scale=True)
m = dom.modifiers.new("Fluid", "FLUID")
m.fluid_type = "DOMAIN"
ds = m.domain_settings
ds.domain_type = "GAS"
ds.resolution_max = SIM_RES
ds.cache_type = "REPLAY"
ds.cache_directory = CACHE
ds.cache_frame_start, ds.cache_frame_end = 1, SIM_END
ds.use_adaptive_domain = False
ds.alpha = 0.6            # la fumee dense retombe un peu (champignon)
ds.beta = 2.2             # la chaleur fait monter fort
ds.vorticity = 0.35
ds.flame_vorticity = 1.4
ds.burning_rate = 0.85
ds.flame_smoke = 1.6
ds.flame_ignition = 1.2
ds.flame_max_temp = 3.0
ds.use_dissolve_smoke = True
ds.dissolve_speed = 34
ds.time_scale = 1.15
ds.use_noise = True
ds.noise_scale = 2
ds.noise_strength = 1.4

# ----------------------------------------------------------------------------- source du souffle (3 images puis coupee)
src = mesh_obj("Blast", bpy.ops.mesh.primitive_uv_sphere_add, radius=0.32, location=(0, 0, 0.3), segments=24, ring_count=12)
src.scale = (1.0, 1.0, 0.55)
fm = src.modifiers.new("Fluid", "FLUID")
fm.fluid_type = "FLOW"
fs = fm.flow_settings
fs.flow_type = "BOTH"
fs.flow_behavior = "INFLOW"
fs.flow_source = "MESH"
fs.surface_distance = 0.6
fs.fuel_amount = 2.2
fs.temperature = 2.5
fs.density = 1.3
fs.smoke_color = (0.2, 0.17, 0.15)
fs.use_initial_velocity = True
fs.velocity_normal = 3.2
fs.velocity_coord = (0, 0, 2.6)
src.hide_render = True
for f, z in ((1, 0.3), (4, 0.3), (5, -50.0)):     # sort du domaine a l'image 5 : souffle bref
    src.location.z = z
    src.keyframe_insert("location", index=2, frame=f)
for fc in src.animation_data.action.fcurves if hasattr(src.animation_data.action, "fcurves") else []:
    for k in fc.keyframe_points:
        k.interpolation = "CONSTANT"

# ----------------------------------------------------------------------------- sol (collision des eclats, invisible)
ground = mesh_obj("Ground", bpy.ops.mesh.primitive_plane_add, size=12, location=(0, 0, 0))
ground.modifiers.new("Col", "COLLISION")
ground.collision.damping_factor = 0.55
ground.collision.friction_factor = 0.4
ground.hide_render = True

# ----------------------------------------------------------------------------- eclats de lave (particules)
chunk = mesh_obj("Chunk", bpy.ops.mesh.primitive_ico_sphere_add, subdivisions=1, radius=1.0, location=(0, 0, -30))
chunk.scale = (1.0, 0.75, 0.6)                 # eclats irreguliers, pas des billes
chunk.visible_shadow = False
emi = mesh_obj("Emitter", bpy.ops.mesh.primitive_ico_sphere_add, subdivisions=2, radius=0.22, location=(0, 0, 0.22))
ps = emi.modifiers.new("Debris", "PARTICLE_SYSTEM").particle_system
pst = ps.settings
pst.count = 110
pst.frame_start, pst.frame_end = 1, 2
pst.lifetime = 80
pst.emit_from = "FACE"
pst.normal_factor = 4.2
pst.factor_random = 2.2
pst.object_align_factor = (0, 0, 2.4)
pst.physics_type = "NEWTON"
pst.mass = 0.3
pst.render_type = "OBJECT"
pst.instance_object = chunk
pst.particle_size = 0.04
pst.size_random = 0.75
pst.use_rotations = True
pst.rotation_factor_random = 1.0
pst.use_render_emitter = False
ps.seed = 7

# ----------------------------------------------------------------------------- materiaux
def ramp_stops(ramp, stops):
    el = ramp.color_ramp.elements
    while len(el) > 2:
        el.remove(el[-1])
    for i, (p, c) in enumerate(stops):
        e = el[i] if i < 2 else el.new(p)
        e.position = p
        e.color = c

# fumee seule (passe "smoke") : absorbe et diffuse la lumiere, aucune emission
mat_smoke = bpy.data.materials.new("Smoke")
mat_smoke.use_nodes = True
nt = mat_smoke.node_tree
nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputMaterial")
vi = nt.nodes.new("ShaderNodeVolumeInfo")
pv = nt.nodes.new("ShaderNodeVolumePrincipled")
pv.inputs["Color"].default_value = (0.30, 0.26, 0.23, 1)
pv.inputs["Emission Strength"].default_value = 0.0
pv.inputs["Blackbody Intensity"].default_value = 0.0
mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = 7.0
nt.links.new(vi.outputs["Density"], mul.inputs[0])
nt.links.new(mul.outputs[0], pv.inputs["Density"])
nt.links.new(pv.outputs[0], out.inputs["Volume"])

# feu seul (passe "emit") : emission pure pilotee par la flamme, sans absorption
mat_fire = bpy.data.materials.new("Fire")
mat_fire.use_nodes = True
nt = mat_fire.node_tree
nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputMaterial")
vi = nt.nodes.new("ShaderNodeVolumeInfo")
cr = nt.nodes.new("ShaderNodeValToRGB")
ramp_stops(cr, [(0.0, (0, 0, 0, 1)), (0.12, (0.35, 0.03, 0.0, 1)), (0.35, (1.0, 0.22, 0.02, 1)),
                (0.62, (1.0, 0.55, 0.12, 1)), (0.85, (1.0, 0.85, 0.5, 1)), (1.0, (1.0, 0.97, 0.9, 1))])
em = nt.nodes.new("ShaderNodeEmission")
pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 1.5
st = nt.nodes.new("ShaderNodeMath"); st.operation = "MULTIPLY"; st.inputs[1].default_value = 26.0
nt.links.new(vi.outputs["Flame"], cr.inputs["Fac"])
nt.links.new(cr.outputs["Color"], em.inputs["Color"])
nt.links.new(vi.outputs["Flame"], pw.inputs[0])
nt.links.new(pw.outputs[0], st.inputs[0])
nt.links.new(st.outputs[0], em.inputs["Strength"])
nt.links.new(em.outputs[0], out.inputs["Volume"])

# eclats : incandescents, refroidissent avec l'age (blanc -> orange -> rouge sombre)
mat_chunk = bpy.data.materials.new("Chunk")
mat_chunk.use_nodes = True
nt = mat_chunk.node_tree
nt.nodes.clear()
out_c = nt.nodes.new("ShaderNodeOutputMaterial")
pi = nt.nodes.new("ShaderNodeParticleInfo")
age = nt.nodes.new("ShaderNodeMath"); age.operation = "DIVIDE"; age.inputs[1].default_value = 34.0
cr2 = nt.nodes.new("ShaderNodeValToRGB")
ramp_stops(cr2, [(0.0, (1.0, 0.95, 0.8, 1)), (0.25, (1.0, 0.6, 0.15, 1)), (0.6, (0.8, 0.15, 0.02, 1)), (1.0, (0.12, 0.02, 0.0, 1))])
inv = nt.nodes.new("ShaderNodeMath"); inv.operation = "SUBTRACT"; inv.inputs[0].default_value = 1.0
s2 = nt.nodes.new("ShaderNodeMath"); s2.operation = "MULTIPLY"; s2.inputs[1].default_value = 18.0
em2 = nt.nodes.new("ShaderNodeEmission")
nt.links.new(pi.outputs["Age"], age.inputs[0])
nt.links.new(age.outputs[0], cr2.inputs["Fac"])
nt.links.new(cr2.outputs["Color"], em2.inputs["Color"])
nt.links.new(age.outputs[0], inv.inputs[1])
nt.links.new(inv.outputs[0], s2.inputs[0])
nt.links.new(s2.outputs[0], em2.inputs["Strength"])
nt.links.new(em2.outputs[0], out_c.inputs["Surface"])
mat_hidden = bpy.data.materials.new("Hidden")
mat_hidden.use_nodes = True
nt = mat_hidden.node_tree
nt.nodes.clear()
o2 = nt.nodes.new("ShaderNodeOutputMaterial")
tb = nt.nodes.new("ShaderNodeBsdfTransparent")
nt.links.new(tb.outputs[0], o2.inputs["Surface"])
chunk.data.materials.append(mat_chunk)
dom.data.materials.append(mat_smoke)

# ----------------------------------------------------------------------------- lumieres
fire_light = bpy.data.objects.new("FireLight", bpy.data.lights.new("FireLight", "POINT"))
sc.collection.objects.link(fire_light)
fire_light.location = (0, 0, 0.55)
fire_light.data.color = (1.0, 0.45, 0.12)
fire_light.data.shadow_soft_size = 0.6
for f, e in ((1, 9000), (6, 6500), (14, 2200), (24, 500), (34, 60)):
    fire_light.data.energy = e
    fire_light.data.keyframe_insert("energy", frame=f)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sc.collection.objects.link(sun)
sun.data.energy = 1.6
sun.data.color = (0.75, 0.82, 1.0)
sun.rotation_euler = (math.radians(35), math.radians(-25), math.radians(20))

# ----------------------------------------------------------------------------- camera 3/4 (comme le jeu)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = 4.6
tilt = math.radians(52)                       # angle de vue plongeant du jeu
dist = 20.0
target = (0.0, 0.0, 1.15)
cam.location = (0.0, target[1] - dist * math.cos(tilt), target[2] + dist * math.sin(tilt))
cam.rotation_euler = (math.radians(90) - tilt, 0, 0)
sc.camera = cam

# ----------------------------------------------------------------------------- simulation + rendu
def render_to(path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

shots = []
for f in range(1, SIM_END + 1):
    sc.frame_set(f)                           # avance la simulation image par image (cache REPLAY)
    if f not in FRAMES:
        continue
    print("RENDER frame", f, flush=True)
    # passe fumee : volume absorbant eclaire, eclats invisibles
    dom.data.materials[0] = mat_smoke
    chunk.data.materials[0] = mat_hidden
    p_smoke = os.path.join(WORK, "smoke_%02d.png" % f)
    render_to(p_smoke)
    # passe feu : emission pure + eclats incandescents
    dom.data.materials[0] = mat_fire
    chunk.data.materials[0] = mat_chunk
    p_emit = os.path.join(WORK, "emit_%02d.png" % f)
    render_to(p_emit)
    shots.append((p_smoke, p_emit))

# ----------------------------------------------------------------------------- planches 4x4 (192 px par case)
CELL = 192
def load(p):
    im = Image.open(p).convert("RGBA").resize((CELL, CELL), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0

def edge_fade():
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    d = np.minimum.reduce([xx, yy, CELL - 1 - xx, CELL - 1 - yy]) / (CELL * 0.08)
    return np.clip(d, 0, 1)
EF = edge_fade()

n = len(shots)
grid = 4 if not PREVIEW else 2
sheet_emit = np.zeros((CELL * grid, CELL * grid, 4), np.float32)
sheet_smoke = np.zeros_like(sheet_emit)
for i, (ps_, pe_) in enumerate(shots):
    r, c = divmod(i, grid)
    sm = load(ps_)
    em = load(pe_)
    # additif : couleur premultipliee -> alpha = canal max, rgb normalise (convention des textures ts/)
    pre = em[..., :3] * em[..., 3:4] * EF[..., None]
    a = pre.max(axis=2)
    rgb = pre / np.maximum(a[..., None], 1e-4)
    sheet_emit[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = np.dstack([rgb, a])
    # fumee : melange normal, alpha du rendu
    sheet_smoke[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = np.dstack([sm[..., :3], sm[..., 3] * EF])

def save(arr, path):
    Image.fromarray(np.clip(arr * 255.0, 0, 255).astype(np.uint8), "RGBA").save(path)

if PREVIEW:
    save(sheet_emit, os.path.join(WORK, "preview_emit.png"))
    save(sheet_smoke, os.path.join(WORK, "preview_smoke.png"))
    # apercu compose sur un sol sombre, tel qu'en jeu : fumee (normal) puis feu (additif)
    bg = np.zeros_like(sheet_emit[..., :3]); bg[:] = (0.16, 0.14, 0.13)
    comp = bg * (1 - sheet_smoke[..., 3:4]) + sheet_smoke[..., :3] * sheet_smoke[..., 3:4]
    comp = np.clip(comp + sheet_emit[..., :3] * sheet_emit[..., 3:4], 0, 1)
    Image.fromarray((comp * 255).astype(np.uint8)).save(os.path.join(ART, "forge_preview.png"))
    print("PREVIEW DONE", flush=True)
else:
    save(sheet_emit, os.path.join(OUT_TS, "ts_slag_impact.png"))
    save(sheet_smoke, os.path.join(OUT_TS, "ts_slag_smoke.png"))
    print("SHEETS DONE", flush=True)
