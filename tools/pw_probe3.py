import asyncio
from playwright.async_api import async_playwright
CH=r"C:\Users\Administrator\AppData\Local\ms-playwright\chromium-1223\chrome-win64\chrome.exe"
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(executable_path=CH, args=["--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader","--ignore-gpu-blocklist","--enable-webgl","--disable-gpu-sandbox"])
        pg=await b.new_page(viewport={"width":1280,"height":720})
        await pg.goto("http://localhost:8990/index.html"); await pg.wait_for_timeout(20000)
        async def click(x,y): await pg.mouse.click(x,y); await pg.wait_for_timeout(1300)
        await click(1195,45); await click(640,578); await click(640,288)
        await pg.wait_for_timeout(1600); await click(1195,45)
        await pg.wait_for_timeout(2500)
        seen=[]
        for i in range(40):
            v=await pg.evaluate("() => window.__dbg ? window.__dbg.t.toFixed(2)+'|f'+window.__dbg.f+'|hf'+window.__dbg.hf+'|ec'+window.__dbg.ec : 'none'")
            seen.append(v); await pg.wait_for_timeout(90)
        # print unique-ish sequence
        print("SEQ:", " ".join(seen))
        await b.close()
asyncio.run(main())
