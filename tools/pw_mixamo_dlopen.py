import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        # top-right DOWNLOAD opens the modal
        await pg.get_by_text("DOWNLOAD", exact=True).first.click(timeout=3000)
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path="cine/_show/mixamo_dlmodal.png")
        print("modal opened")
        await b.close()
asyncio.run(main())
