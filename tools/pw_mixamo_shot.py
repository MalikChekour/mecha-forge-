import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    ws=ver["webSocketDebuggerUrl"]
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ws)
        ctx=b.contexts[0]
        pg=None
        for pageo in ctx.pages:
            if "mixamo.com" in pageo.url:
                pg=pageo; break
        if pg is None:
            pg=ctx.pages[0]
        await pg.bring_to_front()
        await pg.wait_for_timeout(1500)
        await pg.screenshot(path="cine/_show/mixamo_now.png")
        print("shot ok:", pg.url)
        await b.close()
asyncio.run(main())
