import trimesh, numpy as np
from pathlib import Path

def analyze(path):
    scene = trimesh.load(path, force="scene")
    meshes = []
    if isinstance(scene, trimesh.Scene):
        for g in scene.geometry.values():
            if hasattr(g, "vertices"):
                meshes.append(g)
    else:
        meshes = [scene]
    if not meshes:
        return {"err": "no mesh"}
    m = trimesh.util.concatenate(meshes) if len(meshes) > 1 else meshes[0]
    v = np.asarray(m.vertices)
    mins, maxs = v.min(0), v.max(0)
    size = maxs - mins
    axis = int(np.argmax(size))
    h0, h1 = mins[axis], maxs[axis]
    y = h0 + 0.35 * (h1 - h0)
    band = np.abs(v[:, axis] - y) < 0.03 * (h1 - h0)
    pts = v[band]
    axes = [0, 1, 2]
    axes.remove(axis)
    lr = axes[0] if (pts[:, axes[0]].ptp() >= pts[:, axes[1]].ptp()) else axes[1]
    xs = pts[:, lr]
    hist, _ = np.histogram(xs, bins=40)
    mid = len(hist) // 2
    gap = int(np.sum(hist[mid - 3 : mid + 3] == 0))
    return {
        "faces": int(len(m.faces)),
        "mid_empty": gap,
        "hist_mid": hist[mid - 5 : mid + 5].tolist(),
        "LR": [int(hist[:mid].sum()), int(hist[mid:].sum())],
    }

root = Path(r"C:\Users\Administrator\mecha-forge\meshy_in")
names = [
    "en01_tech",
    "en01_tech_swarm",
    "en01_tech_shield",
    "en01_tech_sniper",
    "en02_desert_swarm",
    "en02_desert_shield",
    "en02_desert_sniper",
    "en03_jungle_swarm",
    "en03_jungle_shield",
    "en03_jungle_sniper",
]
for n in names:
    for kind in ["model.glb", "rigged.glb"]:
        p = root / n / kind
        if not p.exists():
            continue
        try:
            r = analyze(str(p))
            print(f"{n}/{kind}: faces={r['faces']} mid_empty={r['mid_empty']} hist={r['hist_mid']} LR={r['LR']}")
        except Exception as e:
            print(f"{n}/{kind}: ERR {e}")
