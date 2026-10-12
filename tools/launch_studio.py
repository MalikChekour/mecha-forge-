#!/usr/bin/env python3
"""
MECHA-FORGE - Visual Scale Studio Server
Serves the web studio on http://127.0.0.1:8890/studio/ and handles visual_scales.json save API.
"""

import http.server
import socketserver
import os
import sys
import json
import webbrowser

PORT = 8890
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME_SCALES_PATH = os.path.join(ROOT_DIR, "game", "visual_scales.json")

class StudioHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        if self.path == "/api/load_scales":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            if os.path.exists(GAME_SCALES_PATH):
                with open(GAME_SCALES_PATH, "rb") as f:
                    self.wfile.write(f.read())
            else:
                default_data = {
                    "decor_global": 1.0,
                    "vfx_global": 1.0,
                    "decor_categories": {},
                    "vfx_categories": {},
                    "decor_custom": {},
                    "vfx_custom": {}
                }
                self.wfile.write(json.dumps(default_data).encode("utf-8"))
            return

        # Redirect root to studio/
        if self.path == "/" or self.path == "":
            self.send_response(302)
            self.send_header("Location", "/studio/")
            self.end_headers()
            return

        super().do_GET()

    def do_POST(self):
        if self.path == "/api/save_scales":
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length)
                data = json.loads(body.decode("utf-8"))
                
                # Write to game/visual_scales.json
                with open(GAME_SCALES_PATH, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
                
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"status":"ok","message":"Saved to game/visual_scales.json"}')
                print("[Studio API] visual_scales.json successfully saved!", flush=True)
                return
            except Exception as e:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode("utf-8"))
                return

        self.send_response(404)
        self.end_headers()

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

def main():
    target_url = f"http://127.0.0.1:{PORT}/studio/"
    print(f"==================================================", flush=True)
    print(f"  MECHA-FORGE — Studio d'Étalonnage Décor & VFX", flush=True)
    print(f"  Serveur Web actif sur {target_url}", flush=True)
    print(f"==================================================", flush=True)

    no_open = "--no-browser" in sys.argv
    if not no_open:
        try:
            webbrowser.open(target_url)
        except Exception:
            pass

    try:
        with ThreadedHTTPServer(("127.0.0.1", PORT), StudioHandler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nArrêt du serveur Studio.", flush=True)

if __name__ == "__main__":
    main()
