"""Single-frame POSE transfer: take one george walk frame, reduce it to a black silhouette (pose only,
no color to copy), and ask Nano Banana to redraw the CHARACTER mecha filling that exact pose silhouette.
Usage: python tools/nano_pose_frame.py <dir> <frameIndex>"""
import os, sys, json, base64, io, urllib.request, urllib.error
import numpy as np
from PIL import Image

TOK = os.environ["REPLICATE_API_TOKEN"]
MODEL = "google/nano-banana"
DIRN = sys.argv[1] if len(sys.argv) > 1 else "front"
IDX = int(sys.argv[2]) if len(sys.argv) > 2 else 3
OUT = r"C:\Users\Administrator\mecha-forge\cine\gemini"
os.makedirs(OUT, exist_ok=True)


def data_uri(im):
    b = io.BytesIO(); im.convert("RGBA").save(b, "PNG")
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


sheet = Image.open(f"game/assets/mecha/george_walk_{DIRN}.png").convert("RGBA")
fw = sheet.width // 8
frame = sheet.crop((IDX * fw, 0, (IDX + 1) * fw, sheet.height))
# black silhouette on white
a = np.asarray(frame.getchannel("A"))
sil = np.where(a[..., None] > 60, np.array([20, 20, 20], np.uint8), np.array([255, 255, 255], np.uint8))
sil_im = Image.fromarray(sil.astype(np.uint8), "RGB")
sil_im.save(os.path.join(OUT, f"sil_{DIRN}_{IDX}.png"))

# character reference in the CORRECT facing: front uses the hi-res artwork, others use our idle sheet f0
if DIRN == "front":
    char_im = Image.open(r"C:\Users\Administrator\mecha-forge\cine\pixel\hi_1.png")
else:
    ish = Image.open(f"game/assets/mecha/lourd_idle_{DIRN}.png").convert("RGBA")
    ifw = ish.width // 8
    char_im = ish.crop((0, 0, ifw, ish.height))

face_txt = {"front": "toward the viewer (front)", "back": "seen from BEHIND (its back)",
            "left": "in left-side profile", "right": "in right-side profile"}[DIRN]
ref_uri = data_uri(sil_im)
char_uri = data_uri(char_im)

prompt = (
    "The FIRST image is a black POSE SILHOUETTE of a walking mecha " + face_txt + " (only the shape/pose "
    "matters: note the leg positions — one leg stepping/lifted, the other planted — and the arm positions). "
    "The SECOND image is the CHARACTER mecha, shown " + face_txt + ". "
    "Redraw the CHARACTER mecha posed to EXACTLY fill that silhouette: same leg stance, same stride, same "
    "arm positions, same facing (" + face_txt + ") and proportions as the silhouette — but rendered with the "
    "CHARACTER's own design, armor, glowing blue core and orange/steel colors. Keep it facing " + face_txt +
    ". ONE single mecha, full body, centered, on a plain flat neutral background, no text. Crisp game-ready "
    "pixel art." +
    (" IMPORTANT: this is the BACK of the mecha viewed from behind — do NOT show the blue core, the face or "
     "the chest. Show only the REAR: the backpack/reactor, the two antennae, the shoulder blades, thruster "
     "nozzles and the backs of the legs. The head faces away from us." if DIRN == "back" else ""))

body = {"input": {"prompt": prompt, "image_input": [ref_uri, char_uri], "output_format": "png"}}
req = urllib.request.Request(
    f"https://api.replicate.com/v1/models/{MODEL}/predictions",
    data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json", "Authorization": f"Bearer {TOK}", "Prefer": "wait"})
try:
    d = json.loads(urllib.request.urlopen(req, timeout=200).read().decode())
except urllib.error.HTTPError as e:
    print("HTTP", e.code, e.read().decode()[:400]); sys.exit(1)
print("status:", d.get("status"), "| err:", str(d.get("error"))[:120])
o = d.get("output")
if o:
    url = o if isinstance(o, str) else o[0]
    dst = os.path.join(OUT, f"pf_{DIRN}_{IDX}.png")
    with urllib.request.urlopen(url, timeout=120) as r:
        open(dst, "wb").write(r.read())
    print("SAVED", dst, os.path.getsize(dst) // 1024, "Ko")
