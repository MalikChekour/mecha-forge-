#!/usr/bin/env python3
"""
Probe / use z.ai (Zhipu) CogVideoX video generation.

Reads ~/.zai_key (utf-8-sig, no BOM), submits a text->video job, polls the async
result, downloads the mp4. Prints clear diagnostics so we can tell whether the
account actually has VIDEO access (vs only the GLM Coding chat plan).

Usage:  python tools/zai_video.py "<prompt>" out.mp4 [model]
"""
import os, sys, json, time, urllib.request, urllib.error

KEY_PATH = os.path.join(os.path.expanduser("~"), ".zai_key")
BASE = "https://api.z.ai/api/paas/v4"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) mecha-forge/1.0"


def key():
    with open(KEY_PATH, "r", encoding="utf-8-sig") as f:
        return f.read().strip()


def _req(url, data=None, method=None):
    hdr = {"Authorization": "Bearer " + key(), "User-Agent": UA,
           "Accept": "application/json"}
    if data is not None:
        hdr["Content-Type"] = "application/json"
        data = json.dumps(data).encode()
    r = urllib.request.Request(url, data=data, headers=hdr, method=method)
    try:
        with urllib.request.urlopen(r, timeout=90) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            return e.code, json.loads(body)
        except Exception:
            return e.code, {"raw": body[:400]}
    except Exception as e:
        return -1, {"exc": str(e)[:300]}


def generate(prompt, out, model="cogvideox-2", size="1920x1080", duration=5,
             with_audio=True, quality="quality"):
    body = {"model": model, "prompt": prompt, "size": size,
            "duration": duration, "with_audio": with_audio, "quality": quality,
            "fps": 30}
    st, d = _req(BASE + "/videos/generations", data=body)
    print("SUBMIT [%s] http=%s -> %s" % (model, st, json.dumps(d)[:300]))
    task = d.get("id")
    if st not in (200, 201) or not task:
        return False
    # poll
    for i in range(60):
        time.sleep(6)
        st, d = _req(BASE + "/async-result/" + task)
        status = d.get("task_status") or d.get("status")
        print("  poll %2d  http=%s  status=%s" % (i, st, status))
        if status == "SUCCESS":
            vids = d.get("video_result") or []
            if vids and vids[0].get("url"):
                url = vids[0]["url"]
                print("  URL", url[:90])
                req = urllib.request.Request(url, headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=180) as r:
                    open(out, "wb").write(r.read())
                print("SAVED", out, os.path.getsize(out) // 1024, "Ko")
                return True
            print("  SUCCESS but no url:", json.dumps(d)[:300])
            return False
        if status in ("FAIL", "FAILED", "ERROR"):
            print("  FAILED:", json.dumps(d)[:300])
            return False
    print("  timeout waiting for result")
    return False


if __name__ == "__main__":
    p = sys.argv[1] if len(sys.argv) > 1 else "test"
    out = sys.argv[2] if len(sys.argv) > 2 else "cine/zai_test.mp4"
    model = sys.argv[3] if len(sys.argv) > 3 else "cogvideox-2"
    ok = generate(p, out, model=model)
    sys.exit(0 if ok else 1)
