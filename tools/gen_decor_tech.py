"""Generate the 9 new 'Secteur Tech' interactive-decor sprites with Gemini 2.5 Flash Image,
matching the existing decor catalog's style (reference: assets/decor/g27.png).
Usage: python tools/gen_decor_tech.py <key> [key2 ...]   (no args = generate all 9)
Saves to tools/decor_gen/<key>_<n>.png for review before promoting into assets/decor/."""
import os, sys
from google import genai
from google.genai import types

OUT = r"C:\Users\Administrator\mecha-forge\tools\decor_gen"
REF = r"C:\Users\Administrator\mecha-forge\game\assets\decor\g27.png"
MODEL = "gemini-2.5-flash-image"
os.makedirs(OUT, exist_ok=True)
client = genai.Client(api_key=os.environ["GOOGLE_API_KEY"])

STYLE = (
    "Study this reference prop art carefully: a top-down 3/4 isometric view of a sci-fi industrial "
    "machine, painted digital concept-art style, cool steel-blue metal with panel lines and rivets, "
    "soft directional lighting, slightly stylized (not photorealistic), crisp clean silhouette, "
    "PURE TRANSPARENT background, no ground shadow baked in, no text, no watermark. Match this exact "
    "rendering style, palette family and framing for a NEW prop described below."
)

PROMPTS = {
    "convoyeur_sol": (
        "A short straight section of an industrial conveyor belt set into a factory floor: metal "
        "rollers on each end, a dark rubber belt surface with faint directional chevron markings, "
        "a thin glowing ORANGE strip along both edges. Seen from the same 3/4 top-down angle."
    ),
    "console_convoyeur": (
        "A standalone factory control console on a sturdy metal pedestal: angled top panel with a "
        "glowing CYAN screen showing simple readouts, a few physical buttons, antenna stub on top. "
        "Same 3/4 top-down angle."
    ),
    "bras_presseur": (
        "A heavy industrial hydraulic PRESS ARM mounted on a floor pedestal: a thick articulated "
        "metal arm ending in a flat square press head, hydraulic pistons along its length, a warning "
        "ORANGE glow strip near the press head. Same 3/4 top-down angle, arm resting/raised."
    ),
    "piston_hydraulique": (
        "A vertical industrial hydraulic PISTON column rising from a floor base: a wide metal cylinder "
        "base, a narrower polished piston rod extending upward, hydraulic hoses wrapped around the "
        "base, a thin CYAN accent light ring at the base. Same 3/4 top-down angle."
    ),
    "vanne_refroidissement": (
        "An industrial coolant VALVE station: a round metal wheel-valve mounted on a pipe junction "
        "with two curved pipes feeding into it, a small gauge, a faint CYAN frost/steam glow around "
        "the valve wheel. Same 3/4 top-down angle."
    ),
    "surchauffe_sol": (
        "A floor HEAT VENT grate set flush into the ground: a metal grille with glowing ORANGE-RED "
        "heat lines radiating from the vents, faint heat-shimmer, no vertical structure (lies flat on "
        "the ground). Same top-down angle as the reference, but flatter/lower profile."
    ),
    "porte_automatique": (
        "A heavy industrial sliding BULKHEAD DOOR set into a frame: two thick metal door panels that "
        "meet in the middle, diagonal hazard stripes near the seam, a small CYAN status light above "
        "the frame. Same 3/4 top-down angle, shown CLOSED."
    ),
    "zone_chargement": (
        "A factory LOADING MARKER on the floor: a square hazard-striped floor plate (yellow/black "
        "stripes) with a small overhead gantry hook hanging just above it, faint ORANGE warning glow. "
        "Same 3/4 top-down angle."
    ),
    "container_mobile": (
        "A compact industrial CARGO CONTAINER on a small rail-wheel base: a metal box with corrugated "
        "side panels, faded stencil markings, small wheels visible at the bottom resting on a short "
        "rail track segment. Same 3/4 top-down angle."
    ),
}

def gen_one(key: str) -> None:
    prompt = PROMPTS[key]
    ref = open(REF, "rb").read()
    contents = [
        types.Part.from_bytes(data=ref, mime_type="image/png"),
        STYLE,
        f"Now create this NEW prop: {prompt} Single object, centered, game-ready sprite icon.",
    ]
    resp = client.models.generate_content(
        model=MODEL, contents=contents,
        config=types.GenerateContentConfig(response_modalities=["IMAGE", "TEXT"]),
    )
    n = 0
    for part in resp.candidates[0].content.parts:
        if getattr(part, "inline_data", None) and part.inline_data.data:
            p = os.path.join(OUT, f"{key}_{n}.png")
            open(p, "wb").write(part.inline_data.data)
            print("IMG", p, len(part.inline_data.data) // 1024, "Ko")
            n += 1
        elif getattr(part, "text", None):
            print(f"[{key}] TXT:", part.text[:300])
    if n == 0:
        print(f"[{key}] NO IMAGE returned")

if __name__ == "__main__":
    keys = sys.argv[1:] if len(sys.argv) > 1 else list(PROMPTS.keys())
    for k in keys:
        print("=== generating", k, "===")
        gen_one(k)
