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
        await pg.evaluate("""()=>{const b=[...document.querySelectorAll('button,a,div')].find(e=>/^\s*upload character\s*$/i.test(e.textContent||'')&&e.offsetParent);if(b)b.click();}""")
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path="cine/_show/mix_upload_modal.png")
        # dump modal buttons + whether file input exists
        info=await pg.evaluate("""()=>{const m=document.querySelector('.modal')||document.body;const btns=[...m.querySelectorAll('button,a,div')].filter(e=>e.offsetParent&&e.textContent.trim()&&e.children.length<=1).map(e=>e.textContent.trim().slice(0,24));const inp=!!document.querySelector('input[type=file]');return {btns:[...new Set(btns)].slice(0,20), fileInput:inp};}""")
        print(json.dumps(info))
        await b.close()
asyncio.run(main())
