#!/usr/bin/env python3
"""
Ask several REAL different LLMs (free OpenRouter models + GLM) to each write a Python VFX script
that renders 6 weapon-effect GIFs. Extract code, run it in the model's folder, record success.
"""
import os, re, json, subprocess, httpx, time

ROOT = "C:/Users/Administrator/mecha-forge"
OUTBASE = f"{ROOT}/refs/models_vfx"
os.makedirs(OUTBASE, exist_ok=True)
OR_KEY = os.environ.get("OPENROUTER_API_KEY")
GLM_KEY = open(f"{ROOT}/.glm_key").read().strip()

MODELS = [
    ("qwen_coder",   "openrouter", "qwen/qwen3-coder:free"),
    ("llama_70b",    "openrouter", "meta-llama/llama-3.3-70b-instruct:free"),
    ("gpt_oss_20b",  "openrouter", "openai/gpt-oss-20b:free"),
    ("gemma_31b",    "openrouter", "google/gemma-4-31b-it:free"),
    ("nemotron_120b","openrouter", "nvidia/nemotron-3-super-120b-a12b:free"),
    ("hermes_405b",  "openrouter", "nousresearch/hermes-3-llama-3.1-405b:free"),
    ("glm",          "glm",        "glm-4.6"),
]

PROMPT = r"""Write a COMPLETE, self-contained Python 3 script (numpy, scipy.ndimage, PIL only — all installed) that generates 6 animated GIF weapon special-effects, isolated on a dark background (additive-glow game VFX look). Make them BEAUTIFUL and readable — your own visual style.

The 6 effects (save with EXACTLY these filenames, into the CURRENT working directory):
- e1_muzzle.gif   : a MUZZLE FLASH pointing to the RIGHT, short punchy burst that fades.
- e2_tracer.gif   : a fast BULLET/tracer travelling left->right with a glowing trail.
- e3_explosion.gif: an EXPLOSION expanding from center then fading (fireball / burst).
- e4_beam.gif     : a horizontal BEAM firing across the frame (brief charge then beam).
- e5_aoe.gif      : an AREA dome/ring expanding from center.
- e6_sabre.gif    : a melee ARC sweeping in a crescent around the center.

Rules:
- Each GIF: 160x160 px, ~20 frames, duration ~65ms, loop=0, disposal=2.
- Seed determinism: np.random.default_rng(42).
- Save into the CURRENT directory (os.getcwd()), do NOT use absolute paths.
- The script MUST run top to bottom without errors and produce all 6 gifs.

OUTPUT ONLY the Python code inside a single ```python ... ``` block. No explanation."""

def _content(j):
    msg = j["choices"][0]["message"]
    return msg.get("content") or msg.get("reasoning_content") or ""

def call_openrouter(model):
    for attempt in range(4):                       # free tier is rate-limited -> back off on 429
        r = httpx.post("https://openrouter.ai/api/v1/chat/completions",
            headers={"Authorization": f"Bearer {OR_KEY}"},
            json={"model": model, "messages": [{"role": "user", "content": PROMPT}], "max_tokens": 4000, "temperature": 0.7},
            timeout=180)
        if r.status_code == 429:
            print(f"    429, retry in 35s ({attempt+1}/4)"); time.sleep(35); continue
        r.raise_for_status()
        return _content(r.json())
    return ""

def call_glm(model):
    r = httpx.post("https://api.z.ai/api/coding/paas/v4/chat/completions",
        headers={"Authorization": f"Bearer {GLM_KEY}"},
        json={"model": model, "messages": [{"role": "user", "content": PROMPT}], "max_tokens": 6000, "temperature": 0.7},
        timeout=240)
    r.raise_for_status()
    return _content(r.json())

def extract_code(txt):
    if not isinstance(txt, str) or not txt.strip():
        return ""
    m = re.search(r"```(?:python)?\s*(.*?)```", txt, re.S)
    return (m.group(1) if m else txt).strip()

results = []
for short, kind, model in MODELS:
    d = os.path.join(OUTBASE, short); os.makedirs(d, exist_ok=True)
    print(f"\n== {short} ({model}) ==")
    try:
        txt = call_glm(model) if kind == "glm" else call_openrouter(model)
    except Exception as e:
        print("  API error:", str(e)[:150]); results.append({"id": short, "model": model, "ok": False, "count": 0, "err": "api"}); continue
    code = extract_code(txt)
    if len(code) < 100:
        print("  no code returned"); results.append({"id": short, "model": model, "ok": False, "count": 0, "err": "nocode"})
        time.sleep(12); continue
    open(os.path.join(d, "gen.py"), "w", encoding="utf-8").write(code)
    try:
        p = subprocess.run(["python", "gen.py"], cwd=d, capture_output=True, text=True, timeout=180)
        err = (p.stderr or "").strip().splitlines()[-1] if p.returncode else ""
    except subprocess.TimeoutExpired:
        err = "timeout"
    n = len([f for f in os.listdir(d) if f.endswith(".gif")])
    ok = n >= 5
    print(f"  gifs={n} {'OK' if ok else 'FAIL: '+err[:120]}")
    results.append({"id": short, "model": model, "ok": ok, "count": n, "err": err[:200]})
    time.sleep(12)                                  # space out to dodge free-tier rate limits

json.dump(results, open(os.path.join(OUTBASE, "_results.json"), "w"), ensure_ascii=False, indent=1)
print("\n=== BILAN ===")
for r in results:
    print(f"  {r['id']:14s} {r['count']}/6  {'✅' if r['ok'] else '❌ '+r.get('err','')[:60]}")
