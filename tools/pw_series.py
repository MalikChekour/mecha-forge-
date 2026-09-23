import asyncio, json
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
        await pg.wait_for_timeout(4000)
        s=await pg.evaluate("() => window.__s || []")
        # group by instance id
        from collections import defaultdict
        print("total entries:", len(s))
        b.close if False else None
        # pick the id with the most samples
        groups={}
        for eid,t in s: groups.setdefault(eid,[]).append(t)
        for eid,ts in sorted(groups.items(), key=lambda kv:-len(kv[1]))[:3]:
            print("ENEMY", eid, "n=%d"%len(ts), "series:", [round(x,2) for x in ts[:40]])
        await b.close()
asyncio.run(main())
