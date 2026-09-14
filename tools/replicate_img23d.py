#!/usr/bin/env python3
"""
Image -> textured 3D GLB via Replicate TRELLIS (firtoz/trellis). Uses REPLICATE_API_TOKEN.
  python replicate_img23d.py <input.png> <outdir>
"""
import os, sys, json, time, base64, mimetypes, httpx

TOK = os.environ.get("REPLICATE_API_TOKEN")
IN, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
H = {"Authorization": f"Bearer {TOK}", "Content-Type": "application/json"}

def data_uri(p):
    mime = mimetypes.guess_type(p)[0] or "image/png"
    return f"data:{mime};base64," + base64.b64encode(open(p, "rb").read()).decode()

body = {"input": {
    "images": [data_uri(IN)],
    "texture_size": 2048,
    "mesh_simplify": 0.92,
    "generate_color": True,
    "generate_model": True,
    "generate_normal": True,
    "ss_sampling_steps": 38,
    "slat_sampling_steps": 20,
}}
print(f"input {IN} ({os.path.getsize(IN)//1024} KB) -> firtoz/trellis")
with httpx.Client(timeout=90) as cx:
    r = cx.post("https://api.replicate.com/v1/predictions", headers=H, json={**body, "version": "e8f6c45206993f297372f5436b90350817bd9b4a0d52d2a76df50c1c8afa2b3c"})
    if r.status_code not in (200, 201):
        print(f"submit HTTP {r.status_code}: {r.text[:300]}"); sys.exit(1)
    pred = r.json()
    get_url = pred["urls"]["get"]
    print("submitted:", pred["id"])
    out = None
    for _ in range(160):                          # up to ~8 min
        time.sleep(3)
        s = cx.get(get_url, headers=H).json()
        st = s["status"]
        if st == "succeeded":
            out = s["output"]; break
        if st in ("failed", "canceled"):
            print("job", st, ":", str(s.get("error"))[:300]); sys.exit(1)
    if out is None:
        print("timeout"); sys.exit(1)
    print("output shape:", json.dumps(out)[:300])
    # dig the glb url out of whatever shape TRELLIS returns
    url = None
    if isinstance(out, dict):
        for k in ("model_file", "model", "glb", "mesh"):
            if out.get(k):
                url = out[k] if isinstance(out[k], str) else out[k].get("url"); break
    elif isinstance(out, str):
        url = out
    if not url:
        print("no glb url found in output"); sys.exit(1)
    glb = cx.get(url, timeout=240).content
    open(os.path.join(OUT, "model.glb"), "wb").write(glb)
    print(f"SAVED {OUT}/model.glb ({len(glb)//1024} KB)")
