"""Walk sprite-sheet via Nano Banana (Gemini 2.5 Flash Image) hosted on Replicate — the direct
Gemini API blocks image gen on this key's free tier, Replicate bills via REPLICATE_API_TOKEN.
Video technique: feed a format-reference sheet + the character artwork + one instruction.
Usage: python tools/nano_sheet.py <tag> [ref.png]   (no ref => text-only grid spec)
"""
import os, sys, json, base64, io, urllib.request, urllib.error
from PIL import Image

TOK = os.environ["REPLICATE_API_TOKEN"]
MODEL = "google/nano-banana"
TAG = sys.argv[1] if len(sys.argv) > 1 else "n1"
REF = sys.argv[2] if len(sys.argv) > 2 else None
OUT = r"C:\Users\Administrator\mecha-forge\cine\gemini"
os.makedirs(OUT, exist_ok=True)


def data_uri(path, maxpx=1024):
    im = Image.open(path).convert("RGBA")
    if max(im.size) > maxpx:
        r = maxpx / max(im.size)
        im = im.resize((int(im.width * r), int(im.height * r)), Image.LANCZOS)
    b = io.BytesIO(); im.save(b, "PNG")
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


char = data_uri(r"C:\Users\Administrator\mecha-forge\cine\pixel\hi_1.png")
images = []
if REF:
    images.append(data_uri(REF))
    images.append(char)
    prompt = (
        "The FIRST image is a REFERENCE WALK sprite sheet: a mecha shown as a 4x8 grid — 4 rows are 4 "
        "facings (row1 FRONT toward viewer, row2 BACK away, row3 LEFT side, row4 RIGHT side), and the 8 "
        "columns of each row are 8 frames of one articulated walking cycle (legs stepping, knees bending, "
        "feet lifting and planting, weight shifting). "
        "The SECOND image is the CHARACTER — a heavy battle-mecha. "
        "Produce a NEW sprite sheet with the EXACT SAME 4x8 grid, the EXACT SAME walking pose in every "
        "single cell (same facing per row, same leg/arm position per column as the reference), but re-drawn "
        "as the CHARACTER mecha: keep the character's exact design, armor shapes, proportions, glowing core "
        "and orange/steel color scheme. Only transfer the POSES from the reference; keep the LOOK of the "
        "character. Every cell identical size, mecha centered, plain flat neutral background, no grid lines, "
        "no text. Crisp game-ready pixel art.")
else:
    images.append(char)
    prompt = (
        "Make a WALK-CYCLE sprite sheet of this heavy battle-mecha. 4 rows (FRONT, BACK, LEFT, RIGHT) x 6 "
        "columns of one articulated walk cycle: legs step, knees bend, feet lift and plant, weight shifts. "
        "Every cell same size, centered, flat neutral background, no text. Keep its exact design and colors. "
        "Crisp game-ready pixel art.")

body = {"input": {"prompt": prompt, "image_input": images, "output_format": "png"}}
req = urllib.request.Request(
    f"https://api.replicate.com/v1/models/{MODEL}/predictions",
    data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json", "Authorization": f"Bearer {TOK}", "Prefer": "wait"})
try:
    d = json.loads(urllib.request.urlopen(req, timeout=200).read().decode())
except urllib.error.HTTPError as e:
    print("HTTP", e.code, e.read().decode()[:400]); sys.exit(1)

print("status:", d.get("status"), "| err:", str(d.get("error"))[:160])
out = d.get("output")
if out:
    url = out if isinstance(out, str) else out[0]
    dst = os.path.join(OUT, f"{TAG}.png")
    with urllib.request.urlopen(url, timeout=120) as r:
        open(dst, "wb").write(r.read())
    print("SAVED", dst, os.path.getsize(dst) // 1024, "Ko")
else:
    print("no output")
