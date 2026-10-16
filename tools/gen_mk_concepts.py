"""Concepts MK2/MK3/MK4 de VORTEX et BLUESTRIKE (16/10) via fal.ai nano-banana/edit, partant du sprite actuel.
Aucun effet sur le jeu : ce sont des PLANCHES de concept a valider (ou annuler) avant toute integration.
Usage : python gen_mk_concepts.py   (FAL_KEY en environnement)"""
import os, sys, json, base64, io, time, urllib.request
from PIL import Image
KEY = os.environ["FAL_KEY"]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "refs", "mk_concepts")
os.makedirs(OUT, exist_ok=True)

def ref(sheet, name):
    im = Image.open(os.path.join(ROOT, "game", "assets", "mecha", sheet)).convert("RGBA").crop((0, 0, 256, 256))
    bb = im.getbbox(); im = im.crop(bb)
    s = 900 / max(im.size)
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    bg = Image.new("RGB", (1024, 1024), (58, 66, 80))
    bg.paste(im, ((1024 - im.width) // 2, (1024 - im.height) // 2), im)
    p = os.path.join(OUT, "_ref_%s.png" % name); bg.save(p)
    buf = io.BytesIO(); bg.resize((768, 768), Image.LANCZOS).save(buf, "JPEG", quality=90)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()

COMMON = ("Same mecha, same character, same pose and same front view, same color identity. Full body visible, centered, "
          "plain flat dark slate background, no text, no logo, game concept art, crisp detailed hard-surface design, "
          "painterly 3D render. ")
SPEC = {
 "vortex": {
  "id": "Vortex: sleek black armor, cyan neon lines, orange glowing chest core, a long energy blade held at the side. ",
  "mk": {
   "mk2": "MARK II upgrade: extra layered armor plates on shoulders and forearms, sharper angular helmet crest, brighter cyan neon circuitry, reinforced knees, a cleaner longer energy blade with cyan edge glow.",
   "mk3": "MARK III upgrade: heavier armored silhouette, small back thrusters with cyan flame vents, shoulder-mounted energy shield emitters, more intricate neon circuitry, glowing orange core inside a reinforced chest frame, blade with plasma aura.",
   "mk4": "MARK IV ultimate version: elite flagship look, black armor with polished chrome and subtle gold trim, floating detached shoulder plates with cyan halo rings, wing-like blade fins on the back, intense orange-white core, a double-edged radiant energy blade."}},
 "bluestrike": {
  "id": "Bluestrike: grey and orange armor, huge round shoulder pods, cyan and magenta glowing head visor, light fast scout. ",
  "mk": {
   "mk2": "MARK II upgrade: extra orange armor plating, improved shoulder pods with vent slits, sharper head crest, brighter cyan/magenta visor, reinforced fists and knees, cleaner paint with panel lines.",
   "mk3": "MARK III upgrade: heavier assault configuration, shoulder pods turned into twin blaster cannons, small back thrusters with orange flame, extra armor skirt, glowing energy conduits on arms and legs.",
   "mk4": "MARK IV ultimate version: elite prototype look, orange and gunmetal armor with white and gold trim accents, floating weapon drones attached behind the shoulders, glowing visor halo, energy wings of translucent cyan light, intense core glow."}}}

def post(url, payload):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json", "Authorization": "Key " + KEY})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.loads(r.read().decode())

if __name__ == "__main__":
    only = sys.argv[1:] 
    for name, spec in SPEC.items():
        uri = ref("%s_idle_front.png" % name if name == "vortex" else "%s_walk_front.png" % name, name)
        for mk, desc in spec["mk"].items():
            dst = os.path.join(OUT, "%s_%s.png" % (name, mk))
            if only and "%s_%s" % (name, mk) not in only: continue
            if os.path.exists(dst): continue
            prompt = COMMON + spec["id"] + desc
            try:
                d = post("https://fal.run/fal-ai/nano-banana/edit", {"prompt": prompt, "image_urls": [uri], "num_images": 1})
                url = d["images"][0]["url"]
                with urllib.request.urlopen(url, timeout=120) as r: open(dst, "wb").write(r.read())
                print("OK", dst)
            except Exception as e:
                print("ECHEC", name, mk, str(e)[:200])
            time.sleep(1)
