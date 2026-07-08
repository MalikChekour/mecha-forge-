#!/usr/bin/env python3
"""Generate a concept image via Pollinations FLUX (free, no key) for Meshy
image-to-3D. Sequential use only (Pollinations rate-limits parallel -> 429).

  python flux_concept.py "<prompt>" <out.png> [seed]
"""
import urllib.request, urllib.parse, os, sys

prompt = sys.argv[1]
out = sys.argv[2]
seed = sys.argv[3] if len(sys.argv) > 3 else "7"
style = ("clean hard-surface game character concept, full body, centered, "
         "isolated subject on plain flat light-grey background, sharp silhouette, "
         "even studio lighting, no text, no watermark")
u = ("https://image.pollinations.ai/prompt/"
     + urllib.parse.quote("%s, %s" % (prompt, style))
     + "?width=768&height=768&nologo=true&model=flux&seed=%s" % seed)
req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
data = urllib.request.urlopen(req, timeout=180).read()
os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
open(out, "wb").write(data)
print("concept", out, len(data), "bytes")
