import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(300)
        r=await pg.evaluate("""() => {
            const out=[];
            for(const e of document.querySelectorAll('button, a')){
                const t=(e.textContent||'').trim();
                if(/download/i.test(t) && e.offsetParent!==null)
                    out.push({tag:e.tagName, cls:e.className, txt:t.slice(0,30), w:e.offsetWidth, h:e.offsetHeight});
            }
            return out;
        }""")
        print(json.dumps(r, indent=1))
        await b.close()
asyncio.run(main())
