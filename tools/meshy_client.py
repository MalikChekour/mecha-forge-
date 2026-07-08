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


def refine_with_retry(preview_id, name, pbr=True, tries=3):
    """Meshy refine (texturing) times out server-side fairly often. Retry, and
    after repeated timeouts drop PBR (lighter → far more likely to succeed).
    Base color alone still bakes into great sprites at 2D scale."""
    use_pbr = pbr
    last = None
    for attempt in range(tries):
        rid = _task_id(_req("POST", "/v2/text-to-3d",
                            {"mode": "refine", "preview_task_id": preview_id, "enable_pbr": use_pbr}))
        print("REFINE %s (pbr=%s, try %d) %s" % (name, use_pbr, attempt + 1, rid), flush=True)
        try:
            return poll("/v2/text-to-3d/%s" % rid, name + ":refine")
        except RuntimeError as e:
            last = e
            print("  refine failed: %s" % e, flush=True)
            if "timeout" in str(e).lower() and attempt < tries - 1:
                if attempt >= 1:
                    use_pbr = False   # give up on PBR maps, keep base color
                continue
            raise
    raise RuntimeError("refine exhausted: %s" % last)


def gen_text(prompt, name, pbr=False):
    tid = _task_id(_req("POST", "/v2/text-to-3d",
                        {"mode": "preview", "prompt": prompt[:600], "ai_model": "meshy-6",
                         "target_formats": ["glb"]}))
    print("text-to-3d PREVIEW", tid, flush=True)
    poll("/v2/text-to-3d/%s" % tid, name + ":preview")
    task = refine_with_retry(tid, name, pbr)
    return _save(task, name)


# ---- rigging + animation (humanoid/biped models only, per Meshy docs) ----
# Useful action_ids (catalog 0-696): idle 0, walk 106 (Confident_Walk) / 30 (Casual_Walk),
# run 16, attack 4, hit 178, die 8.
ANIM_IDS = {"idle": 0, "walk": 106, "attack": 4, "hit": 178, "die": 8}


def rig(model_task_id, name, height=1.8):
    tid = _task_id(_req("POST", "/v1/rigging",
                        {"input_task_id": model_task_id, "height_meters": height}))
    print("RIG %s task %s" % (name, tid), flush=True)
    task = poll("/v1/rigging/%s" % tid, name + ":rig")
    outdir = os.path.join(INDIR, name); os.makedirs(outdir, exist_ok=True)
    download(task.get("rigged_character_glb_url"), os.path.join(outdir, "rigged.glb"))
    with open(os.path.join(outdir, "rig_task.json"), "w") as f:
        json.dump({"rig_task_id": task.get("id")}, f)
    print("RIGGED %s rig_task_id=%s" % (name, task.get("id")), flush=True)
    return task.get("id")


def animate(rig_task_id, action, name, label=None):
    action_id = ANIM_IDS.get(action, action) if isinstance(action, str) else action
    label = label or (action if isinstance(action, str) else "act%s" % action)
    tid = _task_id(_req("POST", "/v1/animations",
                        {"rig_task_id": rig_task_id, "action_id": int(action_id)}))
    print("ANIM %s/%s (action %s) task %s" % (name, label, action_id, tid), flush=True)
    task = poll("/v1/animations/%s" % tid, "%s:%s" % (name, label))
    outdir = os.path.join(INDIR, name); os.makedirs(outdir, exist_ok=True)
    p = os.path.join(outdir, "anim_%s.glb" % label)
    download(task.get("animation_glb_url"), p)
    print("ANIMATED %s/%s -> %s" % (name, label, p), flush=True)
    return p


def process_anims(name, model_task_id, labels, height=1.8):
    rid = rig(model_task_id, name, height)
    for lab in labels:
        try:
            animate(rid, lab, name, lab)
        except Exception as e:
            print("  anim %s failed: %s" % (lab, e), flush=True)
    return rid


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
    elif kind == "refine":
        # retry texturing from an existing preview task id (no re-preview cost)
        task = refine_with_retry(rest[0], name, pbr)
        _save(task, name)
    elif kind == "rig":
        rig(rest[0], name)
    elif kind == "animate":
        # animate <rig_task_id> <action(name or id)> --name X --label walk
        lab = None
        if "--label" in a:
            lab = a[a.index("--label") + 1]
        animate(rest[0], rest[1], name, lab)
    elif kind == "riganim":
        # riganim <model_task_id> --name X [--label walk,attack,die]
        labels = ["walk"]
        if "--label" in a:
            labels = a[a.index("--label") + 1].split(",")
        process_anims(name, rest[0], labels)
    else:
        sys.exit("kind must be 'text', 'image', 'roster', 'refine', 'rig', 'animate', or 'riganim'")


if __name__ == "__main__":
    main()
