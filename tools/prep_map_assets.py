# Prepare biome grounds + all decor objects (base64) for the map decorator module.
import json, base64, io, os, re
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "game", "assets", "decor")

def b64(im):
    buf = io.BytesIO(); im.save(buf, "PNG"); return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

def load(p): return Image.open(p).convert("RGBA")

def thumb(im, maxd):
    w, h = im.size
    if max(w, h) <= maxd: return im
    r = maxd / max(w, h)
    return im.resize((max(1, int(w*r)), max(1, int(h*r))), Image.LANCZOS)

BIOMES = ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "ruines"]
BIOME_LABEL = {"tech": "Usine / Tech", "earth": "Terre", "spaceship": "Vaisseau", "volcanic": "Volcanique",
               "desert": "Desert", "ice": "Glace", "jungle": "Jungle", "swamp": "Marais", "ruines": "Ruines"}

def group_of(name):
    if name.startswith("land_"): return "Features de biome"
    if re.search(r"boulder|mesa|rock|pillar|\brock\b|debris|\brocher", name): return "Roches & terrain"
    if "crystal" in name or name == "crystal": return "Cristaux"
    if "bush" in name or "deadtree" in name or "tree" in name: return "Flore"
    if "container" in name or "crate" in name or "barrier" in name or "pylon" in name or "wreck" in name: return "Structures & debris"
    if re.match(r"g\d+$", name): return "Divers (g##)"
    return "Autres"

out = {"biomes": BIOMES, "biome_label": BIOME_LABEL, "grounds": {}, "decor": {}}

# grounds (tiled bg). Keep a bit larger for tiling quality.
for b in BIOMES:
    p = os.path.join(D, "ground_%s.png" % b)
    if os.path.exists(p):
        out["grounds"][b] = b64(thumb(load(p), 256))

# all decor objects
for f in sorted(os.listdir(D)):
    if not f.endswith(".png"): continue
    name = f[:-4]
    if name.startswith("ground_"): continue
    im = load(p_full := os.path.join(D, f))
    t = thumb(im, 150)
    out["decor"][name] = {"url": b64(t), "w": t.width, "h": t.height, "group": group_of(name)}

# mech chassis (size reference) reused from the shield/weapon asset pack.
# _sh_assets stores raw base64 (no data: prefix) -> add it so <img>/Image work directly.
try:
    sh = json.load(open(os.path.join(ROOT, "cine", "_show", "_sh_assets.json")))
    out["mech"] = {}
    for k, v in sh["mech"].items():
        out["mech"][k] = v if str(v).startswith("data:") else "data:image/png;base64," + v
    print("mech chassis:", list(out["mech"].keys()))
except Exception as e:
    print("no mech reuse", e); out["mech"] = {}

dst = os.path.join(ROOT, "cine", "_show", "_map_assets.json")
json.dump(out, open(dst, "w"), separators=(",", ":"))
kb = os.path.getsize(dst) / 1024
print("wrote", dst, "%.0f KB" % kb)
print("grounds:", list(out["grounds"].keys()))
groups = {}
for n, d in out["decor"].items():
    groups.setdefault(d["group"], []).append(n)
for g, items in groups.items():
    print(" ", g, "=", len(items))
print("total decor:", len(out["decor"]))
