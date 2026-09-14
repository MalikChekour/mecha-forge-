#!/usr/bin/env python3
"""
Image -> 3D via fal.ai (queue API, raw httpx — no fal_client needed).
Cheaper alternative to Meshy; uses FAL_KEY from env.

  python fal_img23d.py <input.png> <outdir> [model]

Tries a few known image-to-3D model ids until one accepts the request, submits,
polls the queue, and downloads the resulting GLB into <outdir>/model.glb.
"""
import os, sys, json, time, base64, mimetypes, httpx

KEY = os.environ.get("FAL_KEY")
IN = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)

# candidate models (id, input-key, how to dig the glb url out of the result)
CANDIDATES = [
    ("fal-ai/trellis", "image_url", ["model_mesh", "url"]),
    ("fal-ai/hunyuan3d-v21", "input_image_url", ["model_glb", "url"]),
    ("fal-ai/hunyuan3d/v2", "input_image_url", ["model_mesh", "url"]),
    ("fal-ai/triposr", "image_url", ["model_mesh", "url"]),
]
if len(sys.argv) > 3:
    CANDIDATES = [c for c in CANDIDATES if c[0] == sys.argv[3]] or CANDIDATES

def data_uri(path):
    mime = mimetypes.guess_type(path)[0] or "image/png"
    return f"data:{mime};base64," + base64.b64encode(open(path, "rb").read()).decode()

def dig(d, path):
    for k in path:
        if isinstance(d, dict):
            d = d.get(k)
        else:
            return None
    return d

H = {"Authorization": f"Key {KEY}", "Content-Type": "application/json"}
img = data_uri(IN)
print(f"input {IN} ({os.path.getsize(IN)//1024} KB)")

with httpx.Client(timeout=60) as cx:
    for model, ikey, glbpath in CANDIDATES:
        body = {ikey: img}
        print(f"\n== try {model} ==")
        try:
            r = cx.post(f"https://queue.fal.run/{model}", headers=H, json=body)
        except Exception as e:
            print("  submit error:", e); continue
        if r.status_code not in (200, 201):
            print(f"  submit HTTP {r.status_code}: {r.text[:200]}"); continue
        q = r.json()
        rid = q.get("request_id")
        status_url = q.get("status_url") or f"https://queue.fal.run/{model}/requests/{rid}/status"
        resp_url = q.get("response_url") or f"https://queue.fal.run/{model}/requests/{rid}"
        print(f"  submitted, request_id={rid}")
        result = None
        for _ in range(120):                     # up to ~6 min
            time.sleep(3)
            s = cx.get(status_url, headers=H)
            st = s.json().get("status")
            if st == "COMPLETED":
                result = cx.get(resp_url, headers=H).json(); break
            if st in ("FAILED", "ERROR"):
                print("  job failed:", s.text[:200]); break
            print(f"  ...{st}")
        if not result:
            continue
        url = dig(result, glbpath)
        if not url:                              # unknown shape -> dump keys to adapt
            print("  result keys:", list(result.keys()), "->", json.dumps(result)[:400]); continue
        glb = cx.get(url, timeout=180).content
        open(os.path.join(OUT, "model.glb"), "wb").write(glb)
        print(f"\nSAVED {OUT}/model.glb ({len(glb)//1024} KB) via {model}")
        sys.exit(0)
print("\nALL CANDIDATES FAILED")
sys.exit(1)
