import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        # pick a clean forward "Running"
        await pg.evaluate("""()=>{const bad=/turn|180|backward|strafe|jump|slide|stop|start|left|right|stairs|injured|dive/i;const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img')&&e.offsetParent);let pk=t.find(e=>/^running$/i.test(e.textContent.trim())&&!bad.test(e.textContent))||t.find(e=>/run/i.test(e.textContent)&&!bad.test(e.textContent));if(pk)(pk.querySelector('img')||pk).click();}""")
        await pg.wait_for_timeout(5500)
        # In Place
        await pg.evaluate("""()=>{const cbs=[...document.querySelectorAll('input[type=checkbox]')];const ip=cbs.find(c=>c.offsetParent&&/place/i.test((c.closest('div')||c.parentElement||{}).innerText||''));if(ip&&!ip.checked)ip.click();}""")
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path="cine/_show/mix_jug_run.png")
        t=await pg.evaluate("()=>{for(const e of document.querySelectorAll('*')){const x=(e.textContent||'').trim();if(/ON JUGGERNAUT/i.test(x)&&x.length<50)return x;}return '?';}")
        print("APPLIED:", t)
        await b.close()
asyncio.run(main())
