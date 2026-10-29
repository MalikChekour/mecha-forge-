# -*- coding: utf-8 -*-
import os, sys, re, time, json
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass
ROOT = r"C:\Users\Administrator\mecha-forge"
sys.path.insert(0, r"C:\Users\Administrator\workspace\pod")
from flux_gen import flux
MD = os.path.join(ROOT, "docs", "MESHY_ENEMY_ROLE_PROMPTS.md")
OUT = os.path.join(ROOT, "refs", "enemies_role_concepts")
os.makedirs(OUT, exist_ok=True)
TECH = (
" Full body head to toe single character centered. Strict symmetrical A-pose arms away from torso at 40 degrees, "
"elbows slightly bent hands open separated from hips legs shoulder-width feet flat. Orthographic front view. "
"Flat even studio lighting plain flat neutral grey background #808080 no ground no cast shadow. "
"No text no logo no watermark. No thin antennas cables wires cape. Clean humanoid biped two legs two arms one head."
)
text = open(MD, encoding="utf-8", errors="replace").read()
blocks = []
for m in re.finditer(r"###[^\n]*`(en\d+_[a-z0-9_]+)`", text):
    name = m.group(1)
    rest = text[m.end():]
    fm = re.search(r"```\s*\n(.*?)\n```", rest, re.S)
    if not fm:
        continue
    body = re.sub(r"\n\+\s*\[TECHNICAL REQUIREMENTS\]\s*$", "", fm.group(1).strip())
    blocks.append((name, body))
print("parsed", len(blocks), flush=True)
json.dump([{"name": n, "prompt": b} for n, b in blocks], open(os.path.join(OUT, "_prompts.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
limit = int(os.environ.get("CONCEPT_LIMIT", "0") or "0")
todo = blocks if limit <= 0 else blocks[:limit]
ok = sk = fail = 0
log_path = os.path.join(OUT, "_batch_log.jsonl")
for i, (name, body) in enumerate(todo, 1):
    dst = os.path.join(OUT, name + ".png")
    if os.path.exists(dst) and os.path.getsize(dst) > 5000:
        print("[%d/%d] SKIP %s" % (i, len(todo), name), flush=True)
        sk += 1
        continue
    prompt = (body.replace("\n", " ") + " " + TECH)[:1800]
    print("[%d/%d] GEN %s" % (i, len(todo), name), flush=True)
    t0 = time.time()
    success = False
    for attempt in range(3):
        try:
            success = bool(flux(prompt, dst, steps=8))
        except Exception as e:
            print("  exc", e, flush=True)
            success = False
        if success and os.path.exists(dst) and os.path.getsize(dst) > 2000:
            break
        time.sleep(1 + attempt)
    nbytes = os.path.getsize(dst) if os.path.exists(dst) else 0
    rec = {"name": name, "ok": success, "sec": round(time.time() - t0, 1), "bytes": nbytes, "backend": "cf-flux-schnell"}
    open(log_path, "a", encoding="utf-8").write(json.dumps(rec) + "\n")
    if success:
        ok += 1
        print("  OK", nbytes, "B", rec["sec"], "s", flush=True)
    else:
        fail += 1
        print("  FAIL", name, flush=True)
    time.sleep(0.3)
summary = {"ok": ok, "skip": sk, "fail": fail, "total": len(todo), "parsed": len(blocks), "backend": "cf-flux-schnell"}
json.dump(summary, open(os.path.join(OUT, "_summary.json"), "w", encoding="utf-8"), indent=2)
print("DONE", summary, flush=True)
