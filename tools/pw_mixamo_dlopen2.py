import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        vp=pg.viewport_size or {"width":1920,"height":940}
        await pg.mouse.click(int(vp["width"]*0.915), int(vp["height"]*0.20))  # orange DOWNLOAD
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path="cine/_show/mixamo_dlmodal.png")
        print("clicked download @", int(vp["width"]*0.915), int(vp["height"]*0.20))
        await b.close()
asyncio.run(main())
