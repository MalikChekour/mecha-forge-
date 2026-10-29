import asyncio, json, urllib.request
from playwright.async_api import async_playwright
OUT=r"C:\Users\Administrator\mecha-forge\cine\_show\mixamo_roles"
import os; os.makedirs(OUT, exist_ok=True)
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in (x.url or "")), ctx.pages[0])
        await pg.bring_to_front()
        await pg.wait_for_timeout(3000)
        info=await pg.evaluate("""() => {
          const t=document.body?document.body.innerText.slice(0,2500):'';
          const login=/sign in|log in|adobe id/i.test(t);
          const upload=/upload character/i.test(t);
          const chars=[...document.querySelectorAll('button,a,div')].filter(e=>/upload character|characters|animations/i.test(e.textContent||'') && e.offsetParent).slice(0,12).map(e=>(e.textContent||'').trim().slice(0,40));
          return {url:location.href, loginLikely:login, uploadVisible:upload, title:document.title, sample:t.slice(0,600), btns:chars};
        }""")
        print(json.dumps(info, ensure_ascii=False, indent=2))
        await pg.screenshot(path=os.path.join(OUT,"00_home.png"), full_page=False)
        print("shot ok")
        await b.close()
asyncio.run(main())
