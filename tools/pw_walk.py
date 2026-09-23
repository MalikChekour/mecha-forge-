import time, os
from playwright.sync_api import sync_playwright
from PIL import Image

CHROME = r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
URL = "http://127.0.0.1:8990/index.html"
OUT = r"C:\Users\Administrator\mecha-forge\cine\_show"
CROP = (500, 265, 780, 620)   # tight box around the player mech (centered, sits slightly low)

def run():
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path=CHROME, headless=True, args=[
            "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
            "--ignore-gpu-blocklist", "--enable-webgl", "--no-sandbox"])
        pg = b.new_page(viewport={"width": 1280, "height": 720})
        errs = []
        pg.on("console", lambda m: errs.append(m.type + ": " + m.text) if m.type == "error" else None)
        pg.goto(URL, wait_until="load", timeout=60000)
        time.sleep(18)
        def shot(n): pg.screenshot(path="%s/w_%s.png" % (OUT, n)); print("shot", n)
        shot("s0_cine")
        pg.mouse.click(1195, 45); time.sleep(2.5); shot("s1_menu")      # PASSER
        pg.mouse.click(640, 578); time.sleep(2.2); shot("s2_diff")      # JOUER
        pg.mouse.click(640, 288); time.sleep(5.5); shot("s3_run")       # NORMAL -> run starts directly (no OPTIONS click!)

        def burst(key, tag):
            pg.keyboard.down(key)
            time.sleep(0.5)
            frames = []
            for i in range(6):
                path = "%s/burst_%s_%d.png" % (OUT, tag, i)
                pg.screenshot(path=path)
                frames.append(Image.open(path).crop(CROP))
                time.sleep(0.13)
            pg.keyboard.up(key)
            time.sleep(0.4)
            w, h = frames[0].size
            strip = Image.new("RGB", (w * len(frames), h), (18, 20, 26))
            for i, f in enumerate(frames):
                strip.paste(f, (i * w, 0))
            strip.save("%s/ingame_%s.png" % (OUT, tag))
            print("burst", tag)

        # most-important directions first (front & back) in case swiftshader crashes late
        burst("ArrowDown", "down")
        burst("ArrowUp", "up")
        burst("ArrowRight", "right")
        burst("ArrowLeft", "left")
        if errs:
            print("=== errors ===")
            for e in errs[-6:]:
                print(" ", e[:120])
        b.close(); print("done")

run()
