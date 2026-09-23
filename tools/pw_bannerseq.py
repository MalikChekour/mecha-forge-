import time
from playwright.sync_api import sync_playwright
from PIL import Image
CHROME=r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
URL="http://127.0.0.1:8990/index.html"; OUT=r"C:\Users\Administrator\mecha-forge\cine\_show"
with sync_playwright() as p:
    b=p.chromium.launch(executable_path=CHROME,headless=True,args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader","--ignore-gpu-blocklist","--enable-webgl","--no-sandbox"])
    pg=b.new_page(viewport={"width":1280,"height":720}); pg.goto(URL,wait_until="load",timeout=60000)
    time.sleep(18)
    pg.mouse.click(1195,45); time.sleep(2.5)
    pg.mouse.click(640,578); time.sleep(2.2)
    pg.mouse.click(640,288); time.sleep(1.4)
    pg.mouse.click(1195,45)   # biome skip -> t0
    crops=[]
    for i in range(9):        # t0+1 .. t0+9, one shot/sec, crop the banner band
        time.sleep(1.0)
        pg.screenshot(path=OUT+r"\_bs.png")
        crops.append(Image.open(OUT+r"\_bs.png").crop((300,60,980,140)))
    strip=Image.new("RGB",(680,80*9),(10,10,14))
    for i,c in enumerate(crops): strip.paste(c,(0,80*i))
    strip.save(OUT+r"\banner_montage.png")
    b.close(); print("done")
