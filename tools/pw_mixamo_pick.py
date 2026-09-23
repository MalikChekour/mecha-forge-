import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(500)
        # try to click an exact "Walking" tile
        picked=False
        for name in ["Walking","Walk","Walking In Circle"]:
            try:
                el=pg.get_by_text(name, exact=True).first
                if await el.count():
                    await el.scroll_into_view_if_needed(); await el.click(timeout=2500)
                    picked=name; break
            except Exception as e: print("pick fail",name,e)
        await pg.wait_for_timeout(4500)
        # enable In Place
        try:
            ip=pg.get_by_text("In Place", exact=True).first
            if await ip.count(): await ip.click(timeout=2000)
        except Exception as e: print("inplace fail",e)
        await pg.wait_for_timeout(3500)
        await pg.screenshot(path="cine/_show/mixamo_pick.png")
        print("picked:", picked)
        await b.close()
asyncio.run(main())
