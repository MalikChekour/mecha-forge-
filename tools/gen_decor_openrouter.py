"""Generate the remaining decor sprites via OpenRouter (image-output model), using the same
reference-image + prompt approach as gen_decor_tech.py (Gemini direct) but routed through
OpenRouter to use its own key/quota instead of the exhausted direct Gemini API key.
Usage: python tools/gen_decor_openrouter.py <key> [key2 ...]   (no args = generate all 11)
Reads prompts from tools/decor_export/<NN>_<key>.txt, reference image from
tools/decor_export/reference_style.png. Saves to tools/decor_gen2/<key>.png
and prints the RAW response on the first call so we can confirm the actual response shape
before trusting the parser."""
import os, sys, json, base64, glob
import requests

EXPORT = r"C:\Users\Administrator\mecha-forge\tools\decor_export"
OUT = r"C:\Users\Administrator\mecha-forge\tools\decor_gen2"
REF = os.path.join(EXPORT, "reference_style.png")
MODEL = "google/gemini-2.5-flash-image"
API_KEY = os.environ["OPENROUTER_API_KEY"]
os.makedirs(OUT, exist_ok=True)

STYLE = (
    "Study this reference prop art carefully: a top-down 3/4 isometric view of a sci-fi industrial "
    "machine, painted digital concept-art style, cool steel-blue metal with panel lines and rivets, "
    "soft directional lighting, slightly stylized (not photorealistic), crisp clean silhouette, "
    "PURE TRANSPARENT background, no ground shadow baked in, no text, no watermark. Match this exact "
    "rendering style, palette family and framing for a NEW prop described below."
)

def find_prompt_file(key: str) -> str:
    matches = glob.glob(os.path.join(EXPORT, f"*_{key}.txt"))
    if not matches:
        matches = glob.glob(os.path.join(EXPORT, f"{key}.txt"))
    if not matches:
        raise FileNotFoundError(f"no prompt file for '{key}' in {EXPORT}")
    return matches[0]

def b64_data_uri(path: str, mime: str) -> str:
    with open(path, "rb") as f:
        return f"data:{mime};base64," + base64.b64encode(f.read()).decode()

def gen_one(key: str, show_raw: bool = False) -> None:
    prompt_path = find_prompt_file(key)
    prompt_text = open(prompt_path, "r", encoding="utf-8").read().strip()
    ref_uri = b64_data_uri(REF, "image/png")

    body = {
        "model": MODEL,
        "modalities": ["image", "text"],
        "messages": [
            {"role": "user", "content": [
                {"type": "image_url", "image_url": {"url": ref_uri}},
                {"type": "text", "text": STYLE + "\n\nNow create this NEW prop: " + prompt_text +
                 " Single object, centered, game-ready sprite icon."},
            ]},
        ],
    }
    resp = requests.post(
        "https://openrouter.ai/api/v1/chat/completions",
        headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
        data=json.dumps(body), timeout=120,
    )
    if show_raw:
        print("STATUS", resp.status_code)
        print(resp.text[:2000])
    resp.raise_for_status()
    data = resp.json()
    msg = data["choices"][0]["message"]
    images = msg.get("images") or []
    n = 0
    for img in images:
        url = img.get("image_url", {}).get("url", "") if isinstance(img, dict) else ""
        if url.startswith("data:"):
            b64part = url.split(",", 1)[1]
            raw = base64.b64decode(b64part)
            p = os.path.join(OUT, f"{key}.png")
            open(p, "wb").write(raw)
            print("IMG", p, len(raw) // 1024, "Ko")
            n += 1
    if n == 0:
        print(f"[{key}] NO IMAGE in response. content=", str(msg.get("content"))[:300])

if __name__ == "__main__":
    keys = sys.argv[1:] if len(sys.argv) > 1 else [
        "porte_securite_orbitale", "emetteur_laser_rotatif", "pilier_energie",
        "segment_mur_modulaire", "plaque_de_glace", "pic_de_glace",
        "trou_glace_effondree", "bassin_liquide_toxique", "turbine_geante",
        "grille_ventilation", "sol_collant",
    ]
    for i, k in enumerate(keys):
        print("=== generating", k, "===")
        gen_one(k, show_raw=(i == 0))
