import sys, os
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from playwright.sync_api import sync_playwright
SRC=os.path.abspath("cine/_show/type_specimen.html"); OUT=sys.argv[1]
TMP=os.path.join(OUT,"_sp.html"); os.makedirs(OUT,exist_ok=True)
open(TMP,"w",encoding="utf-8").write('<meta charset="utf-8">\n'+open(SRC,encoding="utf-8").read())
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(viewport={"width":1340,"height":1200})
    pg.goto("file:///"+TMP.replace("\\","/")); pg.wait_for_timeout(4500)
    fams=pg.evaluate("()=>Array.from(new Set(Array.from(document.fonts).filter(f=>f.status==='loaded').map(f=>f.family))).sort()")
    print("polices chargees:",fams)
    w=pg.evaluate("""()=>Array.from(document.querySelectorAll('.big')).map(e=>Math.round(e.getBoundingClientRect().width))""")
    print("largeurs des 6 titres:",w,"| doublons:", len(w)!=len(set(w)))
    el=pg.query_selector("#sheet"); f=os.path.join(OUT,"specimen_polices.png"); el.screenshot(path=f)
    print("capture:",os.path.basename(f), el.bounding_box()["width"],"x",round(el.bounding_box()["height"]))
    b.close()
os.remove(TMP)
