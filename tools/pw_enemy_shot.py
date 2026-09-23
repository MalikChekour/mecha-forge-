import asyncio
from playwright.async_api import async_playwright
CH=r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(executable_path=CH, args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader","--ignore-gpu-blocklist","--enable-webgl","--disable-gpu-sandbox"])
        pg=await b.new_page(viewport={"width":1280,"height":720})
        await pg.goto("http://localhost:8990/index.html")
        await pg.wait_for_timeout(17000)
        async def click(x,y,w=1200):
            await pg.mouse.click(x,y); await pg.wait_for_timeout(w)
        await click(1195,45)          # skip main intro
        await click(640,578)          # main menu -> play
        await click(640,226)          # CHAPITRE 1 (nouveau flux)
        await pg.wait_for_timeout(1500)
        await click(1195,45)          # skip biome intro -> RUN STARTS
        await pg.wait_for_timeout(700) # enemies (unlock 0) spawn immediately
        # dense burst over first ~7s of the run (bot dies ~12s in)
        for i in range(16):
            await pg.wait_for_timeout(450)
            await pg.screenshot(path=f"cine/_show/enemyshot_{i:02d}.png")
        print("captured")
        await b.close()
asyncio.run(main())
