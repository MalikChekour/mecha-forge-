import asyncio, json, urllib.request, glob, os
from playwright.async_api import async_playwright
DL=r"C:\Users\Administrator\Downloads"
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        await pg.bring_to_front(); await pg.wait_for_timeout(300)
        before=set(glob.glob(DL+r"\*.fbx"))
        # click the modal's primary Download (not Cancel)
        await pg.evaluate("""() => {
            const btns=[...document.querySelectorAll('.modal button')].filter(e=>e.offsetParent && /download/i.test(e.textContent));
            if(btns.length) btns[0].click();
        }""")
        newf=None
        for _ in range(50):
            await pg.wait_for_timeout(1500)
            cur=set(glob.glob(DL+r"\*.fbx")); crd=glob.glob(DL+r"\*.crdownload")
            new=cur-before
            if new and not crd: newf=max(new,key=os.path.getmtime); break
        print("DOWNLOADED:", newf, (os.path.getsize(newf)//1024 if newf else 0), "KB")
        await b.close()
asyncio.run(main())
