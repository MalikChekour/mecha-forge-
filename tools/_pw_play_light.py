import time
from playwright.sync_api import sync_playwright
CHROME = r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
URL = "http://127.0.0.1:8991/index.html"
OUT = r"C:\Users\Administrator\mecha-forge\cine\_show"
with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, headless=True, args=[
        "--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader",
        "--ignore-gpu-blocklist","--enable-webgl","--no-sandbox"])
    pg = b.new_page(viewport={"width":1280,"height":720})
    pg.goto(URL, wait_until="load", timeout=60000)
    time.sleep(20)
    def shot(n): pg.screenshot(path="%s/lt_%s.png"%(OUT,n)); print("shot",n)
    pg.mouse.click(1195,45); time.sleep(2.5)                 # PASSER cinematic
    pg.mouse.click(640,578); time.sleep(2.5)                 # JOUER
    pg.mouse.click(640,288); time.sleep(4.5); shot("game")   # NORMAL -> run
    # drive and observe
    for key,n in [("ArrowRight","R"),("ArrowUp","U"),("ArrowLeft","L")]:
        pg.keyboard.down(key); time.sleep(1.4); shot(n); pg.keyboard.up(key); time.sleep(0.4)
    pg.keyboard.down("ArrowRight")
    for i in range(3): time.sleep(0.3); shot("walk%d"%i)
    pg.keyboard.up("ArrowRight")
    b.close(); print("done")
