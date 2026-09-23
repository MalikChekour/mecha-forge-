import asyncio, json, urllib.request
from playwright.async_api import async_playwright
OUT=r"C:\Users\Administrator\mecha-forge\meshy_in\enemies\mixamo_run.fbx"
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(500)
        # search running
        sb=pg.locator("input[type='text'], input[placeholder='Search']").first
        await sb.click(); await sb.fill("running"); await pg.keyboard.press("Enter")
        await pg.wait_for_timeout(4500)
        await pg.screenshot(path="cine/_show/mixamo_run_search.png")
        # click first result tile
        vp=pg.viewport_size or {"width":1920,"height":940}
        await pg.mouse.click(int(vp["width"]*0.088), int(vp["height"]*0.35))
        await pg.wait_for_timeout(5000)
        # ensure In Place checked
        try:
            st=await pg.evaluate("""() => {
                const cbs=[...document.querySelectorAll('input[type=checkbox]')];
                const ip=cbs.find(c=>c.offsetParent && /place/i.test((c.closest('div')||c.parentElement||{}).innerText||''));
                if(ip && !ip.checked){ ip.click(); return 'clicked-inplace'; }
                return ip? 'already:'+ip.checked : 'no-inplace';
            }""")
            print("inplace:", st)
        except Exception as e: print("ip err", e)
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path="cine/_show/mixamo_run_applied.png")
        # download
        await pg.locator("button.btn-primary", has_text="Download").first.click(timeout=4000)
        await pg.wait_for_selector(".modal", timeout=6000); await pg.wait_for_timeout(900)
        async with pg.expect_download(timeout=120000) as di:
            await pg.locator(".modal button", has_text="Download").first.click()
        dl=await di.value; await dl.save_as(OUT)
        print("SAVED", OUT)
        await b.close()
asyncio.run(main())
