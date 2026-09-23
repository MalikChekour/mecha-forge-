import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        await pg.evaluate("""()=>{const b=[...document.querySelectorAll('button,a,div')].find(e=>/^\s*next\s*$/i.test(e.textContent||'')&&e.offsetParent&&e.children.length<=1);if(b)b.click();}""")
        await pg.wait_for_timeout(3500)
        await pg.screenshot(path="cine/_show/mix_markers2.png")
        t=await pg.evaluate("()=>document.body.innerText")
        import re
        print("HAS_CHIN:", "chin" in t.lower(), "HAS_WRIST:", "wrist" in t.lower())
        await b.close()
asyncio.run(main())
