# -*- coding: utf-8 -*-
"""Capture chaque style d'onglet : menu en contexte + bande agrandie, en une image."""
import sys, os
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from playwright.sync_api import sync_playwright
SRC=os.path.abspath("cine/_show/tab_styles.html"); OUT=sys.argv[1]; os.makedirs(OUT,exist_ok=True)
TMP=os.path.join(OUT,"_cap.html")
open(TMP,"w",encoding="utf-8").write('<meta charset="utf-8">\n'+open(SRC,encoding="utf-8").read())
SLUGS=["plaque","hud","chevron","bandeau","hexa","terminal"]
WIDEN="""() => { document.getElementById('app').style.maxWidth='1700px';
  document.querySelector('.side').style.display='none';
  document.querySelector('main').style.gridTemplateColumns='1fr';
  window.dispatchEvent(new Event('resize'));
  return document.querySelector('.scaler').clientWidth; }"""
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(viewport={"width":1760,"height":1400}, device_scale_factor=1)
    pg.goto("file:///"+TMP.replace("\\","/")); pg.wait_for_timeout(1500)
    print("largeur scene:", pg.evaluate(WIDEN))
    n=pg.eval_on_selector_all("#opts .opt","e=>e.length")
    for i in range(n):
        pg.eval_on_selector_all("#opts .opt","e=>e[%d].click()"%i); pg.evaluate(WIDEN); pg.wait_for_timeout(500)
        el=pg.query_selector(".stagewrap")
        f=os.path.join(OUT,"tabs_%d_%s.png"%(i,SLUGS[i] if i<len(SLUGS) else i))
        el.screenshot(path=f); bb=el.bounding_box()
        print("  %s  %dx%d"%(os.path.basename(f),int(bb["width"]),int(bb["height"])))
    b.close()
os.remove(TMP); print("DONE")
