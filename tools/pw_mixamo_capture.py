import asyncio, json, urllib.request
from playwright.async_api import async_playwright
CANDS=["Exo Gray","Vanguard By","Ely By","Alien Soldier","Mutant","Paladin","Crypto","Maw"]
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        for name in CANDS:
            r=await pg.evaluate("""(nm) => {
                const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img')&&e.offsetParent&&e.textContent.includes(nm));
                if(!t.length) return 'miss';
                (t[0].querySelector('img')||t[0]).click(); return 'ok';
            }""", name)
            if r!='ok': print("skip",name,r); continue
            await pg.wait_for_timeout(5000)
            slug=name.split(" ")[0].lower()
            full=await pg.screenshot()
            open(f"cine/_show/mixchars/{slug}.png","wb").write(full)
            print("captured",name)
        await b.close()
asyncio.run(main())
