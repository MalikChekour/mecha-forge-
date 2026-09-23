import asyncio
from playwright.async_api import async_playwright
CH=r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(executable_path=CH, args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader","--ignore-gpu-blocklist","--enable-webgl","--disable-gpu-sandbox"])
        pg=await b.new_page(viewport={"width":1280,"height":720})
        errs=[]
        pg.on("console", lambda m: errs.append(m.type+": "+m.text) if m.type=="error" else None)
        await pg.goto("http://localhost:8990/index.html")
        await pg.wait_for_timeout(19000)
        async def click(x,y,w=1400):
            await pg.mouse.click(x,y); await pg.wait_for_timeout(w)
        await click(1195,45)          # skip intro
        await pg.screenshot(path="cine/_show/chap_0_hub.png")     # HUB
        await click(640,578)          # JOUER
        await pg.screenshot(path="cine/_show/chap_1_select.png")  # CHAPTER SELECT (attendu)
        await click(640,226)          # chapitre 1 (L Usine)
        await pg.wait_for_timeout(1600)
        await pg.screenshot(path="cine/_show/chap_2_run.png")     # run lancée ?
        print("=== console errors ===");
        for e in errs[-6:]: print(" ", e[:120])
        print("done")
        await b.close()
asyncio.run(main())
