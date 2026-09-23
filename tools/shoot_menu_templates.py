# -*- coding: utf-8 -*-
"""Capture chaque template de menu en 1280x720 natif (Playwright local, sans MCP)."""
import sys, os
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from playwright.sync_api import sync_playwright

SRC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "cine", "_show", "menu_templates.html"))
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

# file:// carries no charset header, so the browser would decode our UTF-8 as
# latin-1 and mangle every accent (ECRAN -> Ã‰...). The published artifact gets a
# charset from its wrapper; for the local capture we prepend one ourselves.
META = '<meta charset="utf-8">'
HTML = os.path.join(OUT, "_capture.html")
open(HTML, "w", encoding="utf-8").write(META + open(SRC, encoding="utf-8").read())

SLUGS = ["actuel", "cinema", "dock_lateral", "carte_chapitre", "panneaux_tactiques", "epure"]

WIDEN = """() => {
  document.getElementById('app').style.maxWidth = '1700px';
  document.querySelector('.side').style.display = 'none';
  document.querySelector('main').style.gridTemplateColumns = '1fr';
  window.dispatchEvent(new Event('resize'));
  return document.querySelector('.scaler').clientWidth;
}"""

with sync_playwright() as p:
    b = p.chromium.launch(args=["--force-color-profile=srgb"])
    pg = b.new_page(viewport={"width": 1760, "height": 1100}, device_scale_factor=1)
    pg.goto("file:///" + HTML.replace("\\", "/"))
    pg.wait_for_timeout(1200)

    names = pg.eval_on_selector_all(".trow .t", "els => els.map(e => e.textContent.trim())")
    print("templates:", names)
    pg.eval_on_selector_all(".rb", "els => els[1].click()")     # 16:9 reference frame
    print("scaler:", pg.evaluate(WIDEN), "px (>=1280 => 1:1)")

    for i, nm in enumerate(names):
        pg.eval_on_selector_all(".trow", "els => els[%d].click()" % i)
        pg.evaluate(WIDEN)
        pg.wait_for_timeout(450)
        st = pg.query_selector("#stage")
        box = st.bounding_box()
        f = os.path.join(OUT, "menu_%d_%s.png" % (i, SLUGS[i] if i < len(SLUGS) else "t%d" % i))
        st.screenshot(path=f)
        print("  %s  %dx%d  <- %s" % (os.path.basename(f), int(box["width"]), int(box["height"]), nm))
    b.close()
os.remove(HTML)
print("OK ->", OUT)

# --- extra: the CURRENT menu at the ratios where it actually breaks ---
EXTRA = [(0, "4:3", 0, "probleme_4_3"), (0, "21:9", 4, "probleme_21_9")]
with sync_playwright() as p:
    b = p.chromium.launch(args=["--force-color-profile=srgb"])
    pg = b.new_page(viewport={"width": 1900, "height": 1100}, device_scale_factor=1)
    open(HTML, "w", encoding="utf-8").write(META + open(SRC, encoding="utf-8").read())
    pg.goto("file:///" + HTML.replace("\\", "/"))
    pg.wait_for_timeout(1000)
    for ti, label, ri, slug in EXTRA:
        pg.eval_on_selector_all(".trow", "els => els[%d].click()" % ti)
        pg.eval_on_selector_all(".rb", "els => els[%d].click()" % ri)
        pg.evaluate(WIDEN)
        pg.wait_for_timeout(400)
        st = pg.query_selector("#stage")
        box = st.bounding_box()
        f = os.path.join(OUT, "menu_x_%s.png" % slug)
        st.screenshot(path=f)
        print("  %s  %dx%d  <- ACTUEL @%s" % (os.path.basename(f), int(box["width"]), int(box["height"]), label))
    b.close()
os.remove(HTML)
