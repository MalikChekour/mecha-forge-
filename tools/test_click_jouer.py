import asyncio
import os
import sys
from playwright.async_api import async_playwright

CH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "cine", "proof_v1190")

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=CH,
            headless=True,
            args=[
                "--use-gl=angle",
                "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader",
                "--ignore-gpu-blocklist",
                "--enable-webgl",
                "--disable-gpu-sandbox",
                "--no-sandbox"
            ]
        )
        page = await browser.new_page(viewport={"width": 1280, "height": 720})
        await page.goto("http://127.0.0.1:8990/index.html")
        print("Loading...")
        sys.stdout.flush()
        await page.wait_for_timeout(20000)
        
        async def click(x, y, wait_ms=1200):
            print(f"Click at ({x}, {y})")
            sys.stdout.flush()
            await page.mouse.click(x, y)
            await page.wait_for_timeout(wait_ms)
            
        # 1. Skip intro
        await click(1195, 45, 2000)
        
        # 2. Click JOUER (at 500, 415)
        await click(500, 415, 2500)
        await page.screenshot(path=os.path.join(OUT_DIR, "step2_after_jouer.png"))
        print("Captured step2_after_jouer.png")
        sys.stdout.flush()
        
        await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
