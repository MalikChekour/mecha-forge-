import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(500)
        try:
            await pg.get_by_text("Characters", exact=True).first.click(timeout=3000)
        except Exception as e: print("tab err",e)
        await pg.wait_for_timeout(4000)
        await pg.screenshot(path="cine/_show/mixamo_chars.png", full_page=False)
        names=await pg.evaluate("""() => {
            const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img')&&e.offsetParent);
            return t.slice(0,60).map(e=>(e.textContent||'').trim().replace(/Description.*/,'').slice(0,26));
        }""")
        print("NAMES:", json.dumps(names))
        await b.close()
asyncio.run(main())
