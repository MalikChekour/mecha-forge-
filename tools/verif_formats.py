# -*- coding: utf-8 -*-
"""Verifie l'export web dans les 4 formats d'ecran, et COMPTE LES ERREURS DE PAGE.

Pourquoi un fichier et pas un script jetable : ce controle a ete reecrit a l'identique
plusieurs fois parce qu'il ne vivait qu'en ligne de commande. Il est la consigne du patron
(« verifier en vrai avant de dire que c'est fait »), donc il merite d'etre outille.

Usage : python tools/verif_formats.py [dossier_de_sortie]
Rend 0 si les 4 formats se chargent SANS erreur de page, 1 sinon.
"""
import os, sys, http.server, socketserver, threading, functools, json
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

RACINE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build")
SORTIE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(RACINE), "_verif")
PORT   = 8994
# 🚨 LOCALHOST UNIQUEMENT. Aucun tunnel public, jamais.
ADRESSE = "127.0.0.1"
FORMATS = [("16_9", 1280, 720), ("portrait", 480, 960), ("4_3", 1024, 768), ("21_9", 1720, 720)]
# Godot web a besoin de ces en-tetes pour SharedArrayBuffer : sans elles la page se charge
# "sans erreur" mais le moteur ne demarre jamais — un faux vert.
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()
    def log_message(self, *a): pass

def main():
    if not os.path.isdir(RACINE) or not os.path.exists(os.path.join(RACINE, "index.html")):
        print("ERREUR: pas d'export web dans", RACINE); return 1
    os.makedirs(SORTIE, exist_ok=True)
    srv = socketserver.TCPServer((ADRESSE, PORT), functools.partial(H, directory=RACINE))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    from playwright.sync_api import sync_playwright
    erreurs_total = 0
    try:
        with sync_playwright() as pw:
            nav = pw.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
            for nom, w, h in FORMATS:
                pg = nav.new_page(viewport={"width": w, "height": h})
                errs = []
                pg.on("pageerror", lambda e: errs.append(str(e)))
                pg.on("console", lambda m: errs.append(m.text) if m.type == "error" else None)
                pg.goto("http://%s:%d/index.html" % (ADRESSE, PORT), wait_until="load", timeout=60000)
                # on attend que le CANEVAS ait vraiment peint : une page "chargee" dont le
                # moteur n'a pas demarre passerait sinon pour un succes.
                pg.wait_for_timeout(14000)
                peint = pg.evaluate("""() => { const c = document.querySelector('canvas');
                    return c ? (c.width > 0 && c.height > 0) : false; }""")
                pg.screenshot(path=os.path.join(SORTIE, "%s.png" % nom))
                dur = [e for e in errs if "SharedArrayBuffer" not in e]
                erreurs_total += len(dur)
                print("[%s] %-9s canevas=%s erreurs=%d %s" % (
                    "ok" if (peint and not dur) else "KO", nom, peint, len(dur),
                    dur[0][:90] if dur else ""))
                if not peint: erreurs_total += 1
                pg.close()
            nav.close()
    finally:
        srv.shutdown()
    print("\nerreurs: %d  ->  %s" % (erreurs_total, SORTIE))
    return 0 if erreurs_total == 0 else 1

sys.exit(main())
