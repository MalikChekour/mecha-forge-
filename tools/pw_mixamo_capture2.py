import asyncio, json, urllib.request
from playwright.async_api import async_playwright
CANDS=[("exo","Exo Gray"),("vanguard","Vanguard By"),("ely","Ely By"),("alien","Alien Soldier"),
       ("mutant","Mutant"),("paladin","Paladin"),("crypto","Crypto"),("maw","Maw")]
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        for slug,name in CANDS:
            r=await pg.evaluate("""(nm) => {
                const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img')&&e.offsetParent&&e.textContent.includes(nm));
                if(!t.length) return 'miss'; (t[0].querySelector('img')||t[0]).click(); return 'ok';
            }""", name)
            if r!='ok': print("skip",name); continue
            await pg.wait_for_timeout(1500)
            # confirm modal "USE THIS CHARACTER"
            await pg.evaluate("""() => {
                const btn=[...document.querySelectorAll('button,a,div')].find(e=>/use this character/i.test(e.textContent||'')&&e.offsetParent&&e.children.length<=1);
                if(btn) btn.click();
            }""")
            await pg.wait_for_timeout(6000)
            open(f"cine/_show/mixchars/{slug}.png","wb").write(await pg.screenshot())
            print("captured",name)
        await b.close()
asyncio.run(main())
