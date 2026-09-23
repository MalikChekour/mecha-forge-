import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(300)
        await pg.locator("button.btn-primary", has_text="Download").first.click(timeout=4000)
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path="cine/_show/mixamo_dlmodal.png")
        # dump modal buttons/selects for the next step
        r=await pg.evaluate("""() => {
            const info={buttons:[],selects:[]};
            for(const e of document.querySelectorAll('.modal button, .modal a')) if(e.offsetParent) info.buttons.push(e.textContent.trim().slice(0,20));
            for(const s of document.querySelectorAll('.modal select')) if(s.offsetParent) info.selects.push([...s.options].map(o=>o.text));
            return info;
        }""")
        print(json.dumps(r))
        await b.close()
asyncio.run(main())
