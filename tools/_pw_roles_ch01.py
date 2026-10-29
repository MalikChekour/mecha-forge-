
import time, os
from playwright.sync_api import sync_playwright
CHROME = r"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
URL = "http://127.0.0.1:8990/index.html"
OUT = r"C:\\Users\\Administrator\\mecha-forge\\cine\\_show\\roles_ch01b"
os.makedirs(OUT, exist_ok=True)
with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, headless=True, args=[
        "--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader",
        "--ignore-gpu-blocklist","--enable-webgl","--no-sandbox","--disable-gpu-sandbox"])
    pg = b.new_page(viewport={"width":1280,"height":720})
    logs=[]
    pg.on("console", lambda m: logs.append("[%s] %s"%(m.type, m.text)))
    print("goto", flush=True)
    pg.goto(URL, wait_until="load", timeout=90000)
    time.sleep(22)
    def shot(n):
        path=os.path.join(OUT, n+".png"); pg.screenshot(path=path); print("shot", n, flush=True)
    def click(x,y,w=1.2):
        pg.mouse.click(x,y); time.sleep(w)
    # burn through intros: PASSER + tap center repeatedly
    for i in range(8):
        click(1195, 45, 0.8)
        click(640, 620, 0.9)  # Touchez pour continuer
        click(640, 500, 0.6)
        if i in (0,2,4,7):
            shot("boot_%02d"%i)
    # JOUER (several possible Y)
    for y in (578, 430, 400, 460, 520):
        click(640, y, 1.0)
    shot("after_jouer")
    # chapter 1 / difficulty
    for y in (226, 255, 288, 300, 340):
        click(640, y, 1.0)
    click(835, 255, 1.0)  # deployer
    shot("after_ch")
    # skip biome intro
    for _ in range(4):
        click(1195, 45, 0.7)
        click(640, 620, 0.7)
    shot("run_start")
    # play ~40s
    for i in range(28):
        if i % 3 == 0:
            pg.keyboard.down("ArrowRight"); time.sleep(0.7); pg.keyboard.up("ArrowRight")
        elif i % 3 == 1:
            pg.keyboard.down("ArrowUp"); time.sleep(0.5); pg.keyboard.up("ArrowUp")
        else:
            time.sleep(0.8)
        if i in (0,3,6,10,14,18,22,27):
            shot("run_%02d"%i)
    open(os.path.join(OUT,"console.txt"),"w",encoding="utf-8").write("\\n".join(logs[-100:]))
    b.close(); print("done", flush=True)
