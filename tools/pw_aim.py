import time
from playwright.sync_api import sync_playwright
from PIL import Image

CHROME = r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
URL = "http://127.0.0.1:8990/index.html"
OUT = r"C:\Users\Administrator\mecha-forge\cine\_show"
CROP = (500, 265, 780, 620)

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, headless=True, args=[
        "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
        "--ignore-gpu-blocklist", "--enable-webgl", "--no-sandbox"])
    pg = b.new_page(viewport={"width": 1280, "height": 720})
    pg.goto(URL, wait_until="load", timeout=60000)
    time.sleep(18)
    pg.mouse.click(1195, 45); time.sleep(2.5)     # PASSER
    pg.mouse.click(640, 578); time.sleep(2.2)     # JOUER
    pg.mouse.click(640, 288); time.sleep(1.6)     # NORMAL -> run

    def clear():
        for y in (300, 372, 444): pg.mouse.click(640, y)

    def burst(key, tag, n=6):
        clear(); time.sleep(0.2)
        if key: pg.keyboard.down(key)
        time.sleep(0.4)
        frames = []
        for i in range(n):
            clear(); time.sleep(0.1)
            pth = "%s/aim_%s_%d.png" % (OUT, tag, i)
            pg.screenshot(path=pth)
            frames.append(Image.open(pth).crop(CROP))
            time.sleep(0.06)
        if key: pg.keyboard.up(key)
        time.sleep(0.3)
        w, h = frames[0].size
        strip = Image.new("RGB", (w * len(frames), h), (18, 20, 26))
        for i, f in enumerate(frames): strip.paste(f, (i * w, 0))
        strip.save("%s/aimstrip_%s.png" % (OUT, tag))
        print("burst", tag)

    burst(None, "stand")          # STANDING + auto-firing -> should show the AIM pose (arms forward)
    burst("ArrowRight", "move")   # moving -> walk (arms up guard)
    b.close(); print("done")
