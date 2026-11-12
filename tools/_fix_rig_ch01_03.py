# -*- coding: utf-8 -*-
"""Force remesh -> re-rig -> re-anim (Confident_Walk=106) for Ch01-03 roles.
Fixes stuck-legs / bad skin weights from prior rig-without-remesh.
"""
import os, sys, json, time, shutil, traceback

ROOT = r"C:\Users\Administrator\mecha-forge"
sys.path.insert(0, os.path.join(ROOT, "tools"))

# Load key before importing / configuring meshy_client
import sys as _sys, os as _os; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__))); from keys import get_key
KEY = get_key("meshy")
os.environ["MESHY_KEY"] = KEY
os.environ["MESHY_API_KEY"] = KEY

import meshy_client as mc
mc.KEY = KEY

NAMES = [
    "en01_tech_swarm", "en01_tech_shield", "en01_tech_sniper",
    "en02_desert_swarm", "en02_desert_shield", "en02_desert_sniper",
    "en03_jungle_swarm", "en03_jungle_shield", "en03_jungle_sniper",
]

INDIR = os.path.join(ROOT, "meshy_in")
LOGP = os.path.join(INDIR, "_fix_rig_ch01_03.log")
RESP = os.path.join(INDIR, "_fix_rig_ch01_03.json")

# walk=106 Confident_Walk (not ANIM_IDS["walk"]=30 Casual_Walk)
WALK_ID = 106
ATTACK_ID = 4
DIE_ID = 8


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(LOGP, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def archive_prev(name):
    d = os.path.join(INDIR, name)
    prev = os.path.join(d, "_prev")
    os.makedirs(prev, exist_ok=True)
    for fn in ("anim_walk.glb", "anim_attack.glb", "anim_die.glb", "rigged.glb"):
        src = os.path.join(d, fn)
        dst = os.path.join(prev, fn)
        if os.path.exists(src) and not os.path.exists(dst):
            shutil.copy2(src, dst)
            log("  archived %s -> _prev/" % fn)


def save_results(results, t0):
    summary = {
        "ok": sum(1 for r in results if r.get("ok")),
        "fail": sum(1 for r in results if not r.get("ok")),
        "elapsed_s": round(time.time() - t0, 1),
        "items": results,
    }
    with open(RESP, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
    return summary


def process_one(name):
    meta_p = os.path.join(INDIR, name, "meta.json")
    if not os.path.exists(meta_p):
        raise RuntimeError("missing meta.json")
    meta = json.load(open(meta_p, encoding="utf-8"))
    model_id = meta.get("id")
    if not model_id:
        raise RuntimeError("meta.json has no id")

    archive_prev(name)

    entry = {"name": name, "model_id": model_id, "steps": {}}
    t0 = time.time()

    log("REMESH %s (input=%s)" % (name, model_id))
    mid = mc.remesh(model_id, name)
    entry["steps"]["remesh"] = mid
    log("  remesh ok -> %s" % mid)

    log("RIG %s (from remesh %s)" % (name, mid))
    rid = mc.rig(mid, name, height=1.8)
    entry["steps"]["rig"] = rid
    log("  rig ok -> %s" % rid)

    for action_id, label in ((WALK_ID, "walk"), (ATTACK_ID, "attack"), (DIE_ID, "die")):
        log("ANIM %s/%s action_id=%s" % (name, label, action_id))
        path = mc.animate(rid, action_id, name, label)
        entry["steps"][label] = path
        exists = os.path.exists(path) if path else False
        mtime = os.path.getmtime(path) if exists else None
        log("  anim %s ok exists=%s mtime=%s" % (label, exists, mtime))

    entry["ok"] = True
    entry["secs"] = round(time.time() - t0, 1)
    return entry


def main():
    open(LOGP, "w", encoding="utf-8").write(
        "START %s KEY_LEN=%d\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), len(KEY))
    )
    log("KEY loaded len=%d" % len(KEY))
    results = []
    t_all = time.time()

    for i, name in enumerate(NAMES, 1):
        log("==== [%d/%d] %s ====" % (i, len(NAMES), name))
        try:
            entry = process_one(name)
            results.append(entry)
            log("OK %s in %.0fs" % (name, entry["secs"]))
        except Exception as e:
            tb = traceback.format_exc()
            log("FAIL %s: %s" % (name, e))
            log(tb)
            results.append({
                "name": name, "ok": False, "err": str(e),
                "secs": 0,
            })
            # stop early on credit / auth errors
            es = str(e).lower()
            if any(x in es for x in ("402", "credit", "quota", "401", "unauthorized", "payment")):
                log("STOP early: likely credits/auth error")
                save_results(results, t_all)
                break
        save_results(results, t_all)

    summary = save_results(results, t_all)
    log("DONE ok=%d fail=%d elapsed=%.0fs" % (
        summary["ok"], summary["fail"], summary["elapsed_s"]))
    print(json.dumps(summary, indent=2), flush=True)
    return 0 if summary["fail"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
