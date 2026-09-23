import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        # switch to Animations tab
        try:
            await pg.get_by_text("Animations", exact=True).first.click(timeout=3000)
        except Exception as e: print("anim tab err", e)
        await pg.wait_for_timeout(3000)
        # search
        sb=pg.locator("input[type='text'], input[placeholder='Search']").first
        await sb.click(); 
        await pg.keyboard.press("Control+A"); await pg.keyboard.press("Delete")
        await sb.type("running", delay=40); await pg.keyboard.press("Enter")
        await pg.wait_for_timeout(5000)
        # list tiles
        names=await pg.evaluate("""() => {
            const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.offsetParent && e.textContent.trim());
            return t.slice(0,12).map(e=>e.textContent.trim().slice(0,26));
        }""")
        print("TILES:", names)
        # click a running tile
        r=await pg.evaluate("""() => {
            const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.offsetParent && /run/i.test(e.textContent));
            if(!t.length) return 'no-run-tile';
            (t[0].querySelector('img')||t[0]).click(); return 'clicked:'+t[0].textContent.trim().slice(0,26);
        }""")
        print("CLICK:", r)
        await pg.wait_for_timeout(5500)
        title=await pg.evaluate("() => { const h=[...document.querySelectorAll('*')].find(e=>/ON TPOSE_MIXAMO/i.test(e.textContent||'') && e.children.length===0); return h? h.textContent.trim():'?'; }")
        print("APPLIED:", title)
        await pg.screenshot(path="cine/_show/mixamo_run2.png")
        await b.close()
asyncio.run(main())
