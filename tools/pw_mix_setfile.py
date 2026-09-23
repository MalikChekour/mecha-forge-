import asyncio, json, urllib.request
from playwright.async_api import async_playwright
FBX=r"C:\Users\Administrator\mecha-forge\meshy_in\enemies\juggernaut.fbx"
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        inp=await pg.query_selector("input[type=file]")
        await inp.set_input_files(FBX); print("file set")
        # wait for upload+process -> marker screen
        for _ in range(20):
            await pg.wait_for_timeout(3000)
            txt=await pg.evaluate("()=>document.body.innerText.slice(0,3000)")
            if "AUTO-RIGGER" in txt.upper() or "chin" in txt.lower() or "wrists" in txt.lower():
                print("MARKER SCREEN READY"); break
        await pg.screenshot(path="cine/_show/mix_markers.png")
        print("shot")
        await b.close()
asyncio.run(main())
