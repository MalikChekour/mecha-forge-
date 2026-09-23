"""High-quality still generator via fal.ai — FLUX 1.1 [pro] ultra (sharp, detailed, real 16:9).
Usage: python fal_gen.py "<prompt>" out.png [aspect]   aspect e.g. 16:9, 9:16, 1:1
Reads FAL_KEY. Much higher quality than FLUX schnell.
"""
import os, sys, json, urllib.request, urllib.error

KEY = os.environ.get("FAL_KEY")
# quality order
ENDPOINTS = ["fal-ai/flux-pro/v1.1-ultra", "fal-ai/flux/dev"]


def _post(url, payload, timeout=180):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json",
                                          "Authorization": f"Key {KEY}"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def _download(url, out):
    with urllib.request.urlopen(url, timeout=120) as r:
        data = r.read()
    with open(out, "wb") as f:
        f.write(data)


def generate(prompt, out, aspect="16:9"):
    for ep in ENDPOINTS:
        try:
            body = {"prompt": prompt, "num_images": 1, "enable_safety_checker": False}
            if "ultra" in ep:
                body["aspect_ratio"] = aspect
            else:
                # flux/dev uses image_size presets
                body["image_size"] = "landscape_16_9" if aspect == "16:9" else (
                    "portrait_16_9" if aspect == "9:16" else "square_hd")
            d = _post(f"https://fal.run/{ep}", body)
            url = d["images"][0]["url"]
            _download(url, out)
            print(f"OK  [{ep}] -> {out}")
            return True
        except urllib.error.HTTPError as e:
            print(f"..  {ep}: HTTP {e.code} {e.read().decode()[:160]}")
        except Exception as e:
            print(f"..  {ep}: {type(e).__name__} {str(e)[:160]}")
    print("ECHEC fal"); return False


if __name__ == "__main__":
    p = sys.argv[1]; out = sys.argv[2]
    asp = sys.argv[3] if len(sys.argv) > 3 else "16:9"
    generate(p, out, asp)
