import asyncio, json, urllib.request, base64
from playwright.async_api import async_playwright
BASE="https://www.mixamo.com/api/v1/characters/%s/assets/thumbnails/static.png"
CANDS={
 "exo_gray":"ef7eb018-7cf3-4ae1-99ac-bab1c2c5d419",
 "vanguard":"45d387cb-2276-426b-9547-95f501296b68",
 "ely":"f7b85d05-5f1c-47d8-9770-9a1a054bd6f6",
 "alien_soldier":"75fb0e3e-cf4c-4828-b72b-63b42a4a5cbb",
 "crypto":"baa8eb9f-499f-4a3d-87ee-3f1e41bad413",
 "paladin":"eface83a-acc0-4036-a15e-3c650df1510d",
 "akai":"9da313dd-67a7-4677-8515-7a24b8035a69",
 "mutant":"cccc84b6-d072-4972-99da-75c5702e25f6",
 "maw":"c5ab0438-6309-40a5-bd0c-73ab2e23ecf1",
 "warrok":"efb06b46-a470-49b2-b7da-a06755d4dba7",
 "pumpkinhulk":"a4440477-3191-424b-8703-8126d1982f67",
 "demon":"447a4990-f669-436e-a066-e2e2968bdcba",
}
async def main():
    ver=json.load(urllib.request.urlopen("http://localhost:9224/json/version"))
    async with async_playwright() as p:
        b=await p.chromium.connect_over_cdp(ver["webSocketDebuggerUrl"])
        ctx=b.contexts[0]
        pg=next((x for x in ctx.pages if "mixamo.com" in x.url), ctx.pages[0])
        for slug,cid in CANDS.items():
            url=BASE%cid
            data=await pg.evaluate("""async(u)=>{ const r=await fetch(u,{credentials:'include'}); if(!r.ok) return 'ERR'+r.status; const buf=await r.arrayBuffer(); let s=''; const b=new Uint8Array(buf); for(let i=0;i<b.length;i++)s+=String.fromCharCode(b[i]); return btoa(s); }""", url)
            if data.startswith("ERR"): print(slug,data); continue
            open(f"cine/_show/mixchars/thumb_{slug}.png","wb").write(base64.b64decode(data))
            print("ok",slug,len(data))
        await b.close()
asyncio.run(main())
