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
    pg.mouse.click(640, 288); time.sleep(1.6)     # NORMAL -> run (capture sides FAST before level-ups pile up)

    def clear_levelup():
        # a level-up freezes the run; click several card rows to dismiss whatever is open (harmless picks)
        for y in (300, 372, 444):
            pg.mouse.click(640, y)

    def burst(key, tag):
        clear_levelup(); time.sleep(0.2)
        pg.keyboard.down(key)
        time.sleep(0.4)
        frames = []
        for i in range(6):
            clear_levelup()                         # keep the run un-paused each frame
            time.sleep(0.1)
            path = "%s/burst_%s_%d.png" % (OUT, tag, i)
            pg.screenshot(path=path)
            frames.append(Image.open(path).crop(CROP))
            time.sleep(0.05)
        pg.keyboard.up(key)
        time.sleep(0.3)
        w, h = frames[0].size
        strip = Image.new("RGB", (w * len(frames), h), (18, 20, 26))
        for i, f in enumerate(frames):
            strip.paste(f, (i * w, 0))
        strip.save("%s/ingame2_%s.png" % (OUT, tag))
        print("burst", tag)

    burst("ArrowRight", "right")
    burst("ArrowDown", "front")
    b.close(); print("done")
