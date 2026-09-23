#!/usr/bin/env python3
"""Tiny localhost server for cine/ WITH HTTP Range support (video seek).

Python's stdlib http.server ignores Range -> browsers can't seek. This handler
answers 206 Partial Content so scrubbing / jump-to-beat works. Bound to 127.0.0.1.

Usage:  python tools/serve_cine.py [port]
"""
import os, sys, re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "cine")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
TYPES = {".html": "text/html; charset=utf-8", ".mp4": "video/mp4",
         ".mp3": "audio/mpeg", ".wav": "audio/wav", ".png": "image/png",
         ".jpg": "image/jpeg", ".css": "text/css", ".js": "text/javascript"}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):  # quiet
        pass

    def _serve(self, head=False):
        p = self.path.split("?")[0].lstrip("/") or "player.html"
        fp = os.path.normpath(os.path.join(ROOT, p))
        if not fp.startswith(ROOT) or not os.path.isfile(fp):
            self.send_error(404); return
        size = os.path.getsize(fp)
        ctype = TYPES.get(os.path.splitext(fp)[1].lower(), "application/octet-stream")
        rng = self.headers.get("Range")
        start, end = 0, size - 1
        status = 200
        if rng:
            m = re.match(r"bytes=(\d*)-(\d*)", rng)
            if m:
                if m.group(1):
                    start = int(m.group(1))
                if m.group(2):
                    end = int(m.group(2))
                start = max(0, start); end = min(end, size - 1)
                status = 206
        length = end - start + 1
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        if status == 206:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, size))
        self.end_headers()
        if head:
            return
        with open(fp, "rb") as f:
            f.seek(start)
            remaining = length
            while remaining > 0:
                chunk = f.read(min(65536, remaining))
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    return
                remaining -= len(chunk)

    def do_GET(self):
        self._serve()

    def do_HEAD(self):
        self._serve(head=True)


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), H)
    print("SERVING %s on http://127.0.0.1:%d  (Range OK)" % (ROOT, PORT))
    srv.serve_forever()
