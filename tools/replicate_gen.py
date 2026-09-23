"""High-quality still generator via Replicate — FLUX 1.1 [pro]. Sharp, detailed, real aspect ratios.
Usage:  from replicate_gen import generate ; generate(prompt, out, "16:9")
Reads REPLICATE_API_TOKEN. This is the quality tier that Google/fal blocked on balance.
"""
import os, sys, json, urllib.request, urllib.error

TOK = os.environ.get("REPLICATE_API_TOKEN")
MODEL = "black-forest-labs/flux-1.1-pro"


def generate(prompt, out, aspect="16:9"):
    body = {"input": {"prompt": prompt, "aspect_ratio": aspect,
                      "output_format": "png", "safety_tolerance": 5}}
    req = urllib.request.Request(
        f"https://api.replicate.com/v1/models/{MODEL}/predictions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json",
                 "Authorization": f"Bearer {TOK}", "Prefer": "wait"})
    try:
        d = json.loads(urllib.request.urlopen(req, timeout=150).read().decode())
    except urllib.error.HTTPError as e:
        print(f"..  HTTP {e.code} {e.read().decode()[:160]}"); return False
    if d.get("status") != "succeeded" or not d.get("output"):
        print(f"..  status={d.get('status')} err={str(d.get('error'))[:120]}"); return False
    url = d["output"] if isinstance(d["output"], str) else d["output"][0]
    with urllib.request.urlopen(url, timeout=120) as r:
        open(out, "wb").write(r.read())
    print(f"OK  [flux-1.1-pro] -> {out}")
    return True


if __name__ == "__main__":
    generate(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "16:9")
