import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        await pg.screenshot(path="cine/_show/mixamo_state.png")
        modal=await pg.evaluate("() => { const m=document.querySelector('.modal'); return m && m.offsetParent ? m.innerText.slice(0,200) : 'no-modal'; }")
        print("MODAL:", repr(modal))
        await b.close()
asyncio.run(main())
