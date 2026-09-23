# -*- coding: utf-8 -*-
"""Captures des 6 nouveaux styles (animations coupees) + une VIDEO des animations."""
import sys, os, glob
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from playwright.sync_api import sync_playwright
SRC=os.path.abspath("cine/_show/tab_styles2.html"); OUT=sys.argv[1]; os.makedirs(OUT,exist_ok=True)
TMP=os.path.join(OUT,"_cap.html")
open(TMP,"w",encoding="utf-8").write('<meta charset="utf-8">\n'+open(SRC,encoding="utf-8").read())
SLUGS=["stencil","cartouche","tag","circuit","capsule","ruban"]
WIDEN="""() => { document.getElementById('app').style.maxWidth='1700px';
  document.querySelector('.side').style.display='none';
  document.querySelector('main').style.gridTemplateColumns='1fr';
  window.dispatchEvent(new Event('resize'));
  return document.querySelector('.scaler').clientWidth; }"""
with sync_playwright() as p:
    b=p.chromium.launch()
    pg=b.new_page(viewport={"width":1760,"height":1400}, device_scale_factor=1)
    pg.goto("file:///"+TMP.replace("\\","/")); pg.wait_for_timeout(1200)
    # animations coupees : derniere option des deux listes
    pg.eval_on_selector_all("#tanim .opt","e=>e[e.length-1].click()")
    pg.eval_on_selector_all("#banim .opt","e=>e[e.length-1].click()")
    print("largeur scene:", pg.evaluate(WIDEN))
    n=pg.eval_on_selector_all("#opts .opt","e=>e.length")
    for i in range(n):
        pg.eval_on_selector_all("#opts .opt","e=>e[%d].click()"%i); pg.evaluate(WIDEN); pg.wait_for_timeout(450)
        el=pg.query_selector(".stagewrap")
        f=os.path.join(OUT,"t2_%d_%s.png"%(i,SLUGS[i] if i<len(SLUGS) else i))
        el.screenshot(path=f); print("  ",os.path.basename(f))
    b.close()

# --- VIDEO des animations : assemblage du titre + cascade des onglets, rejouee ---
VID=os.path.join(OUT,"vid"); os.makedirs(VID,exist_ok=True)
for f in glob.glob(os.path.join(VID,"*.webm")): os.remove(f)
with sync_playwright() as p:
    b=p.chromium.launch()
    ctx=b.new_context(viewport={"width":1400,"height":880}, record_video_dir=VID,
                      record_video_size={"width":1400,"height":880})
    pg=ctx.new_page(); pg.goto("file:///"+TMP.replace("\\","/")); pg.wait_for_timeout(1200)
    pg.eval_on_selector_all("#opts .opt","e=>e[0].click()")     # STENCIL
    pg.eval_on_selector_all("#tanim .opt","e=>e[0].click()")    # titre : assemblage
    pg.eval_on_selector_all("#banim .opt","e=>e[0].click()")    # onglets : cascade
    pg.evaluate(WIDEN); pg.wait_for_timeout(2200)
    for _ in range(2):
        pg.eval_on_selector("#replay","e=>e.click()"); pg.wait_for_timeout(2000)
    pg.eval_on_selector_all("#tanim .opt","e=>e[2].click()")    # titre : balayage
    pg.eval_on_selector_all("#banim .opt","e=>e[1].click()")    # onglets : reflet
    pg.evaluate(WIDEN); pg.wait_for_timeout(4200)
    ctx.close(); b.close()
os.remove(TMP)
print("video:", [os.path.basename(f) for f in glob.glob(os.path.join(VID,"*.webm"))])
