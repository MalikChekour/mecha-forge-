"""Generate a mecha walk sprite sheet with Gemini 2.5 Flash Image ('Nano Banana'), following the
video technique: teach the format with a reference sheet, then ask for the character's sheet.
Usage: python tools/gemini_sheet.py <tag> [ref.png]
Saves every returned image to cine/gemini/<tag>_<n>.png and prints any text the model returns."""
import os, sys
from google import genai
from google.genai import types

TAG = sys.argv[1] if len(sys.argv) > 1 else "t1"
REF = sys.argv[2] if len(sys.argv) > 2 else None
OUT = r"C:\Users\Administrator\mecha-forge\cine\gemini"
os.makedirs(OUT, exist_ok=True)
MODEL = "gemini-2.5-flash-image"

client = genai.Client(api_key=os.environ["GOOGLE_API_KEY"])
char = open(r"C:\Users\Administrator\mecha-forge\cine\pixel\hi_1.png", "rb").read()

contents = []
if REF:
    ref = open(REF, "rb").read()
    contents += [
        types.Part.from_bytes(data=ref, mime_type="image/png"),
        ("Study this sprite sheet carefully. It is the FORMAT I want: a heavy battle-mecha shown as "
         "an animation strip, one pose per cell, centered on a transparent background, consistent size "
         "and lighting across every cell. Learn its grid layout, framing and pixel-art style."),
    ]

contents += [
    types.Part.from_bytes(data=char, mime_type="image/png"),
    ("Now make a WALK-CYCLE sprite sheet of THIS mecha. Follow exactly the format and pixel-art style "
     "of the reference. Layout: 4 rows = 4 facings (row1 FRONT/toward camera, row2 BACK, row3 LEFT side, "
     "row4 RIGHT side); each row = 6 frames of one full walking cycle, left to right. "
     "Make it a REAL articulated walk: legs clearly step, knees bend, one foot lifts and plants while the "
     "other pushes off, arms/torso sway naturally, weight shifts. Every cell same size, mecha centered, "
     "pure transparent background, no grid lines, no text. Keep the mecha's exact design, proportions and "
     "colors from the artwork. Clean game-ready pixel art."),
]

resp = client.models.generate_content(
    model=MODEL, contents=contents,
    config=types.GenerateContentConfig(response_modalities=["IMAGE", "TEXT"]),
)
n = 0
for part in resp.candidates[0].content.parts:
    if getattr(part, "inline_data", None) and part.inline_data.data:
        p = os.path.join(OUT, f"{TAG}_{n}.png")
        open(p, "wb").write(part.inline_data.data)
        print("IMG", p, len(part.inline_data.data) // 1024, "Ko")
        n += 1
    elif getattr(part, "text", None):
        print("TXT:", part.text[:300])
if n == 0:
    print("NO IMAGE returned")
