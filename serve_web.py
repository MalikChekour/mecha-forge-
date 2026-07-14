import http.server, socketserver, os, sys

# Sert la build web de MECHA-FORGE sur 127.0.0.1:8872 (headers no-cache).
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "web"))

class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()
    def log_message(self, *a):
        pass

class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

BIND = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
try:
    with Server((BIND, 8872), H) as httpd:
        print("Serveur MECHA-FORGE actif sur %s:8872" % BIND, flush=True)
        httpd.serve_forever()
except OSError:
    # port deja pris = un serveur tourne deja, c'est bon
    print("Un serveur ecoute deja sur le port 8872 (OK).", flush=True)
