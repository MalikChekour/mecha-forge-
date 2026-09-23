import asyncio, json, urllib.request
from playwright.async_api import async_playwright
OUT=r"C:\Users\Administrator\mecha-forge\meshy_in\enemies\mix_juggernaut_wide.fbx"
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(400)
        title=await pg.evaluate("()=>{for(const e of document.querySelectorAll('*')){const x=(e.textContent||'').trim();if(/ON /i.test(x)&&x.length<40&&x.toUpperCase()===x)return x;}return '?';}")
        print("loaded:", title)
        # apply a plain Running for a fair comparison
        await pg.evaluate("""()=>{const bad=/turn|180|backward|strafe|jump|slide|stop|start|left|right|stairs|injured|dive|fast|pistol|rifle|shoot|look/i;const t=[...document.querySelectorAll('[class*=product]')].filter(e=>e.querySelector('img')&&e.offsetParent);let pk=t.find(e=>/^running$/i.test(e.textContent.trim())&&!bad.test(e.textContent))||t.find(e=>/run/i.test(e.textContent)&&!bad.test(e.textContent));if(pk)(pk.querySelector('img')||pk).click();}""")
        await pg.wait_for_timeout(5000)
        # set Character Arm-Space to max via jQuery UI slider
        res=await pg.evaluate("""()=>{
            if(!window.jQuery) return 'no-jquery';
            const sliders=jQuery('.ui-slider');
            let done=[];
            sliders.each(function(){ const lbl=(jQuery(this).closest('div').text()||'').toLowerCase();
                if(/arm.?space/.test(lbl)){ jQuery(this).slider('value',100); jQuery(this).slider('option','slide').call(this,null,{value:100}); done.push('armspace=100'); } });
            return done.length?done.join(','):'no-armspace-slider';
        }""")
        print("slider:", res)
        # fallback: click far-right of the 2nd slider track
        await pg.wait_for_timeout(500)
        try:
            sl=pg.locator(".ui-slider").nth(1)
            box=await sl.bounding_box()
            if box: await pg.mouse.click(box["x"]+box["width"]-4, box["y"]+box["height"]/2)
        except Exception as e: print("click fallback err", e)
        await pg.wait_for_timeout(2500)
        await pg.evaluate("""()=>{const cbs=[...document.querySelectorAll('input[type=checkbox]')];const ip=cbs.find(c=>c.offsetParent&&/place/i.test((c.closest('div')||c.parentElement||{}).innerText||''));if(ip&&!ip.checked)ip.click();}""")
        await pg.wait_for_timeout(1500)
        await pg.screenshot(path="cine/_show/mix_armspace.png")
        # download
        await pg.locator("button.btn-primary", has_text="Download").first.click(timeout=5000)
        await pg.wait_for_selector(".modal", timeout=6000); await pg.wait_for_timeout(900)
        async with pg.expect_download(timeout=120000) as di:
            await pg.locator(".modal button", has_text="Download").first.click()
        dl=await di.value; await dl.save_as(OUT); print("SAVED wide")
        await b.close()
asyncio.run(main())
