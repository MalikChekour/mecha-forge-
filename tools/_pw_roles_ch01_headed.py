import time, os
from playwright.sync_api import sync_playwright
CHROME = r"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
URL = "http://127.0.0.1:8990/index.html"
OUT = r"C:\\Users\\Administrator\\mecha-forge\\cine\\_show\\roles_ch01_headed"
os.makedirs(OUT, exist_ok=True)
with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, headless=False, args=[
        "--ignore-gpu-blocklist","--enable-webgl","--no-sandbox",
        "--disable-gpu-sandbox","--start-maximized"])
    ctx = b.new_context(viewport={"width":1280,"height":720})
    pg = ctx.new_page()
    logs=[]
    pg.on("console", lambda m: logs.append("[%s] %s"%(m.type, m.text)))
    print("goto", flush=True)
    pg.goto(URL, wait_until="load", timeout=90000)
    time.sleep(25)
    def shot(n):
        path=os.path.join(OUT, n+".png"); pg.screenshot(path=path); print("shot", n, flush=True)
    def click(x,y,w=1.2):
        pg.mouse.click(x,y); time.sleep(w)
    for i in range(10):
        click(1195, 45, 0.8)
        click(640, 620, 0.9)
        click(640, 500, 0.6)
        if i in (0,2,5,9):
            shot("boot_%02d"%i)
    for y in (578, 430, 400, 460, 520):
        click(640, y, 1.0)
    shot("after_jouer")
    for y in (226, 255, 288, 300, 340):
        click(640, y, 1.0)
    click(835, 255, 1.0)
    shot("after_ch")
    for _ in range(5):
        click(1195, 45, 0.7)
        click(640, 620, 0.7)
    shot("run_start")
    for i in range(32):
        if i % 3 == 0:
            pg.keyboard.down("ArrowRight"); time.sleep(0.7); pg.keyboard.up("ArrowRight")
        elif i % 3 == 1:
            pg.keyboard.down("ArrowUp"); time.sleep(0.5); pg.keyboard.up("ArrowUp")
        else:
            time.sleep(0.8)
        if i in (0,4,8,12,16,20,24,28,31):
            shot("run_%02d"%i)
    open(os.path.join(OUT,"console.txt"),"w",encoding="utf-8").write("\n".join(logs[-150:]))
    b.close(); print("done", flush=True)
