import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        # clear the search filter chip / box
        try:
            await pg.evaluate("""() => {
                const x=[...document.querySelectorAll('*')].find(e=>/^\s*×\s*\"?Run/i.test(e.textContent||'')&&e.children.length<=1&&e.offsetParent);
                if(x) x.click();
            }""")
        except Exception as e: print("clear err",e)
        await pg.wait_for_timeout(800)
        sb=pg.locator("input[type='text'], input[placeholder='Search']").first
        await sb.click(); await pg.keyboard.press("Control+A"); await pg.keyboard.press("Delete"); await pg.keyboard.press("Enter")
        await pg.wait_for_timeout(4500)
        names=await pg.evaluate("""() => {
            const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img')&&e.offsetParent);
            return t.map(e=>(e.textContent||'').trim().replace(/Description.*/,'').slice(0,24)).filter(x=>x&&!/per page|showing/i.test(x));
        }""")
        print("NCHARS:", len(names))
        print("NAMES:", json.dumps(names))
        await pg.screenshot(path="cine/_show/mixamo_chars2.png")
        await b.close()
asyncio.run(main())
