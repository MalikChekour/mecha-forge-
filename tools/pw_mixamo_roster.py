import asyncio, json, urllib.request
from playwright.async_api import async_playwright
ROSTER=[("vanguard","Vanguard"),("exo_gray","Exo Gray"),("ely","Ely"),("paladin","Paladin"),("mutant","Mutant")]
OUT=r"C:\Users\Administrator\mecha-forge\meshy_in\enemies"
async def jclick(pg, text, tag="[class*=product]"):
    return await pg.evaluate("""(a)=>{const [t,sel]=a;const els=[...document.querySelectorAll(sel)].filter(e=>e.offsetParent&&e.textContent.includes(t));if(!els.length)return false;(els[0].querySelector('img')||els[0]).click();return true;}""",[text,tag])
async def clickbtn(pg, rx):
    return await pg.evaluate("""(rx)=>{const re=new RegExp(rx,'i');const b=[...document.querySelectorAll('button,a,div')].find(e=>re.test(e.textContent||'')&&e.offsetParent&&e.children.length<=1);if(b){b.click();return true;}return false;}""", rx)
async def search(pg, term):
    sb=pg.locator("input[type='text'], input[placeholder='Search']").first
    await sb.click(); await pg.keyboard.press("Control+A"); await pg.keyboard.press("Delete")
    await sb.type(term, delay=30); await pg.keyboard.press("Enter"); await pg.wait_for_timeout(3500)
async def tab(pg, name):
    try: await pg.get_by_text(name, exact=True).first.click(timeout=3000)
    except: pass
    await pg.wait_for_timeout(2500)
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front()
        for slug,name in ROSTER:
            try:
                await tab(pg,"Characters"); await search(pg,name)
                if not await jclick(pg,name): print("CHAR MISS",name); continue
                await pg.wait_for_timeout(1500); await clickbtn(pg,"use this character"); await pg.wait_for_timeout(6500)
                await tab(pg,"Animations"); await search(pg,"running")
                # pick a clean forward Running tile
                await pg.evaluate("""()=>{const bad=/turn|180|backward|strafe|jump|slide|stop|start|left|right|injured|dive/i;const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img')&&e.offsetParent);let pk=t.find(e=>/^running/i.test(e.textContent.trim())&&!bad.test(e.textContent))||t.find(e=>/run/i.test(e.textContent)&&!bad.test(e.textContent));if(pk)(pk.querySelector('img')||pk).click();}""")
                await pg.wait_for_timeout(5500)
                await pg.evaluate("""()=>{const cbs=[...document.querySelectorAll('input[type=checkbox]')];const ip=cbs.find(c=>c.offsetParent&&/place/i.test((c.closest('div')||c.parentElement||{}).innerText||''));if(ip&&!ip.checked)ip.click();}""")
                await pg.wait_for_timeout(2000)
                await pg.locator("button.btn-primary", has_text="Download").first.click(timeout=5000)
                await pg.wait_for_selector(".modal", timeout=6000); await pg.wait_for_timeout(900)
                async with pg.expect_download(timeout=120000) as di:
                    await pg.locator(".modal button", has_text="Download").first.click()
                dl=await di.value; await dl.save_as(f"{OUT}\mix_{slug}.fbx")
                print("SAVED",slug)
            except Exception as e:
                print("FAIL",slug,repr(e)[:120])
        await b.close()
asyncio.run(main())
