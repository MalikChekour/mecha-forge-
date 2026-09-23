"""Cinematic still generator — tries the highest-quality Google image models first, falls back.
Usage: python cine_gen.py "<prompt>" out.png [aspect]   (aspect e.g. 16:9, 9:16, 1:1)
Reads GOOGLE_API_KEY; falls back to FLUX (Cloudflare) if Google image quota is exhausted.
"""
import os, sys, json, base64, io, urllib.request, urllib.error
from PIL import Image

KEY = os.environ.get("GOOGLE_API_KEY")
BASE = "https://generativelanguage.googleapis.com/v1beta/models"
# quality order: dedicated Imagen ultra -> Gemini 3 Pro image -> 3.1 flash image
IMAGEN = ["imagen-4.0-ultra-generate-001", "imagen-4.0-generate-001"]
GEMINI_IMG = ["gemini-3-pro-image", "gemini-3.1-flash-image"]


def _post(url, payload, timeout=180):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def try_imagen(model, prompt, aspect):
    d = _post(f"{BASE}/{model}:predict?key={KEY}",
              {"instances": [{"prompt": prompt}],
               "parameters": {"sampleCount": 1, "aspectRatio": aspect}})
    b64 = d["predictions"][0]["bytesBase64Encoded"]
    return base64.b64decode(b64)


def try_gemini(model, prompt):
    d = _post(f"{BASE}/{model}:generateContent?key={KEY}",
              {"contents": [{"parts": [{"text": prompt}]}],
               "generationConfig": {"responseModalities": ["IMAGE"]}})
    for p in d["candidates"][0]["content"]["parts"]:
        if "inlineData" in p:
            return base64.b64decode(p["inlineData"]["data"])
    raise RuntimeError("no image part")


def try_flux(prompt, aspect):
    acct = os.environ.get("CF_ACCOUNT_ID"); tok = os.environ.get("CF_API_TOKEN")
    d = _post(f"https://api.cloudflare.com/client/v4/accounts/{acct}/ai/run/@cf/black-forest-labs/flux-1-schnell",
              {"prompt": prompt, "steps": 8})
    # CF returns JSON with result.image (b64); auth header needed
    return None  # handled separately below


def flux_authed(prompt):
    acct = os.environ.get("CF_ACCOUNT_ID"); tok = os.environ.get("CF_API_TOKEN")
    req = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4/accounts/{acct}/ai/run/@cf/black-forest-labs/flux-1-schnell",
        data=json.dumps({"prompt": prompt, "steps": 8}).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {tok}"})
    with urllib.request.urlopen(req, timeout=120) as r:
        d = json.loads(r.read().decode())
    return base64.b64decode(d["result"]["image"])


def generate(prompt, out, aspect="16:9"):
    for m in IMAGEN:
        try:
            raw = try_imagen(m, prompt, aspect)
            Image.open(io.BytesIO(raw)).convert("RGB").save(out)
            print(f"OK  [{m}] -> {out}"); return True
        except urllib.error.HTTPError as e:
            print(f"..  {m}: HTTP {e.code} {e.read().decode()[:120]}")
        except Exception as e:
            print(f"..  {m}: {str(e)[:120]}")
    for m in GEMINI_IMG:
        try:
            raw = try_gemini(m, prompt)
            Image.open(io.BytesIO(raw)).convert("RGB").save(out)
            print(f"OK  [{m}] -> {out}"); return True
        except urllib.error.HTTPError as e:
            print(f"..  {m}: HTTP {e.code} {e.read().decode()[:120]}")
        except Exception as e:
            print(f"..  {m}: {str(e)[:120]}")
    try:
        raw = flux_authed(prompt)
        Image.open(io.BytesIO(raw)).convert("RGB").save(out)
        print(f"OK  [FLUX schnell] -> {out}"); return True
    except Exception as e:
        print(f"..  FLUX: {str(e)[:120]}")
    print("ECHEC total"); return False


if __name__ == "__main__":
    p = sys.argv[1]; out = sys.argv[2]
    asp = sys.argv[3] if len(sys.argv) > 3 else "16:9"
    generate(p, out, asp)
