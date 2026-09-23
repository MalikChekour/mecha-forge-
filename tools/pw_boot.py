import sys, time
from playwright.sync_api import sync_playwright

CHROME = r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
URL = "http://127.0.0.1:8990/index.html"
OUT = r"C:\Users\Administrator\mecha-forge\cine\_show"

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, headless=True, args=[
        "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
        "--ignore-gpu-blocklist", "--enable-webgl", "--no-sandbox"])
    pg = b.new_page(viewport={"width": 1280, "height": 720})
    errs = []
    pg.on("console", lambda m: errs.append(m.type + ": " + m.text) if m.type in ("error", "warning") else None)
    pg.goto(URL, wait_until="load", timeout=60000)
    for s in (8, 14, 20):
        time.sleep(s if s == 8 else s - 8 if s == 14 else 6)
        pg.screenshot(path="%s/pw_%02ds.png" % (OUT, s))
        print("shot at", s, "s")
    print("=== console (last 8) ===")
    for e in errs[-8:]:
        print(" ", e[:120])
    b.close()
