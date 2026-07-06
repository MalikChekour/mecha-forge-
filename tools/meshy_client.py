#!/usr/bin/env python3
"""
mecha-forge — Meshy AI client (image->3D / text->3D, textured PBR GLB).

Meshy v6 gives real hard-surface geometry + PBR textures without a local GPU.
This client generates a textured GLB (+ texture maps) and drops it into
tools/../meshy_in/<name>/ ready for bake_meshy.py to render into 2D sprites.

Auth: reads MESHY_KEY from the environment (never hardcode — brief §8).
Requires a paid Meshy plan (API access). Costs: preview 20 cr, textured ~30 cr.

Usage:
  set MESHY_KEY=...   (PowerShell: $env:MESHY_KEY="...")
  python meshy_client.py text  "top-down 3/4 heroic battle mecha, blue steel armor, glowing cyan core" --name vanguard --pbr
  python meshy_client.py image  path\\to\\concept.png  --name crawler --pbr
  python meshy_client.py image  https://.../concept.png --name drone

Docs verified 2026-07: https://docs.meshy.ai/en/api/{image-to-3d,text-to-3d}
"""
import os, sys, json, time, base64, mimetypes, urllib.request, urllib.error

BASE = "https://api.meshy.ai/openapi"
KEY = os.environ.get("MESHY_KEY") or os.environ.get("MESHY_API_KEY")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDIR = os.path.join(ROOT, "meshy_in")


def _req(method, path, body=None):
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer %s" % KEY,
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        raise RuntimeError("HTTP %s: %s" % (e.code, e.read().decode()[:400]))


def _task_id(resp):
    return resp.get("result") or resp.get("id")


def poll(get_path, label=""):
    delay = 5
    while True:
        t = _req("GET", get_path)
        st, pr = t.get("status"), t.get("progress", 0)
        print("  [%s] %s %d%%" % (label, st, pr), flush=True)
        if st == "SUCCEEDED":
            return t
        if st in ("FAILED", "CANCELED"):
            raise RuntimeError("task %s: %s" % (st, t.get("task_error")))
        time.sleep(delay)
        delay = min(delay + 2, 15)


def _data_uri(path):
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as f:
        return "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode())


def download(url, path):
    if not url:
        return False
    req = urllib.request.Request(url, headers={"User-Agent": "mecha-forge"})
    with urllib.request.urlopen(req, timeout=300) as r, open(path, "wb") as f:
        f.write(r.read())
    return True


def _save(task, name):
    outdir = os.path.join(INDIR, name)
    os.makedirs(outdir, exist_ok=True)
    mu = task.get("model_urls", {})
    ok = download(mu.get("glb"), os.path.join(outdir, "model.glb"))
    tex = (task.get("texture_urls") or [{}])[0]
    for k in ("base_color", "metallic", "roughness", "normal", "emission"):
        if tex.get(k):
            download(tex[k], os.path.join(outdir, "tex_%s.png" % k))
    download(task.get("thumbnail_url"), os.path.join(outdir, "thumb.png"))
    with open(os.path.join(outdir, "meta.json"), "w") as f:
        json.dump({"id": task.get("id"), "credits": task.get("consumed_credits")}, f, indent=2)
    print("SAVED %s (glb=%s, credits=%s)" % (outdir, ok, task.get("consumed_credits")))
    return outdir


def gen_image(image, name, pbr=False):
    img = image if image.startswith("http") else _data_uri(image)
    body = {"image_url": img, "ai_model": "meshy-6", "should_texture": True,
            "enable_pbr": pbr, "target_formats": ["glb"], "topology": "triangle",
            "target_polycount": 30000}
    tid = _task_id(_req("POST", "/v1/image-to-3d", body))
    print("image-to-3d task", tid, flush=True)
    task = poll("/v1/image-to-3d/%s" % tid, name)
    return _save(task, name)


def gen_text(prompt, name, pbr=False):
    tid = _task_id(_req("POST", "/v2/text-to-3d",
                        {"mode": "preview", "prompt": prompt[:600], "ai_model": "meshy-6",
                         "target_formats": ["glb"]}))
    print("text-to-3d PREVIEW", tid, flush=True)
    poll("/v2/text-to-3d/%s" % tid, name + ":preview")
    rid = _task_id(_req("POST", "/v2/text-to-3d",
                        {"mode": "refine", "preview_task_id": tid, "enable_pbr": pbr}))
    print("text-to-3d REFINE", rid, flush=True)
    task = poll("/v2/text-to-3d/%s" % rid, name + ":refine")
    return _save(task, name)


def run_roster(path, only=None):
    spec = json.load(open(path))
    done, failed = [], []
    for item in spec["assets"]:
        nm = item.get("name")
        if not nm or nm.startswith("_"):
            continue
        if only and nm not in only:
            continue
        pbr = bool(item.get("pbr", True))
        print("=== %s (%s) ===" % (nm, item.get("group", "")), flush=True)
        try:
            if item.get("kind", "text") == "image":
                gen_image(item["image"], nm, pbr)
            else:
                gen_text(item["prompt"], nm, pbr)
            done.append(nm)
        except Exception as e:
            print("FAILED %s: %s" % (nm, e), flush=True)
            failed.append(nm)
    print("\nROSTER done=%s failed=%s" % (done, failed))


def main():
    if not KEY:
        sys.exit("MESHY_KEY not set. PowerShell: $env:MESHY_KEY=\"...\"  (needs a paid Meshy plan)")
    a = sys.argv
    if len(a) < 3:
        sys.exit(__doc__)
    kind = a[1]
    # parse flags
    name = "asset"; pbr = False; only = None; rest = []
    i = 2
    while i < len(a):
        if a[i] == "--name" and i + 1 < len(a):
            name = a[i + 1]; i += 2
        elif a[i] == "--only" and i + 1 < len(a):
            only = set(a[i + 1].split(",")); i += 2
        elif a[i] == "--pbr":
            pbr = True; i += 1
        else:
            rest.append(a[i]); i += 1
    if kind == "text":
        gen_text(" ".join(rest), name, pbr)
    elif kind == "image":
        gen_image(rest[0], name, pbr)
    elif kind == "roster":
        run_roster(rest[0], only)
    else:
        sys.exit("kind must be 'text', 'image', or 'roster'")


if __name__ == "__main__":
    main()
