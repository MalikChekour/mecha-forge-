# Menu art (hero bg, emblem) + a mech, base64, for the menu-template presentation.
import json, base64, io, os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
M = os.path.join(ROOT, "game", "assets", "menu")

def b64(im, fmt="PNG", q=85):
    buf = io.BytesIO()
    if fmt == "JPEG":
        im.convert("RGB").save(buf, "JPEG", quality=q, optimize=True)
        return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
    im.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

def thumb(im, w):
    if im.width <= w: return im
    return im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)

out = {}
out["hero"] = b64(thumb(Image.open(os.path.join(M, "hero_bg.png")), 1100), "JPEG", 80)
em = Image.open(os.path.join(M, "emblem_cut.png")).convert("RGBA")
out["emblem"] = b64(thumb(em, 240))
try:
    sh = json.load(open(os.path.join(ROOT, "cine", "_show", "_sh_assets.json")))
    v = sh["mech"]["player"]
    out["mech"] = v if str(v).startswith("data:") else "data:image/png;base64," + v
except Exception as e:
    print("no mech", e)

dst = os.path.join(ROOT, "cine", "_show", "_menu_assets.json")
json.dump(out, open(dst, "w"), separators=(",", ":"))
print("wrote", dst, "%.0f KB" % (os.path.getsize(dst)/1024), "| keys:", list(out.keys()))
