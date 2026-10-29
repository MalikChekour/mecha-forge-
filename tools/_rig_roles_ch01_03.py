"""One-shot: Meshy RIG + ANIM (walk/attack/die) for Ch01-03 role chassis."""
import json, os, sys, traceback
from pathlib import Path

ROOT = Path(r"C:\Users\Administrator\mecha-forge")
sys.path.insert(0, str(ROOT / "tools"))

key_path = ROOT / ".meshy_key"
key = key_path.read_text(encoding="utf-8").strip()
if not key:
    sys.exit("empty .meshy_key")
os.environ["MESHY_KEY"] = key

import meshy_client as mc  # noqa: E402
# reload KEY inside module
mc.KEY = key

NAMES = [
    "en01_tech_swarm", "en01_tech_shield", "en01_tech_sniper",
    "en02_desert_swarm", "en02_desert_shield", "en02_desert_sniper",
    "en03_jungle_swarm", "en03_jungle_shield", "en03_jungle_sniper",
]
LABELS = ["walk", "attack", "die"]
OUT = ROOT / "meshy_in" / "_rig_roles_ch01_03.json"


def complete(name: str) -> bool:
    d = ROOT / "meshy_in" / name
    need = ["rigged.glb", "anim_walk.glb", "anim_attack.glb", "anim_die.glb"]
    return all((d / f).exists() and (d / f).stat().st_size > 0 for f in need)


def files_status(name: str) -> dict:
    d = ROOT / "meshy_in" / name
    out = {}
    for f in ["rigged.glb", "anim_walk.glb", "anim_attack.glb", "anim_die.glb"]:
        p = d / f
        out[f] = str(p) if p.exists() and p.stat().st_size > 0 else None
    return out


def looks_polycount(err: str) -> bool:
    e = (err or "").lower()
    return any(x in e for x in ("poly", "triangle", "vertex", "too many", "remesh", "face"))


results = []
for name in NAMES:
    entry = {"name": name, "status": None, "error": None, "files": None, "remesh_retry": False}
    try:
        meta_p = ROOT / "meshy_in" / name / "meta.json"
        if not meta_p.exists():
            entry["status"] = "fail"
            entry["error"] = "missing meta.json"
            results.append(entry)
            continue
        meta = json.loads(meta_p.read_text(encoding="utf-8"))
        mid = meta.get("id")
        entry["model_task_id"] = mid
        if not mid:
            entry["status"] = "fail"
            entry["error"] = "meta.json missing id"
            results.append(entry)
            continue
        if complete(name):
            entry["status"] = "skip"
            entry["files"] = files_status(name)
            print(f"SKIP {name} already complete", flush=True)
            results.append(entry)
            continue
        print(f"=== RIGANIM {name} mid={mid} ===", flush=True)
        try:
            mc.process_anims(name, mid, LABELS, height=1.8, do_remesh=False)
        except Exception as e1:
            msg = str(e1)
            print(f"FAIL first pass {name}: {msg}", flush=True)
            if looks_polycount(msg):
                entry["remesh_retry"] = True
                print(f"RETRY remesh {name}", flush=True)
                mc.process_anims(name, mid, LABELS, height=1.8, do_remesh=True)
            else:
                raise
        st = files_status(name)
        entry["files"] = st
        if st["rigged.glb"] and st["anim_walk.glb"] and st["anim_attack.glb"] and st["anim_die.glb"]:
            entry["status"] = "ok"
        else:
            entry["status"] = "partial"
            missing = [k for k, v in st.items() if not v]
            entry["error"] = "missing: " + ",".join(missing)
        print(f"DONE {name} status={entry['status']}", flush=True)
    except Exception as e:
        entry["status"] = "fail"
        entry["error"] = str(e)
        entry["traceback"] = traceback.format_exc()[-800:]
        entry["files"] = files_status(name)
        print(f"FAILED {name}: {e}", flush=True)
    results.append(entry)
    OUT.write_text(json.dumps({"results": results}, indent=2), encoding="utf-8")

ok = sum(1 for r in results if r["status"] in ("ok", "skip"))
fail = sum(1 for r in results if r["status"] == "fail")
partial = sum(1 for r in results if r["status"] == "partial")
summary = {
    "results": results,
    "summary": {"ok_or_skip": ok, "partial": partial, "fail": fail, "total": len(results)},
}
OUT.write_text(json.dumps(summary, indent=2), encoding="utf-8")
print("SUMMARY", summary["summary"], flush=True)
print("WROTE", OUT, flush=True)
