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
        # Character Arm-Space handle ~ (0.914*W, 0.553*H); drag to right end (0.99*W)
        hx=int(vp["width"]*0.914); hy=int(vp["height"]*0.553)
        await pg.mouse.move(hx,hy); await pg.mouse.down()
        for f in range(1,11):
            await pg.mouse.move(hx+int((vp["width"]*0.988-hx)*f/10), hy); await pg.wait_for_timeout(40)
        await pg.mouse.up(); await pg.wait_for_timeout(2500)
        val=await pg.evaluate("""()=>{const el=[...document.querySelectorAll('*')].find(e=>/Character Arm-Space/i.test(e.textContent||'')&&e.children.length<6);return el?el.textContent.replace(/\s+/g,' ').slice(0,40):'?';}""")
        print("armspace row:", val)
        await pg.screenshot(path="cine/_show/mix_armdrag.png")
        await b.close()
asyncio.run(main())
