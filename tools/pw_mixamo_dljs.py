import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        r=await pg.evaluate("""() => {
            const els=[...document.querySelectorAll('button, a, div')].filter(e=>e.textContent.trim()==='DOWNLOAD' && e.offsetParent!==null);
            if(!els.length) return 'no-btn';
            // pick the smallest (the actual button, not a container)
            els.sort((a,b)=>(a.offsetWidth*a.offsetHeight)-(b.offsetWidth*b.offsetHeight));
            els[0].click(); return 'clicked '+els[0].tagName+' '+els[0].className;
        }""")
        print("js:", r)
        await pg.wait_for_timeout(2800)
        await pg.screenshot(path="cine/_show/mixamo_dlmodal.png")
        await b.close()
asyncio.run(main())
