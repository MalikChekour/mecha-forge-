"""Per-DIRECTION walk strip via Nano Banana: give one articulated 8-frame walk row as the pose
reference + the character, ask for the SAME 8 frames re-skinned as the character. One image per call
keeps Nano Banana internally consistent. Usage: python tools/nano_row.py <dir>  (front/back/left/right)"""
import os, sys, json, base64, io, urllib.request, urllib.error
from PIL import Image

TOK = os.environ["REPLICATE_API_TOKEN"]
MODEL = "google/nano-banana"
DIRN = sys.argv[1] if len(sys.argv) > 1 else "front"
OUT = r"C:\Users\Administrator\mecha-forge\cine\gemini"
os.makedirs(OUT, exist_ok=True)


def data_uri(path_or_im, maxpx=1536):
    im = path_or_im if isinstance(path_or_im, Image.Image) else Image.open(path_or_im)
    im = im.convert("RGBA")
    if max(im.size) > maxpx:
        r = maxpx / max(im.size)
        im = im.resize((int(im.width * r), int(im.height * r)), Image.LANCZOS)
    b = io.BytesIO(); im.save(b, "PNG")
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


# reference: one direction's articulated 8-frame walk row (put it on white for clarity)
ref = Image.open(f"game/assets/mecha/george_walk_{DIRN}.png").convert("RGBA")
white = Image.new("RGBA", ref.size, (255, 255, 255, 255)); white.alpha_composite(ref)
ref_uri = data_uri(white)
char_uri = data_uri(r"C:\Users\Administrator\mecha-forge\cine\pixel\hi_1.png")

facing = {"front": "toward the viewer (front)", "back": "away from the viewer (back)",
          "left": "to the left (left side profile)", "right": "to the right (right side profile)"}[DIRN]

prompt = (
    "The FIRST image is a REFERENCE WALK STRIP: one heavy mecha, facing " + facing + ", shown as 8 frames "
    "in a single horizontal row — one full articulated walking cycle read left to right (legs clearly "
    "stepping, knees bending, one foot lifting and planting while the other pushes off, torso and arms "
    "swaying with the weight shift). "
    "The SECOND image is the CHARACTER mecha. "
    "Draw a NEW single horizontal row of exactly 8 frames that copies the REFERENCE's body pose in every "
    "frame (frame 1 matches reference frame 1, frame 2 matches reference frame 2, and so on — same leg and "
    "arm positions, same facing), but re-skinned as the CHARACTER: keep the character's exact design, armor "
    "shapes, proportions, glowing blue core and orange/steel colors. Do NOT copy the reference's green "
    "color. All 8 frames the same size, the mecha centered in each frame, evenly spaced, on a plain flat "
    "neutral background, no grid lines, no text. Crisp game-ready pixel art, one row only.")

body = {"input": {"prompt": prompt, "image_input": [ref_uri, char_uri], "output_format": "png"}}
req = urllib.request.Request(
    f"https://api.replicate.com/v1/models/{MODEL}/predictions",
    data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json", "Authorization": f"Bearer {TOK}", "Prefer": "wait"})
try:
    d = json.loads(urllib.request.urlopen(req, timeout=200).read().decode())
except urllib.error.HTTPError as e:
    print("HTTP", e.code, e.read().decode()[:400]); sys.exit(1)
print("status:", d.get("status"), "| err:", str(d.get("error"))[:160])
o = d.get("output")
if o:
    url = o if isinstance(o, str) else o[0]
    dst = os.path.join(OUT, f"row_{DIRN}.png")
    with urllib.request.urlopen(url, timeout=120) as r:
        open(dst, "wb").write(r.read())
    print("SAVED", dst, os.path.getsize(dst) // 1024, "Ko")
