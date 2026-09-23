import time
from playwright.sync_api import sync_playwright
CHROME = r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
URL = "http://127.0.0.1:8990/index.html"; OUT=r"C:\Users\Administrator\mecha-forge\cine\_show"
with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, headless=True, args=[
        "--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader","--ignore-gpu-blocklist","--enable-webgl","--no-sandbox"])
    pg = b.new_page(viewport={"width":1280,"height":720})
    pg.goto(URL, wait_until="load", timeout=60000); time.sleep(20)
    pg.mouse.click(1195,45); time.sleep(2.5); pg.mouse.click(640,578); time.sleep(2.5); pg.mouse.click(640,288); time.sleep(4.5)
    for key,n in [("ArrowRight","fix_R"),("ArrowUp","fix_U"),("ArrowLeft","fix_L"),("ArrowDown","fix_D")]:
        pg.keyboard.down(key); time.sleep(1.3)
        print(n, pg.evaluate("window.__dbg")); pg.screenshot(path="%s/%s.png"%(OUT,n)); pg.keyboard.up(key); time.sleep(0.3)
    b.close()
