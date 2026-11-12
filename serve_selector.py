import os
import sys
import json
import shutil
import subprocess
from http.server import HTTPServer, SimpleHTTPRequestHandler

PORT = 8089
ROOT_DIR = r"C:\Users\Administrator\mecha-forge"
ASSETS_DIR = os.path.join(ROOT_DIR, "selector_assets")

MECHAS_MAP = {
    'ch02_v2': 'ch02_gundam_desert_v2_1792504770410.jpg',
    'ch03_v2': 'ch03_gundam_jungle_v2_1792504713155.jpg',
    'ch05_v2': 'ch05_gundam_swamp_v2_1792504737086.jpg',
    'ch07_v2': 'ch07_gundam_reacteur_v2_1792504808484.jpg',
    'ch01_v1': 'ch01_gundam_mecha_1792503626618.jpg',
    'ch02_v1': 'ch02_gundam_desert_1792503752210.jpg',
    'ch03_v1': 'ch03_gundam_jungle_1792503785319.jpg',
    'ch04_v1': 'ch04_gundam_volcanic_1792503824716.jpg',
    'ch05_v1': 'ch05_gundam_swamp_1792503857868.jpg',
    'ch06_v1': 'ch06_gundam_cryo_1792503890181.jpg',
    'ch07_v1': 'ch07_gundam_reacteur_1792503927457.jpg',
    'ch08_v1': 'ch08_gundam_ruche_1792503962696.jpg',
    'ch09_v1': 'ch09_gundam_citadelle_1792503998405.jpg',
    'ch10': 'abyss_walker_mecha_1792436404452.jpg',
    'ch11': 'ether_walker_mecha_1792436439299.jpg',
    'ch12': 'titans_walker_mecha_1792436476294.jpg',
    'ch13': 'orbit_walker_mecha_1792436506588.jpg',
    'ch14': 'quantum_walker_mecha_1792436546606.jpg',
    'ch15': 'ozone_walker_mecha_1792436577107.jpg',
    'ch16': 'prism_walker_mecha_1792436607198.jpg',
    'ch17': 'steampunk_walker_mecha_1792436648178.jpg',
    'ch18': 'colosseum_walker_mecha_1792436834734.jpg',
}

class SelectorHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/" or self.path == "":
            self.path = "/mecha_selector.html"
        return super().do_GET()

    def do_POST(self):
        if self.path == "/api/save":
            try:
                length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(length).decode("utf-8")
                data = json.loads(body)
                
                selected_ids = data.get("selected", [])
                folder_name = data.get("folderName", "ma_selection_mechas")
                dest_dir = os.path.join(ROOT_DIR, folder_name)
                os.makedirs(dest_dir, exist_ok=True)
                
                saved_files = []
                for mid in selected_ids:
                    fname = MECHAS_MAP.get(mid)
                    if not fname:
                        # try direct filename
                        if mid in MECHAS_MAP.values():
                            fname = mid
                    if fname:
                        src = os.path.join(ASSETS_DIR, fname)
                        if os.path.exists(src):
                            dst = os.path.join(dest_dir, fname)
                            shutil.copy2(src, dst)
                            saved_files.append(fname)

                # Open explorer to the saved folder
                try:
                    subprocess.Popen(["explorer", dest_dir])
                except Exception:
                    pass

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                resp = {
                    "status": "success",
                    "destination": dest_dir,
                    "count": len(saved_files),
                    "files": saved_files
                }
                self.wfile.write(json.dumps(resp).encode("utf-8"))
                return
            except Exception as e:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode("utf-8"))
                return

        return super().do_POST()

if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", PORT), SelectorHandler)
    print(f"Serveur Sélecteur démarré sur http://localhost:{PORT}")
    server.serve_forever()
