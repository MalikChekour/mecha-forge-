import asyncio, json, urllib.request
from playwright.async_api import async_playwright
OUT=r"C:\Users\Administrator\mecha-forge\meshy_in\enemies\mixamo_walk.fbx"
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        # open modal
        await pg.locator("button.btn-primary", has_text="Download").first.click(timeout=4000)
        await pg.wait_for_selector(".modal", timeout=6000)
        await pg.wait_for_timeout(900)
        try:
            async with pg.expect_download(timeout=120000) as di:
                await pg.locator(".modal button", has_text="Download").first.click()
            dl=await di.value
            await dl.save_as(OUT)
            print("SAVED", OUT)
        except Exception as e:
            print("expect_download failed:", e)
        await b.close()
asyncio.run(main())
