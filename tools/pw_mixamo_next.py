import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(800)
        vp=pg.viewport_size or {"width":1920,"height":940}
        print("viewport", vp)
        # click NEXT (bottom-right orange) — try by text first, fallback to coords
        clicked=False
        for sel in ["button:has-text('NEXT')","text=NEXT"]:
            try:
                el=pg.locator(sel).first
                if await el.count():
                    await el.click(timeout=2500); clicked=True; break
            except Exception as e: print("sel fail",sel,e)
        if not clicked:
            await pg.mouse.click(int(vp["width"]*0.822), int(vp["height"]*0.893))
        await pg.wait_for_timeout(4000)
        await pg.screenshot(path="cine/_show/mixamo_after_next.png")
        print("after NEXT shot")
        await b.close()
asyncio.run(main())
