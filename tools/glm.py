#!/usr/bin/env python3
"""
Minimal z.ai GLM client (OpenAI-compatible coding endpoint). Offloads heavy
generation from Claude; Claude supervises + validates headless. Key in .glm_key.

  python glm.py --prompt promptfile [--system sysfile] [--out out.gd] [--code]
                [--model glm-4.6] [--maxtok 8000]
--code extracts the first fenced code block from the reply (drops prose).
"""
import sys, os, json, re, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
import sys as _sys, os as _os; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__))); from keys import get_key
KEY = get_key("glm")
Z_URL = "https://api.z.ai/api/coding/paas/v4/chat/completions"
OR_URL = "https://openrouter.ai/api/v1/chat/completions"


# Model id routes the provider: "a/b" -> OpenRouter (paid, reliable), else z.ai GLM.
# Council: glm-5.2 / glm-4.6 (z.ai) | qwen/qwen3-coder, google/gemini-2.5-flash,
# deepseek/deepseek-chat-v3-0324 (OpenRouter).
def glm(prompt, system=None, model="glm-5.2", max_tokens=8000, temperature=0.35):
    is_or = "/" in model
    url = OR_URL if is_or else Z_URL
    key = os.environ.get("OPENROUTER_API_KEY", "") if is_or else KEY
    msgs = []
    if system:
        msgs.append({"role": "system", "content": system})
    msgs.append({"role": "user", "content": prompt})
    body = {"model": model, "messages": msgs, "max_tokens": max_tokens, "temperature": temperature}
    if (not is_or) and model.startswith("glm-5"):
        body["thinking"] = {"type": "disabled"}   # thinking model: answer straight into content
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
                                 method="POST")
    with urllib.request.urlopen(req, timeout=600) as r:
        d = json.loads(r.read().decode())
    msg = d["choices"][0]["message"]
    return msg.get("content") or msg.get("reasoning_content") or ""


def extract_code(text):
    m = re.search(r"```(?:[a-zA-Z0-9]*)\n(.*?)```", text, re.DOTALL)
    return m.group(1).rstrip() + "\n" if m else text


def _read(flag):
    a = sys.argv
    return open(a[a.index(flag) + 1], encoding="utf-8").read() if flag in a else None


def main():
    a = sys.argv
    prompt = _read("--prompt") or (a[1] if len(a) > 1 and not a[1].startswith("--") else "")
    system = _read("--system")
    model = a[a.index("--model") + 1] if "--model" in a else "glm-4.6"
    maxtok = int(a[a.index("--maxtok") + 1]) if "--maxtok" in a else 8000
    resp = glm(prompt, system, model, maxtok)
    if "--code" in a:
        resp = extract_code(resp)
    out = a[a.index("--out") + 1] if "--out" in a else None
    if out:
        open(out, "w", encoding="utf-8").write(resp)
        print("wrote", out, len(resp), "chars")
    else:
        print(resp)


if __name__ == "__main__":
    main()
