import asyncio, json, urllib.request
from playwright.async_api import async_playwright
FBX=r"C:\Users\Administrator\mecha-forge\meshy_in\enemies\juggernaut.fbx"
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(500)
        # click UPLOAD CHARACTER (may trigger unsaved modal first)
        await pg.evaluate("""()=>{const b=[...document.querySelectorAll('button,a,div')].find(e=>/upload character/i.test(e.textContent||'')&&e.offsetParent&&e.children.length<=1);if(b)b.click();}""")
        await pg.wait_for_timeout(1500)
        # confirm any 'unsaved' modal
        await pg.evaluate("""()=>{const b=[...document.querySelectorAll('button,a,div')].find(e=>/(use this character|yes|continue|ok)/i.test(e.textContent||'')&&e.offsetParent&&e.children.length<=1);if(b)b.click();}""")
        await pg.wait_for_timeout(1500)
        await pg.screenshot(path="cine/_show/mix_upload_modal.png")
        # try to set the file input directly if present
        inp=await pg.query_selector("input[type=file]")
        if inp:
            await inp.set_input_files(FBX); print("FILE SET via input")
        else:
            print("NO input[type=file] visible yet")
        await pg.wait_for_timeout(9000)
        await pg.screenshot(path="cine/_show/mix_after_upload.png")
        print("done")
        await b.close()
asyncio.run(main())
