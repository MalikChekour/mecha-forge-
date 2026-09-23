import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(600)
        # search "walking"
        sb=pg.locator("input[type='text'], input[placeholder='Search']").first
        await sb.click(); await sb.fill("walking"); await pg.keyboard.press("Enter")
        await pg.wait_for_timeout(4000)
        await pg.screenshot(path="cine/_show/mixamo_search.png")
        # click first animation result thumbnail (top-left card image area)
        vp=pg.viewport_size or {"width":1920,"height":940}
        await pg.mouse.click(int(vp["width"]*0.088), int(vp["height"]*0.35))
        await pg.wait_for_timeout(5000)   # let it apply + play
        await pg.screenshot(path="cine/_show/mixamo_walk1.png")
        await pg.wait_for_timeout(700)
        await pg.screenshot(path="cine/_show/mixamo_walk2.png")
        print("walk applied + shots")
        await b.close()
asyncio.run(main())
