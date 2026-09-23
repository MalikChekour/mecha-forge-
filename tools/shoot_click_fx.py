#!/usr/bin/env python3
"""Capture l'effet au clic (punch + onde de choc) sur JOUER, en plein milieu de l'animation."""
import os, sys, time, threading, functools
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from http.server import HTTPServer, SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright
WEB=r"C:\Users\Administrator\mecha-forge\web"; PORT=8994
CHROME=r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
OUT=sys.argv[1]; os.makedirs(OUT, exist_ok=True)
class H(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy","same-origin")
        self.send_header("Cross-Origin-Embedder-Policy","require-corp")
        self.send_header("Cross-Origin-Resource-Policy","cross-origin"); super().end_headers()
    def log_message(self,*a): pass
threading.Thread(target=lambda: HTTPServer(("127.0.0.1",PORT),
    functools.partial(H,directory=WEB)).serve_forever(), daemon=True).start()
time.sleep(1)
with sync_playwright() as p:
    b=p.chromium.launch(executable_path=CHROME, headless=True, args=[
        "--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader",
        "--no-sandbox","--disable-setuid-sandbox"])
    pg=b.new_page(viewport={"width":1280,"height":720})
    pg.goto("http://127.0.0.1:%d/index.html"%PORT, wait_until="networkidle"); time.sleep(9)
    pg.mouse.click(1195,45); time.sleep(3.0)            # PASSER l'intro
    pg.screenshot(path=os.path.join(OUT,"fx_0_repos.png"))
    # centre reel du bouton JOUER : x=640, y~456
    # rafale : en rendu logiciel une capture prend ~0.3s, donc on mitraille pour
    # tomber dans la fenetre de 0.4s de l'onde de choc.
    pg.mouse.move(640,456); pg.mouse.down()
    for i in range(6):
        pg.screenshot(path=os.path.join(OUT,"fx_burst_%d.png"%i)); print("   burst",i,flush=True)
    b.close()   # on ne relache pas : evite de lancer la partie
print("DONE")
