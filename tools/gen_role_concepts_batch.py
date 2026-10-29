# -*- coding: utf-8 -*-
"""Batch: 54 enemy role concepts via Cloudflare FLUX from MESHY_ENEMY_ROLE_PROMPTS.md"""
import os, sys, re, time, json
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = r"C:\Users\Administrator\mecha-forge"
MD = os.path.join(ROOT, "docs", "MESHY_ENEMY_ROLE_PROMPTS.md")
OUT = os.path.join(ROOT, "refs", "enemies_role_concepts")
LOG = os.path.join(OUT, "_batch_log.jsonl")
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, r"C:\Users\Administrator\workspace\pod")
from flux_gen import flux

TECH = (
" TECHNICAL REQUIREMENTS (this image will be converted to a rigged 3D model - accuracy is critical): "
"Full body, head to toe, nothing cropped or cut off. Single character, centered. "
"Strict symmetrical A-POSE: both arms held clearly AWAY from the torso at ~40 degrees, elbows "
"slightly bent, hands open and separated from the hips, legs straight and shoulder-width apart, "
"feet flat and apart. NO limb touching the body, NO limb touching another limb, NO overlapping parts. "
"Orthographic front view, camera at chest height, zero perspective distortion. "
"Flat even studio lighting, no harsh shadows, no rim light, no lens flare, no glow bloom. "
"Plain flat neutral grey background (#808080), no ground plane, no cast shadow, no floor. "
"Sharp focus, no motion blur, no depth of field. No text, no logo, no watermark, no UI. "
"NO thin antennas, NO cables, NO wires, NO cape, NO chains, NO flags - every part must be thicker "
"than a finger and solidly attached. Clean readable humanoid biped silhouette: two legs, two arms, one head."
)

text = open(MD, encoding="utf-8", errors="replace").read()
# Match ### ROLE ... `chassis` then fenced prompt
pat = re.compile(
    r"###\s+[^\n`]*`([a-z0-9_]+)`\s*\n+```\s*\n(.*?)(?:\n\+ \[TECHNICAL REQUIREMENTS\])?\s*\n```",
    re.S | re.I,
)
items = [(m.group(1), m.group(2).strip()) for m in pat.finditer(text)]
print("parsed", len(items), "prompts", flush=True)
if len(items) < 50:
    print("WARN expected 54", flush=True)

ok_n = skip_n = fail_n = 0
for i, (name, body) in enumerate(items, 1):
    dst = os.path.join(OUT, name + ".png")
    if os.path.exists(dst) and os.path.getsize(dst) > 5000:
        print("[%d/%d] SKIP %s" % (i, len(items), name), flush=True)
        skip_n += 1
        continue
    prompt = body.replace("\n", " ") + TECH
    # CF FLUX prompt length soft limit — keep under ~2000 chars
    if len(prompt) > 1900:
        prompt = prompt[:1900]
    print("[%d/%d] GEN %s (%d chars)" % (i, len(items), name, len(prompt)), flush=True)
    t0 = time.time()
    success = False
    for attempt in range(3):
        try:
            success = bool(flux(prompt, dst, steps=8, seed=1000 + i))
        except Exception as e:
            print("  exc", e, flush=True)
            success = False
        if success and os.path.exists(dst) and os.path.getsize(dst) > 2000:
            break
        time.sleep(2 + attempt * 2)
    rec = {"name": name, "ok": success, "sec": round(time.time() - t0, 1), "bytes": os.path.getsize(dst) if os.path.exists(dst) else 0}
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec) + "\n")
    if success:
        ok_n += 1
        print("  OK", rec["bytes"], "B in", rec["sec"], "s", flush=True)
    else:
        fail_n += 1
        print("  FAIL", name, flush=True)
    time.sleep(0.4)

summary = {"ok": ok_n, "skip": skip_n, "fail": fail_n, "total": len(items), "out": OUT}
open(os.path.join(OUT, "_summary.json"), "w", encoding="utf-8").write(json.dumps(summary, indent=2))
print("DONE", summary, flush=True)
