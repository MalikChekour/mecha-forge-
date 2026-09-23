#!/usr/bin/env python3
"""Capture un BOSS a l'ecran depuis le build web (boss decale a 5s pour le test).
Sert web/ avec les en-tetes COOP/COEP (threads Godot), traverse le menu, attend, screenshote."""
import os, sys, time, threading, functools
from http.server import HTTPServer, SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright

WEB = r"C:\Users\Administrator\mecha-forge\web"
PORT = 8991
CHROME = r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
OUTDIR = r"C:\Users\Administrator\mecha-forge\cine\_show"

class H(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()
    def log_message(self, *a): pass

def serve():
    HTTPServer(("127.0.0.1", PORT), functools.partial(H, directory=WEB)).serve_forever()

threading.Thread(target=serve, daemon=True).start()
time.sleep(1)

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, headless=True, args=[
        "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
        "--no-sandbox", "--disable-setuid-sandbox"])
    pg = b.new_page(viewport={"width": 1280, "height": 720})
    pg.goto("http://127.0.0.1:%d/index.html" % PORT, wait_until="networkidle")
    time.sleep(6)
    def shot(n): pg.screenshot(path=os.path.join(OUTDIR, "boss_shot_%s.png" % n)); print("shot", n, flush=True)
    shot("0menu")
    # menu (1280x720) : PASSER -> JOUER -> CHAPITRE 1 (y~226) -> PASSER cinematique (UN seul clic)
    for (x, y, tag, wait) in [(1195, 45, "passer", 1.5), (640, 578, "jouer", 1.8),
                              (640, 226, "chap1", 2.5), (1195, 45, "skipcine", 2.5)]:
        pg.mouse.click(x, y); time.sleep(wait); shot("click_" + tag)
    # gameplay lance. On DISSIPE les drafts (clic 640,270 = 1re amelioration) ET on REVIT (640,381)
    # pour reprendre le jeu, puis capture rapide du boss engage (centre, non fige).
    for i in range(18):
        pg.mouse.click(640, 270); pg.mouse.click(640, 381)
        time.sleep(1.2); shot("g%d" % i)
    shot("boss")
    b.close()
print("DONE")
