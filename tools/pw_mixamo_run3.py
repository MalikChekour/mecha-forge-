import asyncio, json, urllib.request
from playwright.async_api import async_playwright
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        sb=pg.locator("input[type='text'], input[placeholder='Search']").first
        await sb.click(); await pg.keyboard.press("Control+A"); await pg.keyboard.press("Delete")
        await sb.type("run", delay=40); await pg.keyboard.press("Enter")
        await pg.wait_for_timeout(5000)
        r=await pg.evaluate("""() => {
            const cards=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img') && e.offsetParent);
            const named=cards.map(c=>({el:c, name:(c.textContent||'').trim().replace(/Description.*/,'').trim()}));
            const bad=/turn|180|backward|strafe|slide|jump|stop|start|left|right|circle|injured|dive|crouch/i;
            let pick=named.find(c=>/^running$/i.test(c.name)) 
                   || named.find(c=>/^run$/i.test(c.name))
                   || named.find(c=>/^fast run/i.test(c.name))
                   || named.find(c=>/run/i.test(c.name) && !bad.test(c.name));
            if(!pick) return {ok:false, names:named.slice(0,12).map(x=>x.name.slice(0,22))};
            (pick.el.querySelector('img')||pick.el).click();
            return {ok:true, clicked:pick.name.slice(0,22)};
        }""")
        print("PICK:", json.dumps(r))
        await pg.wait_for_timeout(6000)
        title=await pg.evaluate("""() => {
            for(const e of document.querySelectorAll('h1,h2,h3,div,span')){
                const t=(e.textContent||'').trim();
                if(/ON TPOSE_MIXAMO/i.test(t) && t.length<40) return t;
            } return '?';
        }""")
        print("APPLIED:", title)
        await pg.screenshot(path="cine/_show/mixamo_run3.png")
        await b.close()
asyncio.run(main())
