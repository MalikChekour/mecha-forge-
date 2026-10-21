#!/usr/bin/env python3
import os, sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "web_dbg")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8990

class H(SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *a):
        pass

print(f"Serving {ROOT} on port {PORT}")
sys.stdout.flush()
ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
