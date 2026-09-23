import asyncio, json, urllib.request
from playwright.async_api import async_playwright
OUT=r"C:\Users\Administrator\mecha-forge\meshy_in\enemies\mix_juggernaut.fbx"
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        # exact plain Running (gentler than Fast Run)
        r=await pg.evaluate("""()=>{const bad=/turn|180|backward|strafe|jump|slide|stop|start|left|right|stairs|injured|dive|fast|pistol|rifle|shoot/i;const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img')&&e.offsetParent);let pk=t.find(e=>/^running$/i.test(e.textContent.trim())&&!bad.test(e.textContent));if(!pk)pk=t.find(e=>/run/i.test(e.textContent)&&!bad.test(e.textContent));if(pk){(pk.querySelector('img')||pk).click();return pk.textContent.trim().slice(0,20);}return 'none';}""")
        print("picked",r); await pg.wait_for_timeout(5500)
        await pg.evaluate("""()=>{const cbs=[...document.querySelectorAll('input[type=checkbox]')];const ip=cbs.find(c=>c.offsetParent&&/place/i.test((c.closest('div')||c.parentElement||{}).innerText||''));if(ip&&!ip.checked)ip.click();}""")
        await pg.wait_for_timeout(2500)
        await pg.locator("button.btn-primary", has_text="Download").first.click(timeout=5000)
        await pg.wait_for_selector(".modal", timeout=6000); await pg.wait_for_timeout(900)
        async with pg.expect_download(timeout=120000) as di:
            await pg.locator(".modal button", has_text="Download").first.click()
        dl=await di.value; await dl.save_as(OUT); print("SAVED")
        await b.close()
asyncio.run(main())
