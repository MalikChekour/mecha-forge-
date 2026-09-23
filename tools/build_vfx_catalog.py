#!/usr/bin/env python3
"""Inline the catalog assets (effect GIFs + in-game shots) into the page as data URIs.
Reads page template with {{ASSET:name}} placeholders, writes the self-contained artifact HTML."""
import base64, os, sys, re

ROOT = "C:/Users/Administrator/mecha-forge"
CARDS = f"{ROOT}/refs/vfx_cards"
SC = "C:/Users/Administrator/AppData/Local/Temp/2/claude/C--Users-Administrator/5ead40ad-f19f-4901-a883-ccc2b3edf7a6/scratchpad"
ACTION = f"{SC}/action"

def durl(path):
    ext = os.path.splitext(path)[1].lower()
    mime = {"gif": "image/gif", "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png"}[ext[1:]]
    with open(path, "rb") as f:
        return f"data:{mime};base64," + base64.b64encode(f.read()).decode()

ASSETS = {}
for idv in ["muzzle", "impact", "explosion", "beam", "aoe", "sabre", "shockwave", "charge"]:
    ASSETS[f"fx_{idv}"] = durl(f"{CARDS}/{idv}.gif")
for k in range(4):
    p = f"{ACTION}/act_{k}.jpg"
    if os.path.exists(p):
        ASSETS[f"act_{k}"] = durl(p)
for k in ["ig_sabre", "ig_overdrive"]:      # in-game motion clips
    ASSETS[k] = durl(f"{SC}/{k}.gif")
BCARDS = f"{ROOT}/refs/bullet_cards"        # animated HDR bullets
for k in ["tracer", "warhead", "lance", "orb"]:
    ASSETS[f"bul_{k}"] = durl(f"{BCARDS}/{k}.gif")
ASSETS["realsize"] = durl(f"{ACTION}/realsize.jpg")
ASSETS["ig_bullets"] = durl(f"{SC}/ig_bullets.gif")   # real play session, 4 weapons

src, dst = sys.argv[1], sys.argv[2]
html = open(src, encoding="utf-8").read()

def sub(m):
    key = m.group(1)
    if key not in ASSETS:
        raise SystemExit(f"missing asset: {key}")
    return ASSETS[key]

html = re.sub(r"\{\{ASSET:([a-z0-9_]+)\}\}", sub, html)
open(dst, "w", encoding="utf-8").write(html)
print(f"wrote {dst}  {os.path.getsize(dst)//1024}KB  ({len(ASSETS)} assets inlined)")
