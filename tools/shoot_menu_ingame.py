#!/usr/bin/env python3
"""Capture le MENU REEL depuis le build web, a plusieurs ratios, pour verifier
le calibrage + la police + l'effet au clic (JOUER enfonce)."""
import os, sys, time, threading, functools
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from http.server import HTTPServer, SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright

WEB = r"C:\Users\Administrator\mecha-forge\web"
PORT = 8993
CHROME = r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

class H(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()
    def log_message(self, *a): pass

threading.Thread(target=lambda: HTTPServer(("127.0.0.1", PORT),
    functools.partial(H, directory=WEB)).serve_forever(), daemon=True).start()
time.sleep(1)

SIZES = [("h_16_9", 1280, 720), ("v_phone", 720, 1280)]

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, headless=True, args=[
        "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
        "--no-sandbox", "--disable-setuid-sandbox"])
    for tag, w, h in SIZES:
        pg = b.new_page(viewport={"width": w, "height": h})
        pg.goto("http://127.0.0.1:%d/index.html" % PORT, wait_until="networkidle")
        time.sleep(9)
        # l'intro se passe avec PASSER en haut a droite, mais sa position/taille varie
        # selon le format : on tape plusieurs cibles plausibles jusqu'a sortir de la cinematique.
        for (cx, cy) in [(w - 50, 26), (w - 85, 45), (w - 60, 30), (w - 110, 40)]:
            pg.mouse.click(cx, cy); time.sleep(1.4)
        time.sleep(2.5)
        f = os.path.join(OUT, "ingame_menu_%s.png" % tag)
        pg.screenshot(path=f); print("  capture", os.path.basename(f), "%dx%d" % (w, h), flush=True)
        if tag == "h_16_9":
            # effet au clic : on appuie sur JOUER et on capture PENDANT l'enfoncement
            pg.mouse.move(w // 2, 404); pg.mouse.down(); time.sleep(0.06)
            pg.screenshot(path=os.path.join(OUT, "ingame_click_punch.png"))
            time.sleep(0.10)
            pg.screenshot(path=os.path.join(OUT, "ingame_click_shock.png"))
            pg.mouse.up()
            print("  capture effet au clic", flush=True)
        pg.close()
    b.close()
print("DONE")
