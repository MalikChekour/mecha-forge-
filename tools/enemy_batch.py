#!/usr/bin/env python3
"""Lot « ennemis de base des 18 chapitres » : image -> Meshy image-to-3D -> rig -> walk/attack/die (reprenable).
  python tools/enemy_batch.py gen    # Meshy (credits !) : saute ce qui existe deja
  python tools/enemy_batch.py bake   # cuit les sprites 8 directions des ennemis dont les 3 animations sont la
Sortie : meshy_in/<name>/ ; game/assets/enemies/<name>_<anim>_<dir>.png (chassis = name)"""
import os, sys, json, time, subprocess
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
IMG = os.path.join(ROOT, "images_18_mechas")
LIST = [   # 20/10 : chapitres 10-18 (rendus fournis, anim Meshy walk/die conservees) PUIS 1-9 (images du pack_mechas_aujourdhui, recadrees dans images_18_mechas/sel)
 ("en10_abyss", "Ch10_Abyss_Nautilus01.png"), ("en11_ether", "Ch11_Ether_SporeStrider.png"), ("en12_titans", "Ch12_Titans_GoliathRelic.png"),
 ("en13_orbit", "Ch13_Orbit_AstroVecteur.png"), ("en14_quantum", "Ch14_Quantum_CipherByte.png"), ("en15_ozone", "Ch15_Ozone_VoltJumper.png"),
 ("en16_prism", "Ch16_Prism_SpectraMech.png"), ("en17_steampunk", "Ch17_Steampunk_SteamDread.png"), ("en18_colosseum", "Ch18_Colosseum_ColosseumGladiator.png"),
 ("en01_tech", "sel/Ch01.png"), ("en02_desert", "sel/Ch02.png"), ("en03_jungle", "sel/Ch03.png"), ("en04_volcanic", "sel/Ch04.png"), ("en05_swamp", "sel/Ch05.png"),
 ("en06_cryo", "sel/Ch06.png"), ("en07_reacteur", "sel/Ch07.png"), ("en08_ruche", "sel/Ch08.png"), ("en09_citadelle", "sel/Ch09.png"),
]
def gen():
    os.environ["MESHY_KEY"] = open(os.path.join(ROOT, ".meshy_key")).read().strip()
    import meshy_client as m
    m.KEY = os.environ["MESHY_KEY"]
    for name, img in LIST:
        d = os.path.join(ROOT, "meshy_in", name)
        try:
            if not os.path.exists(os.path.join(d, "model.glb")):
                m.gen_image(os.path.join(IMG, img), name, True)
            if not os.path.exists(os.path.join(d, "rig_task.json")):
                tid = json.load(open(os.path.join(d, "meta.json")))["id"]
                m.rig(tid, name, 2.2)
            rid = json.load(open(os.path.join(d, "rig_task.json")))["rig_task_id"]
            print("PRET", name, flush=True)
        except Exception as e:
            print("ECHEC", name, str(e)[:200], flush=True)
def bake():
    while True:
        todo = 0
        for name, _ in LIST:
            d = os.path.join(ROOT, "meshy_in", name)
            done = os.path.join(ROOT, "game", "assets", "enemies", name + "_die_back_left.png")
            if os.path.exists(done): continue
            if os.path.exists(os.path.join(d, "rigged.glb")):
                subprocess.run([sys.executable, os.path.join(ROOT, "tools", "bake_enemy_all.py"), name, name], cwd=ROOT)
                print("CUIT", name, flush=True); todo += 1
        pending = [n for n, _ in LIST if not os.path.exists(os.path.join(ROOT, "game", "assets", "enemies", n + "_die_back_left.png"))]
        if not pending: print("TOUT CUIT"); return
        if todo == 0: time.sleep(60)
if __name__ == "__main__":
    {"gen": gen, "bake": bake}[sys.argv[1]]()
