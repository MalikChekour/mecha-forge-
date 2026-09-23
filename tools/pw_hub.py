import time
from playwright.sync_api import sync_playwright
CHROME=r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
OUT=r"C:\Users\Administrator\mecha-forge\cine\_show"
errs=[]
with sync_playwright() as p:
    b=p.chromium.launch(executable_path=CHROME,headless=True,args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader","--no-sandbox"])
    pg=b.new_page(viewport={"width":1280,"height":720})
    pg.on("console",lambda m: errs.append(m.type+": "+m.text) if m.type in ("error","warning") else None)
    pg.goto("http://127.0.0.1:8990/index.html",wait_until="load",timeout=60000)
    time.sleep(18)
    pg.mouse.click(1195,45); time.sleep(3.0)      # PASSER cinematic
    pg.screenshot(path=OUT+r"\hub.png"); print("hub shot")
    for e in errs[-8:]: print("  ",e[:130])
    b.close(); print("done")
