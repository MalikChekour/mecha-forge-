# Prepare real weapon textures (base64) for the animated weapon optimizer module.
# Reuses the mech render from _sh_assets.json as the orbit center.
import json, base64, io, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, "game", "assets")

def b64(im):
    buf = io.BytesIO(); im.save(buf, "PNG"); return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

def load(rel):
    return Image.open(os.path.join(A, rel)).convert("RGBA")

def thumb(im, maxw):
    if im.width <= maxw: return im
    r = maxw / im.width
    return im.resize((maxw, max(1, int(im.height * r))), Image.LANCZOS)

out = {"sprites": {}, "sheets": {}}

# --- single sprites (orbitals + held guns) ---
for name, rel, mw in [
    ("drone", "equip/drone.png", 128),
    ("blade", "equip/blade.png", 160),
    ("orb", "equip/orb.png", 128),
    ("cannon_shoulder", "equip/cannon_shoulder.png", 256),
    ("autocannon", "weapons/autocannon.png", 256),
    ("railgun", "weapons/railgun.png", 256),
    ("plasmacaster", "weapons/plasmacaster.png", 256),
    ("missilepod", "weapons/missilepod.png", 256),
]:
    try:
        out["sprites"][name] = b64(thumb(load(rel), mw))
    except Exception as e:
        print("skip sprite", name, e)

# --- sprite sheets (bullets 12f, muzzle/impact 28f). Keep frames aligned by scaling whole sheet. ---
# frame size square = height. Downscale to target frame height, keep count.
def sheet(rel, target_h):
    im = load(rel)
    fh = im.height
    n = round(im.width / fh)
    if n < 1: n = 1
    if fh > target_h:
        r = target_h / fh
        im = im.resize((max(1, int(im.width * r)), target_h), Image.LANCZOS)
        fh = target_h
    return {"png": b64(im), "frames": n, "fh": fh}

for name, rel in [
    ("bullet_tracer", "bullets/tracer.png"),
    ("bullet_warhead", "bullets/warhead.png"),
    ("bullet_orb", "bullets/orb.png"),
    ("bullet_lance", "bullets/lance.png"),
]:
    try: out["sheets"][name] = sheet(rel, 96)
    except Exception as e: print("skip sheet", name, e)

for name, rel in [
    ("muzzle_aaa", "vfx/aaa_muzzle.png"),
    ("muzzle_hq", "vfx/hq_muzzle.png"),
    ("muzzle_dp", "vfx/dp_muzzle.png"),
    ("impact_aaa", "vfx/aaa_impact.png"),
    ("impact_hq", "vfx/hq_impact.png"),
    ("explosion", "vfx/aaa_explosion.png"),
]:
    try: out["sheets"][name] = sheet(rel, 112)
    except Exception as e: print("skip sheet", name, e)

# missiles used as enemy/boss projectile images (static, oriented) — kept as sprites
for name, rel in [
    ("missile_gunner", "weapons/missile_gunner.png"),
    ("missile_boss", "weapons/missile_boss.png"),
]:
    try: out["sprites"][name] = b64(thumb(load(rel), 128))
    except Exception as e: print("skip", name, e)

# --- mech (orbit center) reused from shield assets ---
try:
    sh = json.load(open(os.path.join(ROOT, "cine", "_show", "_sh_assets.json")))
    out["mech"] = sh["mech"]  # player/base/colosse/broyeur/souverain
except Exception as e:
    print("no mech reuse", e); out["mech"] = {}

dst = os.path.join(ROOT, "cine", "_show", "_wpn_assets.json")
json.dump(out, open(dst, "w"), separators=(",", ":"))
kb = os.path.getsize(dst) / 1024
print("wrote", dst, "%.0f KB" % kb)
print("sprites:", list(out["sprites"].keys()))
print("sheets:", {k: (v["frames"], v["fh"]) for k, v in out["sheets"].items()})
print("mech:", list(out["mech"].keys()))
