# -*- coding: utf-8 -*-
"""Capture chaque style de caracteres du menu EPURE en 1280x720 natif."""
import sys, os
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from playwright.sync_api import sync_playwright

SRC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "cine", "_show", "menu_style_lab.html"))
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
META = '<meta charset="utf-8">'
HTML = os.path.join(OUT, "_cap.html")
open(HTML, "w", encoding="utf-8").write(META + open(SRC, encoding="utf-8").read())

SLUGS = ["0_actuel", "1_techno_hud", "2_militaire", "3_affiche", "4_condense", "5_technique"]
WIDEN = """() => {
  document.getElementById('app').style.maxWidth='1700px';
  document.querySelector('.side').style.display='none';
  document.querySelector('main').style.gridTemplateColumns='1fr';
  window.dispatchEvent(new Event('resize'));
  return document.querySelector('.scaler').clientWidth;
}"""

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": 1760, "height": 1100}, device_scale_factor=1)
    pg.goto("file:///" + HTML.replace("\\", "/"))
    pg.wait_for_timeout(2500)
    try:
        pg.wait_for_function("Array.from(document.fonts).filter(f=>f.status==='loaded').length > 10", timeout=20000)
        print("polices web: CHARGEES")
    except Exception:
        print("polices web: TIMEOUT (repli systeme possible)")
    loaded = pg.evaluate("() => Array.from(document.fonts).filter(f=>f.status==='loaded').map(f=>f.family)")
    print("familles chargees:", sorted(set(loaded)))
    print("scaler:", pg.evaluate(WIDEN), "px")

    names = pg.eval_on_selector_all("#typos .opt .t", "els => els.map(e=>e.textContent.trim())")
    for i, nm in enumerate(names):
        pg.eval_on_selector_all("#typos .opt", "els => els[%d].click()" % i)
        pg.evaluate(WIDEN)
        pg.wait_for_timeout(400)
        st = pg.query_selector("#stage")
        f = os.path.join(OUT, "typo_%s.png" % (SLUGS[i] if i < len(SLUGS) else "t%d" % i))
        st.screenshot(path=f)
        bb = st.bounding_box()
        print("  %s  %dx%d  <- %s" % (os.path.basename(f), int(bb["width"]), int(bb["height"]), nm))
    b.close()
os.remove(HTML)
print("OK ->", OUT)
