import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(300)
        await pg.keyboard.press("Escape"); await pg.wait_for_timeout(500)
        try: await pg.get_by_text("Characters", exact=True).first.click(timeout=2500)
        except: pass
        await pg.wait_for_timeout(2500)
        # scroll the results panel to load all tiles
        for _ in range(6):
            await pg.mouse.wheel(0, 1200); await pg.wait_for_timeout(700)
        data=await pg.evaluate("""() => {
            const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img'));
            const seen={}; const out=[];
            for(const e of t){
                const nm=(e.textContent||'').trim().replace(/Description.*/,'').slice(0,26);
                const img=e.querySelector('img'); const src=img?img.src:'';
                if(nm && src && !seen[nm]){ seen[nm]=1; out.push([nm,src]); }
            }
            return out;
        }""")
        print("COUNT", len(data))
        print(json.dumps(data))
        await b.close()
asyncio.run(main())
